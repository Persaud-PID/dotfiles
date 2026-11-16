if (( $+commands[eza] )); then
  alias ls='eza --group-directories-first --icons always'
  alias ll='eza -lh --icons --git'
  alias la='eza -lah --icons --git'
  alias tree='eza --tree --icons'
fi
alias tf=terraform python=python3 rbac=rbac-lookup rmd=rmdir k=kubectl
unalias rd 2>/dev/null || true
if (( $+commands[bat] )); then
  alias cat='bat --paging=never'
fi
(( $+commands[batgrep] )) && alias bgrep='batgrep --context=0 --color --terminal-width="$(tput cols)"'
(( $+commands[batman] )) && alias man=batman
(( $+commands[jless] )) && alias -s json=jless
(( $+commands[rg] )) && alias grep='rg --color=auto'
if (( $+commands[gdiff] )); then
  alias diff='gdiff --color=auto'
elif command diff --color=auto /dev/null /dev/null >/dev/null 2>&1; then
  alias diff='diff --color=auto'
fi
if (( $+commands[bat] )); then
  alias -s {conf,config,cfg,ini,env,yaml,yml,toml,properties}=bat
  _dotfiles_script() {
    if [[ -x "$1" ]]; then
      command "$@"
    else
      command bat "$@"
    fi
  }
  alias -s {sh,bash,zsh,py,js}=_dotfiles_script
  alias -s {go,rs,ts,tsx,jsx,lua}=bat
  alias -s {tf,tfvars,hcl,css,html,xml,md,txt,log,csv,tsv}=bat
fi
if [[ "$OSTYPE" == darwin* ]]; then
  alias java11='export JAVA_HOME="$(/usr/libexec/java_home -v 11)"'
  alias java17='export JAVA_HOME="$(/usr/libexec/java_home -v 17)"'
fi
