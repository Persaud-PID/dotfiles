#!/usr/bin/env bash
printf '%s\n' 'This bootstrap is retired. Use ../setup.sh and ../scripts/; see ../README.md.' >&2
exit 1

set -euo pipefail

# ------------------------------------------------------------
# Archived pre-Stow bootstrap. Do not run; use ../setup.sh and ../scripts/.
# - Installs Homebrew itself if missing, then idempotent installs via Homebrew and pipx
# - Installs shells, CLIs, plugins, and apps used by ~/.zshrc
# - Installs cmux as the terminal app
# - Installs Starship for a conditional AWS/Kubernetes prompt
# - Installs Node LTS through nvm for npm/npx
# - Configures cmux agent hooks, skills, and Catppuccin appearance
# - Links cmux's global app config into the repository
# - Links repo .zshrc and core/tools/company zsh files into ~/.zshrc / ~/.zsh
# - Downloads latest fubectl.source and patches KUBECONTEXT/NAMESPACECONTEXT
# - Opens cmux at completion
# - Ensures Homebrew zsh is installed, whitelisted in /etc/shells,
#   and set as the default login shell
# - Installs Oh My Zsh itself if missing (required by ~/.zshrc)
# ------------------------------------------------------------

if [[ -n ${BASH_SOURCE:-} ]]; then
  REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  REPO_DIR="${${(%):-%N}:A:h}"
fi
ZSHRC_SRC="${REPO_DIR}/zshrc"
STARSHIP_CONFIG_SRC="${REPO_DIR}/starship.toml"
CMUX_CONFIG_SRC="${REPO_DIR}/cmux/cmux.json"
COMPLETIONS_ZSH_SRC="${REPO_DIR}/core/completions.zsh"
PLUGINS_ZSH_SRC="${REPO_DIR}/core/plugins.zsh"
AWS_ZSH_SRC="${REPO_DIR}/tools/aws.zsh"
KUBERNETES_ZSH_SRC="${REPO_DIR}/tools/kubernetes.zsh"
GIT_ZSH_SRC="${REPO_DIR}/tools/git.zsh"
COMPANY_DIR="${REPO_DIR}/company"
FUBECTL_PATH="${HOME}/Documents/fubectl.source"

cecho() { printf "\033[1;36m==>\033[0m %s\n" "$*"; }
ok()    { printf "\033[1;32m[ok]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[warn]\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m[err]\033[0m %s\n" "$*"; }

if [[ -n "${COMPANY_NAME:-}" ]]; then
  cecho "Using COMPANY_NAME from environment: ${COMPANY_NAME}"
