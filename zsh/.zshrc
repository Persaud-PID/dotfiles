# Source ordered modules; keep secrets and machine-specific overrides outside Git.
for config_file in "$HOME"/.zsh.d/*.zsh(N); do
  source "$config_file"
done
unset config_file
