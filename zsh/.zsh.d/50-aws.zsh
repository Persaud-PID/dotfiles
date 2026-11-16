############################################################
# aws.zsh — AWS profile workflow & cloud helpers
# Loaded from ~/.zsh.d by the Stow-managed .zshrc.
############################################################

## Aliases
alias sso="aws-sso-util login --all"
alias sso-logout="aws-sso-util logout"

########## AWS profile workflow (no auto-persist) ##########
# Clear AWS env quickly
unset_aws_env() {
  unset AWS_PROFILE AWS_DEFAULT_PROFILE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY \
        AWS_SESSION_TOKEN AWS_REGION AWS_DEFAULT_REGION AWS_ROLE_ARN \
        AWS_WEB_IDENTITY_TOKEN_FILE AWS_SECURITY_TOKEN
}
alias unsetAWS='unset_aws_env'

# Keep persisted profiles out of the source-controlled .zshrc.
_aws_detect_rc() {
  if [[ -n ${ZSH_VERSION:-} ]]; then
    echo "$HOME/.zsh/aws-profile.zsh"
  elif [[ -n ${BASH_VERSION:-} && -f "$HOME/.bashrc" ]]; then
    echo "$HOME/.bashrc"
  elif [[ -f "$HOME/.bash_profile" ]]; then
    echo "$HOME/.bash_profile"
  else
    echo "$HOME/.profile"
  fi
}

# List profiles (bypass any grep aliases)
_aws_list_profiles() {
  local cfg="$HOME/.aws/config" cred="$HOME/.aws/credentials"

  {
    if [[ -f "$cfg" ]]; then
      command grep -E '^\[(profile [^]]+|default)\]' "$cfg" \
        | sed -E 's/^\[profile ([^]]+)\]$/\1/; s/^\[default\]$/default/'
    fi
    true
  } \
  ; {
    if [[ -f "$cred" ]]; then
      command grep -E '^\[[^]]+\]' "$cred" \
        | sed -E 's/^\[([^]]+)\]$/\1/'
    fi
    true
  } \
  | command grep -viE '^sso([- ]session)?[[:space:]]' \
  | sort -u
}

