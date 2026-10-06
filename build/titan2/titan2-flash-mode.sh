#!/usr/bin/env bash
# Titan 2 deployment transport-mode discovery and bounded transition helper.
# Source-only. It performs no work until titan2_ensure_fastbootd_mode is called.
# Do not enable errexit or pipefail here; callers use explicit return-code checks.

TITAN2_MODE_COMMAND_TIMEOUT_SECONDS="${TITAN2_MODE_COMMAND_TIMEOUT_SECONDS:-8}"
TITAN2_MODE_BOOTLOADER_WAIT_SECONDS="${TITAN2_MODE_BOOTLOADER_WAIT_SECONDS:-45}"
TITAN2_MODE_FASTBOOTD_WAIT_SECONDS="${TITAN2_MODE_FASTBOOTD_WAIT_SECONDS:-60}"
TITAN2_MODE_POLL_SECONDS="${TITAN2_MODE_POLL_SECONDS:-1}"

titan2_mode_hash_serial() {
  printf '%s' "$1" | sha256sum | awk '{print $1}'
}

titan2_mode_timeout_bin() {
  TITAN2_MODE_TIMEOUT_BIN="$(command -v timeout 2>/dev/null || true)"
  [[ -n "$TITAN2_MODE_TIMEOUT_BIN" && -x "$TITAN2_MODE_TIMEOUT_BIN" ]]
}

titan2_mode_capture() {
  local seconds="$1"
  shift
  titan2_mode_timeout_bin || return 127
  "$TITAN2_MODE_TIMEOUT_BIN" --foreground "${seconds}s" "$@" </dev/null 2>&1
}

titan2_mode_find_bound_adb() {
  local adb="$1"
  local expected_hash="$2"
  local output rc serial state hash matches=0

  TITAN2_MODE_ADB_SERIAL=""
  TITAN2_MODE_ADB_TRANSPORT_STATE=""
  if output="$(titan2_mode_capture "$TITAN2_MODE_COMMAND_TIMEOUT_SECONDS" "$adb" devices)"; then
    rc=0
  else
    rc=$?
  fi
  [[ "$rc" -eq 0 ]] || return "$rc"

  while read -r serial state; do
    [[ -n "$serial" ]] || continue
    case "$state" in
      device|recovery) ;;
      *) continue ;;
    esac
    hash="$(titan2_mode_hash_serial "$serial")"
    if [[ "$hash" == "$expected_hash" ]]; then
      TITAN2_MODE_ADB_SERIAL="$serial"
      TITAN2_MODE_ADB_TRANSPORT_STATE="$state"
      matches=$((matches + 1))
    fi
  done <<<"$output"

  [[ "$matches" -le 1 ]] || return 3
  [[ "$matches" -eq 1 ]]
}

titan2_mode_find_bound_fastboot() {
  local fastboot="$1"
  local expected_hash="$2"
  local output rc serial extra hash matches=0

  TITAN2_MODE_FASTBOOT_SERIAL=""
  if output="$(titan2_mode_capture "$TITAN2_MODE_COMMAND_TIMEOUT_SECONDS" "$fastboot" devices)"; then
    rc=0
  else
    rc=$?
  fi
  [[ "$rc" -eq 0 ]] || return "$rc"

  while read -r serial extra; do
    [[ -n "$serial" ]] || continue
    hash="$(titan2_mode_hash_serial "$serial")"
    if [[ "$hash" == "$expected_hash" ]]; then
      TITAN2_MODE_FASTBOOT_SERIAL="$serial"
      matches=$((matches + 1))
    fi
  done <<<"$output"

  [[ "$matches" -le 1 ]] || return 3
  [[ "$matches" -eq 1 ]]
}

titan2_mode_adb_getprop() {
  local adb="$1"
  local serial="$2"
  local key="$3"
  local out rc
  if out="$(titan2_mode_capture "$TITAN2_MODE_COMMAND_TIMEOUT_SECONDS"     "$adb" -s "$serial" shell getprop "$key")"; then
    rc=0
  else
    rc=$?
  fi
  [[ "$rc" -eq 0 ]] || return "$rc"
  printf '%s\n' "$out" | tr -d '\r' | tail -n 1
}

titan2_mode_fastboot_getvar() {
  local fastboot="$1"
  local serial="$2"
  local key="$3"
  local out rc
  if out="$(titan2_mode_capture "$TITAN2_MODE_COMMAND_TIMEOUT_SECONDS"     "$fastboot" -s "$serial" getvar "$key")"; then
    rc=0
  else
    rc=$?
  fi
  [[ "$rc" -eq 0 ]] || return "$rc"
  printf '%s\n' "$out" |
    sed -n -E "s/^(\(bootloader\)[[:space:]]*)?${key}:[[:space:]]*//p" |
    tail -n 1
}

