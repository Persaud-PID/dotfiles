setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS EXTENDED_GLOB
setopt HIST_IGNORE_DUPS HIST_IGNORE_SPACE HIST_EXPIRE_DUPS_FIRST SHARE_HISTORY
export HIST_STAMPS="mm/dd/yyyy"
export LANG="${LANG:-en_US.UTF-8}" LC_CTYPE="${LC_CTYPE:-en_US.UTF-8}"
HISTSIZE=100000
SAVEHIST=100000
HISTFILE="${ZDOTDIR:-$HOME}/.zsh_history"

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""
DISABLE_UPDATE_PROMPT=true
ENABLE_CORRECTION=true
COMPLETION_WAITING_DOTS=true
plugins=(git brew jfrog)
if [[ -f "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
else
  autoload -Uz compinit
  compinit
fi
