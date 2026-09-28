#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
DOC="$ROOT/docs/titan2/N1B_PHASE_16_EXECUTABLE_PLAN_DRAFT.md"
ASSEMBLER="$ROOT/build/titan2/assemble-n1b-phase-16-executable-plan-draft.sh"
SOURCE_MAP="$ROOT/docs/titan2/TITAN2_DELIVERABLE_SOURCE_MAP.md"

failures=0

echo "===== N1B PHASE 16 EXECUTABLE-PLAN DRAFT CONTRACT ====="
echo "ROOT=$ROOT"
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO_CONTRACT_STATIC_AND_FIXTURE_ONLY"
echo "ADB_COMMANDS_RUN=NO"
echo "FASTBOOT_COMMANDS_RUN=NO"
echo "REBOOT_COMMANDS_RUN=NO"
echo "FLASH_AUTHORIZED=NO"
echo "FLASH_COMMANDS_RUN=NO"
echo "ERASE_COMMANDS_RUN=NO"
echo "UNLOCK_COMMANDS_RUN=NO"
echo "LP_MUTATION_AUTHORIZED=NO"
echo "AVB_MUTATION_AUTHORIZED=NO"
echo "SLOT_MUTATION_AUTHORIZED=NO"
echo "COMMAND_OUTPUTS_EXECUTABLE_COMMANDS=NO"
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
    -e '^[[:space:]]*(adb|fastboot)[[:space:]].*(reboot|flash|erase|format|flashing|oem|set_active|--set-active|resize-logical-partition|delete-logical-partition|create-logical-partition|boot )' \
    -e '\$\{FASTBOOT\[@\]\}.*(reboot|flash|erase|format|flashing|oem|set_active|--set-active|resize-logical-partition|delete-logical-partition|create-logical-partition|boot )' \
    -e '\$\{ADB\[@\]\}.*(reboot|root|remount|push|sync|install|shell)' \
    -e 'subprocess\.(run|call|check_call|check_output|Popen).*\b(adb|fastboot)\b' \
    -e 'os\.system.*\b(adb|fastboot)\b' \
    -e 'resize-logical-partition' \
    -e 'delete-logical-partition' \
    -e 'create-logical-partition' \
    "$path" > "$tmp"; then
    echo "$marker=FAIL"
    cat "$tmp"
    failures=$((failures + 1))
  else
    echo "$marker=PASS"
  fi

  rm -f "$tmp"
}

require_file "$DOC" "N1B_PHASE_16_DOC"
require_file "$ASSEMBLER" "N1B_PHASE_16_ASSEMBLER"
require_file "$SOURCE_MAP" "N1B_PHASE_16_SOURCE_MAP"

if [[ -f "$ASSEMBLER" ]]; then
  if bash -n "$ASSEMBLER"; then
    echo "N1B_PHASE_16_ASSEMBLER_SYNTAX=PASS"
  else
    echo "N1B_PHASE_16_ASSEMBLER_SYNTAX=FAIL"
    failures=$((failures + 1))
  fi
  forbidden_command_scan "$ASSEMBLER" "N1B_PHASE_16_ASSEMBLER_FORBIDDEN_COMMAND_SCAN"
  require_grep "AUTHORIZE_EXECUTION=NO" "$ASSEMBLER" "N1B_PHASE_16_ASSEMBLER_NO_EXECUTION_MARKER"
  require_grep "COMMAND_OUTPUTS_EXECUTABLE_COMMANDS=NO" "$ASSEMBLER" "N1B_PHASE_16_ASSEMBLER_NO_RUNNABLE_COMMANDS_MARKER"
  require_grep "APPROVE_PHASE_16_EXECUTABLE_PLAN_DRAFT_ONLY" "$ASSEMBLER" "N1B_PHASE_16_ASSEMBLER_OWNER_AUTH_MARKER"
fi

if [[ -f "$DOC" ]]; then
  require_grep "APPROVE_PHASE_16_EXECUTABLE_PLAN_DRAFT_ONLY=YES" "$DOC" "N1B_PHASE_16_DOC_OWNER_AUTH_MARKER"
  require_grep "AUTHORIZE_EXECUTION=NO" "$DOC" "N1B_PHASE_16_DOC_NO_EXECUTION_MARKER"
  require_grep "COMMAND_OUTPUTS_EXECUTABLE_COMMANDS=NO" "$DOC" "N1B_PHASE_16_DOC_NO_RUNNABLE_COMMANDS_MARKER"
  require_grep "N1B_PHASE_16_EXECUTABLE_PLAN_DRAFT=PASS_REVIEW_DRAFT_READY" "$DOC" "N1B_PHASE_16_DOC_RESULT_MARKER"
