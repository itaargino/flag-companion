# The app's ZDOTDIR holds only this file. It hands ZDOTDIR back to the user
# right away, so zsh reads their .zshenv, .zprofile, .zshrc and .zlogin from the
# usual place and HISTFILE keeps pointing at their history.
ZDOTDIR="${FC_USER_ZDOTDIR:-$HOME}"
[[ -f "$ZDOTDIR/.zshenv" ]] && source "$ZDOTDIR/.zshenv"
[[ -o interactive ]] && source "$FC_SPIKE_DIR/hooks-forward.zsh"
