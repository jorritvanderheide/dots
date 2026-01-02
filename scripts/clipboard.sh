#!/usr/bin/env bash
# Show clipboard history in fuzzel and paste selection
# Usage: clipboard.sh

# shellcheck source=lib/common.sh disable=SC1091
source "$(dirname "$0")/lib/common.sh"

main() {
  setup_error_handling

  # Check dependencies
  command -v fuzzel >/dev/null 2>&1 || die "fuzzel is not installed"
  command -v cliphist >/dev/null 2>&1 || die "cliphist is not installed"
  command -v wl-copy >/dev/null 2>&1 || die "wl-copy is not installed"
  command -v app2unit >/dev/null 2>&1 || die "app2unit is not installed"

  # Close fuzzel if already running, otherwise show clipboard history
  if pgrep -x fuzzel >/dev/null; then
    pkill fuzzel
  else
    cliphist list \
      | app2unit a: -- fuzzel -d \
      | cliphist decode \
      | wl-copy
  fi
}

main "$@"
