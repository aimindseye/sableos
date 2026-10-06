#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DRIVER="$ROOT/build/titan2/run-n1i-d0-host-closure.sh"
AUDIT="$ROOT/build/titan2/audit-n1i-d0-host.py"
APEX="$ROOT/build/titan2/materialize-n1i-d0-apex.py"
DEX="$ROOT/build/titan2/prepare-n1i-d0-dex-container.py"
NATIVE_SUM="$ROOT/build/titan2/summarize-n1i-d0-native.py"
DOC="$ROOT/docs/titan2/N1I_D0_HOST_BOOT_COMPATIBILITY_CLOSURE_R4.md"

fail() {
  echo "N1I_D0_HOST_CONTRACT=FAIL reason=$1" >&2
  exit 1
}

for path in "$DRIVER" "$AUDIT" "$APEX" "$DEX" "$NATIVE_SUM" "$DOC"; do
  [[ -f "$path" ]] || fail "required_file_missing=$path"
done

bash -n "$DRIVER" || fail driver_shell_syntax
PYTHONPYCACHEPREFIX=/tmp/sable-pycache python3 -m py_compile "$AUDIT" "$APEX" "$DEX" "$NATIVE_SUM" ||
  fail python_syntax

python3 "$AUDIT" --selftest >/dev/null ||
  fail host_audit_selftest
python3 "$APEX" --system-root /dev/null --out /dev/null   --debugfs /dev/null --fsck-erofs /dev/null --selftest >/dev/null ||
  fail apex_materializer_selftest
python3 "$DEX" --input /dev/null --out /dev/null --env /dev/null   --selftest >/dev/null ||
  fail dex_container_selftest
python3 "$NATIVE_SUM" --gates /dev/null --a4 /dev/null   --selftest >/dev/null ||
  fail native_summary_selftest

marker() {
  local label="$1" file="$2" value="$3"
  grep -Fq -- "$value" "$file" ||
    fail "missing_marker=$label:$value"
  echo "N1I_D0_HOST_CONTRACT_$label=PASS"
}

marker N1F_SHA "$DRIVER" 'dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a'
marker C2_SHA "$DRIVER" '630db78ef3f888b961640d17c5237495e673a953d67f1d52fabe056cbb76bb50'
marker STOCK_SYSTEM_SHA "$DRIVER" 'b2074e20afb6b1dccb87f804ec93b2b8cc64ac6f2366b8d3e6d52522f7f431bd'
marker STOCK_SYSTEM_EXT_SHA "$DRIVER" '1d9d25921def9b7e4e767c00a1f34d19ef5e7320138e3522545f2a2f2047d170'
marker STOCK_PRODUCT_SHA "$DRIVER" 'de1fdecab38b3c5ad7f30beea13f1afb46fa02d98b6cc78d57749b34513aad37'
marker STOCK_VENDOR_SHA "$DRIVER" 'cfeacc74b4289e56921016fedf35a45a995121b874be3cd2f1561b8ed2d61ada'
marker B2_PIN "$DRIVER" '1697f21989b8ed6f1db90f8886952894592c7d0f'
marker C3A_SOURCE_HEADS "$DRIVER" 'C3A_HEADS="$C3A_HISTORY/all-project-heads.tsv"'
marker C3A_CORE_SEAL "$DRIVER" 'for project in system/core system/sepolicy; do'
marker INIT_SOURCE_AUTH "$DRIVER" 'init_selinux_source:$ANDROID_ROOT/system/core/init/selinux.cpp'
marker SEPOLICY_SOURCE_AUTH "$DRIVER" 'sepolicy_android_bp:$ANDROID_ROOT/system/sepolicy/Android.bp'

marker BUILD_NO "$DRIVER" 'BUILD_AUTHORIZED=NO'
marker NETWORK_NO "$DRIVER" 'NETWORK_FETCH_AUTHORIZED=NO'
marker DEVICE_NO "$DRIVER" 'DEVICE_CONTACT_AUTHORIZED=NO'
marker REBOOT_NO "$DRIVER" 'REBOOT_AUTHORIZED=NO'
marker FLASH_NO "$DRIVER" 'FLASH_AUTHORIZED=NO'
marker A4_RETIRED "$DRIVER" 'N1I_D0_A4_IMPORT_AUTHORITY=RETIRED'

