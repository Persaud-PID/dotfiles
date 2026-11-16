#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
brew_bundle Brewfile.neovim
nvim --headless -u NONE -i NONE '+lua if vim.fn.has("nvim-0.12") == 0 then vim.cmd("cquit 1") end' +qa \
  || die "The Neovim configuration requires Neovim 0.12+."
"$REPO_DIR/setup.sh" "$@"
log "Neovim and system dependencies ready. Your Neovim config manages plugins and language tools."
