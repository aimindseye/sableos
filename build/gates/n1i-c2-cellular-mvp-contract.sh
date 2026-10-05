#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV="$ROOT/build/titan2/n1i-c2-cellular-mvp.env"
DOC="$ROOT/docs/titan2/N1I_C2_CELLULAR_MVP_BUNDLE_R1.md"
TMETRICS="$ROOT/patches/android-16-n1i-c1/telephony/0001-telephony-add-titan2-legacy-writeRilAnswer-overload.patch"

fail() {
    echo "N1I_C2_CELLULAR_MVP_CONTRACT=FAIL reason=$*" >&2
    exit 1
}

require_line() {
    local file="$1"
    local line="$2"
    grep -Fxq -- "$line" "$file" || fail "missing_marker=$line file=$file"
}

[[ -f "$ENV" ]] || fail "env_missing=$ENV"
[[ -f "$DOC" ]] || fail "doc_missing=$DOC"
[[ -f "$TMETRICS" ]] || fail "telephonymetrics_patch_missing=$TMETRICS"

echo "===== N1I-C2 CELLULAR MVP CONTRACT ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"

require_line "$ENV" 'N1I_C2_MVP_REVISION=R1'
require_line "$ENV" 'N1I_C2_MVP_ANDROID_PLATFORM=16'
require_line "$ENV" 'N1I_C2_MVP_GOAL=TRAY1_SINGLE_SIM_CELLULAR_WORKING_THEN_RETURN_TO_SABLEOS'
require_line "$ENV" 'N1I_C2_MVP_RESTLESS_CONTROL_PATCH_COUNT=369'
require_line "$ENV" 'N1I_C2_MVP_RESTLESS_COMPATIBILITY_SUBSTRATE=RETAIN'
require_line "$ENV" 'N1I_C2_MVP_OEM_IMS_PROVIDER=com.mediatek.ims'
require_line "$ENV" 'N1I_C2_MVP_JAVA_REQUIRED_JAR_COUNT=2'
require_line "$ENV" 'N1I_C2_MVP_REQUIRED_JAR_1=/system_ext/framework/mediatek-common.jar'
require_line "$ENV" 'N1I_C2_MVP_REQUIRED_JAR_2=/system_ext/framework/mediatek-ims-base.jar'
require_line "$ENV" 'N1I_C2_MVP_NATIVE_POLICY=PREFER_EXACT_B2_ELSE_ACCEPT_N1I_A_A4_33_FILE_SUPERSET_ONCE'
require_line "$ENV" 'N1I_C2_MVP_VENDOR_NATIVE_POLICY=PRESERVE_VENDOR_DO_NOT_DUPLICATE'
require_line "$ENV" 'N1I_C2_MVP_TELEPHONYMETRICS_TWO_ARG_OVERLOAD=ADMIT'
require_line "$ENV" 'N1I_C2_MVP_TELEPHONYMETRICS_SEMANTICS=NOOP_COMPATIBILITY_ONLY'
require_line "$ENV" 'N1I_C2_MVP_INCOMING_CALL_BINDER_COMPAT=ENABLE_TITAN2_EXISTING_RESTLESS_PATH'
require_line "$ENV" 'N1I_C2_MVP_TITAN_CELLULAR_INTEGRATION_PACKAGE=ADMIT'
require_line "$ENV" 'N1I_C2_MVP_VENDOR_UA_READINESS=VERIFY_AND_WAIT_FOR_STOCK_ATTRIBUTED_SERVICES'
require_line "$ENV" 'N1I_C2_MVP_HEALER_CODE=SHIP_DISABLED_BY_DEFAULT'
require_line "$ENV" 'N1I_C2_MVP_HEALER_TRIGGER=STATE_FAILURE_ONLY'
require_line "$ENV" 'N1I_C2_MVP_TRAY2=DEFER'
require_line "$ENV" 'N1I_C2_MVP_DSDS=DEFER'
require_line "$ENV" 'N1I_C2_MVP_VOWIFI_QNS_IWLAN=DEFER'
require_line "$ENV" 'N1I_C2_MVP_MTKRADIOEX_NEW_CLIENT=DEFER_UNLESS_RUNTIME_PROVES_REQUIRED'
require_line "$ENV" 'N1I_C2_MVP_ATLAS_BLIND_SIMSWITCH_HOLD=REJECT'
require_line "$ENV" 'N1I_C2_MVP_GENERIC_RIL_RESTART=REJECT'
require_line "$ENV" 'N1I_C2_MVP_SELINUX_PERMISSIVE_RECOVERY=REJECT'
require_line "$ENV" 'N1I_C2_MVP_ACCEPT_BOOT_X3=REQUIRED'
require_line "$ENV" 'N1I_C2_MVP_ACCEPT_DATA_STABLE_30_MIN=REQUIRED'
require_line "$ENV" 'N1I_C2_MVP_ACCEPT_IMS_REGISTERED=REQUIRED'
require_line "$ENV" 'N1I_C2_MVP_ACCEPT_VOICE_MO=REQUIRED'
require_line "$ENV" 'N1I_C2_MVP_ACCEPT_VOICE_MT=REQUIRED'
require_line "$ENV" 'N1I_C2_MVP_SOURCE_MUTATION_AUTHORIZED=NO'
require_line "$ENV" 'N1I_C2_MVP_BUILD_AUTHORIZED=NO'
require_line "$ENV" 'N1I_C2_MVP_DEVICE_CONTACT_AUTHORIZED=NO'
require_line "$ENV" 'N1I_C2_MVP_FLASH_AUTHORIZED=NO'

