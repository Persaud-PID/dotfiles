execBash() { [[ "$#" -lt 1 ]] && { echo "Usage: execBash <image>"; return 1; }; docker run -it --entrypoint /bin/bash "$1"; }
execSh()   { [[ "$#" -lt 1 ]] && { echo "Usage: execSh <image>"; return 1; }; docker run -it --entrypoint /bin/sh "$1"; }
decode() {
  [[ "$#" -ne 1 ]] && { echo "Usage: decode <BASE64_STRING>"; return 1; }
  if [[ "$OSTYPE" == darwin* ]]; then
    printf '%s' "$1" | base64 -D
  else
    printf '%s' "$1" | base64 -d
  fi
}
cover() (
  local report
  report="$(mktemp "${TMPDIR:-/tmp}/go-cover.XXXXXX")" || return 1
  trap 'command rm -f "$report"' EXIT
  go test -coverprofile="$report" "$@" && go tool cover -html="$report"
)
