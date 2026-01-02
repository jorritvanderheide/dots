#!/usr/bin/env bash
# Check flake outputs for errors
# Usage: ncheck

# shellcheck source=lib/common.sh disable=SC1091
source "$(dirname "$0")/lib/common.sh"

main() {
  setup_error_handling

  # Check dependencies
  command -v nix >/dev/null 2>&1 || die "nix is not installed"

  log_info "Checking flake outputs..."
  nix flake check --no-build

  log_success "Flake check passed!"
}

main "$@"
