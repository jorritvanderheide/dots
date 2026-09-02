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
