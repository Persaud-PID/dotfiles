#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
if ! is_macos; then
  apt_install build-essential curl git
fi
export GOENV_ROOT="$HOME/.goenv"
if [[ ! -d "$GOENV_ROOT" ]]; then
  git clone --depth=1 https://github.com/go-nv/goenv.git "$GOENV_ROOT"
fi
export PATH="$GOENV_ROOT/bin:$GOENV_ROOT/shims:$HOME/go/bin:$PATH"
version="${GO_VERSION:-}"
if [[ -z "$version" ]]; then
  version="$(goenv install --list | awk '/^[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+$/ {gsub(/ /,""); print}' | sort -t . -k1,1n -k2,2n -k3,3n | tail -n 1)"
fi
[[ -n "$version" ]] || die "Could not determine a stable Go version."
goenv install -s "$version"
goenv global "$version"
goenv rehash
for tool in \
  github.com/golangci/golangci-lint/v2/cmd/golangci-lint \
  github.com/segmentio/golines \
  mvdan.cc/gofumpt \
  github.com/incu6us/goimports-reviser/v3 \
  github.com/cweill/gotests/gotests \
  golang.org/x/tools/cmd/godoc \
  golang.org/x/tools/cmd/goimports \
  github.com/spf13/cobra-cli \
  github.com/air-verse/air \
  github.com/swaggo/swag/cmd/swag; do
  log "Installing $tool"
  go install "$tool@latest"
done
goenv rehash
log "goenv Go $(go version) and the reference Go tool collection are ready."
