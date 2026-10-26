#!/usr/bin/env bash
# Install a NixOS host locally. Run while booted on the target machine
# itself (e.g. from a live ISO). See docs/install.md for the full walkthrough.
#
# Usage: sudo ./scripts/install.sh [--new-hardware] [hostname]
#   --new-hardware  gather this machine's hardware report and install with
#                   it, for a host without a second computer to commit one
set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info() { echo -e "${BLUE}==>${NC} $*"; }
log_success() { echo -e "${GREEN}==>${NC} $*"; }
die() {
  echo -e "${RED}==>${NC} $*"
  exit 1
}

readonly FLAKE_DIR="${INSTALL_HOST_FLAKE_DEFAULT:-$(pwd)}"
readonly NIX="nix --extra-experimental-features nix-command --extra-experimental-features flakes"
readonly REPO_URL="https://codeberg.org/BW20/dots.git"
readonly REPO_PUSH_URL="ssh://git@codeberg.org/BW20/dots.git"

main() {
  local new_hardware=false
  if [[ ${1:-} == --new-hardware ]]; then
    new_hardware=true
    shift
  fi
  local hostname="${1:-}"
  if [[ -z $hostname ]]; then
    local hosts
    mapfile -t hosts < <($NIX eval --raw "${FLAKE_DIR}#nixosConfigurations" \
      --apply 'hosts: builtins.concatStringsSep "\n" (builtins.attrNames hosts)')
    PS3="Host to install: "
    select hostname in "${hosts[@]}"; do
      [[ -n $hostname ]] && break
    done
    [[ -n $hostname ]] || die "No host picked."
  fi
  [[ $EUID -eq 0 ]] || die "Run as root (disko and nixos-install both need it)"

  # age-plugin-yubikey talks to the key over PC/SC; the live ISO doesn't run
  # pcscd by default, so start it ourselves if nothing already has.
  pgrep -x pcscd >/dev/null 2>&1 || pcscd

  # The repository that ends up in /etc/nixos. The flake fetched from
  # Codeberg has no repository to commit and push from. jj fills in your
  # name on the first commit.
  local repo=/tmp/dots
  rm -rf "$repo"
  log_info "Cloning ${REPO_URL}..."
  jj git clone --colocate --remote codeberg "$REPO_URL" "$repo"
  jj -R "$repo" git remote set-url codeberg "$REPO_PUSH_URL"

  # Installed from the clone, as pushed to Codeberg: the host's new age key
  # re-encrypts its secrets there, and with --new-hardware this
  # machine's hardware report goes in it too, since there is no other
  # computer to commit one from. They stay uncommitted changes in
  # /etc/nixos, to commit and push after the first boot.
  local flake="path:${repo}"
  if $new_hardware; then
    log_info "Gathering this machine's hardware report..."
    mkdir -p "${repo}/modules/hosts/${hostname}"
    nixos-facter >"${repo}/modules/hosts/${hostname}/facter.json"
  fi
  local secrets_file="${repo}/secrets/${hostname}.yaml"
  [[ -f $secrets_file ]] || die "Missing ${secrets_file}"

  [[ -s "${repo}/modules/hosts/${hostname}/facter.json" ]] ||
    die "${hostname} has no facter.json yet: commit one first, or add --new-hardware to gather it here (docs/install.md, \"A new host\")."

  local nixos_gid
  nixos_gid=$($NIX eval "${flake}#nixosConfigurations.${hostname}.config.users.groups.nixos.gid" 2>/dev/null) ||
    die "No nixosConfigurations.${hostname} found in flake"

  # The disk disko will wipe, by its model and serial (see lib.mainDisk).
  # Not there means the facter report is from other hardware.
  local disk
  disk=$($NIX eval --raw "${flake}#nixosConfigurations.${hostname}.config.disko.devices.disk.main.device")
  [[ -e $disk ]] || die "Disk ${disk} not found: is this ${hostname}? On new hardware, add --new-hardware."

  # Every disk disko sets up: it wipes those with destroy (the main disk),
  # and keeps the others, like dapple's media disk.
  local disks
  # shellcheck disable=SC2016 # a Nix expression, interpolated by Nix
  disks=$($NIX eval --raw "${flake}#nixosConfigurations.${hostname}.config.disko.devices.disk" \
    --apply 'disks: builtins.concatStringsSep "\n" (map (name: "${disks.${name}.device} ${if disks.${name}.destroy then "wipe" else "keep"}") (builtins.attrNames disks))')
  local -a wipe_disks=() keep_disks=()
  local dev action
  while read -r dev action; do
    [[ -e $dev ]] || die "Disk ${dev} not found."
    if [[ $action == wipe ]]; then
      wipe_disks+=("$dev")
    else
      keep_disks+=("$dev")
    fi
  done <<<"$disks"

  # Decrypt with whichever YubiKey is plugged in: each host has its own,
  # and all of them are recipients. SOPS_AGE_KEY_FILE overrides it, e.g.
  # with the passphrase identity (see docs/secrets.md).
  local attempt
  if [[ -z ${SOPS_AGE_KEY_FILE:-} ]]; then
    export SOPS_AGE_KEY_FILE=/tmp/yubikey-identity.txt
    for attempt in $(seq 1 10); do
      age-plugin-yubikey --identity 2>/dev/null >"$SOPS_AGE_KEY_FILE" || true
      grep -q '^AGE-PLUGIN-YUBIKEY-' "$SOPS_AGE_KEY_FILE" && break
      [[ $attempt -lt 10 ]] || die "No YubiKey found. Plug one in, or set SOPS_AGE_KEY_FILE to the passphrase identity."
      log_info "No YubiKey yet, retrying in 2s..."
      sleep 2
    done
  fi

  # disko needs the LUKS password as a plaintext file before the OS (and
  # sops-nix) exist. Every other secret is decrypted by sops-nix, with the
  # host's own age key.
  log_info "Decrypting LUKS password..."
  trap 'rm -f /tmp/secret.key /tmp/host-age.key' EXIT
  for attempt in $(seq 1 10); do
    # Created owner-only, so it is never world-readable, not even before
    # the chmod 400.
    (umask 077 && sops -d --extract '["luks_password"]' "$secrets_file" >/tmp/secret.key) && break
    [[ $attempt -lt 10 ]] || die "Failed to decrypt luks_password after 10 attempts"
    log_info "Decrypt attempt ${attempt} failed, retrying in 2s (pcscd/YubiKey enumeration can race transiently)..."
    sleep 2
  done
  chmod 400 /tmp/secret.key

  # The host's own age key, so its services decrypt from the first boot on.
  # They couldn't with a YubiKey: dapple's file only opens with a PIN, which
  # no service can type, and without their secrets the accounts stay
  # locked. Its public half replaces the old one in secrets/.sops.yaml, and the
  # host's file is re-encrypted for it, with the same YubiKey.
  log_info "Making ${hostname}'s own age key..."
  (umask 077 && age-keygen -o /tmp/host-age.key 2>/dev/null)
  local host_key
  host_key=$(age-keygen -y /tmp/host-age.key)
  local sops_config="${repo}/secrets/.sops.yaml"
  sed -i -E "s/(&${hostname}_host )age1[0-9a-z]+/\1${host_key}/" "$sops_config"
  grep -q "&${hostname}_host ${host_key}" "$sops_config" ||
    die "No &${hostname}_host key in ${sops_config} to replace"
  SOPS_CONFIG=$sops_config sops updatekeys --yes "$secrets_file"

  log_info "Partitioning + formatting (disko). This wipes:"
  lsblk -o PATH,MODEL,SERIAL,SIZE "${wipe_disks[@]}"
  if [[ ${#keep_disks[@]} -gt 0 ]]; then
    log_info "And keeps, opening its LUKS and importing its pool (formatted only if it isn't LUKS yet):"
    lsblk -o PATH,MODEL,SERIAL,SIZE "${keep_disks[@]}"
  fi
  read -rp "Type 'yes' to continue: " confirm
  [[ $confirm == "yes" ]] || die "Aborted."
  # zpool create can't load the module itself on the live ISO.
  modprobe zfs
  local disko_script
  disko_script=$($NIX build --no-link --print-out-paths \
    "${flake}#nixosConfigurations.${hostname}.config.system.build.diskoScript")
  "$disko_script"

  # The age key secrets.nix decrypts with, readable by root only. Before
  # nixos-install, whose activation decrypts the secrets with it.
  install -d -m 0700 /mnt/persist/system/var/lib/sops
  install -m 0400 /tmp/host-age.key /mnt/persist/system/var/lib/sops/age.key

  # --no-root-password: root's and jorrit's passwords come from sops
  # (secrets.nix, lib.mkUser), set again at every boot's activation.
  log_info "Installing NixOS..."
  nixos-install --no-root-password --flake "${flake}#${hostname}"

  local etc_nixos=/mnt/persist/system/etc/nixos
  mkdir -p "$(dirname "$etc_nixos")"
  log_info "Copying the repository to /etc/nixos..."
  cp -a "$repo" "$etc_nixos"
  chown -R "0:${nixos_gid}" "$etc_nixos"
  # Symmetric owner/group perms: g+rwX alone leaves files owner-only-read
  # (444 base), which self-locks the first time a nixos-group member's own
  # edit reassigns owner to themselves (owner bits then apply instead of
  # group bits, and owner never had write). X keeps executables executable.
  chmod -R u+rwX,g+rwX "$etc_nixos"
  find "$etc_nixos" -type d -exec chmod g+s {} +

  # The ISO imported the pools with its own host ID. The first boot only
  # imports a pool another host left imported when forced, as zroot is and
  # zmedia isn't: exported, both import cleanly.
  umount -R /mnt
  zpool export -a

  log_success "Installation complete! Reboot when ready."
  log_info "Type the LUKS password on the boots until secure boot is on: the first one with it on binds the TPM, so later boots unlock by themselves. Then restore its data with sudo offsite-restore (docs/install.md)."
  log_info "After the first boot, commit and push secrets/.sops.yaml and secrets/${hostname}.yaml (its new age key) from /etc/nixos, or from rocinante for a host without git (docs/install.md)."
  if $new_hardware; then
    log_info "Commit modules/hosts/${hostname}/facter.json with them."
  fi
}

main "$@"
