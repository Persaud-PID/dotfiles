#!/bin/zsh

typeset -g ROTATION_TEST_REPO_ROOT="${0:A:h:h}"

main() {
emulate -L zsh
unsetopt xtrace verbose allexport
umask 077
local repo_root="$ROTATION_TEST_REPO_ROOT"
local original_path="$PATH"
local test_root
if ! test_root="$(command mktemp -d "${TMPDIR:-/tmp}/gitlab-token-rotation-tests.XXXXXX")"; then
  print -u2 -- "FAIL: could not create private test workspace"
  exit 1
fi
command chmod 700 "$test_root" || exit 1
local mock_bin="$test_root/bin"
local test_tmp="$test_root/tmp"
local state="$test_root/state"
command mkdir -m 700 "$mock_bin" "$test_tmp" "$state" || exit 1
local item_file="$state/item.json"
local response_file="$state/response.json"
local old_token_file="$state/current-token"
local new_token_file="$state/new-token"
local item_id='syntheticitemfixture0001'
local workspace="$test_tmp/gitlab-token-rotation-${UID}-${item_id}"
local secret_old="synthetic-old-token-${$}"
local secret_new="synthetic-new-token-${$}"
local passes=0
local failures=0
local rotate_status=0
trap 'command rm -r "$test_root" 2>/dev/null' EXIT
export TEST_STATE="$state" TEST_ITEM_FILE="$item_file" TEST_RESPONSE_FILE="$response_file"
export TEST_OLD_TOKEN_FILE="$old_token_file" TEST_NEW_TOKEN_FILE="$new_token_file"
export TEST_EXPECTED_ITEM_ID="$item_id" TEST_SAFE_MODE=1 TMPDIR="$test_tmp"
export GITLAB_ROTATION_HOST=gitlab.example.com GITLAB_ROTATION_OP_ITEM_ID="$item_id"
PATH="$mock_bin:$original_path"
export PATH

cat > "$mock_bin/date" <<'MOCK_DATE'
#!/bin/sh
[ "$#" -eq 3 ] && [ "$1" = -u ] && [ "$2" = -v+90d ] && [ "$3" = +%Y-%m-%d ] || exit 90
[ "${TEST_DATE_FAIL:-0}" = 0 ] || exit 2
printf '%s\n' 2027-01-06
MOCK_DATE

cat > "$mock_bin/op" <<'MOCK_OP'
#!/bin/sh
[ "${TEST_SAFE_MODE:-0}" = 1 ] || exit 90
[ -z "${current_item:-}${field_snapshot:-}${current_token:-}${response_token:-}" ] || exit 89
[ "$1" = item ] || exit 91
case "$2" in
  get)
    [ "$3" = "$TEST_EXPECTED_ITEM_ID" ] || exit 92
    shift 3
    [ "$1" = --vault ] && [ "$2" = Employee ] || exit 93
    [ "$3" = --format ] && [ "$4" = json ] && [ "$5" = --reveal ] || exit 94
    count=0
    [ -f "$TEST_STATE/get-count" ] && read -r count < "$TEST_STATE/get-count"
    count=$((count + 1))
    printf '%s\n' "$count" > "$TEST_STATE/get-count"
    [ "${TEST_FAIL_GET:-0}" = 0 ] || exit 31
    cat "$TEST_ITEM_FILE"
    ;;
  edit)
    [ "$3" = "$TEST_EXPECTED_ITEM_ID" ] || exit 95
    [ "$4" = --vault ] && [ "$5" = Employee ] || exit 96
    printf '%s\n' "$*" > "$TEST_STATE/edit-args"
    count=0
    [ -f "$TEST_STATE/edit-count" ] && read -r count < "$TEST_STATE/edit-count"
    count=$((count + 1))
    printf '%s\n' "$count" > "$TEST_STATE/edit-count"
    cat > "$TEST_STATE/edited-item.json" || exit 97
    [ "${TEST_FAIL_EDIT:-0}" = 0 ] || exit 32
    cp "$TEST_STATE/edited-item.json" "$TEST_ITEM_FILE"
    ;;
  *) exit 98 ;;
esac
MOCK_OP

