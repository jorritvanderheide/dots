#!/usr/bin/env bash
# Install a NixOS host remotely using nixos-anywhere
# Generates SSH host keys, configures sops, and installs in one go
#
# Usage: install-host <hostname> <target-ip>

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info() { echo -e "${BLUE}==>${NC} $*"; }
log_success() { echo -e "${GREEN}==>${NC} $*"; }
log_warn() { echo -e "${YELLOW}==>${NC} $*"; }
die() { echo -e "${RED}==>${NC} $*"; exit 1; }

readonly FLAKE_DIR="${INSTALL_HOST_FLAKE_DIR:-$(pwd)}"

main() {
  local tmpdir
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT

  # Disable SSH agent to prevent key enumeration issues with nixos-anywhere
  unset SSH_AUTH_SOCK

  local hostname="${1:-}"
  local target="${2:-}"

  [[ -n "$hostname" ]] || die "Usage: install-host <hostname> <target-ip>"
  [[ -n "$target" ]] || die "Usage: install-host <hostname> <target-ip>"

  # Derive sops age key from system SSH host key
  if [[ -z "${SOPS_AGE_KEY:-}" ]]; then
    local ssh_key_path="/etc/ssh/ssh_host_ed25519_key"
    log_info "Deriving sops age key from ${ssh_key_path}..."
    SOPS_AGE_KEY=$(ssh-to-age -private-key -i "$ssh_key_path" 2>/dev/null) \
      || die "Could not read system SSH key. Make sure you're in the 'sops-users' group."
    export SOPS_AGE_KEY
  fi

  # Prompt for target SSH password early (needed for facter and nixos-anywhere)
  if [[ -z "${SSHPASS:-}" ]]; then
    log_info "Enter SSH password for nixos@${target}:"
    read -rs SSHPASS
    export SSHPASS
  fi

  # Gather hardware facts from target machine
  local facter_path="${FLAKE_DIR}/modules/hosts/${hostname}/facter.json"
  log_info "Gathering hardware facts from ${target}..."
  sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "nixos@${target}" "sudo nix run --extra-experimental-features 'nix-command flakes' nixpkgs#nixos-facter 2>/dev/null" \
    > "$facter_path" \
    || die "Failed to gather facter data from target"
  [[ -s "$facter_path" ]] || die "Facter output is empty — is nixos-facter available on the target?"
  log_success "Saved facter.json to ${facter_path}"

  # Verify the flake has this host configuration
  nix eval "${FLAKE_DIR}#nixosConfigurations.${hostname}" --apply 'x: true' 2>/dev/null \
    || die "No nixosConfigurations.${hostname} found in flake"

  # Generate SSH host key for the new machine
  log_info "Generating SSH host key for ${hostname}..."
  ssh-keygen -t ed25519 -f "${tmpdir}/ssh_host_ed25519_key" -N "" -C "root@${hostname}" -q

  # Derive age public key for sops encryption
  log_info "Deriving age key from host key..."
  local age_pubkey
  age_pubkey=$(ssh-to-age < "${tmpdir}/ssh_host_ed25519_key.pub")
  log_info "Age public key: ${age_pubkey}"

  # Update .sops.yaml with the new host's key
  local sops_yaml="${FLAKE_DIR}/.sops.yaml"
  if grep -q "&root_${hostname}" "$sops_yaml"; then
    log_warn "Key anchor &root_${hostname} already exists in .sops.yaml, replacing with new key..."
    sed -i "s|&root_${hostname} .*|\&root_${hostname} ${age_pubkey}|" "$sops_yaml"
  else
    log_info "Adding ${hostname} key to .sops.yaml..."

    # Add key anchor before creation_rules
    sed -i "/^creation_rules:/i\\  - \&root_${hostname} ${age_pubkey}" "$sops_yaml"

    # Add key reference to system-wide secrets (after the last existing age key reference)
    sed -i "/path_regex: secrets\/secrets/,/^  -/ {
      /\*root_/ { N; /key_groups/!{ s/\n/\n          - *root_${hostname}\n/; } }
    }" "$sops_yaml"
  fi

  log_success "Updated .sops.yaml"

  # Re-encrypt all secrets files for the new key
  log_info "Re-encrypting secrets..."
  local ssh_key_path="/etc/ssh/ssh_host_ed25519_key"
  local sops_age_key
  sops_age_key=$(ssh-to-age -private-key -i "$ssh_key_path" 2>/dev/null)

  for secrets_file in "${FLAKE_DIR}"/secrets/**/*.yaml "${FLAKE_DIR}/secrets/secrets.yaml"; do
    if [ -f "$secrets_file" ]; then
      log_info "Re-encrypting $(basename "$secrets_file")..."
      SOPS_AGE_KEY="$sops_age_key" sops updatekeys -y "$secrets_file"
    fi
  done

  # Prepare extra files (SSH host key for persistence)
  log_info "Preparing extra files..."
  local extra_dir="${tmpdir}/extra"
  mkdir -p "${extra_dir}/persist/system/etc/ssh"
  mkdir -p "${extra_dir}/persist/system/var/lib/nixos"
  cp "${tmpdir}/ssh_host_ed25519_key" "${extra_dir}/persist/system/etc/ssh/"
  cp "${tmpdir}/ssh_host_ed25519_key.pub" "${extra_dir}/persist/system/etc/ssh/"
  chmod 600 "${extra_dir}/persist/system/etc/ssh/ssh_host_ed25519_key"
  chmod 644 "${extra_dir}/persist/system/etc/ssh/ssh_host_ed25519_key.pub"

  # Decrypt LUKS password from sops
  log_info "Decrypting LUKS password from sops..."
  local luks_file="${tmpdir}/luks.key"
  sops -d --extract '["luks_password"]' "${FLAKE_DIR}/secrets/secrets.yaml" > "$luks_file"

  # Run nixos-anywhere
  log_info "Installing ${hostname} to ${target}..."
  nixos-anywhere \
    --env-password \
    --flake "${FLAKE_DIR}#${hostname}" \
    --extra-files "${extra_dir}" \
    --disk-encryption-keys /tmp/secret.key "$luks_file" \
    "nixos@${target}"

  log_success "Installation complete!"
  log_info "You can now SSH in: ssh nixos@${target}"
}

main "$@"
