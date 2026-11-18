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
# The skills CLI treats any leftover config folder as an installed agent, so name the real ones.
export PATH="$HOME/.local/bin:$PATH"
skill_agents=()
while IFS= read -r agent; do skill_agents+=("$agent"); done < <(skills_agents)
log "Installing cmux skills for: ${skill_agents[*]}"
npx --yes skills add manaflow-ai/cmux -g -y --agent "${skill_agents[@]}" || warn "cmux skills installation failed."
log "Installing Orca skills for: ${skill_agents[*]}"
for skill in orca-cli orchestration orca-computer-use; do
  npx --yes skills add https://github.com/stablyai/orca --skill "$skill" -g -y --agent "${skill_agents[@]}" || warn "Orca skill $skill installation failed."
done
"$cmux" reload-config || warn "Run cmux reload-config inside cmux to apply terminal preferences."
