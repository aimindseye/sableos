#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DRIVER="$ROOT/build/titan2/run-n1i-d0-host-closure.sh"
HELPER="$ROOT/build/titan2/n1i-d0-host.py"
PLAN="$ROOT/docs/titan2/N1I_D0_EXECUTION_PLAN_R4.md"
CONFIG="$ROOT/build/titan2/n1i-d0.env.example"
B2_PIN="1697f21989b8ed6f1db90f8886952894592c7d0f"

fail() {
  echo "N1I_D0_HOST_CLOSURE_CONTRACT=FAIL reason=$1" >&2
  exit 1
}

for f in "$DRIVER" "$HELPER" "$PLAN" "$CONFIG"; do
  [[ -f "$f" ]] || fail "required_file_missing=$f"
done

bash -n "$DRIVER" || fail driver_shell_syntax
python3 -m py_compile "$HELPER" || fail helper_python_syntax
python3 "$HELPER" selftest >/dev/null || fail helper_selftest

git -C "$ROOT" merge-base --is-ancestor "$B2_PIN" HEAD >/dev/null 2>&1 ||
  fail b2_pin_not_ancestor

marker() {
  local label="$1" file="$2" value="$3"
  grep -Fq -- "$value" "$file" || fail "missing_marker=$label:$value"
  echo "N1I_D0_HOST_CLOSURE_CONTRACT_$label=PASS"
}

marker SET_U "$DRIVER" 'set -u'
marker POLICY_NO_BUILD "$DRIVER" 'BUILD_AUTHORIZED=NO'
marker POLICY_NO_NETWORK "$DRIVER" 'NETWORK_FETCH_AUTHORIZED=NO'
marker POLICY_NO_DEVICE "$DRIVER" 'DEVICE_CONTACT_AUTHORIZED=NO'
marker POLICY_NO_REBOOT "$DRIVER" 'REBOOT_AUTHORIZED=NO'
marker POLICY_NO_FLASH "$DRIVER" 'FLASH_AUTHORIZED=NO'
marker B2_PIN "$DRIVER" 'B2_PIN="1697f21989b8ed6f1db90f8886952894592c7d0f"'
marker B2_LOCAL_ARCHIVE "$DRIVER" 'git -C "$ROOT" archive "$B2_PIN"'
marker B2_NO_FALLBACK "$DRIVER" 'N1I_D0_A4_IMPORT_AUTHORITY RETIRED_REFERENCE_ONLY'
marker TMetrics_SCOPE "$DRIVER" 'N1I_D0_TELEPHONYMETRICS_SCOPE C2_ONLY'
marker A0 "$DRIVER" 'N1I_D0_A0_'
marker A1 "$DRIVER" 'INIT_EQUIVALENT_SPLIT_COMPILE'
marker A2 "$DRIVER" 'FULL_COMPLIANCE_COMPILE'
marker B_AFTER_A "$PLAN" 'Gate B runs after A1 and consumes A1'
marker N1F_D_CONTROL "$DRIVER" 'privapp-tree'
marker N1F_E_CONTROL "$DRIVER" 'run_classpath N1F'
marker D_ENFORCE "$DRIVER" 'mode=enforce missing='
marker E_FATAL_PATH "$DRIVER" 'runtime_classpath_missing='
marker E_DUP_REPORT_ONLY "$DRIVER" 'DUPLICATES_REPORT_ONLY_PENDING_BOOT_PATH'
marker F_BOOT_PATH "$DRIVER" 'BOOT_PATH_COMPONENT='
marker G2_VERSION_UNKNOWN "$DRIVER" 'N1I_D0_G2_SYMBOL_VERSION_CHECK UNKNOWN_NOT_IMPLEMENTED'
marker G2_NAMESPACE_UNKNOWN "$DRIVER" 'N1I_D0_G2_LINKER_NAMESPACE_CHECK UNKNOWN_NOT_IMPLEMENTED'
marker VERDICT_UNKNOWN "$DRIVER" 'N1I_D0_CLOSURE_UNKNOWN_COUNT'
marker COMPOSITION_READY "$DRIVER" 'N1I_D0_C1J_COMPOSITION_READY'
marker NEXT_N1F_OBS "$DRIVER" 'N1I_D0_NEXT_PHYSICAL_IMAGE N1F_OBS_ONLY_AFTER_D0_REVIEW'
marker PHYSICAL_NONE "$DRIVER" 'N1I_D0_PHYSICAL_ACTIONS=NONE'
marker PLAN_GATE_E_SEVERITY "$PLAN" '## Gate E severity'
marker PLAN_PER_GATE_N1F "$PLAN" 'Every applicable gate runs the same algorithm on N1F and C2'
marker PLAN_A0 "$PLAN" '### A0 — policy-path selection'
marker PLAN_G2_GAP "$PLAN" 'UNKNOWN_NOT_IMPLEMENTED'
marker PLAN_OBS_ALWAYS "$PLAN" 'The first physical image after D0 is always N1F-OBS'

if grep -Fq -- 'set -euo pipefail' "$DRIVER" ||
   grep -Eq '(^|[[:space:]])set[[:space:]]+-o[[:space:]]+pipefail' "$DRIVER"; then
  fail driver_forbidden_strict_shell_mode
fi

if grep -Eq '(^|[[:space:]])(adb|fastboot)([[:space:]]|$)' "$DRIVER"; then
  fail device_command_surface_present
fi
if grep -Eq '(^|[[:space:]])(curl|wget)([[:space:]]|$)|git[[:space:]]+(fetch|pull|clone)|repo[[:space:]]+sync' "$DRIVER"; then
  fail network_command_surface_present
fi
if grep -Eq '(^|[[:space:]])(m|make|ninja)([[:space:]]+)(systemimage|bootimage|target-files-package)' "$DRIVER"; then
  fail build_command_surface_present
fi

# A4 may be read for comparison only; it must never feed product mutation.
A4_REFS="$(grep -Fc 'a4-native-superset.txt' "$DRIVER" || true)"
[[ "$A4_REFS" -le 1 ]] || fail "a4_reference_count=$A4_REFS"
if grep -Eq 'PRODUCT_PACKAGES.*a4|a4.*PRODUCT_PACKAGES' "$DRIVER"; then
  fail a4_product_admission_surface
fi

# The helper must exercise partition-scoped allowlist and policy-path fixtures.
marker HELPER_A0 "$HELPER" 'def policy_path('
marker HELPER_PRIVAPP "$HELPER" 'def privapp('
marker HELPER_PRIVAPP_TREE "$HELPER" 'def privapp_tree('
marker HELPER_SEAPP "$HELPER" 'def seapp('
marker HELPER_APEX "$HELPER" 'def apex_extract('
marker HELPER_CLASSPATH "$HELPER" 'def classpath('
marker HELPER_PRIVAPP_SELFTEST "$HELPER" 'assert priv["missing_required"] == ["android.permission.P2"]'

echo "N1I_D0_HOST_CLOSURE_CONTRACT=PASS"
echo "DEVICE_CONTACT=NONE"
echo "BUILD_STARTED=NO"
echo "NETWORK_FETCH=NONE"
echo "REBOOT=NONE"
echo "FLASH=NONE"
