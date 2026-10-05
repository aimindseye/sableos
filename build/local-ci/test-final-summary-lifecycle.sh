#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN="$ROOT/build/local-ci/run.sh"
[[ -f "$RUN" ]] || { echo "SABLE_LOCAL_CI_FINAL_SUMMARY_LIFECYCLE_SELFTEST=FAIL missing_run_sh" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

awk '
  /^emit_final_summary\(\) \{$/ { capture=1 }
  capture { print }
  capture && /^}$/ { exit }
' "$RUN" > "$TMP/function.sh"

grep -Fqx 'emit_final_summary() {' "$TMP/function.sh" || {
  echo "SABLE_LOCAL_CI_FINAL_SUMMARY_LIFECYCLE_SELFTEST=FAIL function_extract" >&2
  exit 1
}
bash -n "$TMP/function.sh"

mkdir -p "$TMP/fake-root/build/local-ci" "$TMP/evidence" "$TMP/cache"
cat > "$TMP/fake-root/build/local-ci/summarize.py" <<'PY'
#!/usr/bin/env python3
import argparse
import os
import pathlib
import sys

p = argparse.ArgumentParser()
p.add_argument("--log")
p.add_argument("--out")
p.add_argument("--profile")
p.add_argument("--device")
p.add_argument("--release")
p.add_argument("--source-commit")
p.add_argument("--evidence-dir")
p.add_argument("--exit-code", type=int)
a = p.parse_args()
log = pathlib.Path(a.log).read_text(encoding="utf-8", errors="replace")
required = os.environ.get("REQUIRE_LOG_MARKER", "")
if required and required not in log:
    print("LIFECYCLE_FAKE_SUMMARY=FAIL_MISSING_DRAINED_MARKER", file=sys.stderr)
    raise SystemExit(9)
if os.environ.get("FORCE_SUMMARY_FAIL") == "YES":
    print("LIFECYCLE_FAKE_SUMMARY=FORCED_FAIL", file=sys.stderr)
    raise SystemExit(8)
out = (
    f"SUMMARY_EXIT_CODE={a.exit_code}\n"
    f"LOG_HAS_DIRTY={'SABLE_LOCAL_CI=FAIL_DIRTY_SOURCE' in log}\n"
)
pathlib.Path(a.out).write_text(out, encoding="utf-8")
print(out, end="")
PY
chmod +x "$TMP/fake-root/build/local-ci/summarize.py"

cat > "$TMP/harness-prefix.sh" <<'EOF_H'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$TEST_ROOT"
PROFILE=full
SABLEOS_DEVICE=titan2
SABLEOS_RELEASE_VERSION=N1I
SOURCE_COMMIT=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
EVIDENCE_ROOT="$TEST_EVIDENCE"
CACHE_ROOT="$TEST_CACHE"
mkdir -p "$CACHE_ROOT"
RUN_ID="$TEST_RUN_ID"
EVIDENCE_DIR="$EVIDENCE_ROOT/$RUN_ID"
mkdir -p "$EVIDENCE_DIR"
LOG_FIFO="$EVIDENCE_DIR/.local-ci.log.fifo"
rm -f "$LOG_FIFO"
mkfifo "$LOG_FIFO"
exec 3>&1 4>&2
tee "$EVIDENCE_DIR/local-ci.log" < "$LOG_FIFO" >&3 &
TEE_PID=$!
exec > "$LOG_FIFO" 2>&1
EOF_H
cat "$TMP/harness-prefix.sh" "$TMP/function.sh" > "$TMP/harness.sh"
cat >> "$TMP/harness.sh" <<'EOF_H'
trap 'emit_final_summary "$?"' EXIT
case "$TEST_CASE" in
  dirty)
    echo "SABLE_LOCAL_CI=FAIL_DIRTY_SOURCE"
    echo " M fixture"
    exit 2
    ;;
  synthetic)
    echo "FINAL_DRAIN_MARKER=present"
    exit 7
    ;;
  summaryfail)
    echo "CI_BODY=PASS"
    exit 0
    ;;
  *) exit 64 ;;
esac
EOF_H
chmod +x "$TMP/harness.sh"
bash -n "$TMP/harness.sh"

run_case() {
  local name="$1" expected="$2" marker="${3:-}" rc
  rm -rf "$TMP/evidence/$name"
  set +e
  TEST_ROOT="$TMP/fake-root" \
  TEST_EVIDENCE="$TMP/evidence" \
  TEST_CACHE="$TMP/cache" \
  TEST_RUN_ID="$name" \
  TEST_CASE="$name" \
  REQUIRE_LOG_MARKER="$marker" \
    "$TMP/harness.sh" > "$TMP/$name.out" 2> "$TMP/$name.err"
  rc=$?
  set -e
  [[ "$rc" -eq "$expected" ]] || {
    cat "$TMP/$name.out" >&2 || true
    cat "$TMP/$name.err" >&2 || true
    echo "SABLE_LOCAL_CI_FINAL_SUMMARY_LIFECYCLE_SELFTEST=FAIL case=$name rc=$rc expected=$expected" >&2
    exit 1
  }
}

run_case dirty 2 'SABLE_LOCAL_CI=FAIL_DIRTY_SOURCE'
run_case synthetic 7 'FINAL_DRAIN_MARKER=present'

rm -rf "$TMP/evidence/summaryfail"
set +e
TEST_ROOT="$TMP/fake-root" \
TEST_EVIDENCE="$TMP/evidence" \
TEST_CACHE="$TMP/cache" \
TEST_RUN_ID=summaryfail \
TEST_CASE=summaryfail \
FORCE_SUMMARY_FAIL=YES \
  "$TMP/harness.sh" > "$TMP/summaryfail.out" 2> "$TMP/summaryfail.err"
summary_rc=$?
set -e
[[ "$summary_rc" -eq 1 ]] || {
  echo "SABLE_LOCAL_CI_FINAL_SUMMARY_LIFECYCLE_SELFTEST=FAIL summary_failure_rc=$summary_rc" >&2
  exit 1
}

grep -Fqx 'SUMMARY_EXIT_CODE=2' "$TMP/evidence/dirty/LOCAL_CI_SUMMARY.txt"
grep -Fqx 'LOG_HAS_DIRTY=True' "$TMP/evidence/dirty/LOCAL_CI_SUMMARY.txt"
grep -Fqx 'SUMMARY_EXIT_CODE=7' "$TMP/evidence/synthetic/LOCAL_CI_SUMMARY.txt"
grep -Fq 'SABLE_LOCAL_CI_SUMMARY=FAIL_GENERATION' "$TMP/summaryfail.out"

echo "SABLE_LOCAL_CI_DIRTY_SOURCE_SUMMARY_RUNTIME=PASS"
echo "SABLE_LOCAL_CI_LOG_DRAIN_RUNTIME=PASS"
echo "SABLE_LOCAL_CI_NONZERO_PRESERVATION_RUNTIME=PASS"
echo "SABLE_LOCAL_CI_SUMMARY_FAILURE_PROPAGATION_RUNTIME=PASS"
echo "SABLE_LOCAL_CI_FINAL_SUMMARY_LIFECYCLE_SELFTEST=PASS"
