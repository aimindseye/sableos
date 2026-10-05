#!/usr/bin/env bash
# Host-only regression tests for the N1I-C1 governed Titan 2 flash executor.
# Mocks only. This script must never contact a real device.
set -u
set -o pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
FLASH="$ROOT/build/titan2/flash-n1i-c1-cellular-isolation.sh"
COMMON="$ROOT/build/titan2/n1i-c1-flash-common.sh"
QUAL="$ROOT/build/titan2/qualify-n1i-c1-fastboot-state.py"
RETIRE="$ROOT/build/titan2/retire-n1i-c1-prewrite-abort.sh"
RECOVERY="$ROOT/build/titan2/collect-n1i-c1-recovery-failure.sh"
CENTRAL_GUARD="$ROOT/build/gates/titan2-central-flash-guard-contract.sh"
MODE="${1:-}"

FAILS=0
pass() { echo "N1I_C1_FLASH_TEST_$1=PASS"; }
fail() {
  echo "N1I_C1_FLASH_TEST_$1=FAIL ${2:-}" >&2
  FAILS=$((FAILS + 1))
}

bash -n "$FLASH" "$COMMON" "$RETIRE" "$RECOVERY" "$CENTRAL_GUARD" "$0" || {
  fail SYNTAX shell
  exit 1
}
python3 - "$QUAL" <<'PY_SYNTAX' || {
import pathlib
import sys
path = pathlib.Path(sys.argv[1])
compile(path.read_text(encoding="utf-8"), str(path), "exec")
PY_SYNTAX
  fail SYNTAX python
  exit 1
}
pass SYNTAX

if grep -Fxq 'C1_RECOVERY="build/titan2/collect-n1i-c1-recovery-failure.sh"' "$CENTRAL_GUARD" &&
   grep -Fq 'require_file "N1I_C1_RECOVERY_FAILURE_COLLECTOR" "$C1_RECOVERY"' "$CENTRAL_GUARD"; then
  pass RECOVERY_GUARD_BINDING
else
  fail RECOVERY_GUARD_BINDING "collector path not bound in central guard"
fi

if python3 - "$FLASH" "$RETIRE" "$RECOVERY" <<'PY_LOCAL'
import pathlib
import re
import sys

bad = []
assign = re.compile(r'([A-Za-z_][A-Za-z0-9_]*)="([^"]*)"')

for raw_path in sys.argv[1:]:
    path = pathlib.Path(raw_path)
    for lineno, raw in enumerate(
        path.read_text(encoding="utf-8").splitlines(),
        1,
    ):
        line = raw.strip()
        if not line.startswith("local "):
            continue
        seen = []
        for match in assign.finditer(line):
            name = match.group(1)
            rhs = match.group(2)
            for earlier in seen:
                if f"${earlier}" in rhs or f"${{{earlier}}}" in rhs:
                    bad.append(f"{path}:{lineno}:{earlier}->{name}")
            seen.append(name)

if bad:
    print("\n".join(bad))
    raise SystemExit(1)
PY_LOCAL
then
  pass NOUNSET_LOCAL_DEPENDENCY
else
  fail NOUNSET_LOCAL_DEPENDENCY "dependent local initializer found"
fi

ROLE_READ_COUNT="$(grep -Fc 'role="$(n1i_c1_env_value "$env_file" ARTIFACT_ROLE)" || return 1' "$FLASH" || true)"
BYTES_READ_COUNT="$(grep -Fc 'bytes="$(n1i_c1_env_value "$env_file" SYSTEM_BYTES)" || return 1' "$FLASH" || true)"
ROLE_COMPARE_COUNT="$(grep -Fc '[[ "$role" == "$ARTIFACT_ROLE" ]] || return 1' "$FLASH" || true)"
BYTES_COMPARE_COUNT="$(grep -Fc '[[ "$bytes" == "$SYSTEM_BYTES" ]] || return 1' "$FLASH" || true)"
if [[ "$ROLE_READ_COUNT" == 2 &&
      "$BYTES_READ_COUNT" == 2 &&
      "$ROLE_COMPARE_COUNT" == 2 &&
      "$BYTES_COMPARE_COUNT" == 2 ]]; then
  pass EXACT_ARTIFACT_JOURNAL_BINDINGS
