#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
brew_bundle Brewfile.kubernetes
helm="$(brew --prefix)/opt/helm@3/bin/helm"
[[ -x "$helm" ]] || die "Helm 3 executable missing."
for plugin in diff secrets; do
  if ! "$helm" plugin list | awk 'NR>1 {print $1}' | command grep -Fxq "$plugin"; then
    if [[ "$plugin" == diff ]]; then
      "$helm" plugin install https://github.com/databus23/helm-diff --version v3.13.0
    else
      "$helm" plugin install https://github.com/jkroepke/helm-secrets
    fi
  fi
done
mkdir -p "$HOME/.zsh/completions"
kubectl completion zsh > "$HOME/.zsh/completions/_kubectl"
"$helm" completion zsh > "$HOME/.zsh/completions/_helm"
if [[ ! -x "${KREW_ROOT:-$HOME/.krew}/bin/kubectl-krew" ]]; then
  temp="$(mktemp -d)"
  trap 'rm -rf "$temp"' EXIT
  case "$(uname -m)" in arm64) arch=arm64 ;; x86_64) arch=amd64 ;; *) die "Unsupported CPU for krew" ;; esac
  curl -fsSL "https://github.com/kubernetes-sigs/krew/releases/latest/download/krew-darwin_${arch}.tar.gz" -o "$temp/krew.tar.gz"
  tar -xzf "$temp/krew.tar.gz" -C "$temp"
  "$temp/krew-darwin_${arch}" install krew
fi
fubectl="$HOME/Documents/fubectl.source"
if [[ ! -f "$fubectl" ]]; then
  mkdir -p "$(dirname "$fubectl")"
  download="$(mktemp)"
  curl -fsSL https://raw.githubusercontent.com/kubermatic/fubectl/main/fubectl.source -o "$download"
  install -m 644 "$download" "$fubectl"
  rm -f "$download"
fi
log "AWS/Kubernetes tools ready. No cluster or AWS API operations were performed."
