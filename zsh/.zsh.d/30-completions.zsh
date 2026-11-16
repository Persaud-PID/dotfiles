# ------------------------------------------------------------
# ~/.zsh.d/30-completions.zsh
# Centralized completions and keybindings for zsh.
# ------------------------------------------------------------

# Local completion function dir; added to $fpath for autoloaded comps.
: "${ZSH_FUNC_DIR:=$HOME/.zsh/completions}"
mkdir -p -- "$ZSH_FUNC_DIR"
fpath=("$ZSH_FUNC_DIR" $fpath)

# Directory above must be in $fpath before oh-my-zsh initializes compinit.

# Bash-style completion support for tools that require it.
autoload -U +X bashcompinit && bashcompinit

# ----- pipx (argcomplete) -----
if command -v register-python-argcomplete >/dev/null 2>&1; then
  if [[ -z "${__PIPX_ARGCOMP_DONE:-}" ]]; then
    eval "$(register-python-argcomplete pipx)"
    __PIPX_ARGCOMP_DONE=1
  fi
fi

# ----- Terraform (bash-style completion) -----
if command -v terraform >/dev/null 2>&1; then
  if [[ -z "${__TF_BASHCOMP_DONE:-}" ]]; then
    complete -o nospace -C "$(command -v terraform)" terraform
    __TF_BASHCOMP_DONE=1
  fi
fi

# ----- AWS CLI (bash-style via aws_completer) -----
if command -v aws >/dev/null 2>&1; then
  if [[ -z "${__AWS_BASHCOMP_DONE:-}" ]]; then
    if command -v aws_completer >/dev/null 2>&1; then
      complete -C "$(command -v aws_completer)" aws
      __AWS_BASHCOMP_DONE=1
    else
      for candidate in /opt/homebrew/bin/aws_completer /usr/local/bin/aws_completer /usr/bin/aws_completer; do
        if [[ -x "$candidate" ]]; then
          complete -C "$candidate" aws
          __AWS_BASHCOMP_DONE=1
          break
        fi
      done
    fi
  fi
fi

# ----- gh (GitHub CLI) completion -----
if command -v gh >/dev/null 2>&1; then
  if [[ -z "${__GH_ZSHCOMP_DONE:-}" ]]; then
    eval "$(gh completion -s zsh)"
    __GH_ZSHCOMP_DONE=1
  fi
fi

# ----- tenv completion -----
if command -v tenv >/dev/null 2>&1; then
  if [[ -z "${__TENV_ZSHCOMP_DONE:-}" ]]; then
    eval "$(tenv completion zsh)"
    __TENV_ZSHCOMP_DONE=1
  fi
fi

# ----- nvm completion -----
if command -v nvm >/dev/null 2>&1; then
  if [[ -z "${__NVM_BASHCOMP_DONE:-}" ]]; then
    if [[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ]]; then
      source "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"
    elif [[ -s "$NVM_DIR/bash_completion" ]]; then
      source "$NVM_DIR/bash_completion"
    fi
    __NVM_BASHCOMP_DONE=1
  fi
fi

# ----- tdo-skill completion -----
if command -v tdo-skill >/dev/null 2>&1; then
  if [[ -z "${__TDO_SKILL_ZSHCOMP_DONE:-}" ]]; then
    eval "$(tdo-skill completion zsh)"
    __TDO_SKILL_ZSHCOMP_DONE=1
  fi
fi
