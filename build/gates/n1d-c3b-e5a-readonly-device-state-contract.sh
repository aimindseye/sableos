#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COLLECTOR="$ROOT/build/titan2/collect-n1d-c3b-e5a-readonly-device-state.sh"
QUALIFIER="$ROOT/build/titan2/qualify-n1d-c3b-e5a-readonly-device-state.sh"

fail(){ echo "N1D_C3B_E5A_CONTRACT_FAIL=$1" >&2; exit 1; }

[[ -f "$COLLECTOR" ]] || fail missing_collector
[[ -f "$QUALIFIER" ]] || fail missing_qualifier
bash -n "$COLLECTOR"
bash -n "$QUALIFIER"

bash "$ROOT/build/gates/n1b-phase-10-readonly-preflight-contract.sh" >/dev/null
bash "$ROOT/build/gates/n1b-phase-11-lp-super-sizing-contract.sh" >/dev/null

required=(
'--authorize-e5a-readonly'
'--authorize-reboot-to-fastbootd'
'DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY_E5A'
'FLASH_AUTHORIZED=NO'
'ERASE_AUTHORIZED=NO'
'LP_MUTATION_AUTHORIZED=NO'
'AVB_MUTATION_AUTHORIZED=NO'
'SLOT_MUTATION_AUTHORIZED=NO'
'UNLOCK_LOCK_AUTHORIZED=NO'
'FACTORY_RESET_AUTHORIZED=NO'
'CUSTOM_BOOT_AUTHORIZED=NO'
'REBOOT_BACK_TO_ANDROID=NO_NOT_AUTHORIZED'
'--adb-reboot-bootloader-if-android'
'--fastboot-reboot-fastbootd-if-bootloader'
'--require-fastbootd'
'collect-n1b-phase-10a-adb-readonly-preflight.sh'
'collect-n1b-phase-10b-fastboot-readonly-preflight.sh'
'collect-n1b-phase-11-fastbootd-lp-sizing.sh'
'qualify-n1d-c3b-e5a-readonly-device-state.sh'
)
for token in "${required[@]}"; do
  grep -Fq -- "$token" "$COLLECTOR" || fail "collector_missing_token=$token"
done

if grep -En '^fastboot[[:space:]]+(flash|update|boot|erase|format|flashing|oem|set_active|--set-active|resize-logical-partition|delete-logical-partition|create-logical-partition|wipe-super|snapshot-update|fetch)([[:space:]]|$)' "$COLLECTOR"; then
  fail direct_fastboot_mutation_present
fi

mapfile -t direct_adb < <(grep -E '^adb[[:space:]]' "$COLLECTOR" || true)
[[ "${#direct_adb[@]}" -eq 2 ]] || fail unexpected_direct_adb_command_count
grep -Fxq 'adb -s "$DEVICE_SERIAL" shell dumpsys battery > "$EVIDENCE_DIR/adb-extra/battery.txt" 2>&1 || true' "$COLLECTOR" || fail battery_query_missing
expected_lpdump="adb -s \"\$DEVICE_SERIAL\" shell 'lpdump 2>/dev/null || true' > \"\$EVIDENCE_DIR/adb-extra/lpdump.txt\" 2>&1 || true"
grep -Fxq -- "$expected_lpdump" "$COLLECTOR" || fail lpdump_query_missing

echo "N1D_C3B_E5A_DIRECT_MUTATION_SCAN=PASS"

if grep -En \
  -e '^[[:space:]]*(curl|wget|make|ninja)([[:space:]]|$)' \
  -e '^[[:space:]]*repo[[:space:]]+sync([[:space:]]|$)' \
  -e '^[[:space:]]*git[[:space:]]+(fetch|pull|clone)([[:space:]]|$)' \
  "$COLLECTOR" "$QUALIFIER"; then
  fail forbidden_host_operation
fi
echo "N1D_C3B_E5A_HOST_OPERATION_SCAN=PASS"

if grep -En '^[[:space:]]*(adb|fastboot)[[:space:]]' "$QUALIFIER"; then
  fail qualifier_device_command_present
fi
echo "N1D_C3B_E5A_QUALIFIER_DEVICE_COMMANDS=PASS_ABSENT"

for token in \
  'N1D_C3B_E5A_FLASH_AUTHORIZED=NO' \
  'N1D_C3B_E5A_LP_MUTATION_AUTHORIZED=NO' \
  'N1D_C3B_E5A_AVB_MUTATION_AUTHORIZED=NO' \
  'N1D_C3B_E5A_SLOT_MUTATION_AUTHORIZED=NO' \
  'N1D_C3B_E5A_REBOOT_BACK_TO_ANDROID=NO_NOT_AUTHORIZED' \
  'N1D_C3B_E5A_READONLY_DEVICE_STATE='; do
  grep -Fq "$token" "$QUALIFIER" || fail "qualifier_missing_token=$token"
done

echo "N1D_C3B_E5A_READONLY_DEVICE_STATE_CONTRACT=PASS"
