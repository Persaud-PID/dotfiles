if (( $+commands[nvim] )); then
  export EDITOR=nvim VISUAL=nvim
  autoload -Uz edit-command-line
  zle -N edit-command-line
  _edit-and-execute() {
    zle edit-command-line
    [[ -z "$BUFFER" ]] || zle .accept-line
  }
  zle -N _edit-and-execute
  bindkey '^X^E' _edit-and-execute
fi
