#!/usr/bin/env bash
# Install a NixOS host locally. Run while booted on the target machine
# itself (e.g. from a live ISO), with a YubiKey in. What's particular to a
# setup, it reads from the host's yubinstall options (yubinstall.nix). The
# README's "Installation" has the walkthrough.
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

# One of the host's yubinstall settings, by its jq path.
setting() { jq -r "$1" <<<"$settings"; }

# Every disk disko sets up, a line each: its device, whether disko wipes it
# (destroy, the main disk) or keeps it (like dapple's media disk), and its
# LUKS and pool names.
disko_disks() {
  # shellcheck disable=SC2016 # a Nix expression, interpolated by Nix
  $NIX eval --raw "$1#nixosConfigurations.$2.config.disko.devices.disk" \
    --apply 'disks: builtins.concatStringsSep "\n" (map (name: let d = disks.${name}; in "${d.device} ${if d.destroy then "wipe" else "keep"} ${d.content.name or "-"} ${d.content.content.pool or "-"}") (builtins.attrNames disks))'
}

# A pool on a disk the installer keeps has to import before disko runs: when
# its import fails, for a damaged pool or features this ISO's ZFS doesn't know,
# disko creates the pool anew over the data. A disk that isn't LUKS yet is a
# new one, for disko to format.
check_kept_pool() {
  local dev=$1 crypt=$2 pool=$3 key_file=$4
  cryptsetup isLuks "$dev" || return 0
  # Without a trailing newline, as disko reads it.
  [[ -e /dev/mapper/$crypt ]] || cryptsetup open --key-file <(printf %s "$(<"$key_file")") "$dev" "$crypt" ||
    die "The LUKS password doesn't open ${dev}. No disk was changed."
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

# The new hardware report goes to the repository with the deploy key, so
# no other computer has to carry it there. Unsigned: comin deploys only a
# signed tip, so it deploys with the next signed commit, which has to sit
# on top of it. The installed host already runs it.
push_hardware_report() {
  local repo=$1 hostname=$2
  local -x JJ_USER JJ_EMAIL
  JJ_USER=$(setting .reportCommit.name)
  JJ_EMAIL=$(setting .reportCommit.email)
  jj -R "$repo" commit -m "chore: ${hostname}'s hardware report, from its installer" "root:$(setting .hardwareReport)"
  jj -R "$repo" bookmark set "$(setting .repository.branch)" -r @-
  setting .repository.knownHosts >/tmp/push-known-hosts
  GIT_SSH_COMMAND="ssh -i /tmp/deploy-key -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/tmp/push-known-hosts" \
    jj -R "$repo" git push --remote "$(setting .repository.remote)" --bookmark "$(setting .repository.branch)"
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

  # The host's settings, from the flake this runs from, which is what the
  # clone below gets. They don't need its hardware report, which a new host
  # doesn't have yet.
  local settings
  settings=$($NIX eval --json "${FLAKE_DIR}#nixosConfigurations.${hostname}.config.yubinstall") ||
    die "Can't evaluate ${hostname}'s yubinstall settings (the error above). Is its configuration pushed? (README, \"A new host\")"

  # age-plugin-yubikey talks to the key over PC/SC; the live ISO doesn't run
  # pcscd by default, so start it ourselves if nothing already has.
  pgrep -x pcscd >/dev/null 2>&1 || pcscd

  # The repository that ends up in checkout.path, and that a new hardware
  # report is committed in. The flake this runs from has no repository to
  # commit from.
  local repo=/tmp/repo
  rm -rf "$repo"
  log_info "Cloning $(setting .repository.url)..."
  jj_quiet git clone --colocate --remote "$(setting .repository.remote)" "$(setting .repository.url)" "$repo"
  jj_quiet -R "$repo" git remote set-url "$(setting .repository.remote)" --push "$(setting .repository.pushUrl)"
  local flake="path:${repo}"
  local secrets_file
  secrets_file="${repo}/$(setting .secrets.file)"
  [[ -f $secrets_file ]] || die "Missing ${secrets_file}"

  # The committed hardware report is this machine's if the disks disko
  # wipes are here, by their model and serial (lib.mainDisk). If they
  # aren't, or there is no report, this machine is new hardware for the
  # host, or the wrong machine: asked, as the report also picks the disk
  # to wipe.
  local report reason="" dev action rest
  report="${repo}/$(setting .hardwareReport)"
  if $new_hardware; then
    reason="--new-hardware was given."
  elif [[ ! -s $report ]]; then
    reason="${hostname} has no hardware report yet."
  else
    local committed
    committed=$(disko_disks "$flake" "$hostname") || die "Can't evaluate nixosConfigurations.${hostname} (the error above)"
    while read -r dev action rest; do
      if [[ $action == wipe && ! -e $dev ]]; then
        reason="${hostname}'s hardware report names ${dev}, which this machine doesn't have."
      fi
    done <<<"$committed"
  fi
  local gathered=false
  if [[ -n $reason ]]; then
    log_info "$reason"
    read -rp "Install ${hostname} on this machine, with a new hardware report? Type 'yes': " confirm
    [[ $confirm == "yes" ]] || die "Aborted."
    mkdir -p "$(dirname "$report")"
    nixos-facter >"$report"
    gathered=true
  fi

  local checkout_gid
  checkout_gid=$($NIX eval "${flake}#nixosConfigurations.${hostname}.config.users.groups.$(setting .checkout.group).gid") ||
    die "Can't evaluate nixosConfigurations.${hostname} (the error above)"

  local disks
  disks=$(disko_disks "$flake" "$hostname")
  local -a wipe_disks=() keep_disks=() keep_luks=()
  local crypt pool
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
  local luks_key_file
  luks_key_file=$(setting .secrets.luksKeyFile)
  # shellcheck disable=SC2064 # the path, as it is now
  trap "rm -f '${luks_key_file}' /tmp/host-age.key /tmp/deploy-key" EXIT
  umask 077

  # disko needs the LUKS password as a plaintext file before the OS (and
  # sops-nix) exist. Every other secret is decrypted by sops-nix, with the
  # host's own age key.
  log_info "Decrypting the LUKS password..."
  decrypt "the LUKS password" --extract "[\"$(setting .secrets.luksPassword)\"]" "$secrets_file" >"$luks_key_file"

  # The host's own age key, so its services decrypt from the first boot on,
  # and the deploy key for the report, from the installer's own file, which
  # only a YubiKey's PIN identity or the passphrase opens. One sops run, for
  # one PIN.
  local installer_file age_key_name
  installer_file=$(setting .secrets.installerFile)
  age_key_name=$(setting .secrets.ageKey)
  log_info "Decrypting ${hostname}'s age key (the YubiKey's PIN)..."
  local installer_secrets
  installer_secrets=$(decrypt "$installer_file" --output-type json "${repo}/${installer_file}")
  jq -r --arg key "$age_key_name" '.[$key] // empty' <<<"$installer_secrets" >/tmp/host-age.key
  jq -r --arg key "$(setting .secrets.deployKey)" '.[$key] // empty' <<<"$installer_secrets" >/tmp/deploy-key
  unset installer_secrets
  [[ -s /tmp/host-age.key ]] || die "${installer_file} has no ${age_key_name} (README, \"A new host\")."
  # The key the host's file is encrypted for, or its secrets won't open.
  local host_public
  host_public=$(age-keygen -y /tmp/host-age.key)
  grep -q "recipient: ${host_public}\$" "$secrets_file" ||
    die "${age_key_name} in ${installer_file} isn't a recipient of $(setting .secrets.file)."
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
    check_kept_pool "$dev" "$crypt" "$pool" "$luks_key_file"
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

  # --no-root-password: the users' passwords come from sops (secrets.nix,
  # lib.mkUser), set again at every boot's activation.
  log_info "Installing NixOS..."
  nixos-install --no-root-password --flake "${flake}#${hostname}"

  # After the install, so a failed one pushes nothing. Asked, as the next
  # signed push deploys it: a test install, as in a VM, mustn't give the
  # real host its hardware. Not pushed, it stays in the checkout, uncommitted.
  local pushed=false
  if $gathered; then
    read -rp "Push ${hostname}'s new hardware report to $(setting .repository.pushUrl), for the next deploy? Type 'yes': " confirm
    if [[ $confirm != "yes" ]]; then
      log_info "Not pushed."
    elif [[ ! -s /tmp/deploy-key ]]; then
      log_warn "${installer_file} has no $(setting .secrets.deployKey)."
    elif push_hardware_report "$repo" "$hostname"; then
      pushed=true
    fi
  fi

  local checkout
  checkout="/mnt$(setting .checkout.path)"
  mkdir -p "$(dirname "$checkout")"
  log_info "Copying the repository to $(setting .checkout.path)..."
  cp -a "$repo" "$checkout"
  chown -R "0:${checkout_gid}" "$checkout"
  # Symmetric owner/group perms: g+rwX alone leaves files owner-only-read
  # (444 base), which self-locks the first time a group member's own edit
  # reassigns owner to themselves (owner bits then apply instead of group
  # bits, and owner never had write). X keeps executables executable.
  chmod -R u+rwX,g+rwX "$checkout"
  find "$checkout" -type d -exec chmod g+s {} +

  # The ISO imported the pools with its own host ID. The first boot only
  # imports a pool another host left imported when forced, as zroot is and
  # zmedia isn't: exported, both import cleanly.
  umount -R /mnt
  zpool export -a

  log_success "Installation complete! Reboot when ready."
  log_info 'Type the LUKS password on the boots until secure boot is on: the first one with it on binds the TPM, so later boots unlock by themselves. Then restore its data with sudo offsite-restore (README, "Restoring data").'
  if $gathered && ! $pushed; then
    log_warn "The hardware report isn't pushed: commit and push it from $(setting .checkout.path) after the first boot, or deploys will build ${hostname} for the old report."
  fi
}

main "$@"
