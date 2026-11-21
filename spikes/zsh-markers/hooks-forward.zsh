# Variant of the spec's hooks that survives themes rebuilding PS1 and other
# hooks registered after ours (the user's .zshrc loads after this file).
_fc_status() {
  local ec=$?
  printf '\e]133;D;%s\a' "$ec"
  # Keep _fc_status first, to read $? before anything else, and _fc_prompt
  # last, to run after any theme has rebuilt PS1.
  precmd_functions=(_fc_status ${precmd_functions:#_fc_(status|prompt)} _fc_prompt)
}
_fc_prompt() {
  printf '\e]7;file://%s%s\a' "$HOST" "$PWD"
  printf '\e]133;A\a'
  [[ $PS1 == *$'\e]133;B'* ]] || PS1="$PS1%{"$'\e]133;B\a'"%}"
}
_fc_preexec() {
  printf '\e]7770;cmd;%s\a' "$(printf '%s' "$1" | base64)"
  printf '\e]133;C\a'
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd _fc_status
add-zsh-hook precmd _fc_prompt
add-zsh-hook preexec _fc_preexec
