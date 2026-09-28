#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
DOC="$ROOT/docs/titan2/N1B_PHASE_18_CROSS_REPO_FLASH_READINESS.md"
QUALIFIER="$ROOT/build/titan2/qualify-n1b-phase-18-cross-repo-flash-readiness.sh"

failures=0

echo "===== N1B PHASE 18 CROSS-REPO FLASH READINESS CONTRACT ====="
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

require_file "$DOC" "N1B_PHASE_18_DOC"
require_file "$QUALIFIER" "N1B_PHASE_18_QUALIFIER"

if [[ -f "$QUALIFIER" ]]; then
  if bash -n "$QUALIFIER"; then
    echo "N1B_PHASE_18_QUALIFIER_SYNTAX=PASS"
  else
    echo "N1B_PHASE_18_QUALIFIER_SYNTAX=FAIL"
    failures=$((failures + 1))
  fi
  forbidden_command_scan "$QUALIFIER" "N1B_PHASE_18_QUALIFIER_FORBIDDEN_COMMAND_SCAN"
  require_grep "N1B_PHASE_18_CROSS_REPO_FLASH_READINESS=BLOCKED_WRITE_CAPABLE_PLAN_REQUIRED" "$QUALIFIER" "N1B_PHASE_18_QUALIFIER_BLOCKED_MARKER"
  require_grep "COMMAND_OUTPUTS_EXECUTABLE_COMMANDS=NO" "$QUALIFIER" "N1B_PHASE_18_QUALIFIER_NO_COMMAND_MARKER"
  require_grep "PHASE_19_WRITE_CAPABLE_FLASH_PLAN_PR_ONLY" "$QUALIFIER" "N1B_PHASE_18_QUALIFIER_NEXT_PHASE_MARKER"
fi

if [[ -f "$DOC" ]]; then
  require_grep "BLOCKED_WRITE_CAPABLE_PLAN_REQUIRED" "$DOC" "N1B_PHASE_18_DOC_BLOCKED_MARKER"
  require_grep "sableos-project/build" "$DOC" "N1B_PHASE_18_DOC_BUILD_REPO_MARKER"
  require_grep "aimindseye/unihertz-titan2" "$DOC" "N1B_PHASE_18_DOC_TITAN2_REPO_MARKER"
  require_grep "exact command sequence must be reviewed" "$DOC" "N1B_PHASE_18_DOC_EXACT_COMMAND_REVIEW_MARKER"
  require_grep "APPROVE_PHASE_19_WRITE_CAPABLE_FLASH_PLAN_PR_ONLY=YES" "$DOC" "N1B_PHASE_18_DOC_RECOMMENDATION_MARKER"
  require_grep "AUTHORIZE_EXECUTION=NO" "$DOC" "N1B_PHASE_18_DOC_NO_EXECUTION_MARKER"
fi

if [[ -f "$QUALIFIER" ]]; then
  FIXTURE_DIR="$(mktemp -d)"
  cat > "$FIXTURE_DIR/phase17.json" <<'JSON'
{
  "status":"PASS_REVIEW_DRAFT_READY",
  "authorize_execution":"NO",
  "flash_authorized":"NO",
  "lp_mutation_authorized":"NO",
  "command_outputs_executable_commands":"NO"
}
JSON
  cat > "$FIXTURE_DIR/phase17.sh.draft" <<'EOF'
#!/usr/bin/env bash
# NON-RUNNABLE REVIEW DRAFT. DO NOT EXECUTE.
# AUTHORIZE_EXECUTION=NO
exit 97
# ACTION_INTENT_1=VERIFY_OPERATOR_INTENT_AND_STOP_CONDITIONS
EOF
  if SABLE_N1B_PHASE_18_EVIDENCE_ROOT="$FIXTURE_DIR/evidence" \
    bash "$QUALIFIER" \
      --phase17-json "$FIXTURE_DIR/phase17.json" \
      --phase17-draft-script "$FIXTURE_DIR/phase17.sh.draft" \
      > "$FIXTURE_DIR/fixture.log" 2>&1; then
    cat "$FIXTURE_DIR/fixture.log"
    if grep -Fq "N1B_PHASE_18_CROSS_REPO_FLASH_READINESS=BLOCKED_WRITE_CAPABLE_PLAN_REQUIRED" "$FIXTURE_DIR/fixture.log"; then
      echo "N1B_PHASE_18_FIXTURE_BLOCKED_RESULT=PASS"
    else
      echo "N1B_PHASE_18_FIXTURE_BLOCKED_RESULT=FAIL"
      failures=$((failures + 1))
    fi
  else
    echo "N1B_PHASE_18_FIXTURE_EXECUTION=FAIL"
    cat "$FIXTURE_DIR/fixture.log" || true
    failures=$((failures + 1))
  fi
  rm -rf "$FIXTURE_DIR"
fi

echo "===== N1B PHASE 18 CROSS-REPO FLASH READINESS CONTRACT RESULT ====="
echo "FAILURES=$failures"
if [[ "$failures" -eq 0 ]]; then
  echo "N1B_PHASE_18_CROSS_REPO_FLASH_READINESS_CONTRACT=PASS"
else
  echo "N1B_PHASE_18_CROSS_REPO_FLASH_READINESS_CONTRACT=FAIL"
  exit 1
fi
