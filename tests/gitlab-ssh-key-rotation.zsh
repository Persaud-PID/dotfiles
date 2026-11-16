#!/bin/zsh

typeset -g SSH_ROTATION_REPO_ROOT="${0:A:h:h}"

main() {
emulate -L zsh
unsetopt xtrace verbose allexport
umask 077
local repo_root="$SSH_ROTATION_REPO_ROOT"
local original_path="$PATH"
local test_root
if ! test_root="$(command mktemp -d "${TMPDIR:-/tmp}/gitlab-ssh-rotation-tests.XXXXXX")"; then
  print -u2 -- 'FAIL: could not create private test workspace'
  exit 1
fi
command chmod 700 "$test_root" || exit 1
local mock_bin="$test_root/bin"
local test_home="$test_root/home"
local ssh_dir="$test_home/.ssh"
local workspace="$ssh_dir/.gitlab-key-rotation"
local keys_file="$test_root/gitlab-keys.json"
local state="$test_root/state"
local old_public='ssh-ed25519 AAAAoldfixturekey fixture@example.com (gitlab)'
local server_old_public='ssh-ed25519 AAAAoldfixturekey GitLab-normalized-comment'
local new_public='ssh-ed25519 AAAAnewfixturekeygitlab-rotation'
local passes=0
local failures=0
local rotate_status=0
command mkdir -m 700 "$mock_bin" "$test_home" "$ssh_dir" "$state" || exit 1
trap 'command rm -r "$test_root" 2>/dev/null' EXIT
export HOME="$test_home" TEST_SAFE_MODE=1 TEST_HOST=gitlab.example.com TEST_EXPECTED_EXPIRY=2027-01-06
export TEST_SSH_DIR="$ssh_dir" TEST_KEYS_FILE="$keys_file" TEST_STATE="$state"
export TEST_OLD_PUBLIC="$old_public" TEST_NEW_PUBLIC="$new_public"
PATH="$mock_bin:$original_path"
export PATH

cat > "$mock_bin/date" <<'MOCK_DATE'
#!/bin/sh
[ "$#" -eq 3 ] && [ "$1" = -u ] && [ "$2" = -v+90d ] && [ "$3" = +%Y-%m-%d ] || exit 90
[ "${TEST_DATE_FAIL:-0}" = 0 ] || exit 2
printf '%s\n' "$TEST_EXPECTED_EXPIRY"
MOCK_DATE

cat > "$mock_bin/ssh-keygen" <<'MOCK_KEYGEN'
#!/bin/sh
[ "${TEST_SAFE_MODE:-0}" = 1 ] || exit 90
if [ "${1:-}" = -y ]; then
  private_file=
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -f) shift; private_file="$1" ;;
    esac
    shift
  done
  [ -n "$private_file" ] && [ -f "$private_file.pub" ] || exit 91
  if [ "${TEST_MISMATCH_PRIVATE:-0}" = 1 ]; then
    printf '%s\n' 'ssh-ed25519 mismatched-key'
  else
    cat "$private_file.pub"
  fi
  exit 0
fi
[ "$1" = -q ] || exit 92
key_file=
passphrase_marker=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    -f) shift; key_file="$1" ;;
    -N) shift; [ -z "$1" ] && passphrase_marker=1 ;;
    -t) shift; [ "$1" = ed25519 ] || exit 93 ;;
  esac
  shift
done
[ -n "$key_file" ] && [ "$passphrase_marker" = 1 ] || exit 94
printf '%s\n' 'synthetic-new-private-key' > "$key_file"
printf '%s\n' "$TEST_NEW_PUBLIC" > "$key_file.pub"
chmod 600 "$key_file"
chmod 644 "$key_file.pub"
MOCK_KEYGEN

cat > "$mock_bin/glab" <<'MOCK_GLAB'
#!/bin/sh
[ "${TEST_SAFE_MODE:-0}" = 1 ] || exit 90
[ "$1" = api ] || exit 91
shift
host=
method=GET
format=json
paginate=0
input_file=
content_type=
endpoint=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --hostname) shift; host="$1" ;;
    --method) shift; method="$1" ;;
    --output) shift; format="$1" ;;
    --paginate) paginate=1 ;;
    --input) shift; input_file="$1" ;;
    --header) shift; content_type="$1" ;;
    *) endpoint="$1" ;;
  esac
  shift
