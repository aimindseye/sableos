#!/usr/bin/env bash

ROOT_DIR="${1:-.}"

FAILURES=0

say() {
  printf '%s\n' "$*"
}

pass() {
  say "$1=PASS"
}

fail() {
  say "$1=FAIL"
  FAILURES=$((FAILURES + 1))
}

require_file() {
  local label="$1"
  local path="$2"

  if [ -f "$ROOT_DIR/$path" ]; then
    pass "$label"
  else
    fail "$label"
    say "missing_path=$path"
  fi
}

require_marker() {
  local label="$1"
  local path="$2"
  local marker="$3"

  if [ ! -f "$ROOT_DIR/$path" ]; then
    fail "$label"
    say "missing_path=$path"
    return
  fi

  grep -F "$marker" "$ROOT_DIR/$path" >/dev/null 2>&1
  RC=$?
  if [ "$RC" -eq 0 ]; then
    pass "$label"
  else
    fail "$label"
    say "missing_marker=$marker"
    say "in_path=$path"
  fi
}

say "===== SABLE MULTI-PROFILE CONTRACT GATE ====="
say "ROOT_DIR=$ROOT_DIR"
say "DOCUMENTATION_ONLY=YES"
say "BUILD_CODE_CHANGED=NO"
say "DEVICE_CODE_CHANGED=NO"
say "IMAGE_BUILD_AUTHORIZED=NO"
say "DEVICE_CONTACT_AUTHORIZED=NO"
say "FLASH_AUTHORIZED=NO"
say "ADB_COMMANDS_RUN=NO"
say "FASTBOOT_COMMANDS_RUN=NO"
say "PUBLIC_RELEASE=NO"

PANTHER_DOC="docs/panther/PANTHER_TOUCH_FIRST_NON_REGRESSION.md"
TITAN_DOC="docs/titan2/N1B_MULTI_PROFILE_NON_REGRESSION.md"

require_file "PANTHER_TOUCH_FIRST_DOC_PRESENT" "$PANTHER_DOC"
require_file "N1B_MULTI_PROFILE_DOC_PRESENT" "$TITAN_DOC"

require_marker \
  "PANTHER_TOUCH_FIRST_REFERENCE_PROTECTED_MARKER" \
  "$PANTHER_DOC" \
  "PANTHER_TOUCH_FIRST_REFERENCE_PROTECTED=YES"

require_marker \
  "KEYBOARD_FIRST_DEFAULTS_DISABLED_ON_PANTHER_MARKER" \
  "$PANTHER_DOC" \
  "KEYBOARD_FIRST_DEFAULTS_DISABLED_ON_PANTHER=YES"

require_marker \
  "TITAN2_N1B_DOES_NOT_MUTATE_PANTHER_DEFAULTS_MARKER" \
  "$PANTHER_DOC" \
  "TITAN2_N1B_DOES_NOT_MUTATE_PANTHER_DEFAULTS=YES"

require_marker \
  "COMMON_CODE_REQUIRES_TOUCH_AND_KEYBOARD_GATES_PANTHER_MARKER" \
  "$PANTHER_DOC" \
  "COMMON_CODE_REQUIRES_TOUCH_AND_KEYBOARD_GATES=YES"

require_marker \
  "PUBLIC_BUILD_PATH_FAIL_CLOSED_PANTHER_MARKER" \
  "$PANTHER_DOC" \
  "PUBLIC_BUILD_PATH_FAIL_CLOSED=YES"

require_marker \
  "N1B_MULTI_PROFILE_NON_REGRESSION_MARKER" \
  "$TITAN_DOC" \
  "N1B_MULTI_PROFILE_NON_REGRESSION=YES"

require_marker \
  "KEYBOARD_FIRST_CHANGES_PROFILE_GATED_MARKER" \
  "$TITAN_DOC" \
  "KEYBOARD_FIRST_CHANGES_PROFILE_GATED=YES"

require_marker \
  "COMMON_CODE_REQUIRES_TOUCH_AND_KEYBOARD_GATES_TITAN_MARKER" \
  "$TITAN_DOC" \
  "COMMON_CODE_REQUIRES_TOUCH_AND_KEYBOARD_GATES=YES"

require_marker \
  "IMAGE_BUILD_BLOCKED_UNTIL_CODE_PHYSICAL_CI_PASS_MARKER" \
  "$TITAN_DOC" \
  "IMAGE_BUILD_BLOCKED_UNTIL_CODE_PHYSICAL_CI_PASS=YES"

require_marker \
  "PUBLIC_BUILD_PATH_FAIL_CLOSED_TITAN_MARKER" \
  "$TITAN_DOC" \
  "PUBLIC_BUILD_PATH_FAIL_CLOSED=YES"

if [ "$FAILURES" -eq 0 ]; then
  say "FAILURES=0"
  say "SABLE_MULTI_PROFILE_CONTRACT=PASS"
  exit 0
fi

say "FAILURES=$FAILURES"
say "SABLE_MULTI_PROFILE_CONTRACT=FAIL"
exit 1
