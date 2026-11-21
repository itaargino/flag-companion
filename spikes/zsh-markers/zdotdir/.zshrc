# The app's .zshrc as the spec describes it: load the user's ~/.zshrc first,
# then register the hooks. zsh reads this file because ZDOTDIR points here.
[[ -f "$HOME/.zshrc" ]] && source "$HOME/.zshrc"
source "$FC_SPIKE_DIR/hooks.zsh"
