#!/usr/bin/env bash
# Compatibility only: Rye is unmaintained; use uv for new projects.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
if [[ ! -x "$HOME/.rye/shims/rye" ]]; then
  RYE_INSTALL_OPTION="--yes --no-modify-path" download_run https://rye.astral.sh/get bash
fi
"$HOME/.rye/shims/rye" --version
warn "Rye is included but is no longer maintained. Prefer uv."