titan2_mode_classify_fastboot() {
  local fastboot="$1"
  local serial="$2"
  local bootloader_product="$3"
  local fastbootd_product="$4"
  local userspace product

  TITAN2_MODE_FASTBOOT_CLASS=FASTBOOT_UNKNOWN
  if userspace="$(titan2_mode_fastboot_getvar "$fastboot" "$serial" is-userspace)"; then
    :
  else
    return 1
  fi
  if product="$(titan2_mode_fastboot_getvar "$fastboot" "$serial" product)"; then
    :
  else
    return 1
  fi

  TITAN2_MODE_FASTBOOT_USERSPACE="$userspace"
  TITAN2_MODE_FASTBOOT_PRODUCT="$product"

  if [[ "${userspace,,}" == yes && "$product" == "$fastbootd_product" ]]; then
    TITAN2_MODE_FASTBOOT_CLASS=FASTBOOTD
    return 0
  fi
  if [[ "${userspace,,}" == no && "$product" == "$bootloader_product" ]]; then
    TITAN2_MODE_FASTBOOT_CLASS=BOOTLOADER_FASTBOOT
    return 0
  fi
  return 2
}

titan2_detect_device_mode() {
  local adb="$1"
  local fastboot="$2"
  local requested_serial="$3"
  local expected_adb_hash="$4"
  local expected_fastboot_hash="$5"
  local android_product="$6"
  local bootloader_product="$7"
  local fastbootd_product="$8"
  local requested_hash adb_found=NO fastboot_found=NO
  local adb_product adb_bootmode rc

  TITAN2_MODE_DETECTED=UNAVAILABLE
  TITAN2_MODE_ADB_SERIAL=""
  TITAN2_MODE_ADB_TRANSPORT_STATE=""
  TITAN2_MODE_ADB_PRODUCT=""
  TITAN2_MODE_ADB_BOOTMODE=""
  TITAN2_MODE_ADB_PROPERTIES_READABLE=NO
  TITAN2_MODE_FASTBOOT_SERIAL=""
  TITAN2_MODE_FASTBOOT_PRODUCT=""
  TITAN2_MODE_FASTBOOT_USERSPACE=""

  requested_hash="$(titan2_mode_hash_serial "$requested_serial")"
  if [[ "$requested_hash" != "$expected_adb_hash" &&
        "$requested_hash" != "$expected_fastboot_hash" ]]; then
    TITAN2_MODE_DETECTED=REQUESTED_SERIAL_NOT_BOUND
    return 4
  fi

  if titan2_mode_find_bound_adb "$adb" "$expected_adb_hash"; then
    rc=0
  else
    rc=$?
  fi
  case "$rc" in
    0) adb_found=YES ;;
    3) TITAN2_MODE_DETECTED=AMBIGUOUS_ADB; return 3 ;;
  esac

  if titan2_mode_find_bound_fastboot "$fastboot" "$expected_fastboot_hash"; then
    rc=0
  else
    rc=$?
  fi
  case "$rc" in
    0) fastboot_found=YES ;;
    3) TITAN2_MODE_DETECTED=AMBIGUOUS_FASTBOOT; return 3 ;;
  esac

  if [[ "$adb_found" == YES && "$fastboot_found" == YES ]]; then
    TITAN2_MODE_DETECTED=AMBIGUOUS_TRANSPORTS
    return 3
  fi

  if [[ "$adb_found" == YES ]]; then
    # Recovery on Titan 2 may enumerate through ADB while rejecting shell/getprop.
    # The bound ADB transport state "recovery" is therefore authoritative for
    # recovery classification; property reads are best-effort evidence only.
    if [[ "$TITAN2_MODE_ADB_TRANSPORT_STATE" == recovery ]]; then
      TITAN2_MODE_DETECTED=RECOVERY_ADB
      TITAN2_MODE_ADB_PROPERTIES_READABLE=NO
      return 0
    fi

    if adb_product="$(titan2_mode_adb_getprop "$adb" "$TITAN2_MODE_ADB_SERIAL" ro.product.device)"; then
      rc=0
    else
      rc=$?
    fi
    [[ "$rc" -eq 0 ]] || {
      TITAN2_MODE_DETECTED=ADB_UNREADABLE
      return 1
    }
    [[ "$adb_product" == "$android_product" ]] || {
      TITAN2_MODE_DETECTED=WRONG_ADB_PRODUCT
      return 5
    }
    if adb_bootmode="$(titan2_mode_adb_getprop "$adb" "$TITAN2_MODE_ADB_SERIAL" ro.bootmode)"; then
      :
    else
      adb_bootmode=""
    fi
    TITAN2_MODE_ADB_PRODUCT="$adb_product"
    TITAN2_MODE_ADB_BOOTMODE="$adb_bootmode"
    TITAN2_MODE_ADB_PROPERTIES_READABLE=YES
    if [[ "${adb_bootmode,,}" == *recovery* ]]; then
      TITAN2_MODE_DETECTED=RECOVERY_ADB
    else
      TITAN2_MODE_DETECTED=ANDROID_ADB
    fi
    return 0
  fi

  if [[ "$fastboot_found" == YES ]]; then
    if titan2_mode_classify_fastboot         "$fastboot" "$TITAN2_MODE_FASTBOOT_SERIAL"         "$bootloader_product" "$fastbootd_product"; then
      rc=0
    else
      rc=$?
    fi
    TITAN2_MODE_DETECTED="$TITAN2_MODE_FASTBOOT_CLASS"
    return "$rc"
  fi

  TITAN2_MODE_DETECTED=UNAVAILABLE
  return 1
}

