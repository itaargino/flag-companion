# Hook sketch from the spec ("Terminal capture", step 3), unchanged, so the
# spike tests exactly what the spec proposes.
_fc_precmd() {
  local ec=$?
  printf '\e]133;D;%s\a' "$ec"
  printf '\e]7;file://%s%s\a' "$HOST" "$PWD"
  printf '\e]133;A\a'
}
_fc_preexec() {
  printf '\e]7770;cmd;%s\a' "$(printf '%s' "$1" | base64)"
  printf '\e]133;C\a'
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd _fc_precmd
add-zsh-hook preexec _fc_preexec
PS1="$PS1%{$(printf '\e]133;B\a')%}"
