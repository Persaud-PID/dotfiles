(( $+commands[fzf] )) || return 0
if (( $+commands[fd] )); then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
fi
# Match the existing Catppuccin Mocha terminal instead of upstream's Tokyo Night.
export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:-} --height=40% --layout=reverse --border --color=bg:#1e1e2e,fg:#cdd6f4,hl:#f9e2af,fg+:#cdd6f4,bg+:#313244,prompt:#b4befe,pointer:#f5c2e7"
if [[ -r "$BREW_PREFIX/opt/fzf/shell/completion.zsh" ]]; then
  source "$BREW_PREFIX/opt/fzf/shell/completion.zsh"
  source "$BREW_PREFIX/opt/fzf/shell/key-bindings.zsh"
elif [[ -f "$HOME/.fzf.zsh" ]]; then
  source "$HOME/.fzf.zsh"
else
  for directory in /usr/share/doc/fzf/examples /usr/share/fzf; do
    if [[ -f "$directory/completion.zsh" ]]; then
      source "$directory/completion.zsh"
      source "$directory/key-bindings.zsh"
      break
    fi
  done
fi
