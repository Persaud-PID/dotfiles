## Context

See `proposal.md` for motivation and `specs/gitlab-token-rotation/spec.md` for the behavior contract. `zsh/.zsh.d/72-gitlab.zsh` is loaded by the Stow-managed `.zshrc`. The GitLab host and 1Password item ID come from the private `GITLAB_ROTATION_HOST` and `GITLAB_ROTATION_OP_ITEM_ID` environment variables (for example in `~/.envrc`); the private company configuration may set `SSL_CERT_FILE`. `curl`, `jq`, and 1Password CLI (`op`) are installed; `jq` is a bootstrap dependency.

The local OpenSpec change and configuration are uncommitted. Preserve unrelated user edits. Do not read the live vault item, display secrets, or perform a live rotation during implementation or tests.

GitLab self-rotation revokes the old token and returns the new token once. Replaying a revoked token can revoke its active token family. 1Password supports piping updated item JSON to `op item edit`; passing a secret as a field-assignment argument can expose it in process arguments.

## Goals / Non-Goals

**Goals:**
- Add one small, explicitly invoked helper with no startup network activity.
- Update the credential through the existing CLI without putting either token in a command argument or terminal output.
- Retain one private recovery response and block another local rotation if the result may have changed at GitLab but was not saved to 1Password.
- Test only with synthetic fixtures and stubbed service commands.

**Non-Goals:**
- A general-purpose API client, automatic retry/resume, separate recovery command, extensive signal framework, or guarantee against manual/concurrent rotations from other machines.
- A pre-rotation GitLab status GET, token consumer/environment updates, or live API execution.

## Decisions

### Keep the shell workflow; configure host and item privately

Add the no-argument `rotateGitlabToken` function to `zsh/.zsh.d/72-gitlab.zsh`. Read the host from `GITLAB_ROTATION_HOST` and the item ID from `GITLAB_ROTATION_OP_ITEM_ID` at invocation, and reject a missing value, a host that is not a bare hostname, or a non-alphanumeric item ID before any other work. Use the `Employee` vault, the unique `credential` field, and the agreed 90-day UTC expiry. Run the function body in a subshell so its `umask`, shell options, and local state do not change the interactive shell. Reject arguments and missing commands before accessing the item. Sourcing the file performs no rotation.

The example's preliminary token-status GET and DuckDB parser are unnecessary for self-rotation: the POST uses the current token itself and `jq` is already available. Only the host and item ID are configurable; the path, vault, field, and lifetime stay fixed. This avoids a general configuration interface while keeping internal identifiers out of the repository.

### Carry secrets only through stdin and a private response file

Read the specified item as JSON with `op item get --vault Employee --format json --reveal`. Require the API Credential category and exactly one nonempty `credential` field. Hold the current value only in a non-exported local variable. Compute the UTC expiry using macOS `date -u -v+90d`.

Atomically create a deterministic, owner-only workspace below `${TMPDIR:-/tmp}` before reading the item; its existence is both the local lock and an unresolved-recovery marker. Precreate an owner-only response JSON file there. An existing path is a hard stop, so a retained replacement cannot be overwritten by a second local rotation.

Send exactly one HTTPS POST to the self-rotation endpoint. Put `-q` first to ignore `.curlrc`, keep TLS verification on, use `SSL_CERT_FILE` with `--cacert` when set, bound request time, and never follow redirects or retry. Pipe the `PRIVATE-TOKEN` header to `curl --header @-`. Write the response to the protected file and capture the HTTP status separately. Keep the body even when transport or status is uncertain; never print it.

### Replace one field and rely on the CLI result

Validate HTTP 200 and a nonempty string `token` before any edit. Use `jq --slurpfile` to replace only the selected field's `value` in the item JSON already fetched, then pipe that JSON to `op item edit <uuid> --vault Employee`. The token is never a `jq --arg` or `op` argument. Suppress command output and report a short success message only if `op item edit` exits successfully; no extra read-back request is needed. This trusts the 1Password CLI write result; mocked verification covers that result and field preservation.

### Keep recovery small and manual

Before the POST, any ordinary error removes the invocation's empty workspace. After the POST starts, any transport, response-validation, or 1Password update failure retains the response file and lock and reports the private path without printing token contents. The next local invocation refuses to run while that path exists. The user must inspect the protected response, save a valid replacement to the same item, verify it in 1Password, and then remove the recovery workspace. Never retry the POST with the old token.

The filesystem state itself persists if the function is interrupted; do not add custom signal traps or automatic stale-lock cleanup. If an interruption occurs before the POST, the empty lock may need manual removal; if after it, first reconcile GitLab and 1Password. This small fail-closed behavior is preferred over a larger trap/recovery framework.

## Risks / Trade-offs

- **GitLab and 1Password writes are not atomic** → Keep the response in a 0600 file inside a 0700 workspace until `op item edit` succeeds. If the workspace is lost before saving, manual GitLab recovery may be required.
- **The item JSON is the snapshot fetched before the POST** → A concurrent edit to unrelated 1Password metadata during rotation could be overwritten. This local one-person helper does not implement optimistic concurrency or a second fetch.
- **An interrupted operation can leave a stale lock** → Fail closed and require manual reconciliation/cleanup instead of guessing whether GitLab rotated.
- **The live item category and server lifetime policy are unverified** → Abort before POST for an unsupported category or invalid credential; surface GitLab rejection without shortening the requested 90-day expiry.

## Migration Plan

Set `GITLAB_ROTATION_HOST` and `GITLAB_ROTATION_OP_ITEM_ID` privately, then start a new shell to define the helper; sourcing it does not rotate a token. The first live invocation is left to the user. Removing the function later cannot undo a completed GitLab rotation. Resolve any retained recovery workspace before invoking the helper again.

## References

- User-provided example: https://www.fedux.net/post/rotate-gitlab-pat/
- GitLab rotation and self-rotation: https://docs.gitlab.com/api/personal_access_tokens/
- 1Password item JSON editing: https://www.1password.dev/cli/item-edit
