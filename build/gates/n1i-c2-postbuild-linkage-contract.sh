#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
QUALIFIER="$ROOT/build/titan2/qualify-n1i-c2-postbuild-linkage.sh"
LINKAGE="$ROOT/build/titan2/run-n1i-c1-runtime-linkage-audit.sh"
APEX="$ROOT/build/titan2/audit-n1i-c1-apex-runtime-parity.py"
DERIVER="$ROOT/build/titan2/derive-n1i-c1-runtime-classpath.py"
MEMBER="$ROOT/build/titan2/audit-n1i-c1-runtime-linkage.py"
AGENT_CLASSIFIER="$ROOT/build/titan2/classify-n1i-c2-agentpremain-gap.py"

fail() {
  echo "N1I_C2_POSTBUILD_LINKAGE_CONTRACT=FAIL reason=$1" >&2
  exit 1
}

for path in "$QUALIFIER" "$LINKAGE" "$APEX" "$DERIVER" "$MEMBER" "$AGENT_CLASSIFIER"; do
  [[ -f "$path" ]] || fail "required_file_missing=$path"
done

bash -n "$QUALIFIER" || fail qualifier_shell_syntax
bash -n "$LINKAGE" || fail linkage_shell_syntax
python3 -m py_compile "$APEX" "$DERIVER" "$MEMBER" "$AGENT_CLASSIFIER" || fail python_syntax

marker() {
  local label="$1" file="$2" value="$3"
  grep -Fq -- "$value" "$file" || fail "missing_marker=$label:$value"
  echo "N1I_C2_POSTBUILD_LINKAGE_CONTRACT_$label=PASS"
}

marker BUILD_NO "$QUALIFIER" 'BUILD_AUTHORIZED=NO'
marker SOURCE_NO "$QUALIFIER" 'SOURCE_MUTATION_AUTHORIZED=NO'
marker NETWORK_NO "$QUALIFIER" 'NETWORK_FETCH_AUTHORIZED=NO'
marker DEVICE_NO "$QUALIFIER" 'DEVICE_CONTACT_AUTHORIZED=NO'
marker REBOOT_NO "$QUALIFIER" 'REBOOT_AUTHORIZED=NO'
marker FLASH_NO "$QUALIFIER" 'FLASH_AUTHORIZED=NO'
marker SOURCE_BIND "$QUALIFIER" 'EXPECTED_OUT_BASENAME="out-n1i-c2-${SOURCE_COMMIT:0:12}"'
marker ARTIFACT_SEAL "$QUALIFIER" 'sha256sum -c SHA256SUMS.txt'
marker RECEIPT_41 "$QUALIFIER" 'N1I_C2_POSTBUILD_RECEIPT=PASS rows=41'
marker NATIVE_28_5 "$QUALIFIER" 'count=33 frozen_stock=28 android_platform=5'
marker IMS_IDENTITY "$QUALIFIER" 'N1I_C2_POSTBUILD_IMS_IDENTITY=PASS'
marker BOOTCLASSPATH "$QUALIFIER" 'N1I_C2_POSTBUILD_BOOTCLASSPATH=PASS'
marker LINKAGE_CALL "$QUALIFIER" 'run-n1i-c1-runtime-linkage-audit.sh'
marker LINKAGE_SHA "$QUALIFIER" '--expected-system-sha "$EXPECTED_SYSTEM_SHA"'
marker LINKAGE_BYTES "$QUALIFIER" '--expected-system-bytes "$EXPECTED_SYSTEM_BYTES"'
marker LINKAGE_FULL_CLASSIFICATION "$QUALIFIER" 'PASS_FULL_CLASSIFICATION_AGENTPREMAIN_8'
marker LINKAGE_NO_SUPPRESSION "$QUALIFIER" 'AGENTPREMAIN_BROAD_RUNTIME_FAILURE_SUPPRESSION=NO'
marker CLASSIFIER_EXACT "$AGENT_CLASSIFIER" 'PASS_EXACT_DORMANT_NON_ANDROID_DEBUG_AGENT'
marker CLASSIFIER_FAILURE_COUNT "$AGENT_CLASSIFIER" 'EXPECTED_AGENT_FAILURES = 8'
marker CLASSIFIER_NO_SUPPRESSION "$AGENT_CLASSIFIER" 'N1I_C2_AGENTPREMAIN_BROAD_RUNTIME_FAILURE_SUPPRESSION=NO'
marker CLASSIFIER_TELEPHONY_ZERO "$AGENT_CLASSIFIER" 'N1I_C2_AGENTPREMAIN_TELEPHONY_FAILURE_COUNT='
marker CLASSIFIER_INBOUND_ZERO "$AGENT_CLASSIFIER" 'N1I_C2_AGENTPREMAIN_EXTERNAL_INBOUND_REF_COUNT='
marker EVIDENCE_SEAL "$QUALIFIER" 'N1I_C2_POSTBUILD_EVIDENCE_SEAL=PASS_EXCLUDES_QUALIFY_LOG'
marker FINAL_PASS "$QUALIFIER" 'N1I_C2_POSTBUILD_LINKAGE_QUALIFICATION=PASS'
marker MERGE_READY "$QUALIFIER" 'N1I_C2_READY_FOR_MERGE_REVIEW=YES'
marker FLASH_QUAL_READY "$QUALIFIER" 'N1I_C2_READY_FOR_FLASH_QUALIFICATION=YES'

