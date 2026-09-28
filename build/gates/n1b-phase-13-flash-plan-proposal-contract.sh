#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SOURCE_MAP="$ROOT/docs/titan2/TITAN2_DELIVERABLE_SOURCE_MAP.md"
DOC="$ROOT/docs/titan2/N1B_PHASE_13_FLASH_PLAN_PROPOSAL.md"
DESIGNER="$ROOT/build/titan2/design-n1b-phase-13-flash-plan-proposal.sh"

failures=0

echo "===== N1B PHASE 13 FLASH-PLAN PROPOSAL CONTRACT ====="
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
    -e '^[[:space:]]*(adb|fastboot)[[:space:]].*(reboot|flash|erase|format|flashing|oem|set_active|--set-active|resize-logical-partition|delete-logical-partition|create-logical-partition)' \
    -e '\$\{FASTBOOT\[@\]\}.*(reboot|flash|erase|format|flashing|oem|set_active|--set-active|resize-logical-partition|delete-logical-partition|create-logical-partition)' \
    -e 'subprocess\.(run|check_call|check_output|Popen).*fastboot' \
    -e 'subprocess\.(run|check_call|check_output|Popen).*adb' \
    -e 'os\.system\(.*(fastboot|adb)' \
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

require_file "$SOURCE_MAP" "N1B_PHASE_13_SOURCE_MAP"
require_file "$DOC" "N1B_PHASE_13_DOC"
require_file "$DESIGNER" "N1B_PHASE_13_DESIGNER"

if [[ -f "$DESIGNER" ]]; then
  if bash -n "$DESIGNER"; then
    echo "N1B_PHASE_13_DESIGNER_SYNTAX=PASS"
  else
    echo "N1B_PHASE_13_DESIGNER_SYNTAX=FAIL"
    failures=$((failures + 1))
  fi
  forbidden_command_scan "$DESIGNER" "N1B_PHASE_13_DESIGNER_FORBIDDEN_COMMAND_SCAN"
  require_grep "SOURCE_MAP_REVIEWED=YES" "$DESIGNER" "N1B_PHASE_13_DESIGNER_SOURCE_MAP_MARKER"
  require_grep "DEVICE_CONTACT_AUTHORIZED=NO_OFFLINE_ONLY" "$DESIGNER" "N1B_PHASE_13_DESIGNER_OFFLINE_MARKER"
  require_grep "COMMAND_OUTPUTS_EXECUTABLE_COMMANDS=NO" "$DESIGNER" "N1B_PHASE_13_DESIGNER_NO_EXEC_COMMANDS_MARKER"
  require_grep "N1B_PHASE_13_FLASH_PLAN_ALLOWED=NO" "$DESIGNER" "N1B_PHASE_13_DESIGNER_NO_FLASH_PLAN_MARKER"
  require_grep "N1B_PHASE_13_LP_MUTATION_ALLOWED=NO" "$DESIGNER" "N1B_PHASE_13_DESIGNER_NO_LP_MUTATION_MARKER"
fi

if [[ -f "$DOC" ]]; then
  require_grep "Phase 13 is not flash execution" "$DOC" "N1B_PHASE_13_DOC_NOT_EXECUTION_MARKER"
  require_grep "DO_NOT_USE_DSU_FOR_N1B_GSI=YES" "$DOC" "N1B_PHASE_13_DOC_NO_DSU_MARKER"
  require_grep "DO_NOT_USE_FASTBOOT_BOOT_FOR_N1B_GSI=YES" "$DOC" "N1B_PHASE_13_DOC_NO_FASTBOOT_BOOT_MARKER"
  require_grep "TITAN2_GSI_DEPLOYMENT_REQUIRES_FASTBOOTD_LP_CONTEXT=YES" "$DOC" "N1B_PHASE_13_DOC_FASTBOOTD_LP_MARKER"
  require_grep "COMMAND_OUTPUTS_EXECUTABLE_COMMANDS=NO" "$DOC" "N1B_PHASE_13_DOC_NO_EXEC_COMMANDS_MARKER"
  require_grep "N1B_PHASE_13_FLASH_ALLOWED=NO" "$DOC" "N1B_PHASE_13_DOC_NO_FLASH_MARKER"
fi

if [[ -f "$SOURCE_MAP" ]]; then
  require_grep "Titan2 GSI deployment planning is not the same as a generic Android phone flow." "$SOURCE_MAP" "N1B_PHASE_13_SOURCE_MAP_TITAN2_SPECIFIC_MARKER"
  require_grep "Userspace fastbootd is required for LP/super sizing decisions." "$SOURCE_MAP" "N1B_PHASE_13_SOURCE_MAP_FASTBOOTD_MARKER"
  require_grep "LP mutation commands are not authorized by sizing gates." "$SOURCE_MAP" "N1B_PHASE_13_SOURCE_MAP_NO_LP_MUTATION_MARKER"
fi

# Fixture execution proves the designer emits a review-required proposal offline.
if [[ -f "$DESIGNER" ]]; then
  fixture_dir="$(mktemp -d)"
  trap 'rm -rf "$fixture_dir"' EXIT
  fixture_json="$fixture_dir/phase12.json"
  fixture_img="$fixture_dir/system.img"
  fixture_out="$fixture_dir/phase13.json"
  python3 - "$fixture_json" "$fixture_img" <<'PY'
from __future__ import annotations

import json
import pathlib
import sys

phase12 = pathlib.Path(sys.argv[1])
img = pathlib.Path(sys.argv[2])
img.write_bytes(b"0" * 4096)
phase12.write_text(json.dumps({
    "required_system_bytes": 3180666880,
    "system_current_bytes": 756441088,
    "system_missing_direct_bytes": 2424225792,
    "system_target_bytes": 3449815040,
    "system_growth_bytes": 2693373952,
    "super_headroom_estimate_bytes": 5510365184,
    "remaining_super_headroom_estimate_bytes": 2816991232,
    "alignment_bytes": 1048576,
    "min_remaining_super_headroom_bytes": 536870912,
    "status": "PASS_REVIEW_REQUIRED",
}, indent=2) + "\n")
PY
  SABLE_N1B_PHASE_13_EVIDENCE_ROOT="$fixture_dir/evidence" \
    bash "$DESIGNER" \
      --phase12-json "$fixture_json" \
      --system-image "$fixture_img" \
      --output-json "$fixture_out" \
      > "$fixture_dir/output.txt"
  if grep -Fq "N1B_PHASE_13_FLASH_PLAN_PROPOSAL=PASS_REVIEW_REQUIRED" "$fixture_dir/output.txt" \
    && grep -Fq "COMMAND_OUTPUTS_EXECUTABLE_COMMANDS=NO" "$fixture_dir/output.txt"; then
    echo "N1B_PHASE_13_DESIGNER_FIXTURE=PASS"
  else
    echo "N1B_PHASE_13_DESIGNER_FIXTURE=FAIL"
    cat "$fixture_dir/output.txt"
    failures=$((failures + 1))
  fi
fi

echo "===== N1B PHASE 13 FLASH-PLAN PROPOSAL CONTRACT RESULT ====="
echo "FAILURES=$failures"
if [[ "$failures" -eq 0 ]]; then
  echo "N1B_PHASE_13_FLASH_PLAN_PROPOSAL_CONTRACT=PASS"
else
  echo "N1B_PHASE_13_FLASH_PLAN_PROPOSAL_CONTRACT=FAIL"
  exit 1
fi
