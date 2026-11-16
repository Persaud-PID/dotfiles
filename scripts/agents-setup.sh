#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
require_macos
use_default_node
export PATH="$HOME/.local/bin:$PATH"

agent_installed() {
  local binary
  while IFS= read -r binary; do
    # cmux can expose wrappers even when the underlying agent is absent.
    case "$binary" in */cmux-cli-shims/*) continue ;; esac
    return 0
  done < <(type -a -p "$1")
  return 1
}

if ! agent_installed pi; then
  npm install --global --ignore-scripts @earendil-works/pi-coding-agent
fi
if ! agent_installed gemini; then
  npm install --global @google/gemini-cli
fi
if ! agent_installed devin; then
  ensure_homebrew
  brew install --cask devin-cli
fi
for agent in pi gemini devin; do
  agent_installed "$agent" || die "$agent is unavailable after installation."
done
log "Pi, Devin CLI and Gemini CLI ready. Existing installations are kept; sign in manually."
