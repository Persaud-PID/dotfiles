# zoxide
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# direnv
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

# autosuggestions
if command -v brew >/dev/null 2>&1; then
  BREW_PREFIX="${BREW_PREFIX:-$(brew --prefix 2>/dev/null)}"
  if [[ -r "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    source "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  fi
fi

# Linux uses the same plugins cloned by install-core-tools.sh.
if [[ "$OSTYPE" == linux* ]]; then
  for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    script="$HOME/.oh-my-zsh/custom/plugins/$plugin/$plugin.zsh"
    [[ -r "$script" ]] && source "$script"
  done
  unset plugin script
fi

# syntax highlighting — MUST be last
if command -v brew >/dev/null 2>&1; then
  BREW_PREFIX="${BREW_PREFIX:-$(brew --prefix 2>/dev/null)}"
  if [[ -r "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    source "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  fi
fi
