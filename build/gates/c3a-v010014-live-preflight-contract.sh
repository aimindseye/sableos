#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WRAPPER="$ROOT/build/titan2/collect-c3a-v010014-live-preflight.sh"
QUALIFIER="$ROOT/build/titan2/qualify-c3a-v010014-live-preflight.sh"
E5A_COLLECTOR="$ROOT/build/titan2/collect-n1d-c3b-e5a-readonly-device-state.sh"
E5A_QUALIFIER="$ROOT/build/titan2/qualify-n1d-c3b-e5a-readonly-device-state.sh"

fail() {
  echo "C3A_V010014_LIVE_PREFLIGHT_CONTRACT=FAIL reason=$*" >&2
  exit 1
}

for f in "$WRAPPER" "$QUALIFIER" "$E5A_COLLECTOR" "$E5A_QUALIFIER"; do
  [[ -f "$f" ]] || fail "missing=$f"
  bash -n "$f" || fail "bash_n=$f"
done

bash "$ROOT/build/gates/n1d-c3b-e5a-readonly-device-state-contract.sh" >/dev/null
bash "$ROOT/build/gates/n1d-c3b-e5b-authorization-package-contract.sh" >/dev/null

for marker in \
  'SABLE_E5A_SYSTEM_IMG=' \
  'SABLE_E5A_EXPECTED_SYSTEM_SHA256=' \
  'SABLE_E5A_EXPECTED_SYSTEM_BYTES='; do
  grep -Fq -- "$marker" "$E5A_COLLECTOR" || fail "parameterized_collector_missing=$marker"
done

for marker in \
  'SABLE_E5A_EXPECTED_SYSTEM_SHA256' \
  'SABLE_E5A_EXPECTED_SYSTEM_BYTES' \
  'SABLE_E5A_PLANNED_SYSTEM_TARGET_BYTES'; do
  grep -Fq -- "$marker" "$E5A_QUALIFIER" || fail "parameterized_qualifier_missing=$marker"
done

for marker in \
  'EXPECTED_OFFLINE_SEAL="e6ad9a20192ef7c1fcb8bf0bfc1f393afd8b9cdd7239cb19b0497512f4f8fd57"' \
  '--authorize-readonly-device-contact' \
  '--authorize-reboot-to-fastbootd' \
  'DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY_C3A_CONTROL' \
  'FLASH_AUTHORIZED=NO' \
  'FACTORY_RESET_AUTHORIZED=NO' \
  'LP_MUTATION_AUTHORIZED=NO' \
  'COW_CLEANUP_AUTHORIZED=NO' \
  'AVB_MUTATION_AUTHORIZED=NO' \
  'SLOT_MUTATION_AUTHORIZED=NO' \
  'REBOOT_BACK_TO_ANDROID_AUTHORIZED=NO' \
  'collect-n1d-c3b-e5a-readonly-device-state.sh' \
  'prepare-n1d-c3b-e5b-authorization-package.sh' \
  'qualify-c3a-v010014-live-preflight.sh'; do
  grep -Fq -- "$marker" "$WRAPPER" || fail "wrapper_marker_missing=$marker"
done

for marker in \
  'EXPECTED_C3A_SHA256="4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16"' \
  'EXPECTED_C3A_BYTES=3146977280' \
  'EXPECTED_STOCK_INCREMENTAL="V01.00.14"' \
  'EXPECTED_SLOT="a"' \
  'EXPECTED_PRODUCT="Titan_2"' \
  'EXPECTED_SUPER_BYTES=9663676416' \
  'FASTBOOT_DEVICE_BINDING_CHANGED' \
  'FASTBOOT_PRODUCT_MISMATCH' \
  'FASTBOOT_SNAPSHOT_UPDATE_STATUS_NOT_NONE' \
  'LOGICAL_PARTITION_INVENTORY_INCOMPLETE' \
  'SYSTEM_A_NOT_REPORTED_LOGICAL' \
  'ACTIVE_COW_COUNT_NOT_ZERO' \
  'COW_CLEANUP_WOULD_BE_REQUIRED' \
  'TARGET_NOT_SYSTEM_A' \
  'ACTIVE_GROUP_CAPACITY_NOT_SAFE' \
  'TOTAL_SUPER_CAPACITY_NOT_SAFE' \
  'PASS_READY_FOR_CONTROL_EXECUTION_REVIEW' \
  'C3A_V010014_LIVE_FLASH_AUTHORIZED=NO' \
  'C3A_V010014_LIVE_FACTORY_RESET_AUTHORIZED=NO' \
  'C3A_V010014_LIVE_WRITE_CAPABLE_SCRIPT_CREATED=NO'; do
  grep -Fq -- "$marker" "$QUALIFIER" || fail "qualifier_marker_missing=$marker"
done

if grep -En '^fastboot[[:space:]]+(flash|update|boot|erase|format|flashing|oem|set_active|--set-active|resize-logical-partition|delete-logical-partition|create-logical-partition|wipe-super|snapshot-update|fetch)([[:space:]]|$)' "$WRAPPER" "$QUALIFIER"; then
  fail write_fastboot_command_present
fi
if grep -En '^[[:space:]]*(adb|fastboot)[[:space:]]' "$QUALIFIER"; then
  fail qualifier_device_command_present
fi
if grep -En \
  -e '^[[:space:]]*(curl|wget|make|ninja)([[:space:]]|$)' \
  -e '^[[:space:]]*repo[[:space:]]+sync([[:space:]]|$)' \
  -e '^[[:space:]]*git[[:space:]]+(fetch|pull|clone)([[:space:]]|$)' \
  "$WRAPPER" "$QUALIFIER"; then
  fail forbidden_host_operation
fi

echo "C3A_V010014_LIVE_PREFLIGHT_SCRIPT_SYNTAX=PASS"
echo "C3A_V010014_LIVE_PREFLIGHT_E5A_DEFAULT_COMPATIBILITY=PASS_STATIC"
echo "C3A_V010014_LIVE_PREFLIGHT_REUSES_AUDITED_DEVICE_COLLECTOR=PASS"
echo "C3A_V010014_LIVE_PREFLIGHT_COW_GROUP_CAPACITY_GATES=PASS_STATIC"
echo "C3A_V010014_LIVE_PREFLIGHT_NO_WRITE_COMMANDS=PASS"
echo "C3A_V010014_LIVE_PREFLIGHT_CONTRACT=PASS"
