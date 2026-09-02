#!/usr/bin/env bash
# Adjust screen brightness
# Usage: brightness.sh {up|down}

# shellcheck source=lib/common.sh disable=SC1091
source "$(dirname "$0")/lib/common.sh"

readonly STEP="5%"

main() {
  setup_error_handling

  # Check dependencies
  command -v brightnessctl >/dev/null 2>&1 || die "brightnessctl is not installed"

  case "${1:-}" in
  up)
    brightnessctl set "$STEP+" >/dev/null
    ;;
  down)
    brightnessctl set "$STEP-" >/dev/null
    ;;
  *)
    log_error "Usage: $(basename "$0") {up|down}"
    exit 1
    ;;
  esac
}

main "$@"