else
  fail EXACT_ARTIFACT_JOURNAL_BINDINGS     "role_reads=$ROLE_READ_COUNT bytes_reads=$BYTES_READ_COUNT role_cmp=$ROLE_COMPARE_COUNT bytes_cmp=$BYTES_COMPARE_COUNT"
fi

for token in \
  'verify_attempt_retirement' \
  'attempt-retirement' \
  'KNOWN_NOUNSET_JOURNAL_VERIFIER_BEFORE_FLASH_SITE'
do
  grep -Fq -- "$token" "$FLASH" ||
    fail PREWRITE_RETIREMENT_INTEGRATION "missing=$token"
done
[[ "$FAILS" -eq 0 ]] && pass PREWRITE_RETIREMENT_INTEGRATION

FLASH_LINE='"$FASTBOOT_BIN" -s "$SERIAL" flash system_a "$SYSTEM_IMG"'
FLASH_COUNT="$(grep -Fc "$FLASH_LINE" "$FLASH" || true)"
[[ "$FLASH_COUNT" == 1 ]] ||
  fail SINGLE_FLASH_SITE "count=$FLASH_COUNT"
[[ "$FLASH_COUNT" == 1 ]] && pass SINGLE_FLASH_SITE

for token in   ' erase '   ' format '   ' delete-logical-partition '   ' create-logical-partition '   ' resize-logical-partition '   ' set_active '   ' flash vbmeta'   ' flash boot '   ' flash vendor '   ' flash super '   ' wipe-super '   ' -w '
do
  if grep -Fq -- "$token" "$FLASH"; then
    fail FORBIDDEN_MUTATION "token=$token"
  fi
done
[[ "$FAILS" -eq 0 ]] && pass FORBIDDEN_MUTATION

for token in   'N1I_C1_AUTOMATIC_FLASH_RETRY=NO'   'FLASH_ATTEMPT_NUMBER=1'   'ATTEMPT_STATE=ARMED'   'N1I_C1_FLASH_ATTEMPT_JOURNAL=PASS'   'N1I_C1_FLASH_DUPLICATE_WRITE_GUARD=REFUSE_PRIOR_ATTEMPT'   'N1I_C1_FLASH_DUPLICATE_WRITE_GUARD=REFUSE_CORRUPT_ATTEMPT_EVIDENCE'   'FLASH_ATTEMPT_COUNT=1'   'N1I_C1_DO_NOT_REFLASH=YES'   'N1I_C1_FLASH_DUPLICATE_WRITE_GUARD=REFUSE_CORRUPT_EVIDENCE'   'finalize-receipt'   'TITAN2_FLASH_RECEIPT_VERSION=1'   'TITAN2_FLASH_RECEIPT.env'   'POST_FLASH_MODE=ANDROID_ADB'   'TARGET_PARTITION=$TARGET_PARTITION'
do
  grep -Fq -- "$token" "$FLASH" ||
    fail REQUIRED_CONTRACT "missing=$token"
done
[[ "$FAILS" -eq 0 ]] && pass REQUIRED_CONTRACT

