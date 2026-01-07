#!/usr/bin/env bash
# Edit sops secrets using the system SSH key
# Usage: sops-edit.sh [sops arguments]

# shellcheck source=lib/common.sh disable=SC1091
source "$(dirname "$0")/lib/common.sh"

main() {
  setup_error_handling

  # Check dependencies
  command -v sops >/dev/null 2>&1 || die "sops is not installed"
  command -v ssh-to-age >/dev/null 2>&1 || die "ssh-to-age is not installed"
  command -v nano >/dev/null 2>&1 || die "nano is not installed"

  # Convert SSH key to age key
  local ssh_key_path="/etc/ssh/ssh_host_ed25519_key"
  local age_key
  if ! age_key=$(ssh-to-age -private-key -i "$ssh_key_path" 2>/dev/null); then
    die "Could not read system SSH key. Make sure you're in the 'sops-users' group."
  fi

  export SOPS_AGE_KEY="$age_key"

  # Execute sops with provided arguments
  exec sops "$@"
}

main "$@"