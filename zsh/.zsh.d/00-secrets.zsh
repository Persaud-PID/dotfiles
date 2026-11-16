# These private files are deliberately not part of a Stow package.
if [[ -f "$HOME/.zsh/secrets.env" ]]; then
  set -a
  source "$HOME/.zsh/secrets.env"
  set +a
fi
[[ -f "$HOME/.zsh/aws-profile.zsh" ]] && source "$HOME/.zsh/aws-profile.zsh"
