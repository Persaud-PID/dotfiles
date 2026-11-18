#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
if ! is_macos; then apt_install build-essential curl pkg-config libssl-dev; fi
ensure_rust
rustup default stable
command_exists rg || cargo install ripgrep --locked
"$REPO_DIR/scripts/python-dev.sh"
"$REPO_DIR/scripts/rye-dev.sh"
log "Rust/rustup/Cargo and the Python companion tools are ready."
