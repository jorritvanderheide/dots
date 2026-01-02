#!/usr/bin/env bash
# Deploy NixOS to a new host using nixos-anywhere
# Usage: ndeploy <hostname> <ip>
# Example: ndeploy myHost 192.168.1.100

# shellcheck source=lib/common.sh disable=SC1091
source "$(dirname "$0")/lib/common.sh"

# Configuration
readonly SSH_TIMEOUT="10"
readonly SSH_ATTEMPTS="3"
readonly DEFAULT_USER="nixos"
readonly DEFAULT_PASSWORD="nixos"

# SSH options for installer
readonly SSH_OPTS=(
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o ConnectTimeout="$SSH_TIMEOUT"
  -o ConnectionAttempts="$SSH_ATTEMPTS"
)

# Helper functions
get_age_key() {
  sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key 2>/dev/null || die "Failed to convert SSH key to age key"
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
  command -v nixos-anywhere >/dev/null 2>&1 || die "nixos-anywhere is not installed"
  command -v ssh-keygen >/dev/null 2>&1 || die "ssh-keygen is not installed"
  command -v ssh-to-age >/dev/null 2>&1 || die "ssh-to-age is not installed"
  command -v sops >/dev/null 2>&1 || die "sops is not installed"
  command -v jq >/dev/null 2>&1 || die "jq is not installed"

  # === USAGE ===
  [ $# -lt 2 ] && die "Usage: ndeploy <hostname> <ip>
Example: ndeploy myHost 192.168.1.100"

  # === SETUP ===
  local HOST="$1"
  local TARGET_IP="$2"
  local TARGET="${DEFAULT_USER}@$TARGET_IP"
  local HOST_DIR="modules/hosts/$HOST"

  log_info "Deploying $HOST to $TARGET_IP"

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

  # === SSH ACCESS SETUP ===
  local USE_PASSWORD=true
  local PUBKEY
  PUBKEY=$(cat ~/.ssh/id_ed25519.pub 2>/dev/null || cat ~/.ssh/id_rsa.pub 2>/dev/null || true)

  if [ -n "$PUBKEY" ]; then
    log_info "Copying SSH key to target..."
    local SETUP_CMD="mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$PUBKEY' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
    # shellcheck disable=SC1007
    if SSH_AUTH_SOCK= sshpass -p "$DEFAULT_PASSWORD" ssh "${SSH_OPTS[@]}" -o PubkeyAuthentication=no -o PreferredAuthentications=password "$TARGET" "$SETUP_CMD" 2>/dev/null; then
      USE_PASSWORD=false
    fi
  fi

  # === RUN FACTER ===
  log_info "Running nixos-facter on target..."
  local FACTER_CMD="sudo nix run --extra-experimental-features 'nix-command flakes' nixpkgs#nixos-facter -- -o /tmp/facter.json && sudo cat /tmp/facter.json"

  if [ "$USE_PASSWORD" = true ]; then
    # shellcheck disable=SC1007
    SSH_AUTH_SOCK= sshpass -p "$DEFAULT_PASSWORD" ssh "${SSH_OPTS[@]}" -o PubkeyAuthentication=no -o PreferredAuthentications=password "$TARGET" "$FACTER_CMD" > "$HOST_DIR/facter.json"
  else
    ssh "${SSH_OPTS[@]}" -o IdentitiesOnly=yes "$TARGET" "$FACTER_CMD" > "$HOST_DIR/facter.json"
  fi

  jq empty "$HOST_DIR/facter.json" 2>/dev/null || die "facter.json is not valid JSON!"
  log_success "Saved facter.json to $HOST_DIR/"

  # === GENERATE SSH HOST KEY ===
  log_info "Generating SSH host key for $HOST..."
  local EXTRA_FILES_DIR
  EXTRA_FILES_DIR=$(mktemp -d)
  TEMP_FILES+=("$EXTRA_FILES_DIR")

  # Create persist directory structure
  mkdir -p "$EXTRA_FILES_DIR/persist/system/etc/ssh" \
    "$EXTRA_FILES_DIR/persist/system/var/"{log,lib/{nixos,systemd}} \
    "$EXTRA_FILES_DIR/persist/home"
  chmod 755 "$EXTRA_FILES_DIR/persist/home"

  # Generate SSH host keys in persistent location
  local HOST_KEY_FILE="$EXTRA_FILES_DIR/persist/system/etc/ssh/ssh_host_ed25519_key"
  ssh-keygen -t ed25519 -N "" -f "$HOST_KEY_FILE" -C "$HOST" >/dev/null
  chmod 600 "$HOST_KEY_FILE"
  chmod 644 "$HOST_KEY_FILE.pub"
  log_success "SSH host key generated"

  # Read keys once
  local HOST_PUBLIC_KEY HOST_AGE_KEY
  HOST_PUBLIC_KEY=$(cat "$HOST_KEY_FILE.pub")
  HOST_AGE_KEY=$(echo "$HOST_PUBLIC_KEY" | ssh-to-age)

  # === ADD TO SOPS ===
  log_info "Configuring sops for $HOST..."
  local SOPS_BACKUP
  SOPS_BACKUP=$(mktemp)
  TEMP_FILES+=("$SOPS_BACKUP")
  cp .sops.yaml "$SOPS_BACKUP"

  update_sops_yaml
  log_success "Updated .sops.yaml"

  # Get current system's age key for decryption
  log_info "Re-encrypting secrets..."
  local CURRENT_AGE_KEY
  CURRENT_AGE_KEY=$(mktemp)
  TEMP_FILES+=("$CURRENT_AGE_KEY")
  get_age_key > "$CURRENT_AGE_KEY"

  if ! SOPS_AGE_KEY_FILE="$CURRENT_AGE_KEY" sops updatekeys secrets/secrets.yaml 2>/dev/null; then
    mv "$SOPS_BACKUP" .sops.yaml
    die "Failed to re-encrypt secrets!"
  fi
  log_success "Secrets re-encrypted"

  # === EXTRACT LUKS PASSWORD ===
  log_info "Extracting LUKS password..."
  local LUKS_PASSWORD_FILE
  LUKS_PASSWORD_FILE=$(mktemp)
  TEMP_FILES+=("$LUKS_PASSWORD_FILE")

  if [ -f /run/secrets/luks_password ]; then
    # shellcheck disable=SC2024
    sudo cat /run/secrets/luks_password > "$LUKS_PASSWORD_FILE"
  else
    local LUKS_PASSWORD
    LUKS_PASSWORD=$(SOPS_AGE_KEY_FILE="$CURRENT_AGE_KEY" sops -d --extract '["luks_password"]' secrets/secrets.yaml 2>/dev/null) || die "Failed to decrypt LUKS password"
    echo -n "$LUKS_PASSWORD" > "$LUKS_PASSWORD_FILE"
  fi
  [ -s "$LUKS_PASSWORD_FILE" ] || die "LUKS password file is empty!"
  log_success "LUKS password extracted"

  # === DEPLOY ===
  log_info "Deploying NixOS to $TARGET..."
  local DEPLOY_ARGS=(
    --extra-files "$EXTRA_FILES_DIR"
    --disk-encryption-keys /tmp/secret.key "$LUKS_PASSWORD_FILE"
    --flake ".#$HOST"
  )

  if [ "$USE_PASSWORD" = true ]; then
    # shellcheck disable=SC1007
    SSH_AUTH_SOCK= SSHPASS="$DEFAULT_PASSWORD" nixos-anywhere "${DEPLOY_ARGS[@]}" --ssh-option "StrictHostKeyChecking=no" --ssh-option "UserKnownHostsFile=/dev/null" --env-password "$TARGET" || die "Deployment failed!"
  else
    nixos-anywhere "${DEPLOY_ARGS[@]}" --ssh-option "IdentitiesOnly=yes" --ssh-option "UserKnownHostsFile=/dev/null" "$TARGET" || die "Deployment failed!"
  fi

  log_success "Deployment complete!"

  # === UPDATE KNOWNHOSTS ===
  local CURRENT_HOST CURRENT_HOST_CONFIG
  CURRENT_HOST=$(hostname)
  CURRENT_HOST_CONFIG="modules/hosts/$CURRENT_HOST/configuration.nix"

  if [ -f "$CURRENT_HOST_CONFIG" ] && ! grep -q "ssh.knownHosts.\"$HOST\"" "$CURRENT_HOST_CONFIG"; then
    log_info "Adding $HOST to $CURRENT_HOST's knownHosts..."
    awk -v host="$HOST" -v ip="$TARGET_IP" -v key="$HOST_PUBLIC_KEY" '
      /^    };$/ && !inserted {
        print "      ssh.knownHosts.\"" host "\" = {"
        print "        publicKey = \"" key "\";"
        print "        hostNames = [ \"" host "\" \"" ip "\" ];"
        print "      };"
        print ""
        inserted=1
      }
      {print}
    ' "$CURRENT_HOST_CONFIG" > "$CURRENT_HOST_CONFIG.tmp"
    mv "$CURRENT_HOST_CONFIG.tmp" "$CURRENT_HOST_CONFIG"
    log_success "Added $HOST to knownHosts configuration"
  fi

  # === SUCCESS ===
  log_success "All done! Host $HOST deployed successfully"
  echo
  log_info "Changes made:"
  echo "  - Added facter.json for $HOST"
  echo "  - Generated and deployed SSH host key"
  echo "  - Added age key to .sops.yaml and re-encrypted secrets"
  echo "  - Updated knownHosts configuration"
  echo
  log_info "Next steps:"
  echo "  1. Review and commit the changes"
  echo "  2. Run 'nswitch' to apply the knownHosts configuration"
  echo "  3. SSH into the new host: ssh nixos@$TARGET_IP"
}

main "$@"
