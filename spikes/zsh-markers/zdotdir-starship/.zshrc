# Starship without the user's PROMPT override, to see if the B marker survives.
eval "$(starship init zsh)"
source "$FC_SPIKE_DIR/hooks.zsh"