fi

if [[ -f "$SOURCE_MAP" ]]; then
  require_grep "Titan2 GSI deployment planning is not the same as a generic Android phone flow." "$SOURCE_MAP" "N1B_PHASE_16_SOURCE_MAP_GENERIC_FLOW_MARKER"
  require_grep "Userspace fastbootd is required for LP/super sizing decisions." "$SOURCE_MAP" "N1B_PHASE_16_SOURCE_MAP_FASTBOOTD_MARKER"
fi

if [[ -f "$ASSEMBLER" ]]; then
  FIXTURE_DIR="$(mktemp -d)"
  mkdir -p "$FIXTURE_DIR/restore"
  SYSTEM_IMG="$FIXTURE_DIR/system.img"
  python3 - "$SYSTEM_IMG" <<'PY'
import pathlib
import sys
path = pathlib.Path(sys.argv[1])
path.write_bytes(b"\0" * 4096)
PY
  SYSTEM_SHA="$(sha256sum "$SYSTEM_IMG" | awk '{print $1}')"
  cat > "$FIXTURE_DIR/phase15.json" <<JSON
{
  "status":"READY_FOR_OWNER_REVIEW",
  "recommended_owner_decision":"APPROVE_PHASE_16_EXECUTABLE_PLAN_DRAFT_ONLY",
  "required_system_bytes":4096,
  "system_current_bytes":1024,
  "system_target_bytes":1048576,
  "system_growth_bytes":1047552,
  "super_headroom_estimate_bytes":4194304,
  "remaining_super_headroom_estimate_bytes":3145728
}
JSON
  cat > "$FIXTURE_DIR/phase14.json" <<'JSON'
{"final_state":"APPROVAL_READY_FOR_MANUAL_AUTHORIZATION"}
JSON
  cat > "$FIXTURE_DIR/phase13.json" <<'JSON'
{"status":"PASS_REVIEW_REQUIRED"}
JSON
  cat > "$FIXTURE_DIR/artifact.json" <<JSON
{"build_source":"0000000000000000000000000000000000000000","primary_artifact":"system","sha256":"$SYSTEM_SHA"}
JSON
  if SABLE_N1B_PHASE_16_EVIDENCE_ROOT="$FIXTURE_DIR/evidence" \
    bash "$ASSEMBLER" \
      --phase15-json "$FIXTURE_DIR/phase15.json" \
      --phase14-json "$FIXTURE_DIR/phase14.json" \
      --phase13-json "$FIXTURE_DIR/phase13.json" \
      --artifact-manifest "$FIXTURE_DIR/artifact.json" \
      --restore-report "$FIXTURE_DIR/restore" \
      --system-image "$SYSTEM_IMG" \
      > "$FIXTURE_DIR/fixture.log" 2>&1; then
    cat "$FIXTURE_DIR/fixture.log"
    if grep -Fq "N1B_PHASE_16_EXECUTABLE_PLAN_DRAFT=PASS_REVIEW_DRAFT_READY" "$FIXTURE_DIR/fixture.log"; then
      echo "N1B_PHASE_16_FIXTURE_READY_RESULT=PASS"
    else
      echo "N1B_PHASE_16_FIXTURE_READY_RESULT=FAIL"
      failures=$((failures + 1))
    fi
    if grep -Fq "COMMAND_OUTPUTS_EXECUTABLE_COMMANDS=NO" "$FIXTURE_DIR/fixture.log"; then
      echo "N1B_PHASE_16_FIXTURE_NO_RUNNABLE_COMMANDS=PASS"
    else
      echo "N1B_PHASE_16_FIXTURE_NO_RUNNABLE_COMMANDS=FAIL"
      failures=$((failures + 1))
    fi
  else
    echo "N1B_PHASE_16_FIXTURE_EXECUTION=FAIL"
    cat "$FIXTURE_DIR/fixture.log" || true
    failures=$((failures + 1))
  fi
  rm -rf "$FIXTURE_DIR"
fi

echo "===== N1B PHASE 16 EXECUTABLE-PLAN DRAFT CONTRACT RESULT ====="
echo "FAILURES=$failures"
if [[ "$failures" -eq 0 ]]; then
  echo "N1B_PHASE_16_EXECUTABLE_PLAN_DRAFT_CONTRACT=PASS"
else
  echo "N1B_PHASE_16_EXECUTABLE_PLAN_DRAFT_CONTRACT=FAIL"
  exit 1
fi
