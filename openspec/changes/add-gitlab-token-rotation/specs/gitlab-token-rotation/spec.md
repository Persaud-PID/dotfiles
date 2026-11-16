## Purpose

Allow the user to explicitly rotate the configured Zscaler GitLab personal access token and update its 1Password credential without exposing the token or losing a replacement that GitLab has already issued.

## ADDED Requirements

### Requirement: Rotation is explicitly invoked

The Zscaler shell configuration SHALL expose a no-argument `rotateGitlabToken` command. Loading the configuration SHALL NOT contact GitLab or 1Password for rotation. Unexpected arguments or unavailable required commands SHALL return nonzero without rotating a token.

#### Scenario: Loading shell configuration
- **WHEN** the user sources the Zscaler shell configuration
- **THEN** the command is available and no rotation request is made

#### Scenario: Invalid invocation or missing dependency
- **WHEN** the user supplies an argument or a required command is unavailable
- **THEN** the helper returns nonzero and makes no rotation POST

### Requirement: Rotate only the configured credential

The helper SHALL read item `syntheticitemfixture0001` from the `Employee` vault, require the `API_CREDENTIAL` category, and use exactly one nonempty field labeled `credential`. It SHALL make at most one POST to `https://gitlab.example.com/api/v4/personal_access_tokens/self/rotate`, authenticated with that current token, requesting a UTC `expires_at` date 90 days after invocation in `YYYY-MM-DD` format.

#### Scenario: Valid configured item
- **WHEN** the specified item and unique credential field are valid
- **THEN** one POST is sent to the corporate self-rotation endpoint with the agreed expiry

#### Scenario: Invalid or unsupported item
- **WHEN** the item cannot be read, is not an API Credential, or has a missing, duplicate, empty, or invalid credential field
- **THEN** the helper returns nonzero without issuing a POST or editing 1Password

### Requirement: Validate the response and update only the credential

The helper SHALL update 1Password only when the request completes successfully with HTTP 200 and a nonempty string `token`. It SHALL update only the selected credential value in the same item's fetched JSON, preserve the other fields in that snapshot, and pipe the edited JSON to the 1Password CLI. A successful CLI write is sufficient to report success; no separate read-back is required. HTTP failures, invalid JSON/token responses, and write failures SHALL return nonzero.

#### Scenario: Rotation and 1Password update succeed
- **WHEN** GitLab returns a valid replacement and the CLI accepts the updated item JSON
- **THEN** only the credential field is replaced and the helper reports non-secret success

#### Scenario: Invalid response or 1Password write failure
- **WHEN** the POST fails, returns a non-200 status or invalid token, or the CLI write fails
- **THEN** the helper returns nonzero, does not retry the POST, and preserves post-request recovery data and its blocking marker

### Requirement: Protect tokens and recover from an unresolved rotation

The helper SHALL NOT print either token or pass a token as an external command argument. It SHALL keep TLS verification enabled and honor configured corporate trust. Before the POST, it SHALL create a private local lock/recovery workspace and response file with owner-only permissions. If the POST may have started but the result is not saved to 1Password, it SHALL retain the response and lock, report only the private path and non-secret recovery guidance, and refuse a subsequent local rotation while that workspace remains.

#### Scenario: Secret-safe request and update
- **WHEN** the helper calls GitLab and updates the item
- **THEN** the request token is supplied through stdin, the replacement is supplied to the item update through JSON stdin, and neither token appears in terminal output or command arguments

#### Scenario: The replacement cannot be saved or the request outcome is uncertain
- **WHEN** a failure occurs after the POST may have reached GitLab
- **THEN** the private response and lock remain available, the old token is not assumed safe to retry, and another local invocation is blocked until the user reconciles the token in 1Password