else
  company_options=()
  if [[ -d "$COMPANY_DIR" ]]; then
    for f in "$COMPANY_DIR"/*.zsh; do
      [[ -f "$f" ]] || continue
      company_options+=("$(basename "$f" .zsh)")
    done
  fi
  if (( ${#company_options[@]} > 0 )); then
    company_hint="$(IFS=', '; echo "${company_options[*]}")"
  else
    company_hint="none found in company/"
  fi
  read -r -p "Company config to load from company/ (available: ${company_hint}; blank to skip): " COMPANY_NAME
fi

ensure_homebrew_installed() {
  if command -v brew >/dev/null 2>&1; then
    ok "Homebrew already installed."
    return 0
  fi
  cecho "Homebrew not found; installing…"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  local brew_bin=""
  if [[ -x /opt/homebrew/bin/brew ]]; then
    brew_bin="/opt/homebrew/bin/brew"
  elif [[ -x /usr/local/bin/brew ]]; then
    brew_bin="/usr/local/bin/brew"
  fi

  if [[ -z "$brew_bin" ]]; then
    err "Homebrew install finished but brew binary not found in expected locations."
    exit 1
  fi

  eval "$("$brew_bin" shellenv)"

  if ! command -v brew >/dev/null 2>&1; then
    err "Homebrew installed but not on PATH after shellenv."
    exit 1
  fi
  ok "Homebrew installed: $(brew --version | head -n1)"
}

brew_install_or_upgrade() {
  local pkg="$1"
  if brew list --formula --versions "$pkg" >/dev/null 2>&1 || brew list --cask --versions "$pkg" >/dev/null 2>&1; then
    brew upgrade "$pkg" >/dev/null 2>&1 || true
  else
    brew install "$pkg"
  fi
}

ensure_node_npx_installed() {
  local nvm_dir="${NVM_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/nvm}"
  [[ -d "$HOME/.nvm" ]] && nvm_dir="$HOME/.nvm"
  local nvm_script="$(brew --prefix nvm)/nvm.sh"

  mkdir -p "$nvm_dir"
  export NVM_DIR="$nvm_dir"
  if [[ ! -s "$nvm_script" ]]; then
    err "nvm script not found at ${nvm_script}."
    return 1
  fi

  # nvm may reference unset internals under nounset; restore strict mode afterward.
  set +u
  if ! . "$nvm_script"; then
    set -euo pipefail
    err "Unable to load nvm from ${nvm_script}."
    return 1
  fi
  if nvm use --silent default >/dev/null 2>&1 && command -v npx >/dev/null 2>&1; then
    :
  elif nvm use --silent node >/dev/null 2>&1 && command -v npx >/dev/null 2>&1; then
    nvm alias default node >/dev/null
  else
    cecho "Installing the current Node.js LTS through nvm…"
    nvm install --lts
    nvm alias default 'lts/*' >/dev/null
    nvm use --silent default >/dev/null
  fi

  set -euo pipefail
  if ! command -v npx >/dev/null 2>&1; then
    err "npx is not available after configuring Node.js."
    return 1
  fi
  ok "Node.js and npx available: $(node --version)."
}

ensure_pinentry_installed() {
  local gnupg_dir="$HOME/.gnupg"
  local gpg_agent_conf="$gnupg_dir/gpg-agent.conf"
  local pinentry_line="pinentry-program $(brew --prefix)/bin/pinentry-mac"

  mkdir -p "$gnupg_dir"
  touch "$gpg_agent_conf"

  if ! grep -qxF "$pinentry_line" "$gpg_agent_conf"; then
    echo "$pinentry_line" >> "$gpg_agent_conf"
  fi

  killall gpg-agent 2>/dev/null || true
  ok "pinentry-mac configured in ${gpg_agent_conf}."
}

ensure_tap() {
  local tap="$1"
  brew tap | grep -q "^${tap}\$" || brew tap "$tap"
}

ensure_cask() {
  local cask="$1" app_path="${2:-}"
  if [[ -n "$app_path" && -d "$app_path" ]]; then
    ok "${cask} already present; skipping."
    return 0
  fi
  brew list --cask --versions "$cask" >/dev/null 2>&1 || brew install --cask "$cask"
}

install_meslo_nf() {
  local target="$HOME/Library/Fonts"
  local marker="$target/.meslo-nerdfont-installed"
  if [[ -f "$marker" ]]; then
    ok "MesloLGS NF already installed."
    return 0
  fi
  cecho "Installing MesloLGS Nerd Font…"
  local tmp; tmp="$(mktemp -d)"
  (
    set -e
    cd "$tmp"
    curl -fsSLO "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip"
    unzip -qq Meslo.zip
    mkdir -p "$target"
    find . -type f -name "Meslo*.ttf" -exec cp "{}" "$target/" \;
    touch "$marker"
  )
  rm -rf "$tmp"
  ok "MesloLGS NF installed."
}

install_helm3_via_brew() {
  cecho "Installing Helm 3 via Homebrew (helm@3)…"
  brew list --formula --versions helm >/dev/null 2>&1 && brew unlink helm >/dev/null 2>&1 || true
  brew install helm@3 >/dev/null 2>&1 || true
  brew link --force --overwrite helm@3 >/dev/null 2>&1 || true
  if ! helm version --short 2>/dev/null | grep -q '^v3\.'; then
    err "Helm v3 not on PATH after install."
    exit 1
  fi
  ok "Helm pinned to $(helm version --short)."
}

install_helm_diff_plugin() {
  cecho "Installing helm-diff plugin…"
  helm plugin remove diff >/dev/null 2>&1 || true
  helm plugin install https://github.com/databus23/helm-diff --version v3.13.0 >/dev/null 2<&1 || true
  ok "helm-diff installed for $(helm version --short)."
}

# Robust helm-secrets installer (cleans stale dirs that cause "Unable to update repository")
install_helm_secrets_plugin() {
  cecho "Installing helm-secrets plugin…"
  helm plugin rm secrets >/dev/null 2>&1 || true
  local candidates=()
  if [[ -n "${HELM_PLUGINS:-}" ]]; then
    candidates+=("$HELM_PLUGINS/helm-secrets")
  fi
  candidates+=("$HOME/Library/helm/plugins/helm-secrets" "$HOME/.local/share/helm/plugins/helm-secrets")
  for d in "${candidates[@]}"; do
    if [[ -d "$d" ]]; then
      cecho "Removing stale plugin dir: $d"
      rm -rf "$d"
    fi
  done
  [[ -n "${HELM_PLUGINS:-}" ]] && mkdir -p "$HELM_PLUGINS"
  helm plugin install https://github.com/jkroepke/helm-secrets
  ok "helm-secrets installed."
}

install_krew_if_missing() {
  if ! command -v kubectl >/dev/null 2>&1; then return 0; fi
  if kubectl krew >/dev/null 2>&1; then return 0; fi
  cecho "Installing krew…"
  local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  (
    cd "$tmp"
    curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/krew-darwin_arm64.tar.gz"
    tar zxf krew-darwin_arm64.tar.gz
    ./krew-darwin_arm64 install krew
  )
  ok "krew installed to \$HOME/.krew/bin."
}

non_brew_install_or_upgrade_tflint() {
  if command -v tflint >/dev/null 2>&1; then
    cecho "Upgrading tflint via official release binary…"
  else
    cecho "Installing tflint via official release binary…"
  fi
  local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  (
    set -e
    cd "$tmp"
    curl -sSLO "https://github.com/terraform-linters/tflint/releases/latest/download/tflint_darwin_arm64.zip"
    curl -sSLO "https://github.com/terraform-linters/tflint/releases/latest/download/checksums.txt"
    if command -v gh >/dev/null 2>&1; then
      gh attestation verify checksums.txt -R terraform-linters/tflint \
        || echo "[warn] tflint attestation verification failed or unavailable; continuing with checksum check only"
    fi
    shasum -a 256 --ignore-missing -c checksums.txt
    unzip -qq tflint_darwin_arm64.zip
    sudo install -c -v tflint /usr/local/bin/
  )
  ok "tflint installed: $(tflint --version 2>/dev/null | head -n1 || echo unknown)"
}

download_latest_fubectl_source() {
  local dest="$FUBECTL_PATH"
  local url_primary="https://raw.githubusercontent.com/kubermatic/fubectl/main/fubectl.source"
  local url_fallback="https://rawgit.com/kubermatic/fubectl/main/fubectl.source"
  cecho "Fetching latest fubectl.source…"
  mkdir -p "$(dirname "$dest")"
  if curl -fsSL -o "$dest" "$url_primary"; then :; else
    warn "Primary fetch failed; trying fallback URL…"
    curl -fsSL -o "$dest" "$url_fallback"
  fi
  chmod 0644 "$dest" || true
  ok "fubectl.source downloaded to ${dest}"
}

patch_fubectl_source_kube_lines() {
  local file="$FUBECTL_PATH"
  local want_ctx="    KUBECONTEXT=\"\$(kubectl config current-context 2>/dev/null || true)\""
  local want_ns="    NAMESPACECONTEXT=\"\$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null || true)\""
  if [[ ! -f "$file" ]]; then
    warn "fubectl.source not found at: $file"
    return 0
  fi
  cecho "Patching fubectl.source…"
  if grep -q '^[[:space:]]*KUBECONTEXT=' "$file"; then
    sed -E -i '' "s|^[[:space:]]*KUBECONTEXT=.*$|$want_ctx|" "$file"
  else
    printf "\n%s\n" "$want_ctx" >> "$file"
  fi
  if grep -q '^[[:space:]]*NAMESPACECONTEXT=' "$file"; then
    sed -E -i '' "s|^[[:space:]]*NAMESPACECONTEXT=.*$|$want_ns|" "$file"
  else
    printf "%s\n" "$want_ns" >> "$file"
  fi
  ok "fubectl.source updated."
}

ensure_default_shell_zsh() {
  cecho "Ensuring Homebrew zsh is default login shell…"
  local brew_prefix zsh_bin
  brew_prefix="$(brew --prefix 2>/dev/null || echo /opt/homebrew)"
  zsh_bin="${brew_prefix}/bin/zsh"
  [[ -x "$zsh_bin" ]] || zsh_bin="$(command -v zsh || true)"
  if [[ -z "${zsh_bin:-}" || ! -x "$zsh_bin" ]]; then
    err "zsh binary not found after installation."
    return 1
  fi
  if ! grep -q "^${zsh_bin}\$" /etc/shells; then
    cecho "Adding ${zsh_bin} to /etc/shells…"
    echo "${zsh_bin}" | sudo tee -a /etc/shells >/dev/null
  fi
  if [[ "${SHELL:-}" != "${zsh_bin}" ]]; then
    cecho "Setting default shell to ${zsh_bin}…"
    chsh -s "${zsh_bin}" "${USER}" || warn "chsh failed; manual shell switch may be required."
  else
    ok "Default shell already set to ${zsh_bin}."
  fi
}

ensure_oh_my_zsh_installed() {
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    ok "Oh My Zsh already installed."
    return 0
  fi
  cecho "Oh My Zsh not found; installing…"
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    err "Oh My Zsh install finished but ~/.oh-my-zsh not found."
    exit 1
  fi
  ok "Oh My Zsh installed."
}

open_cmux() {
  cecho "Opening cmux…"
  open -a cmux
}

cmux_cli() {
  local cmux_bin
  cmux_bin="$(command -v cmux 2>/dev/null || true)"
  if [[ -n "$cmux_bin" ]]; then
    "$cmux_bin" "$@"
    return
  fi

  local bundled_cli="/Applications/cmux.app/Contents/Resources/bin/cmux"
  if [[ ! -x "$bundled_cli" ]]; then
    bundled_cli="$HOME/Applications/cmux.app/Contents/Resources/bin/cmux"
  fi
  if [[ -x "$bundled_cli" ]]; then
    "$bundled_cli" "$@"
    return
  fi
  return 127
}

configure_cmux() {
  cecho "Configuring cmux agent integrations and appearance…"
  if ! cmux_cli hooks setup; then
    warn "cmux agent hooks could not be configured; rerun 'cmux hooks setup' after installing agent CLIs."
  fi

  if command -v npx >/dev/null 2>&1; then
    npx --yes skills add manaflow-ai/cmux -g -y \
      || warn "cmux skills installation failed; rerun 'npx skills add manaflow-ai/cmux -g -y' later."
  else
    warn "npx not found; skipping cmux skills installation."
  fi

  if ! cmux_cli config set app.appearance dark; then
    warn "Could not set cmux appearance to dark."
  fi
  if ! cmux_cli themes set "Catppuccin Mocha"; then
    warn "Could not set the Catppuccin Mocha terminal theme."
  fi
  # Stable cmux exposes sidebar matching and accent colors, but not a full chrome palette.
  if ! cmux_cli config set sidebarAppearance.matchTerminalBackground true; then
    warn "Could not configure the cmux sidebar to match the terminal background."
  fi
  if ! cmux_cli config set app.accentColor "#b4befe"; then
    warn "Could not set the cmux accent to Catppuccin Mocha Lavender."
  fi
  if ! cmux_cli config set sidebar.showBranchDirectory true; then
    warn "Could not enable Git branch details in the cmux sidebar."
  fi
}

# ------------------------------------------------------------
# Homebrew and core shell tooling
# ------------------------------------------------------------
ensure_homebrew_installed

cecho "Updating Homebrew…"
brew update || true

cecho "Installing shell & base tools…"
brew_install_or_upgrade zsh
brew_install_or_upgrade starship
brew_install_or_upgrade kustomize

ensure_default_shell_zsh
ensure_oh_my_zsh_installed

# ------------------------------------------------------------
# Requested CLIs
# ------------------------------------------------------------
cecho "Installing requested CLIs…"
brew_install_or_upgrade awscli
brew_install_or_upgrade jq
brew_install_or_upgrade yq
non_brew_install_or_upgrade_tflint
brew_install_or_upgrade tfsec
brew_install_or_upgrade kubeconform
brew_install_or_upgrade direnv
brew_install_or_upgrade zoxide
brew_install_or_upgrade eza
brew_install_or_upgrade ripgrep
brew_install_or_upgrade bat
brew_install_or_upgrade git-delta
brew_install_or_upgrade jfrog-cli
brew_install_or_upgrade kubectl
brew_install_or_upgrade derailed/k9s/k9s
brew_install_or_upgrade sops
brew_install_or_upgrade pinentry-mac
ensure_pinentry_installed
brew_install_or_upgrade colima
brew_install_or_upgrade docker
brew_install_or_upgrade docker-compose
brew_install_or_upgrade go
brew_install_or_upgrade nvm
ensure_node_npx_installed
brew_install_or_upgrade uv
brew_install_or_upgrade pipx
brew_install_or_upgrade git
brew_install_or_upgrade gh
brew_install_or_upgrade tenv
brew_install_or_upgrade zellij
brew_install_or_upgrade teleport
brew_install_or_upgrade cobra-cli
ensure_tap "eth-p/software"
brew_install_or_upgrade bat-extras
brew_install_or_upgrade telnet

# ------------------------------------------------------------
# zsh plugins and fzf bindings
# ------------------------------------------------------------
cecho "Installing zsh plugins…"
brew_install_or_upgrade zsh-autosuggestions
brew_install_or_upgrade zsh-syntax-highlighting
brew_install_or_upgrade fzf
"$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-fish >/dev/null 2>&1 || true

# ------------------------------------------------------------
# Helm 3 and plugins
# ------------------------------------------------------------
install_helm3_via_brew
install_helm_diff_plugin
install_helm_secrets_plugin

# ------------------------------------------------------------
# Generate zsh completion functions for kubectl and helm
# ------------------------------------------------------------
cecho "Writing zsh completion functions for kubectl and helm…"
ZFUNC_DIR="$HOME/.zsh/completions"
mkdir -p "$ZFUNC_DIR"
if command -v kubectl >/dev/null 2>&1; then
  kubectl completion zsh > "$ZFUNC_DIR/_kubectl" || true
fi
if command -v helm >/dev/null 2>&1; then
  helm completion zsh > "$ZFUNC_DIR/_helm" || true
fi
ok "zsh completion functions written to $ZFUNC_DIR"

# ------------------------------------------------------------
# kubectl plugin manager
# ------------------------------------------------------------
install_krew_if_missing

# ------------------------------------------------------------
# Apps via cask
# ------------------------------------------------------------
cecho "Installing apps…"
ensure_tap "manaflow-ai/cmux"
ensure_cask cmux "/Applications/cmux.app"
ensure_cask clocker "/Applications/Clocker.app"
ensure_cask obsidian "/Applications/Obsidian.app"

# ------------------------------------------------------------
# Terminal font
# ------------------------------------------------------------
install_meslo_nf

# ------------------------------------------------------------
# aws-sso-util (Ben Kehoe) via pipx
# ------------------------------------------------------------
cecho "Installing aws-sso-util (pipx)…"
# ensure pipx path for current shell
if command -v pipx >/dev/null 2>&1; then
  pipx ensurepath >/dev/null 2>&1 || true
  if ! command -v aws-sso-util >/dev/null 2>&1; then
    pipx install aws-sso-util >/dev/null
  else
    pipx upgrade aws-sso-util >/dev/null || true
    ok "aws-sso-util already installed; upgraded if needed."
  fi
else
  warn "pipx not found; aws-sso-util will be available after opening a new shell."
fi

# ------------------------------------------------------------
# Git defaults
# ------------------------------------------------------------
cecho "Configuring Git defaults…"
git config --global core.pager "delta"
git config --global interactive.diffFilter "delta --color-only"
git config --global delta.navigate true
git config --global delta.light false
git config --global init.defaultBranch main || true

# ------------------------------------------------------------
# Symlinks for zsh files
# ------------------------------------------------------------
mkdir -p "$HOME/.zsh"

cecho "Linking ${ZSHRC_SRC} -> ~/.zshrc …"
if [[ -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
  ts="$(date +%Y%m%d%H%M%S)"
  cp "$HOME/.zshrc" "$HOME/.zshrc.backup.${ts}"
  ok "Backed up existing ~/.zshrc"
fi
ln -sf "${ZSHRC_SRC}" "$HOME/.zshrc"
ok "Symlinked .zshrc"

STARSHIP_CONFIG_DST="$HOME/.config/starship.toml"
mkdir -p "$HOME/.config"
cecho "Linking ${STARSHIP_CONFIG_SRC} -> ${STARSHIP_CONFIG_DST} …"
if [[ -L "$STARSHIP_CONFIG_DST" ]] && [[ "$(readlink "$STARSHIP_CONFIG_DST")" == "$STARSHIP_CONFIG_SRC" ]]; then
  ok "Starship config already linked."
else
  if [[ -e "$STARSHIP_CONFIG_DST" || -L "$STARSHIP_CONFIG_DST" ]]; then
    ts="$(date +%Y%m%d%H%M%S)"
    mv "$STARSHIP_CONFIG_DST" "${STARSHIP_CONFIG_DST}.backup.${ts}"
    ok "Backed up existing Starship config."
  fi
  ln -s "$STARSHIP_CONFIG_SRC" "$STARSHIP_CONFIG_DST"
  ok "Symlinked Starship config."
fi

CMUX_CONFIG_DST="$HOME/.config/cmux/cmux.json"
mkdir -p "$HOME/.config/cmux"
cecho "Linking ${CMUX_CONFIG_SRC} -> ${CMUX_CONFIG_DST} …"
if [[ -L "$CMUX_CONFIG_DST" ]] && [[ "$(readlink "$CMUX_CONFIG_DST")" == "$CMUX_CONFIG_SRC" ]]; then
  ok "cmux config already linked."
else
  if [[ -e "$CMUX_CONFIG_DST" || -L "$CMUX_CONFIG_DST" ]]; then
    ts="$(date +%Y%m%d%H%M%S)"
    if [[ -f "$CMUX_CONFIG_DST" && ! -L "$CMUX_CONFIG_DST" ]]; then
      cp -p "$CMUX_CONFIG_DST" "${CMUX_CONFIG_DST}.backup.${ts}"
    else
      mv "$CMUX_CONFIG_DST" "${CMUX_CONFIG_DST}.backup.${ts}"
    fi
    ok "Backed up existing cmux config."
  fi
  ln -s "$CMUX_CONFIG_SRC" "$CMUX_CONFIG_DST"
  ok "Symlinked cmux config."
fi

cecho "Linking ${COMPLETIONS_ZSH_SRC} -> ~/.zsh/completions.zsh …"
if [[ -f "$HOME/.zsh/completions.zsh" && ! -L "$HOME/.zsh/completions.zsh" ]]; then
  ts="$(date +%Y%m%d%H%M%S)"
  cp "$HOME/.zsh/completions.zsh" "$HOME/.zsh/completions.zsh.backup.${ts}"
  ok "Backed up existing ~/.zsh/completions.zsh"
fi
ln -sf "${COMPLETIONS_ZSH_SRC}" "$HOME/.zsh/completions.zsh"
ok "Symlinked completions.zsh"

cecho "Linking ${PLUGINS_ZSH_SRC} -> ~/.zsh/plugins.zsh …"
if [[ -f "$HOME/.zsh/plugins.zsh" && ! -L "$HOME/.zsh/plugins.zsh" ]]; then
  ts="$(date +%Y%m%d%H%M%S)"
  cp "$HOME/.zsh/plugins.zsh" "$HOME/.zsh/plugins.zsh.backup.${ts}"
  ok "Backed up existing ~/.zsh/plugins.zsh"
fi
ln -sf "${PLUGINS_ZSH_SRC}" "$HOME/.zsh/plugins.zsh"
ok "Symlinked plugins.zsh"

cecho "Linking ${AWS_ZSH_SRC} -> ~/.zsh/aws.zsh …"
if [[ -f "$HOME/.zsh/aws.zsh" && ! -L "$HOME/.zsh/aws.zsh" ]]; then
  ts="$(date +%Y%m%d%H%M%S)"
  cp "$HOME/.zsh/aws.zsh" "$HOME/.zsh/aws.zsh.backup.${ts}"
  ok "Backed up existing ~/.zsh/aws.zsh"
fi
ln -sf "${AWS_ZSH_SRC}" "$HOME/.zsh/aws.zsh"
ok "Symlinked aws.zsh"

cecho "Linking ${KUBERNETES_ZSH_SRC} -> ~/.zsh/kubernetes.zsh …"
if [[ -f "$HOME/.zsh/kubernetes.zsh" && ! -L "$HOME/.zsh/kubernetes.zsh" ]]; then
  ts="$(date +%Y%m%d%H%M%S)"
  cp "$HOME/.zsh/kubernetes.zsh" "$HOME/.zsh/kubernetes.zsh.backup.${ts}"
  ok "Backed up existing ~/.zsh/kubernetes.zsh"
fi
ln -sf "${KUBERNETES_ZSH_SRC}" "$HOME/.zsh/kubernetes.zsh"
ok "Symlinked kubernetes.zsh"

cecho "Linking ${GIT_ZSH_SRC} -> ~/.zsh/git.zsh …"
if [[ -f "$HOME/.zsh/git.zsh" && ! -L "$HOME/.zsh/git.zsh" ]]; then
  ts="$(date +%Y%m%d%H%M%S)"
  cp "$HOME/.zsh/git.zsh" "$HOME/.zsh/git.zsh.backup.${ts}"
  ok "Backed up existing ~/.zsh/git.zsh"
fi
ln -sf "${GIT_ZSH_SRC}" "$HOME/.zsh/git.zsh"
ok "Symlinked git.zsh"

if [[ -n "${COMPANY_NAME:-}" ]]; then
  COMPANY_ZSH_SRC="${COMPANY_DIR}/${COMPANY_NAME}.zsh"
  if [[ -f "$COMPANY_ZSH_SRC" ]]; then
    cecho "Linking ${COMPANY_ZSH_SRC} -> ~/.zsh/company.zsh …"
    if [[ -f "$HOME/.zsh/company.zsh" && ! -L "$HOME/.zsh/company.zsh" ]]; then
      ts="$(date +%Y%m%d%H%M%S)"
      cp "$HOME/.zsh/company.zsh" "$HOME/.zsh/company.zsh.backup.${ts}"
      ok "Backed up existing ~/.zsh/company.zsh"
    fi
    ln -sf "${COMPANY_ZSH_SRC}" "$HOME/.zsh/company.zsh"
    ok "Symlinked company.zsh -> ${COMPANY_NAME}.zsh"
  else
    warn "No company config found at ${COMPANY_ZSH_SRC}; skipping company.zsh symlink."
  fi
else
  warn "No company specified; skipping company-specific zsh config."
fi

# ------------------------------------------------------------
# fubectl.source: download latest and apply patch
# ------------------------------------------------------------
download_latest_fubectl_source
patch_fubectl_source_kube_lines
configure_cmux

# Summary
jq --version | head -n1 || true
yq --version | head -n1 || true
ok "eza / zoxide / delta installed."
ok "Oh My Zsh: $([[ -d "$HOME/.oh-my-zsh" ]] && echo installed || echo not-found)"
ok ".zshrc linked from: ${ZSHRC_SRC}"
ok "Starship config linked from: ${STARSHIP_CONFIG_SRC}"
ok "cmux config linked from: ${CMUX_CONFIG_SRC}"
ok "completions.zsh linked from: ${COMPLETIONS_ZSH_SRC}"
ok "plugins.zsh linked from: ${PLUGINS_ZSH_SRC}"
ok "aws.zsh linked from: ${AWS_ZSH_SRC}"
ok "kubernetes.zsh linked from: ${KUBERNETES_ZSH_SRC}"
ok "git.zsh linked from: ${GIT_ZSH_SRC}"
ok "company.zsh linked from: ${COMPANY_ZSH_SRC:-<none>}"
ok "cmux terminal theme and agent setup configured."
ok "Helm: $(helm version --short 2>/dev/null || echo not-found)"
ok "fubectl.source refreshed and patched."
sleep 5

# ------------------------------------------------------------
# Finalization: open cmux
# ------------------------------------------------------------
open_cmux
