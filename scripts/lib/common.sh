#!/usr/bin/env bash
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
log() { printf '==> %s\n' "$*"; }
warn() { printf 'Warning: %s\n' "$*" >&2; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
command_exists() { command -v "$1" >/dev/null 2>&1; }
is_macos() { [[ "$(uname -s)" == Darwin ]]; }
apt_install() {
  command_exists apt-get || die "Linux installers support Debian/Ubuntu with apt."
  if [[ "$EUID" == 0 ]]; then
    apt-get update
    apt-get install -y "$@"
  else
    sudo apt-get update
    sudo apt-get install -y "$@"
  fi
}
download_run() (
  local installer
  installer="$(mktemp)"
  trap 'rm -f "$installer"' EXIT
  curl --proto '=https' --tlsv1.2 -fsSL "$1" -o "$installer"
  local runner="$2"
  shift 2
  "$runner" "$installer" "$@"
)
ensure_rust() {
  if [[ ! -x "$HOME/.cargo/bin/rustup" ]]; then
    download_run https://sh.rustup.rs sh -y --no-modify-path
  fi
  export PATH="$HOME/.cargo/bin:$PATH"
}
require_macos() {
  [[ "$(uname -s)" == Darwin ]] || die "Provisioning is macOS-only; setup.sh can still link configs on other systems."
}
ensure_homebrew() {
  require_macos
  if ! command_exists brew; then
    if [[ -x /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    else
      local installer
      installer="$(mktemp)"
      curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer"
      /bin/bash "$installer"
      rm -f "$installer"
      if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      else
        eval "$(/usr/local/bin/brew shellenv)"
      fi
    fi
  fi
}
brew_bundle() {
  ensure_homebrew
  brew bundle install --no-upgrade --file="$REPO_DIR/brew/$1"
}
install_nerd_font() {
  local cask="$1" family="$2" font_dir="$HOME/Library/Fonts"
  local backup_dir="" font destination
  ensure_homebrew
  if brew list --cask "$cask" >/dev/null 2>&1; then return 0; fi
  [[ ! -L "$font_dir" ]] || die "Refusing to move fonts through a directory symlink: $font_dir"
  for font in "$font_dir/$family"*NerdFont*.ttf; do
    [[ -f "$font" || -L "$font" ]] || continue
    if [[ -z "$backup_dir" ]]; then
      backup_dir="$(mktemp -d "$HOME/.dotfiles_font_backup_$(date +%Y%m%d_%H%M%S).XXXXXX")"
      chmod 700 "$backup_dir"
      log "Existing $family Nerd Font backups: $backup_dir"
    fi
    mv "$font" "$backup_dir/" || return 1
  done
  if brew install --cask "$cask"; then return 0; fi
  if [[ -n "$backup_dir" ]]; then
    for font in "$backup_dir/"*; do
      [[ -e "$font" || -L "$font" ]] || continue
      destination="$font_dir/${font##*/}"
      if [[ ! -e "$destination" && ! -L "$destination" ]]; then
        mv "$font" "$destination" || warn "Could not restore font; retained at $font"
      else
        warn "Destination exists; original font retained at $font"
      fi
    done
  fi
  warn "Font installation failed: $cask. Original fonts restored where possible."
  return 1
}
load_nvm() {
  export NVM_DIR="${NVM_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/nvm}"
  [[ -d "$HOME/.nvm" ]] && export NVM_DIR="$HOME/.nvm"
  mkdir -p "$NVM_DIR"
  local script="$NVM_DIR/nvm.sh"
  if [[ ! -s "$script" ]] && command_exists brew; then
    script="$(brew --prefix nvm)/nvm.sh"
  fi
  [[ -s "$script" ]] || die "Cannot find nvm.sh; run scripts/typescript-dev.sh first."
  set +u
  # shellcheck source=/dev/null
  source "$script"
  set -u
}
