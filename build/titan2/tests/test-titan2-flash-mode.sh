#!/usr/bin/env bash
# Offline fake-transport self-test for Titan 2 flash mode discovery/transition.
# No real adb/fastboot/device contact.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
HELPER="$ROOT/build/titan2/titan2-flash-mode.sh"
TMP="$(mktemp -d)"
STATE="$TMP/state"
ADB_SERIAL="TITAN-ADB-UNIT"
FASTBOOT_SERIAL="TITAN-FB-UNIT"
FAILURES=0
CASES=0

cleanup() {
  rm -rf "$TMP"
}
trap cleanup EXIT

fail_case() {
  echo "CASE=$1 result=FAIL detail=$2"
  FAILURES=$((FAILURES + 1))
}

pass_case() {
  echo "CASE=$1 result=PASS"
}

cat > "$TMP/adb" <<'EOF'
#!/usr/bin/env bash
state="$(cat "$TITAN2_TEST_STATE")"
if [[ "$1" == devices ]]; then
  echo "List of devices attached"
  if [[ "$state" == android ]]; then
    printf '%s\tdevice\n' "$TITAN2_TEST_ADB_SERIAL"
  elif [[ "$state" == recovery ]]; then
    printf '%s\trecovery\n' "$TITAN2_TEST_ADB_SERIAL"
  fi
  exit 0
fi
if [[ "$1" == -s ]]; then
  serial="$2"
  shift 2
  [[ "$serial" == "$TITAN2_TEST_ADB_SERIAL" ]] || exit 9
  if [[ "$1" == shell && "$2" == getprop ]]; then
    if [[ "$state" == recovery ]]; then
      exit 13
    fi
    case "$3" in
      ro.product.device) echo Titan_2 ;;
      ro.bootmode) echo normal ;;
      *) echo ;;
    esac
    exit 0
  fi
  if [[ "$1" == reboot && "$2" == bootloader ]]; then
    echo bootloader > "$TITAN2_TEST_STATE"
    exit 0
  fi
fi
exit 8
EOF

cat > "$TMP/fastboot" <<'EOF'
#!/usr/bin/env bash
state="$(cat "$TITAN2_TEST_STATE")"
if [[ "$1" == devices ]]; then
  if [[ "$state" == bootloader || "$state" == fastbootd ]]; then
    printf '%s\tfastboot\n' "$TITAN2_TEST_FASTBOOT_SERIAL"
  fi
  exit 0
fi
if [[ "$1" == -s ]]; then
  serial="$2"
  shift 2
  [[ "$serial" == "$TITAN2_TEST_FASTBOOT_SERIAL" ]] || exit 9
  if [[ "$1" == getvar ]]; then
    case "$2" in
      is-userspace)
        [[ "$state" == fastbootd ]] && value=yes || value=no
        ;;
      product)
        [[ "$state" == fastbootd ]] && value=Titan_2 || value=g71v78c2k_dfl_tee
        ;;
      *) value="" ;;
    esac
    echo "$2: $value" >&2
    exit 0
  fi
  if [[ "$1" == reboot && "$2" == fastboot ]]; then
    echo fastbootd > "$TITAN2_TEST_STATE"
    exit 0
  fi
fi
exit 8
EOF
chmod +x "$TMP/adb" "$TMP/fastboot"

export TITAN2_TEST_STATE="$STATE"
export TITAN2_TEST_ADB_SERIAL="$ADB_SERIAL"
export TITAN2_TEST_FASTBOOT_SERIAL="$FASTBOOT_SERIAL"
export TITAN2_MODE_COMMAND_TIMEOUT_SECONDS=2
export TITAN2_MODE_BOOTLOADER_WAIT_SECONDS=3
export TITAN2_MODE_FASTBOOTD_WAIT_SECONDS=3
export TITAN2_MODE_POLL_SECONDS=1

# shellcheck source=/dev/null
source "$HELPER"

ADB_HASH="$(printf '%s' "$ADB_SERIAL" | sha256sum | awk '{print $1}')"
FASTBOOT_HASH="$(printf '%s' "$FASTBOOT_SERIAL" | sha256sum | awk '{print $1}')"

