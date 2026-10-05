#!/usr/bin/env bash
# Host-only retirement for the known N1I-C1 prewrite nounset abort.
# This script never invokes adb or fastboot and never deletes original evidence.
set -euo pipefail
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/build/config/storage.env"
source "$ROOT/build/titan2/n1i-c1-flash-common.sh"

BUGGY_TOOL_SOURCE_COMMIT="4024d750e5e2eb019ff62532d2a1fe685902c0aa"
IMAGE_SOURCE_COMMIT="a745c7daa08267d851f45785a5bb7ff762ed4604"
ARTIFACT_ROLE="N1I_C1_ANDROID16_CELLULAR_ISOLATION"
SYSTEM_SHA256="137bc8771c817c0afb3122d9f03e7a94575e03bcccc643b56235edd1075f2160"
SYSTEM_BYTES="3210661888"
TARGET_PARTITION="system_a"
STOCK_SYSTEM_A_BYTES="757059584"
AUTH=""
SERIAL=""
EVIDENCE_DIR=""

fail() {
  echo "N1I_C1_PREWRITE_ABORT_RETIREMENT=FAIL reason=$1" >&2
  exit "${2:-1}"
}

usage() {
  cat <<'EOF'
Usage:
  bash build/titan2/retire-n1i-c1-prewrite-abort.sh \
    --authorize-retirement YES_KNOWN_PREWRITE_NOUNSET_ABORT \
    --serial SERIAL \
    --evidence-dir FLASH_EVIDENCE_DIR
EOF
}

while (($#)); do
  case "$1" in
    --authorize-retirement)
      [[ "$#" -ge 2 ]] || fail missing_authorization 64
      AUTH="$2"; shift 2
      ;;
    --serial)
      [[ "$#" -ge 2 ]] || fail missing_serial 64
      SERIAL="$2"; shift 2
      ;;
    --evidence-dir)
      [[ "$#" -ge 2 ]] || fail missing_evidence_dir 64
      EVIDENCE_DIR="$2"; shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      fail "unknown_argument=$1" 64
      ;;
  esac
done

[[ "$AUTH" == YES_KNOWN_PREWRITE_NOUNSET_ABORT ]] ||
  fail exact_retirement_authorization_required 64
[[ "$SERIAL" =~ ^[A-Za-z0-9._:-]{1,128}$ ]] || fail invalid_serial 64
[[ -d "$EVIDENCE_DIR" ]] || fail evidence_dir_missing 64

