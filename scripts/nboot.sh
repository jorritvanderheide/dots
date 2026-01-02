#!/usr/bin/env bash
# Rebuild NixOS configuration for next boot
# Usage: nboot [hostname]

# shellcheck source=lib/common.sh disable=SC1091
source "$(dirname "$0")/lib/common.sh"

main() {
  setup_error_handling

  # Check dependencies
  command -v nixos-rebuild >/dev/null 2>&1 || die "nixos-rebuild is not installed"
  command -v sudo >/dev/null 2>&1 || die "sudo is not installed"

  local hostname
  hostname="$(get_hostname "$1")"

  local log_file
  log_file="$(setup_logging "nixos-boot")"

  log_info "Rebuilding NixOS configuration for $hostname (boot only)..."

  # shellcheck disable=SC2024
  if ! sudo nixos-rebuild boot --flake ".#$hostname" &> "$log_file"; then
    log_error "Rebuild failed! Check $log_file"
    tail -n 20 "$log_file"
    exit 1
  fi

  log_success "Done! Changes will apply on next boot."
}

main "$@"
