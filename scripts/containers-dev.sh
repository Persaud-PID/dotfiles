#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
brew_bundle Brewfile.containers
log "Colima/Docker installed. No VM or daemon was started."
