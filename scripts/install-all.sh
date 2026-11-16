#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
setup_args=("$@")
while (( $# )); do
  case "$1" in
    --help|-h) "$REPO_DIR/setup.sh" --help; exit 0 ;;
    --company|--nvim-config)
      [[ $# -ge 2 && -n "$2" ]] || die "$1 needs a value."
      if [[ "$1" == --company ]]; then
        [[ "$2" == none || -f "$REPO_DIR/company/.zsh/companies/$2.zsh" ]] \
          || die "Unknown company: $2"
      fi
      shift 2 ;;
    *) die "Use setup.sh for previews/alternate targets. install-all.sh accepts --company NAME and --nvim-config DIR." ;;
  esac
done
for script in install-core-tools typescript-dev rust-dev go-dev terraform-dev terminals-setup; do
  "$REPO_DIR/scripts/$script.sh"
done
if is_macos; then
  "$REPO_DIR/scripts/kubernetes-dev.sh"
  "$REPO_DIR/scripts/containers-dev.sh"
  "$REPO_DIR/scripts/neovim-setup.sh" "${setup_args[@]}"
  "$REPO_DIR/scripts/cmux-setup.sh"
else
  "$REPO_DIR/setup.sh" "${setup_args[@]}"
  log "Reference Linux toolchain installed. Neovim needs 0.12+ from a suitable distro/source build."
fi
log "Provisioning complete. Open a new shell."
