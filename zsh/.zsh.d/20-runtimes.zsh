export SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"
[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"

export NVM_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvm"
[[ -d "$HOME/.nvm" ]] && export NVM_DIR="$HOME/.nvm"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  source "$NVM_DIR/nvm.sh"
elif [[ -s "$BREW_PREFIX/opt/nvm/nvm.sh" ]]; then
  source "$BREW_PREFIX/opt/nvm/nvm.sh"
fi
if (( $+functions[nvm] )); then
  nvm use --silent default >/dev/null 2>&1 || nvm use --silent node >/dev/null 2>&1
fi
if [[ -x "$HOME/.goenv/bin/goenv" ]]; then
  export GOENV_ROOT="$HOME/.goenv"
  path=("$GOENV_ROOT/bin" $path)
  eval "$(goenv init -)"
  path=("$(goenv exec go env GOPATH)/bin" "$HOME/go/bin" $path)
fi
if [[ -s "$HOME/.bun/_bun" ]]; then
  source "$HOME/.bun/_bun"
fi
