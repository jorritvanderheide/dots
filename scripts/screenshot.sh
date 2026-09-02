#!/usr/bin/env bash
# Take screenshot of selected area and copy to clipboard
# Usage: screenshot.sh

# shellcheck source=lib/common.sh disable=SC1091
source "$(dirname "$0")/lib/common.sh"

main() {
  setup_error_handling

  # Check dependencies
  command -v slurp >/dev/null 2>&1 || die "slurp is not installed"
  command -v grim >/dev/null 2>&1 || die "grim is not installed"
  command -v wl-copy >/dev/null 2>&1 || die "wl-copy is not installed"

  local selection
  if ! selection=$(slurp); then
    log_error "Screenshot cancelled"
    exit 1
  fi

  if ! grim -g "$selection" - | wl-copy --type image/png; then
    log_error "Failed to capture screenshot"
    exit 1
  fi
}

main "$@"
