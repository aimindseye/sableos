#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/build/titan2/prepare-n1d-c3b-e5b-authorization-package.sh"

fail() {
  echo "N1D_C3B_E5B_AUTH_PACKAGE_CONTRACT_FAIL=$1" >&2
  exit 1
}

[[ -f "$SCRIPT" ]] || fail missing_script
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
  'WRITE_CAPABLE_COMMANDS_EMITTED=NO' \
  'GROUP_CAPACITY_PROOF=REQUIRED_BEFORE_AUTHORIZATION' \
  'PREFER_INACTIVE_SLOT_IF_BOOT_CHAIN_AND_GROUP_CAPACITY_CONFIRMED'; do
  grep -Fq "$token" "$SCRIPT" || fail "missing_token=$token"
done

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
  -e 'flash[[:space:]]' \
  "$SCRIPT"; then
  fail write_capable_instruction_present
fi

echo "N1D_C3B_E5B_AUTH_PACKAGE_SHELL_SYNTAX=PASS"
echo "N1D_C3B_E5B_AUTH_PACKAGE_DEVICE_COMMANDS=PASS_ABSENT"
echo "N1D_C3B_E5B_AUTH_PACKAGE_WRITE_COMMANDS=PASS_ABSENT"
echo "N1D_C3B_E5B_AUTH_PACKAGE_CONTRACT=PASS"
