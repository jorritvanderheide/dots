#!/usr/bin/env bash
# Adjust system volume
# Usage: volume.sh {up|down|mute}

# shellcheck source=lib/common.sh disable=SC1091
source "$(dirname "$0")/lib/common.sh"

readonly STEP="5%"
readonly SINK="@DEFAULT_AUDIO_SINK@"
readonly UNMUTE_DELAY="0.1"

is_muted() {
  wpctl get-volume "$SINK" | grep -q "\[MUTED\]"
}

unmute_if_needed() {
  if is_muted; then
    wpctl set-mute "$SINK" 0
    sleep "$UNMUTE_DELAY"
  fi
}

main() {
  setup_error_handling

  # Check dependencies
  command -v wpctl >/dev/null 2>&1 || die "wpctl is not installed"

  case "${1:-}" in
    up)
      unmute_if_needed
      wpctl set-volume "$SINK" "${STEP}+" --limit 1
      ;;
    down)
      unmute_if_needed
      wpctl set-volume "$SINK" "${STEP}-"
      ;;
    mute)
      wpctl set-mute "$SINK" toggle
      ;;
    *)
      log_error "Usage: $(basename "$0") {up|down|mute}"
      exit 1
      ;;
  esac
}

main "$@"
