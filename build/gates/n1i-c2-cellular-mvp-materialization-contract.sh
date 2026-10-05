#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TOOL="$ROOT/build/titan2/materialize-n1i-c2-cellular-mvp-stock.py"
DRIVER="$ROOT/build/titan2/run-n1i-c2-cellular-mvp-materialization.sh"
TEST="$ROOT/tests/titan2/n1i-c2/test-cellular-mvp-materialization.py"
DOC="$ROOT/docs/titan2/N1I_C2_CELLULAR_MVP_MATERIALIZATION_R1.md"

fail() {
    echo "N1I_C2_CELLULAR_MVP_MATERIALIZATION_CONTRACT=FAIL reason=$*" >&2
    exit 1
}

marker() {
    local name="$1"
    local file="$2"
    local value="$3"
    grep -Fq -- "$value" "$file" || fail "missing_marker=$name"
    echo "N1I_C2_MATERIALIZATION_CONTRACT_$name=PASS"
}

for file in "$TOOL" "$DRIVER" "$TEST" "$DOC"; do
    [[ -f "$file" ]] || fail "missing_file=$file"
done

echo "===== N1I-C2 CELLULAR MVP MATERIALIZATION CONTRACT ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "REBOOT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"

bash -n "$DRIVER"
echo "N1I_C2_MATERIALIZATION_CONTRACT_SHELL_SYNTAX=PASS"

PYTHONPYCACHEPREFIX="${TMPDIR:-/tmp}/sable-pycache"     python3 -m py_compile "$TOOL" "$TEST"
echo "N1I_C2_MATERIALIZATION_CONTRACT_PYTHON_SYNTAX=PASS"

marker STOCK_COUNT "$TOOL" 'EXPECTED_STOCK_FILE_COUNT = 36'
marker NATIVE_COUNT "$TOOL" 'EXPECTED_NATIVE_COUNT = 33'
marker MUTATION_COUNT "$TOOL" 'EXPECTED_MUTATION_COUNT = 41'
marker OEM_IMS_SHA "$TOOL" '30db90de9e21d153f93deff2cf3d6c1a73f9c3fd7090533055267ee64cc66539'
marker COMMON_JAR_SHA "$TOOL" '511b674b91dd29e84e06c8e46c718e35650745c0359edd665d5fb3e88e6ed549'
marker IMS_BASE_JAR_SHA "$TOOL" 'bb5769a098b59f9d299495981e87500da32e0667cf6a22931de2894d324a82ab'
marker A4_SHA "$TOOL" '6dad2e573b912d6a20fd5b16cb667dc15b9d43cb1f831fa2751830282e437fd4'
marker A4_REFERENCE_BLOB "$TOOL" '4eaa02f10b6732c07ffe2fa2e244824297da1cb3'
marker A4_TARGET_AUTHORITY "$TOOL" 'native_target_authority_drift='
marker STOCK_SYSTEM_SHA "$TOOL" 'b2074e20afb6b1dccb87f804ec93b2b8cc64ac6f2366b8d3e6d52522f7f431bd'
marker STOCK_SYSTEM_EXT_SHA "$TOOL" '1d9d25921def9b7e4e767c00a1f34d19ef5e7320138e3522545f2a2f2047d170'
marker STOCK_PRODUCT_SHA "$TOOL" 'de1fdecab38b3c5ad7f30beea13f1afb46fa02d98b6cc78d57749b34513aad37'
marker STOCK_VENDOR_SHA "$TOOL" 'cfeacc74b4289e56921016fedf35a45a995121b874be3cd2f1561b8ed2d61ada'
marker C3A_SHA "$TOOL" '4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16'
marker ELF64 "$TOOL" 'native_not_elf64_le='
marker AARCH64 "$TOOL" 'native_not_aarch64='
marker FROZEN_MANIFEST "$TOOL" 'CELLULAR_MVP_FROZEN_MUTATION_MANIFEST.tsv'
marker NATIVE_HASH_COUNT "$TOOL" 'N1I_C2_MATERIALIZATION_NATIVE_HASH_COUNT'
marker FULL_MUTATION_ID_SET "$TOOL" 'EXPECTED_MUTATION_IDS = {f"M{i:03d}" for i in range(1, 42)}'
marker NON_STOCK_SEMANTICS "$TOOL" 'EXPECTED_NON_STOCK_MUTATIONS = {'
marker NATIVE_ID_SET "$TOOL" 'expected_native_ids = {f"M{i:03d}" for i in range(7, 40)}'
marker SYMLINK_FAIL_CLOSED "$TOOL" 'stock_source_symlink='
marker OUTPUT_PROTECTION "$TOOL" 'output_inside_protected='
marker AUTH_REQUIRED "$DRIVER" 'materialization_requires_--authorize-materialization'
marker FRESH_REPLAY_ONLY "$DRIVER" 'FRESH_PINNED_REPLAY_ONLY'
marker REPLAY_WORK_CLEANUP "$DRIVER" 'PASS_REMOVED_AFTER_FREEZE'
marker REPLAY_RC_CAPTURE "$DRIVER" 'REPLAY_RC=$?'
marker MATERIALIZER_RC_CAPTURE "$DRIVER" 'MATERIALIZE_RC=$?'
marker SOURCE_COMMIT_EVIDENCE "$DRIVER" 'N1I_C2_MATERIALIZATION_SOURCE_COMMIT='
marker OUTPUT_REPO_GUARD "$DRIVER" 'out_inside_repo='
marker EVIDENCE_REPO_GUARD "$DRIVER" 'evidence_inside_repo='
marker MANIFEST_OUTPUT_GUARD "$DRIVER" 'out_inside_manifest_evidence='
marker AUDIT_BLOB "$DRIVER" '02f7b7330b468a31be8cfc60551673cad127313e'
marker NO_SOURCE_MUTATION "$DRIVER" 'SOURCE_MUTATION_AUTHORIZED=NO'
marker NO_BUILD "$DRIVER" 'BUILD_AUTHORIZED=NO'
marker NO_DEVICE "$DRIVER" 'DEVICE_CONTACT_AUTHORIZED=NO'
marker NO_FLASH "$DRIVER" 'FLASH_AUTHORIZED=NO'

