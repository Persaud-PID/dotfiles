#!/usr/bin/env bash
# All writes stay in a disposable target. No installers or real services run.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
root="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-setup-test.XXXXXX")"
trap 'rm -rf "$root"' EXIT
home="$root/home with spaces"
external="$root/configs/nvim with spaces"
mkdir -p "$external"
printf 'return {}\n' > "$external/init.lua"
printf '{"fixture":true}\n' > "$external/lazy-lock.json"
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

run_setup() { HOME="$home" NVIM_CONFIG_DIR="$external" "$REPO_DIR/setup.sh" --target "$home" "$@"; }
before="$(find "$home" -print | sort)"
run_setup --dry-run > "$root/preview"
[[ "$before" == "$(find "$home" -print | sort)" ]]
[[ "$(cat "$home/.zshrc")" == 'original zshrc' ]]
run_setup > "$root/first"
[[ "$home/.zshrc" -ef "$REPO_DIR/zsh/.zshrc" ]]
[[ "$home/.config/nvim" -ef "$external" ]]
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

alternate="$root/alternate nvim"
mkdir -p "$alternate"
printf '" fixture\n' > "$alternate/init.vim"
HOME="$home" NVIM_CONFIG_DIR="$root/missing-env" "$REPO_DIR/setup.sh" \
  --target "$home" --nvim-config "$alternate" > "$root/nvim-override.log"
[[ "$home/.config/nvim" -ef "$alternate" ]]
run_setup --skip-nvim > "$root/nvim-skip.log"
[[ "$home/.config/nvim" -ef "$alternate" ]]
[[ "$(cat "$external/lazy-lock.json")" == '{"fixture":true}' ]]

missing_home="$root/missing-config-home"
mkdir -p "$missing_home/.config/nvim" "$root/empty-config"
printf 'keep my config\n' > "$missing_home/.config/nvim/init.lua"
HOME="$missing_home" "$REPO_DIR/setup.sh" --nvim-config "$root/not-cloned" \
  > "$root/nvim-missing.log" 2>&1
[[ ! -L "$missing_home/.config/nvim" ]]
[[ "$(cat "$missing_home/.config/nvim/init.lua")" == 'keep my config' ]]
command grep -Fq 'leaving' "$root/nvim-missing.log"
HOME="$missing_home" "$REPO_DIR/setup.sh" --nvim-config "$root/empty-config" \
  > "$root/nvim-empty.log" 2>&1
[[ "$(cat "$missing_home/.config/nvim/init.lua")" == 'keep my config' ]]
mv "$missing_home/.config/nvim" "$root/preserved-nvim"
ln -s "$root/unavailable-config" "$missing_home/.config/nvim"
HOME="$missing_home" "$REPO_DIR/setup.sh" --nvim-config "$root/not-cloned" \
  > "$root/nvim-missing-symlink.log" 2>&1
[[ "$(readlink "$missing_home/.config/nvim")" == "$root/unavailable-config" ]]

# Exercise the submodule default independently of any real user checkout.
isolated="$root/default layout/dotfiles"
default_config="$isolated/nvim/.config/nvim"
default_home="$root/default-home"
mkdir -p "$isolated" "$default_config" "$default_home"
cp -p "$REPO_DIR/setup.sh" "$isolated/setup.sh"
for package in zsh starship cmux ghostty git company tmux bash alacritty-darwin alacritty-linux; do
  mkdir -p "$isolated/$package"
done
printf 'return {}\n' > "$default_config/init.lua"
env -u NVIM_CONFIG_DIR HOME="$default_home" COMPANY_NAME=none "$isolated/setup.sh" > "$root/nvim-default.log"
[[ "$default_home/.config/nvim" -ef "$default_config" ]]
default_target="$(readlink "$default_home/.config/nvim")"
mv "$default_config" "$root/uninitialized-config"
env -u NVIM_CONFIG_DIR HOME="$default_home" COMPANY_NAME=none "$isolated/setup.sh" \
  > "$root/nvim-uninitialized.log" 2>&1
[[ ! -e "$default_config" ]]
[[ "$(readlink "$default_home/.config/nvim")" == "$default_target" ]]
command grep -Fq 'leaving' "$root/nvim-uninitialized.log"
if run_setup --nvim-config > "$root/nvim-invalid.log" 2>&1; then
  echo "FAIL: missing Neovim path argument was accepted" >&2
  exit 1
fi

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
echo "PASS: preview, backups, external Neovim selection/skip safety, spaces, idempotence, company/platform selection, and conflicts"
