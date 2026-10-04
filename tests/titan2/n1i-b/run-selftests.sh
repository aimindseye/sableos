#!/usr/bin/env bash
# N1I-B unified self-test runner. Offline only: no device, no /srv, no network.
#   run-selftests.sh [--quick] [--table FILE]
#     --quick   skip the ~75 s fake-adb end-to-end capture runs (result is then NOT review evidence)
#     --table   also write the full case table (TSV) to FILE
# A component marker is PASS only when the component ran, printed at least one case and no FAIL.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUICK=0 TABLE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --quick) QUICK=1; shift ;;
    --table) TABLE="${2:?}"; shift 2 ;;
    *) echo "usage: $0 [--quick] [--table FILE]" >&2; exit 2 ;;
  esac
done

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
ALL="$TMP/cases.tsv"; : > "$ALL"

# component  marker  command...
COMPONENTS=(
  "guard|READ_ONLY_GUARD_TESTS|bash $HERE/test-guard.sh"
  "capture_cli|READ_ONLY_GUARD_TESTS|bash $HERE/test-capture-cli.sh $([[ $QUICK -eq 1 ]] && echo --quick)"
  "sanitizer|SANITIZER_FIXTURE_TESTS|python3 $HERE/test-sanitizer.py"
  "timeline|TIMELINE_B0_APN_TESTS|python3 $HERE/test-timeline.py"
  "static|N1I_STATIC_DEXDUMP_ORACLE|python3 $HERE/test-static.py"
  "members|MEMBER_RESOLVER_TESTS|python3 $HERE/test-members.py"
  "native|NATIVE_DATAFLOW_TESTS|python3 $HERE/test-native.py"
)

declare -A MARK_STATE=()
for entry in "${COMPONENTS[@]}"; do
  IFS='|' read -r comp marker cmd <<< "$entry"
  out="$TMP/$comp.out"
  # shellcheck disable=SC2086
  $cmd > "$out" 2> "$TMP/$comp.err"; rc=$?
  grep -P '^CASE\t' "$out" >> "$ALL"
  n=$(grep -cP "^CASE\t$comp\t" "$out"); nf=$(grep -cP "^CASE\t$comp\t[^\t]*\tFAIL\t" "$out")
  state=PASS
  if [[ $rc -ne 0 || $n -eq 0 || $nf -ne 0 ]]; then state=FAIL; fi
  printf 'COMPONENT %-12s cases=%-4s failed=%-3s rc=%s -> %s\n' "$comp" "$n" "$nf" "$rc" "$state"
  [[ $rc -ne 0 && $nf -eq 0 ]] && sed 's/^/  stderr: /' "$TMP/$comp.err" | tail -5
  prev="${MARK_STATE[$marker]:-PASS}"
  [[ "$state" == FAIL ]] && prev=FAIL
  MARK_STATE[$marker]="$prev"
done

echo
echo "| component | case | result | detail |"
echo "|---|---|---|---|"
awk -F'\t' '{ d=$5; gsub(/\|/, "\\|", d); c=$3; gsub(/\|/, "\\|", c); printf "| %s | `%s` | %s | %s |\n", $2, c, $4, d }' "$ALL"
[[ -n "$TABLE" ]] && cp "$ALL" "$TABLE"

total=$(wc -l < "$ALL" | tr -d ' '); failed=$(grep -cP '\tFAIL\t' "$ALL")
echo
for m in "${!MARK_STATE[@]}"; do echo "$m=${MARK_STATE[$m]}"; done | sort
[[ $QUICK -eq 1 ]] && echo "SELFTEST_MODE=QUICK_NOT_REVIEW_EVIDENCE"
echo "SELFTEST_CASES=$total"
echo "SELFTEST_FAILED=$failed"
overall=PASS
for m in "${!MARK_STATE[@]}"; do [[ "${MARK_STATE[$m]}" == PASS ]] || overall=FAIL; done
[[ $failed -eq 0 && $total -gt 0 ]] || overall=FAIL
echo "SELFTEST=$overall"
[[ "$overall" == PASS ]]
