#!/usr/bin/env bash
# Font migration uses a fake Homebrew; no real fonts or packages are changed.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_DIR/scripts/lib/common.sh"
root="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-font-test.XXXXXX")"
trap 'rm -rf "$root"' EXIT
export HOME="$root/home with spaces"
mkdir -p "$HOME/Library/Fonts"
calls="$root/brew-calls"
ensure_homebrew() { :; }
managed=0
fail_install=0
partial_install=0
brew() {
  printf '%s\n' "$*" >> "$calls"
  case "$*" in
    'list --cask font-meslo-lg-nerd-font') [[ "$managed" == 1 ]] ;;
    'install --cask font-meslo-lg-nerd-font')
      if [[ "$fail_install" == 1 ]]; then
        if [[ "$partial_install" == 1 ]]; then
          printf 'partial new font\n' > "$HOME/Library/Fonts/MesloLGLDZNerdFont-Bold.ttf"
        fi
        return 1
      fi
      [[ ! -e "$HOME/Library/Fonts/MesloLGLDZNerdFont-Bold.ttf" ]] || return 1
      printf 'new font\n' > "$HOME/Library/Fonts/MesloLGLDZNerdFont-Bold.ttf"
      managed=1 ;;
    *) echo "Unexpected Homebrew command: $*" >&2; return 1 ;;
  esac
}

printf 'old bold\n' > "$HOME/Library/Fonts/MesloLGLDZNerdFont-Bold.ttf"
printf 'old mono\n' > "$HOME/Library/Fonts/MesloLGLNerdFontMono-Regular.ttf"
printf 'other font\n' > "$HOME/Library/Fonts/HackNerdFont-Regular.ttf"
printf 'non-Nerd Meslo\n' > "$HOME/Library/Fonts/MesloLG-Regular.ttf"
printf 'linked font\n' > "$root/shared.ttf"
ln -s "$root/shared.ttf" "$HOME/Library/Fonts/MesloLGLNerdFontPropo-Italic.ttf"
install_nerd_font font-meslo-lg-nerd-font MesloLG
backup="$(find "$HOME" -maxdepth 1 -type d -name '.dotfiles_font_backup_*')"
[[ -n "$backup" ]]
[[ "$(cat "$backup/MesloLGLDZNerdFont-Bold.ttf")" == 'old bold' ]]
[[ "$(cat "$backup/MesloLGLNerdFontMono-Regular.ttf")" == 'old mono' ]]
[[ -L "$backup/MesloLGLNerdFontPropo-Italic.ttf" ]]
[[ "$(cat "$root/shared.ttf")" == 'linked font' ]]
[[ "$(cat "$HOME/Library/Fonts/MesloLGLDZNerdFont-Bold.ttf")" == 'new font' ]]
[[ "$(cat "$HOME/Library/Fonts/HackNerdFont-Regular.ttf")" == 'other font' ]]
[[ "$(cat "$HOME/Library/Fonts/MesloLG-Regular.ttf")" == 'non-Nerd Meslo' ]]
install_nerd_font font-meslo-lg-nerd-font MesloLG
[[ "$(command grep -c '^install ' "$calls")" == 1 ]]

export HOME="$root/managed-home"
mkdir -p "$HOME/Library/Fonts"
printf 'managed font\n' > "$HOME/Library/Fonts/MesloLGLDZNerdFont-Bold.ttf"
install_nerd_font font-meslo-lg-nerd-font MesloLG
[[ "$(cat "$HOME/Library/Fonts/MesloLGLDZNerdFont-Bold.ttf")" == 'managed font' ]]
[[ -z "$(find "$HOME" -maxdepth 1 -type d -name '.dotfiles_font_backup_*')" ]]

export HOME="$root/failed-home"
mkdir -p "$HOME/Library/Fonts"
printf 'original font\n' > "$HOME/Library/Fonts/MesloLGLDZNerdFont-Bold.ttf"
managed=0
fail_install=1
if install_nerd_font font-meslo-lg-nerd-font MesloLG; then
  echo 'FAIL: cask failure was ignored' >&2
  exit 1
fi
[[ "$(cat "$HOME/Library/Fonts/MesloLGLDZNerdFont-Bold.ttf")" == 'original font' ]]

export HOME="$root/partial-home"
mkdir -p "$HOME/Library/Fonts"
printf 'original font\n' > "$HOME/Library/Fonts/MesloLGLDZNerdFont-Bold.ttf"
partial_install=1
if install_nerd_font font-meslo-lg-nerd-font MesloLG; then
  echo 'FAIL: partial cask failure was ignored' >&2
  exit 1
fi
backup="$(find "$HOME" -maxdepth 1 -type d -name '.dotfiles_font_backup_*')"
[[ "$(cat "$backup/MesloLGLDZNerdFont-Bold.ttf")" == 'original font' ]]
[[ "$(cat "$HOME/Library/Fonts/MesloLGLDZNerdFont-Bold.ttf")" == 'partial new font' ]]
echo 'PASS: font backups, managed/repeat skips, family isolation and failure recovery'
