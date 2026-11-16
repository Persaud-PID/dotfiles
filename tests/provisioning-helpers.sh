#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temp="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-provisioning-test.XXXXXX")"
trap 'rm -rf "$temp"' EXIT
mkdir -p "$temp/bin" "$temp/home"
export TEST_CALLS="$temp/calls"
export TEST_ALIAS_MODULE="$REPO_DIR/zsh/.zsh.d/75-common-aliases.zsh"
cat > "$temp/bin/curl" <<'EOF'
#!/bin/sh
while [ "$#" -gt 0 ]; do
  if [ "$1" = -o ]; then shift; destination="$1"; fi
  shift
done
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "$TEST_CALLS"\n' > "$destination"
EOF
cat > "$temp/bin/uname" <<'EOF'
#!/bin/sh
printf '%s\n' Linux
EOF
cat > "$temp/bin/sudo" <<'EOF'
#!/bin/sh
exec "$@"
EOF
cat > "$temp/bin/apt-get" <<'EOF'
#!/bin/sh
printf 'apt-get %s\n' "$*" >> "$TEST_CALLS"
EOF
chmod +x "$temp/bin/"*
(
  export HOME="$temp/home" PATH="$temp/bin:$PATH"
  source "$REPO_DIR/scripts/lib/common.sh"
  if is_macos; then exit 1; fi
  download_run https://example.invalid/installer sh --test-flag 'argument with spaces'
  apt_install stow zsh
)
command grep -Fxq -- '--test-flag argument with spaces' "$TEST_CALLS"
command grep -Fxq -- 'apt-get install -y stow zsh' "$TEST_CALLS"
cat > "$temp/probe.sh" <<'EOF'
#!/bin/sh
printf '%s\n' "$1"
EOF
chmod +x "$temp/probe.sh"
cat > "$temp/suffix-test.zsh" <<'EOF'
source "$TEST_ALIAS_MODULE"
./probe.sh --executable-script
EOF
(cd "$temp" && zsh -f suffix-test.zsh) > "$temp/suffix-output"
command grep -Fxq -- '--executable-script' "$temp/suffix-output"
echo "PASS: installer argument forwarding and Linux package routing use mocks only"
