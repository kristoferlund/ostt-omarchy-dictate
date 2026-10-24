# shellcheck shell=bash
# Sourced by the bin scripts.

# The error in ostt's stderr ($1): from its "Error: " line on, without the
# prefix and the "Caused by:" layout (causes indented by four spaces, and
# numbered when there are several); for invalid arguments, the "error: " line;
# its last line if there is neither; or $2.
ostt_error() {
  local error
  error=$(sed -n '/^Error: /,$p' <<<"$1" |
    sed -e '1s/^Error: //' -e '/^Caused by:$/d' -e 's/^    \([0-9][0-9]*: \)\{0,1\}//' -e '/^$/d')
  [[ $error ]] || error=$(sed -n 's/^error: //p' <<<"$1" | head -n1)
  [[ $error ]] || error=$(grep -v '^[[:space:]]*$' <<<"$1" | tail -n1)
  error=${error:-${2:-}}
  (( ${#error} > 400 )) && error="${error:0:400}…"
  printf '%s' "$error"
}

# Runs a command and prints its output, or, if it fails, its error output
# instead, with its exit status. Keeping the two apart keeps a warning on
# stderr out of JSON on stdout.
stdout_or_stderr() {
  local errors output status
  errors=$(mktemp) || return 1
  output=$("$@" 2>"$errors")
  status=$?
  if (( status == 0 )); then printf '%s\n' "$output"; else cat "$errors"; fi
  rm -f "$errors"
  return "$status"
}
