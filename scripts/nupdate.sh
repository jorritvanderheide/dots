#!/usr/bin/env bash
# Update flake inputs
# Usage: nupdate

# shellcheck source=lib/common.sh disable=SC1091
source "$(dirname "$0")/lib/common.sh"

main() {
  setup_error_handling

  # Check dependencies
  command -v nix >/dev/null 2>&1 || die "nix is not installed"

  log_info "Updating flake inputs..."
  nix flake update

  log_success "Flake inputs updated!"
  log_info "Run 'nswitch' to apply changes."
}

main "$@"