run_success_case() {
  local name="$1"
  local initial="$2"
  local requested="$3"
  local expected_initial="$4"
  local expected_transitions="$5"
  local out="$TMP/$name.out"
  local rc

  CASES=$((CASES + 1))
  echo "$initial" > "$STATE"
  REBOOTED_TO_FLASH_MODE=NO
  REBOOTED_TO_BOOTLOADER=NO
  (
    # Compatibility simulation only: the shared flash runner currently has
    # inherited errexit. The Titan helper itself must not depend on or enable it.
    set -e
    titan2_ensure_fastbootd_mode       "$TMP/adb" "$TMP/fastboot" "$requested"       "$ADB_HASH" "$FASTBOOT_HASH"       Titan_2 g71v78c2k_dfl_tee Titan_2 "$TMP"
  ) > "$out" 2>&1
  rc=$?

  if [[ "$rc" -ne 0 ]]; then
    fail_case "$name" "rc=$rc"
    cat "$out"
    return
  fi
  [[ "$(cat "$STATE")" == fastbootd ]] || {
    fail_case "$name" "final_state=$(cat "$STATE")"
    return
  }
  grep -Fq "TITAN2_FLASH_INITIAL_MODE=$expected_initial" "$out" || {
    fail_case "$name" "initial_marker"
    return
  }
  grep -Fq "TITAN2_FLASH_MODE_TRANSITION_COUNT=$expected_transitions" "$out" || {
    fail_case "$name" "transition_count"
    return
  }
  grep -Fq "TITAN2_FLASH_FASTBOOTD_READY=PASS" "$out" || {
    fail_case "$name" "ready_marker"
    return
  }
  pass_case "$name"
}

run_failure_case() {
  local name="$1"
  local initial="$2"
  local requested="$3"
  local expected_marker="$4"
  local out="$TMP/$name.out"
  local rc

  CASES=$((CASES + 1))
  echo "$initial" > "$STATE"
  REBOOTED_TO_FLASH_MODE=NO
  REBOOTED_TO_BOOTLOADER=NO
  (
    # Compatibility simulation only: the shared flash runner currently has
    # inherited errexit. The Titan helper itself must not depend on or enable it.
    set -e
    titan2_ensure_fastbootd_mode       "$TMP/adb" "$TMP/fastboot" "$requested"       "$ADB_HASH" "$FASTBOOT_HASH"       Titan_2 g71v78c2k_dfl_tee Titan_2 "$TMP"
  ) > "$out" 2>&1
  rc=$?

  if [[ "$rc" -eq 0 ]]; then
    fail_case "$name" "unexpected_success"
    cat "$out"
    return
  fi
  grep -Fq "$expected_marker" "$out" || {
    fail_case "$name" "missing_marker=$expected_marker"
    cat "$out"
    return
  }
  pass_case "$name"
}

run_success_case android_to_fastbootd android "$ADB_SERIAL" ANDROID_ADB 2
run_success_case bootloader_to_fastbootd bootloader "$FASTBOOT_SERIAL" BOOTLOADER_FASTBOOT 1
run_success_case already_fastbootd fastbootd "$FASTBOOT_SERIAL" FASTBOOTD 0
run_failure_case recovery_blocked recovery "$ADB_SERIAL"   "TITAN2_FLASH_MODE_TRANSITION=BLOCKED_RECOVERY_MANUAL_REVIEW_REQUIRED"
run_failure_case wrong_serial android WRONG-SERIAL   "TITAN2_FLASH_MODE_DISCOVERY=FAIL mode=REQUESTED_SERIAL_NOT_BOUND"

echo "TITAN2_FLASH_MODE_SELFTEST_CASES=$CASES"
echo "TITAN2_FLASH_MODE_SELFTEST_FAILURES=$FAILURES"
if [[ "$FAILURES" -eq 0 && "$CASES" -eq 5 ]]; then
  echo "TITAN2_FLASH_MODE_SELFTEST=PASS"
  exit 0
fi

echo "TITAN2_FLASH_MODE_SELFTEST=FAIL"
exit 1
