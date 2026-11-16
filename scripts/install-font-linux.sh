#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
is_macos && die "Use the font casks on macOS."
apt_install curl unzip fontconfig
fonts_dir="$HOME/.local/share/fonts"
mkdir -p "$fonts_dir"
temp="$(mktemp -d)"
trap 'rm -rf "$temp"' EXIT
for font in Hack Noto; do
  curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/$font.zip" -o "$temp/$font.zip"
  unzip -oq "$temp/$font.zip" -d "$fonts_dir"
done
fc-cache -f "$fonts_dir"