done
[ "$host" = "$TEST_HOST" ] || exit 94
case "$method:$endpoint" in
  GET:user/keys)
    count=0
    [ -f "$TEST_STATE/list-count" ] && read -r count < "$TEST_STATE/list-count"
    count=$((count + 1))
    printf '%s\n' "$count" > "$TEST_STATE/list-count"
    [ "$paginate" = 1 ] && [ "$format" = ndjson ] || exit 95
    jq -c '.[]' "$TEST_KEYS_FILE"
    ;;
  POST:user/keys)
    [ "$content_type" = 'Content-Type: application/json' ] || { printf '%s\n' 'The provided content-type is not supported.' >&2; exit 96; }
    [ -f "$input_file" ] || exit 97
    title=$(jq -r '.title' "$input_file") || exit 97
    new_key=$(jq -r '.key' "$input_file") || exit 98
    usage=$(jq -r '.usage_type' "$input_file") || exit 99
    expiry=$(jq -r '.expires_at' "$input_file") || exit 100
    [ -n "$title" ] && [ "$usage" = auth_and_signing ] && [ "$expiry" = "$TEST_EXPECTED_EXPIRY" ] || exit 101
    count=0
    [ -f "$TEST_STATE/add-count" ] && read -r count < "$TEST_STATE/add-count"
    count=$((count + 1))
    printf '%s\n' "$count" > "$TEST_STATE/add-count"
    if [ "${TEST_FAIL_POST_BEFORE_CREATE:-0}" = 1 ]; then printf '%s\n' 'simulated GitLab permission error' >&2; exit 104; fi
    jq --argjson id 202 --arg title "$title" --arg key "$new_key" --arg usage "$usage" --arg expires_at "$expiry" '. + [{id:$id,title:$title,key:$key,usage_type:$usage,expires_at:$expires_at}]' "$TEST_KEYS_FILE" > "$TEST_STATE/keys-next.json" || exit 101
    mv "$TEST_STATE/keys-next.json" "$TEST_KEYS_FILE" || exit 102
    if [ "${TEST_FAIL_POST_AFTER_CREATE:-0}" = 1 ]; then printf '%s\n' 'simulated lost API response' >&2; exit 103; fi
    printf '%s\n' '{"id":202}'
    ;;
  DELETE:user/keys/*)
    key_id="${endpoint##*/}"
    count=0
    [ -f "$TEST_STATE/delete-$key_id" ] && read -r count < "$TEST_STATE/delete-$key_id"
    count=$((count + 1))
    printf '%s\n' "$count" > "$TEST_STATE/delete-$key_id"
    [ "${TEST_FAIL_DELETE_ID:-}" != "$key_id" ] || exit 100
    jq --argjson id "$key_id" '[.[] | select(.id != $id)]' "$TEST_KEYS_FILE" > "$TEST_STATE/keys-next.json" || exit 101
    mv "$TEST_STATE/keys-next.json" "$TEST_KEYS_FILE"
    ;;
  *) exit 102 ;;
esac
MOCK_GLAB

cat > "$mock_bin/ssh" <<'MOCK_SSH'
#!/bin/sh
[ "${TEST_SAFE_MODE:-0}" = 1 ] || exit 90
key_file=
config_file=
identities_only=0
batch_mode=0
strict_host=0
host=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -F) shift; config_file="$1" ;;
    -i) shift; key_file="$1" ;;
    -o)
      shift
      case "$1" in
        BatchMode=yes) batch_mode=1 ;;
        IdentitiesOnly=yes) identities_only=1 ;;
        StrictHostKeyChecking=yes) strict_host=1 ;;
        *) exit 103 ;;
      esac
      ;;
    -T) ;;
    *) host="$1" ;;
  esac
  shift
done
[ "$config_file" = /dev/null ] && [ "$identities_only" = 1 ] && [ "$batch_mode" = 1 ] && [ "$strict_host" = 1 ] || exit 104
[ "$host" = "git@$TEST_HOST" ] && [ -f "$key_file" ] && [ -f "$key_file.pub" ] || exit 105
candidate_public=$(cat "$key_file.pub") || exit 106
jq -e --arg key "$candidate_public" 'any(.[]; .key == $key)' "$TEST_KEYS_FILE" >/dev/null || exit 107
count=0
[ -f "$TEST_STATE/ssh-count" ] && read -r count < "$TEST_STATE/ssh-count"
count=$((count + 1))
printf '%s\n' "$count" > "$TEST_STATE/ssh-count"
[ "${TEST_SSH_FAIL:-0}" = 0 ] || { printf '%s\n' 'Permission denied'; exit 1; }
printf '%s\n' 'Welcome to GitLab, @fixture!' >&2
exit 1
MOCK_SSH

