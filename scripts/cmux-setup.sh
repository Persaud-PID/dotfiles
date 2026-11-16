#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
install_nerd_font font-meslo-lg-nerd-font MesloLG
brew_bundle Brewfile.apps
cmux="$(command -v cmux || true)"
[[ -n "$cmux" ]] || cmux=/Applications/cmux.app/Contents/Resources/bin/cmux
[[ -x "$cmux" ]] || die "cmux CLI unavailable after installation."
"$cmux" hooks setup || warn "Rerun cmux hooks setup after installing agent CLIs."
if ! command_exists npx; then
  "$REPO_DIR/scripts/typescript-dev.sh"
  load_nvm
fi
npx --yes skills add manaflow-ai/cmux -g -y || warn "cmux skills installation failed."
"$cmux" reload-config || warn "Run cmux reload-config inside cmux to apply terminal preferences."