cat > "$mock_bin/curl" <<'MOCK_CURL'
#!/bin/sh
[ "${TEST_SAFE_MODE:-0}" = 1 ] || exit 90
[ -z "${current_item:-}${field_snapshot:-}${current_token:-}${response_token:-}" ] || exit 89
[ "${1:-}" = -q ] || exit 101
count=0
[ -f "$TEST_STATE/curl-count" ] && read -r count < "$TEST_STATE/curl-count"
count=$((count + 1))
printf '%s\n' "$count" > "$TEST_STATE/curl-count"
output_file=
header_spec=
url=
proto=
ca_file=
connect_timeout=
max_time=
request_method=
last_arg=
for arg in "$@"; do
  case "$last_arg" in
    --output) output_file="$arg" ;;
    --header) header_spec="$arg" ;;
    --url) url="$arg" ;;
    --proto) proto="$arg" ;;
    --cacert) ca_file="$arg" ;;
    --connect-timeout) connect_timeout="$arg" ;;
    --max-time) max_time="$arg" ;;
    --request) request_method="$arg" ;;
  esac
  case "$arg" in
    *synthetic-old-token-*|*synthetic-new-token-*|-L|--location|--retry|--retry-all-errors|--insecure|-k) exit 102 ;;
    *) ;;
  esac
  printf '%s\n' "$arg" >> "$TEST_STATE/curl-args"
  last_arg="$arg"
done
[ "$header_spec" = @- ] && [ "$proto" = '=https' ] && [ "$connect_timeout" = 10 ] && [ "$max_time" = 60 ] && [ "$request_method" = POST ] || exit 103
[ "$ca_file" = "$TEST_CURL_CA_FILE" ] || exit 104
[ "$url" = 'https://gitlab.example.com/api/v4/personal_access_tokens/self/rotate?expires_at=2027-01-06' ] || exit 105
IFS= read -r request_header || exit 106
expected_token=$(cat "$TEST_OLD_TOKEN_FILE") || exit 107
[ "$request_header" = "PRIVATE-TOKEN: $expected_token" ] || exit 108
printf '%s\n' "$request_header" > "$TEST_STATE/header"
[ "${TEST_TRANSPORT_FAIL:-0}" = 0 ] || exit 7
cp "$TEST_RESPONSE_FILE" "$output_file" || exit 109
printf '%s' "${TEST_HTTP_STATUS:-200}"
MOCK_CURL
command chmod 700 "$mock_bin/date" "$mock_bin/op" "$mock_bin/curl" || exit 1

pass() { passes=$((passes + 1)); }
fail() { failures=$((failures + 1)); print -u2 -- "FAIL: $1"; }
assert_eq() { if [[ "$1" == "$2" ]]; then pass; else fail "$3"; fi; }
assert_true() { if [[ "$1" == 1 || "$1" == true ]]; then pass; else fail "$2"; fi; }

make_fixture() {
  if [[ -L "$workspace" ]]; then command rm "$workspace"; elif [[ -d "$workspace" ]]; then command rm -r "$workspace"; fi
  command rm -f "$item_file" "$response_file" "$old_token_file" "$new_token_file" "$state/get-count" "$state/edit-count" "$state/curl-count" "$state/edit-args" "$state/curl-args" "$state/header" "$state/stdout" "$state/stderr"
  print -rn -- "$secret_old" > "$old_token_file"
  print -rn -- "$secret_new" > "$new_token_file"
  cat > "$item_file" <<EOF
{"id":"$item_id","title":"Synthetic GitLab credential","category":"API_CREDENTIAL","tags":["synthetic"],"urls":[{"label":"website","url":"https://gitlab.example.com"}],"fields":[{"id":"credential","type":"CONCEALED","label":"credential","value":"$secret_old"},{"id":"username","type":"STRING","label":"username","value":"synthetic-user"},{"id":"extra","type":"STRING","label":"extra","value":"preserve me"}]}
EOF
  cat > "$response_file" <<EOF
{"token":"$secret_new","expires_at":"2027-01-06"}
EOF
  command chmod 600 "$item_file" "$response_file" "$old_token_file" "$new_token_file"
  unset TEST_FAIL_GET TEST_FAIL_EDIT TEST_TRANSPORT_FAIL TEST_HTTP_STATUS TEST_DATE_FAIL
  export TEST_SAFE_MODE=1
}

