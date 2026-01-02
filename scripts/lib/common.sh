#!/usr/bin/env bash
# Common library for NixOS management scripts
# Provides logging, error handling, and utility functions

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}==>${NC} $*"; }
log_success() { echo -e "${GREEN}==>${NC} $*"; }
log_warn() { echo -e "${YELLOW}==>${NC} $*"; }
log_error() { echo -e "${RED}==>${NC} $*"; }

# Exit with error message
die() {
  log_error "$*"
  exit 1
}

# Configure strict error handling
setup_error_handling() {
  set -euo pipefail
}

# Get flake directory (where flake.nix lives)
get_flake_dir() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

# Get hostname with optional override
get_hostname() {
  local override="${1:-}"
  echo "${override:-$(hostname)}"
}

# Setup logging directory and return log file path
setup_logging() {
  local script_name="$1"
  local flake_dir
  flake_dir="$(get_flake_dir)"

  local log_dir="$flake_dir/logs"
  local log_file="$log_dir/${script_name}.log"

  mkdir -p "$log_dir"
  echo "$log_file"
}

# Display jujutsu status and pending changes
show_jj_status() {
  if [[ ! -d .jj ]]; then
    return
  fi

  local status_output
  status_output=$(jj status 2>/dev/null || true)

  if [[ -n "$status_output" ]]; then
    log_warn "Uncommitted changes detected:"
    echo "$status_output"
    echo
  fi

  local diff_output
  diff_output=$(jj diff --stat 2>/dev/null || true)

  if [[ -n "$diff_output" ]]; then
    log_warn "Changes to be applied:"
    echo "$diff_output"
    echo
  fi
}

# Auto-commit changes with jujutsu
jj_auto_commit() {
  local message="$1"
  local nvd_output="${2:-}"

  if [[ ! -d .jj ]]; then
    return
  fi

  local diff_output
  diff_output=$(jj diff 2>/dev/null || true)

  if [[ -z "$diff_output" ]]; then
    log_info "No changes to commit"
    return
  fi

  local commit_msg="$message"
  if [[ -n "$nvd_output" ]]; then
    commit_msg="$commit_msg

$nvd_output"
  fi

  log_info "Committing changes"
  jj commit -m "$commit_msg"
  log_success "Changes committed"
}

# Display current NixOS generation information
show_generation_info() {
  local gen_line
  gen_line=$(nixos-rebuild list-generations | awk '$NF=="True"' 2>/dev/null || true)

  if [[ -z "$gen_line" ]]; then
    log_warn "Could not determine current generation"
    return 1
  fi

  local gen date time
  read -r gen date time _ <<<"$gen_line"
  log_success "Current generation: $gen ($date $time)"

  echo "$gen $date $time"
}

# Display package changes between two system generations
show_package_changes() {
  local old_system="$1"
  local new_system="$2"

  if ! command -v nvd &>/dev/null; then
    return
  fi

  log_info "Package changes:"
  nvd diff "$old_system" "$new_system" 2>/dev/null || true
}
