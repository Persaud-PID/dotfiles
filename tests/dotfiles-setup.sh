#!/usr/bin/env bash
# All writes stay in a disposable target. No installers or real services run.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
root="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-setup-test.XXXXXX")"
trap 'rm -rf "$root"' EXIT
home="$root/home with spaces"
mkdir -p "$home/.config/nvim" "$home/.config/cmux" "$home/.zsh" "$home/.config/laptop-setup/companies"
printf 'original zshrc\n' > "$home/.zshrc"
printf 'original prompt\n' > "$home/.config/starship.toml"
printf 'original editor\n' > "$home/.config/nvim/init.lua"
printf '{"app":{"appearance":"light"}}\n' > "$home/.config/cmux/cmux.json"
printf 'private fixture\n' > "$home/.zsh/secrets.env"
printf '[user]\n    name = Fixture User\n' > "$home/.gitconfig"
ln -s "$REPO_DIR/zshrc" "$home/.zsh/old-unrelated-link"
ln -s "$REPO_DIR" "$home/repository"
ln -s "$REPO_DIR/company/.config/laptop-setup/companies/zscaler.zsh" "$home/.zsh/company.zsh"
ln -s "$REPO_DIR/company/.config/laptop-setup/companies/zscaler.zsh" "$home/.config/laptop-setup/companies/zscaler.zsh"
ln -s "../../../repository/company/.config/laptop-setup/companies/chewy.zsh" "$home/.config/laptop-setup/companies/chewy.zsh"
ln -s "$root/other-repo/company/.config/laptop-setup/companies/custom.zsh" "$home/.config/laptop-setup/companies/custom.zsh"
printf 'private company config\n' > "$home/.config/laptop-setup/companies/private.zsh"

run_setup() { HOME="$home" "$REPO_DIR/setup.sh" --target "$home" "$@"; }
before="$(find "$home" -print | sort)"
run_setup --dry-run > "$root/preview"
[[ "$before" == "$(find "$home" -print | sort)" ]]
[[ "$(cat "$home/.zshrc")" == 'original zshrc' ]]
run_setup > "$root/first"
[[ "$home/.zshrc" -ef "$REPO_DIR/zsh/.zshrc" ]]
[[ "$home/.config/nvim" -ef "$REPO_DIR/nvim/.config/nvim" ]]
[[ "$home/.config/cmux/cmux.json" -ef "$REPO_DIR/cmux/.config/cmux/cmux.json" ]]
[[ "$home/.tmux.conf" -ef "$REPO_DIR/tmux/.tmux.conf" ]]
[[ "$home/.bashrc" -ef "$REPO_DIR/bash/.bashrc" ]]
case "$(uname -s)" in Darwin) platform=darwin ;; Linux) platform=linux ;; esac
[[ "$home/.config/alacritty/alacritty.toml" -ef "$REPO_DIR/alacritty-$platform/.config/alacritty/alacritty.toml" ]]
[[ "$home/.zsh/company.zsh" -ef "$REPO_DIR/company/.zsh/companies/zscaler.zsh" ]]
[[ "$home/.zsh/companies/chewy.zsh" -ef "$REPO_DIR/company/.zsh/companies/chewy.zsh" ]]
[[ ! -L "$home/.config/laptop-setup/companies/zscaler.zsh" ]]
[[ ! -L "$home/.config/laptop-setup/companies/chewy.zsh" ]]
[[ -L "$home/.config/laptop-setup/companies/custom.zsh" ]]
[[ "$(cat "$home/.config/laptop-setup/companies/private.zsh")" == 'private company config' ]]
[[ "$(cat "$home/.zsh/secrets.env")" == 'private fixture' ]]
[[ -L "$home/.zsh/old-unrelated-link" ]]
[[ "$(git config --file "$home/.gitconfig" user.name)" == 'Fixture User' ]]
backup="$(find "$home" -maxdepth 1 -type d -name '.dotfiles_backup_*')"
[[ -n "$backup" && "$(cat "$backup/.zshrc")" == 'original zshrc' ]]
[[ "$(cat "$backup/.config/nvim/init.lua")" == 'original editor' ]]
[[ -L "$backup/.config/laptop-setup/companies/zscaler.zsh" ]]
[[ -L "$backup/.config/laptop-setup/companies/chewy.zsh" ]]
count="$(find "$home" -maxdepth 1 -type d -name '.dotfiles_backup_*' | wc -l)"
run_setup --company zscaler > "$root/second"
[[ "$count" == "$(find "$home" -maxdepth 1 -type d -name '.dotfiles_backup_*' | wc -l)" ]]
[[ "$(git config --file "$home/.gitconfig" --get-all include.path | wc -l | tr -d ' ')" == 1 ]]
run_setup --company none > "$root/none"
[[ ! -e "$home/.zsh/company.zsh" && ! -L "$home/.zsh/company.zsh" ]]
run_setup --company chewy > "$root/chewy"
[[ "$home/.zsh/company.zsh" -ef "$REPO_DIR/company/.zsh/companies/chewy.zsh" ]]
run_setup > "$root/retain-company"
[[ "$home/.zsh/company.zsh" -ef "$REPO_DIR/company/.zsh/companies/chewy.zsh" ]]

conflict="$root/directory-conflict"
mkdir -p "$conflict" "$root/foreign"
ln -s "$root/foreign" "$conflict/.zsh.d"
printf 'untouched\n' > "$conflict/.zshrc"
if HOME="$conflict" "$REPO_DIR/setup.sh" --target "$conflict" --skip-nvim > "$root/conflict.log" 2>&1; then
  echo "FAIL: foreign directory symlink was not refused" >&2
  exit 1
fi
[[ -L "$conflict/.zsh.d" && "$(cat "$conflict/.zshrc")" == untouched ]]
legacy_conflict="$root/legacy-namespace-symlink"
mkdir -p "$legacy_conflict/.config" "$root/foreign/companies"
ln -s "$REPO_DIR/company/.config/laptop-setup/companies/zscaler.zsh" "$root/foreign/companies/zscaler.zsh"
ln -s "$root/foreign" "$legacy_conflict/.config/laptop-setup"
HOME="$legacy_conflict" "$REPO_DIR/setup.sh" --skip-nvim > "$root/legacy-conflict.log"
[[ -L "$root/foreign/companies/zscaler.zsh" ]]
mkdir -p "$root/mock" "$root/linux-home"
cat > "$root/mock/uname" <<'EOF'
#!/bin/sh
printf '%s\n' Linux
EOF
chmod +x "$root/mock/uname"
PATH="$root/mock:$PATH" HOME="$root/linux-home" "$REPO_DIR/setup.sh" --skip-nvim > "$root/linux.log"
[[ "$root/linux-home/.config/alacritty/alacritty.toml" -ef "$REPO_DIR/alacritty-linux/.config/alacritty/alacritty.toml" ]]
if run_setup --company missing-company > "$root/invalid.log" 2>&1; then
  echo "FAIL: unknown company was accepted" >&2
  exit 1
fi
echo "PASS: preview, backups, spaces, idempotence, company migration/choice, platform selection, and conflict safety"
