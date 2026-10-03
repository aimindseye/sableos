#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WRAPPER="$ROOT/build/titan2/collect-c3a-v010014-fastboot-entry-preflight.sh"
QUALIFIER="$ROOT/build/titan2/qualify-c3a-v010014-fastboot-entry-preflight.sh"
PHASE10B_COLLECTOR="$ROOT/build/titan2/collect-n1b-phase-10b-fastboot-readonly-preflight.sh"
PHASE11_COLLECTOR="$ROOT/build/titan2/collect-n1b-phase-11-fastbootd-lp-sizing.sh"

fail() {
  echo "C3A_FASTBOOT_ENTRY_PREFLIGHT_CONTRACT=FAIL reason=$*" >&2
  exit 1
}

for f in "$WRAPPER" "$QUALIFIER" "$PHASE10B_COLLECTOR" "$PHASE11_COLLECTOR"; do
  [[ -f "$f" ]] || fail "missing=$f"
  bash -n "$f" || fail "bash_n=$f"
done

bash "$ROOT/build/gates/n1b-phase-10-readonly-preflight-contract.sh" >/dev/null
bash "$ROOT/build/gates/n1b-phase-11-lp-super-sizing-contract.sh" >/dev/null

for marker in   'EXPECTED_OFFLINE_SEAL="e6ad9a20192ef7c1fcb8bf0bfc1f393afd8b9cdd7239cb19b0497512f4f8fd57"'   'EXPECTED_BASELINE_E5B_SHA256="74531923a9ea6c755a9f8ea52db511c4a4a19a5d9dba3cb51da342c04b768926"'   '--authorize-readonly-fastboot-contact'   '--authorize-fastbootd-mode-switch'   'ENTRY_STATE=FASTBOOT_OR_FASTBOOTD_FROM_N1D_BOOTLOOP'   'ADB_AUTHORIZED=NO'   'FASTBOOT_READONLY_AUTHORIZED=YES'   'FASTBOOTD_MODE_SWITCH_AUTHORIZED=YES_IF_BOOTLOADER'   'FLASH_AUTHORIZED=NO'   'FACTORY_RESET_AUTHORIZED=NO'   'LP_MUTATION_AUTHORIZED=NO'   'COW_CLEANUP_AUTHORIZED=NO'   'AVB_MUTATION_AUTHORIZED=NO'   'SLOT_MUTATION_AUTHORIZED=NO'   'REBOOT_ANDROID_AUTHORIZED=NO'   'collect-n1b-phase-10b-fastboot-readonly-preflight.sh'   '--fastboot-reboot-fastbootd-if-bootloader'   '--require-fastbootd'   'collect-n1b-phase-11-fastbootd-lp-sizing.sh'   'EXPECTED_FASTBOOT_BINDING_SHA256'   '--phase11-getvar-selected "$PHASE11_GETVAR_SELECTED"'   'qualify-c3a-v010014-fastboot-entry-preflight.sh'
do
  grep -Fq -- "$marker" "$WRAPPER" || fail "wrapper_marker_missing=$marker"
done

for marker in   '--phase11-getvar-selected PATH'   'phase11_getvar_selected:$PHASE11_GETVAR_SELECTED'   'EXPECTED_C3A_SHA256="4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16"'   'EXPECTED_C3A_BYTES=3146977280'   'EXPECTED_SLOT="a"'   'EXPECTED_PRODUCT="Titan_2"'   'EXPECTED_SUPER_BYTES=9663676416'   'EXPECTED_BASELINE_E5B_SHA256="74531923a9ea6c755a9f8ea52db511c4a4a19a5d9dba3cb51da342c04b768926"'   'FASTBOOT_DEVICE_BINDING_CHANGED'   'FASTBOOT_SERIAL_CHANGED_BETWEEN_PHASES'   'FASTBOOT_SNAPSHOT_UPDATE_STATUS_NOT_NONE'   'SYSTEM_A_NOT_REPORTED_LOGICAL'   'ACTIVE_COW_COUNT_NOT_ZERO'   'FRESH_ACTIVE_GROUP_MEMBER_SIZE_INCOMPLETE'   'ACTIVE_GROUP_CAPACITY_NOT_SAFE'   'TOTAL_SUPER_CAPACITY_NOT_SAFE'   'PASS_READY_FOR_PHYSICAL_CONTROL_REVIEW'   'C3A_FASTBOOT_ENTRY_FLASH_AUTHORIZED=NO'   'C3A_FASTBOOT_ENTRY_FACTORY_RESET_AUTHORIZED=NO'   'C3A_FASTBOOT_ENTRY_LP_MUTATION_AUTHORIZED=NO'   'C3A_FASTBOOT_ENTRY_COW_CLEANUP_AUTHORIZED=NO'   'C3A_FASTBOOT_ENTRY_AVB_MUTATION_AUTHORIZED=NO'   'C3A_FASTBOOT_ENTRY_SLOT_MUTATION_AUTHORIZED=NO'   'C3A_FASTBOOT_ENTRY_WRITE_CAPABLE_SCRIPT_CREATED=NO'
do
  grep -Fq -- "$marker" "$QUALIFIER" || fail "qualifier_marker_missing=$marker"
done

if grep -Fq -- '--adb-reboot-bootloader-if-android' "$WRAPPER"; then
  fail wrapper_must_not_enable_adb_entry
fi

if grep -En '^[[:space:]]*adb([[:space:]]|$)' "$WRAPPER" "$QUALIFIER"; then
  fail direct_adb_command_present
fi

if grep -En '^fastboot[[:space:]]+(flash|update|boot|erase|format|flashing|oem|set_active|--set-active|resize-logical-partition|delete-logical-partition|create-logical-partition|wipe-super|snapshot-update|fetch)([[:space:]]|$)' "$WRAPPER" "$QUALIFIER"; then
  fail write_fastboot_command_present
fi

if grep -En   -e '^[[:space:]]*(curl|wget|make|ninja)([[:space:]]|$)'   -e '^[[:space:]]*repo[[:space:]]+sync([[:space:]]|$)'   -e '^[[:space:]]*git[[:space:]]+(fetch|pull|clone)([[:space:]]|$)'   "$WRAPPER" "$QUALIFIER"; then
  fail forbidden_host_operation
fi

echo "C3A_FASTBOOT_ENTRY_PREFLIGHT_SCRIPT_SYNTAX=PASS"
echo "C3A_FASTBOOT_ENTRY_PREFLIGHT_SEALED_BASELINE_BINDING=PASS_STATIC"
echo "C3A_FASTBOOT_ENTRY_PREFLIGHT_FASTBOOT_ONLY_ENTRY=PASS_STATIC"
echo "C3A_FASTBOOT_ENTRY_PREFLIGHT_DEVICE_BINDING_GATE=PASS_STATIC"
echo "C3A_FASTBOOT_ENTRY_PREFLIGHT_COW_GROUP_CAPACITY_GATES=PASS_STATIC"
echo "C3A_FASTBOOT_ENTRY_PREFLIGHT_NO_WRITE_COMMANDS=PASS"
echo "C3A_FASTBOOT_ENTRY_PREFLIGHT_CONTRACT=PASS"
