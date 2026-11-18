## Why

Rotating a GitLab personal access token stored in 1Password currently requires manually transferring a secret between GitLab and 1Password. A callable shell helper should perform the rotation and persist the replacement safely, accounting for GitLab immediately revoking the previous token.

## What Changes

- Add an explicitly invoked, no-argument `rotateGitlabToken` function to `zsh/.zsh.d/72-gitlab.zsh`; sourcing the file must not rotate tokens or contact either service.
- Read the current token from the 1Password item whose ID is set in `GITLAB_ROTATION_OP_ITEM_ID`, in the `Employee` vault, selecting exactly one field with label `credential`.
- POST once to `https://$GITLAB_ROTATION_HOST/api/v4/personal_access_tokens/self/rotate`, authenticating with the current token and requesting an expiration date 90 days from invocation. The lifetime was confirmed by the user. The host and item ID are kept out of the repository (for example in `~/.envrc`); missing or invalid values fail before any service access.
- Validate the response and replace only the selected credential field in the same 1Password item, preserving supported unrelated item data and verifying the saved value.
- Keep secrets out of command arguments, tracing, terminal output, and repository files. Preserve normal certificate verification and the existing corporate trust configuration.
- Serialize local invocations. If rotation succeeds but persistence fails, or the POST outcome is uncertain, retain owner-only recovery state, block another local rotation until recovery is resolved, and report non-secret recovery guidance rather than retrying the POST.
- Add isolated zsh tests with mocked service commands; verification must not rotate a live token.

## Capabilities

### New Capabilities

- `gitlab-token-rotation`: Explicit shell-driven rotation of the configured GitLab personal access token, secure replacement in 1Password, and safe failure/recovery behavior.

### Modified Capabilities

None. The project has no existing OpenSpec capabilities.

## Impact

- Implementation target: `zsh/.zsh.d/72-gitlab.zsh`, loaded by the Stow-managed `.zshrc`. The host and item ID are read from `GITLAB_ROTATION_HOST` and `GITLAB_ROTATION_OP_ITEM_ID` at invocation.
- Test target: a new self-contained `tests/gitlab-token-rotation.zsh`; no existing automated test framework was found.
- Dependencies: existing `curl`, `jq`, and 1Password CLI (`op`), plus standard macOS utilities. `jq` is already installed by the bootstrap script; all three CLIs are present on this machine. No bootstrap changes or new package dependency are planned.
- External systems: the configured GitLab instance and the single configured 1Password item. The existing token needs `api` or `self_rotate` scope, and the selected 1Password account needs item read/write access.
- Local runtime state: a private lock/recovery directory outside the repository, with temporary secret material removed only after a verified successful update or a confirmed pre-rotation failure.
- Out of scope: scheduled rotation, rotating other items, changing token scopes, propagating tokens into running shells or other consumers, bypassing GitLab lifetime policy, and live API execution during proposal or automated verification.
