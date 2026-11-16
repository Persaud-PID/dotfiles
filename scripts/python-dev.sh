#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
if is_macos; then
  brew_bundle Brewfile.python
elif ! command_exists uv; then
  export UV_NO_MODIFY_PATH=1
  download_run https://astral.sh/uv/install.sh sh
fi
export PATH="$HOME/.local/bin:$PATH"
uv python install --default
for tool in ruff black isort mypy pytest ipython; do
  uv tool install "$tool"
done
if is_macos && ! command_exists aws-sso-util && [[ ! -x "$HOME/.local/bin/aws-sso-util" ]]; then
  pipx install aws-sso-util
fi
log "uv-managed Python and ruff/black/isort/mypy/pytest/IPython ready."