command chmod 700 "$mock_bin/date" "$mock_bin/ssh-keygen" "$mock_bin/glab" "$mock_bin/ssh" || exit 1
pass() { passes=$((passes + 1)); }
fail() { failures=$((failures + 1)); print -u2 -- "FAIL: $1"; }
assert_eq() { if [[ "$1" == "$2" ]]; then pass; else fail "$3"; fi; }
assert_true() { if [[ "$1" == 1 || "$1" == true ]]; then pass; else fail "$2"; fi; }
assert_file_lacks() { local content="$(<"$1")"; if [[ "$content" == *"$2"* ]]; then fail "$3"; else pass; fi; }
assert_file_has() { local content="$(<"$1")"; if [[ "$content" == *"$2"* ]]; then pass; else fail "$3"; fi; }

make_fixture() {
  [[ ! -d "$workspace" ]] || command rm -r "$workspace"
  command rm -f "$state/list-count" "$state/add-count" "$state/ssh-count" "$state/delete-101" "$state/delete-202" "$state/stdout" "$state/stderr" "$state/keys-next.json"
  print -r -- 'synthetic-old-private-key' > "$ssh_dir/id_ed25519_gitlab"
  print -r -- "$old_public" > "$ssh_dir/id_ed25519_gitlab.pub"
  command chmod 600 "$ssh_dir/id_ed25519_gitlab"
  command chmod 644 "$ssh_dir/id_ed25519_gitlab.pub"
  jq -cn --arg title 'fixture@example.com (gitlab)' --arg key "$server_old_public" '[{id:101,title:$title,key:$key,usage_type:"auth_and_signing",expires_at:"2026-10-19"}]' > "$keys_file"
  command chmod 600 "$keys_file"
  unset TEST_SSH_FAIL TEST_FAIL_DELETE_ID TEST_MISMATCH_PRIVATE TEST_FAIL_POST_BEFORE_CREATE TEST_FAIL_POST_AFTER_CREATE TEST_DATE_FAIL
  export TEST_SAFE_MODE=1
}

run_rotation() {
  local code
  if rotateGitlabSshKey > "$state/stdout" 2> "$state/stderr"; then code=0; else code=$?; fi
  rotate_status=$code
}

source "$repo_root/company/.zsh/companies/zscaler.zsh" > /dev/null 2> "$state/source.stderr"
make_fixture
assert_true "$(jq --rawfile local_key "$ssh_dir/id_ed25519_gitlab.pub" -er '.[0].key as $server_key | ($server_key | split(" ")[0:2]) == ($local_key | rtrimstr("\n") | split(" ")[0:2]) and $server_key != ($local_key | rtrimstr("\n"))' "$keys_file")" 'fixture should model GitLab normalizing the public-key comment'
run_rotation
assert_eq "$rotate_status" 0 'mocked SSH key rotation should succeed'
assert_eq "$(<"$state/add-count")" 1 'exactly one replacement key should be registered'
assert_eq "$(<"$state/delete-101")" 1 'the identified old GitLab key should be deleted after testing the replacement'
assert_eq "$(<"$state/ssh-count")" 1 'the staged replacement should be tested once'
assert_true "$(jq --rawfile expected "$ssh_dir/id_ed25519_gitlab.pub" --arg expiry "$TEST_EXPECTED_EXPIRY" -er '. | any(.[]; .id == 202 and .key == ($expected | rtrimstr("\n")) and .title == "fixture@example.com (gitlab)" and .usage_type == "auth_and_signing" and .expires_at == $expiry)' "$keys_file")" 'replacement GitLab key metadata is wrong'
assert_file_has "$ssh_dir/id_ed25519_gitlab" 'synthetic-new-private-key' 'new private key was not installed'
assert_true "$( [[ ! -e "$workspace" ]] && print 1 || print 0 )" 'successful rotation left backups or a lock'
assert_file_lacks "$state/stdout" 'synthetic-new-private-key' 'private key appeared on stdout'
assert_file_lacks "$state/stderr" 'synthetic-new-private-key' 'private key appeared on stderr'

