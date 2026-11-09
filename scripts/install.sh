#!/usr/bin/env bash
# Install a NixOS host locally. Run while booted on the target machine
# itself (e.g. from a live ISO), with a YubiKey in. The README's
# "Installation" has the walkthrough.
#
# Usage: sudo ./scripts/install.sh [--new-hardware] [hostname]
#   --new-hardware  gather this machine's hardware report even though the
#                   committed one's disk is here (other hardware around it)
set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info() { echo -e "${BLUE}==>${NC} $*"; }
log_success() { echo -e "${GREEN}==>${NC} $*"; }
log_warn() { echo -e "${RED}==>${NC} $*" >&2; }
die() {
  log_warn "$*"
  exit 1
}

readonly FLAKE_DIR="${INSTALL_HOST_FLAKE_DEFAULT:-$(pwd)}"
readonly NIX="nix --extra-experimental-features nix-command --extra-experimental-features flakes"
readonly REPO_URL="https://codeberg.org/BW20/dots.git"
readonly REPO_PUSH_URL="ssh://git@codeberg.org/BW20/dots.git"

# A pool on a disk the installer keeps has to import before disko runs: when
# its import fails, for a damaged pool or features this ISO's ZFS doesn't know,
# disko creates the pool anew over the data. A disk that isn't LUKS yet is a
# new one, for disko to format.
check_kept_pool() {
  local dev=$1 crypt=$2 pool=$3
  cryptsetup isLuks "$dev" || return 0
  # Without a trailing newline, as disko reads it.
  [[ -e /dev/mapper/$crypt ]] || cryptsetup open --key-file <(printf %s "$(</tmp/secret.key)") "$dev" "$crypt" ||
    die "luks_password doesn't open ${dev}. No disk was changed."
  zpool list "$pool" >/dev/null 2>&1 || zpool import -N -f "$pool" ||
    die "Pool ${pool} on ${dev}, which this keeps, won't import, and disko would create it anew. No disk was changed. Fix the import, or wipe ${dev} by hand if it should start over."
  zpool export "$pool"
  cryptsetup close "$crypt"
}

# Decrypts with the plugged-in YubiKey, retrying: pcscd and the YubiKey's
# enumeration can race at first. Arguments: what it is, then sops's.
decrypt() {
  local what=$1 attempt
  shift
  for attempt in $(seq 1 10); do
    sops -d "$@" && return 0
    [[ $attempt -lt 10 ]] || die "Failed to decrypt ${what} after 10 attempts"
    log_info "Decrypting ${what} failed, retrying in 2s..." >&2
    sleep 2
  done
}

# The new hardware report goes to Codeberg's main with the deploy key, so
# no other computer has to carry it there. Unsigned: comin deploys only a
# signed tip, so it deploys with the next signed commit, which has to sit
# on top of it. The installed host already runs it.
push_hardware_report() {
  local repo=$1 hostname=$2
  local -x JJ_USER="dots installer" JJ_EMAIL="root@dots-installer"
  jj -R "$repo" commit -m "chore: ${hostname}'s hardware report, from its installer" "root:modules/hosts/${hostname}/facter.json"
  jj -R "$repo" bookmark set main -r @-
  printf 'codeberg.org %s\n' "${CODEBERG_HOST_KEY:?}" >/tmp/codeberg-known-hosts
  GIT_SSH_COMMAND="ssh -i /tmp/deploy-key -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/tmp/codeberg-known-hosts" \
    jj -R "$repo" git push --remote codeberg --bookmark main
}

