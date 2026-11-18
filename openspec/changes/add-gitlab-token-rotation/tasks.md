## 1. Establish isolated tests before implementation

- [x] 1.1 Add `tests/gitlab-token-rotation.zsh` with synthetic item/response fixtures, isolated temporary state, and strict PATH stubs for service commands that cannot fall through to live `op` or `curl`; verify the harness passes `zsh -n tests/gitlab-token-rotation.zsh` and unexpected mock calls fail closed.
- [x] 1.2 Add a failing end-to-end happy-path test for the public no-argument helper, exact configured item/vault/field, corporate endpoint, 90-day expiry, single POST, same-field replacement via the CLI, and cleanup; run the harness and verify it fails because the helper is not implemented, without any real service call.

## 2. Add the helper and preflight guards

- [x] 2.1 Add `rotateGitlabToken` to `company/zscaler.zsh` with isolated zsh state, disabled secret tracing/export, dependency checks, and no-argument validation; verify tests for source-time inactivity, unexpected arguments, missing dependencies, and unchanged caller directory/options/traps/umask/environment.
- [x] 2.2 Implement private retrieval and validation of the specified item's unique credential field and supported lossless JSON representation, using documented/static CLI item formats to define the safe category guard; verify fixtures for authentication/read failure, invalid JSON, missing/duplicate fields, null/non-string/empty/whitespace/CRLF credentials, and unsupported/passkey-bearing items all prevent POST and edit.
- [x] 2.3 Implement atomic owner-only local locking before credential retrieval and precreated owner-only response storage outside the repository; verify existing locks, retained recovery, workspace symlinks, and storage-creation failures prevent token retrieval/POST, and verify private directory/file permissions.

## 3. Implement the secured single rotation request

- [x] 3.1 Calculate a UTC `YYYY-MM-DD` expiry 90 days ahead with macOS-compatible date arithmetic; verify deterministic expiry arguments and that date failure prevents all service calls.
- [x] 3.2 Issue one HTTPS POST with curl defaults disabled, the token header delivered through stdin, configured corporate CA trust, bounded timeouts, private body/status capture, and no redirects/retries; verify mock argv/stdin checks for the exact URL, header, expiry, TLS settings, timeout settings, absence of token arguments, and no inherited unsafe curl settings.
- [x] 3.3 Validate HTTP 200 and a nonempty replacement token before persistence; verify a representative non-200 response, invalid token response, and transport failure do not update 1Password or retry the POST.

## 4. Keep the item update small and secret-safe

- [x] 4.1 Use the already fetched API Credential JSON to replace only the selected field's value and pipe the full updated JSON to `op item edit`; verify a mocked successful update preserves the other fields in that snapshot and no token appears in the CLI arguments.
- [x] 4.2 Treat successful `op item edit` as save confirmation, without a second read-back; verify a failed edit returns nonzero and leaves the private response and lock intact.

## 5. Preserve recovery only where rotation makes it necessary

- [x] 5.1 Verify pre-POST item/credential/expiry failures release the newly created empty lock, a possibly started but unsaved POST retains the owner-only response and lock, a second invocation is blocked, and a successful update removes the temporary state.
- [x] 5.2 Ensure diagnostics never print response bodies or tokens and tell the user where to find the protected response plus how to manually reconcile 1Password before clearing the lock; verify with synthetic tokens.

## 6. Verify the focused implementation

- [x] 6.1 Run `zsh -n company/zscaler.zsh`, `zsh -n tests/gitlab-token-rotation.zsh`, and `zsh -f tests/gitlab-token-rotation.zsh`; verify mocked success, invalid response, failed save/recovery, blocking, and secret-hygiene scenarios without live services.
- [x] 6.2 Review `git diff` and `git diff --check` to preserve existing user edits/comments, confirm only the helper and its tests are added, and verify no live token rotation was performed.

## 7. Fix Zsh compatibility regression

- [x] 7.1 Remove the unsupported Zsh option and avoid leaking preflight cleanup helpers into the interactive shell; verify clean success stderr, unchanged caller options, and no helper-function pollution on the installed Zsh version.

## 8. Keep internal identifiers out of the repository

- [x] 8.1 Move the helper to `zsh/.zsh.d/72-gitlab.zsh` and read the host and item ID from `GITLAB_ROTATION_HOST` and `GITLAB_ROTATION_OP_ITEM_ID`; verify missing or invalid configuration fails before item retrieval, locking, or POST, and that tests use only placeholder hosts and item IDs.
