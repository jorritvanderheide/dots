#!/usr/bin/env bash
# Install NixOS locally on current host
# Usage: ninstall <hostname>
# Example: ninstall myHost

# shellcheck source=lib/common.sh disable=SC1091
source "$(dirname "$0")/lib/common.sh"

# Configuration
readonly MOUNT_POINT="/mnt"

# Helper functions
get_age_key_from_file() {
  local key_file="$1"
  ssh-keygen -y -f "$key_file" | ssh-to-age 2>/dev/null || die "Failed to convert SSH key to age key"
}

update_sops_yaml() {
  local key_line="  - &$HOST $HOST_AGE_KEY"
  local ref_line="          - *$HOST"

  # Add or update host key
  if grep -q "^  - &$HOST " .sops.yaml; then
    # shellcheck disable=SC2155
    local existing_key=$(grep "^  - &$HOST " .sops.yaml | awk '{print $3}')
    [ "$existing_key" != "$HOST_AGE_KEY" ] && sed -i "s|^  - &$HOST .*|$key_line|" .sops.yaml
  else
    sed -i "/^keys:/a\\$key_line" .sops.yaml
  fi

  # Add host to creation_rules if not present
  grep -q "^\s*- \*$HOST\s*$" .sops.yaml || sed -i "/- age:/a\\$ref_line" .sops.yaml
}

