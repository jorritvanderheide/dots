#!/usr/bin/env bash
# Install a NixOS host locally -- run while booted on the target machine
# itself (e.g. from a live ISO). See docs/install.md for the full walkthrough.
#
# Usage: sudo ./scripts/install.sh <hostname>
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

readonly FLAKE_DIR="${INSTALL_HOST_FLAKE_DIR:-${INSTALL_HOST_FLAKE_DEFAULT:-$(pwd)}}"
readonly SECRETS_FILE="${FLAKE_DIR}/secrets/secrets.yaml"
readonly NIX="nix --extra-experimental-features nix-command --extra-experimental-features flakes"
readonly REPO_URL="https://codeberg.org/BW20/dots.git"
readonly REPO_PUSH_URL="ssh://git@codeberg.org/BW20/dots.git"

# age-plugin-yubikey talks to the key over PC/SC; the live ISO doesn't run
# pcscd by default, so start it ourselves if nothing already has.
pgrep -x pcscd >/dev/null 2>&1 || pcscd

main() {
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
  [[ -f $SECRETS_FILE ]] || die "Missing ${SECRETS_FILE}"

  local facter_path="${FLAKE_DIR}/modules/hosts/${hostname}/facter.json"
  if [[ ! -s $facter_path ]]; then
    log_info "Gathering hardware facts..."
    $NIX run nixpkgs#nixos-facter >"$facter_path"
  fi

  local nixos_gid
  nixos_gid=$($NIX eval "${FLAKE_DIR}#nixosConfigurations.${hostname}.config.users.groups.nixos.gid" 2>/dev/null) ||
    die "No nixosConfigurations.${hostname} found in flake"

  # The disk disko will wipe, by its model and serial (see lib.mainDisk).
  # Not there means the facter report is from other hardware.
  local disk
  disk=$($NIX eval --raw "${FLAKE_DIR}#nixosConfigurations.${hostname}.config.disko.devices.disk.main.device")
  [[ -e $disk ]] || die "Disk ${disk} not found: is this ${hostname}?"

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
  # sops-nix) exist. Every other secret is decrypted directly by the
  # systemd service that needs it (see secrets.nix / lib.nix / boot.nix),
  # once real systemd + pcscd are up -- not via sops-nix's own
  # activation-time install, which never works on this host (see docs/install.md).
  log_info "Decrypting LUKS password..."
  trap 'rm -f /tmp/secret.key' EXIT
  for attempt in $(seq 1 10); do
    sops -d --extract '["luks_password"]' "$SECRETS_FILE" >/tmp/secret.key && break
    [[ $attempt -lt 10 ]] || die "Failed to decrypt luks_password after 10 attempts"
    log_info "Decrypt attempt ${attempt} failed, retrying in 2s (pcscd/YubiKey enumeration can race transiently)..."
    sleep 2
  done
  chmod 400 /tmp/secret.key

  log_info "Partitioning + formatting (disko). This wipes:"
  lsblk -o PATH,MODEL,SERIAL,SIZE "$disk"
  read -rp "Type 'yes' to continue: " confirm
  [[ $confirm == "yes" ]] || die "Aborted."
  # zpool create can't load the module itself on the live ISO.
  modprobe zfs
  local disko_script
  disko_script=$($NIX build --no-link --print-out-paths \
    "${FLAKE_DIR}#nixosConfigurations.${hostname}.config.system.build.diskoScript")
  "$disko_script"

  # --no-root-password: root and jorrit both get their real passwords set by
  # set-password-root/set-password-jorrit (see secrets.nix / lib.nix's
  # mkUser) once booted for real, not during this install. Neither can
  # reliably decrypt inside nixos-install's bare chroot -- no systemd there,
  # so pcscd's socket activation for the YubiKey doesn't apply, and that's
  # true on every real boot too (see docs/install.md), not just here.
  log_info "Installing NixOS..."
  nixos-install --no-root-password --flake "${FLAKE_DIR}#${hostname}"

  local etc_nixos=/mnt/persist/system/etc/nixos
  mkdir -p "$(dirname "$etc_nixos")"
  if [[ -n ${INSTALL_HOST_FLAKE_DIR:-} ]]; then
    # A local checkout: copy it as it is, with its repository and the new
    # host's uncommitted facter.json.
    log_info "Copying ${FLAKE_DIR} to /etc/nixos..."
    mkdir -p "$etc_nixos"
    tar -C "$FLAKE_DIR" --exclude='.direnv' --exclude='result' --exclude='result-*' -cf - . |
      tar -C "$etc_nixos" -xf -
    diff -rq --exclude='.direnv' --exclude='result' --exclude='result-*' \
      "$FLAKE_DIR" "$etc_nixos" ||
      die "Copied config does not match source -- installation may be corrupted"
  else
    # The flake fetched from Codeberg has no repository, so clone one to
    # commit and push from. jj fills in your name on the first commit.
    log_info "Cloning ${REPO_URL} to /etc/nixos..."
    jj git clone --colocate --remote codeberg "$REPO_URL" "$etc_nixos"
    jj -R "$etc_nixos" git remote set-url codeberg "$REPO_PUSH_URL"
  fi
  chown -R "0:${nixos_gid}" "$etc_nixos"
  # Symmetric owner/group perms -- g+rwX alone leaves files owner-only-read
  # (444 base), which self-locks the first time a nixos-group member's own
  # edit reassigns owner to themselves (owner bits then apply instead of
  # group bits, and owner never had write). X keeps executables executable.
  chmod -R u+rwX,g+rwX "$etc_nixos"
  find "$etc_nixos" -type d -exec chmod g+s {} +

  # preservation.nix symlinks /etc/machine-id to here. On a true first boot
  # that target doesn't exist yet, so the symlink is dangling -- systemd's
  # machine-id commit uses O_CREAT|O_EXCL, which fails with EEXIST against a
  # dangling symlink (the path "exists" even though its target doesn't).
  # That kills dbus-broker (no valid machine ID), which cascades into every
  # D-Bus-dependent service failing (polkit, pcscd, tpm2-luks-enroll,
  # set-password-*, the sddm session). Seed it ourselves, deterministically
  # from the hostname, so the symlink target already exists before boot.
  log_info "Seeding persisted machine-id..."
  echo -n "$hostname" | sha256sum | cut -c1-32 >/mnt/persist/system/etc/machine-id
  chmod 0444 /mnt/persist/system/etc/machine-id

  log_success "Installation complete! Reboot when ready."
  log_info "Type the LUKS password on the first boot, with the YubiKey still in: that boot enrolls the TPM, so later boots unlock by themselves. Then join the tailnet (docs/install.md)."
}

main "$@"
