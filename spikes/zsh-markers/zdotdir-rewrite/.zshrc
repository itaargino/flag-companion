# Stand-in for themes like Powerlevel10k that rebuild PS1 before every prompt.
_theme_precmd() { PS1="theme %~ %# " }
autoload -Uz add-zsh-hook
add-zsh-hook precmd _theme_precmd
source "$FC_SPIKE_DIR/hooks.zsh"