titan2_wait_for_fastboot_mode() {
  local fastboot="$1"
  local expected_fastboot_hash="$2"
  local bootloader_product="$3"
  local fastbootd_product="$4"
  local expected_mode="$5"
  local timeout_seconds="$6"
  local start now

  start="$(date +%s)"
  while :; do
    if titan2_mode_find_bound_fastboot "$fastboot" "$expected_fastboot_hash"; then
      if titan2_mode_classify_fastboot           "$fastboot" "$TITAN2_MODE_FASTBOOT_SERIAL"           "$bootloader_product" "$fastbootd_product"; then
        if [[ "$TITAN2_MODE_FASTBOOT_CLASS" == "$expected_mode" ]]; then
          return 0
        fi
      fi
    fi

    now="$(date +%s)"
    if (( now - start >= timeout_seconds )); then
      return 1
    fi
    sleep "$TITAN2_MODE_POLL_SECONDS"
  done
}

titan2_ensure_fastbootd_mode() {
  local adb="$1"
  local fastboot="$2"
  local requested_serial="$3"
  local expected_adb_hash="$4"
  local expected_fastboot_hash="$5"
  local android_product="$6"
  local bootloader_product="$7"
  local fastbootd_product="$8"
  local evidence_dir="${9:-}"
  local rc

  TITAN2_MODE_INITIAL=""
  TITAN2_MODE_FINAL=""
  TITAN2_MODE_TRANSITION_COUNT=0

  if titan2_detect_device_mode       "$adb" "$fastboot" "$requested_serial"       "$expected_adb_hash" "$expected_fastboot_hash"       "$android_product" "$bootloader_product" "$fastbootd_product"; then
    rc=0
  else
    rc=$?
  fi
  TITAN2_MODE_INITIAL="$TITAN2_MODE_DETECTED"
  echo "TITAN2_FLASH_INITIAL_MODE=$TITAN2_MODE_INITIAL"

  if [[ "$rc" -ne 0 ]]; then
    echo "TITAN2_FLASH_MODE_DISCOVERY=FAIL mode=$TITAN2_MODE_INITIAL rc=$rc"
    return "$rc"
  fi
  echo "TITAN2_FLASH_MODE_DISCOVERY=PASS mode=$TITAN2_MODE_INITIAL"

  case "$TITAN2_MODE_INITIAL" in
    FASTBOOTD)
      echo "TITAN2_FLASH_MODE_TRANSITION=NONE_ALREADY_FASTBOOTD"
      ;;
    ANDROID_ADB)
      echo "TITAN2_FLASH_MODE_TRANSITION=ANDROID_ADB_TO_BOOTLOADER_FASTBOOT"
      if titan2_mode_capture "$TITAN2_MODE_COMMAND_TIMEOUT_SECONDS"           "$adb" -s "$TITAN2_MODE_ADB_SERIAL" reboot bootloader >/dev/null; then
        rc=0
      else
        rc=$?
      fi
      [[ "$rc" -eq 0 ]] || {
        echo "TITAN2_FLASH_MODE_TRANSITION=FAIL_ADB_REBOOT_BOOTLOADER rc=$rc"
        return "$rc"
      }
      REBOOTED_TO_FLASH_MODE=YES
      REBOOTED_TO_BOOTLOADER=YES
      TITAN2_MODE_TRANSITION_COUNT=$((TITAN2_MODE_TRANSITION_COUNT + 1))
      if ! titan2_wait_for_fastboot_mode           "$fastboot" "$expected_fastboot_hash"           "$bootloader_product" "$fastbootd_product"           BOOTLOADER_FASTBOOT "$TITAN2_MODE_BOOTLOADER_WAIT_SECONDS"; then
        echo "TITAN2_FLASH_MODE_TRANSITION=FAIL_BOOTLOADER_NOT_REACHED"
        return 1
      fi
      ;&
    BOOTLOADER_FASTBOOT)
      echo "TITAN2_FLASH_MODE_TRANSITION=BOOTLOADER_FASTBOOT_TO_FASTBOOTD"
      if titan2_mode_capture "$TITAN2_MODE_COMMAND_TIMEOUT_SECONDS"           "$fastboot" -s "$TITAN2_MODE_FASTBOOT_SERIAL" reboot fastboot >/dev/null; then
        rc=0
      else
        rc=$?
      fi
      [[ "$rc" -eq 0 ]] || {
        echo "TITAN2_FLASH_MODE_TRANSITION=FAIL_REBOOT_FASTBOOTD rc=$rc"
        return "$rc"
      }
      REBOOTED_TO_FLASH_MODE=YES
      TITAN2_MODE_TRANSITION_COUNT=$((TITAN2_MODE_TRANSITION_COUNT + 1))
      if ! titan2_wait_for_fastboot_mode           "$fastboot" "$expected_fastboot_hash"           "$bootloader_product" "$fastbootd_product"           FASTBOOTD "$TITAN2_MODE_FASTBOOTD_WAIT_SECONDS"; then
        echo "TITAN2_FLASH_MODE_TRANSITION=FAIL_FASTBOOTD_NOT_REACHED"
        return 1
      fi
      ;;
    RECOVERY_ADB)
      echo "TITAN2_FLASH_MODE_TRANSITION=BLOCKED_RECOVERY_MANUAL_REVIEW_REQUIRED"
      return 78
      ;;
    *)
      echo "TITAN2_FLASH_MODE_TRANSITION=BLOCKED_UNSUPPORTED_INITIAL_MODE mode=$TITAN2_MODE_INITIAL"
      return 78
      ;;
  esac

  if ! titan2_mode_find_bound_fastboot "$fastboot" "$expected_fastboot_hash"; then
    echo "TITAN2_FLASH_FINAL_MODE=FAIL_FASTBOOT_SERIAL_NOT_BOUND"
    return 1
  fi
  if ! titan2_mode_classify_fastboot       "$fastboot" "$TITAN2_MODE_FASTBOOT_SERIAL"       "$bootloader_product" "$fastbootd_product"; then
    echo "TITAN2_FLASH_FINAL_MODE=FAIL_UNCLASSIFIED_FASTBOOT"
    return 1
  fi
  [[ "$TITAN2_MODE_FASTBOOT_CLASS" == FASTBOOTD ]] || {
    echo "TITAN2_FLASH_FINAL_MODE=FAIL mode=$TITAN2_MODE_FASTBOOT_CLASS"
    return 1
  }

  TITAN2_MODE_FINAL=FASTBOOTD
  echo "TITAN2_FLASH_FINAL_MODE=FASTBOOTD"
  echo "TITAN2_FLASH_FASTBOOTD_PRODUCT=$TITAN2_MODE_FASTBOOT_PRODUCT"
  echo "TITAN2_FLASH_FASTBOOTD_IS_USERSPACE=$TITAN2_MODE_FASTBOOT_USERSPACE"
  echo "TITAN2_FLASH_MODE_TRANSITION_COUNT=$TITAN2_MODE_TRANSITION_COUNT"
  echo "TITAN2_FLASH_FASTBOOTD_READY=PASS"

  if [[ -n "$evidence_dir" && -d "$evidence_dir" ]]; then
    {
      echo "INITIAL_MODE=$TITAN2_MODE_INITIAL"
      echo "FINAL_MODE=$TITAN2_MODE_FINAL"
      echo "TRANSITION_COUNT=$TITAN2_MODE_TRANSITION_COUNT"
      echo "FASTBOOT_PRODUCT=$TITAN2_MODE_FASTBOOT_PRODUCT"
      echo "FASTBOOT_IS_USERSPACE=$TITAN2_MODE_FASTBOOT_USERSPACE"
      echo "FASTBOOT_SERIAL_SHA256=$(titan2_mode_hash_serial "$TITAN2_MODE_FASTBOOT_SERIAL")"
    } > "$evidence_dir/titan2-device-mode.env"
  fi
  return 0
}
