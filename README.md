# dotfiles

macOS and Linux dev setup: GNU Stow packages, modular Zsh, small provisioning
scripts, and a Neovim config pinned as a submodule. cmux and Starship use the
TokyoNight Night palette.

## Quick start

```sh
git clone --recurse-submodules https://github.com/Persaud-PID/dotfiles.git
cd dotfiles
brew install stow
./setup.sh --dry-run
./setup.sh
```

Open a new shell afterwards, or run `exec zsh`. Inside cmux, run
`cmux reload-config` if terminal settings changed.

## setup.sh

`setup.sh` only links config: Zsh, Starship, cmux, Ghostty, Git, tmux, Bash and
the Alacritty package for the current platform. It doesn't install software,
change the login shell or set up agent hooks. Anything already in the way moves
to `~/.dotfiles_backup_<timestamp>.*` first, so reruns are safe.

| Option | Effect |
| --- | --- |
| `--dry-run` | Show what would change |
| `--company NAME` | Link the company config `NAME.zsh` (see below). Leave it out to keep the current one |
| `--company none` | Remove the company selection |
| `--company-dir DIR` | Location of the company-configs checkout (also `COMPANY_CONFIG_DIR`) |
| `--nvim-config DIR` | Use another Neovim config checkout (also `NVIM_CONFIG_DIR`) |
| `--skip-nvim` | Leave `~/.config/nvim` alone |
| `--target DIR` | Link into another directory, handy for testing |

### Company config

Work-specific shell config lives in the private `Persaud-PID/company-configs`
repo, not here. With `--company NAME`, setup clones that repo next to this one
if it's missing (an existing checkout is never pulled), links each `*.zsh` into
`~/.zsh/companies/` and points `~/.zsh/company.zsh` at `NAME.zsh`. Both sides
are the same file, so an edit in either place shows up in the other. Set
`COMPANY_CONFIG_REPO` to clone from somewhere else.

Links left over from the old `company/` package or
`~/.config/laptop-setup/companies/` get moved to the backup folder. Private
files are left in place.

## Installing tools

Each script covers one area. Homebrew gets installed first if it's missing.

| Script | Installs |
| --- | --- |
| `install-core-tools.sh` | Zsh/Oh My Zsh, plugins, fzf/fd, Starship, Git/delta, jq/yq, pinentry, JFrog, Zellij, Teleport |
| `typescript-dev.sh` | Node LTS via NVM, Bun, Yarn, TypeScript, ts-node, ESLint, Prettier, TypeDoc, tsx |
| `python-dev.sh` | uv-managed Python, ruff, black, isort, mypy, pytest, IPython; pipx and SSO tools on macOS |
| `rust-dev.sh` | Rust via rustup, plus everything from `python-dev.sh` and `rye-dev.sh` |
| `rye-dev.sh` | Rye, which is unmaintained; uv is the better choice |
| `go-dev.sh` | goenv, Go, golangci-lint v2, golines, gofumpt, goimports-reviser, gotests, godoc, goimports, Cobra, Air, Swag |
| `terraform-dev.sh` | tfenv/Terraform, GNU grep, tfsec, checksummed tflint, terraform-docs; OpenTofu and Terragrunt on macOS |
| `terminals-setup.sh` | tmux with TPM/sensible/resurrect, Alacritty, Hack Nerd Font |
| `kubernetes-dev.sh` | macOS: AWS CLI, kubectl, kustomize, k9s, kubeconform, Helm 3 with diff/secrets, Krew, fubectl |
| `containers-dev.sh` | macOS: Docker CLI/Compose and Colima (no VM is started) |
| `agents-setup.sh` | macOS: Pi, Devin CLI and Gemini CLI; run after `typescript-dev.sh` |
| `cmux-setup.sh` | macOS: cmux, Orca, Clocker, Obsidian, Ollama, Meslo font, agent CLIs, Pi/Gemini hooks, cmux skills |
| `neovim-setup.sh` | macOS: Neovim and its system dependencies, then links the config |
| `install-font-linux.sh` | Linux: Hack and Noto Nerd Fonts (also run by `terminals-setup.sh`) |

`./scripts/install-all.sh --company NAME` runs the whole set. It provisions the
machine, so skip it when only relinking.

Notes:

- Homebrew packages come from the `brew/Brewfile*` manifests, with no bulk
  upgrades. Stale Helm plugins are never removed and Docker/Colima are never
  started.
