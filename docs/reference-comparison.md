# Comparison With catpaladin/dotfiles

Compared reference revision `7bae6ea174b0ac7da64c3dd037d247eb34526a59`
and Neovim config revision `bbee1118183afaf1507db043c78de555ad7edc09`.
This records repository capabilities, not whether optional tools are installed
on every machine.

## Adopted

- GNU Stow package layout, `setup.sh`, ordered `.zsh.d` modules, shared script
  helpers, and focused development-environment installers.
- Neovim system dependencies and a pinned config submodule, linked separately
  from Stow. It uses `Persaud-PID/nvim-config` at `nvim/.config/nvim` rather than
  the reference's upstream remote; override with `--nvim-config`/`NVIM_CONFIG_DIR`.
- `EDITOR`/`VISUAL`, edit-command-line widget, expanded history, fd-backed fzf,
  `ll`/`la`/`tree`, JSON viewing via jless, and a Go coverage helper.
- Added missing dependency inventory for Stow, Neovim, tree-sitter CLI, fd,
  jless, LazyGit, and terraform-docs. Linking alone does not install these.

## Completed Reference Parity

| Reference feature | Decision / current equivalent |
| --- | --- |
| tmux and Tokyo Night status bar | Copied; Ctrl-F prefix, TPM, sensible and resurrect. cmux does not auto-start tmux. |
| Alacritty macOS/Linux | Original YAML retained; active config ported to supported TOML with all six palettes and the same settings/keybindings. macOS builds from Cargo because the Homebrew cask is disabled. |
| Bash fallback | Reference `.bashrc` is a Stow package. |
| Linux apt/fonts | Added core/language/terminal installers for modern Debian/Ubuntu plus Hack/Noto Nerd Fonts. Linux execution is not validated on this Mac. |
| Rust/rustup/Cargo | Added `scripts/rust-dev.sh`, using official rustup without modifying tracked shell profiles. |
| goenv and Go collection | goenv plus golines, gofumpt, goimports-reviser, gotests, godoc, Cobra, Air, Swag and golangci-lint. Use current golangci-lint v2 rather than obsolete reference v1.60.1. |
| tfenv-managed Terraform | Replaces tenv for Terraform. Existing OpenTofu/Terragrunt functionality moves to standalone packages. |
| Bun/Yarn/global TS tools | Added Node LTS via NVM, Bun, Yarn, TypeScript, ts-node, ESLint/parser/plugin, Prettier, TypeDoc and tsx. Existing global agent CLIs migrate when Node versions change. |
| uv Python and tools | uv-managed default Python plus ruff, black, isort, mypy, pytest and IPython. |
| Rye | Included for parity; unmaintained. Its shims stay behind uv so it does not replace the managed Python default. |
| pi footer theme | Same root theme asset copied. As in the reference, this does not install the footer extension or provide credentials. |
| Suffix aliases / grep / diff | Copied; GNU `gdiff` is used on macOS for colour compatibility. |
| Ctrl-X Ctrl-E | Matches the edit-and-execute binding. Nonempty commands execute on return from the editor. |

## Dotfiles Extras Retained In The Same Format

| Existing extra | New location |
| --- | --- |
| cmux settings, terminal theme/font, Starship | `cmux/`, `ghostty/`, `starship/` Stow packages |
| User-owned Neovim config | `Persaud-PID/nvim-config` submodule linked to `~/.config/nvim`; explicit external overrides supported; no automatic submodule updates or plugin provisioning |
| AWS profile and cloud helper functions | `zsh/.zsh.d/50-aws.zsh` |
| Kubernetes/Helm functions | `zsh/.zsh.d/60-kubernetes.zsh` |
| Git branch/PR workflows | `zsh/.zsh.d/70-git.zsh` |
| Chewy/Zscaler, GitLab token and SSH rotation | `company/.zsh/companies/`, mirroring the reference's shell-focused home layout; tests preserved |
| Custom completions and direnv/zoxide/plugins | numbered Zsh modules; generated completions stay private under `~/.zsh/completions` |
| Node/npm/npx, Go, uv/pipx, Terraform | focused scripts and `brew/Brewfile.*` manifests; goenv/tfenv replace Homebrew Go/tenv |
| AWS/Kubernetes/Helm/Krew/SSO | `scripts/kubernetes-dev.sh`, `python-dev.sh`, cloud Brewfile |
| Docker/Colima, Clocker/Obsidian, JFrog/Zellij/Teleport | scoped manifests/installers |
| Git delta/default branch defaults | `git/.config/git/laptop-setup.gitconfig`, included without tracking identity |
| OpenSpec work | `openspec/` left in place; historical paths in its prior artifacts refer to the pre-migration layout |
| Prior bootstrap | `legacy/`, preserved but not run; obsolete iTerm2 preferences and shell integration removed |

## Safety Differences

Unlike the reference setup, this installer never uses Stow `--adopt` or clones
shell plugins during shell startup. It preflights directory conflicts, backs up
files/symlinks and preserves private shell state. It never initializes or updates
Neovim submodules automatically, runs their plugin manager, or changes their
lockfile. Missing/uninitialized configs are skipped without replacing an existing
config. Unknown company names fail before linking. Runtime files and secrets do not belong in
Stow packages.

Practical impact: the earlier omissions did not prevent cmux or Neovim from
working. The new additions change default runtime/tool resolution and interactive
bindings; they do not migrate Terraform state or change cluster/cloud resources.
Project version files and lockfiles should pin versions. cmux and Starship use
TokyoNight Night; tmux/Alacritty/Neovim use their upstream Tokyo Night variants.