marker A0 "$AUDIT" 'PRECOMPILED_POLICY_MATCHES_INIT_HASHES'
marker A1_INIT_EQ "$AUDIT" 'INIT_EQUIVALENT_SECILC_RC='
marker PROPERTY_CHECKER "$AUDIT" 'PROPERTY_INFO_CHECKER_UNAVAILABLE'
marker PARTITION_CONTEXTS "$AUDIT" 'partition_context_files'
marker SERVICE_VINTF "$AUDIT" 'SERVICE_PROVIDER_MISSING_FUNCTIONAL_RISK'
marker PRIVAPP_SYSTEM_EXT "$AUDIT" 'SYSTEM_EXT_PRIVAPP_MISSING='
marker SEAPP "$AUDIT" 'UNKNOWN_AMBIGUOUS_MATCHING_DOMAINS'
marker MAC_PERMISSIONS_BIND "$AUDIT" 'PASS_CERT_BOUND_SEINFO'
marker MAC_PERMISSIONS_UNKNOWN "$AUDIT" 'UNKNOWN_SIGNING_CERT_NOT_BOUND_TO_MAC_PERMISSIONS'
marker SEINFO_NO_ASSUMPTION "$AUDIT" 'SEINFO_AUTHORITY_UNCLOSED'
marker STOCK_E "$AUDIT" '"stock"'
marker SYSTEMSERVER "$AUDIT" 'SYSTEMSERVERCLASSPATH = 2'
marker APEX_UPDATABLE "$AUDIT" 'updatable-bcp-packages.txt'
marker APEX_OVERLAP "$AUDIT" 'gate-e-{profile}-apex-overlaps.tsv'
marker MTK_APEX_OVERLAP "$AUDIT" 'MTK_APEX_CLASS_OVERLAP_UNPROVEN_BOOT_USE='
marker BOOT_FATAL_PATH "$AUDIT" 'RUNTIME_CLASSPATH_PATH_MISSING='
marker WINNER_RISK "$AUDIT" 'BOOTCLASSPATH_WINNER_CHANGED_UNPROVEN_BOOT_USE='
marker F_PROVEN "$AUDIT" 'N1I_D0_GATE_F_BOOT_EXECUTION_PROVEN'
marker F_REACHABLE "$AUDIT" 'N1I_D0_GATE_F_BOOT_EXECUTION_REACHABLE'
marker N1F_F_NA "$AUDIT" 'NO_OEM_IMS_IN_N1F_CONTROL'
marker UNKNOWN_RULE "$AUDIT" 'STOCK_ODM_PRESENT_BUT_UNPINNED'
marker VERDICT_DEFECT "$AUDIT" 'DEFECT_FOUND'
marker VERDICT_NOT_CLOSED "$AUDIT" 'NOT_CLOSED'
marker C1J_READY "$AUDIT" 'N1I_D0_C1J_COMPOSITION_READY'

marker APEX_ALL "$APEX" 'Gate G may require'
marker VDEX_SYNTH "$DEX" 'SYNTHETIC_FROM_SIBLING_VDEX'
marker G2_UNKNOWN "$NATIVE_SUM" 'UNKNOWN_NOT_IMPLEMENTED'
marker G_N1F_NA "$NATIVE_SUM" 'N1I_D0_GATE_G_N1F=NOT_APPLICABLE'

if grep -Eq '(^|[[:space:]])(curl|wget)([[:space:]]|$)|git[[:space:]]+(fetch|pull|clone)|repo[[:space:]]+sync' "$DRIVER"; then
  fail network_command_surface_present
fi
if grep -Eq '(^|[[:space:]])(make|m|mm|mmm|ninja)([[:space:]]|$)' "$DRIVER"; then
  fail build_command_surface_present
fi
if grep -Eq '(^|[[:space:]])(adb|fastboot)[[:space:]]+[^({]' "$DRIVER"; then
  fail device_command_surface_present
fi

# The driver intentionally hashes the four large system/stock authorities once
# each before extraction. It must not hash them again later.
for token in   'hash_exact N1F_SYSTEM'   'hash_exact C2_SYSTEM'   'hash_exact STOCK_SYSTEM'
do
  [[ "$(grep -Fc -- "$token" "$DRIVER")" == 1 ]] ||
    fail "duplicate_authority_hash=$token"
done

# B2 files must remain source-pinned, not modified by D0.
marker B2_BLOB_CHECK "$DRIVER" 'b2_analyzer_drift='
marker SEALED_C3A_SOURCE "$DRIVER" 'c3a_source_heads_seal_invalid'
marker NO_A4_FALLBACK "$DOC" 'A4 is never an import fallback'
marker N1F_CONTROL "$DOC" 'N1F control'
marker OBS_REQUIRED "$DOC" 'N1F-OBS'

echo "N1I_D0_HOST_CONTRACT=PASS"
