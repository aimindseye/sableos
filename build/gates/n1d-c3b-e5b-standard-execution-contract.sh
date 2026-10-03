#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
FLASH="$ROOT/build/deploy/flash.sh"
TITAN="$ROOT/build/devices/titan2.sh"

fail() {
  echo "N1D_C3B_E5B_STANDARD_EXECUTION_CONTRACT=FAIL reason=$1" >&2
  exit 1
}

for path in "$FLASH" "$TITAN"; do
  [[ -f "$path" ]] || fail "missing_file=$path"
done

bash -n "$FLASH"
bash -n "$TITAN"

FLASH_TEXT="$(cat "$FLASH")"
TITAN_TEXT="$(cat "$TITAN")"

for marker in \
  'SABLE_DEVICE_FLASH_SUPPORTED=NO' \
  'SABLE_DEVICE_PRESERVED_DATA_FLASH_SUPPORTED=NO' \
  'TITAN2_FLASH_EXECUTION_SUPPORTED=NO' \
  'TITAN2_WRITE_CAPABLE_SCRIPT_ALLOWED=NO' \
  'TITAN2_N1D_E5B_BUILD_SOURCE="caf98dde723d07a071d95aaa1ef27d578d3208d8"' \
  'TITAN2_N1D_E5B_SYSTEM_SHA256="998a8b99cd4d1a631006291a96c6f0160c5a4400c4bf6bba62c319c4ed3c82a5"' \
  'TITAN2_N1D_E5B_DECISION_SHA256="74531923a9ea6c755a9f8ea52db511c4a4a19a5d9dba3cb51da342c04b768926"' \
  'TITAN2_N1D_E5B_FREEZE_SHA256="a5df48f0e77c9372dadc1a7453f0bc265c1a01733132c0b50d4969ba2c041e3a"' \
  'TITAN2_N1D_E5B_PLAN_SEAL_SHA256="62f92bff11821979b070b5568038dbae132e6714c87b9b43016be9c5ae503d69"' \
  'TITAN2_N1D_E5B_SYSTEM_CURRENT_BYTES=757059584' \
  'TITAN2_N1D_E5B_SYSTEM_LOGICAL_BYTES=2994405376' \
  'TITAN2_N1D_E5B_SUPER_BYTES=9663676416' \
  'TITAN2_N1D_E5B_TARGET_PARTITION=system_a' \
  'TITAN2_N1D_E5B_EXPECTED_SLOT=a' \
  'TITAN2_N1D_E5B_SCOPE_TOKEN="N1D-C3B-E5B:system_a:2994405376:62f92bff11821979b070b5568038dbae132e6714c87b9b43016be9c5ae503d69"' \
  'TITAN2_STANDARD_FLASH_POLICY=BLOCKED_RELEASE' \
  'TITAN2_STANDARD_FLASH_POLICY=BLOCKED_BUILD_SOURCE' \
  'TITAN2_STANDARD_FLASH_POLICY=BLOCKED_SCOPE_TOKEN' \
  'SABLE_DEVICE_FLASH_ENTRY_MODE=fastbootd' \
  'SABLE_DEVICE_PRESERVED_DATA_BASELINE_REQUIRED=NO' \
  'SABLE_DEVICE_POSTBOOT_POLICY=adapter-observe' \
  'EXPECTED_FASTBOOT_BINDING_SHA256' \
  'EXPECTED_ADB_BINDING_SHA256' \
  'snapshot-update-status": "none"' \
  'LIVE_ACTIVE_COW_COUNT=0' \
  'TITAN2_N1D_E5B_LIVE_PREFLIGHT=PASS' \
  'TITAN2_N1D_E5B_FIRST_BOOT_OBSERVATION=RECOVERY' \
  'TITAN2_N1D_E5B_FIRST_BOOT_OBSERVATION=ANDROID_BOOT_COMPLETED' \
  'TITAN2_N1D_E5B_FACTORY_RESET=NOT_AUTHORIZED'