marker C1_DEFAULT_SHA "$LINKAGE" 'EXPECTED_C1_SHA="137bc8771c817c0afb3122d9f03e7a94575e03bcccc643b56235edd1075f2160"'
marker C1_DEFAULT_BYTES "$LINKAGE" 'EXPECTED_C1_BYTES="3210661888"'
marker LINKAGE_OVERRIDE_SHA "$LINKAGE" '--expected-system-sha)'
marker LINKAGE_OVERRIDE_BYTES "$LINKAGE" '--expected-system-bytes)'
marker APEX_OVERRIDE "$APEX" '"--expected-system-sha"'
marker APEX_DEFAULT "$APEX" 'default=EXPECTED_C1_SHA'
marker DERIVER_OVERRIDE "$DERIVER" '"--expected-system-sha"'
marker DERIVER_DEFAULT "$DERIVER" 'default=EXPECTED_C1_SHA'
marker DERIVER_DRIVER_PROPAGATION "$LINKAGE" '--expected-system-sha "$EXPECTED_C1_SHA"'

if grep -Eq '(^|[[:space:]])(adb|fastboot)([[:space:]]|$)' "$QUALIFIER" "$AGENT_CLASSIFIER"; then
  fail device_command_surface_present
fi
if grep -Eq '(^|[[:space:]])(make|m)([[:space:]]+)(systemimage|bootimage|target-files-package)' "$QUALIFIER" "$AGENT_CLASSIFIER"; then
  fail build_command_surface_present
fi
if grep -Eq '(^|[[:space:]])(curl|wget|git[[:space:]]+fetch|repo[[:space:]]+sync)([[:space:]]|$)' "$QUALIFIER" "$AGENT_CLASSIFIER"; then
  fail network_command_surface_present
fi
if grep -Fq -- 'sha256(system_img)' "$AGENT_CLASSIFIER"; then
  fail redundant_agentpremain_system_image_hash
fi

python3 "$APEX" --selftest >/dev/null ||
  fail apex_runtime_parity_selftest
python3 "$DERIVER" --selftest >/dev/null ||
  fail runtime_classpath_deriver_selftest
python3 "$MEMBER" --selftest >/dev/null ||
  fail runtime_member_linkage_selftest
python3 "$AGENT_CLASSIFIER" --selftest >/dev/null ||
  fail agentpremain_classifier_selftest

echo "N1I_C2_POSTBUILD_LINKAGE_CONTRACT=PASS"