# jj, without the warning that root has no name and email: meant, as the
# clone becomes rocinante's /etc/nixos, where jj fills in yours on the first
# commit. Errors still show.
jj_quiet() {
  jj --quiet "$@" 2> >(grep -v '^Warning: Name and email not configured' >&2)
}

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

  # The repository that ends up in /etc/nixos, and that a new hardware
  # report is committed in. The flake fetched from Codeberg has no
  # repository to commit from.
  local repo=/tmp/dots
  rm -rf "$repo"
  log_info "Cloning ${REPO_URL}..."
  jj_quiet git clone --colocate --remote codeberg "$REPO_URL" "$repo"
  jj_quiet -R "$repo" git remote set-url codeberg --push "$REPO_PUSH_URL"
  local flake="path:${repo}"
  local host_dir="${repo}/modules/hosts/${hostname}"
  local secrets_file="${repo}/secrets/${hostname}.yaml"
  [[ -f "${host_dir}/configuration.nix" ]] ||
    die "${hostname} has no configuration.nix on Codeberg: write and push it first (README, \"A new host\")."
  [[ -f $secrets_file ]] || die "Missing ${secrets_file}"

  # The committed hardware report is this machine's if the disk it names
  # is here, by its model and serial (lib.mainDisk). If it isn't, or there
  # is no report, this machine is new hardware for the host, or the wrong
  # machine: asked, as the report also picks the disk to wipe.
  local report="${host_dir}/facter.json" reason=""
  if $new_hardware; then
    reason="--new-hardware was given."
  elif [[ ! -s $report ]]; then
    reason="${hostname} has no hardware report yet."
  else
    local committed_disk
    committed_disk=$($NIX eval --raw "${flake}#nixosConfigurations.${hostname}.config.disko.devices.disk.main.device") ||
      die "Can't evaluate nixosConfigurations.${hostname} (the error above)"
    [[ -e $committed_disk ]] || reason="${hostname}'s hardware report names ${committed_disk}, which this machine doesn't have."
  fi
  local gathered=false
  if [[ -n $reason ]]; then
    log_info "$reason"
    read -rp "Install ${hostname} on this machine, with a new hardware report? Type 'yes': " confirm
    [[ $confirm == "yes" ]] || die "Aborted."
    nixos-facter >"$report"
    gathered=true
  fi

  local nixos_gid
  nixos_gid=$($NIX eval "${flake}#nixosConfigurations.${hostname}.config.users.groups.nixos.gid") ||
    die "Can't evaluate nixosConfigurations.${hostname} (the error above)"
  local disk
  disk=$($NIX eval --raw "${flake}#nixosConfigurations.${hostname}.config.disko.devices.disk.main.device")
  [[ -e $disk ]] || die "Disk ${disk} not found."

  # Every disk disko sets up: it wipes those with destroy (the main disk),
  # and keeps the others, like dapple's media disk.
  local disks
  # shellcheck disable=SC2016 # a Nix expression, interpolated by Nix
  disks=$($NIX eval --raw "${flake}#nixosConfigurations.${hostname}.config.disko.devices.disk" \
    --apply 'disks: builtins.concatStringsSep "\n" (map (name: let d = disks.${name}; in "${d.device} ${if d.destroy then "wipe" else "keep"} ${d.content.name or "-"} ${d.content.content.pool or "-"}") (builtins.attrNames disks))')
  local -a wipe_disks=() keep_disks=() keep_luks=()
  local dev action crypt pool
  while read -r dev action crypt pool; do
    [[ -e $dev ]] || die "Disk ${dev} not found."
    if [[ $action == wipe ]]; then
      wipe_disks+=("$dev")
    else
      keep_disks+=("$dev")
      keep_luks+=("$dev $crypt $pool")
    fi
  done <<<"$disks"

  # A regenerated hardware report can name the kept disk as the main one.
  local wiped kept
  for wiped in "${wipe_disks[@]}"; do
    for kept in "${keep_disks[@]}"; do
      [[ $(readlink -f "$wiped") != $(readlink -f "$kept") ]] ||
        die "${wiped} is the disk to wipe and also ${kept}, the disk to keep. Is the hardware report's first disk the right one?"
    done
  done

  # Decrypt with whichever YubiKey is plugged in. SOPS_AGE_KEY_FILE
  # overrides it, e.g. with the passphrase identity (README, "Secrets and
  # keys").
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

  # Created owner-only, so none is ever world-readable.
  trap 'rm -f /tmp/secret.key /tmp/host-age.key /tmp/deploy-key' EXIT
  umask 077

  # disko needs the LUKS password as a plaintext file before the OS (and
  # sops-nix) exist. Every other secret is decrypted by sops-nix, with the
  # host's own age key.
  log_info "Decrypting the LUKS password..."
  decrypt luks_password --extract '["luks_password"]' "$secrets_file" >/tmp/secret.key

  # The host's own age key, so its services decrypt from the first boot on,
  # and the deploy key for the report: secrets/installer.yaml, which only
  # a YubiKey's PIN identity or the passphrase opens. One sops run, for
  # one PIN.
  log_info "Decrypting ${hostname}'s age key (the YubiKey's PIN)..."
  local installer_secrets
  installer_secrets=$(decrypt secrets/installer.yaml --output-type json "${repo}/secrets/installer.yaml")
  jq -r --arg key "${hostname}_age_key" '.[$key] // empty' <<<"$installer_secrets" >/tmp/host-age.key
  jq -r '.codeberg_deploy_key // empty' <<<"$installer_secrets" >/tmp/deploy-key
  unset installer_secrets
  [[ -s /tmp/host-age.key ]] || die "secrets/installer.yaml has no ${hostname}_age_key (README, \"A new host\")."
  # The key the host's file is encrypted for, or its secrets won't open.
  local host_public
  host_public=$(age-keygen -y /tmp/host-age.key)
  grep -q "&${hostname}_host ${host_public}\$" "${repo}/secrets/.sops.yaml" ||
    die "${hostname}_age_key in secrets/installer.yaml isn't the &${hostname}_host recipient in secrets/.sops.yaml."
  umask 022

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
  local kept_disk
  for kept_disk in "${keep_luks[@]}"; do
    read -r dev crypt pool <<<"$kept_disk"
    check_kept_pool "$dev" "$crypt" "$pool"
  done
  local disko_script
  disko_script=$($NIX build --no-link --print-out-paths \
    "${flake}#nixosConfigurations.${hostname}.config.system.build.diskoScript")
  "$disko_script"

  # The age key sops-nix decrypts with, readable by root only. Before
  # nixos-install, whose activation decrypts the secrets with it.
  local age_key_file
  age_key_file=$($NIX eval --raw "${flake}#nixosConfigurations.${hostname}.config.sops.age.keyFile")
  install -d -m 0700 "/mnt$(dirname "$age_key_file")"
  install -m 0400 /tmp/host-age.key "/mnt${age_key_file}"

  # --no-root-password: root's and jorrit's passwords come from sops
  # (secrets.nix, lib.mkUser), set again at every boot's activation.
  log_info "Installing NixOS..."
  nixos-install --no-root-password --flake "${flake}#${hostname}"

  # After the install, so a failed one pushes nothing. Asked, as the next
  # signed push deploys it: a test install, as in a VM, mustn't give the
  # real host its hardware. Not pushed, it stays in /etc/nixos, uncommitted.
  local pushed=false
  if $gathered; then
    read -rp "Push ${hostname}'s new hardware report to Codeberg's main, for the next deploy? Type 'yes': " confirm
    if [[ $confirm != "yes" ]]; then
      log_info "Not pushed."
    elif [[ ! -s /tmp/deploy-key ]]; then
      log_warn "secrets/installer.yaml has no codeberg_deploy_key."
    elif push_hardware_report "$repo" "$hostname"; then
      pushed=true
    fi
  fi

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
  log_info 'Type the LUKS password on the boots until secure boot is on: the first one with it on binds the TPM, so later boots unlock by themselves. Then restore its data with sudo offsite-restore (README, "Restoring data").'
  if $gathered && ! $pushed; then
    log_warn "The hardware report isn't on Codeberg: commit and push it from /etc/nixos after the first boot, or deploys will build ${hostname} for the old report."
  fi
}

main "$@"