do
  [[ "$TITAN_TEXT" == *"$marker"* ]] || fail "titan_marker=$marker"
done

for marker in \
  '--scope-token' \
  'sable_device_flash_policy "$RELEASE" "$BUILD_SOURCE" "$SCOPE_TOKEN"' \
  'SABLE_DEVICE_FLASH_ENTRY_MODE="${SABLE_DEVICE_FLASH_ENTRY_MODE:-adb}"' \
  'SABLE_DEVICE_PRESERVED_DATA_BASELINE_REQUIRED="${SABLE_DEVICE_PRESERVED_DATA_BASELINE_REQUIRED:-YES}"' \
  'SABLE_DEVICE_POSTBOOT_POLICY="${SABLE_DEVICE_POSTBOOT_POLICY:-android-preserved-data}"' \
  'SABLE_PRE_DEVICE_BINDING=DELEGATED_FASTBOOTD_ADAPTER' \
  'SABLE_PRESERVED_DATA_BASELINE=SKIPPED_ADAPTER_POLICY' \
  'adapter-observe)'
do
  [[ "$FLASH_TEXT" == *"$marker"* ]] || fail "common_flash_marker=$marker"
done

flash_count="$(grep -Fxc '  "$FASTBOOT_BIN" -s "$SERIAL" flash system_a "$PRIMARY_PATH" </dev/null 2>&1 |' "$TITAN" || true)"
[[ "$flash_count" -eq 1 ]] || fail "system_a_flash_count=$flash_count"

reboot_count="$(grep -Fxc '  "$FASTBOOT_BIN" -s "$SERIAL" reboot </dev/null || return 1' "$TITAN" || true)"
[[ "$reboot_count" -eq 1 ]] || fail "reboot_count=$reboot_count"

if grep -Eq '(^|[[:space:]])(resize-logical-partition|delete-logical-partition|create-logical-partition|erase|format|set_active|--set-active)([[:space:]]|=|$)' "$TITAN"; then
  fail forbidden_mutation_command_present
fi

if grep -Eq '"\$FASTBOOT_BIN".*[[:space:]]flash[[:space:]]+(boot|init_boot|vendor_boot|dtbo|vbmeta|vbmeta_system|vbmeta_vendor|super|product|system_ext|vendor)([[:space:]]|$)' "$TITAN"; then
  fail forbidden_flash_target_present
fi

if grep -Eq '"\$ADB_BIN".*[[:space:]](reboot|disable-verity|enable-verity|root|remount)([[:space:]]|$)' "$TITAN"; then
  fail forbidden_adb_mutation_present
fi

if grep -Eq '(factory[[:space:]_-]*reset|wipe[[:space:]_-]*data|--wipe|-w)([[:space:]]|$)' "$TITAN"; then
  fail factory_reset_or_wipe_command_present
fi

echo "N1D_C3B_E5B_COMMON_FLASH_FASTBOOTD_MODE=PASS"
echo "N1D_C3B_E5B_PANTHER_DEFAULT_FLASH_MODE=PASS_PRESERVED"
echo "N1D_C3B_E5B_TITAN_STATIC_FAIL_CLOSED=PASS"
echo "N1D_C3B_E5B_SCOPE_TOKEN_BINDING=PASS"
echo "N1D_C3B_E5B_LIVE_SERIAL_BINDING=PASS_STATIC"
echo "N1D_C3B_E5B_LIVE_GETVAR_PREFLIGHT=PASS_STATIC"
echo "N1D_C3B_E5B_MUTATION_SURFACE=PASS_ONE_SYSTEM_A_FLASH_ONE_REBOOT"
echo "N1D_C3B_E5B_FORBIDDEN_MUTATIONS=PASS_ABSENT"
echo "N1D_C3B_E5B_STANDARD_EXECUTION_CONTRACT=PASS"
