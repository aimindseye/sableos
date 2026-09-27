#!/usr/bin/env bash
#
# Sable build methodology contract gate.
#
# This gate verifies the shared state-output helper and build methodology
# documentation exist and preserve the common cross-device build contract.
#
# It is intentionally lightweight by default. Set
# SABLE_STRICT_SCRIPT_COLOR_AUDIT=1 to fail if build shell scripts do not source
# the shared state helper.

ROOT="${SABLE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
EVIDENCE="${EVIDENCE_DIR:-${ROOT}/out/sable-build-methodology-contract}"
RESULT_FILE="${EVIDENCE}/99-build-methodology-contract-result.txt"

mkdir -p "$EVIDENCE"
: > "$RESULT_FILE"

# shellcheck source=/dev/null
if [ -f "$ROOT/build/lib/sable-state.sh" ]; then
  . "$ROOT/build/lib/sable-state.sh"
else
  printf 'FAIL  STATE_OUTPUT_HELPER=FAIL\n'
  printf 'STATE_OUTPUT_HELPER=FAIL\n' >> "$RESULT_FILE"
  printf 'SABLE_BUILD_METHODOLOGY_CONTRACT=FAIL\n' >> "$RESULT_FILE"
  exit 1
fi

sable_section "SABLE BUILD METHODOLOGY CONTRACT"
sable_record_and_emit "$RESULT_FILE" INFO "SABLE_BUILD_METHODOLOGY_CONTRACT" "START"
sable_record_and_emit "$RESULT_FILE" GATE "APPLIES_TO" "all_devices"
sable_record_and_emit "$RESULT_FILE" GATE "BUILD_PRODUCT_CODE_CHANGED" "NO"
sable_record_and_emit "$RESULT_FILE" GATE "DEVICE_CODE_CHANGED" "NO"
sable_record_and_emit "$RESULT_FILE" GATE "FLASH_ENABLEMENT" "NO"

FAIL_COUNT=0
WARN_COUNT=0

check_file() {
  check_path="$1"
  check_key="$2"

  if [ -f "$ROOT/$check_path" ]; then
    sable_record_and_emit "$RESULT_FILE" PASS "$check_key" "PASS"
  else
    sable_record_and_emit "$RESULT_FILE" FAIL "$check_key" "FAIL"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

check_contains() {
  check_path="$1"
  check_pattern="$2"
  check_key="$3"

  if grep -q "$check_pattern" "$ROOT/$check_path" 2>/dev/null; then
    sable_record_and_emit "$RESULT_FILE" PASS "$check_key" "PASS"
  else
    sable_record_and_emit "$RESULT_FILE" FAIL "$check_key" "FAIL"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

check_file "build/lib/sable-state.sh" "STATE_OUTPUT_HELPER_FILE"
check_file "docs/SABLE_BUILD_METHODOLOGY.md" "SABLE_BUILD_METHODOLOGY_DOC"

check_contains "build/lib/sable-state.sh" "NO_COLOR" "NO_COLOR_SUPPORTED"
check_contains "build/lib/sable-state.sh" "SABLE_COLOR" "SABLE_COLOR_SUPPORTED"
check_contains "build/lib/sable-state.sh" "sable_state_pass" "STATE_PASS_HELPER"
check_contains "build/lib/sable-state.sh" "sable_record_and_emit" "STATE_RECORD_AND_EMIT_HELPER"
check_contains "docs/SABLE_BUILD_METHODOLOGY.md" "ONE_METHOD_ALL_DEVICES=YES" "ONE_METHOD_ALL_DEVICES"
check_contains "docs/SABLE_BUILD_METHODOLOGY.md" "COLOR_CODED_STATE_OUTPUT=REQUIRED" "COLOR_CODED_STATE_OUTPUT_REQUIRED"
check_contains "docs/SABLE_BUILD_METHODOLOGY.md" "MACHINE_READABLE_KEY_VALUE_OUTPUT=REQUIRED" "MACHINE_READABLE_KEY_VALUE_REQUIRED"
check_contains "docs/SABLE_BUILD_METHODOLOGY.md" "TMUX_DRIVER_SET_E_STRICT_MODE=NO" "TMUX_DRIVER_STRICT_MODE_RULE"
check_contains "docs/SABLE_BUILD_METHODOLOGY.md" "DEVICE_SPECIFIC_METHOD_FORKS=NO" "DEVICE_SPECIFIC_METHOD_FORKS_BLOCKED"

sable_section "OPTIONAL SCRIPT COLOR AUDIT"

MISSING_HELPER_LIST="$EVIDENCE/scripts-missing-sable-state-helper.txt"
: > "$MISSING_HELPER_LIST"

find "$ROOT/build" \
  -type f \
  \( -name '*.sh' -o -name '*.bash' \) \
  ! -path "$ROOT/build/lib/sable-state.sh" \
  ! -path "$ROOT/build/gates/sable-build-methodology-contract.sh" \
  -print \
  | sort \
  | while read -r script_path; do
      if ! grep -q 'sable-state.sh' "$script_path"; then
        printf '%s\n' "${script_path#$ROOT/}" >> "$MISSING_HELPER_LIST"
      fi
    done

MISSING_COUNT=$(wc -l < "$MISSING_HELPER_LIST" | tr -d ' ')
sable_record_and_emit "$RESULT_FILE" INFO "SCRIPT_COLOR_HELPER_MISSING_COUNT" "$MISSING_COUNT"

if [ "$MISSING_COUNT" != "0" ]; then
  if [ "${SABLE_STRICT_SCRIPT_COLOR_AUDIT:-0}" = "1" ]; then
    sable_record_and_emit "$RESULT_FILE" FAIL "SCRIPT_COLOR_HELPER_STRICT_AUDIT" "FAIL"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  else
    sable_record_and_emit "$RESULT_FILE" WARN "SCRIPT_COLOR_HELPER_STRICT_AUDIT" "WARN_DEFERRED_MIGRATION"
    WARN_COUNT=$((WARN_COUNT + 1))
  fi
else
  sable_record_and_emit "$RESULT_FILE" PASS "SCRIPT_COLOR_HELPER_AUDIT" "PASS"
fi

sable_section "FINAL RESULT"
sable_record_state "$RESULT_FILE" "FAIL_COUNT" "$FAIL_COUNT"
sable_record_state "$RESULT_FILE" "WARN_COUNT" "$WARN_COUNT"
sable_record_state "$RESULT_FILE" "EVIDENCE" "$EVIDENCE"

if [ "$FAIL_COUNT" = "0" ]; then
  sable_record_and_emit "$RESULT_FILE" PASS "SABLE_BUILD_METHODOLOGY_CONTRACT" "PASS"
  sable_record_and_emit "$RESULT_FILE" NEXT "NEXT_ACTION" "source shared state helper from new build and CI scripts"
else
  sable_record_and_emit "$RESULT_FILE" FAIL "SABLE_BUILD_METHODOLOGY_CONTRACT" "FAIL"
  sable_record_and_emit "$RESULT_FILE" NEXT "NEXT_ACTION" "fix build methodology contract failures"
fi

cat "$RESULT_FILE"

if [ "$FAIL_COUNT" = "0" ]; then
  exit 0
fi

exit 1
