#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
QUALIFIER="$ROOT/build/titan2/qualify-n1i-c2-recovery-entry.sh"
MODE_HELPER="$ROOT/build/titan2/titan2-flash-mode.sh"
MODE_SELFTEST="$ROOT/build/titan2/tests/test-titan2-flash-mode.sh"
POSTBUILD_QUALIFIER="$ROOT/build/titan2/qualify-n1i-c2-postbuild-linkage.sh"

fail() {
  echo "N1I_C2_RECOVERY_ENTRY_CONTRACT=FAIL reason=$1" >&2
  exit 1
}

for path in "$QUALIFIER" "$MODE_HELPER" "$MODE_SELFTEST" "$POSTBUILD_QUALIFIER"; do
  [[ -f "$path" ]] || fail "required_file_missing=$path"
done

bash -n "$QUALIFIER" || fail qualifier_shell_syntax
bash -n "$MODE_HELPER" || fail mode_helper_shell_syntax
bash -n "$MODE_SELFTEST" || fail mode_selftest_shell_syntax

marker() {
  local label="$1" file="$2" value="$3"
  grep -Fq -- "$value" "$file" || fail "missing_marker=$label:$value"
  echo "N1I_C2_RECOVERY_ENTRY_CONTRACT_$label=PASS"
}

marker READONLY_DEVICE "$QUALIFIER" 'DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY_RECOVERY_STATE_ONLY'
marker ADB_READONLY "$QUALIFIER" 'ADB_READ_ONLY_AUTHORIZED=YES'
marker FASTBOOT_DISCOVERY_ONLY "$QUALIFIER" 'FASTBOOT_READ_ONLY_DISCOVERY_AUTHORIZED=YES'
marker MODE_TRANSITION_NO "$QUALIFIER" 'MODE_TRANSITION_AUTHORIZED=NO'
marker REBOOT_NO "$QUALIFIER" 'REBOOT_AUTHORIZED=NO'
marker FLASH_NO "$QUALIFIER" 'FLASH_AUTHORIZED=NO'
marker RESET_NO "$QUALIFIER" 'FACTORY_RESET_AUTHORIZED=NO'
marker SLOT_NO "$QUALIFIER" 'SLOT_CHANGE_AUTHORIZED=NO'
marker LP_NO "$QUALIFIER" 'LP_MUTATION_AUTHORIZED=NO'
marker AVB_NO "$QUALIFIER" 'AVB_MUTATION_AUTHORIZED=NO'
marker RECOVERY_REQUIRED "$QUALIFIER" '[[ "$TITAN2_MODE_DETECTED" == RECOVERY_ADB ]]'
marker RECOVERY_TRANSPORT "$QUALIFIER" '[[ "$TITAN2_MODE_ADB_TRANSPORT_STATE" == recovery ]]'
marker RECOVERY_PROPERTIES_NOT_REQUIRED "$QUALIFIER" 'N1I_C2_RECOVERY_ADB_PROPERTIES=NOT_REQUIRED_KNOWN_UNREADABLE'
marker FASTBOOT_ABSENT "$QUALIFIER" '[[ -z "$TITAN2_MODE_FASTBOOT_SERIAL" ]]'
marker BINDING "$QUALIFIER" 'EXPECTED_BINDING_SHA256="bcfdee61b23e3cb002919c27a055389ffe37e284bf5150dfc1d0bbbd7564090a"'
marker SEALED_BIND_OPTION "$QUALIFIER" '--bind-sealed-recovery'
marker SEALED_BIND_DISCOVERY "$QUALIFIER" 'titan2_mode_find_bound_adb "$SABLE_ADB" "$EXPECTED_BINDING_SHA256"'
marker SEALED_BIND_METHOD "$QUALIFIER" 'BINDING_METHOD=SEALED_HASH_MATCH_READ_ONLY_DISCOVERY'
marker BIND_MUTUAL_EXCLUSION "$QUALIFIER" 'serial_and_bound_recovery_are_mutually_exclusive'
marker HOST_AUTHORITY_FIRST "$QUALIFIER" '===== VERIFY POSTBUILD AUTHORITY ====='
marker LIVE_BIND_AFTER_AUTHORITY "$QUALIFIER" '===== BIND SEALED TITAN RECOVERY IDENTITY ====='
marker PRODUCT "$QUALIFIER" 'EXPECTED_ANDROID_PRODUCT="Titan_2"'
marker BOOTLOADER_PRODUCT "$QUALIFIER" 'EXPECTED_BOOTLOADER_PRODUCT="g71v78c2k_dfl_tee"'
marker FASTBOOTD_PRODUCT "$QUALIFIER" 'EXPECTED_FASTBOOTD_PRODUCT="Titan_2"'
marker TARGET "$QUALIFIER" 'EXPECTED_TARGET_PARTITION="system_a"'
marker SLOT "$QUALIFIER" 'EXPECTED_SLOT="a"'
marker POSTBUILD_SOURCE_READER "$QUALIFIER" 'BUILD_SOURCE_COMMIT=$BUILD_SOURCE'
marker POSTBUILD_SOURCE_WRITER "$POSTBUILD_QUALIFIER" 'BUILD_SOURCE_COMMIT=$SOURCE_COMMIT'
marker POSTBUILD_RUNTIME "$QUALIFIER" 'PASS_FULL_CLASSIFICATION_AGENTPREMAIN_8'
marker POSTBUILD_PARITY "$QUALIFIER" 'APEX_JAVA_BOOT_RUNTIME_PARITY=PASS'
marker HASH_DEFER "$QUALIFIER" 'N1I_C2_RECOVERY_ARTIFACT_HASH_RECHECK=DEFERRED_TO_FASTBOOTD_PREWRITE_GATE'
marker FINAL_PASS "$QUALIFIER" 'N1I_C2_RECOVERY_ENTRY_QUALIFICATION=PASS_RECOVERY_CONFIRMED_NO_TRANSITION'
marker REVIEW_READY "$QUALIFIER" 'N1I_C2_READY_FOR_RECOVERY_TO_FASTBOOTD_REVIEW=YES'
marker WRITE_BLOCK "$QUALIFIER" 'N1I_C2_READY_FOR_FLASH_WRITE=NO'
marker EXPLICIT_RC_SHELL "$QUALIFIER" 'set -u'

