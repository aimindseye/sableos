#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PREP="$ROOT/build/titan2/prepare-n1b-v010014-control.sh"
DOC="$ROOT/docs/titan2/N1B_V010014_CONTROL.md"
LEDGER="$ROOT/docs/titan2/N1B_FIRST_BOOT_LEDGER_AND_N1B2_HANDOFF.md"

fail() {
  echo "N1B_V010014_CONTROL_CONTRACT=FAIL reason=$*" >&2
  exit 1
}

for f in "$PREP" "$DOC" "$LEDGER"; do
  [[ -f "$f" ]] || fail "missing_file=$f"
done

bash -n "$PREP" || fail "bash_n=$PREP"

for marker in \
  'EXPECTED_N1B_SOURCE="8dd06e77410fea131e4716447f7f05067e427654"' \
  'EXPECTED_N1B_SHA256="bc550bfaf8463324c122abb490cf4aba956b89e7e4d42168a55f0f0f0f5b638e"' \
  'EXPECTED_N1B_BYTES=3180666880' \
  'EXPECTED_E5B_SHA256="74531923a9ea6c755a9f8ea52db511c4a4a19a5d9dba3cb51da342c04b768926"' \
  'EXPECTED_CURRENT_INCREMENTAL="V01.00.14"' \
  'EXPECTED_SLOT="a"' \
  'EXPECTED_FASTBOOT_PRODUCT="Titan_2"' \
  'EXPECTED_SUPER_BYTES=9663676416' \
  'MINIMUM_REMAINING_HEADROOM_BYTES=536870912'
do
  grep -Fq -- "$marker" "$PREP" || fail "prep_marker_missing=$marker"
done

for marker in \
  'SOURCE_COMMIT=8dd06e77410fea131e4716447f7f05067e427654' \
  'SYSTEM_SHA256=bc550bfaf8463324c122abb490cf4aba956b89e7e4d42168a55f0f0f0f5b638e' \
  'SYSTEM_BYTES=3180666880' \
  'TARGET_PARTITION=system_a' \
  'FIRST_N1B_BOOT=PASS'
do
  grep -Fq -- "$marker" "$LEDGER" || fail "ledger_marker_missing=$marker"
done

if grep -Eq '^[[:space:]]*(adb|fastboot)([[:space:]]|$)|"\$[^" ]*(ADB|FASTBOOT)[^" ]*"[[:space:]]+-s' "$PREP"; then
  fail device_command_present
fi

for marker in \
  'DEVICE_CONTACT_AUTHORIZED=NO' \
  'FLASH_AUTHORIZED=NO' \
  'FACTORY_RESET_AUTHORIZED=NO' \
  'N1E_BUILD_AUTHORIZED=NO' \
  'LIVE_PREFLIGHT_REQUIRED=YES' \
  'LIVE_REQUIRE_ACTIVE_COW_COUNT=0' \
  'MANUAL_PRE_RESIZE_ALLOWED=NO' \
  'COW_DELETION_ALLOWED=NO' \
  'SLOT_CHANGE_ALLOWED=NO' \
  'AVB_MUTATION_ALLOWED=NO' \
  'BOOT_CHAIN_FLASH_ALLOWED=NO' \
  'WHOLE_SUPER_FLASH_ALLOWED=NO' \
  'RECOVERY_RESULT_REQUIRES_SEPARATE_FACTORY_RESET_AUTHORIZATION=YES' \
  'WRITE_CAPABLE_SCRIPT_CREATED=NO'
do
  grep -Fq -- "$marker" "$PREP" || fail "safety_marker_missing=$marker"
done

grep -Fq 'e5a_source_json_sha256' "$PREP" || fail e5a_e5b_binding_missing
grep -Fq '[[ "$e5b_sha" == "$EXPECTED_E5B_SHA256" ]]' "$PREP" || fail e5b_hash_gate_missing
grep -Fq '[[ "$actual_sha" == "$EXPECTED_N1B_SHA256" ]]' "$PREP" || fail n1b_hash_gate_missing
grep -Fq '[[ "$actual_bytes" == "$EXPECTED_N1B_BYTES" ]]' "$PREP" || fail n1b_size_gate_missing
grep -Fq 'GSI_IMAGE_LOGICAL_BYTES=$EXPECTED_N1B_BYTES' "$PREP" || fail n1b_geometry_gate_missing
grep -Fq '! -name prepare.log' "$PREP" || fail live_prepare_log_must_be_excluded_from_seal

if grep -Eq '^[[:space:]]*(repo[[:space:]]+sync|make[[:space:]]|m[[:space:]]|ninja[[:space:]]|fastboot[[:space:]]+(flash|erase|delete-logical-partition|resize-logical-partition)|adb[[:space:]]+reboot)' "$PREP"; then
  fail mutation_command_present
fi

for marker in \
  'Status: **offline qualification package / no device contact / no mutation**' \
  'N1B_V010014_CONTROL=NEXT_PHYSICAL_CONTROL_AFTER_REVIEW' \
  'N1E_BUILD_AUTHORIZED=NO_PENDING_N1B_CONTROL' \
  'COUNT_ZERO_STATUS=PRIMARY_SUSPECT_NOT_PROVEN_ROOT_CAUSE'
do
  grep -Fq -- "$marker" "$DOC" || fail "doc_marker_missing=$marker"
done

echo "N1B_V010014_CONTROL_SCRIPT_SYNTAX=PASS"
echo "N1B_V010014_CONTROL_HISTORICAL_BINDING=PASS"
echo "N1B_V010014_CONTROL_E5A_E5B_BINDING=PASS_STATIC"
echo "N1B_V010014_CONTROL_NO_DEVICE_COMMANDS=PASS"
echo "N1B_V010014_CONTROL_NO_WRITE_AUTHORIZATION=PASS"
echo "N1B_V010014_CONTROL_CONTRACT=PASS"
