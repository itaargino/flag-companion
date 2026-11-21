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
# Byte -> %XX table, built once, so encoding a long command takes
# milliseconds instead of one printf per character.
typeset -gA _fc_hex
() {
  emulate -L zsh
  setopt no_multibyte
  local -i b
  local hex
  for (( b = 1; b < 256; b++ )); do
    printf -v hex '%%%02X' $b
    _fc_hex[${(#)b}]=$hex
  done
}
# URL-escapes $1 into REPLY, byte by byte, so the command can never
# contain ESC, BEL or ";" and end the OSC early.
_fc_urlencode() {
  emulate -L zsh
  setopt no_multibyte extended_glob
  REPLY=${1//(#m)[^A-Za-z0-9._~\/-]/$_fc_hex[$MATCH]}
}
_fc_preexec() {
  local REPLY
  _fc_urlencode "$1"
  printf '\e]133;C;cmdline_url=%s\a' "$REPLY"
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd _fc_status
add-zsh-hook precmd _fc_prompt
add-zsh-hook preexec _fc_preexec
