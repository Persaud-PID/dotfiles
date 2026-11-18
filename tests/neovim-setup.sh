#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temp="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-neovim-test.XXXXXX")"
trap 'rm -rf "$temp"' EXIT
fixture="$temp/repo"
external="$temp/external config"
mkdir -p "$fixture/scripts/lib" "$fixture/brew" "$temp/bin" "$external" "$temp/home"
cp "$REPO_DIR/scripts/"{neovim-setup,install-all}.sh "$fixture/scripts/"
cp "$REPO_DIR/scripts/lib/common.sh" "$fixture/scripts/lib/"
cp "$REPO_DIR/brew/Brewfile.neovim" "$fixture/brew/"
export TEST_CALLS="$temp/calls" HOME="$temp/home"
unset COMPANY_CONFIG_DIR
export PATH="$temp/bin:/usr/bin:/bin:/usr/sbin:/sbin"
printf 'return {}\n' > "$external/init.lua"
printf '{"unchanged":true}\n' > "$external/lazy-lock.json"
cat > "$temp/bin/uname" <<'EOF'
#!/bin/sh
printf 'Darwin\n'
EOF
cat > "$temp/bin/brew" <<'EOF'
#!/bin/sh
printf 'brew %s\n' "$*" >> "$TEST_CALLS"
EOF
cat > "$temp/bin/nvim" <<'EOF'
#!/bin/sh
printf 'nvim %s\n' "$*" >> "$TEST_CALLS"
# Never start the user's config, Lazy or Mason from provisioning.
case "$*" in '--headless -u NONE -i NONE '*) ;; *) exit 93 ;; esac
[ "${TEST_OLD_NVIM:-0}" = 0 ]
EOF
cat > "$fixture/setup.sh" <<'EOF'
#!/bin/sh
printf 'setup' >> "$TEST_CALLS"
printf ' <%s>' "$@" >> "$TEST_CALLS"
printf '\n' >> "$TEST_CALLS"
EOF
for script in install-core-tools typescript-dev rust-dev go-dev terraform-dev terminals-setup \
  kubernetes-dev containers-dev cmux-setup; do
  cat > "$fixture/scripts/$script.sh" <<'EOF'
#!/bin/sh
printf 'installer %s\n' "${0##*/}" >> "$TEST_CALLS"
EOF
done
chmod +x "$temp/bin/"* "$fixture/setup.sh" "$fixture/scripts/"*.sh
bash "$fixture/scripts/neovim-setup.sh" --nvim-config "$external" > "$temp/neovim-output"
command grep -Fxq "setup <--nvim-config> <$external>" "$TEST_CALLS"
bash "$fixture/scripts/install-all.sh" --company none --nvim-config "$external" > "$temp/all-output"
command grep -Fxq "setup <--company> <none> <--nvim-config> <$external>" "$TEST_CALLS"
[[ "$(command grep -c '^nvim ' "$TEST_CALLS")" == 2 ]]
[[ "$(command grep -c '^brew bundle install --no-upgrade ' "$TEST_CALLS")" == 2 ]]
[[ "$(cat "$external/lazy-lock.json")" == '{"unchanged":true}' ]]
if bash "$fixture/scripts/install-all.sh" --nvim-config > "$temp/invalid-output" 2>&1; then
  echo "FAIL: full installer accepted a missing Neovim config argument" >&2
  exit 1
fi
[[ "$(command grep -c '^nvim ' "$TEST_CALLS")" == 2 ]]
if TEST_OLD_NVIM=1 bash "$fixture/scripts/neovim-setup.sh" > "$temp/old-version-output" 2>&1; then
  echo "FAIL: unsupported Neovim version was accepted" >&2
  exit 1
fi
[[ "$(command grep -c '^setup' "$TEST_CALLS")" == 2 ]]
mkdir -p "$temp/company configs"
printf 'company fixture\n' > "$temp/company configs/work.zsh"
bash "$fixture/scripts/install-all.sh" --company work --company-dir "$temp/company configs" > "$temp/company-output"
command grep -Fxq "setup <--company> <work> <--company-dir> <$temp/company configs>" "$TEST_CALLS"
if bash "$fixture/scripts/install-all.sh" --company missing --company-dir "$temp/company configs" > "$temp/company-invalid" 2>&1; then
  echo "FAIL: full installer accepted an unknown company" >&2
  exit 1
fi
bash "$fixture/scripts/install-all.sh" --company work --company-dir "$temp/not cloned yet" > "$temp/company-clone-output"
command grep -Fxq "setup <--company> <work> <--company-dir> <$temp/not cloned yet>" "$TEST_CALLS"
[[ "$(command grep -c '^setup' "$TEST_CALLS")" == 4 ]]
echo "PASS: Neovim system-only provisioning, full-install argument forwarding and version guard use mocks only"
