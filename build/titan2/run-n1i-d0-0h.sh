#!/usr/bin/env bash
# Canonical host-only Titan 2 N1I-D0-0H runner.
set -u
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/build/config/storage.env" || exit 64
source "$ROOT/build/config/host-tools.env" || exit 64

PREP="$ROOT/build/titan2/prepare-n1i-d0-0h-inputs.sh"
QUAL="$ROOT/build/titan2/qualify-n1i-d0-0h.py"

ANDROID_ROOT="$SABLE_WORKSPACES_ROOT/titan2-n1d/android"
INPUTS_DIR=""
OUT=""
C1_ROOT=""
REUSE_INPUTS=NO

fail() {
  echo "N1I_D0_0H_RUNNER=FAIL reason=$1" >&2
  exit "${2:-1}"
}

usage() {
  cat <<'EOF'
Usage:
  bash build/titan2/run-n1i-d0-0h.sh [options]

Options:
  --android-root DIR   Android 16 source tree used to derive init semantics.
  --inputs-dir DIR     Reuse an already sealed prepare-n1i-d0-0h-inputs output.
  --out DIR            Evidence root. Default: timestamped Sable evidence dir.
  --c1-root DIR        Optional retained/materialized exact C1 runtime root.
  --reuse-inputs       Reuse matching materialized filesystem roots in a newly
                       prepared input directory when supported.
  -h, --help

Host-only. No build, network fetch, adb, fastboot, reboot, flash or mount.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --android-root)
      [[ "$#" -ge 2 ]] || fail missing_android_root 64
      ANDROID_ROOT="$2"; shift 2 ;;
    --inputs-dir)
      [[ "$#" -ge 2 ]] || fail missing_inputs_dir 64
      INPUTS_DIR="$2"; shift 2 ;;
    --out)
      [[ "$#" -ge 2 ]] || fail missing_out 64
      OUT="$2"; shift 2 ;;
    --c1-root)
      [[ "$#" -ge 2 ]] || fail missing_c1_root 64
      C1_ROOT="$2"; shift 2 ;;
    --reuse-inputs)
      REUSE_INPUTS=YES; shift ;;
    -h|--help)
      usage
      exit 0 ;;
    *)
      usage >&2
      fail "unknown_argument=$1" 64 ;;
  esac
done

[[ -f "$PREP" ]] || fail prep_missing 64
[[ -f "$QUAL" ]] || fail qualifier_missing 64
[[ -x "$SABLE_PYTHON" ]] || fail "python_missing=$SABLE_PYTHON" 64
[[ -d "$ANDROID_ROOT" ]] || fail "android_root_missing=$ANDROID_ROOT" 64
[[ -f "$ANDROID_ROOT/system/core/init/selinux.cpp" ]] ||
  fail android_init_selinux_source_missing 64
[[ -f "$ANDROID_ROOT/system/core/init/Android.bp" ]] ||
  fail android_init_build_file_missing 64

repo_status="$(git -C "$ROOT" status --porcelain=v1 --untracked-files=all)" ||
  fail repo_status 64
[[ -z "$repo_status" ]] || fail source_worktree_not_clean 64
TOOL_SOURCE_COMMIT="$(git -C "$ROOT" rev-parse HEAD)" ||
  fail repo_head 64

if [[ -z "$OUT" ]]; then
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  OUT="$SABLE_EVIDENCE_ROOT/titan2/n1i-d0-0h/$stamp"
fi
[[ ! -e "$OUT" ]] || fail "output_exists=$OUT" 64
mkdir -p "$OUT" || fail output_create 64
OUT="$(cd "$OUT" && pwd -P)" || fail output_resolve 64

echo "===== TITAN 2 N1I-D0-0H HOST CLOSURE ====="
echo "TOOL_SOURCE_COMMIT=$TOOL_SOURCE_COMMIT"
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "MODE_TRANSITION_AUTHORIZED=NO"
echo "REBOOT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "ANDROID_ROOT=$ANDROID_ROOT"
echo "EVIDENCE_ROOT=$OUT"

if [[ -z "$INPUTS_DIR" ]]; then
  INPUTS_DIR="$OUT/inputs"
  prep_args=(--out "$INPUTS_DIR")
  if [[ "$REUSE_INPUTS" == YES ]]; then
    prep_args+=(--reuse)
  fi
  bash "$PREP" "${prep_args[@]}"
  prep_rc=$?
  [[ "$prep_rc" -eq 0 ]] ||
    fail "input_prep_rc=$prep_rc" 65
else
  [[ -d "$INPUTS_DIR" ]] || fail "inputs_dir_missing=$INPUTS_DIR" 64
  INPUTS_DIR="$(cd "$INPUTS_DIR" && pwd -P)" ||
    fail inputs_dir_resolve 64
fi

qual_args=(
  --inputs-dir "$INPUTS_DIR"
  --android-root "$ANDROID_ROOT"
  --out "$OUT/analysis"
)
if [[ -n "$C1_ROOT" ]]; then
  [[ -d "$C1_ROOT" ]] || fail "c1_root_missing=$C1_ROOT" 64
  qual_args+=(--c1-root "$C1_ROOT")
fi

"$SABLE_PYTHON" "$QUAL" "${qual_args[@]}"
qual_rc=$?

echo "N1I_D0_0H_QUALIFIER_RC=$qual_rc"
echo "N1I_D0_INPUTS_DIR=$INPUTS_DIR"
echo "N1I_D0_ANALYSIS_DIR=$OUT/analysis"

repo_status_after="$(git -C "$ROOT" status --porcelain=v1 --untracked-files=all)" ||
  fail repo_status_after 66
[[ -z "$repo_status_after" ]] || fail source_mutated_by_d0 66

case "$qual_rc" in
  0)
    echo "N1I_D0_0H_RUNNER=PASS_CLOSED"
    exit 0 ;;
  3)
    echo "N1I_D0_0H_RUNNER=NOT_CLOSED"
    exit 3 ;;
  *)
    fail "qualifier_rc=$qual_rc" "$qual_rc" ;;
esac
