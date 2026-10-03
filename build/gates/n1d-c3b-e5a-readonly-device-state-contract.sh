#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DRIVER="$ROOT/build/titan2/collect-n1d-c3b-e5a-readonly-device-state.sh"

fail() {
  echo "N1D_C3B_E5A_CONTRACT_FAIL=$1" >&2
  exit 1
}

[[ -f "$DRIVER" ]] || fail missing_driver
bash -n "$DRIVER"

required=(
  '--authorize-e5a-readonly'
  '--authorize-reboot-to-fastbootd'
  'DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY_E5A'
  'ADB_READONLY_AUTHORIZED=YES'
  'FASTBOOT_READONLY_AUTHORIZED=YES'
  'REBOOT_BOOTLOADER_AUTHORIZED=YES'
  'REBOOT_FASTBOOTD_AUTHORIZED=YES'
  'FLASH_AUTHORIZED=NO'
  'ERASE_AUTHORIZED=NO'
  'FORMAT_AUTHORIZED=NO'
  'LP_MUTATION_AUTHORIZED=NO'
  'AVB_MUTATION_AUTHORIZED=NO'
  'SLOT_MUTATION_AUTHORIZED=NO'
  'UNLOCK_LOCK_AUTHORIZED=NO'
  'FACTORY_RESET_AUTHORIZED=NO'
  'CUSTOM_BOOT_AUTHORIZED=NO'
  'REBOOT_BACK_TO_ANDROID=NO_NOT_AUTHORIZED'
  'EXPECTED_STOCK_INCREMENTAL="V01.00.14"'
  'EXPECTED_SYSTEM_SHA256="998a8b99cd4d1a631006291a96c6f0160c5a4400c4bf6bba62c319c4ed3c82a5"'
  'PLANNED_SYSTEM_TARGET_BYTES="3263168512"'
  'FASTBOOTD_ALLOCATION_COMPLETE='
  'N1D_C3B_E5A_FASTBOOT_BINDING_SHA256='
  'N1D_C3B_E5A_DEVICE_BINDING_METHOD=CONTROLLED_SINGLE_DEVICE_MODE_TRANSITION'
  'N1D_C3B_E5A_READONLY_DEVICE_STATE='
)
for token in "${required[@]}"; do
  grep -Fq -- "$token" "$DRIVER" || fail "missing_token=$token"
done

grep -Fq 'bash "$ROOT/build/gates/n1d-c3b-e4-evidence-contract.sh"' "$DRIVER" ||
  fail missing_e4_evidence_gate
grep -Fq '"${ADB[@]}" reboot bootloader' "$DRIVER" ||
  fail missing_authorized_adb_reboot
grep -Fq '"${FASTBOOT[@]}" reboot fastboot' "$DRIVER" ||
  fail missing_authorized_fastbootd_reboot
grep -Fq '"${FASTBOOT[@]}" getvar "$key"' "$DRIVER" ||
  fail missing_readonly_getvar
grep -Fq 'has-slot:system' "$DRIVER" ||
  fail missing_slot_completeness_probe
grep -Fq 'allocation_complete' "$DRIVER" ||
  fail missing_allocation_completeness_gate

# Prohibited write-capable fastboot forms. Match command text, not documentation words.
if grep -En   -e '"\${FASTBOOT\[@\]}"[[:space:]]+(flash|update|boot|erase|format|flashing|oem|set_active|--set-active|resize-logical-partition|delete-logical-partition|create-logical-partition|wipe-super|snapshot-update|fetch)([[:space:]]|$)'   -e '(^|[;&|][[:space:]]*)fastboot[[:space:]]+(-s[[:space:]]+[^[:space:]]+[[:space:]]+)?(flash|update|boot|erase|format|flashing|oem|set_active|--set-active|resize-logical-partition|delete-logical-partition|create-logical-partition|wipe-super|snapshot-update|fetch)([[:space:]]|$)'   "$DRIVER"; then
  fail forbidden_fastboot_mutation
fi

# Only the explicitly authorized reboot destinations may be present as invocations.
if grep -En '"\${ADB\[@\]}"[[:space:]]+reboot([[:space:]]|$)' "$DRIVER" |
  grep -vF 'reboot bootloader'; then
  fail adb_reboot_scope
fi
if grep -En '"\${FASTBOOT\[@\]}"[[:space:]]+reboot([[:space:]]|$)' "$DRIVER" |
  grep -vF 'reboot fastboot'; then
  fail fastboot_reboot_scope
fi

# Prohibit common ADB mutation families on actual ADB-array invocations.
if grep -En   -e '"\${ADB\[@\]}"[[:space:]]+(root|remount|push|sync|install|uninstall|disable-verity|enable-verity)([[:space:]]|$)'   -e '"\${ADB\[@\]}"[[:space:]]+shell[[:space:]].*(dd[[:space:]]|setprop[[:space:]]|settings[[:space:]]+(put|delete)|pm[[:space:]]+(install|uninstall|disable|enable)|cmd[[:space:]]+package|svc[[:space:]]+power|reboot)'   "$DRIVER"; then
  fail forbidden_adb_mutation
fi

# E5A must not perform build/network/signing work.
if grep -En   -e '^[[:space:]]*(curl|wget)([[:space:]]|$)'   -e '^[[:space:]]*git[[:space:]]+(fetch|pull|clone)([[:space:]]|$)'   -e '^[[:space:]]*repo[[:space:]]+sync([[:space:]]|$)'   -e '^[[:space:]]*(m|make|ninja)[[:space:]]'   "$DRIVER"; then
  fail forbidden_host_operation
fi

echo "N1D_C3B_E5A_SHELL_SYNTAX=PASS"
echo "N1D_C3B_E5A_FASTBOOT_MUTATION_COMMANDS=PASS_ABSENT"
echo "N1D_C3B_E5A_ADB_MUTATION_COMMANDS=PASS_ABSENT"
echo "N1D_C3B_E5A_REBOOT_SCOPE=PASS_BOOTLOADER_AND_FASTBOOTD_ONLY"
echo "N1D_C3B_E5A_NETWORK_BUILD_COMMANDS=PASS_ABSENT"
echo "N1D_C3B_E5A_READONLY_DEVICE_STATE_CONTRACT=PASS"
