#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temp="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-agents-test.XXXXXX")"
trap 'rm -rf "$temp"' EXIT
mkdir -p "$temp/repo/scripts/lib" "$temp/repo/brew" "$temp/bin" \
  "$temp/node/bin" "$temp/old-node/bin" "$temp/cmux-cli-shims/test" "$temp/home/.nvm"
cp "$REPO_DIR/scripts/"{agents-setup,cmux-setup}.sh "$temp/repo/scripts/"
cp "$REPO_DIR/scripts/lib/common.sh" "$temp/repo/scripts/lib/"
cp "$REPO_DIR/brew/Brewfile.apps" "$temp/repo/brew/"
export HOME="$temp/home" NVM_DIR="$temp/home/.nvm" TEST_NODE_BIN="$temp/node/bin"
export TEST_CALLS="$temp/calls"
export PATH="$temp/cmux-cli-shims/test:$temp/old-node/bin:$temp/bin:/usr/bin:/bin:/usr/sbin:/sbin"
cat > "$NVM_DIR/nvm.sh" <<'EOF'
nvm() {
  [[ "$*" == "use --silent default" ]] || return 1
  export PATH="$TEST_NODE_BIN:$PATH"
  printf 'nvm %s\n' "$*" >> "$TEST_CALLS"
}
EOF
cat > "$temp/bin/uname" <<'EOF'
#!/bin/sh
printf 'Darwin\n'
EOF
cat > "$temp/bin/defaults" <<'EOF'
#!/bin/sh
printf 'defaults %s\n' "$*" >> "$TEST_CALLS"
EOF
cat > "$temp/bin/brew" <<'EOF'
#!/bin/sh
printf 'brew %s\n' "$*" >> "$TEST_CALLS"
if [ "$1 $2" = "list --cask" ]; then exit 1; fi
if [ "$*" = "install --cask devin-cli" ]; then
  mkdir -p "$HOME/.local/bin"
  printf '#!/bin/sh\nexit 0\n' > "$HOME/.local/bin/devin"
  chmod +x "$HOME/.local/bin/devin"
fi
EOF
cat > "$TEST_NODE_BIN/npm" <<'EOF'
#!/bin/sh
set -eu
printf 'npm %s\n' "$*" >> "$TEST_CALLS"
[ "${TEST_FAIL_NPM:-0}" = 0 ] || exit 42
case "$*" in
  'install --global --ignore-scripts @earendil-works/pi-coding-agent') agent=pi ;;
  'install --global @google/gemini-cli') agent=gemini ;;
  *) exit 90 ;;
esac
printf '#!/bin/sh\nexit 0\n' > "$TEST_NODE_BIN/$agent"
chmod +x "$TEST_NODE_BIN/$agent"
EOF
cat > "$TEST_NODE_BIN/npx" <<'EOF'
#!/bin/sh
printf 'npx %s\n' "$*" >> "$TEST_CALLS"
EOF
cat > "$temp/bin/cmux" <<'EOF'
#!/bin/sh
set -eu
printf 'cmux %s\n' "$*" >> "$TEST_CALLS"
case "$*" in
  'hooks setup --agent pi --yes'|'hooks setup --agent gemini --yes')
    [ -x "$TEST_NODE_BIN/pi" ] && [ -x "$TEST_NODE_BIN/gemini" ]
    [ "$(command -v npx)" = "$TEST_NODE_BIN/npx" ] ;;
  reload-config) ;;
  *) exit 91 ;;
esac
EOF
# Old Node and cmux wrappers must neither mask missing agents nor run installers.
for binary in "$temp/old-node/bin/npm" "$temp/old-node/bin/npx" \
  "$temp/cmux-cli-shims/test/pi" "$temp/cmux-cli-shims/test/gemini" \
  "$temp/cmux-cli-shims/test/devin"; do
  printf '#!/bin/sh\nexit 92\n' > "$binary"
done
chmod +x "$temp/bin/"* "$TEST_NODE_BIN/"* "$temp/old-node/bin/"* \
  "$temp/cmux-cli-shims/test/"* "$temp/repo/scripts/"*.sh

bash "$temp/repo/scripts/cmux-setup.sh" > "$temp/first-output"
bash "$temp/repo/scripts/cmux-setup.sh" > "$temp/repeat-output"
[[ "$(command grep -c '^npm ' "$TEST_CALLS")" == 2 ]]
[[ "$(command grep -c '^brew install --cask devin-cli$' "$TEST_CALLS")" == 1 ]]
[[ "$(command grep -c '^cmux hooks setup --agent pi --yes$' "$TEST_CALLS")" == 2 ]]
[[ "$(command grep -c '^cmux hooks setup --agent gemini --yes$' "$TEST_CALLS")" == 2 ]]
first_install="$(command grep -n '^npm ' "$TEST_CALLS" | head -n 1 | cut -d: -f1)"
first_hook="$(command grep -n '^cmux hooks ' "$TEST_CALLS" | head -n 1 | cut -d: -f1)"
[[ "$first_install" -lt "$first_hook" ]]
command grep -Fxq 'cask "obsidian"' "$temp/repo/brew/Brewfile.apps"
command grep -Fxq 'cask "ollama-app"' "$temp/repo/brew/Brewfile.apps"
command grep -Fxq 'tap "stablyai/orca"' "$temp/repo/brew/Brewfile.apps"
command grep -Fxq 'cask "stablyai/orca/orca"' "$temp/repo/brew/Brewfile.apps"

rm "$TEST_NODE_BIN/pi"
if TEST_FAIL_NPM=1 bash "$temp/repo/scripts/cmux-setup.sh" > "$temp/failure-output" 2>&1; then
  echo "FAIL: agent installation failure was ignored" >&2
  exit 1
fi
[[ "$(command grep -c '^cmux hooks ' "$TEST_CALLS")" == 4 ]]
echo "PASS: agents precede scoped hooks, cmux shims are ignored, repeat runs skip installs, failures stop hooks"