run_helper() {
  if (( $# == 0 )); then
    if rotateGitlabToken > "$state/stdout" 2> "$state/stderr"; then rotate_status=0; else rotate_status=$?; fi
  else
    if rotateGitlabToken "$@" > "$state/stdout" 2> "$state/stderr"; then rotate_status=0; else rotate_status=$?; fi
  fi
}

if [[ "${1:-}" == --self-test ]]; then
  if TEST_SAFE_MODE=0 "$mock_bin/curl" --must-not-reach-network > /dev/null 2> "$state/stderr"; then exit 1; fi
  print -- "PASS: mocked service commands fail closed"
  exit 0
fi

make_fixture
export TEST_CURL_CA_FILE="$test_root/mock-ca.pem"
print -r -- "synthetic CA" > "$TEST_CURL_CA_FILE"
source "$repo_root/zsh/.zsh.d/72-gitlab.zsh" > /dev/null 2> "$state/source.stderr"
export SSL_CERT_FILE="$TEST_CURL_CA_FILE"
assert_eq "${+functions[cleanup_preflight]}" 0 "sourcing configuration defined an internal cleanup function"
assert_true "$( [[ ! -e "$state/get-count" && ! -e "$state/curl-count" ]] && print 1 || print 0 )" "sourcing configuration called a service"
local caller_directory="$PWD"
local caller_umask="$(umask)"
local caller_traps="$(trap -p)"
local caller_options="${options[xtrace]}:${options[allexport]}:${options[pipefail]}"
run_helper
assert_eq "$rotate_status" 0 "mocked rotation should succeed"
assert_eq "${+functions[cleanup_preflight]}" 0 "helper leaked an internal cleanup function into the shell"
assert_true "$( [[ ! -s "$state/stderr" ]] && print 1 || print 0 )" "helper emitted a runtime warning"
assert_eq "$(<"$state/get-count")" 1 "the item should be read once"
assert_eq "$(<"$state/curl-count")" 1 "one rotation POST should be sent"
assert_eq "$(<"$state/edit-count")" 1 "the item should be edited once"
assert_true "$(jq --rawfile expected "$new_token_file" -er 'any(.fields[]; .label == "credential" and .value == $expected)' "$item_file")" "the replacement was not saved"
assert_true "$(jq -er '.fields[1].value == "synthetic-user" and .fields[2].value == "preserve me" and .urls[0].url == "https://gitlab.example.com"' "$item_file")" "unrelated item fields were not preserved"
assert_file_lacks "$state/stdout" "$secret_new" "replacement appeared on stdout"
assert_file_lacks "$state/stderr" "$secret_new" "replacement appeared on stderr"
assert_file_lacks "$state/curl-args" "$secret_old" "current token appeared in curl arguments"
assert_file_lacks "$state/edit-args" "$secret_new" "replacement token appeared in op arguments"
local received_header="$(<"$state/header")"
assert_eq "$received_header" "PRIVATE-TOKEN: $secret_old" "current token was not sent through header stdin"
assert_true "$( [[ ! -e "$workspace" && "$PWD" == "$caller_directory" && "$(umask)" == "$caller_umask" && "${options[xtrace]}:${options[allexport]}:${options[pipefail]}" == "$caller_options" && "$(trap -p)" == "$caller_traps" ]] && print 1 || print 0 )" "success left temporary state or changed caller state"

make_fixture
exec 9>&2
exec 2> "$state/traced.stderr"
setopt xtrace allexport
local traced_options_before="${options[xtrace]}:${options[allexport]}:${options[pipefail]}"
run_helper
local traced_options_after="${options[xtrace]}:${options[allexport]}:${options[pipefail]}"
unsetopt xtrace allexport
exec 2>&9
exec 9>&-
assert_eq "$rotate_status" 0 "trace/export-enabled rotation should succeed"
assert_eq "$traced_options_after" "$traced_options_before" "helper changed options when tracing/export was enabled"
assert_file_lacks "$state/traced.stderr" "$secret_old" "current token appeared under xtrace"
assert_file_lacks "$state/traced.stderr" "$secret_new" "replacement token appeared under xtrace"

make_fixture
run_helper unexpected
assert_eq "$rotate_status" 1 "unexpected arguments should fail"
assert_true "$( [[ ! -e "$state/get-count" && ! -e "$state/curl-count" ]] && print 1 || print 0 )" "unexpected arguments caused service access"

make_fixture
export TEST_FAIL_EDIT=1
run_helper
assert_eq "$rotate_status" 1 "failed item update should return nonzero"
assert_true "$( [[ -d "$workspace" && -s "$workspace/rotation.json" ]] && print 1 || print 0 )" "failed update did not retain private recovery"
assert_eq "$(command stat -f '%Lp' "$workspace")" 700 "recovery directory is not owner-only"
assert_eq "$(command stat -f '%Lp' "$workspace/rotation.json")" 600 "recovery response is not owner-only"
assert_file_lacks "$state/stdout" "$secret_old" "failed update leaked current token to stdout"
assert_file_lacks "$state/stdout" "$secret_new" "failed update leaked replacement to stdout"
assert_file_lacks "$state/stderr" "$secret_old" "failed update leaked current token to stderr"
assert_file_lacks "$state/stderr" "$secret_new" "failed update leaked replacement to stderr"
assert_file_has "$state/stderr" "$workspace/rotation.json" "failed update did not report the recovery file"
local get_count_before="$(<"$state/get-count")"
run_helper
assert_eq "$rotate_status" 1 "unresolved recovery should block a new rotation"
assert_eq "$(<"$state/get-count")" "$get_count_before" "lock should block credential retrieval"
assert_eq "$(<"$state/curl-count")" 1 "lock should block a second POST"

make_fixture
export TEST_HTTP_STATUS=500
run_helper
assert_eq "$rotate_status" 1 "HTTP failure should return nonzero"
assert_true "$( [[ -d "$workspace" && -s "$workspace/rotation.json" && ! -e "$state/edit-count" ]] && print 1 || print 0 )" "HTTP failure should preserve recovery without editing"
assert_file_lacks "$state/stderr" "$secret_old" "HTTP failure leaked current token"
assert_file_lacks "$state/stderr" "$secret_new" "HTTP failure leaked replacement token"
assert_file_has "$state/stderr" "$workspace/rotation.json" "HTTP failure did not report the recovery file"

make_fixture
print -r -- '{"expires_at":"2027-01-06"}' > "$response_file"
run_helper
assert_eq "$rotate_status" 1 "invalid token response should return nonzero"
assert_true "$( [[ -d "$workspace" && -s "$workspace/rotation.json" && ! -e "$state/edit-count" ]] && print 1 || print 0 )" "invalid response should retain recovery without editing"
assert_file_lacks "$state/stderr" "$secret_new" "invalid response leaked its token"
assert_file_has "$state/stderr" "$workspace/rotation.json" "invalid response did not report the recovery file"

make_fixture
jq '.category = "LOGIN"' "$item_file" > "$state/unsupported.json"
command mv "$state/unsupported.json" "$item_file"
run_helper
assert_eq "$rotate_status" 1 "unsupported item should fail before rotation"
assert_true "$( [[ ! -e "$state/curl-count" && ! -e "$workspace" ]] && print 1 || print 0 )" "unsupported item caused a POST or left a lock"

make_fixture
export TEST_TRANSPORT_FAIL=1
run_helper
assert_eq "$rotate_status" 1 "uncertain transport failure should return nonzero"
assert_true "$( [[ -d "$workspace" && -f "$workspace/rotation.json" ]] && print 1 || print 0 )" "uncertain request should retain its lock and response"
assert_file_lacks "$state/stderr" "$secret_old" "transport failure leaked current token"
assert_file_lacks "$state/stderr" "$secret_new" "transport failure leaked replacement token"

make_fixture
export TEST_DATE_FAIL=1
run_helper
assert_eq "$rotate_status" 1 "expiry calculation failure should return nonzero"
assert_true "$( [[ ! -e "$state/get-count" && ! -e "$state/curl-count" && ! -e "$workspace" ]] && print 1 || print 0 )" "expiry failure proceeded or left a lock"

make_fixture
unset GITLAB_ROTATION_HOST
run_helper
assert_eq "$rotate_status" 1 "missing GitLab host should fail"
assert_file_has "$state/stderr" GITLAB_ROTATION_HOST "missing host did not name the setting"
assert_true "$( [[ ! -e "$state/get-count" && ! -e "$state/curl-count" && ! -e "$workspace" ]] && print 1 || print 0 )" "missing host caused service access or a lock"
export GITLAB_ROTATION_HOST=gitlab.example.com

make_fixture
export GITLAB_ROTATION_OP_ITEM_ID='../escape'
run_helper
assert_eq "$rotate_status" 1 "invalid item ID should fail"
assert_file_has "$state/stderr" GITLAB_ROTATION_OP_ITEM_ID "invalid item ID did not name the setting"
assert_true "$( [[ ! -e "$state/get-count" && ! -e "$state/curl-count" ]] && print 1 || print 0 )" "invalid item ID caused service access"
export GITLAB_ROTATION_OP_ITEM_ID="$item_id"

if (( failures == 0 )); then
  print -- "${passes} assertions passed; no live services were used"
  exit 0
fi
print -u2 -- "${passes} assertions passed; ${failures} failed"
exit 1
}

assert_file_lacks() {
  local content="$(<"$1")"
  if [[ "$content" == *"$2"* ]]; then fail "$3"; else pass; fi
}

assert_file_has() {
  local content="$(<"$1")"
  if [[ "$content" == *"$2"* ]]; then pass; else fail "$3"; fi
}

main "$@"
