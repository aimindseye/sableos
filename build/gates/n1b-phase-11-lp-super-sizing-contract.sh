#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
DOC="$ROOT/docs/titan2/N1B_PHASE_11_LP_SUPER_SIZING.md"
COLLECTOR="$ROOT/build/titan2/collect-n1b-phase-11-fastbootd-lp-sizing.sh"
QUALIFIER="$ROOT/build/titan2/qualify-n1b-phase-11-lp-super-sizing.sh"

failures=0

echo "===== N1B PHASE 11 LP/SUPER SIZING CONTRACT ====="
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
echo "LP_MUTATION_AUTHORIZED=NO"
echo "AVB_MUTATION_AUTHORIZED=NO"
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
  if grep -Fq -- "$pattern" "$path"; then
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
    -e '^[[:space:]]*(adb|fastboot)[[:space:]].*(reboot|flash|erase|format|flashing|oem|set_active|--set-active|resize-logical-partition|delete-logical-partition|create-logical-partition)' \
    -e '\$\{FASTBOOT\[@\]\}.*(reboot|flash|erase|format|flashing|oem|set_active|--set-active|resize-logical-partition|delete-logical-partition|create-logical-partition)' \
    -e 'run_fastboot .* (reboot|flash|erase|format|flashing|oem|set_active|--set-active|resize-logical-partition|delete-logical-partition|create-logical-partition)' \
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

require_file "$DOC" "N1B_PHASE_11_DOC"
require_file "$COLLECTOR" "N1B_PHASE_11_COLLECTOR"
require_file "$QUALIFIER" "N1B_PHASE_11_QUALIFIER"

if [[ -f "$COLLECTOR" ]]; then
  if bash -n "$COLLECTOR"; then
    echo "N1B_PHASE_11_COLLECTOR_SYNTAX=PASS"
  else
    echo "N1B_PHASE_11_COLLECTOR_SYNTAX=FAIL"
    failures=$((failures + 1))
  fi
  forbidden_command_scan "$COLLECTOR" "N1B_PHASE_11_COLLECTOR_FORBIDDEN_COMMAND_SCAN"
  require_grep "FASTBOOT_COMMANDS_AUTHORIZED=YES_READ_ONLY_GETVAR_ONLY" "$COLLECTOR" "N1B_PHASE_11_COLLECTOR_READONLY_MARKER"
  require_grep "REBOOT_COMMANDS_RUN=NO" "$COLLECTOR" "N1B_PHASE_11_COLLECTOR_NO_REBOOT_MARKER"
  require_grep "FLASH_COMMANDS_RUN=NO" "$COLLECTOR" "N1B_PHASE_11_COLLECTOR_NO_FLASH_MARKER"
  require_grep "LP_MUTATION_AUTHORIZED=NO" "$COLLECTOR" "N1B_PHASE_11_COLLECTOR_NO_LP_MUTATION_MARKER"
fi

if [[ -f "$QUALIFIER" ]]; then
  if bash -n "$QUALIFIER"; then
    echo "N1B_PHASE_11_QUALIFIER_SYNTAX=PASS"
  else
    echo "N1B_PHASE_11_QUALIFIER_SYNTAX=FAIL"
    failures=$((failures + 1))
  fi
  forbidden_command_scan "$QUALIFIER" "N1B_PHASE_11_QUALIFIER_FORBIDDEN_COMMAND_SCAN"
  require_grep "DEVICE_CONTACT_AUTHORIZED=NO_OFFLINE_ONLY" "$QUALIFIER" "N1B_PHASE_11_QUALIFIER_OFFLINE_MARKER"
  require_grep "N1B_PHASE_11_FLASH_PLAN_ALLOWED=NO" "$QUALIFIER" "N1B_PHASE_11_QUALIFIER_NO_FLASH_PLAN_MARKER"
  require_grep "LP_MUTATION_AUTHORIZED=NO" "$QUALIFIER" "N1B_PHASE_11_QUALIFIER_NO_LP_MUTATION_MARKER"
fi

if [[ -f "$DOC" ]]; then
  require_grep "Phase 11 is a plan-only sizing gate." "$DOC" "N1B_PHASE_11_DOC_PLAN_ONLY_MARKER"
  require_grep "FASTBOOT_COMMANDS_AUTHORIZED=YES_READ_ONLY_GETVAR_ONLY" "$DOC" "N1B_PHASE_11_DOC_READONLY_MARKER"
  require_grep "FLASH_AUTHORIZED=NO" "$DOC" "N1B_PHASE_11_DOC_NO_FLASH_MARKER"
  require_grep "LP_MUTATION_AUTHORIZED=NO" "$DOC" "N1B_PHASE_11_DOC_NO_LP_MUTATION_MARKER"
  require_grep "TITAN2_DYNAMIC_PARTITIONS=YES" "$DOC" "N1B_PHASE_11_DOC_TITAN2_DYNAMIC_PARTITIONS_MARKER"
  require_grep "TITAN2_DSU_AVAILABLE=NO" "$DOC" "N1B_PHASE_11_DOC_TITAN2_NO_DSU_MARKER"
  require_grep "TITAN2_FASTBOOT_BOOT_SUPPORTED=NO" "$DOC" "N1B_PHASE_11_DOC_TITAN2_NO_FASTBOOT_BOOT_MARKER"
  require_grep "TITAN2_STANDALONE_RECOVERY_PARTITION=NO_OBSERVED" "$DOC" "N1B_PHASE_11_DOC_TITAN2_NO_STANDALONE_RECOVERY_MARKER"
  require_grep "TITAN2_GSI_DEPLOYMENT_REQUIRES_FASTBOOTD_LP_CONTEXT=YES" "$DOC" "N1B_PHASE_11_DOC_TITAN2_FASTBOOTD_LP_CONTEXT_MARKER"
  require_grep "DO_NOT_TREAT_BOOTLOADER_FASTBOOT_AS_SUFFICIENT_FOR_LP_SIZING=YES" "$DOC" "N1B_PHASE_11_DOC_BOOTLOADER_FASTBOOT_INSUFFICIENT_MARKER"
fi

echo "===== N1B PHASE 11 LP/SUPER SIZING CONTRACT RESULT ====="
echo "FAILURES=$failures"
if [[ "$failures" -eq 0 ]]; then
  echo "N1B_PHASE_11_LP_SUPER_SIZING_CONTRACT=PASS"
else
  echo "N1B_PHASE_11_LP_SUPER_SIZING_CONTRACT=FAIL"
  exit 1
fi