- Homebrew tap trust isn't changed automatically. If Homebrew refuses the cmux
  or Orca tap (`stablyai/orca`), review it and follow Homebrew's scoped trust
  instructions.
- Orca installs from its own tap as `stablyai/orca/orca`. The app updates itself
  after install. Nothing launches it.
- `cmux-setup.sh` also runs `agents-setup.sh`. Pi comes from
  `@earendil-works/pi-coding-agent` (installed with `--ignore-scripts`), Gemini
  from `@google/gemini-cli`, and Devin from the `devin-cli` cask when it's
  missing. Agents that are already installed stay, including the Devin bundled
  with the desktop app. cmux shims don't count as installed agents. Logins are
  manual.
- cmux hooks get set up for Pi and Gemini only. Claude works through cmux's
  wrapper integration, and Devin and Ollama have no hook target. Other hooks
  aren't touched.
- `ApplePressAndHoldEnabled=false` is set for `com.cmuxterm.app` only, so a held
  key repeats instead of opening the accent picker.
- Ollama installs from the `ollama-app` cask, its new Homebrew name. Nothing
  launches it, starts its server or downloads models.
- Meslo or Hack Nerd Font files installed by hand move to
  `~/.dotfiles_font_backup_<timestamp>.*` before Homebrew takes over, which
  avoids the "existing Font is different" error. Other fonts aren't touched. If
  an install fails, the originals go back, or stay in that backup folder.
- Linux support targets Ubuntu 24.04+ or a recent Debian with `eza`, using apt.
  The AWS, container and cmux installers are macOS-only. Neovim 0.12+ has to
  come from a suitable package or a source build; an older distro package won't
  be used instead.

## Layout

```text
setup.sh                         Stow links, backups, company choice, Neovim link
zsh/.zshrc                       sources ~/.zsh.d/*.zsh in numeric order
zsh/.zsh.d/                      paths, core, runtimes, completions, cloud and GitLab helpers
starship/.config/starship.toml   TokyoNight Night prompt; Git status stays in the cmux sidebar
cmux/.config/cmux/cmux.json      cmux app and sidebar settings
ghostty/.config/ghostty/config   terminal theme and Nerd Font
git/.config/git/                 Git defaults, included from ~/.gitconfig
tmux/.tmux.conf                  Tokyo Night, Ctrl-F prefix, TPM plugins
bash/.bashrc                     Bash fallback
alacritty-{darwin,linux}/        TOML config, palettes, original YAML
pi-powerline-footer/theme.json   pi footer theme (the extension itself isn't included)
nvim/.config/nvim/               Persaud-PID/nvim-config submodule, linked directly, not stowed
brew/Brewfile*                   package lists by workflow
scripts/                         installers and shared helpers in scripts/lib/
tests/                           setup tests and mocked GitLab rotation tests
legacy/                          old bootstrap script, kept but never run
```

Every package mirrors its path under `$HOME`. `--no-folding` keeps directories
real and links only files, so cmux locks, shell state and caches never end up in
the repo. Changes saved to the linked `cmux.json` show up as normal Git diffs.

## Shell

- `EDITOR` and `VISUAL` are `nvim` when it's installed. Ctrl-X Ctrl-E opens the
  current command in the editor and runs it on exit unless it's empty, so treat
  it as "edit and run", not a preview.
- Helpers: AWS profiles (`useprof`, `saveprof`, `unsetAWS`), Kubernetes/Helm,
  Git/PR shortcuts, GitLab rotation, and whatever the selected company config
  adds. `saveprof` only writes to `~/.zsh/aws-profile.zsh`.
- `grep` is an interactive alias for ripgrep and `diff` uses GNU diff with
  colour. Typing a source or config filename on its own opens it in bat;
  executable scripts still run normally.
- `rotateGitlabToken` and `rotateGitlabSshKey` read `GITLAB_ROTATION_HOST`,
  `GITLAB_ROTATION_OP_ITEM_ID` and optionally `GITLAB_ROTATION_KEY_TITLE`, for
  example from `~/.envrc`. Without those variables, both stop before contacting
  anything.
- `k8sDebug helloWorld` runs the image in `K8S_DEBUG_HELLO_WORLD_IMAGE`.

Private files, never stowed:

- `~/.zsh/secrets.env` for secrets.
- `~/.zsh/local.zsh` for machine-only overrides.
- `PE_ROOT` points at an optional corporate CLI and completions directory.

