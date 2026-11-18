rotateGitlabToken() (
  emulate -L zsh
  setopt pipefail
  unsetopt xtrace verbose allexport
  umask 077

  local gitlab_host="${GITLAB_ROTATION_HOST:-}"
  local item_id="${GITLAB_ROTATION_OP_ITEM_ID:-}"
  local vault='Employee'
  local item_field='credential'
  local workspace="${TMPDIR:-/tmp}/gitlab-token-rotation-${UID}-${item_id}"
  local response_file="$workspace/rotation.json"
  local request_url="https://${gitlab_host}/api/v4/personal_access_tokens/self/rotate"
  local expires_at current_item field_snapshot field_id current_token http_status curl_status utility
  local -a curl_arguments
  typeset +x gitlab_host item_id vault item_field workspace response_file request_url expires_at current_item field_snapshot field_id current_token http_status curl_status utility curl_arguments

  if (( $# != 0 )); then
    print -u2 -- 'Usage: rotateGitlabToken'
    return 1
  fi
  if [[ "$gitlab_host" != [A-Za-z0-9]* || "$gitlab_host" == *[^A-Za-z0-9.-]* ]]; then
    print -u2 -- 'rotateGitlabToken: set GITLAB_ROTATION_HOST to the GitLab hostname (for example in ~/.envrc)'
    return 1
  fi
  if [[ -z "$item_id" || "$item_id" == *[^A-Za-z0-9]* ]]; then
    print -u2 -- 'rotateGitlabToken: set GITLAB_ROTATION_OP_ITEM_ID to the 1Password item ID (for example in ~/.envrc)'
    return 1
  fi
  for utility in curl jq op date mkdir chmod rm rmdir; do
    if ! command -v "$utility" >/dev/null 2>&1; then
      print -u2 -- "rotateGitlabToken: required command unavailable: $utility"
      return 1
    fi
  done
  if [[ -n "${SSL_CERT_FILE:-}" && ! -r "$SSL_CERT_FILE" ]]; then
    print -u2 -- 'rotateGitlabToken: configured SSL_CERT_FILE is not readable'
    return 1
  fi
  if ! expires_at="$(command date -u -v+90d '+%Y-%m-%d' 2>/dev/null)" || [[ "$expires_at" != [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] ]]; then
    print -u2 -- 'rotateGitlabToken: could not calculate the requested 90-day expiry date'
    return 1
  fi
  if [[ ! -d "${TMPDIR:-/tmp}" || ! -w "${TMPDIR:-/tmp}" || -e "$workspace" || -L "$workspace" ]]; then
    print -u2 -- 'rotateGitlabToken: private recovery workspace is unavailable or already in use'
    return 1
  fi
  if ! command mkdir -m 700 "$workspace" 2>/dev/null; then
    print -u2 -- 'rotateGitlabToken: could not acquire the private recovery lock'
    return 1
  fi
  : > "$response_file" || { command rmdir "$workspace" 2>/dev/null; print -u2 -- 'rotateGitlabToken: could not prepare private recovery storage'; return 1; }
  if ! command chmod 600 "$response_file" 2>/dev/null; then
    command rm -f "$response_file" 2>/dev/null
    command rmdir "$workspace" 2>/dev/null
    print -u2 -- 'rotateGitlabToken: could not secure private recovery storage'
    return 1
  fi

  if ! current_item="$(command op item get "$item_id" --vault "$vault" --format json --reveal 2>/dev/null)"; then
    command rm -f "$response_file" 2>/dev/null
    command rmdir "$workspace" 2>/dev/null
    print -u2 -- 'rotateGitlabToken: could not read the configured 1Password item'
    return 1
  fi
  if ! field_snapshot="$(print -r -- "$current_item" | command jq -cer --arg expected_id "$item_id" --arg expected_field "$item_field" '
    if type != "object" or .id != $expected_id or .category != "API_CREDENTIAL" or (.fields | type) != "array" then
      error("unsupported item")
    else
      [.fields[] | select(.label == $expected_field)] as $matches |
      if ($matches | length) != 1 or ($matches[0].id | type) != "string" or ($matches[0].id | length) == 0 or ([.fields[] | select(.id == $matches[0].id)] | length) != 1 then
        error("missing or ambiguous credential")
      elif ($matches[0].value | type) != "string" or ($matches[0].value | gsub("[[:space:]]"; "") | length) == 0 or ($matches[0].value | test("[\\r\\n]")) then
        error("invalid credential")
      else
        [$matches[0].id, $matches[0].value]
      end
    end
  ' 2>/dev/null)"; then
    command rm -f "$response_file" 2>/dev/null
    command rmdir "$workspace" 2>/dev/null
    print -u2 -- 'rotateGitlabToken: item is unsupported or its credential field is invalid'
    return 1
  fi
  field_id="$(print -r -- "$field_snapshot" | command jq -er '.[0]' 2>/dev/null)"
  current_token="$(print -r -- "$field_snapshot" | command jq -er '.[1]' 2>/dev/null)"

  curl_arguments=(-q -sS --proto '=https' --connect-timeout 10 --max-time 60 --request POST)
  [[ -z "${SSL_CERT_FILE:-}" ]] || curl_arguments+=(--cacert "$SSL_CERT_FILE")
  curl_arguments+=(--header @- --output "$response_file" --write-out '%{http_code}' --url "${request_url}?expires_at=${expires_at}")
  curl_status=0
  http_status="$(print -r -- "PRIVATE-TOKEN: ${current_token}" | command curl "${curl_arguments[@]}" 2>/dev/null)" || curl_status=$?
  if (( curl_status != 0 )) || [[ "$http_status" != 200 ]]; then
    print -u2 -- "rotateGitlabToken: GitLab request was not confirmed; do not retry with the old token. Recovery data: $response_file"
    return 1
  fi
  if ! command jq -e '(.token | type == "string") and (.token | gsub("[[:space:]]"; "") | length > 0) and (.token | test("[\\r\\n]") | not)' "$response_file" >/dev/null 2>&1; then
    print -u2 -- "rotateGitlabToken: GitLab response is invalid; inspect the private recovery data: $response_file"
    return 1
  fi
  if ! print -r -- "$current_item" | command jq --slurpfile replacement "$response_file" --arg credential_id "$field_id" '.fields |= map(if .id == $credential_id and .label == "credential" then .value = $replacement[0].token else . end)' 2>/dev/null | command op item edit "$item_id" --vault "$vault" > /dev/null 2>&1; then
    print -u2 -- "rotateGitlabToken: 1Password update failed; save the protected replacement from: $response_file"
    return 1
  fi
  if ! command rm -f "$response_file" 2>/dev/null || ! command rmdir "$workspace" 2>/dev/null; then
    print -u2 -- "rotateGitlabToken: token was saved; remove the private workspace after verifying it: $workspace"
    return 0
  fi
  print -- 'rotateGitlabToken: token rotation saved to 1Password'
)

rotateGitlabSshKey() (
  emulate -L zsh
  setopt pipefail
  unsetopt xtrace verbose allexport
  umask 077

  local gitlab_host="${GITLAB_ROTATION_HOST:-}"
  local ssh_dir="$HOME/.ssh"
  local key_name='id_ed25519_gitlab'
  local key_title="${GITLAB_ROTATION_KEY_TITLE:-${USER:-gitlab} (gitlab)}"
  local private_key="$ssh_dir/$key_name"
  local public_key="$private_key.pub"
  local workspace="$ssh_dir/.gitlab-key-rotation"
  local candidate_key="$workspace/$key_name"
  local candidate_public_key="$candidate_key.pub"
  local old_private_backup="$workspace/$key_name.old"
  local old_public_backup="$old_private_backup.pub"
  local add_request_file="$workspace/add-key.json"
  local add_response_file="$workspace/add-key-response.json"
  local add_error_file="$workspace/add-key.stderr"
  local old_public old_private_public old_public_type old_public_data old_public_comment
  local derived_type derived_data derived_comment candidate_type candidate_data candidate_comment
  local old_key_id new_key_record new_key_id candidate_key_id remote_keys connection_output utility expires_at workspace_created=0 workspace_existing=0
  typeset +x gitlab_host ssh_dir key_name key_title private_key public_key workspace candidate_key candidate_public_key old_private_backup old_public_backup add_request_file add_response_file add_error_file old_public old_private_public old_public_type old_public_data old_public_comment derived_type derived_data candidate_type candidate_data candidate_comment old_key_id new_key_record new_key_id candidate_key_id remote_keys connection_output utility expires_at workspace_created workspace_existing

  if (( $# != 0 )); then
    print -u2 -- 'Usage: rotateGitlabSshKey'
    return 1
  fi
  if [[ "$gitlab_host" != [A-Za-z0-9]* || "$gitlab_host" == *[^A-Za-z0-9.-]* ]]; then
    print -u2 -- 'rotateGitlabSshKey: set GITLAB_ROTATION_HOST to the GitLab hostname (for example in ~/.envrc)'
    return 1
  fi
  for utility in glab ssh ssh-keygen jq date cat mkdir chmod cp mv rm rmdir; do
    if ! command -v "$utility" >/dev/null 2>&1; then
      print -u2 -- "rotateGitlabSshKey: required command unavailable: $utility"
      return 1
    fi
  done
  if ! expires_at="$(command date -u -v+90d '+%Y-%m-%d' 2>/dev/null)" || [[ "$expires_at" != [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] ]]; then
    print -u2 -- 'rotateGitlabSshKey: could not calculate the requested 90-day key expiry'
    return 1
  fi
  if [[ ! -d "$ssh_dir" || ! -w "$ssh_dir" || ! -f "$private_key" || ! -f "$public_key" || -L "$private_key" || -L "$public_key" ]]; then
    print -u2 -- 'rotateGitlabSshKey: expected key pair or private workspace is unavailable'
    return 1
  fi
  if [[ ! -r "$private_key" || ! -r "$public_key" ]]; then
    print -u2 -- 'rotateGitlabSshKey: existing key files are not readable; check their ownership and permissions'
    return 1
  fi
  old_public="$(command cat "$public_key" 2>/dev/null)" || { print -u2 -- 'rotateGitlabSshKey: could not read the existing public key'; return 1; }
  old_private_public="$(command ssh-keygen -y -P '' -f "$private_key" 2>/dev/null)" || { print -u2 -- 'rotateGitlabSshKey: could not verify the existing key pair'; return 1; }
  read -r old_public_type old_public_data old_public_comment <<< "$old_public"
  read -r derived_type derived_data derived_comment <<< "$old_private_public"
  if [[ "$old_public_type" != "$derived_type" || "$old_public_data" != "$derived_data" ]]; then
    print -u2 -- 'rotateGitlabSshKey: local private and public keys do not match'
    return 1
  fi

  if [[ -L "$workspace" || ( -e "$workspace" && ! -d "$workspace" ) ]]; then
    print -u2 -- 'rotateGitlabSshKey: recovery path is not a safe directory'
    return 1
  elif [[ -d "$workspace" ]]; then
    if [[ -L "$candidate_key" || -L "$candidate_public_key" || ! -f "$candidate_key" || ! -f "$candidate_public_key" || -e "$old_private_backup" || -e "$old_public_backup" ]]; then
      print -u2 -- "rotateGitlabSshKey: an incomplete rotation needs manual recovery. Workspace: $workspace"
      return 1
    fi
    old_private_public="$(command ssh-keygen -y -P '' -f "$candidate_key" 2>/dev/null)" || { print -u2 -- "rotateGitlabSshKey: staged key is unreadable; inspect the recovery workspace: $workspace"; return 1; }
    read -r derived_type derived_data derived_comment <<< "$old_private_public"
    read -r candidate_type candidate_data candidate_comment <<< "$(command cat "$candidate_public_key" 2>/dev/null)"
    if [[ "$candidate_type" != "$derived_type" || "$candidate_data" != "$derived_data" ]]; then
      print -u2 -- "rotateGitlabSshKey: staged key pair does not match. Workspace: $workspace"
      return 1
    fi
    workspace_existing=1
  else
    if ! command mkdir -m 700 "$workspace" 2>/dev/null; then
      print -u2 -- 'rotateGitlabSshKey: could not acquire the private rotation workspace'
      return 1
    fi
    workspace_created=1
  fi

  if ! remote_keys="$(command glab api --hostname "$gitlab_host" --paginate --output ndjson user/keys 2>/dev/null)"; then
    (( workspace_created )) && command rmdir "$workspace" 2>/dev/null
    print -u2 -- 'rotateGitlabSshKey: could not read GitLab SSH keys'
    return 1
  fi
  if ! old_key_id="$(print -r -- "$remote_keys" | command jq -ser --rawfile existing_key "$public_key" '
    [ .[] | select((.key | split(" ")[0:2]) == ($existing_key | rtrimstr("\n") | split(" ")[0:2])) ] as $matches |
    if ($matches | length) == 1 then ($matches[0].id | tostring) else error("existing GitLab key not found or ambiguous") end
  ' 2>/dev/null)"; then
    (( workspace_created )) && command rmdir "$workspace" 2>/dev/null
    print -u2 -- 'rotateGitlabSshKey: could not identify the existing GitLab key by its public-key data'
    return 1
  fi

  if (( ! workspace_existing )); then
    if ! command ssh-keygen -q -t ed25519 -C 'gitlab-rotation' -f "$candidate_key" -N '' >/dev/null 2>&1; then
      command rmdir "$workspace" 2>/dev/null
      print -u2 -- 'rotateGitlabSshKey: could not generate a replacement key'
      return 1
    fi
  fi
  if ! candidate_key_id="$(print -r -- "$remote_keys" | command jq -sr --rawfile candidate_key "$candidate_public_key" '
    [ .[] | select((.key | split(" ")[0:2]) == ($candidate_key | rtrimstr("\n") | split(" ")[0:2])) ] as $matches |
    if ($matches | length) == 0 then "" elif ($matches | length) == 1 then ($matches[0].id | tostring) else error("staged GitLab key is ambiguous") end
  ' 2>/dev/null)"; then
    (( workspace_created )) && command rmdir "$workspace" 2>/dev/null
    print -u2 -- "rotateGitlabSshKey: could not verify whether the staged key is registered. Workspace: $workspace"
    return 1
  fi

  if [[ -z "$candidate_key_id" ]]; then
    if ! command jq -n --arg title "$key_title" --arg expires_at "$expires_at" --rawfile key "$candidate_public_key" '{title:$title,key:($key | rtrimstr("\n")),usage_type:"auth_and_signing",expires_at:$expires_at}' > "$add_request_file" 2>/dev/null || ! command chmod 600 "$add_request_file" 2>/dev/null; then
      (( workspace_created )) && { command rm -f "$add_request_file"; command rmdir "$workspace" 2>/dev/null; }
      print -u2 -- 'rotateGitlabSshKey: could not prepare the GitLab add-key request'
      return 1
    fi
    : > "$add_response_file"
    : > "$add_error_file"
    command chmod 600 "$add_response_file" "$add_error_file" 2>/dev/null
    if ! command glab api --hostname "$gitlab_host" --method POST --header 'Content-Type: application/json' --input "$add_request_file" user/keys > "$add_response_file" 2> "$add_error_file"; then
      print -u2 -- "rotateGitlabSshKey: GitLab did not confirm the new key. Check the private response and diagnostics in: $workspace"
      return 1
    fi
    candidate_key_id="$(command jq -er '.id | tostring' "$add_response_file" 2>/dev/null)" || { print -u2 -- "rotateGitlabSshKey: could not identify the new GitLab key. Workspace: $workspace"; return 1; }
  fi
  new_key_id="$candidate_key_id"

  connection_output="$(command ssh -F /dev/null -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -i "$candidate_key" -T "git@$gitlab_host" 2>&1)" || true
  if [[ "$connection_output" != *'Welcome to GitLab,'* ]]; then
    if command glab api --hostname "$gitlab_host" --method DELETE "user/keys/$new_key_id" >/dev/null 2>&1; then
      command rm -f "$candidate_key" "$candidate_public_key" "$add_request_file" "$add_response_file" "$add_error_file"
      command rmdir "$workspace" 2>/dev/null
      print -u2 -- 'rotateGitlabSshKey: the replacement key did not authenticate; the old key was left unchanged'
    else
      print -u2 -- "rotateGitlabSshKey: connection test failed and GitLab could not remove the staged key. Recovery workspace: $workspace"
    fi
    return 1
  fi

  if ! command cp -p "$private_key" "$old_private_backup" || ! command cp -p "$public_key" "$old_public_backup"; then
    if command glab api --hostname "$gitlab_host" --method DELETE "user/keys/$new_key_id" >/dev/null 2>&1; then
      command rm -f "$candidate_key" "$candidate_public_key" "$old_private_backup" "$old_public_backup" "$add_request_file" "$add_response_file" "$add_error_file"
      command rmdir "$workspace" 2>/dev/null
      print -u2 -- 'rotateGitlabSshKey: could not preserve the old key; the old key was left unchanged'
    else
      print -u2 -- "rotateGitlabSshKey: could not preserve the old key or remove the staged GitLab key. Recovery workspace: $workspace"
    fi
    return 1
  fi

  if ! command mv "$candidate_key" "$private_key"; then
    if command glab api --hostname "$gitlab_host" --method DELETE "user/keys/$new_key_id" >/dev/null 2>&1; then
      command rm -f "$candidate_public_key" "$old_private_backup" "$old_public_backup" "$add_request_file" "$add_response_file" "$add_error_file"
      command rmdir "$workspace" 2>/dev/null
      print -u2 -- 'rotateGitlabSshKey: could not install the new private key; the old key was left unchanged'
    else
      print -u2 -- "rotateGitlabSshKey: install failed and GitLab could not remove the staged key. Recovery workspace: $workspace"
    fi
    return 1
  fi
  if ! command mv "$candidate_public_key" "$public_key"; then
    if command mv "$old_private_backup" "$private_key" && command mv "$old_public_backup" "$public_key"; then
      if command glab api --hostname "$gitlab_host" --method DELETE "user/keys/$new_key_id" >/dev/null 2>&1; then
        command rm -f "$candidate_public_key" "$add_request_file" "$add_response_file" "$add_error_file"
        command rmdir "$workspace" 2>/dev/null
        print -u2 -- 'rotateGitlabSshKey: could not install the new public key; the old pair was restored'
      else
        print -u2 -- "rotateGitlabSshKey: old key pair restored, but GitLab could not remove the staged key. Recovery workspace: $workspace"
      fi
    else
      print -u2 -- "rotateGitlabSshKey: local key-pair replacement needs manual recovery. Recovery workspace: $workspace"
    fi
    return 1
  fi

  if ! command glab api --hostname "$gitlab_host" --method DELETE "user/keys/$old_key_id" >/dev/null 2>&1; then
    print -u2 -- "rotateGitlabSshKey: new key is installed, but GitLab did not confirm old-key deletion. Recovery workspace: $workspace"
    return 1
  fi
  command rm -f "$old_private_backup" "$old_public_backup" "$add_request_file" "$add_response_file" "$add_error_file"
  if ! command rmdir "$workspace" 2>/dev/null; then
    print -u2 -- "rotateGitlabSshKey: new key is active; remove the leftover recovery workspace after checking GitLab: $workspace"
    return 0
  fi
  print -- 'rotateGitlabSshKey: SSH key rotated and tested successfully'
)