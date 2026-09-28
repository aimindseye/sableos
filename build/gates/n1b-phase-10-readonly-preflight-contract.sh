#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
DOC="$ROOT/docs/titan2/N1B_PHASE_10_READONLY_PREFLIGHT.md"
ADB_SCRIPT="$ROOT/build/titan2/collect-n1b-phase-10a-adb-readonly-preflight.sh"
FASTBOOT_SCRIPT="$ROOT/build/titan2/collect-n1b-phase-10b-fastboot-readonly-preflight.sh"

failures=0

echo "===== N1B PHASE 10 READ-ONLY PREFLIGHT CONTRACT ====="
echo "ROOT=$ROOT"
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO_CONTRACT_STATIC_ONLY"
echo "ADB_COMMANDS_RUN=NO"
echo "FASTBOOT_COMMANDS_RUN=NO"
echo "REBOOT_COMMANDS_RUN=NO"
echo "FLASH_AUTHORIZED=NO"
echo "FLASH_COMMANDS_RUN=NO"
echo "ERASE_COMMANDS_RUN=NO"
echo "UNLOCK_COMMANDS_RUN=NO"
echo "PUBLIC_RELEASE=NO"
echo "PRODUCTION_SIGNING=NO"

require_file() {
  local path="$1"
  local marker="$2"
  if [[ -f "$path" ]]; then
    echo "$marker=PASS"
  else
    echo "$marker=FAIL path=$path"
    failures=$((failures + 1))
  fi
}

require_grep() {
  local pattern="$1"
  local path="$2"
  local marker="$3"
  if grep -Fq "$pattern" "$path"; then
    echo "$marker=PASS"
  else
    echo "$marker=FAIL pattern=$pattern path=$path"
    failures=$((failures + 1))
  fi
}

forbidden_command_scan() {
  local path="$1"
  local marker="$2"
  local tmp
  tmp="$(mktemp)"

  if grep -En \
    -e '^[[:space:]]*(adb|fastboot)[[:space:]].*(reboot|flash|erase|format|flashing|oem|set_active|--set-active|root|remount|push|sync|install)' \
    -e '\$\{ADB\[@\]\}.*(reboot|root|remount|push|sync|install)' \
    -e '\$\{FASTBOOT\[@\]\}.*(reboot|flash|erase|format|flashing|oem|set_active|--set-active)' \
    -e 'adb shell .*(dd |setprop|settings put|cmd |pm )' \
    "$path" > "$tmp"; then
    echo "$marker=FAIL"
    cat "$tmp"
    failures=$((failures + 1))
  else
    echo "$marker=PASS"
  fi

  rm -f "$tmp"
}

require_file "$DOC" "N1B_PHASE_10_DOC"
require_file "$ADB_SCRIPT" "N1B_PHASE_10A_ADB_SCRIPT"
require_file "$FASTBOOT_SCRIPT" "N1B_PHASE_10B_FASTBOOT_SCRIPT"

if [[ -f "$ADB_SCRIPT" ]]; then
  if bash -n "$ADB_SCRIPT"; then
    echo "N1B_PHASE_10A_ADB_SCRIPT_SYNTAX=PASS"
  else
    echo "N1B_PHASE_10A_ADB_SCRIPT_SYNTAX=FAIL"
    failures=$((failures + 1))
  fi
  forbidden_command_scan "$ADB_SCRIPT" "N1B_PHASE_10A_ADB_FORBIDDEN_COMMAND_SCAN"
  require_grep "ADB_COMMANDS_AUTHORIZED=YES_READ_ONLY" "$ADB_SCRIPT" "N1B_PHASE_10A_ADB_READONLY_MARKER"
  require_grep "REBOOT_COMMANDS_RUN=NO" "$ADB_SCRIPT" "N1B_PHASE_10A_NO_REBOOT_MARKER"
  require_grep "FLASH_COMMANDS_RUN=NO" "$ADB_SCRIPT" "N1B_PHASE_10A_NO_FLASH_MARKER"
fi

if [[ -f "$FASTBOOT_SCRIPT" ]]; then
  if bash -n "$FASTBOOT_SCRIPT"; then
    echo "N1B_PHASE_10B_FASTBOOT_SCRIPT_SYNTAX=PASS"
  else
    echo "N1B_PHASE_10B_FASTBOOT_SCRIPT_SYNTAX=FAIL"
    failures=$((failures + 1))
  fi
  forbidden_command_scan "$FASTBOOT_SCRIPT" "N1B_PHASE_10B_FASTBOOT_FORBIDDEN_COMMAND_SCAN"
  require_grep "FASTBOOT_COMMANDS_AUTHORIZED=YES_READ_ONLY" "$FASTBOOT_SCRIPT" "N1B_PHASE_10B_FASTBOOT_READONLY_MARKER"
  require_grep "REBOOT_COMMANDS_RUN=NO" "$FASTBOOT_SCRIPT" "N1B_PHASE_10B_NO_REBOOT_MARKER"
  require_grep "FLASH_COMMANDS_RUN=NO" "$FASTBOOT_SCRIPT" "N1B_PHASE_10B_NO_FLASH_MARKER"
fi

if [[ -f "$DOC" ]]; then
  require_grep "10A = Android/ADB read-only metadata collection" "$DOC" "N1B_PHASE_10_DOC_10A_MARKER"
  require_grep "10B = bootloader/fastboot or fastbootd read-only metadata collection" "$DOC" "N1B_PHASE_10_DOC_10B_MARKER"
  require_grep "FLASH_AUTHORIZED=NO" "$DOC" "N1B_PHASE_10_DOC_NO_FLASH_MARKER"
  require_grep "REBOOT_AUTHORIZED=NO" "$DOC" "N1B_PHASE_10_DOC_NO_REBOOT_MARKER"
fi

echo "===== N1B PHASE 10 READ-ONLY PREFLIGHT CONTRACT RESULT ====="
echo "FAILURES=$failures"
if [[ "$failures" -eq 0 ]]; then
  echo "N1B_PHASE_10_READONLY_PREFLIGHT_CONTRACT=PASS"
else
  echo "N1B_PHASE_10_READONLY_PREFLIGHT_CONTRACT=FAIL"
  exit 1
fi
