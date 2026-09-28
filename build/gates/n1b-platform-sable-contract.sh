#!/usr/bin/env bash
#
# N1B platform_sable traceability contract gate.
#
# This gate is intentionally documentation/static only. It does not build,
# flash, contact devices, clean, clobber or mutate the workspace.

ROOT_DIR="${1:-$(pwd)}"
FAILURES=0

say() {
  printf '%s\n' "$*"
}

check_file() {
  rel="$1"
  path="$ROOT_DIR/$rel"
  if [ -f "$path" ]; then
    say "PASS file=$rel"
  else
    say "FAIL missing_file=$rel"
    FAILURES=$((FAILURES + 1))
  fi
}

check_marker() {
  rel="$1"
  marker="$2"
  path="$ROOT_DIR/$rel"
  if [ ! -f "$path" ]; then
    say "FAIL marker_file_missing=$rel marker=$marker"
    FAILURES=$((FAILURES + 1))
    return
  fi
  grep -F "$marker" "$path" >/dev/null 2>&1
  rc="$?"
  if [ "$rc" = "0" ]; then
    say "PASS marker=$marker file=$rel"
  else
    say "FAIL missing_marker=$marker file=$rel"
    FAILURES=$((FAILURES + 1))
  fi
}

say "===== N1B PLATFORM SABLE CONTRACT GATE ====="
say "ROOT_DIR=$ROOT_DIR"
say "DOCUMENTATION_STATIC_GATE=YES"
say "BUILD_AUTHORIZED=NO"
say "IMAGE_BUILD_AUTHORIZED=NO"
say "DEVICE_CONTACT_AUTHORIZED=NO"
say "FLASH_AUTHORIZED=NO"
say "ADB_COMMANDS_RUN=NO"
say "FASTBOOT_COMMANDS_RUN=NO"

check_file "docs/titan2/N1B_PLATFORM_SABLE_TRACEABILITY.md"
check_file "docs/titan2/N1B_ISSUE_INCLUSION_MATRIX.md"
check_file "docs/titan2/N1B_BETA_IMAGE_SCOPE.md"
check_file "docs/titan2/N1B_PROMOTION_SEQUENCE.md"
check_file "docs/titan2/N1B_INSTALL_WIZARD_SCOPE.md"
check_file "docs/titan2/N1B_SYSTEM_SURFACE_SCOPE.md"

check_marker "docs/titan2/N1B_PLATFORM_SABLE_TRACEABILITY.md" "N1B_PLATFORM_SABLE_TRACEABILITY=PASS"
check_marker "docs/titan2/N1B_PLATFORM_SABLE_TRACEABILITY.md" "PLATFORM_SABLE_DOCS_BOUND=YES"
check_marker "docs/titan2/N1B_PLATFORM_SABLE_TRACEABILITY.md" "DEVICE_TITAN2_GATES_BOUND=YES"
check_marker "docs/titan2/N1B_PLATFORM_SABLE_TRACEABILITY.md" "UNIHERTZ_TITAN2_RESEARCH_BOUND=YES"
check_marker "docs/titan2/N1B_PLATFORM_SABLE_TRACEABILITY.md" "ANDROID17_BASELINE_PIVOT=NO"

check_marker "docs/titan2/N1B_ISSUE_INCLUSION_MATRIX.md" "N1B_ISSUE_INCLUSION_MATRIX=PASS"
check_marker "docs/titan2/N1B_ISSUE_INCLUSION_MATRIX.md" "ALL_APPS_PERMISSION_SUMMARY_REQUIRED=YES"
check_marker "docs/titan2/N1B_ISSUE_INCLUSION_MATRIX.md" "DUPLICATE_MESSAGES_VISIBLE=NO"

check_marker "docs/titan2/N1B_BETA_IMAGE_SCOPE.md" "N1B_TITAN2_BETA_IMAGE_SCOPE=PASS"
check_marker "docs/titan2/N1B_BETA_IMAGE_SCOPE.md" "SETUP_WIZARD_FIRST_BOOT"
check_marker "docs/titan2/N1B_BETA_IMAGE_SCOPE.md" "TITAN_TOUCHPAD_DAEMON_ENABLED=NO"

check_marker "docs/titan2/N1B_PROMOTION_SEQUENCE.md" "N1B_PROMOTION_SEQUENCE=PASS"
check_marker "docs/titan2/N1B_PROMOTION_SEQUENCE.md" "N1B_SKIP_TO_IMAGE_BUILD=NO"

check_marker "docs/titan2/N1B_INSTALL_WIZARD_SCOPE.md" "N1B_INSTALL_WIZARD_SCOPE=PASS"
check_marker "docs/titan2/N1B_INSTALL_WIZARD_SCOPE.md" "PHYSICAL_KEYBOARD_VERIFICATION=PASS_REQUIRED_OR_BLOCKED_REASON"
check_marker "docs/titan2/N1B_INSTALL_WIZARD_SCOPE.md" "NO_SETUP_DEAD_ENDS=PASS_REQUIRED"

check_marker "docs/titan2/N1B_SYSTEM_SURFACE_SCOPE.md" "N1B_SYSTEM_SURFACE_SCOPE=PASS"
check_marker "docs/titan2/N1B_SYSTEM_SURFACE_SCOPE.md" "QUICK_SETTINGS_NOTIFICATION_SHADE_BOUND=YES"
check_marker "docs/titan2/N1B_SYSTEM_SURFACE_SCOPE.md" "LOCKSCREEN_SECURE_ENTRY_BOUND=YES"
check_marker "docs/titan2/N1B_SYSTEM_SURFACE_SCOPE.md" "GRAPHENEOS_BRANDING_IN_USER_UI=NO_ON_SABLE_OWNED_SURFACES"

say "FAILURES=$FAILURES"

if [ "$FAILURES" = "0" ]; then
  say "N1B_PLATFORM_SABLE_CONTRACT=PASS"
  exit 0
fi

say "N1B_PLATFORM_SABLE_CONTRACT=FAIL"
exit 1