grep -Fq -- 'public void writeRilAnswer(int phoneId, int rilSerial)' "$TMETRICS" ||
    fail "telephonymetrics_two_arg_overload_missing"

grep -Fq -- 'The next candidate shall be a **small coherent cellular subsystem**' "$DOC" ||
    fail "coherent_subsystem_policy_missing"

grep -Fq -- 'HEALER_ENABLED=NO' "$DOC" ||
    fail "healer_default_off_missing"

grep -Fq -- 'one Cellular MVP candidate' "$DOC" ||
    fail "single_candidate_policy_missing"

for forbidden in     'N1I_C2_MVP_TRAY2=REQUIRED'     'N1I_C2_MVP_DSDS=REQUIRED'     'N1I_C2_MVP_VOWIFI_QNS_IWLAN=REQUIRED'     'N1I_C2_MVP_MTKRADIOEX_NEW_CLIENT=ADMIT'     'N1I_C2_MVP_GENERIC_RIL_RESTART=ADMIT'     'N1I_C2_MVP_SELINUX_PERMISSIVE_RECOVERY=ADMIT'
do
    if grep -Fxq -- "$forbidden" "$ENV"; then
        fail "forbidden_scope_expansion=$forbidden"
    fi
done

echo "N1I_C2_MVP_SCOPE=PASS_FINITE_CELLULAR_SUBSYSTEM"
echo "N1I_C2_MVP_RESTLESS_SUBSTRATE=PASS_RETAIN_369"
echo "N1I_C2_MVP_OEM_IMS_ISLAND=PASS_DEFINED"
echo "N1I_C2_MVP_NATIVE_POLICY=PASS_CLOSE_ONCE_WITH_ACCEPTED_A4_FALLBACK"
echo "N1I_C2_MVP_FRAMEWORK_COMPAT=PASS_DEFINED"
echo "N1I_C2_MVP_INTEGRATION_PACKAGE=PASS_REQUIRED"
echo "N1I_C2_MVP_HEALER_POLICY=PASS_SHIP_DISABLED"
echo "N1I_C2_MVP_ACCEPTANCE=PASS_TRAY1_ONLY"
echo "N1I_C2_CELLULAR_MVP_CONTRACT=PASS"