marker MODE_RECOVERY_CLASS "$MODE_HELPER" 'TITAN2_MODE_DETECTED=RECOVERY_ADB'
marker MODE_RECOVERY_TRANSPORT_AUTHORITY "$MODE_HELPER" 'TITAN2_MODE_ADB_TRANSPORT_STATE" == recovery'
marker MODE_RECOVERY_PROPERTIES_UNREADABLE "$MODE_HELPER" 'TITAN2_MODE_ADB_PROPERTIES_READABLE=NO'
marker MODE_RECOVERY_BLOCK "$MODE_HELPER" 'BLOCKED_RECOVERY_MANUAL_REVIEW_REQUIRED'

if grep -Fq -- 'set -euo pipefail' "$QUALIFIER" ||
   grep -Fq -- 'set -o pipefail' "$QUALIFIER" ||
   grep -Fq -- 'set +e' "$QUALIFIER"; then
  fail forbidden_shell_error_mode_present
fi
if grep -Eq '(^|[[:space:]])(adb|fastboot)([[:space:]]+.*)?(reboot|flash|erase|format|set_active|delete-logical-partition|create-logical-partition|resize-logical-partition)([[:space:]]|$)' "$QUALIFIER"; then
  fail mutating_transport_command_surface_present
fi
if grep -Eq '(^|[[:space:]])(make|m|mm|mmm|ninja)([[:space:]]|$)' "$QUALIFIER"; then
  fail build_command_surface_present
fi
if grep -Eq '(^|[[:space:]])(curl|wget)([[:space:]]|$)|git[[:space:]]+(fetch|pull|clone)|repo[[:space:]]+sync' "$QUALIFIER"; then
  fail network_command_surface_present
fi
if grep -Fq -- 'sha256sum "$SYSTEM_IMG"' "$QUALIFIER"; then
  fail redundant_full_image_hash_present
fi
if grep -Fq -- 'titan2_mode_adb_getprop "$SABLE_ADB"' "$QUALIFIER"; then
  fail recovery_adb_shell_probe_present
fi
if grep -Eq 'head[[:space:]]+-n[[:space:]]+1|NR[[:space:]]*==[[:space:]]*1' "$QUALIFIER"; then
  fail first_device_fallback_present
fi

authority_line="$(grep -nF '===== VERIFY POSTBUILD AUTHORITY =====' "$QUALIFIER" | cut -d: -f1)"
bind_line="$(grep -nF '===== BIND SEALED TITAN RECOVERY IDENTITY =====' "$QUALIFIER" | cut -d: -f1)"
[[ "$authority_line" =~ ^[0-9]+$ && "$bind_line" =~ ^[0-9]+$ ]] ||
  fail live_binding_order_markers_missing
[[ "$authority_line" -lt "$bind_line" ]] ||
  fail live_binding_occurs_before_host_authority

bash "$MODE_SELFTEST" >/dev/null ||
  fail mode_selftest

echo "N1I_C2_RECOVERY_ENTRY_CONTRACT=PASS"
