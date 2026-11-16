#!/usr/bin/env bash
# Link configuration only. Software installation lives in scripts/.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$HOME"
DRY_RUN=0
SKIP_NVIM=0
COMPANY="${COMPANY_NAME:-}"
BACKUP_DIR=""
PACKAGES=(zsh starship cmux ghostty git company tmux bash)
case "$(uname -s)" in
  Darwin) PACKAGES+=(alacritty-darwin) ;;
  Linux) PACKAGES+=(alacritty-linux) ;;
  *) echo "Unsupported platform" >&2; exit 1 ;;
esac

usage() {
  cat <<'EOF'
Usage: ./setup.sh [--dry-run] [--target DIR] [--company NAME|none] [--skip-nvim]
Uses GNU Stow without --adopt; conflicting files are moved to a private backup.
No packages, plugins, login-shell changes, or cmux hooks are installed here.
EOF
}
while (( $# )); do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --skip-nvim) SKIP_NVIM=1 ;;
    --target|--company)
      [[ $# -ge 2 && -n "$2" ]] || { usage >&2; exit 2; }
      if [[ "$1" == --target ]]; then TARGET="$2"; else COMPANY="$2"; fi
      shift ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done
command -v stow >/dev/null || { echo "Install GNU Stow first: brew install stow" >&2; exit 1; }
[[ -d "$TARGET" ]] || { echo "Target directory must already exist: $TARGET" >&2; exit 1; }
TARGET="$(cd "$TARGET" && pwd -P)"
if [[ -z "$COMPANY" && -L "$TARGET/.zsh/company.zsh" ]]; then
  COMPANY="$(basename "$(readlink "$TARGET/.zsh/company.zsh")" .zsh)"
fi
if [[ -n "$COMPANY" && "$COMPANY" != none ]]; then
  case "$COMPANY" in *[!a-zA-Z0-9_-]*) echo "Invalid company name" >&2; exit 2 ;; esac
  [[ -f "$REPO_DIR/company/.zsh/companies/$COMPANY.zsh" ]] || {
    echo "Unknown company: $COMPANY" >&2; exit 2;
  }
fi

backup() {
  local path="$1" relative="${1#"$TARGET"/}"
  [[ -e "$path" || -L "$path" ]] || return 0
  if (( DRY_RUN )); then
    printf 'Would back up: %s\n' "$path"
    return
  fi
  if [[ -z "$BACKUP_DIR" ]]; then
    BACKUP_DIR="$(mktemp -d "$TARGET/.dotfiles_backup_$(date +%Y%m%d_%H%M%S).XXXXXX")"
    chmod 700 "$BACKUP_DIR"
  fi
  mkdir -p "$BACKUP_DIR/$(dirname "$relative")"
  mv "$path" "$BACKUP_DIR/$relative"
}
link_config() {
  local source="$1" destination="$2"
  [[ "$source" -ef "$destination" ]] && return 0
  backup "$destination"
  if (( DRY_RUN )); then
    printf 'Would link: %s -> %s\n' "$destination" "$source"
  else
    mkdir -p "$(dirname "$destination")"
    ln -s "$source" "$destination"
  fi
}

# Refuse directory-level conflicts before touching files. Never adopt or write
# through a foreign directory symlink into another dotfiles repository.
for package in "${PACKAGES[@]}"; do
  while IFS= read -r -d '' directory; do
    relative="${directory#"$REPO_DIR/$package"}"
    destination="$TARGET$relative"
    if [[ -L "$destination" || ( -e "$destination" && ! -d "$destination" ) ]]; then
      echo "Directory conflict (left untouched): $destination" >&2
      exit 1
    fi
  done < <(find "$REPO_DIR/$package" -type d -print0)
done
if [[ -L "$TARGET/.zsh" || ( -e "$TARGET/.zsh" && ! -d "$TARGET/.zsh" ) ]]; then
  echo "Private ~/.zsh must be a real directory (left untouched)." >&2
  exit 1
fi
# Retire only old links owned by this repository, never unrelated private files.
for legacy in aws git kubernetes completions plugins; do
  old="$TARGET/.zsh/$legacy.zsh"
  if [[ -L "$old" ]]; then
    case "$(readlink "$old")" in
      "$REPO_DIR/tools/"*|"$REPO_DIR/core/"*) backup "$old" ;;
    esac
  fi
done
# Stow cannot retire paths removed from a package. Back up only our old links,
# including relative links, without traversing foreign namespace symlinks.
old_companies="$TARGET/.config/laptop-setup/companies"
if [[ ! -L "$TARGET/.config/laptop-setup" && ! -L "$old_companies" ]]; then
  for old in "$old_companies/"*.zsh; do
    [[ -L "$old" ]] || continue
    link="$(readlink "$old")"
    suffix="/company/.config/laptop-setup/companies/$(basename "$old")"
    if [[ "$link" == *"$suffix" ]]; then
      owner="${link%"$suffix"}"
      [[ "$owner" == /* ]] || owner="$old_companies/$owner"
      if [[ "$owner" -ef "$REPO_DIR" ]]; then backup "$old"; fi
    fi
  done
fi
if (( ! SKIP_NVIM )) && [[ ! -f "$REPO_DIR/nvim/.config/nvim/init.lua" ]]; then
  if (( DRY_RUN )); then
    echo "Would initialize the pinned Neovim submodule."
  else
    git -C "$REPO_DIR" submodule update --init --recursive -- nvim/.config/nvim
  fi
fi

for package in "${PACKAGES[@]}"; do
  while IFS= read -r -d '' source; do
    relative="${source#"$REPO_DIR/$package/"}"
    destination="$TARGET/$relative"
    if [[ ! "$source" -ef "$destination" ]]; then
      backup "$destination"
    fi
  done < <(find "$REPO_DIR/$package" -type f ! -name '*.cmux-write.lock' ! -name '.DS_Store' -print0)
done
if (( DRY_RUN )); then
  printf 'Would stow into %s: %s\n' "$TARGET" "${PACKAGES[*]}"
else
  stow --dir="$REPO_DIR" --target="$TARGET" --no-folding \
    --ignore='\.cmux-write\.lock$|(^|/)\.DS_Store$' --restow "${PACKAGES[@]}"
fi
if (( ! SKIP_NVIM )); then
  link_config "$REPO_DIR/nvim/.config/nvim" "$TARGET/.config/nvim"
fi
if [[ "$COMPANY" == none ]]; then
  backup "$TARGET/.zsh/company.zsh"
elif [[ -n "$COMPANY" ]]; then
  link_config "$REPO_DIR/company/.zsh/companies/$COMPANY.zsh" "$TARGET/.zsh/company.zsh"
fi

# Include only our defaults; user identity, credentials, and corporate includes
# remain in the user's existing .gitconfig.
git_include="$TARGET/.config/git/laptop-setup.gitconfig"
if ! git config --file "$TARGET/.gitconfig" --get-all include.path 2>/dev/null | command grep -Fxq "$git_include"; then
  if (( DRY_RUN )); then
    echo "Would include Git defaults in $TARGET/.gitconfig"
  else
    if [[ -f "$TARGET/.gitconfig" ]]; then
      if [[ -z "$BACKUP_DIR" ]]; then
        BACKUP_DIR="$(mktemp -d "$TARGET/.dotfiles_backup_$(date +%Y%m%d_%H%M%S).XXXXXX")"
        chmod 700 "$BACKUP_DIR"
      fi
      cp -pL "$TARGET/.gitconfig" "$BACKUP_DIR/gitconfig.before-include"
    fi
    git config --file "$TARGET/.gitconfig" --add include.path "$git_include"
  fi
fi
[[ -z "$BACKUP_DIR" ]] || printf 'Backups: %s\n' "$BACKUP_DIR"
printf 'Configuration %s. Open a new shell to load Zsh modules.\n' "$([[ "$DRY_RUN" == 1 ]] && echo previewed || echo linked)"
