#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
if is_macos; then
  brew_bundle Brewfile.terraform
else
  apt_install curl unzip git
fi
if [[ ! -d "$HOME/.tfenv" ]]; then
  git clone --depth=1 https://github.com/tfutils/tfenv.git "$HOME/.tfenv"
fi
export PATH="$HOME/.tfenv/bin:$HOME/.local/bin:$HOME/go/bin:$PATH"
version="${TERRAFORM_VERSION:-latest}"
tfenv install "$version"
tfenv use "$version"
if ! command_exists tflint; then
  temp="$(mktemp -d)"
  trap 'rm -rf "$temp"' EXIT
  case "$(uname -m)" in
    arm64|aarch64) arch=arm64 ;;
    x86_64) arch=amd64 ;;
    *) die "Unsupported CPU for tflint" ;;
  esac
  platform="$(uname -s | tr '[:upper:]' '[:lower:]')"
  archive="tflint_${platform}_${arch}.zip"
  base=https://github.com/terraform-linters/tflint/releases/latest/download
  curl -fsSL "$base/$archive" -o "$temp/$archive"
  curl -fsSL "$base/checksums.txt" -o "$temp/checksums.txt"
  if command_exists gh; then
    gh attestation verify "$temp/checksums.txt" -R terraform-linters/tflint \
      || warn "Attestation unavailable; checking the release checksum."
  fi
  (cd "$temp" && command grep "  $archive\$" checksums.txt | shasum -a 256 -c -)
  unzip -q "$temp/$archive" -d "$temp"
  mkdir -p "$HOME/.local/bin"
  install -m 755 "$temp/tflint" "$HOME/.local/bin/tflint"
fi
if ! is_macos; then
  export PATH="$HOME/.goenv/bin:$HOME/.goenv/shims:$PATH"
  command_exists go || die "Run scripts/go-dev.sh first for Linux Terraform helper builds."
  command_exists terraform-docs || go install github.com/terraform-docs/terraform-docs@latest
  command_exists tfsec || go install github.com/aquasecurity/tfsec/cmd/tfsec@latest
fi
log "tfenv Terraform and Terraform tools ready; OpenTofu/Terragrunt use standalone packages on macOS."
