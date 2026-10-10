#!/usr/bin/env bash
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

fail() { printf 'P3R1_HOLD=%s\n' "$1" >&2; exit 1; }
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd -P)"
MODULES="$ROOT/build/titan2"
TESTS="$ROOT/tests/titan2/n1i-historical"
SELFTEST="$ROOT/tests/titan2/n1i-b/run-selftests.sh"
ENVFILE="$ROOT/build/config/host-tools.env"
MODE="${1:-}"
case "$MODE" in
  --synthetic-only) [[ $# == 1 ]] || fail INVALID_ARGS ;;
  --historical-offline|--full-host)
    [[ $# == 3 && "$2" == --evidence-manifest && -n "$3" ]] || fail EVIDENCE_MANIFEST_REQUIRED
    EVIDENCE_MANIFEST="$3" ;;
  *) fail REQUIRED_EXPLICIT_MODE ;;
esac

printf '%s\n' '===== N1I-H1C3 REPOSITORY QUALIFICATION P3R1 =====' \
 'NETWORK_FETCH_AUTHORIZED=NO' 'SOURCE_MUTATION_AUTHORIZED=NO' \
 'COMMIT_AUTHORIZED=NO' 'PUSH_AUTHORIZED=NO' 'MERGE_AUTHORIZED=NO' \
 'DEVICE_CONTACT_AUTHORIZED=NO' 'ADB_AUTHORIZED=NO' \
 'FASTBOOT_AUTHORIZED=NO' 'FLASH_AUTHORIZED=NO'

[[ -f "$MODULES/n1i_h1c3.py" && -d "$TESTS" ]] || fail MISSING_RELOCATED_H1
if [[ "$MODE" == "--full-host" ]]; then
  [[ -f "$SELFTEST" && -f "$ENVFILE" ]] || fail MISSING_N1I_SELFTEST_OR_ENV
fi
[[ -z "$(git -C "$ROOT" diff --name-only HEAD --)" ]] || fail TRACKED_WORKTREE_DIRTY
[[ -z "$(git -C "$ROOT" diff --cached --name-only --)" ]] || fail INDEX_DIRTY

# Existing untracked H1-C3 integration files are expected; preserve exact status.
BEFORE_STATUS="$(git -C "$ROOT" status --porcelain=v1 --untracked-files=all)"
BEFORE_HEAD="$(git -C "$ROOT" rev-parse HEAD)"
BEFORE_REF="$(git -C "$ROOT" symbolic-ref -q HEAD || true)"
check_preservation() {
  rc=$?
  trap - EXIT
  if [[ "$(git -C "$ROOT" rev-parse HEAD)" != "$BEFORE_HEAD" || \
        "$(git -C "$ROOT" symbolic-ref -q HEAD || true)" != "$BEFORE_REF" || \
        "$(git -C "$ROOT" status --porcelain=v1 --untracked-files=all)" != "$BEFORE_STATUS" ]]; then
    echo 'P3R1_REPO_PRESERVATION=FAIL' >&2
    exit 1
  fi
  echo 'P3R1_REPO_PRESERVATION=PASS'
  echo "P3R1_PROCESS_EXIT=$rc"
  exit "$rc"
}
trap check_preservation EXIT

export PYTHONPATH="$MODULES:$TESTS"
if [[ "$MODE" != "--synthetic-only" ]]; then
  echo '===== P7R1 HISTORICAL MANIFEST PREFLIGHT ====='
  python3 -B - "$EVIDENCE_MANIFEST" <<'PY_PREFLIGHT'
import sys
import n1i_h1_evidence_manifest as manifest
import n1i_h1c2 as c2
manifest.load(sys.argv[1], c2.SNAPSHOTS)
print('P7R1_MANIFEST_PREFLIGHT=PASS')
PY_PREFLIGHT
fi
echo '===== H1 RELOCATED REGRESSIONS ====='
python3 -B -m unittest -v \
  test_n1i_h1b2 test_n1i_h1b6 test_n1i_h1c1 \
  test_n1i_h1c2 test_n1i_h1c2b test_n1i_h1c3 test_n1i_h1_p5r1 test_n1i_h1_p7r1

if [[ "$MODE" != "--synthetic-only" ]]; then
  echo '===== VERIFIED HISTORICAL SUMMARY ====='
  python3 -B "$MODULES/n1i_h1c3.py" --summary-only --evidence-manifest "$EVIDENCE_MANIFEST"
fi
if [[ "$MODE" == "--full-host" ]]; then
  echo '===== N1I V1.2 REGRESSIONS ====='
  cd "$ROOT"
  source "$ENVFILE"
  bash "$SELFTEST"
fi
echo 'N1I_H1C3_P7R1_QUALIFICATION=PASS'
echo 'DEVICE_CONTACT=NOT_EXECUTED'
echo 'FLASH=NOT_EXECUTED'
echo 'COMMIT=NOT_EXECUTED'
echo 'PUSH=NOT_EXECUTED'
