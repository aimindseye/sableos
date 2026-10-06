#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

RUNNER="$ROOT/build/titan2/run-n1i-d0-0h.sh"
PREP="$ROOT/build/titan2/prepare-n1i-d0-0h-inputs.sh"
QUAL="$ROOT/build/titan2/qualify-n1i-d0-0h.py"
APEX="$ROOT/build/titan2/materialize-n1i-d0-apex.py"
LOAD_SCAN="$ROOT/build/titan2/scan-n1i-d0-native-loads.py"
B2_NATIVE="$ROOT/build/titan2/n1i-b2-native.py"
B2_MEMBERS="$ROOT/build/titan2/n1i-b2-members.py"
PLAN="$ROOT/docs/titan2/N1I_D0_EXECUTION_PLAN_R4.md"

fail() {
  echo "N1I_D0_0H_CONTRACT=FAIL reason=$1" >&2
  exit 1
}

for path in \
  "$RUNNER" "$PREP" "$QUAL" "$APEX" "$LOAD_SCAN" \
  "$B2_NATIVE" "$B2_MEMBERS" "$PLAN"
do
  [[ -f "$path" ]] || fail "required_file_missing=$path"
done

bash -n "$RUNNER" || fail runner_shell_syntax
bash -n "$PREP" || fail prep_shell_syntax

PYTHONPYCACHEPREFIX=/tmp/sable-pycache \
python3 -m py_compile "$QUAL" "$APEX" "$LOAD_SCAN" ||
  fail python_syntax

python3 "$QUAL" --selftest >/dev/null ||
  fail qualifier_selftest
python3 "$APEX" --selftest >/dev/null ||
  fail apex_materializer_selftest
python3 "$LOAD_SCAN" --selftest >/dev/null ||
  fail native_load_scan_selftest
python3 "$B2_NATIVE" --help >/dev/null ||
  fail b2_native_cli
python3 "$B2_MEMBERS" --help >/dev/null ||
  fail b2_members_cli

marker() {
  local label="$1" file="$2" value="$3"
  grep -Fq -- "$value" "$file" ||
    fail "missing_marker=$label:$value"
  echo "N1I_D0_0H_CONTRACT_$label=PASS"
}

marker HOST_ONLY_RUNNER "$RUNNER" 'DEVICE_CONTACT_AUTHORIZED=NO'
marker NO_BUILD "$RUNNER" 'BUILD_AUTHORIZED=NO'
marker NO_NETWORK "$RUNNER" 'NETWORK_FETCH_AUTHORIZED=NO'
marker NO_REBOOT "$RUNNER" 'REBOOT_AUTHORIZED=NO'
marker NO_FLASH "$RUNNER" 'FLASH_AUTHORIZED=NO'
marker N1F_CONTROL "$PLAN" 'N1F is the known-good'
marker UNKNOWN_RULE "$PLAN" 'Missing required evidence is'
marker F_G_NA "$PLAN" 'NOT_APPLICABLE_OEM_IMS_ABSENT'
marker A0_PRECOMPILED "$QUAL" 'precompiled_authority('
marker INIT_VERSION "$QUAL" 'init_sepolicy_version('
marker INIT_FLAGS "$QUAL" '"-m", "-M", "true", "-G", "-N"'
marker GATE_B_AFTER_A "$QUAL" 'effective_policy_unavailable gate_a='
marker SERVICE_MERGE "$QUAL" 'merged-service-contexts'
marker PRIVAPP_PARTITION "$QUAL" 'system_ext_privapp_missing='
marker SEAPP "$QUAL" 'SEAPP_RESULT='
marker PER_SIDE_APEX "$QUAL" 'N1F_APEX_ROOT'
marker APEX_STOCK "$QUAL" 'STOCK_APEX_ROOT'
marker UPDATABLE_BCP "$QUAL" 'updatable-bcp-packages.txt'
marker MEMBER_AUDIT "$QUAL" 'audit-n1i-c1-runtime-linkage.py'
marker MEMBER_SEVERITY "$QUAL" 'boot_caller_not_proven'
marker B2_NATIVE "$QUAL" 'n1i-b2-native.py'
marker JAR_LOAD_SCAN "$QUAL" 'scan-n1i-d0-native-loads.py'
marker G2_UNKNOWN "$QUAL" 'UNKNOWN_NOT_IMPLEMENTED'
marker A4_RETIREMENT "$QUAL" 'A4_RETIREMENT.tsv'
marker A4_NO_AUTH "$PLAN" 'A4 is comparison evidence only.'
marker C1J_READY "$QUAL" 'N1I_D0_C1J_COMPOSITION_READY='
marker VERDICT_DEFECT "$QUAL" '"DEFECT_FOUND"'
marker VERDICT_NOT_CLOSED "$QUAL" '"NOT_CLOSED"'
marker VERDICT_NO_FATAL "$QUAL" '"NO_FATAL_DEFECT_FOUND"'
marker APEX_INPUT_N1F "$PREP" 'N1F_APEX_ROOT='
marker APEX_INPUT_C2 "$PREP" 'C2_APEX_ROOT='
marker APEX_INPUT_STOCK "$PREP" 'STOCK_APEX_ROOT='
marker B2_PROVENANCE "$QUAL" '1697f21989b8ed6f1db90f8886952894592c7d0f'

if grep -Fq -- 'c3a_apex_root' "$QUAL" ||
   grep -Fq -- 'work/apex/c3a' "$QUAL"; then
  fail stale_c3a_apex_runtime_borrowing
fi
echo "N1I_D0_0H_CONTRACT_PER_SIDE_APEX_ONLY=PASS"

for file in "$RUNNER" "$PREP" "$QUAL" "$APEX" "$LOAD_SCAN"; do
  if grep -Eq '(^|[[:space:]])(adb|fastboot)([[:space:]]|$)' "$file"; then
    fail "device_command_surface_present=$file"
  fi
done
echo "N1I_D0_0H_CONTRACT_DEVICE_COMMAND_SURFACE=PASS_ABSENT"

for file in "$RUNNER" "$PREP" "$QUAL" "$APEX" "$LOAD_SCAN"; do
  if grep -Eq '(^|[[:space:]])(curl|wget)([[:space:]]|$)|git[[:space:]]+(fetch|pull|clone)|repo[[:space:]]+sync' "$file"; then
    fail "network_command_surface_present=$file"
  fi
done
echo "N1I_D0_0H_CONTRACT_NETWORK_SURFACE=PASS_ABSENT"

if grep -Eq '(^|[[:space:]])(make|m|mm|mmm|ninja)([[:space:]]|$)' \
  "$RUNNER" "$PREP"; then
  fail build_command_surface_present
fi
echo "N1I_D0_0H_CONTRACT_BUILD_SURFACE=PASS_ABSENT"

if grep -Eq '(^|[[:space:]])mount([[:space:]]|$)|(^|[[:space:]])umount([[:space:]]|$)' \
  "$RUNNER" "$PREP" "$QUAL" "$APEX" "$LOAD_SCAN"; then
  fail mount_command_surface_present
fi
echo "N1I_D0_0H_CONTRACT_MOUNT_SURFACE=PASS_ABSENT"

if ! git -C "$ROOT" merge-base --is-ancestor \
  1697f21989b8ed6f1db90f8886952894592c7d0f HEAD; then
  fail b2_provenance_not_ancestor
fi
echo "N1I_D0_0H_CONTRACT_B2_PROVENANCE=PASS_ANCESTOR"

echo "N1I_D0_0H_CONTRACT=PASS"
