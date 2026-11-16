typeset -U path fpath
if command -v brew >/dev/null 2>&1; then
  BREW_PREFIX="$(brew --prefix)"
elif [[ -d /opt/homebrew ]]; then
  BREW_PREFIX=/opt/homebrew
elif [[ -d /home/linuxbrew/.linuxbrew ]]; then
  BREW_PREFIX=/home/linuxbrew/.linuxbrew
else
  BREW_PREFIX=/usr/local
fi

PE_ROOT="${PE_ROOT:-$HOME/Documents/Gitlab/Zscaler/pe}"
path=(
  "$HOME/.local/bin"
  "$HOME/bin" "$BREW_PREFIX/bin" "$BREW_PREFIX/sbin"
  "$BREW_PREFIX/opt/openjdk/bin" "$HOME/go/bin"
  "$BREW_PREFIX/opt/helm@3/bin"
  "${KREW_ROOT:-$HOME/.krew}/bin" "$HOME/.local/bin"
  "$BREW_PREFIX/opt/libpq/bin" "$HOME/.codeium/windsurf/bin"
  $path
)
[[ -d "$PE_ROOT/bin" ]] && path=("$PE_ROOT/bin" $path)
[[ -d "$PE_ROOT/contrib/completion" ]] && fpath=("$PE_ROOT/contrib/completion" $fpath)
[[ -d "$HOME/.cargo/bin" ]] && path=("$HOME/.cargo/bin" $path)
[[ -d "$HOME/.bun/bin" ]] && path=("$HOME/.bun/bin" $path)
[[ -d "$HOME/.rye/shims" ]] && path+=("$HOME/.rye/shims")
[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
[[ -d "$HOME/.tfenv/bin" ]] && path=("$HOME/.tfenv/bin" $path)
export ZSH_FUNC_DIR="$HOME/.zsh/completions"
fpath=("$ZSH_FUNC_DIR" $fpath)

export AWS_SDK_LOAD_CONFIG=1 EKSCTL_ENABLE_CREDENTIAL_CACHE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
if [[ -d "$BREW_PREFIX/opt/openssl" && -d "$BREW_PREFIX/opt/libpq" ]]; then
  export LDFLAGS="-L$BREW_PREFIX/opt/openssl/lib -L$BREW_PREFIX/opt/libpq/lib"
  export CPPFLAGS="-I$BREW_PREFIX/opt/openssl/include -I$BREW_PREFIX/opt/libpq/include"
  export PKG_CONFIG_PATH="$BREW_PREFIX/opt/openssl/lib/pkgconfig"
fi