Secrets don't belong in cmux actions, Neovim overrides or tracked Zsh modules.

## Toolchains

- Go comes from goenv (`~/.goenv`) and Terraform from tfenv (`~/.tfenv`). A
  project's `.go-version` or `.terraform-version` wins over the global version.
- A one-time migration removes Homebrew Go/Cobra and tenv once the replacements
  work. OpenTofu and Terragrunt stay as separate packages. Regular runs don't
  uninstall anything.
- Node LTS comes from NVM. When the version changes, global npm packages get
  reinstalled so the agent CLIs stay on `PATH`.
- Python defaults to uv's managed Python. Rye's shims sit behind uv on `PATH`.
  Project environments are never deleted.
- Global tool versions can drift from a project's own. `npx`, `uv run` and
  lockfiles keep builds reproducible.
- Alacritty opens tmux; cmux doesn't. The tmux prefix is Ctrl-F (press it twice
  to send Ctrl-F), and the tmux status bar only shows inside tmux.
- The Alacritty Homebrew cask is disabled, so on macOS it's built from the
  crates.io release with Cargo, with no Gatekeeper bypass.

## Neovim

The config lives in [Persaud-PID/nvim-config](https://github.com/Persaud-PID/nvim-config),
pinned here as the `nvim/.config/nvim` submodule and linked to
`~/.config/nvim`. It uses Tokyo Night Storm and lualine, with Go, TypeScript,
Python and Terraform support. AI integrations are off by default.

Requirements: Neovim 0.12+, `tree-sitter-cli`, Git, `cc` (Xcode Command Line
Tools), Node/npm, `fd`, `ripgrep`, `lazygit` and a Nerd Font.

`neovim-setup.sh` installs those, checks the Neovim version without loading the
config, then links it. It doesn't clone or update the config, run Lazy or Mason,
or touch `lazy-lock.json`. Plugins, parsers and language tools install from
inside Neovim: `:checkhealth`, `:Lazy`, `:Mason`.

Cloned without submodules:

```sh
git submodule update --init --recursive
./setup.sh
```

Config checked out somewhere else (`neovim-setup.sh` and `install-all.sh` take
the same flag):

```sh
./setup.sh --nvim-config "$HOME/src/nvim-config"
```

If the checkout is missing or has no `init.lua`/`init.vim`, setup prints a
warning and leaves `~/.config/nvim` as it is, broken links included. An existing
link gets backed up before it's replaced.

Keys:

- `<Space>p` find files, `<Space>fs` search text
- Ctrl-N file explorer, Ctrl-G LazyGit
- `jk` leave insert mode, `:wq` save and quit, `:q!` quit without saving
- `:Lazy` plugins, `:Mason` language servers and formatters

Editor changes, plugins and `lazy-lock.json` get committed in nvim-config; this
repo only records which commit to use. A standalone nvim-config clone and this
submodule are separate checkouts, so changes pushed from the clone need a
pointer bump here:

```sh
git submodule update --remote -- nvim/.config/nvim
git diff --submodule -- nvim/.config/nvim
git add nvim/.config/nvim
git commit -m "Update nvim-config"
```

Machine-only Neovim settings go in `~/.config/nvim/lua/config.local.lua`, which
nvim-config ignores. `:Lazy sync` updates plugins.

## Legacy

The old single-script bootstrap is kept in `legacy/` and never runs. iTerm2
preferences and shell integration are gone; existing transcript folders are
left alone. Nothing here edits `/etc/shells`, runs `chsh` or launches apps.

## Adding config

- New package: create `<package>/<path under $HOME>` and add it to `PACKAGES`
  in `setup.sh`.
- Zsh: add to the right numbered module in `zsh/.zsh.d/`. Syntax highlighting
  stays last.
- Software: add it to a `brew/Brewfile*` or a focused script, never to
  `setup.sh`.

## Tests

```sh
bash tests/dotfiles-setup.sh
bash tests/neovim-setup.sh
bash tests/agents-setup.sh
bash tests/provisioning-helpers.sh
bash tests/font-cask.sh
zsh -f tests/gitlab-token-rotation.zsh
zsh -f tests/gitlab-ssh-key-rotation.zsh
cmux config validate --path cmux/.config/cmux/cmux.json --scope global
```

The tests use temporary home folders and mocked services; nothing touches real
GitLab or 1Password.