main() {
  setup_error_handling

  # Check dependencies
  command -v nixos-install >/dev/null 2>&1 || die "nixos-install is not installed (are you in a NixOS installer?)"
  command -v ssh-keygen >/dev/null 2>&1 || die "ssh-keygen is not installed"
  command -v ssh-to-age >/dev/null 2>&1 || die "ssh-to-age is not installed"
  command -v sops >/dev/null 2>&1 || die "sops is not installed"
  command -v jq >/dev/null 2>&1 || die "jq is not installed"
  command -v nix >/dev/null 2>&1 || die "nix is not installed"

  # === USAGE ===
  [ $# -lt 1 ] && die "Usage: ninstall <hostname>
Example: ninstall myHost"

  # === SETUP ===
  local HOST="$1"
  local HOST_DIR="modules/hosts/$HOST"
  local FLAKE_DIR
  FLAKE_DIR=$(get_flake_dir)

  log_info "Installing NixOS as $HOST"

  [ -d "$HOST_DIR" ] || die "Host directory $HOST_DIR does not exist! Please create it first with a configuration.nix"
  [ -f .sops.yaml ] || die ".sops.yaml not found!"

  # Setup cleanup trap
  local TEMP_FILES=()
  cleanup() {
    for f in "${TEMP_FILES[@]}"; do
      [ -e "$f" ] && rm -rf "$f"
    done
  }
  trap cleanup EXIT

  # === RUN FACTER ===
  log_info "Running nixos-facter to detect hardware..."
  local FACTER_TEMP
  FACTER_TEMP=$(mktemp)
  TEMP_FILES+=("$FACTER_TEMP")

  nix run --extra-experimental-features 'nix-command flakes' nixpkgs#nixos-facter -- -o "$FACTER_TEMP"
  jq empty "$FACTER_TEMP" 2>/dev/null || die "facter.json is not valid JSON!"

  cp "$FACTER_TEMP" "$HOST_DIR/facter.json"
  log_success "Saved facter.json to $HOST_DIR/"

  # === GENERATE SSH HOST KEY ===
  log_info "Generating SSH host key for $HOST..."
  local PERSIST_DIR="$MOUNT_POINT/persist/system/etc/ssh"

  # Create directory structure (installation will populate /mnt)
  sudo mkdir -p "$PERSIST_DIR" \
    "$MOUNT_POINT/persist/system/var/"{log,lib/{nixos,systemd}} \
    "$MOUNT_POINT/persist/home"
  sudo chmod 755 "$MOUNT_POINT/persist/home"

  # Generate SSH host keys in persistent location
  local HOST_KEY_FILE="$PERSIST_DIR/ssh_host_ed25519_key"
  sudo ssh-keygen -t ed25519 -N "" -f "$HOST_KEY_FILE" -C "$HOST" >/dev/null
  sudo chmod 600 "$HOST_KEY_FILE"
  sudo chmod 644 "$HOST_KEY_FILE.pub"
  log_success "SSH host key generated at $HOST_KEY_FILE"

  # Read keys
  local HOST_PUBLIC_KEY HOST_AGE_KEY
  HOST_PUBLIC_KEY=$(sudo cat "$HOST_KEY_FILE.pub")
  HOST_AGE_KEY=$(echo "$HOST_PUBLIC_KEY" | ssh-to-age)

  # === ADD TO SOPS ===
  log_info "Configuring sops for $HOST..."
  local SOPS_BACKUP
  SOPS_BACKUP=$(mktemp)
  TEMP_FILES+=("$SOPS_BACKUP")
  cp .sops.yaml "$SOPS_BACKUP"

  update_sops_yaml
  log_success "Updated .sops.yaml"

  # Get installer's age key for decryption (if available)
  log_info "Re-encrypting secrets..."
  local CURRENT_AGE_KEY
  CURRENT_AGE_KEY=$(mktemp)
  TEMP_FILES+=("$CURRENT_AGE_KEY")

  # Try to get age key from installer SSH key
  if [ -f /etc/ssh/ssh_host_ed25519_key ]; then
    sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key > "$CURRENT_AGE_KEY" 2>/dev/null || true
  fi

  # If we got a key, use it for re-encryption, otherwise just updatekeys with new host
  if [ -s "$CURRENT_AGE_KEY" ]; then
    if ! SOPS_AGE_KEY_FILE="$CURRENT_AGE_KEY" sops updatekeys secrets/secrets.yaml 2>/dev/null; then
      mv "$SOPS_BACKUP" .sops.yaml
      die "Failed to re-encrypt secrets!"
    fi
  else
    log_warn "Could not get installer age key, secrets may need manual re-encryption"
  fi
  log_success "Secrets updated"

  # === EXTRACT LUKS PASSWORD ===
  log_info "Extracting LUKS password..."
  local LUKS_PASSWORD_FILE="$MOUNT_POINT/tmp/secret.key"
  sudo mkdir -p "$MOUNT_POINT/tmp"

  if [ -s "$CURRENT_AGE_KEY" ]; then
    local LUKS_PASSWORD
    LUKS_PASSWORD=$(SOPS_AGE_KEY_FILE="$CURRENT_AGE_KEY" sops -d --extract '["luks_password"]' secrets/secrets.yaml 2>/dev/null) || die "Failed to decrypt LUKS password"
    echo -n "$LUKS_PASSWORD" | sudo tee "$LUKS_PASSWORD_FILE" >/dev/null
  else
    log_error "Cannot decrypt LUKS password without installer age key"
    log_info "Please provide the LUKS password manually"
    die "LUKS password extraction failed"
  fi

  sudo chmod 600 "$LUKS_PASSWORD_FILE"
  log_success "LUKS password extracted to $LUKS_PASSWORD_FILE"

  # === PARTITION DISKS ===
  log_warn "About to partition disks for $HOST - THIS WILL ERASE ALL DATA!"
  read -p "Continue? (yes/no): " -r
  if [ "$REPLY" != "yes" ]; then
    die "Installation cancelled"
  fi

  log_info "Partitioning disks with disko..."
  sudo nix run --extra-experimental-features 'nix-command flakes' \
    github:nix-community/disko -- \
    --mode disko \
    --flake "$FLAKE_DIR#$HOST" || die "Disk partitioning failed!"
  log_success "Disks partitioned"

  # === INSTALL NIXOS ===
  log_info "Installing NixOS..."
  sudo nixos-install \
    --flake "$FLAKE_DIR#$HOST" \
    --no-root-passwd || die "Installation failed!"

  log_success "Installation complete!"

  # === SUCCESS ===
  log_success "NixOS installed successfully as $HOST"
  echo
  log_info "Changes made:"
  echo "  - Added facter.json for $HOST"
  echo "  - Generated SSH host key in /mnt/persist/system/etc/ssh/"
  echo "  - Added age key to .sops.yaml"
  echo "  - Partitioned and formatted disks"
  echo "  - Installed NixOS to $MOUNT_POINT"
  echo
  log_info "Next steps:"
  echo "  1. Review and commit the changes (facter.json, .sops.yaml)"
  echo "  2. Reboot into the new system"
  echo "  3. After reboot, run 'nswitch' to apply any updates"
}

main "$@"
