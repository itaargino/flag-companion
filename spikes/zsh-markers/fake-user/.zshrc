# A user whose theme rebuilds PS1 before every prompt and whose own precmd
# hook overwrites $?, both registered after the app's hooks.
_theme_precmd() { PS1="theme %~ %# "; true }
autoload -Uz add-zsh-hook
add-zsh-hook precmd _theme_precmd
