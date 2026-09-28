#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
DOC="$ROOT/docs/titan2/TITAN2_DELIVERABLE_SOURCE_MAP.md"
failures=0

echo "===== TITAN2 DELIVERABLE SOURCE MAP CONTRACT ====="
echo "ROOT=$ROOT"
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "ADB_COMMANDS_RUN=NO"
echo "FASTBOOT_COMMANDS_RUN=NO"
echo "REBOOT_COMMANDS_RUN=NO"
echo "FLASH_AUTHORIZED=NO"
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

require_file "$DOC" "TITAN2_SOURCE_MAP_DOC"

if [[ -f "$DOC" ]]; then
  require_grep "aimindseye/unihertz-titan2" "$DOC" "TITAN2_SOURCE_MAP_UNIHERTZ_REPO"
  require_grep "sableos-project/device_sable_titan2" "$DOC" "TITAN2_SOURCE_MAP_DEVICE_REPO"
  require_grep "sableos-project/platform_sable" "$DOC" "TITAN2_SOURCE_MAP_PLATFORM_REPO"
  require_grep "sableos-project/treble_restlessos" "$DOC" "TITAN2_SOURCE_MAP_TREBLE_REPO"
  require_grep "sableos-project/platform_manifest" "$DOC" "TITAN2_SOURCE_MAP_MANIFEST_REPO"
  require_grep "sableos-project/build" "$DOC" "TITAN2_SOURCE_MAP_BUILD_REPO"
  require_grep "aimindseye/sableos" "$DOC" "TITAN2_SOURCE_MAP_INTEGRATION_REPO"

  require_grep "FASTBOOTD_SUPPORTED=YES" "$DOC" "TITAN2_SOURCE_MAP_FASTBOOTD"
  require_grep "FASTBOOT_BOOT_SUPPORTED=NO" "$DOC" "TITAN2_SOURCE_MAP_NO_FASTBOOT_BOOT"
  require_grep "DSU_AVAILABLE=NO_ON_TESTED_STOCK" "$DOC" "TITAN2_SOURCE_MAP_NO_DSU"
  require_grep "STANDALONE_RECOVERY_PARTITION_OBSERVED=NO" "$DOC" "TITAN2_SOURCE_MAP_NO_STANDALONE_RECOVERY"
  require_grep "RECOVERY_LOCATION=vendor_boot_recovery_vendor_ramdisk" "$DOC" "TITAN2_SOURCE_MAP_VENDOR_BOOT_RECOVERY"
  require_grep "AVB_CHAINED_BOOT_VBMETA_SYSTEM_VBMETA_VENDOR=YES" "$DOC" "TITAN2_SOURCE_MAP_CHAINED_AVB"
  require_grep "TITAN2_GSI_DEPLOYMENT_REQUIRES_FASTBOOTD_LP_CONTEXT=YES" "$DOC" "TITAN2_SOURCE_MAP_FASTBOOTD_LP_CONTEXT"

  require_grep "N1B_PHASE_11_LP_SUPER_SIZING=PASS_PLAN_REQUIRED" "$DOC" "TITAN2_SOURCE_MAP_PHASE11_PLAN_REQUIRED"
  require_grep "N1B_PHASE_11_SUPER_HEADROOM_ESTIMATE=PASS_CAPACITY_APPEARS_AVAILABLE_PLAN_REQUIRED" "$DOC" "TITAN2_SOURCE_MAP_SUPER_HEADROOM"
  require_grep "FLASH_AUTHORIZED=NO" "$DOC" "TITAN2_SOURCE_MAP_NO_FLASH"
  require_grep "LP_MUTATION_AUTHORIZED=NO" "$DOC" "TITAN2_SOURCE_MAP_NO_LP_MUTATION"
  require_grep "AVB_MUTATION_AUTHORIZED=NO" "$DOC" "TITAN2_SOURCE_MAP_NO_AVB_MUTATION"

  require_grep "SOURCE_MAP_REVIEWED=YES" "$DOC" "TITAN2_SOURCE_MAP_PR_CHECKLIST"
fi

echo "===== TITAN2 DELIVERABLE SOURCE MAP CONTRACT RESULT ====="
echo "FAILURES=$failures"
if [[ "$failures" -eq 0 ]]; then
  echo "TITAN2_DELIVERABLE_SOURCE_MAP_CONTRACT=PASS"
else
  echo "TITAN2_DELIVERABLE_SOURCE_MAP_CONTRACT=FAIL"
  exit 1
fi
