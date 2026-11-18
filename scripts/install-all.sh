#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
setup_args=("$@")
company=""
company_dir="${COMPANY_CONFIG_DIR:-$(dirname "$REPO_DIR")/company-configs}"
while (( $# )); do
  case "$1" in
    --help|-h) "$REPO_DIR/setup.sh" --help; exit 0 ;;
    --company|--company-dir|--nvim-config)
      [[ $# -ge 2 && -n "$2" ]] || die "$1 needs a value."
      case "$1" in
        --company) company="$2" ;;
        --company-dir) company_dir="$2" ;;
      esac
      shift 2 ;;
    *) die "Use setup.sh for previews/alternate targets. install-all.sh accepts --company NAME, --company-dir DIR and --nvim-config DIR." ;;
  esac
done
if [[ -n "$company" && "$company" != none && ! -f "$HOME/.zsh/companies/$company.zsh" ]]; then
  [[ "$company_dir" != none && ( ! -e "$company_dir" || -f "$company_dir/$company.zsh" ) ]] \
    || die "Unknown company: $company (add $company.zsh to $company_dir or use --company none)"
fi
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
  log "Linux toolchain installed. Neovim needs 0.12+ from a suitable distro/source build."
fi
log "Provisioning complete. Open a new shell."
