#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
previous_node="$(node --version 2>/dev/null || true)"
if is_macos; then
  brew_bundle Brewfile.typescript
else
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    git clone --depth=1 https://github.com/nvm-sh/nvm.git "$NVM_DIR"
  fi
fi
load_nvm
# nvm itself is not nounset-safe.
set +u
nvm install --lts
nvm alias default 'lts/*'
nvm use --silent default
if [[ "$previous_node" == v* && "$previous_node" != "$(node --version)" ]]; then
  nvm reinstall-packages "$previous_node"
fi
set -u
command_exists npx || die "Node installed, but npx is unavailable."
npm install --global yarn typescript ts-node eslint @typescript-eslint/parser \
  @typescript-eslint/eslint-plugin prettier typedoc tsx
if [[ ! -x "$HOME/.bun/bin/bun" ]]; then
  # Bun's generic-shell path avoids modifying the Stow-managed shell files.
  export BUN_INSTALL="$HOME/.bun"
  SHELL=/bin/sh download_run https://bun.sh/install bash
fi
log "Node $(node --version), npm/npx, Bun, Yarn and global TypeScript tools ready."
