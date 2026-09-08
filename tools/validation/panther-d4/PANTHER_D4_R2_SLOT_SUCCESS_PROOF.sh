#!/usr/bin/env bash
set -u
set -o pipefail

DEVICE_CONTACT_AUTHORIZED=${DEVICE_CONTACT_AUTHORIZED:-NO}
DEVICE_REBOOT_AUTHORIZED=${DEVICE_REBOOT_AUTHORIZED:-NO}
FLASH_AUTHORIZED=${FLASH_AUTHORIZED:-NO}
SLOT_CHANGE_AUTHORIZED=${SLOT_CHANGE_AUTHORIZED:-NO}
USERDATA_OR_METADATA_WIPE_AUTHORIZED=${USERDATA_OR_METADATA_WIPE_AUTHORIZED:-NO}
EXPECTED_DEVICE=${EXPECTED_DEVICE:-panther}
EXPECTED_SLOT=${EXPECTED_SLOT:-b}
ADB=${ADB:-adb}
FASTBOOT=${FASTBOOT:-fastboot}
EVIDENCE_ROOT=${EVIDENCE_ROOT:-/tmp}
ENTERED_FASTBOOT=NO
LOG_ACTIVE=NO
EVIDENCE_DIR=
LOG=

seal_if_active() {
  [[ "$LOG_ACTIVE" == YES ]] || return 0
  exec 1>&3 2>&4
  wait
  sha256sum "$0" "$LOG" > "$EVIDENCE_DIR/SHA256SUMS"
  printf '===== EVIDENCE SEAL =====\n'
  cat "$EVIDENCE_DIR/SHA256SUMS"
  printf 'EVIDENCE_DIR=%s\n' "$EVIDENCE_DIR"
  LOG_ACTIVE=NO
}

fail() {
  local code=$1 recovery_rc
  shift
  if [[ "$ENTERED_FASTBOOT" == YES ]]; then
    "$FASTBOOT" reboot </dev/null >/dev/null 2>&1
    recovery_rc=$?
    printf 'RECOVERY_REBOOT_TO_ANDROID_RC=%d\n' "$recovery_rc"
    ENTERED_FASTBOOT=NO
  fi
  printf 'GATE_ERROR=%s\n' "$*"
  printf 'PANTHER_D4_R2_SLOT_SUCCESS_RESULT=BOUNDED_FAIL\n'
  seal_if_active
  exit "$code"
}

need_yes() {
  local name=$1 value=$2
  [[ "$value" == YES ]] || fail 20 "${name}_NOT_AUTHORIZED"
}

need_no() {
  local name=$1 value=$2
  [[ "$value" == NO ]] || fail 21 "${name}_MUST_BE_NO"
}

