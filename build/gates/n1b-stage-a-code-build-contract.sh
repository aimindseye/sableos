#!/usr/bin/env bash

# N1B Stage A code-build contract gate.
# Documentation/static contract only. Does not build apps, sync repos, contact
# devices, use adb/fastboot, or build images.

ROOT="${1:-.}"

failures=0

say() {
  printf '%s\n' "$*"
}

check_file() {
  path="$1"
  if [ ! -f "$ROOT/$path" ]; then
    say "MISSING_FILE=$path"
    failures=$((failures + 1))
  else
    say "FOUND_FILE=$path"
  fi
}

check_marker() {
  path="$1"
  marker="$2"
  if [ ! -f "$ROOT/$path" ]; then
    say "MISSING_MARKER_FILE=$path marker=$marker"
    failures=$((failures + 1))
    return
  fi

  grep -F "$marker" "$ROOT/$path" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    say "MARKER_PASS=$marker"
  else
    say "MARKER_FAIL=$marker file=$path"
    failures=$((failures + 1))
  fi
}

say "===== N1B STAGE A CODE-BUILD CONTRACT GATE ====="
say "ROOT=$ROOT"

check_file "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md"
check_file "docs/titan2/N1B_STAGE_A_MODULE_MATRIX.md"

check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "N1B_STAGE_A_CODE_BUILD_CONTRACT=YES"
check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "N1B_STAGE_A_IMAGE_BUILD=NO"
check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "N1B_STAGE_A_DEVICE_CONTACT=NO"
check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "N1B_STAGE_A_FLASH=NO"
check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "N1B_STAGE_A_PUBLIC_RELEASE=NO"

check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "1_BUILD_SABLEOS_CODE=STAGE_A"
check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "2_VALIDATE_PHYSICAL_UX=STAGE_B"
check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "3_RUN_FULL_CI=STAGE_C"
check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "4_BUILD_CODE_IMAGES=STAGE_D"
check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "N1B_SKIP_TO_IMAGE_BUILD=NO"

check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "PANTHER_TOUCH_FIRST_REFERENCE_PROTECTED=YES"
check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "KEYBOARD_FIRST_CHANGES_PROFILE_GATED=YES"
check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "COMMON_CODE_REQUIRES_TOUCH_AND_KEYBOARD_GATES=YES"
check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "TITAN2_N1B_DOES_NOT_MUTATE_PANTHER_DEFAULTS=YES"

check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "N1B_STAGE_A_MODULE_MATRIX_REQUIRED=YES"
check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "N1B_STAGE_A_MODULE_INVENTORY_REQUIRED=YES"
check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "N1B_STAGE_A_EXACT_BUILD_COMMANDS_REQUIRED=YES"

check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "SETUP_WIZARD_FIRST_BOOT=REQUIRED"
check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "CRITICAL_TEXT_ENTRY_PLUMBING=REQUIRED"
check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "SABLE_START_LAUNCHER=REQUIRED"
check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "ALL_APPS_PRIVACY_SUMMARY=REQUIRED"
check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "SABLE_HUB=REQUIRED"
check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "MESSAGES_PRODUCT_COMPOSITION=REQUIRED"
check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "SABLE_MAIL_INTEGRATION=REQUIRED"

check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "N1B_STAGE_A_CODE_BUILD=PASS"
check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "N1B_STAGE_A_SHARED_APP_BUILD=PASS"
check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "N1B_STAGE_A_PANTHER_NON_REGRESSION_BUILD=PASS"
check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "N1B_STAGE_A_TITAN2_KEYBOARD_PROFILE_BUILD=PASS"

check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "IMAGE_BUILD_AUTHORIZED=NO"
check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "DEVICE_CONTACT_AUTHORIZED=NO"
check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "FLASH_AUTHORIZED=NO"
check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "ADB_COMMANDS_RUN=NO"
check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "FASTBOOT_COMMANDS_RUN=NO"
check_marker "docs/titan2/N1B_STAGE_A_CODE_BUILD_CONTRACT.md" \
  "PUBLIC_RELEASE=NO"

check_marker "docs/titan2/N1B_STAGE_A_MODULE_MATRIX.md" \
  "N1B_STAGE_A_MODULE_MATRIX=YES"
check_marker "docs/titan2/N1B_STAGE_A_MODULE_MATRIX.md" \
  "N1B_STAGE_A_MODULE_INVENTORY_REQUIRED=YES"
check_marker "docs/titan2/N1B_STAGE_A_MODULE_MATRIX.md" \
  "Setup Wizard / First Boot"
check_marker "docs/titan2/N1B_STAGE_A_MODULE_MATRIX.md" \
  "Critical text-entry plumbing"
check_marker "docs/titan2/N1B_STAGE_A_MODULE_MATRIX.md" \
  "Sable Start / Launcher"
check_marker "docs/titan2/N1B_STAGE_A_MODULE_MATRIX.md" \
  "All Apps privacy summaries"
check_marker "docs/titan2/N1B_STAGE_A_MODULE_MATRIX.md" \
  "Sable Hub"
check_marker "docs/titan2/N1B_STAGE_A_MODULE_MATRIX.md" \
  "Messages product composition"
check_marker "docs/titan2/N1B_STAGE_A_MODULE_MATRIX.md" \
  "DOCUMENTATION_ONLY=YES"
check_marker "docs/titan2/N1B_STAGE_A_MODULE_MATRIX.md" \
  "BUILD_CODE_CHANGED=NO"

say "FAILURES=$failures"

if [ "$failures" -eq 0 ]; then
  say "N1B_STAGE_A_CODE_BUILD_CONTRACT=PASS"
  exit 0
fi

say "N1B_STAGE_A_CODE_BUILD_CONTRACT=FAIL"
exit 1