if UNAUTH_OUTPUT="$(bash "$DRIVER" 2>&1)"; then
    fail unauthorized_materialization_was_accepted
else
    UNAUTH_RC=$?
fi
[[ "$UNAUTH_RC" -eq 64 ]] || fail "unauthorized_materialization_rc=$UNAUTH_RC"
grep -Fq 'N1I_C2_MATERIALIZATION_DRIVER=FAIL reason=materialization_requires_--authorize-materialization' <<<"$UNAUTH_OUTPUT" ||
    fail unauthorized_materialization_reason
echo "N1I_C2_MATERIALIZATION_CONTRACT_AUTHORIZATION_FAIL_CLOSED=PASS"

if grep -Eq -- 'subprocess|os\.system|Popen|check_call|check_output|run\(' "$TOOL"; then
    fail materializer_command_execution_surface
fi
echo "N1I_C2_MATERIALIZATION_CONTRACT_NO_COMMAND_EXECUTION=PASS"

if grep -Eq -- '(^|[[:space:]])(m|mm|mmm|make|ninja|soong_ui\.bash)([[:space:]]|$)' "$DRIVER"; then
    fail driver_build_surface
fi
echo "N1I_C2_MATERIALIZATION_CONTRACT_NO_BUILD_COMMAND=PASS"

if grep -Eq -- '(^|[^A-Za-z_])(adb|fastboot)[[:space:](]' "$DRIVER" "$TOOL"; then
    fail device_command_surface
fi
echo "N1I_C2_MATERIALIZATION_CONTRACT_NO_DEVICE_COMMANDS=PASS"

if grep -Eq -- 'curl|wget|requests|urllib|socket|git[[:space:]]+(fetch|pull|clone)|https?://' "$DRIVER" "$TOOL"; then
    fail network_surface
fi
echo "N1I_C2_MATERIALIZATION_CONTRACT_NO_NETWORK=PASS"

if TEST_OUTPUT="$(python3 "$TEST")"; then
    printf '%s\n' "$TEST_OUTPUT"
else
    fail materialization_regression
fi
echo "N1I_C2_MATERIALIZATION_CONTRACT_REGRESSION=PASS"

grep -Fq 'N1I_C2_MATERIALIZATION_TEST_SEMANTIC_DRIFT_FAIL_CLOSED=PASS' <<<"$TEST_OUTPUT" ||
    fail semantic_drift_regression_marker
grep -Fq 'N1I_C2_MATERIALIZATION_TEST_SYMLINK_FAIL_CLOSED=PASS' <<<"$TEST_OUTPUT" ||
    fail symlink_regression_marker
grep -Fq 'N1I_C2_MATERIALIZATION_TEST_NATIVE_TARGET_AUTHORITY=PASS' <<<"$TEST_OUTPUT" ||
    fail native_target_authority_regression_marker
grep -Fq 'N1I_C2_MATERIALIZATION_TEST_OUTPUT_PROTECTION=PASS' <<<"$TEST_OUTPUT" ||
    fail output_protection_regression_marker
echo "N1I_C2_MATERIALIZATION_CONTRACT_FAIL_CLOSED_REGRESSIONS=PASS"

echo "N1I_C2_CELLULAR_MVP_MATERIALIZATION_CONTRACT=PASS"