make_fixture
command chmod 000 "$ssh_dir/id_ed25519_gitlab"
run_rotation
assert_eq "$rotate_status" 1 'unreadable private key should fail preflight'
assert_file_has "$state/stderr" 'not readable' 'unreadable private key did not explain the permissions issue'
assert_true "$( [[ ! -e "$state/list-count" && ! -e "$workspace" ]] && print 1 || print 0 )" 'unreadable private key caused a GitLab request or lock'
command chmod 600 "$ssh_dir/id_ed25519_gitlab"

make_fixture
export TEST_DATE_FAIL=1
run_rotation
assert_eq "$rotate_status" 1 'expiry calculation failure should stop the rotation'
assert_true "$( [[ ! -e "$state/list-count" && ! -e "$state/add-count" && ! -e "$workspace" ]] && print 1 || print 0 )" 'expiry failure made an API request or created a lock'

make_fixture
export TEST_FAIL_POST_BEFORE_CREATE=1
run_rotation
assert_eq "$rotate_status" 1 'failed GitLab add should retain the staged key'
assert_file_has "$workspace/id_ed25519_gitlab" 'synthetic-new-private-key' 'failed add lost the staged private key'
assert_file_has "$workspace/add-key.stderr" 'simulated GitLab permission error' 'failed add did not preserve the CLI error'
assert_true "$(jq -er 'length == 1 and .[0].id == 101' "$keys_file")" 'failed add changed GitLab key state'
assert_file_has "$ssh_dir/id_ed25519_gitlab" 'synthetic-old-private-key' 'failed add changed the active local key'
unset TEST_FAIL_POST_BEFORE_CREATE
run_rotation
assert_eq "$rotate_status" 0 'retry with the staged key should succeed'
assert_eq "$(<"$state/add-count")" 2 'retry should issue exactly one additional add request'
assert_true "$( [[ ! -e "$workspace" ]] && print 1 || print 0 )" 'successful retry left its workspace'

make_fixture
export TEST_FAIL_POST_AFTER_CREATE=1
run_rotation
assert_eq "$rotate_status" 1 'lost add response should retain the staged key'
assert_true "$(jq -er 'length == 2' "$keys_file")" 'simulated lost response should leave the new key registered'
local add_count_before_resume="$(<"$state/add-count")"
unset TEST_FAIL_POST_AFTER_CREATE
run_rotation
assert_eq "$rotate_status" 0 'retry should resume the already registered staged key'
assert_eq "$(<"$state/add-count")" "$add_count_before_resume" 'resume should not add a duplicate key'
assert_true "$( [[ ! -e "$workspace" ]] && print 1 || print 0 )" 'resumed success left its workspace'

make_fixture
export TEST_SSH_FAIL=1
run_rotation
assert_eq "$rotate_status" 1 'failed SSH authentication must abort rotation'
assert_file_has "$ssh_dir/id_ed25519_gitlab" 'synthetic-old-private-key' 'failed SSH test replaced the old local private key'
assert_eq "$(<"$state/delete-202")" 1 'failed SSH test should remove the newly registered GitLab key'
assert_true "$(jq -er 'length == 1 and .[0].id == 101' "$keys_file")" 'failed SSH test should leave the old GitLab key registered'
assert_true "$( [[ ! -e "$workspace" ]] && print 1 || print 0 )" 'failed test cleanup left a recovery lock'

make_fixture
export TEST_FAIL_DELETE_ID=101
run_rotation
assert_eq "$rotate_status" 1 'unconfirmed old-key deletion must report incomplete rotation'
assert_file_has "$ssh_dir/id_ed25519_gitlab" 'synthetic-new-private-key' 'tested replacement key was not activated'
assert_file_has "$workspace/id_ed25519_gitlab.old" 'synthetic-old-private-key' 'old key backup was not retained after partial failure'
assert_true "$(jq -er 'length == 2' "$keys_file")" 'partial failure should preserve both GitLab entries'
local add_count_before="$(<"$state/add-count")"
run_rotation
assert_eq "$rotate_status" 1 'unresolved recovery workspace must block another rotation'
assert_eq "$(<"$state/add-count")" "$add_count_before" 'blocked retry unexpectedly added another GitLab key'
assert_file_lacks "$state/stderr" 'synthetic-old-private-key' 'private key appeared in diagnostics'

if (( failures == 0 )); then
  print -- "${passes} assertions passed; no live GitLab or SSH services were used"
  exit 0
fi
print -u2 -- "${passes} assertions passed; ${failures} failed"
exit 1
}

main "$@"
