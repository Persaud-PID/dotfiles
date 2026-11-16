#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
brew_bundle Brewfile.neovim
nvim --headless -u NONE -i NONE '+lua if vim.fn.has("nvim-0.12") == 0 then vim.cmd("cquit 1") end' +qa \
  || die "catpaladin/nvim-config requires Neovim 0.12+."
command_exists cc || die "Install Xcode Command Line Tools with xcode-select --install."
if ! command_exists node; then
  load_nvm
  set +u
  nvm use --silent default
  set -u
fi
command_exists node || { warn "Node is required by language tools. Run scripts/typescript-dev.sh."; exit 1; }
"$REPO_DIR/setup.sh" "$@"
# Lazy rewrites the lock for disabled optional plugins and its stable bootstrap.
# Preserve the user's exact lockfile while restoring/installing the editor tools.
lock="$REPO_DIR/nvim/.config/nvim/lazy-lock.json"
saved_lock="$(mktemp)"
cp -p "$lock" "$saved_lock"
trap 'cp -p "$saved_lock" "$lock"; rm -f "$saved_lock"' EXIT
nvim --headless '+Lazy! restore' +qa
nvim --headless '+MasonToolsInstallSync' +qa
log "Neovim config linked. Start nvim; use :checkhealth and :Mason for language tools."
