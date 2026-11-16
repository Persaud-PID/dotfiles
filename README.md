# Dotfiles

Personal macOS/Linux development environment, organized like
[catpaladin/dotfiles](https://github.com/catpaladin/dotfiles): GNU Stow packages,
modular Zsh, focused provisioning scripts, and your own Neovim config pinned as a
Git submodule.
cmux and Starship use the TokyoNight Night palette.

## Quick Start

```sh
git clone --recurse-submodules https://github.com/Persaud-PID/dotfiles.git
cd dotfiles
brew install stow
./setup.sh --dry-run --company zscaler
./setup.sh --company zscaler
```

`setup.sh` only links configs, including tmux, Bash and platform-specific Alacritty.
It never adopts local files into Git, installs
software, runs agent hooks, or changes your login shell. Existing conflicts move
to a private `~/.dotfiles_backup_<timestamp>.*` directory. Repeated runs are
idempotent. Use `--company chewy`, `--company none`, or omit the option to retain
the currently selected company. Neovim links to the `nvim/.config/nvim` submodule
when initialized; otherwise setup warns and leaves the existing config untouched.
Use `--nvim-config DIR` or `NVIM_CONFIG_DIR` for another location, or
`--skip-nvim` to leave Neovim untouched. `--target DIR` supports an isolated
preview/test.
Company definitions mirror `~/.zsh/companies/` through the `company/` Stow package.
The selected definition is loaded through `~/.zsh/company.zsh`. Open a new shell
after switching companies. Setup backs up owned links from the former
`~/.config/laptop-setup/companies/` layout without moving private files.

On a fresh Mac, choose the individual installers you need (Homebrew is installed
if absent):

```sh
./scripts/install-core-tools.sh   # shell, plugins, prompt, Git and shared CLI tools
./scripts/typescript-dev.sh       # NVM, Node/npm/npx, Bun, Yarn and TypeScript tools
./scripts/agents-setup.sh         # macOS: pi, Devin CLI, Gemini CLI (after typescript-dev.sh)
./scripts/python-dev.sh           # uv, managed Python, Python tools; pipx/SSO on macOS
./scripts/rust-dev.sh             # Rust/Cargo; also runs python-dev.sh and rye-dev.sh
./scripts/rye-dev.sh              # standalone legacy Rye compatibility; prefer uv
./scripts/go-dev.sh               # goenv + Go and development tools
./scripts/terraform-dev.sh        # tfenv + Terraform and helpers
./scripts/kubernetes-dev.sh       # macOS: AWS, Kubernetes, Helm, Krew and helpers
./scripts/containers-dev.sh       # macOS: Docker/Compose + Colima; does not start a VM
./scripts/terminals-setup.sh      # tmux/TPM, Alacritty, Hack Nerd Font
./scripts/neovim-setup.sh --company zscaler # macOS: editor dependencies and external config link
./scripts/cmux-setup.sh           # macOS: cmux/Obsidian/Ollama, agent CLIs/hooks and cmux skills

# Linux only; also called by terminals-setup.sh on Linux:
# ./scripts/install-font-linux.sh # Hack and Noto Nerd Fonts

# Alternative: run the full setup instead of the individual installers:
# ./scripts/install-all.sh --company zscaler
```

The standalone Python and Rye commands are alternatives if you do not run the
Rust installer; running all three repeats those setup steps.

For the complete former bootstrap toolset, run
`./scripts/install-all.sh --company zscaler`. This explicitly provisions the Mac;
do not run it just to update symlinks. Installers use declarative `brew/Brewfile*`
manifests without bulk upgrades, and never remove stale Helm plugins or start
Docker/Colima. Homebrew tap trust is not changed automatically; if Homebrew refuses
the cmux tap, review it and follow Homebrew's scoped trust instructions.

`cmux-setup.sh` also runs `agents-setup.sh`, including during the full install.
The agent installer uses the NVM default runtime, installs Pi from
`@earendil-works/pi-coding-agent` (with `--ignore-scripts`) and Gemini from
`@google/gemini-cli`, and uses Homebrew's `devin-cli` cask when Devin is absent.
Existing agents, including desktop-bundled Devin, are kept; cmux-only shims do
not count as installed agents. Authentication stays manual.

cmux hook setup is restricted to **Pi and Gemini**, after their CLIs are available.
Claude uses cmux's automatic wrapper integration. Devin and Ollama have no
dedicated `cmux hooks setup` target. Setup does not scan all agents on `PATH` or
uninstall other hooks automatically.

The cmux installer also sets `ApplePressAndHoldEnabled=false` for
`com.cmuxterm.app` only, so holding a key repeats it instead of opening the macOS
accent picker.

The app manifest includes Obsidian and Ollama's desktop app/CLI. Homebrew renamed
the `ollama` cask to `ollama-app`, so the manifest uses the current name
(`brew install --cask ollama-app`). Setup does not launch Ollama, start its server,
or download models.

The macOS cmux/terminal installers migrate manually installed Meslo/Hack Nerd
Fonts before Homebrew manages them. Only the requested Nerd Font family's TTF
files move to a private `~/.dotfiles_font_backup_<timestamp>.*` directory outside
Font Book's font folder; unrelated fonts are left alone. Already-managed font
casks are skipped. If installation fails, original files are restored where no
replacement exists; any remaining originals stay in the printed backup directory.
This handles Homebrew's "existing Font is different" adoption error without
force-overwriting fonts or changing tap trust.

Linux reference provisioning supports Ubuntu 24.04+ or a recent Debian with
`eza` available. It uses apt and installs the same shell/language/terminal tools;
`scripts/install-font-linux.sh` supplies Hack and Noto Nerd Fonts. The extra
AWS/container/cmux Mac installers remain macOS-specific. Linux Neovim requires
0.12+ from a suitable package or source build; an older distro package is not
silently substituted.

Open a new cmux shell after linking, or run `exec zsh` in an idle shell.
Run `cmux reload-config` **inside cmux** for terminal/config changes if necessary.

## Layout

```text
setup.sh                         # GNU Stow, backups, company choice, nvim link
zsh/.zshrc                       # sources ~/.zsh.d/*.zsh in numeric order
zsh/.zsh.d/                      # paths, core, runtimes, completions, cloud helpers
starship/.config/starship.toml   # TokyoNight Night prompt; Git stays in cmux sidebar
cmux/.config/cmux/cmux.json      # native app/sidebar preferences
ghostty/.config/ghostty/config   # terminal theme and Nerd Font
git/.config/git/                 # Git defaults included from private ~/.gitconfig
company/.zsh/companies/          # company shell definitions; select with --company
tmux/.tmux.conf                  # Tokyo Night, Ctrl-F prefix, TPM plugins
bash/.bashrc                     # reference Bash fallback
alacritty-{darwin,linux}/         # current TOML, all palettes, original YAML
pi-powerline-footer/theme.json  # same footer theme asset as the reference
nvim/.config/nvim/               # Persaud-PID/nvim-config Git submodule; not stowed
brew/Brewfile*                   # package inventories by workflow
scripts/lib/common.sh            # shared provisioning helpers
scripts/*-dev.sh                 # optional language/cloud/container setup
tests/                          # isolated setup and mocked GitLab rotation tests
docs/reference-comparison.md     # what differs from catpaladin/dotfiles
legacy/                         # retired bootstrap, not executed
```

All Stow packages mirror their destination under `$HOME`. `--no-folding` keeps
writable config directories real, with only individual files symlinked. This
prevents cmux locks, private shell state, and caches from landing in the repo.
Settings saved to the linked cmux JSON file become normal Git diffs; runtime
sessions, browser data, and credentials are not source-controlled.
Neovim configuration belongs to
[`Persaud-PID/nvim-config`](https://github.com/Persaud-PID/nvim-config), included
here as the `nvim/.config/nvim` submodule and linked directly to `~/.config/nvim`.

## Neovim In cmux

`nvim` runs in any cmux terminal pane. The shell sets `EDITOR`/`VISUAL` to `nvim`
when installed. Like the reference, Ctrl-X Ctrl-E edits the current shell command
and executes the nonempty result on return. Treat this as an execution shortcut,
not just a preview. cmux's own built-in file viewer remains unchanged.

Requirements: Neovim **0.12+**, `tree-sitter-cli`, Git, `cc`/Xcode Command Line
Tools, Node/npm, `fd`, `ripgrep`, `lazygit`, and a Nerd Font. The macOS Neovim
installer installs system dependencies, checks the version without loading user
configuration, and calls the config-linking setup. It does not clone/update the
config repository, run Lazy/Mason, or change `lazy-lock.json`. Plugin, parser and
language-tool installation belongs to your Neovim configuration and may require
network access when you open the editor. Use `:checkhealth`, `:Lazy` and `:Mason`
there.

The home-mirrored layout is:

```text
dotfiles/
  nvim/.config/nvim/            # separate Git repo: init.lua, lua/, lazy-lock.json
```

The default needs no extra setup arguments. If you cloned without
`--recurse-submodules`, initialize the pinned config explicitly:

```sh
git submodule update --init --recursive
./setup.sh
```

For a different checkout location (including a standalone clone):

```sh
./setup.sh --nvim-config "$HOME/src/nvim-config"
# Equivalent environment override; an explicit --nvim-config takes precedence:
NVIM_CONFIG_DIR="$HOME/src/nvim-config" ./setup.sh

# Install Neovim/system dependencies and link the same external checkout:
./scripts/neovim-setup.sh --nvim-config "$HOME/src/nvim-config"
# The full macOS installer also accepts the override:
./scripts/install-all.sh --company zscaler --nvim-config "$HOME/src/nvim-config"
```

A missing/uninitialized checkout or directory without `init.lua`/`init.vim`
produces a warning and leaves `~/.config/nvim` unchanged, including existing or
broken symlinks. Setup does not initialize or update submodules automatically.
Valid link replacements are backed up first, and repeat runs are idempotent.
`--skip-nvim` skips Neovim linking even if a valid checkout is available.

Upstream uses **Tokyo Night Storm** and lualine inside the editor. It enables
Go, TypeScript, Python and Terraform support; AI integrations are off by default.
It does not replace the shell prompt with a persistent terminal status bar.

- `<Space>p`: find files; `<Space>fs`: search project text.
- Ctrl-N: explorer; Ctrl-G: LazyGit.
- `jk`: exit insert mode; `:wq`: save and quit; `:q!`: quit without saving.
- `:Lazy`: plugins; `:Mason`: language servers/formatters.

Commit editor settings, themes, plugins and `lazy-lock.json` in the `nvim-config`
repository; dotfiles records only its commit pointer. Optional machine-local
upstream settings can still use `~/.config/nvim/lua/config.local.lua`, which that
repo ignores. Use `:Lazy sync` when you intentionally want to update plugins.

Your standalone `nvim-config` clone and this submodule are separate checkouts,
not symlinks to each other. Edits in one do not automatically appear in the other.
You can keep editing/pushing from the standalone clone, then update the submodule
and commit its new pointer in dotfiles.

Updating is explicit, never a side effect of `setup.sh`:

```sh
# After committing/pushing the desired changes in nvim-config:
git submodule update --remote -- nvim/.config/nvim
git diff --submodule -- nvim/.config/nvim
git add nvim/.config/nvim
# Review and commit the updated config pointer in dotfiles.
```

## Preserved Workflows

Provision only the pieces you want:

| Script | Tools / behavior |
| --- | --- |
| `install-core-tools.sh` | Zsh/Oh My Zsh, plugins, fzf/fd, Starship, Git/delta, jq/yq, pinentry, JFrog, Zellij, Teleport |
| `python-dev.sh` | uv-managed Python, ruff, black, isort, mypy, pytest, IPython; pipx/SSO on macOS |
| `typescript-dev.sh` | Node LTS via NVM; Bun, Yarn, TypeScript, ts-node, ESLint, Prettier, TypeDoc, tsx |
| `rust-dev.sh` | Rust/rustup/Cargo, reference Python companions and Rye |
| `rye-dev.sh` | deprecated Rye for exact reference compatibility; uv is preferred |
| `go-dev.sh` | goenv, Go, golangci-lint v2, golines, gofumpt, goimports-reviser, gotests, godoc, goimports, Cobra, Air, Swag |
| `terraform-dev.sh` | tfenv/Terraform, GNU grep, tfsec, checksummed tflint, terraform-docs, standalone OpenTofu/Terragrunt on macOS |
| `terminals-setup.sh` | tmux, TPM/sensible/resurrect, Alacritty and Hack Nerd Font |
| `kubernetes-dev.sh` | AWS CLI, kubectl, kustomize, k9s, kubeconform, Helm 3 + diff/secrets, Krew, fubectl |
| `containers-dev.sh` | Docker CLI/Compose and Colima; no VM start |
| `agents-setup.sh` | macOS: Pi, Devin CLI and Gemini CLI; keeps existing agents and leaves login manual |
| `cmux-setup.sh` | cmux, Clocker, Obsidian, Ollama app/CLI, Meslo font, agent CLIs, Pi/Gemini hooks and global cmux skills |
| `neovim-setup.sh` | Neovim/system dependencies and external config linking; no plugin or lockfile provisioning |

AWS profile helpers (`useprof`, `saveprof`, `unsetAWS`), Kubernetes/Helm helpers,
Git/PR commands, and company helpers are retained. `saveprof` now persists only
to private `~/.zsh/aws-profile.zsh`, not a source-controlled shell file.
Git defaults are included without replacing user identity/credentials.

## Toolchain And Terminal Changes

- Go is managed by `~/.goenv`; Terraform by `~/.tfenv`. Project `.go-version` and
  `.terraform-version` files can override global selections.
- The one-time migration removes superseded Homebrew Go/Cobra and tenv after
  replacement verification. OpenTofu and Terragrunt remain available separately.
  Normal provisioning does not perform those uninstalls.
- NVM selects Node LTS. On a version change the script reinstalls existing global
  npm packages into the new runtime, so agent CLIs do not disappear from PATH.
- Python defaults to uv's managed Python. Rye is installed for parity but is
  unmaintained; its shims stay behind uv on PATH. No project environments are deleted.
- Global tool versions may differ from project-local dependencies. Prefer
  `npx`, `uv run` and project lockfiles for reproducible builds.
- Alacritty opens tmux; cmux does not. tmux's prefix is Ctrl-F (press twice to
  forward Ctrl-F). Its status bar exists only inside tmux.
- The Alacritty Homebrew cask is disabled. The macOS installer builds the
  crates.io release with Cargo without bypassing Gatekeeper or disabling security.
- `grep` is an interactive alias for ripgrep, `diff` uses colour-capable GNU diff,
  and typing source/config filenames uses the reference bat suffix aliases.
  Executable scripts still execute normally; non-executable scripts open in bat.
- The pi footer theme is included like the reference; that repository does not
  bundle/install the footer extension or provide any API credentials.

Keep secrets in private `~/.zsh/secrets.env`; keep machine-only overrides in
`~/.zsh/local.zsh`. Neither file is stowed. The `PE_ROOT` override controls the
optional corporate CLI/completion directory without hard-coded usernames.
Do not put secrets in cmux actions, Neovim overrides, or tracked Zsh modules.

The old monolithic bootstrap is preserved in `legacy/` only. Obsolete iTerm2
preferences and shell integration have been removed from this setup; existing
session transcript folders are not managed or deleted by setup.
The installer no longer changes `/etc/shells`, calls `chsh`, or launches apps.

## Add Configuration

Create `<package>/<home-relative-path>` and add the package to `PACKAGES` in
`setup.sh`. Add Zsh functionality to the appropriate numbered module (syntax
highlighting stays last). Add software to a `brew/Brewfile*` or a focused script,
not to config-linking setup.

## Verification

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

The tests use temporary homes and mocked services, not real GitLab credentials.