# Region for profile
_aws_profile_region() {
  local profile="$1" cfg="$HOME/.aws/config" r=""
  if command -v aws >/dev/null 2>&1; then
    r="$(aws configure get region --profile "$profile" 2>/dev/null || true)"
    [[ -n "$r" ]] && { print -r -- "$r"; return; }
  fi
  [[ -f "$cfg" ]] || return
  awk -v p="$profile" '
    BEGIN { inside=0 }
    /^\[/ { inside=0;
      if ($0 ~ "^\\[profile[[:space:]]" p "\\]$") { inside=1; next }
      if ($0 ~ "^\\[default\\]$" && p=="default") { inside=1; next }
      next
    }
    inside && /^[[:space:]]*region[[:space:]]*=/ {
      sub(/^[[:space:]]*region[[:space:]]*=[[:space:]]*/,""); sub(/[[:space:]]+$/,""); print; exit
    }
  ' "$cfg"
}

# fzf preview
_aws_profile_preview() {
  local p="$1" r; r="$(_aws_profile_region "$p")"
  echo "Profile:  $p"
  echo "Region:   ${r:-"(not set)"}"
  echo "Source:   ~/.aws/config and/or ~/.aws/credentials"
}

# Read stdin lines into array (portable)
_read_lines_into_array() {
  local __out="$1"
  if [[ -n ${BASH_VERSION:-} ]]; then
    local -a __tmp; mapfile -t __tmp; eval "$__out=()"; local x
    for x in "${__tmp[@]}"; do eval "$__out+=(\"\$x\")"; done
  elif [[ -n ${ZSH_VERSION:-} ]]; then
    local -a __tmp; __tmp=("${(@f)$(cat)}"); eval "$__out=()"; local x
    for x in "${__tmp[@]}"; do eval "$__out+=(\"\$x\")"; done
  else
    eval "$__out=()"; local line
    while IFS= read -r line; do eval "$__out+=(\"\$line\")"; done
  fi
}

# Pick a profile via gum/fzf/basic
_aws_pick_profile() {
  local picker="${AWSPROF_PICKER:-auto}" chosen
  local -a _list
  # read stdin into _list
  if [[ -n ${BASH_VERSION:-} ]]; then
    mapfile -t _list
  else
    _list=("${(@f)$(cat)}")
  fi

  (( ${#_list[@]} )) || { echo "No profiles found" >&2; return 1; }

  case "$picker" in
    gum) command -v gum >/dev/null && chosen="$(printf '%s\n' "${_list[@]}" | gum filter --placeholder 'Type to filter AWS profiles' --prompt 'AWS > ')" ;;
    fzf) command -v fzf >/dev/null && chosen="$(printf '%s\n' "${_list[@]}" | fzf --prompt='AWS > ' --height=60% --layout=reverse --border --preview='_aws_profile_preview {}' --preview-window=down:4:wrap)" ;;
  esac

  if [[ -z "$chosen" ]]; then
    if command -v gum >/dev/null 2>&1; then
      chosen="$(printf '%s\n' "${_list[@]}" | gum filter --placeholder 'Type to filter AWS profiles' --prompt 'AWS > ')"
    elif command -v fzf >/dev/null 2>&1; then
      chosen="$(printf '%s\n' "${_list[@]}" | fzf --prompt='AWS > ' --height=60% --layout=reverse --border --preview='_aws_profile_preview {}' --preview-window=down:4:wrap)"
    else
      echo "Select an AWS profile:" >&2
      local i=1 p
      for p in "${_list[@]}"; do printf '  %d) %s\n' "$i" "$p" >&2; ((i++)); done
      printf 'Enter number: ' >&2
      local idx; read -r idx
      (( idx>=1 && idx<=${#_list[@]} )) || return 1
      chosen="${_list[idx-1]}"
    fi
  fi

  printf '%s' "$chosen"
}

# OPTIONAL: persistence helper (used only when you ask for it)
_aws_persist_profile() {
  local profile="$1" region="$2" rc="$(_aws_detect_rc)"
  local sed_inplace=(-i) ; sed --version >/dev/null 2>&1 || sed_inplace=(-i '')
  mkdir -p "${rc:h}"
  touch "$rc"
  grep -q '^export AWS_SDK_LOAD_CONFIG=1' "$rc" || printf '\nexport AWS_SDK_LOAD_CONFIG=1\n' >> "$rc"
  if grep -q '^export AWS_PROFILE=' "$rc"; then
    sed "${sed_inplace[@]}" -E "s|^export AWS_PROFILE=.*$|export AWS_PROFILE=${profile}|" "$rc"
  else
    printf 'export AWS_PROFILE=%s\n' "$profile" >> "$rc"
  fi
  if [[ -n "$region" ]]; then
    if grep -q '^export AWS_REGION=' "$rc"; then
      sed "${sed_inplace[@]}" -E "s|^export AWS_REGION=.*$|export AWS_REGION=${region}|" "$rc"
    else
      printf 'export AWS_REGION=%s\n' "$region" >> "$rc"
    fi
    if grep -q '^export AWS_DEFAULT_REGION=' "$rc"; then
      sed "${sed_inplace[@]}" -E "s|^export AWS_DEFAULT_REGION=.*$|export AWS_DEFAULT_REGION=${region}|" "$rc"
    else
      printf 'export AWS_DEFAULT_REGION=%s\n' "$region" >> "$rc"
    fi
  fi
  echo "Persisted to $rc"
}

# Core switcher: NON-PERSIST by default
awsprof() {
  # Usage: awsprof [PROFILE_NAME]  (no persistence)
  local chosen region
  if [[ -n "${1:-}" ]]; then
    chosen="$1"
  else
    chosen="$(_aws_list_profiles | _aws_pick_profile)" || return 1
  fi
  unset_aws_env
  export AWS_PROFILE="$chosen"
  region="$(_aws_profile_region "$chosen")"
  if [[ -n "$region" ]]; then
    export AWS_REGION="$region" AWS_DEFAULT_REGION="$region"
  fi
  export AWS_SDK_LOAD_CONFIG=1
  echo "Now using AWS_PROFILE=$AWS_PROFILE${region:+ (region=$region)}"
}

# Convenience wrappers:
#   useprof  -> only current shell
#   saveprof -> also write to your rc file (when you explicitly want that)
useprof()  { unsetAWS; awsprof "${1:-}"; }
saveprof() { unsetAWS; local p="${1:-}"; [[ -z "$p" ]] && p="$(_aws_list_profiles | _aws_pick_profile)" || true
             [[ -z "$p" ]] && return 1
             export AWS_PROFILE="$p"
             local r="$(_aws_profile_region "$p")"
             [[ -n "$r" ]] && export AWS_REGION="$r" AWS_DEFAULT_REGION="$r"
             _aws_persist_profile "$AWS_PROFILE" "$r"; echo "Re-source your rc for new terminals." ; }

alias sso="aws-sso-util login --all"
alias sso-logout="aws-sso-util logout"

# If you need a persistent default sometimes, call:  saveprof <profile>

########## AWS & cloud helpers ##########
# Delete secrets or log groups
deleteAwsResource() {
  local resource_type="$1" resource_id="$2" region="$3"
  if [[ -z "$resource_type" || -z "$resource_id" || -z "$region" ]]; then
    echo "Usage: deleteAwsResource <--secret|--log-group> <resource-id> <region>"; return 1
  fi
  case "$resource_type" in
    --secret)    echo "Deleting secret: $resource_id ($region)"; aws secretsmanager delete-secret --secret-id "$resource_id" --force-delete-without-recovery --region "$region" ;;
    --log-group) echo "Deleting log group: $resource_id ($region)"; aws logs delete-log-group --log-group-name "$resource_id" --region "$region" ;;
    *) echo "Invalid type"; return 1 ;;
  esac
}