SERIAL_SHA256="$(printf '%s' "$SERIAL" | sha256sum | awk '{print $1}')"
EVIDENCE_DIR="$(cd "$EVIDENCE_DIR" && pwd -P)"
EVIDENCE_ROOT="$(cd "$SABLE_EVIDENCE_ROOT" && pwd -P)/titan2/n1i-c1-governed-flash"
case "$EVIDENCE_DIR/" in
  "$EVIDENCE_ROOT"/*/) ;;
  *) fail evidence_dir_outside_c1_root 64 ;;
esac

ATTEMPT_DIR="$EVIDENCE_DIR/attempt-journal"
ATTEMPT_ENV="$ATTEMPT_DIR/N1I_C1_FLASH_ATTEMPT_ARMED.env"
ATTEMPT_SUMS="$ATTEMPT_DIR/SHA256SUMS.txt"
WRITE_PROOF="$EVIDENCE_DIR/write-proof"
COMMAND_DIR="$EVIDENCE_DIR/command-journal"
RETIRE_DIR="$EVIDENCE_DIR/attempt-retirement"
PRE_STATE="$WRITE_PROOF/pre-state.env"
POLICY="$EVIDENCE_DIR/policy.env"

for required in "$ATTEMPT_ENV" "$ATTEMPT_SUMS" "$PRE_STATE" "$POLICY"; do
  [[ -f "$required" ]] || fail "required_evidence_missing=$required" 65
done

n1i_c1_manifest_safe "$ATTEMPT_SUMS" || fail attempt_manifest_unsafe 65
(
  cd "$ATTEMPT_DIR"
  sha256sum -c SHA256SUMS.txt >/dev/null
) || fail attempt_seal_invalid 65

expect_env() {
  local file="$1" key="$2" expected="$3" actual
  actual="$(n1i_c1_env_value "$file" "$key")" ||
    fail "env_key_invalid file=$file key=$key" 65
  [[ "$actual" == "$expected" ]] ||
    fail "env_value_mismatch key=$key expected=$expected actual=$actual" 65
}

expect_env "$ATTEMPT_ENV" N1I_C1_FLASH_ATTEMPT_JOURNAL_VERSION 1
expect_env "$ATTEMPT_ENV" DEVICE_SERIAL_SHA256 "$SERIAL_SHA256"
expect_env "$ATTEMPT_ENV" ARTIFACT_ROLE "$ARTIFACT_ROLE"
expect_env "$ATTEMPT_ENV" IMAGE_SOURCE_COMMIT "$IMAGE_SOURCE_COMMIT"
expect_env "$ATTEMPT_ENV" SYSTEM_SHA256 "$SYSTEM_SHA256"
expect_env "$ATTEMPT_ENV" SYSTEM_BYTES "$SYSTEM_BYTES"
expect_env "$ATTEMPT_ENV" TARGET_PARTITION "$TARGET_PARTITION"
expect_env "$ATTEMPT_ENV" PREFLASH_BASELINE STOCK_V010014
expect_env "$ATTEMPT_ENV" PREFLASH_SYSTEM_A_BYTES "$STOCK_SYSTEM_A_BYTES"
expect_env "$ATTEMPT_ENV" FLASH_ATTEMPT_NUMBER 1
expect_env "$ATTEMPT_ENV" ATTEMPT_STATE ARMED
expect_env "$ATTEMPT_ENV" TOOL_SOURCE_COMMIT "$BUGGY_TOOL_SOURCE_COMMIT"
expect_env "$ATTEMPT_ENV" AUTOMATIC_FLASH_RETRY NO

expect_env "$PRE_STATE" N1I_C1_FASTBOOT_PHASE PRE
expect_env "$PRE_STATE" N1I_C1_FASTBOOT_BASELINE STOCK_V010014
expect_env "$PRE_STATE" N1I_C1_FASTBOOT_SYSTEM_A_BYTES "$STOCK_SYSTEM_A_BYTES"
expect_env "$PRE_STATE" N1I_C1_FASTBOOT_ACTIVE_COW_COUNT 0
expect_env "$PRE_STATE" N1I_C1_FASTBOOT_STATE PASS

expect_env "$POLICY" N1I_C1_FLASH_TARGET system_a
expect_env "$POLICY" N1I_C1_FLASH_ATTEMPT_LIMIT 1
expect_env "$POLICY" N1I_C1_AUTOMATIC_FLASH_RETRY NO

# The redirection for the flash command creates this file before fastboot is
# launched. Absence therefore proves the command line was never crossed.
[[ ! -e "$WRITE_PROOF/fastboot-flash-system-a.log" ]] ||
  fail flash_log_exists_write_boundary_may_have_been_crossed 66
[[ ! -e "$WRITE_PROOF/fastboot-getvar-all-post.txt" ]] ||
  fail postwrite_getvar_exists 66
[[ ! -e "$WRITE_PROOF/post-state.env" ]] ||
  fail postwrite_state_exists 66
[[ ! -e "$WRITE_PROOF/N1I_C1_WRITE_COMPLETED.env" ]] ||
  fail write_completed_evidence_exists 66
[[ ! -e "$WRITE_PROOF/SHA256SUMS.txt" ]] ||
  fail write_proof_seal_exists 66

if [[ -d "$COMMAND_DIR" ]] &&
   find "$COMMAND_DIR" -mindepth 1 -maxdepth 1 -type f -print -quit |
     grep -q .; then
  fail command_journal_not_empty 66
fi

[[ ! -e "$RETIRE_DIR" ]] || fail retirement_already_exists 66
mkdir -p "$RETIRE_DIR"
chmod 700 "$RETIRE_DIR" 2>/dev/null || true

ATTEMPT_SEAL_SHA256="$(sha256sum "$ATTEMPT_SUMS" | awk '{print $1}')"
PRE_STATE_SHA256="$(sha256sum "$PRE_STATE" | awk '{print $1}')"
RETIRE_TOOL_SOURCE_COMMIT="$(git -C "$ROOT" rev-parse HEAD)"
[[ "$RETIRE_TOOL_SOURCE_COMMIT" =~ ^[0-9a-f]{40}$ ]] ||
  fail retirement_tool_commit_unknown 66

cat > "$RETIRE_DIR/N1I_C1_PREWRITE_ABORT_RETIREMENT.env" <<EOF_RETIRE
N1I_C1_PREWRITE_ABORT_RETIREMENT_VERSION=1
DEVICE_SERIAL_SHA256=$SERIAL_SHA256
ARTIFACT_ROLE=$ARTIFACT_ROLE
IMAGE_SOURCE_COMMIT=$IMAGE_SOURCE_COMMIT
SYSTEM_SHA256=$SYSTEM_SHA256
SYSTEM_BYTES=$SYSTEM_BYTES
TARGET_PARTITION=$TARGET_PARTITION
ORIGINAL_ATTEMPT_TOOL_SOURCE_COMMIT=$BUGGY_TOOL_SOURCE_COMMIT
ORIGINAL_ATTEMPT_SEAL_SHA256=$ATTEMPT_SEAL_SHA256
PREFLIGHT_STATE_SHA256=$PRE_STATE_SHA256
PREFLIGHT_BASELINE=STOCK_V010014
PREFLIGHT_SYSTEM_A_BYTES=$STOCK_SYSTEM_A_BYTES
ABORT_REASON=KNOWN_NOUNSET_JOURNAL_VERIFIER_BEFORE_FLASH_SITE
FLASH_COMMAND_LINE_REACHED=NO
FLASH_LOG_PRESENT=NO
COMMAND_SUCCESS_JOURNAL_PRESENT=NO
WRITE_COMPLETED_PROOF_PRESENT=NO
ORIGINAL_ATTEMPT_RETIRED=YES
RETIREMENT_TOOL_SOURCE_COMMIT=$RETIRE_TOOL_SOURCE_COMMIT
DEVICE_CONTACT=NONE
FASTBOOT_COMMANDS_RUN=NONE
ADB_COMMANDS_RUN=NONE
EOF_RETIRE

(
  cd "$RETIRE_DIR"
  sha256sum N1I_C1_PREWRITE_ABORT_RETIREMENT.env > SHA256SUMS.txt
  sha256sum -c SHA256SUMS.txt >/dev/null
) || fail retirement_seal_failed 67

echo "N1I_C1_PREWRITE_ABORT_RETIREMENT=PASS"
echo "N1I_C1_ORIGINAL_ATTEMPT_RETIRED=YES"
echo "N1I_C1_PHYSICAL_WRITE_ATTEMPTS_PROVEN=0"
echo "N1I_C1_DEVICE_CONTACT=NONE"
echo "N1I_C1_FASTBOOT_COMMANDS_RUN=NONE"
echo "N1I_C1_ADB_COMMANDS_RUN=NONE"
echo "N1I_C1_RETIREMENT_DIR=$RETIRE_DIR"
