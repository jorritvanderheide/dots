#!/usr/bin/env bash
# Rebuild and switch NixOS configuration
# Usage: nswitch [hostname]

# shellcheck source=lib/common.sh disable=SC1091
source "$(dirname "$0")/lib/common.sh"

main() {
  setup_error_handling

  # Check dependencies
  command -v nixos-rebuild >/dev/null 2>&1 || die "nixos-rebuild is not installed"
  command -v sudo >/dev/null 2>&1 || die "sudo is not installed"

  # Configuration
  local hostname
  hostname="$(get_hostname "$1")"

  local log_file
  log_file="$(setup_logging "nixos-switch")"

  local flake_ref=".#$hostname"

  # Show current changes
  show_jj_status

  # Execute rebuild
  log_info "Running: nixos-rebuild switch --flake $flake_ref"
  log_info "Logging to: $log_file"

  # shellcheck disable=SC2024
  if ! sudo nixos-rebuild switch --flake "$flake_ref" &> "$log_file"; then
    log_error "Rebuild failed!"
    echo
    log_error "Last 30 lines of log:"
    tail -n 30 "$log_file"
    echo
    log_error "Errors found:"
    grep --color=always -i "error" "$log_file" || true
    echo
    log_error "Full log at: $log_file"
    exit 1
  fi

  log_success "Rebuild completed successfully!"

  # Show generation info and package changes
  local gen_info nvd_output gen date time
  if gen_info="$(show_generation_info)"; then
    nvd_output="$(show_package_changes /run/current-system /nix/var/nix/profiles/system)"
    read -r gen date time <<<"$gen_info"
    jj_auto_commit "Generation $gen - $date $time" "$nvd_output"
  fi

  log_success "Done!"
}

main "$@"
