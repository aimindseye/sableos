#!/usr/bin/env bash

REPO="${REPO:-$(pwd)}"
LEDGER="$REPO/docs/titan2/N1B_PHASE_EXECUTION_LEDGER.md"
FAILURES=0
FIRST_FAILURE=""

say() {
  printf '%s\n' "$1"
}

record_failure() {
  NAME="$1"
  DETAIL="$2"
  FAILURES=$((FAILURES + 1))
  if [ -z "$FIRST_FAILURE" ]; then
    FIRST_FAILURE="$NAME"
  fi
  say "$NAME=FAIL"
  say "$DETAIL"
}

pass() {
  say "$1=PASS"
}

require_marker() {
  NAME="$1"
  MARKER="$2"
  if grep -Fq "$MARKER" "$LEDGER" 2>/dev/null; then
    pass "$NAME"
  else
    record_failure "$NAME" "MISSING_MARKER=$MARKER"
  fi
}

say "===== N1B PHASE EXECUTION QUALIFIER ====="
say "REPO=$REPO"
say "LEDGER=$LEDGER"
say "SOURCE_MUTATION_AUTHORIZED=NO"
say "BUILD_AUTHORIZED=NO"
say "IMAGE_BUILD_AUTHORIZED=NO"
say "DEVICE_CONTACT_AUTHORIZED=NO"
say "FLASH_AUTHORIZED=NO"
say "ADB_COMMANDS_RUN=NO"
say "FASTBOOT_COMMANDS_RUN=NO"
say "PUBLIC_RELEASE=NO"

if [ ! -f "$LEDGER" ]; then
  record_failure "N1B_PHASE_EXECUTION_LEDGER" "MISSING_PATH=$LEDGER"
else
  pass "N1B_PHASE_EXECUTION_LEDGER"
fi

if [ "$FAILURES" -eq 0 ]; then
  require_marker "N1A_REGISTERED_SUBSTRATE_REQUIRED" \
    "N1A_REGISTERED_SUBSTRATE_REQUIRED=YES"
  require_marker "N1B_STACKED_PRS_REQUIRED" \
    "N1B_STACKED_PRS_REQUIRED=YES"
  require_marker "N1B_IMAGE_BUILD_LAST" \
    "N1B_IMAGE_BUILD_LAST=YES"
  require_marker "N1B_PHASE_01" \
    "N1B_PHASE_01=FAST_LANE_SDK_PREFLIGHT"
  require_marker "N1B_PHASE_03" \
    "N1B_PHASE_03=SABLE_IDENTITY_AND_APP_COMPOSITION_STATIC_GATES"
  require_marker "N1B_PHASE_05" \
    "N1B_PHASE_05=KEYBOARD_FIRST_SETUP_AND_LAUNCHER_BINDING"
  require_marker "N1B_FLASH_METADATA_REQUIRED" \
    "N1B_FLASH_REQUIRES_RESTORE_REPORT=YES"
fi

say "===== N1B PHASE EXECUTION RESULT ====="
say "FAILURES=$FAILURES"
if [ -n "$FIRST_FAILURE" ]; then
  say "FIRST_FAILURE=$FIRST_FAILURE"
fi

if [ "$FAILURES" -eq 0 ]; then
  say "N1B_PHASE_EXECUTION=PASS"
  exit 0
fi

say "N1B_PHASE_EXECUTION=FAIL"
exit 1
