#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
install_nerd_font font-meslo-lg-nerd-font MesloLG
brew_bundle Brewfile.apps
# Let held keys repeat instead of opening the macOS accent picker.
defaults write com.cmuxterm.app ApplePressAndHoldEnabled -bool false
cmux="$(command -v cmux || true)"
[[ -n "$cmux" ]] || cmux=/Applications/cmux.app/Contents/Resources/bin/cmux
[[ -x "$cmux" ]] || die "cmux CLI unavailable after installation."
if ! command_exists npx; then
  "$REPO_DIR/scripts/typescript-dev.sh"
fi
use_default_node
"$REPO_DIR/scripts/agents-setup.sh"
# Claude is wrapper-managed; Devin and Ollama have no dedicated setup target.
for agent in pi gemini; do
  "$cmux" hooks setup --agent "$agent" --yes || warn "Rerun cmux hooks setup --agent $agent."
done
npx --yes skills add manaflow-ai/cmux -g -y || warn "cmux skills installation failed."
"$cmux" reload-config || warn "Run cmux reload-config inside cmux to apply terminal preferences."