sanitize_slot() {
  local x=${1//$'\r'/}
  x=${x//$'\n'/}
  x=${x#_}
  printf '%s' "$x"
}

adb_quiet() {
  "$ADB" "$@" </dev/null
}

wait_adb_device() {
  local i state
  for ((i=0; i<90; i++)); do
    state=$(adb_quiet get-state 2>/dev/null || true)
    [[ "$state" == device ]] && return 0
    sleep 2
  done
  return 1
}

wait_android_boot_complete() {
  local i state boot
  for ((i=0; i<120; i++)); do
    state=$(adb_quiet get-state 2>/dev/null || true)
    if [[ "$state" == device ]]; then
      boot=$(adb_quiet shell getprop sys.boot_completed 2>/dev/null | tr -d '\r\n' || true)
      [[ "$boot" == 1 ]] && return 0
    fi
    sleep 2
  done
  return 1
}

fastboot_device_count() {
  local raw count=0 line
  raw=$("$FASTBOOT" devices 2>/dev/null || true)
  while IFS= read -r line; do
    [[ -n "${line//[[:space:]]/}" ]] && ((count+=1))
  done <<< "$raw"
  printf '%s' "$count"
}

wait_fastboot_one() {
  local i count
  for ((i=0; i<60; i++)); do
    count=$(fastboot_device_count)
    [[ "$count" == 1 ]] && return 0
    sleep 1
  done
  return 1
}

fb_getvar() {
  local var=$1 out rc value
  out=$("$FASTBOOT" getvar "$var" 2>&1 </dev/null)
  rc=$?
  [[ $rc -eq 0 ]] || {
    printf 'rc=%d' "$rc"
    return 1
  }
  value=$(printf '%s\n' "$out" | sed -nE "s/^(\(bootloader\)[[:space:]]*)?${var}:[[:space:]]*//p" | head -n1)
  if [[ -z "$value" ]]; then
    value=$(printf '%s\n' "$out" | sed -nE "s/^${var}:[[:space:]]*//p" | head -n1)
  fi
  [[ -n "$value" ]] || {
    printf 'unparsed'
    return 1
  }
  printf '%s' "$value"
}

need_yes DEVICE_CONTACT_AUTHORIZED "$DEVICE_CONTACT_AUTHORIZED"
need_yes DEVICE_REBOOT_AUTHORIZED "$DEVICE_REBOOT_AUTHORIZED"
need_no FLASH_AUTHORIZED "$FLASH_AUTHORIZED"
need_no SLOT_CHANGE_AUTHORIZED "$SLOT_CHANGE_AUTHORIZED"
need_no USERDATA_OR_METADATA_WIPE_AUTHORIZED "$USERDATA_OR_METADATA_WIPE_AUTHORIZED"

command -v "$ADB" >/dev/null 2>&1 || fail 22 ADB_NOT_FOUND
command -v "$FASTBOOT" >/dev/null 2>&1 || fail 23 FASTBOOT_NOT_FOUND

[[ "$EXPECTED_SLOT" == a || "$EXPECTED_SLOT" == b ]] || fail 24 EXPECTED_SLOT_INVALID

TS=$(date -u +%Y%m%dT%H%M%SZ)
EVIDENCE_DIR=$(mktemp -d "$EVIDENCE_ROOT/PANTHER_D4_R2_SLOT_SUCCESS_PROOF_${TS}_XXXXXX") || fail 25 EVIDENCE_DIR_CREATE_FAILED
chmod 0700 "$EVIDENCE_DIR" || fail 25 EVIDENCE_DIR_PERMISSION_FAILED
LOG="$EVIDENCE_DIR/slot_success_proof.log"
exec 3>&1 4>&2
exec > >(tee "$LOG") 2>&1
LOG_ACTIVE=YES

printf '===== AUTHORIZATION =====\n'
printf 'DEVICE_CONTACT_AUTHORIZED=YES\n'
printf 'DEVICE_REBOOT_AUTHORIZED=YES\n'
printf 'FLASH_AUTHORIZED=NO\n'
printf 'SLOT_CHANGE_AUTHORIZED=NO\n'
printf 'USERDATA_OR_METADATA_WIPE_AUTHORIZED=NO\n'

printf '\n===== TOOL BINDING =====\n'
printf 'ADB_PATH=%s\n' "$(command -v "$ADB")"
printf 'FASTBOOT_PATH=%s\n' "$(command -v "$FASTBOOT")"
sha256sum "$(command -v "$ADB")" "$(command -v "$FASTBOOT")" | sed 's#  .*/#  #' || fail 26 TOOL_HASH_FAILED

printf '\n===== PRE-REBOOT ANDROID BINDING =====\n'
wait_adb_device || fail 30 ADB_DEVICE_NOT_READY
pre_product=$(adb_quiet shell getprop ro.product.device | tr -d '\r\n') || fail 31 PRE_PRODUCT_QUERY_FAILED
pre_slot=$(adb_quiet shell getprop ro.boot.slot_suffix | tr -d '\r\n') || fail 32 PRE_SLOT_QUERY_FAILED
pre_boot=$(adb_quiet shell getprop sys.boot_completed | tr -d '\r\n') || fail 33 PRE_BOOT_QUERY_FAILED
[[ "$pre_product" == "$EXPECTED_DEVICE" ]] || fail 34 PRE_PRODUCT_MISMATCH
[[ "$pre_slot" == "_$EXPECTED_SLOT" ]] || fail 35 PRE_SLOT_MISMATCH
[[ "$pre_boot" == 1 ]] || fail 36 PRE_BOOT_NOT_COMPLETE
printf 'PRE_DEVICE_PRODUCT=%s\n' "$pre_product"
printf 'PRE_SLOT_SUFFIX=%s\n' "$pre_slot"
printf 'PRE_BOOT_COMPLETED=%s\n' "$pre_boot"

printf '\n===== CONTROLLED REBOOT TO BOOTLOADER =====\n'
adb_quiet reboot bootloader || fail 40 ADB_REBOOT_BOOTLOADER_FAILED
# From this point forward, any bounded failure attempts a recovery reboot to Android.
ENTERED_FASTBOOT=YES
wait_fastboot_one || fail 41 FASTBOOT_DEVICE_NOT_READY_OR_NOT_UNIQUE
printf 'FASTBOOT_TRANSPORT=PASS_ONE_DEVICE\n'

printf '\n===== READ-ONLY BOOTLOADER SLOT METADATA =====\n'
fb_product=$(fb_getvar product) || fail 50 FASTBOOT_PRODUCT_UNOBSERVABLE
fb_current=$(fb_getvar current-slot) || fail 51 FASTBOOT_CURRENT_SLOT_UNOBSERVABLE
fb_count=$(fb_getvar slot-count) || fail 52 FASTBOOT_SLOT_COUNT_UNOBSERVABLE
fb_success=$(fb_getvar "slot-successful:$EXPECTED_SLOT") || fail 53 FASTBOOT_SLOT_SUCCESSFUL_UNOBSERVABLE
fb_unbootable=$(fb_getvar "slot-unbootable:$EXPECTED_SLOT") || fail 54 FASTBOOT_SLOT_UNBOOTABLE_UNOBSERVABLE
fb_retry=$(fb_getvar "slot-retry-count:$EXPECTED_SLOT") || fb_retry=UNOBSERVED

fb_current=$(sanitize_slot "$fb_current")
printf 'FASTBOOT_PRODUCT=%s\n' "$fb_product"
printf 'FASTBOOT_CURRENT_SLOT=%s\n' "$fb_current"
printf 'FASTBOOT_SLOT_COUNT=%s\n' "$fb_count"
printf 'FASTBOOT_SLOT_SUCCESSFUL_%s=%s\n' "$EXPECTED_SLOT" "$fb_success"
printf 'FASTBOOT_SLOT_UNBOOTABLE_%s=%s\n' "$EXPECTED_SLOT" "$fb_unbootable"
printf 'FASTBOOT_SLOT_RETRY_COUNT_%s=%s\n' "$EXPECTED_SLOT" "$fb_retry"

[[ "$fb_product" == "$EXPECTED_DEVICE" ]] || fail 56 FASTBOOT_PRODUCT_MISMATCH
[[ "$fb_current" == "$EXPECTED_SLOT" ]] || fail 57 FASTBOOT_CURRENT_SLOT_MISMATCH
[[ "$fb_count" == 2 ]] || fail 58 FASTBOOT_SLOT_COUNT_INVALID
[[ "$fb_success" == yes ]] || fail 59 EXPECTED_SLOT_NOT_MARKED_SUCCESSFUL
[[ "$fb_unbootable" == no ]] || fail 60 EXPECTED_SLOT_MARKED_UNBOOTABLE
if [[ "$fb_retry" != UNOBSERVED && ! "$fb_retry" =~ ^[0-9]+$ ]]; then
  fail 61 EXPECTED_SLOT_RETRY_COUNT_INVALID
fi

printf 'D4_SLOT_%s_SUCCESSFUL=PASS\n' "${EXPECTED_SLOT^^}"
printf 'D4_SLOT_%s_BOOTABLE=PASS\n' "${EXPECTED_SLOT^^}"
printf 'D4_SLOT_%s_CURRENT=PASS\n' "${EXPECTED_SLOT^^}"

printf '\n===== CONTROLLED REBOOT TO ANDROID =====\n'
"$FASTBOOT" reboot </dev/null >/dev/null 2>&1 || fail 70 FASTBOOT_REBOOT_FAILED
ENTERED_FASTBOOT=NO
wait_android_boot_complete || fail 71 POST_ANDROID_BOOT_NOT_COMPLETE

post_product=$(adb_quiet shell getprop ro.product.device | tr -d '\r\n') || fail 72 POST_PRODUCT_QUERY_FAILED
post_slot=$(adb_quiet shell getprop ro.boot.slot_suffix | tr -d '\r\n') || fail 73 POST_SLOT_QUERY_FAILED
post_boot=$(adb_quiet shell getprop sys.boot_completed | tr -d '\r\n') || fail 74 POST_BOOT_QUERY_FAILED
[[ "$post_product" == "$EXPECTED_DEVICE" ]] || fail 75 POST_PRODUCT_MISMATCH
[[ "$post_slot" == "_$EXPECTED_SLOT" ]] || fail 76 POST_SLOT_MISMATCH
[[ "$post_boot" == 1 ]] || fail 77 POST_BOOT_NOT_COMPLETE
printf 'POST_DEVICE_PRODUCT=%s\n' "$post_product"
printf 'POST_SLOT_SUFFIX=%s\n' "$post_slot"
printf 'POST_BOOT_COMPLETED=%s\n' "$post_boot"
printf 'POST_SLOT_PRESERVED=PASS\n'

printf '\n===== FINAL RESULT =====\n'
printf 'PANTHER_D4_R2_SLOT_SUCCESS_RESULT=PASS\n'

# Close the evidence log before hashing it so the seal covers final bytes.
seal_if_active
