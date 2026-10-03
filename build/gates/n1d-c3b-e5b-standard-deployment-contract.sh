#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ADAPTER="$ROOT/build/devices/titan2.sh"
PLAN="$ROOT/build/titan2/prepare-n1d-c3b-e5b-flash-plan.sh"
GSI_INFO="$ROOT/build/deploy/gsi_image_info.py"

fail() {
  echo "N1D_C3B_E5B_STANDARD_DEPLOYMENT_CONTRACT=FAIL reason=$1" >&2
  exit 1
}

for path in "$ADAPTER" "$PLAN" "$GSI_INFO"; do
  [[ -f "$path" ]] || fail "missing_file=$path"
done

bash -n "$ADAPTER"
bash -n "$PLAN"
PYTHONPYCACHEPREFIX="${TMPDIR:-/tmp}/sable-pycache" \
  python3 -m py_compile "$GSI_INFO"
python3 "$GSI_INFO" --self-test | grep -Fxq 'SABLE_GSI_IMAGE_INFO_SELF_TEST=PASS'

ADAPTER_TEXT="$(cat "$ADAPTER")"
PLAN_TEXT="$(cat "$PLAN")"

for marker in \
  'SABLE_DEVICE_FLASH_SUPPORTED=NO' \
  'SABLE_DEVICE_PRESERVED_DATA_FLASH_SUPPORTED=NO' \
  'TITAN2_FLASH_EXECUTION_SUPPORTED=NO' \
  'TITAN2_WRITE_CAPABLE_SCRIPT_ALLOWED=NO' \
  '|N1D|' \
  'caf98dde723d07a071d95aaa1ef27d578d3208d8' \
  '998a8b99cd4d1a631006291a96c6f0160c5a4400c4bf6bba62c319c4ed3c82a5' \
  'TITAN2_N1D_C3B_E3_ARTIFACT_GATE=PASS' \
  'TITAN2_N1D_C3B_E5B_STANDARD_FLASH_PLAN_SUPPORTED=YES' \
  'TITAN2_N1D_C3B_E5B_FLASH_EXECUTION_SUPPORTED=NO' \
  'prepare-n1d-c3b-e5b-flash-plan.sh' \
  'artifacts.e5b_decision.path' \
  'artifacts.e5b_decision.sha256' \
  'artifacts.e5b_freeze.path' \
  'artifacts.e5b_freeze.sha256'
do
  [[ "$ADAPTER_TEXT" == *"$marker"* ]] || fail "adapter_marker=$marker"
done

for marker in \
  'EXPECTED_BUILD_SOURCE="caf98dde723d07a071d95aaa1ef27d578d3208d8"' \
  'EXPECTED_SYSTEM_SHA256="998a8b99cd4d1a631006291a96c6f0160c5a4400c4bf6bba62c319c4ed3c82a5"' \
  'EXPECTED_DECISION_SHA256="74531923a9ea6c755a9f8ea52db511c4a4a19a5d9dba3cb51da342c04b768926"' \
  '--expected-auth-freeze-sha256' \
  '--registry-verified' \
  'registry_verification_required' \
  'N1D_C3B_E5B_REGISTRY_VERIFICATION=PASS_CONSUMED' \
  'TARGET_PARTITION=system_a' \
  'EXPECTED_ACTIVE_SLOT=a' \
  'FASTBOOT_IMPLICIT_RESIZE=YES' \
  'MANUAL_PRE_RESIZE_REQUIRED=NO' \
  'COW_DELETION_ALLOWED=NO' \
  'SLOT_CHANGE_ALLOWED=NO' \
  'AVB_MUTATION_ALLOWED=NO' \
  'BOOT_CHAIN_FLASH_ALLOWED=NO' \
  'WHOLE_SUPER_FLASH_ALLOWED=NO' \
  'USERDATA_ERASE_ALLOWED=NO' \
  'FACTORY_RESET_ALLOWED=NO' \
  'WRITE_CAPABLE_SCRIPT_CREATED=NO' \
  'FLASH_AUTHORIZED=NO' \
  'N1D_C3B_E5B_STANDARD_FLASH_PLAN=PASS_PREPARED_NO_WRITE'
do
  [[ "$PLAN_TEXT" == *"$marker"* ]] || fail "plan_marker=$marker"
done

if grep -Fq 'sha256sum "$SYSTEM_IMG"' "$PLAN"; then
  fail duplicate_system_hash_present
fi
if grep -Fq -- '--expected-sha256 "$EXPECTED_SYSTEM_SHA256"' "$PLAN"; then
  fail duplicate_gsi_hash_present
fi

if grep -Eq '^[[:space:]]*(sudo[[:space:]]+)?(adb|fastboot)([[:space:]]|$)' "$PLAN"; then
  fail plan_device_command_present
fi

if grep -Eq '^[[:space:]]*(sudo[[:space:]]+)?fastboot[[:space:]]+(flash|erase|format|reboot|set_active|--set-active|delete-logical-partition|resize-logical-partition|create-logical-partition)' "$PLAN"; then
  fail plan_write_command_present
fi

echo "N1D_C3B_E5B_GSI_IMAGE_INFO=PASS"
echo "N1D_C3B_E5B_STANDARD_FLASH_PLAN_SHELL_SYNTAX=PASS"
echo "N1D_C3B_E5B_STANDARD_FLASH_PLAN_DEVICE_COMMANDS=PASS_ABSENT"
echo "N1D_C3B_E5B_STANDARD_FLASH_PLAN_WRITE_COMMANDS=PASS_ABSENT"
echo "N1D_C3B_E5B_STANDARD_DEPLOYMENT_CONTRACT=PASS"
