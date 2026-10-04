# Shared helpers for N1I-B shell self-tests. Source, do not execute.
# Every case prints one line:  CASE<TAB>component<TAB>case_id<TAB>PASS|FAIL<TAB>detail
# The runner aggregates these lines; a component is PASS only when it printed >=1 case and no FAIL.

N1IB_FAILS=0
case_result() {
  local comp="$1" id="$2" ok="$3" detail="${4:-}"
  detail="${detail//$'\t'/ }"; detail="${detail//$'\n'/ }"
  if [[ "$ok" == "1" ]]; then
    printf 'CASE\t%s\t%s\tPASS\t%s\n' "$comp" "$id" "$detail"
  else
    printf 'CASE\t%s\t%s\tFAIL\t%s\n' "$comp" "$id" "$detail"
    N1IB_FAILS=$((N1IB_FAILS + 1))
  fi
}

# Print the body of shell function NAME (from "NAME() {" to the first line that is exactly "}").
extract_fn() {
  awk -v n="$2" '
    $0 ~ "^"n"\\(\\) \\{" { on = 1 }
    on { print }
    on && $0 == "}" { exit }
  ' "$1"
}

# Print a top-level array assignment NAME=( ... ) that ends with a line that is exactly ")".
extract_array() {
  awk -v n="$2" '
    $0 ~ "^"n"=\\(" { on = 1 }
    on { print }
    on && $0 == ")" { exit }
  ' "$1"
}

repo_root() { git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel; }
