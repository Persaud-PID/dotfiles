############################################################
# git.zsh — Git branch flow & PR helpers
# Loaded from ~/.zsh.d by the Stow-managed .zshrc.
############################################################

head-branch() {
  local b

  # Authoritative: ask the remote what HEAD points to
  b=$(git ls-remote --symref origin HEAD 2>/dev/null \
      | awk '/^ref:/ {sub("refs/heads/","",$2); print $2; exit}')
  [[ -n "$b" ]] && { echo "$b"; return 0; }

  # Fallbacks (offline / weird remotes)
  b=$(git remote show origin 2>/dev/null | awk -F': ' '/HEAD branch/ {print $2; exit}')
  [[ -n "$b" ]] && { echo "$b"; return 0; }

  b=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
  [[ -n "$b" ]] && { echo "${b#origin/}"; return 0; }

  echo "head-branch: couldn't determine origin HEAD branch" >&2
  return 1
}

bugfix(){ [[ "$#" -lt 1 ]] && { echo "Usage: bugfix ABC-123-bugfix_name"; return 1; }; local base; base=$(head-branch) || return 1; echo INFO: Creating branch for "$1"; git checkout "$base" && git fetch origin && git rebase "origin/$base" && git checkout -b "bugfix/$1" && git push --set-upstream origin "bugfix/$1"; }
hotfix(){ [[ "$#" -lt 1 ]] && { echo "Usage: hotfix ABC-123-hotfix_name"; return 1; }; local base; base=$(head-branch) || return 1; echo INFO: Creating branch for "$1"; git checkout "$base" && git fetch origin && git rebase "origin/$base" && git checkout -b "hotfix/$1" && git push --set-upstream origin "hotfix/$1"; }
feature(){ [[ "$#" -lt 1 ]] && { echo "Usage: feature ABC-123-feature_name"; return 1; }; local base; base=$(head-branch) || return 1; echo INFO: Creating branch for "$1"; git checkout "$base" && git fetch origin && git rebase "origin/$base" && git checkout -b "feature/$1" && git push --set-upstream origin "feature/$1"; }
chore(){ [[ "$#" -lt 1 ]] && { echo "Usage: chore ABC-123-chore_name"; return 1; }; local base; base=$(head-branch) || return 1; echo INFO: Creating branch for "$1"; git checkout "$base" && git fetch origin && git rebase "origin/$base" && git checkout -b "chore/$1" && git push --set-upstream origin "chore/$1"; }
createRequest(){
  local base head remote_url host repo_path web_base url
  base=$(head-branch) || return 1
  head=$(git branch --show-current) || return 1
  [[ -z "$head" ]] && { echo "Not on a branch"; return 1; }

  echo INFO: Preparing change request from "$(pwd)" for "$head"
  git push -u origin "$head" || return 1
  remote_url=$(git remote get-url origin) || return 1

  if [[ "$remote_url" =~ ^git@([^:]+):(.+)\.git$ ]]; then
    host="${match[1]}"
    repo_path="${match[2]}"
    web_base="https://$host"
  elif [[ "$remote_url" =~ ^https?://([^/]+)/(.+?)(\.git)?$ ]]; then
    host="${match[1]}"
    repo_path="${match[2]}"
    web_base="https://$host"
  else
    echo "Unsupported remote URL: $remote_url"
    return 1
  fi

  if [[ "$host" == "github.com" ]]; then
    url="$web_base/$repo_path/compare/$base...$head?expand=1"
  elif [[ "$host" == gitlab* ]]; then
    url="$web_base/$repo_path/-/merge_requests/new?merge_request[source_branch]=$head&merge_request[target_branch]=$base"
  else
    echo "Unknown host '$host'. Branch pushed; open PR/MR manually."
    return 0
  fi

  echo "Open: $url"
  command -v open >/dev/null 2>&1 && open "$url"
}

gitdiff() { git diff --name-only --relative --diff-filter=d | xargs batdiff; }