DEF_LINE="$(grep -n '^find_prior_successful_flash()' "$FLASH" | cut -d: -f1 | head -n1)"
CALL_LINE="$(grep -n 'PRIOR_SUCCESS="$(find_prior_successful_flash' "$FLASH" | cut -d: -f1 | head -n1)"
if [[ "$DEF_LINE" =~ ^[0-9]+$ && "$CALL_LINE" =~ ^[0-9]+$ && "$DEF_LINE" -lt "$CALL_LINE" ]]; then
  pass DUPLICATE_GUARD_DEFINITION_ORDER
else
  fail DUPLICATE_GUARD_DEFINITION_ORDER "def=$DEF_LINE call=$CALL_LINE"
fi

EVIDENCE_LINE="$(grep -n 'echo "N1I_C1_FLASH_EVIDENCE_DIR=\$EVIDENCE_DIR"' "$FLASH" | cut -d: -f1 | head -n1)"
PREFLIGHT_LINE="$(grep -n '===== N1I-C1 FASTBOOTD PREWRITE STATE =====' "$FLASH" | cut -d: -f1 | head -n1)"
if [[ "$EVIDENCE_LINE" =~ ^[0-9]+$ && "$PREFLIGHT_LINE" =~ ^[0-9]+$ && "$EVIDENCE_LINE" -lt "$PREFLIGHT_LINE" ]]; then
  pass EVIDENCE_PATH_BEFORE_PREWRITE
else
  fail EVIDENCE_PATH_BEFORE_PREWRITE "evidence=$EVIDENCE_LINE preflight=$PREFLIGHT_LINE"
fi

ATTEMPT_LINE="$(grep -n 'N1I_C1_FLASH_ATTEMPT_JOURNAL=PASS' "$FLASH" | cut -d: -f1 | head -n1)"
WRITE_LINE="$(grep -nF "$FLASH_LINE" "$FLASH" | cut -d: -f1 | head -n1)"
if [[ "$ATTEMPT_LINE" =~ ^[0-9]+$ && "$WRITE_LINE" =~ ^[0-9]+$ && "$ATTEMPT_LINE" -lt "$WRITE_LINE" ]]; then
  pass ATTEMPT_JOURNAL_BEFORE_WRITE
else
  fail ATTEMPT_JOURNAL_BEFORE_WRITE "attempt=$ATTEMPT_LINE write=$WRITE_LINE"
fi

if grep -Eq 'set[[:space:]]+[+-]e|set[[:space:]]+-[^[:space:]]*e' "$FLASH"; then
  fail EXPLICIT_RC "errexit toggle/policy found"
else
  pass EXPLICIT_RC
fi

if [[ "$MODE" == --static-only ]]; then
  [[ "$FAILS" -eq 0 ]] || exit 1
  echo "N1I_C1_FLASH_STATIC_SELFTEST=PASS"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
STATE="$TMP/state"
LOG="$TMP/transport.log"
SERIAL="TITAN2-TEST-0001"
ADB_BIN="$TMP/adb"
FASTBOOT_BIN="$TMP/fastboot"
export MOCK_STATE_FILE="$STATE"
export MOCK_TRANSPORT_LOG="$LOG"
export MOCK_SERIAL="$SERIAL"
export MOCK_AMBIGUOUS=NO

make_abort_evidence() {
  local root="$1" tool_commit="$2"
  local run="$root/titan2/n1i-c1-governed-flash/run"
  local attempt="$run/attempt-journal"
  local write="$run/write-proof"
  local command="$run/command-journal"
  mkdir -p "$attempt" "$write" "$command"
  cat > "$attempt/N1I_C1_FLASH_ATTEMPT_ARMED.env" <<EOF_ATTEMPT
N1I_C1_FLASH_ATTEMPT_JOURNAL_VERSION=1
DEVICE_SERIAL_SHA256=$(printf '%s' "$SERIAL" | sha256sum | awk '{print $1}')
ARTIFACT_ROLE=N1I_C1_ANDROID16_CELLULAR_ISOLATION
IMAGE_SOURCE_COMMIT=a745c7daa08267d851f45785a5bb7ff762ed4604
SYSTEM_SHA256=137bc8771c817c0afb3122d9f03e7a94575e03bcccc643b56235edd1075f2160
SYSTEM_BYTES=3210661888
TARGET_PARTITION=system_a
PREFLASH_BASELINE=STOCK_V010014
PREFLASH_SYSTEM_A_BYTES=757059584
FLASH_ATTEMPT_NUMBER=1
ATTEMPT_STATE=ARMED
TOOL_SOURCE_COMMIT=$tool_commit
AUTOMATIC_FLASH_RETRY=NO
EOF_ATTEMPT
  (
    cd "$attempt" || exit 1
    sha256sum N1I_C1_FLASH_ATTEMPT_ARMED.env > SHA256SUMS.txt
  )
  cat > "$write/pre-state.env" <<'EOF_PRE'
N1I_C1_FASTBOOT_PHASE=PRE
N1I_C1_FASTBOOT_BASELINE=STOCK_V010014
N1I_C1_FASTBOOT_SYSTEM_A_BYTES=757059584
N1I_C1_FASTBOOT_ACTIVE_COW_COUNT=0
N1I_C1_FASTBOOT_STATE=PASS
EOF_PRE
  cat > "$run/policy.env" <<'EOF_POLICY'
N1I_C1_FLASH_TARGET=system_a
N1I_C1_FLASH_ATTEMPT_LIMIT=1
N1I_C1_AUTOMATIC_FLASH_RETRY=NO
EOF_POLICY
  printf '%s\n' "$run"
}

RETIRE_ROOT="$TMP/retire-evidence"
RETIRE_RUN="$(make_abort_evidence "$RETIRE_ROOT" 4024d750e5e2eb019ff62532d2a1fe685902c0aa)"
SABLE_EVIDENCE_ROOT="$RETIRE_ROOT" \
  bash "$RETIRE" \
    --authorize-retirement YES_KNOWN_PREWRITE_NOUNSET_ABORT \
    --serial "$SERIAL" \
    --evidence-dir "$RETIRE_RUN" \
    > "$TMP/retire-pass.out" 2>&1
RETIRE_RC=$?
if [[ "$RETIRE_RC" -eq 0 ]] &&
   grep -Fq 'N1I_C1_PREWRITE_ABORT_RETIREMENT=PASS' "$TMP/retire-pass.out" &&
   [[ -f "$RETIRE_RUN/attempt-retirement/N1I_C1_PREWRITE_ABORT_RETIREMENT.env" ]]; then
  pass PREWRITE_RETIREMENT_VALID_ZERO_WRITE
else
  fail PREWRITE_RETIREMENT_VALID_ZERO_WRITE "rc=$RETIRE_RC"
fi

RETIRE_BAD_ROOT="$TMP/retire-bad-evidence"
RETIRE_BAD_RUN="$(make_abort_evidence "$RETIRE_BAD_ROOT" 4024d750e5e2eb019ff62532d2a1fe685902c0aa)"
: > "$RETIRE_BAD_RUN/write-proof/fastboot-flash-system-a.log"
SABLE_EVIDENCE_ROOT="$RETIRE_BAD_ROOT" \
  bash "$RETIRE" \
    --authorize-retirement YES_KNOWN_PREWRITE_NOUNSET_ABORT \
    --serial "$SERIAL" \
    --evidence-dir "$RETIRE_BAD_RUN" \
    > "$TMP/retire-bad.out" 2>&1
RETIRE_BAD_RC=$?
if [[ "$RETIRE_BAD_RC" -ne 0 ]] &&
   grep -Fq 'flash_log_exists_write_boundary_may_have_been_crossed' "$TMP/retire-bad.out"; then
  pass PREWRITE_RETIREMENT_REFUSES_FLASH_LOG
else
  fail PREWRITE_RETIREMENT_REFUSES_FLASH_LOG "rc=$RETIRE_BAD_RC"
fi

RETIRE_WRONG_ROOT="$TMP/retire-wrong-head"
RETIRE_WRONG_RUN="$(make_abort_evidence "$RETIRE_WRONG_ROOT" deadbeefdeadbeefdeadbeefdeadbeefdeadbeef)"
SABLE_EVIDENCE_ROOT="$RETIRE_WRONG_ROOT" \
  bash "$RETIRE" \
    --authorize-retirement YES_KNOWN_PREWRITE_NOUNSET_ABORT \
    --serial "$SERIAL" \
    --evidence-dir "$RETIRE_WRONG_RUN" \
    > "$TMP/retire-wrong.out" 2>&1
RETIRE_WRONG_RC=$?
if [[ "$RETIRE_WRONG_RC" -ne 0 ]] &&
   grep -Fq 'env_value_mismatch key=TOOL_SOURCE_COMMIT' "$TMP/retire-wrong.out"; then
  pass PREWRITE_RETIREMENT_REFUSES_OTHER_HEAD
else
  fail PREWRITE_RETIREMENT_REFUSES_OTHER_HEAD "rc=$RETIRE_WRONG_RC"
fi

cat > "$ADB_BIN" <<'EOF_ADB'
#!/usr/bin/env bash
state="$(cat "$MOCK_STATE_FILE")"
printf 'adb %s\n' "$*" >> "$MOCK_TRANSPORT_LOG"
if [[ "$1" == devices ]]; then
  echo "List of devices attached"
  if [[ "$state" == ANDROID ]]; then
    echo -e "$MOCK_SERIAL\tdevice"
  elif [[ "$state" == UNAUTHORIZED ]]; then
    echo -e "$MOCK_SERIAL\tunauthorized"
  elif [[ "$MOCK_AMBIGUOUS" == YES ]]; then
    echo -e "$MOCK_SERIAL\tdevice"
  fi
  exit 0
fi
if [[ "$1" == -s && "$2" == "$MOCK_SERIAL" && "$3" == reboot && "$4" == bootloader ]]; then
  echo FASTBOOT > "$MOCK_STATE_FILE"
  exit 0
fi
echo "mock adb unsupported: $*" >&2
exit 70
EOF_ADB
chmod +x "$ADB_BIN"

cat > "$FASTBOOT_BIN" <<'EOF_FB'
#!/usr/bin/env bash
state="$(cat "$MOCK_STATE_FILE")"
printf 'fastboot %s\n' "$*" >> "$MOCK_TRANSPORT_LOG"
if [[ "$1" == devices ]]; then
  if [[ "$state" == FASTBOOT || "$state" == FASTBOOTD || "$state" == FASTBOOT_RC0_FAIL || "$MOCK_AMBIGUOUS" == YES ]]; then
    echo -e "$MOCK_SERIAL\tfastboot"
  fi
  exit 0
fi
if [[ "$1" == -s && "$2" == "$MOCK_SERIAL" && "$3" == getvar && "$4" == is-userspace ]]; then
  if [[ "$state" == FASTBOOTD ]]; then
    echo "is-userspace: yes" >&2
  elif [[ "$state" == FASTBOOT ]]; then
    echo "is-userspace: no" >&2
  elif [[ "$state" == FASTBOOT_RC0_FAIL ]]; then
    echo "getvar:is-userspace FAILED (remote: 'Variable not found')" >&2
    echo "Finished. Total time: 0.005s" >&2
    exit 0
  else
    exit 1
  fi
  exit 0
fi
if [[ "$1" == -s && "$2" == "$MOCK_SERIAL" && "$3" == reboot && "$4" == fastboot ]]; then
  echo FASTBOOTD > "$MOCK_STATE_FILE"
  exit 0
fi
echo "mock fastboot unsupported: $*" >&2
exit 71
EOF_FB
chmod +x "$FASTBOOT_BIN"

# shellcheck source=/dev/null
source "$COMMON"

probe_once_case() {
  local start="$1" expected="$2"
  echo "$start" > "$STATE"
  : > "$LOG"
  export MOCK_AMBIGUOUS=NO
  local actual adb_devices fb_devices
  actual="$(n1i_c1_probe_mode)"
  adb_devices="$(grep -Fc "adb devices" "$LOG" || true)"
  fb_devices="$(grep -Fc "fastboot devices" "$LOG" || true)"
  if [[ "$actual" == "$expected" && "$adb_devices" == 1 && "$fb_devices" == 1 ]]; then
    pass "PROBE_ONCE_$start"
  else
    fail "PROBE_ONCE_$start" "actual=$actual adb_devices=$adb_devices fastboot_devices=$fb_devices"
  fi
}

probe_once_case ANDROID ANDROID_ADB
probe_once_case FASTBOOT FASTBOOT
probe_once_case FASTBOOTD FASTBOOTD
probe_once_case FASTBOOT_RC0_FAIL FASTBOOT_UNKNOWN

echo FASTBOOT_RC0_FAIL > "$STATE"
: > "$LOG"
if n1i_c1_fastboot_getvar is-userspace >/dev/null 2>&1; then
  fail FASTBOOT_REMOTE_FAILURE_TEXT_REFUSED "unexpected success"
else
  pass FASTBOOT_REMOTE_FAILURE_TEXT_REFUSED
fi

run_mode_case() {
  local start="$1" expected_adb_reboot="$2" expected_fb_reboot="$3"
  echo "$start" > "$STATE"
  : > "$LOG"
  export MOCK_AMBIGUOUS=NO
  n1i_c1_enter_fastbootd > "$TMP/mode-$start.out" 2>&1
  local rc=$?
  if [[ "$rc" -ne 0 || "$(cat "$STATE")" != FASTBOOTD ]]; then
    fail "MODE_$start" "rc=$rc final=$(cat "$STATE")"
    return
  fi
  local adb_count fb_count
  adb_count="$(grep -Fc 'adb -s TITAN2-TEST-0001 reboot bootloader' "$LOG" || true)"
  fb_count="$(grep -Fc 'fastboot -s TITAN2-TEST-0001 reboot fastboot' "$LOG" || true)"
  [[ "$adb_count" == "$expected_adb_reboot" && "$fb_count" == "$expected_fb_reboot" ]] ||
    fail "MODE_$start" "adb_reboot=$adb_count fb_reboot=$fb_count"
  if grep -Fq ' flash ' "$LOG"; then
    fail "MODE_$start" "unexpected flash in mode setup"
  fi
  pass "MODE_$start"
}

run_mode_case ANDROID 1 1
run_mode_case FASTBOOT 0 1
run_mode_case FASTBOOTD 0 0

for bad in UNAUTHORIZED ABSENT FASTBOOT_RC0_FAIL; do
  echo "$bad" > "$STATE"
  : > "$LOG"
  export MOCK_AMBIGUOUS=NO
  n1i_c1_enter_fastbootd > "$TMP/bad-$bad.out" 2>&1
  rc=$?
  if [[ "$rc" -eq 0 ]]; then
    fail "MODE_REFUSE_$bad" "unexpected success"
  elif grep -Eq 'reboot| flash ' "$LOG"; then
    fail "MODE_REFUSE_$bad" "mutation attempted"
  else
    pass "MODE_REFUSE_$bad"
  fi
done

echo ANDROID > "$STATE"
: > "$LOG"
export MOCK_AMBIGUOUS=YES
n1i_c1_enter_fastbootd > "$TMP/ambiguous.out" 2>&1
rc=$?
if [[ "$rc" -eq 0 ]]; then
  fail MODE_REFUSE_AMBIGUOUS "unexpected success"
elif grep -Eq 'reboot| flash ' "$LOG"; then
  fail MODE_REFUSE_AMBIGUOUS "mutation attempted"
else
  pass MODE_REFUSE_AMBIGUOUS
fi
export MOCK_AMBIGUOUS=NO

make_getvar() {
  local out="$1" system_bytes="$2" cow_bytes="${3:-0}"
  cat > "$out" <<EOF_GETVAR
(bootloader) product: Titan_2
(bootloader) current-slot: a
(bootloader) is-userspace: yes
(bootloader) unlocked: yes
(bootloader) snapshot-update-status: none
(bootloader) is-logical:system_a: yes
(bootloader) partition-size:system_a: $system_bytes
(bootloader) is-logical:system_ext_a: yes
(bootloader) partition-size:system_ext_a: 704434176
(bootloader) is-logical:product_a: yes
(bootloader) partition-size:product_a: 1842647040
(bootloader) is-logical:vendor_a: yes
(bootloader) partition-size:vendor_a: 873082880
(bootloader) is-logical:system_dlkm_a: yes
(bootloader) partition-size:system_dlkm_a: 7487488
(bootloader) is-logical:vendor_dlkm_a: yes
(bootloader) partition-size:vendor_dlkm_a: 18366464
(bootloader) is-logical:odm_dlkm_a: yes
(bootloader) partition-size:odm_dlkm_a: 348160
(bootloader) partition-size:super: 9663676416
EOF_GETVAR
  if [[ "$cow_bytes" -gt 0 ]]; then
    cat >> "$out" <<EOF_COW
(bootloader) is-logical:system_a-cow: yes
(bootloader) partition-size:system_a-cow: $cow_bytes
EOF_COW
  fi
}

make_getvar "$TMP/stock.txt" 757059584
python3 "$QUAL" --getvar-all "$TMP/stock.txt" --phase pre --out-env "$TMP/stock.env" >/dev/null
[[ "$?" -eq 0 ]] && pass PREFLIGHT_STOCK_BASELINE ||
  fail PREFLIGHT_STOCK_BASELINE "unexpected fail"

for expected in \
  'N1I_C1_FASTBOOT_BASELINE=STOCK_V010014' \
  'N1I_C1_FASTBOOT_SYSTEM_A_BYTES=757059584' \
  'N1I_C1_FASTBOOT_LOGICAL_ALLOCATED_BYTES=4203425792' \
  'N1I_C1_FASTBOOT_PROJECTED_ALLOCATED_BYTES=6657028096' \
  'N1I_C1_FASTBOOT_PROJECTED_REMAINING_SUPER_BYTES=3006648320' \
  'N1I_C1_FASTBOOT_MIN_REMAINING_SUPER_BYTES=536870912' \
  'N1I_C1_FASTBOOT_REVIEWED_GROUP_SAFE_TARGET_CEILING_BYTES=3263168512' \
  'N1I_C1_FASTBOOT_TARGET_WITHIN_REVIEWED_GROUP_CEILING=YES' \
  'N1I_C1_FASTBOOT_REQUIRED_ACTIVE_LOGICAL_COUNT=7' \
  'N1I_C1_FASTBOOT_ODM_MATERIALIZATION=ABSENT_AS_QUALIFIED' \
  'N1I_C1_FASTBOOT_IMPLICIT_RESIZE=YES' \
  'N1I_C1_FASTBOOT_MANUAL_PRE_RESIZE=NO'
do
  grep -Fxq "$expected" "$TMP/stock.env" ||
    fail PREFLIGHT_LIVE_GEOMETRY "missing=$expected"
done
[[ "$FAILS" -eq 0 ]] && pass PREFLIGHT_LIVE_GEOMETRY

make_getvar "$TMP/c3a.txt" 3146977280
python3 "$QUAL" --getvar-all "$TMP/c3a.txt" --phase pre --out-env "$TMP/c3a.env" >/dev/null
[[ "$?" -eq 0 ]] && pass PREFLIGHT_C3A_BASELINE ||
  fail PREFLIGHT_C3A_BASELINE "unexpected fail"

make_getvar "$TMP/pre.txt" 3200540672
python3 "$QUAL" --getvar-all "$TMP/pre.txt" --phase pre --out-env "$TMP/pre.env" >/dev/null
[[ "$?" -eq 0 ]] && pass PREFLIGHT_N1F_BASELINE ||
  fail PREFLIGHT_N1F_BASELINE "unexpected fail"

make_getvar "$TMP/unknown.txt" 3100000000
python3 "$QUAL" --getvar-all "$TMP/unknown.txt" --phase pre --out-env "$TMP/unknown.env" >/dev/null 2>&1
[[ "$?" -ne 0 ]] && pass PREFLIGHT_UNKNOWN_BASELINE_REFUSED ||
  fail PREFLIGHT_UNKNOWN_BASELINE_REFUSED "unexpected pass"

make_getvar "$TMP/already.txt" 3210661888
python3 "$QUAL" --getvar-all "$TMP/already.txt" --phase pre --out-env "$TMP/already.env" >/dev/null 2>&1
[[ "$?" -eq 20 ]] && pass PREFLIGHT_ALREADY_TARGET_REFUSED ||
  fail PREFLIGHT_ALREADY_TARGET_REFUSED "wrong rc"

make_getvar "$TMP/post.txt" 3210661888
python3 "$QUAL" --getvar-all "$TMP/post.txt" --phase post --out-env "$TMP/post.env" >/dev/null
[[ "$?" -eq 0 ]] && pass POSTFLIGHT_TARGET_SIZE ||
  fail POSTFLIGHT_TARGET_SIZE "unexpected fail"

make_getvar "$TMP/post-wrong.txt" 3200540672
python3 "$QUAL" --getvar-all "$TMP/post-wrong.txt" --phase post --out-env "$TMP/post-wrong.env" >/dev/null 2>&1
[[ "$?" -ne 0 ]] && pass POSTFLIGHT_WRONG_SIZE_REFUSED ||
  fail POSTFLIGHT_WRONG_SIZE_REFUSED "unexpected pass"

make_getvar "$TMP/cow.txt" 3200540672 1048576
python3 "$QUAL" --getvar-all "$TMP/cow.txt" --phase pre --out-env "$TMP/cow.env" >/dev/null 2>&1
[[ "$?" -ne 0 ]] && pass PREFLIGHT_ACTIVE_COW_REFUSED ||
  fail PREFLIGHT_ACTIVE_COW_REFUSED "unexpected pass"

make_getvar "$TMP/truncated.txt" 3200540672
sed -i '/is-logical:vendor_dlkm_a:/d;/partition-size:vendor_dlkm_a:/d' "$TMP/truncated.txt"
python3 "$QUAL" --getvar-all "$TMP/truncated.txt" --phase pre --out-env "$TMP/truncated.env" >/dev/null 2>&1
[[ "$?" -ne 0 ]] && pass PREFLIGHT_TRUNCATED_GEOMETRY_REFUSED ||
  fail PREFLIGHT_TRUNCATED_GEOMETRY_REFUSED "unexpected pass"

make_getvar "$TMP/unexpected-odm.txt" 757059584
cat >> "$TMP/unexpected-odm.txt" <<'EOF_ODM'
(bootloader) is-logical:odm_a: yes
(bootloader) partition-size:odm_a: 1048576
EOF_ODM
python3 "$QUAL" --getvar-all "$TMP/unexpected-odm.txt" --phase pre --out-env "$TMP/unexpected-odm.env" >/dev/null 2>&1
[[ "$?" -ne 0 ]] && pass PREFLIGHT_UNEXPECTED_ODM_REFUSED ||
  fail PREFLIGHT_UNEXPECTED_ODM_REFUSED "unexpected pass"

make_getvar "$TMP/aliases.txt" 3200540672
cat >> "$TMP/aliases.txt" <<'EOF_ALIAS'
(bootloader) is-logical:system: yes
(bootloader) partition-size:system: 3200540672
(bootloader) is-logical:system_ext: yes
(bootloader) partition-size:system_ext: 704434176
(bootloader) is-logical:product: yes
(bootloader) partition-size:product: 1842647040
(bootloader) is-logical:vendor: yes
(bootloader) partition-size:vendor: 873082880
(bootloader) is-logical:system_dlkm: yes
(bootloader) partition-size:system_dlkm: 7487488
(bootloader) is-logical:vendor_dlkm: yes
(bootloader) partition-size:vendor_dlkm: 18366464
(bootloader) is-logical:odm_dlkm: yes
(bootloader) partition-size:odm_dlkm: 348160
EOF_ALIAS
python3 "$QUAL" --getvar-all "$TMP/aliases.txt" --phase pre --out-env "$TMP/aliases.env" >/dev/null 2>&1
[[ "$?" -eq 0 ]] && pass PREFLIGHT_ACTIVE_ALIAS_DEDUP ||
  fail PREFLIGHT_ACTIVE_ALIAS_DEDUP "alias double-count false refusal"

if [[ "$FAILS" -eq 0 ]]; then
  echo "N1I_C1_FLASH_EXECUTOR_SELFTEST=PASS"
  exit 0
fi
echo "N1I_C1_FLASH_EXECUTOR_SELFTEST=FAIL count=$FAILS" >&2
exit 1
