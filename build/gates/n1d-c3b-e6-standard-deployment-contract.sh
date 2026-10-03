#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TITAN="$ROOT/build/devices/titan2.sh"
PLAN="$ROOT/build/titan2/prepare-n1d-c3b-e6-bm001-flash-plan.sh"

fail() {
  echo "N1D_C3B_E6_STANDARD_DEPLOYMENT_CONTRACT=FAIL reason=$1" >&2
  exit 1
}

for path in "$TITAN" "$PLAN"; do
  [[ -f "$path" ]] || fail "missing_file=$path"
  bash -n "$path" || fail "shell_syntax=$path"
done

TITAN_TEXT="$(cat "$TITAN")"
PLAN_TEXT="$(cat "$PLAN")"

for marker in \
  'TITAN2_N1D_E6_BUILD_SOURCE="36d5ee13f5a05b2ac19aeedf0b653a244e1eee3e"' \
  'TITAN2_N1D_E6_SYSTEM_SHA256="a048bde792636338cba4cab18301422179a7aa3322e7bd747f3218e90750502e"' \
  'TITAN2_N1D_E6_SYSTEM_CURRENT_BYTES=2994405376' \
  'TITAN2_N1D_E6_SYSTEM_LOGICAL_BYTES=2994388992' \
  'TITAN2_N1D_E6_SCOPE_PREFIX="N1D-C3B-E6-BM001:system_a:2994388992:"' \
  'TITAN2_N1D_ACTIVE_PROFILE=E6_BM001' \
  'TITAN2_N1D_ACTIVE_SYSTEM_CURRENT_BYTES="$TITAN2_N1D_E6_SYSTEM_CURRENT_BYTES"' \
  'TITAN2_N1D_ACTIVE_SYSTEM_LOGICAL_BYTES="$TITAN2_N1D_E6_SYSTEM_LOGICAL_BYTES"' \
  'prepare-n1d-c3b-e6-bm001-flash-plan.sh'
do
  [[ "$TITAN_TEXT" == *"$marker"* ]] || fail "titan_marker=$marker"
done

for marker in \
  'EXPECTED_PREFLASH_SYSTEM_BYTES=2994405376' \
  'EXPECTED_IMAGE_LOGICAL_BYTES=2994388992' \
  'N1D_C3B_E6_RUNTIME_PATCH=BM-001_REMOVE_INIT_VNDK_NODEF' \
  'N1D_C3B_E6_STANDARD_FLASH_PLAN=PREPARED_NO_WRITE' \
  'AUTOMATIC_RETRY_ALLOWED=NO' \
  'FACTORY_RESET_ALLOWED=NO'
do
  [[ "$PLAN_TEXT" == *"$marker"* ]] || fail "plan_marker=$marker"
done

# Source-only policy check. No adb/fastboot/device command is run.
# shellcheck source=/dev/null
source "$TITAN"

fake_seal="$(printf 'a%.0s' {1..64})"
scope="N1D-C3B-E6-BM001:system_a:2994388992:$fake_seal"
sable_device_flash_policy N1D "$TITAN2_N1D_E6_BUILD_SOURCE" "$scope" >/dev/null ||
  fail e6_policy_valid_scope

[[ "$TITAN2_N1D_ACTIVE_PROFILE" == E6_BM001 ]] || fail active_profile
[[ "$TITAN2_N1D_ACTIVE_SYSTEM_CURRENT_BYTES" == 2994405376 ]] || fail preflash_system_bytes
[[ "$TITAN2_N1D_ACTIVE_SYSTEM_LOGICAL_BYTES" == 2994388992 ]] || fail image_logical_bytes
[[ "$TITAN2_N1D_ACTIVE_PLAN_SEAL_SHA256" == "$fake_seal" ]] || fail plan_seal_binding

if sable_device_flash_policy N1D "$TITAN2_N1D_E6_BUILD_SOURCE"     'N1D-C3B-E6-BM001:system_a:2994388992:not-a-seal' >/dev/null 2>&1; then
  fail invalid_scope_token_accepted
fi

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

if grep -Eq '^[[:space:]]*(adb|fastboot)([[:space:]]|$)' "$PLAN"; then
  fail plan_device_command_present
fi

echo "N1D_C3B_E6_SCRIPT_SYNTAX=PASS"
echo "N1D_C3B_E6_SCOPE_TOKEN_PLAN_SEAL_BINDING=PASS"
echo "N1D_C3B_E6_PREFLASH_SYSTEM_BYTES=PASS value=2994405376"
echo "N1D_C3B_E6_IMAGE_LOGICAL_BYTES=PASS value=2994388992"
echo "N1D_C3B_E6_MUTATION_SURFACE=PASS_ONE_SYSTEM_A_FLASH_ONE_REBOOT"
echo "N1D_C3B_E6_FORBIDDEN_MUTATIONS=PASS_ABSENT"
echo "N1D_C3B_E6_STANDARD_DEPLOYMENT_CONTRACT=PASS"
