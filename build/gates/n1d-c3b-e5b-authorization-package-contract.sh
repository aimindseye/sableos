#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/build/titan2/prepare-n1d-c3b-e5b-authorization-package.sh"
N1B_LEDGER="$ROOT/docs/titan2/N1B_FIRST_BOOT_LEDGER_AND_N1B2_HANDOFF.md"
N1C_POSTMORTEM="$ROOT/docs/titan2/N1C_FIRST_WRITE_POSTMORTEM_20260930.md"

fail() {
  echo "N1D_C3B_E5B_AUTH_PACKAGE_CONTRACT_FAIL=$1" >&2
  exit 1
}

[[ -f "$SCRIPT" ]] || fail missing_script
[[ -f "$N1B_LEDGER" ]] || fail missing_n1b_ledger
[[ -f "$N1C_POSTMORTEM" ]] || fail missing_n1c_postmortem
bash -n "$SCRIPT"

for token in \
  'DEVICE_CONTACT_AUTHORIZED=NO' \
  'ADB_COMMANDS_RUN=NO' \
  'FASTBOOT_COMMANDS_RUN=NO' \
  'FLASH_AUTHORIZED=NO' \
  'ERASE_AUTHORIZED=NO' \
  'LP_MUTATION_AUTHORIZED=NO' \
  'AVB_MUTATION_AUTHORIZED=NO' \
  'SLOT_MUTATION_AUTHORIZED=NO' \
  'FACTORY_RESET_AUTHORIZED=NO' \
  'WRITE_CAPABLE_COMMANDS_EMITTED=NO' \
  'PREVIOUS_INACTIVE_SLOT_PACKAGE=SUPERSEDED' \
  'TITAN2_PARTITION_MODEL=VIRTUAL_AB_METADATA_SLOTTED_ACTIVE_LOGICAL_MATERIALIZATION' \
  'SLOT_POLICY=KEEP_CURRENT_SLOT_NO_SLOT_SWITCH' \
  'HISTORICAL_PROVEN_PATH=N1B_ACTIVE_SYSTEM_COW_CLEANUP_RESIZE_SYSTEM_FLASH_FACTORY_RESET' \
  'N1C_WHOLE_SUPER_PATH=FLASHED_BUT_BOOT_FAILED_DO_NOT_USE_AS_PRIMARY_C3B_PATH' \
  'TARGET_SYSTEM_PARTITION=' \
  'ACTIVE_COW_COUNT=' \
  'COW_CLEANUP_POLICY=' \
  'ACTIVE_GROUP_CAPACITY_SAFE=' \
  'SUPER_CAPACITY_SAFE=' \
  'USERDATA_POLICY=EXPLICIT_FACTORY_RESET_EXPECTED_SEPARATE_AUTHORIZATION_REQUIRED'; do
  grep -Fq "$token" "$SCRIPT" || fail "missing_token=$token"
done

grep -Fq 'TARGET_PARTITION=system_a' "$N1B_LEDGER" || fail n1b_target_not_system_a
grep -Fq 'FLASH_RESULT=PASS_SYSTEM_A_WRITTEN' "$N1B_LEDGER" || fail n1b_system_write_not_proven
grep -Fq 'FACTORY_RESET_REQUIRED=YES_CONFIRMED' "$N1B_LEDGER" || fail n1b_factory_reset_lesson_missing
grep -Fq 'N1C_FIRST_WRITE_RESULT=FLASHED_BUT_BOOT_FAILED' "$N1C_POSTMORTEM" || fail n1c_whole_super_failure_missing

if grep -Fq 'PREFER_INACTIVE_SLOT' "$SCRIPT"; then
  fail inactive_slot_policy_reintroduced
fi
if grep -Fq 'READY_FOR_MANUAL_DECISION_AFTER_GROUP_AND_INACTIVE_BOOT_CHAIN_REVIEW' "$SCRIPT"; then
  fail stale_inactive_slot_state_reintroduced
fi

if grep -En \
  -e '^[[:space:]]*adb[[:space:]]' \
  -e '^[[:space:]]*fastboot[[:space:]]' \
  -e '^[[:space:]]*(curl|wget)[[:space:]]' \
  -e '^[[:space:]]*git[[:space:]]+(fetch|pull|clone)([[:space:]]|$)' \
  -e '^[[:space:]]*repo[[:space:]]+sync([[:space:]]|$)' \
  "$SCRIPT"; then
  fail forbidden_command_present
fi

if grep -En \
  -e 'resize-logical-partition' \
  -e 'delete-logical-partition' \
  -e 'create-logical-partition' \
  -e 'set_active|--set-active' \
  -e '^[[:space:]]*fastboot.*[[:space:]]flash([[:space:]]|$)' \
  "$SCRIPT"; then
  fail write_capable_instruction_present
fi

echo "N1D_C3B_E5B_AUTH_PACKAGE_SHELL_SYNTAX=PASS"
echo "N1D_C3B_E5B_HISTORICAL_N1B_BINDING=PASS_ACTIVE_SYSTEM_A"
echo "N1D_C3B_E5B_N1C_WHOLE_SUPER_NEGATIVE_BINDING=PASS"
echo "N1D_C3B_E5B_INACTIVE_SLOT_ASSUMPTION=PASS_ABSENT"
echo "N1D_C3B_E5B_AUTH_PACKAGE_DEVICE_COMMANDS=PASS_ABSENT"
echo "N1D_C3B_E5B_AUTH_PACKAGE_WRITE_COMMANDS=PASS_ABSENT"
echo "N1D_C3B_E5B_AUTH_PACKAGE_CONTRACT=PASS"
