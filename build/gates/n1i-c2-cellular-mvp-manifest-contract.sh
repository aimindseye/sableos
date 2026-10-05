#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TOOL="$ROOT/build/titan2/prepare-n1i-c2-cellular-mvp-mutation-manifest.py"
TEST="$ROOT/tests/titan2/n1i-c2/test-cellular-mvp-manifest.py"
MVP_ENV="$ROOT/build/titan2/n1i-c2-cellular-mvp.env"
MVP_DOC="$ROOT/docs/titan2/N1I_C2_CELLULAR_MVP_BUNDLE_R1.md"

fail() {
    echo "N1I_C2_CELLULAR_MVP_MANIFEST_CONTRACT=FAIL reason=$*" >&2
    exit 1
}

marker() {
    local name="$1"
    local file="$2"
    local value="$3"
    grep -Fq -- "$value" "$file" || fail "missing_marker=$name"
    echo "N1I_C2_MANIFEST_CONTRACT_$name=PASS"
}

for f in "$TOOL" "$TEST" "$MVP_ENV" "$MVP_DOC"; do
    [[ -f "$f" ]] || fail "missing_file=$f"
done

echo "===== N1I-C2 CELLULAR MVP MANIFEST CONTRACT ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "REBOOT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"

PYTHONPYCACHEPREFIX="${TMPDIR:-/tmp}/sable-pycache" python3 -m py_compile "$TOOL" "$TEST"
echo "N1I_C2_MANIFEST_CONTRACT_PYTHON_SYNTAX=PASS"

marker OEM_IMS_SHA "$TOOL" "30db90de9e21d153f93deff2cf3d6c1a73f9c3fd7090533055267ee64cc66539"
marker COMMON_JAR_SHA "$TOOL" "511b674b91dd29e84e06c8e46c718e35650745c0359edd665d5fb3e88e6ed549"
marker IMS_BASE_JAR_SHA "$TOOL" "bb5769a098b59f9d299495981e87500da32e0667cf6a22931de2894d324a82ab"
marker TMETRICS_BASE "$TOOL" "27638e5be9c008101c2f9b8f1e7a9af49d94f838"
marker TMETRICS_POST "$TOOL" "9d5108e0ddb8d4960d21cda021813b53dbbf4da8"
marker TMETRICS_PATCH "$TOOL" "ee353caded6dd07318991eb52d66687e06034c30"
marker NATIVE_CLOSE_ONCE "$TOOL" "ADMIT_EXACT_STOCK_ONLY_SYSTEM_DEPENDENCY"
marker NATIVE_A4_FALLBACK "$TOOL" "ADMIT_ACCEPTED_A4_COMPATIBILITY_SUPERSET"
marker NATIVE_A4_COUNT "$TOOL" "expected=33"
marker NATIVE_FAIL_CLOSED "$TOOL" "b2_native_closure_not_finite="
marker PHH_MTKMAL "$TOOL" "persist.mtk_ims_support"
marker INCOMING_CALL "$TOOL" "ro.telephony.block_binder_thread_on_incoming_calls"
marker VENDOR_UA "$TOOL" "ALLOW_BOUNDED_START_IF_NOT_READY"
marker INTEGRATION_PACKAGE "$TOOL" "ADD_SABLE_TITAN_CELLULAR_INTEGRATION_PACKAGE"
marker HEALER_DEFAULT "$TOOL" "SHIP_DISABLED_BY_DEFAULT"
marker FINITE_SET "$TOOL" "PASS_FINITE_REVIEWABLE"

python3 "$TEST"
echo "N1I_C2_MANIFEST_CONTRACT_REGRESSION=PASS"

grep -Fxq 'N1I_C2_MVP_NATIVE_POLICY=PREFER_EXACT_B2_ELSE_ACCEPT_N1I_A_A4_33_FILE_SUPERSET_ONCE' "$MVP_ENV" ||
    fail mvp_native_policy_drift
grep -Fxq 'N1I_C2_MVP_TITAN_CELLULAR_INTEGRATION_PACKAGE=ADMIT' "$MVP_ENV" ||
    fail mvp_integration_policy_drift
grep -Fxq 'N1I_C2_MVP_HEALER_CODE=SHIP_DISABLED_BY_DEFAULT' "$MVP_ENV" ||
    fail mvp_healer_policy_drift
grep -Fq -- 'one Cellular MVP candidate' "$MVP_DOC" ||
    fail mvp_single_candidate_policy_drift

echo "N1I_C2_CELLULAR_MVP_MANIFEST_CONTRACT=PASS"
