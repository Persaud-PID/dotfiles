#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
if is_macos; then
  brew_bundle Brewfile
else
  apt_install build-essential ca-certificates curl git stow zsh eza ripgrep bat fd-find fzf jq unzip pkg-config libssl-dev
  mkdir -p "$HOME/.local/bin"
  command_exists bat || ln -s "$(command -v batcat)" "$HOME/.local/bin/bat"
  command_exists fd || ln -s "$(command -v fdfind)" "$HOME/.local/bin/fd"
  export PATH="$HOME/.local/bin:$PATH"
  if ! command_exists starship; then
    download_run https://starship.rs/install.sh sh --yes --bin-dir "$HOME/.local/bin"
  fi
  if ! command_exists jless; then
    ensure_rust
    cargo install jless --locked
  fi
fi
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
fi
if ! is_macos; then
  for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    destination="$HOME/.oh-my-zsh/custom/plugins/$plugin"
    [[ -d "$destination" ]] || git clone --depth=1 "https://github.com/zsh-users/$plugin.git" "$destination"
  done
  log "Linux core tools ready. Ubuntu 24.04+ or a recent Debian with eza is required."
  exit 0
fi

# Keep pinentry configuration private; do not replace the user's other options.
mkdir -p "$HOME/.gnupg"
chmod 700 "$HOME/.gnupg"
conf="$HOME/.gnupg/gpg-agent.conf"
pinentry="pinentry-program $(brew --prefix)/bin/pinentry-mac"
if ! command grep -Fxq "$pinentry" "$conf" 2>/dev/null; then
  [[ ! -f "$conf" ]] || cp -p "$conf" "$conf.backup.$(date +%Y%m%d%H%M%S).$$"
  printf '\n%s\n' "$pinentry" >> "$conf"
  chmod 600 "$conf"
fi
log "Core tools ready. Run ./setup.sh to link dotfiles."
log "Login shell is unchanged. If needed: chsh -s $(brew --prefix)/bin/zsh"
