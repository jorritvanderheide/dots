#!/usr/bin/env bash
# Build NixOS configuration without switching
# Usage: nbuild [hostname]

# shellcheck source=lib/common.sh disable=SC1091
source "$(dirname "$0")/lib/common.sh"

main() {
  setup_error_handling

  # Check dependencies
  command -v nixos-rebuild >/dev/null 2>&1 || die "nixos-rebuild is not installed"

  local hostname
  hostname="$(get_hostname "$1")"

  local log_file
  log_file="$(setup_logging "nixos-build")"

  log_info "Building NixOS configuration for $hostname..."

  if ! nixos-rebuild build --flake ".#$hostname" &> "$log_file"; then
    log_error "Build failed! Check $log_file"
    tail -n 30 "$log_file"
    echo
    grep --color=always -i "error" "$log_file" || true
    exit 1
  fi

  log_success "Build successful!"
  log_info "Result: $(readlink -f result)"

  # Show what would change
  show_package_changes /run/current-system ./result
}

main "$@"
