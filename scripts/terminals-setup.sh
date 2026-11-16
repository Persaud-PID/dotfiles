#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
if is_macos; then
  install_nerd_font font-hack-nerd-font Hack
  brew_bundle Brewfile.terminals
  if ! command_exists alacritty; then
    ensure_rust
    cargo install alacritty --locked
  fi
else
  apt_install tmux alacritty diffutils
  "$REPO_DIR/scripts/install-font-linux.sh"
fi
mkdir -p "$HOME/.tmux/plugins"
for plugin in tpm tmux-sensible tmux-resurrect; do
  if [[ ! -d "$HOME/.tmux/plugins/$plugin" ]]; then
    git clone --depth=1 "https://github.com/tmux-plugins/$plugin.git" "$HOME/.tmux/plugins/$plugin"
  fi
done
log "tmux, TPM plugins, Alacritty and Hack Nerd Font ready. cmux remains your default terminal."
