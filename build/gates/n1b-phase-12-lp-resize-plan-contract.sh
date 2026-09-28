#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
DOC="$ROOT/docs/titan2/N1B_PHASE_12_LP_RESIZE_PLAN.md"
DESIGNER="$ROOT/build/titan2/design-n1b-phase-12-lp-resize-plan.sh"
SOURCE_MAP="$ROOT/docs/titan2/TITAN2_DELIVERABLE_SOURCE_MAP.md"

failures=0

echo "===== N1B PHASE 12 LP RESIZE PLAN CONTRACT ====="
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
    -e '^[[:space:]]*(adb|fastboot)[[:space:]].*' \
    -e 'subprocess\..*(adb|fastboot)' \
    -e 'os\.system\(' \
    -e 'resize-logical-partition|delete-logical-partition|create-logical-partition' \
    "$path" > "$tmp"; then
    echo "$marker=FAIL"
    cat "$tmp"
    failures=$((failures + 1))
  else
    echo "$marker=PASS"
  fi

  rm -f "$tmp"
}

require_file "$SOURCE_MAP" "N1B_PHASE_12_SOURCE_MAP"
require_file "$DOC" "N1B_PHASE_12_DOC"
require_file "$DESIGNER" "N1B_PHASE_12_DESIGNER"

if [[ -f "$DESIGNER" ]]; then
  if bash -n "$DESIGNER"; then
    echo "N1B_PHASE_12_DESIGNER_SYNTAX=PASS"
  else
    echo "N1B_PHASE_12_DESIGNER_SYNTAX=FAIL"
    failures=$((failures + 1))
  fi
  forbidden_command_scan "$DESIGNER" "N1B_PHASE_12_DESIGNER_FORBIDDEN_COMMAND_SCAN"
  require_grep "SOURCE_MAP_REVIEWED=YES" "$DESIGNER" "N1B_PHASE_12_DESIGNER_SOURCE_MAP_MARKER"
  require_grep "DEVICE_CONTACT_AUTHORIZED=NO_OFFLINE_ONLY" "$DESIGNER" "N1B_PHASE_12_DESIGNER_OFFLINE_MARKER"
  require_grep "LP_MUTATION_AUTHORIZED=NO" "$DESIGNER" "N1B_PHASE_12_DESIGNER_NO_LP_MUTATION_MARKER"
  require_grep "COMMAND_OUTPUTS_EXECUTABLE_COMMANDS=NO" "$DESIGNER" "N1B_PHASE_12_DESIGNER_NO_EXECUTABLE_COMMANDS_MARKER"
  require_grep "N1B_PHASE_12_FLASH_PLAN_ALLOWED=NO" "$DESIGNER" "N1B_PHASE_12_DESIGNER_NO_FLASH_PLAN_MARKER"
fi

if [[ -f "$DOC" ]]; then
  require_grep "SOURCE_MAP_REVIEWED=YES" "$DOC" "N1B_PHASE_12_DOC_SOURCE_MAP_MARKER"
  require_grep "COMMAND_OUTPUTS_EXECUTABLE_COMMANDS=NO" "$DOC" "N1B_PHASE_12_DOC_NO_EXECUTABLE_COMMANDS_MARKER"
  require_grep "LP_MUTATION_AUTHORIZED=NO" "$DOC" "N1B_PHASE_12_DOC_NO_LP_MUTATION_MARKER"
  require_grep "TITAN2_GSI_DEPLOYMENT_REQUIRES_FASTBOOTD_LP_CONTEXT=YES" "$DOC" "N1B_PHASE_12_DOC_FASTBOOTD_CONTEXT_MARKER"
  require_grep "DO_NOT_USE_DSU_FOR_N1B_GSI=YES" "$DOC" "N1B_PHASE_12_DOC_NO_DSU_MARKER"
  require_grep "DO_NOT_USE_FASTBOOT_BOOT_FOR_N1B_GSI=YES" "$DOC" "N1B_PHASE_12_DOC_NO_FASTBOOT_BOOT_MARKER"
fi

if [[ -f "$SOURCE_MAP" ]]; then
  require_grep "Titan2 GSI deployment planning is not the same as a generic Android phone flow." "$SOURCE_MAP" "N1B_PHASE_12_SOURCE_MAP_TITAN2_NOT_GENERIC_MARKER"
  require_grep "Userspace fastbootd is required for LP/super sizing decisions." "$SOURCE_MAP" "N1B_PHASE_12_SOURCE_MAP_FASTBOOTD_MARKER"
  require_grep "LP mutation commands are not authorized by sizing gates." "$SOURCE_MAP" "N1B_PHASE_12_SOURCE_MAP_NO_LP_MUTATION_MARKER"
fi

if [[ -f "$DESIGNER" ]]; then
  fixture_dir="$(mktemp -d)"
  trap 'rm -rf "$fixture_dir"' EXIT
  cat > "$fixture_dir/phase11.json" <<'JSON'
{
  "phase": "N1B_PHASE_11_FASTBOOTD_LP_SUPER_SIZING",
  "metadata": {
    "current_slot": "a",
    "is_userspace": "yes",
    "system_current_bytes": "100",
    "super_bytes": "2000",
    "total_selected_dynamic_current_bytes": "1000",
    "super_headroom_estimate_bytes": "1000"
  }
}
JSON
  python3 - "$fixture_dir/system.img" <<'PY'
from pathlib import Path
import sys
Path(sys.argv[1]).write_bytes(b"x" * 400)
PY
  if bash "$DESIGNER" \
      --phase11-json "$fixture_dir/phase11.json" \
      --system-image "$fixture_dir/system.img" \
      --alignment-bytes 1 \
      --system-margin-bytes 0 \
      --min-remaining-super-headroom-bytes 0 \
      --evidence-dir "$fixture_dir/evidence" \
      > "$fixture_dir/designer.out" 2>&1; then
    if grep -Fq "N1B_PHASE_12_LP_RESIZE_PLAN=PASS_REVIEW_REQUIRED" "$fixture_dir/designer.out"; then
      echo "N1B_PHASE_12_DESIGNER_FIXTURE=PASS"
    else
      echo "N1B_PHASE_12_DESIGNER_FIXTURE=FAIL_UNEXPECTED_OUTPUT"
      cat "$fixture_dir/designer.out"
      failures=$((failures + 1))
    fi
  else
    echo "N1B_PHASE_12_DESIGNER_FIXTURE=FAIL_EXECUTION"
    cat "$fixture_dir/designer.out" || true
    failures=$((failures + 1))
  fi
fi

echo "===== N1B PHASE 12 LP RESIZE PLAN CONTRACT RESULT ====="
echo "FAILURES=$failures"
if [[ "$failures" -eq 0 ]]; then
  echo "N1B_PHASE_12_LP_RESIZE_PLAN_CONTRACT=PASS"
else
  echo "N1B_PHASE_12_LP_RESIZE_PLAN_CONTRACT=FAIL"
  exit 1
fi
