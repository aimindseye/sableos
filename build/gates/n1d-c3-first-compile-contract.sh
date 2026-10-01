#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DRIVER="$ROOT/build/titan2/build-n1d-c3-first-systemimage.sh"
PROFILE="$ROOT/build/titan2/n1d-c3-compile.env"
C3_PROFILE="$ROOT/build/titan2/n1d-c3-composition.env"
PRODUCT="$ROOT/build/titan2/n1d-product-contract.env"

fail() {
    echo "N1D_C3_FIRST_COMPILE_CONTRACT=FAIL $*" >&2
    exit 1
}

for f in "$DRIVER" "$PROFILE" "$C3_PROFILE" "$PRODUCT"; do
    [[ -f "$f" ]] || fail "missing_file=$f"
done

bash -n "$DRIVER" "$PROFILE"

for required in     'N1D_C3_COMPILE_VERSION=1'     'N1D_C3_COMPILE_PRODUCT=sable_titan2_n1d_arm64'     'N1D_C3_COMPILE_RELEASE_CONFIG=bp4a'     'N1D_C3_COMPILE_VARIANT=userdebug'     'N1D_C3_FIRST_COMPILE_GOAL=systemimage'     'N1D_C3_COMPILE_OUT_REL=workspaces/titan2-n1d/out-c3'     'N1D_C3_SANDBOX_PROBE_OUT_REL=workspaces/titan2-n1d/out-c3-sandbox-probe'     'N1D_C3_COMPILE_NETWORK_FETCH_AUTHORIZED=NO'     'N1D_C3_COMPILE_DEVICE_CONTACT_AUTHORIZED=NO'     'N1D_C3_COMPILE_FLASH_AUTHORIZED=NO'     'N1D_C3_COMPILE_PRODUCTION_SIGNING_AUTHORIZED=NO'     'N1D_C3_COMPILE_TARGET_FILES_AUTHORIZED=NO'     'N1D_C3_COMPILE_OTA_AUTHORIZED=NO'     'N1D_C3_BUILD_SANDBOX_REQUIRED=YES'     'N1D_C3_COMPILE_PROFILE=PASS'
do
    grep -Fxq "$required" "$PROFILE" || fail "profile_missing=$required"
done

for required in     'N1D_C3_PRODUCT_NAME=sable_titan2_n1d_arm64'     'N1D_C3_RELEASE_CONFIG=bp4a'     'N1D_C3_FIRST_BUILD_VARIANT=userdebug'
do
    grep -Fxq "$required" "$C3_PROFILE" || fail "c3_profile_missing=$required"
done

for required in     'N1D_PRODUCT_CONTRACT_VERSION=3'     'N1D_PRODUCT_NAME=sable_titan2_n1d_arm64'     'N1D_C3_FIRST_BUILD_RELEASE_CONFIG=bp4a'     'N1D_C3_FIRST_BUILD_VARIANT=userdebug'     'N1D_C3_BUILD_AUTHORIZED_BY_COMPOSITION_STAGE=NO'
do
    grep -Fxq "$required" "$PRODUCT" || fail "product_contract_missing=$required"
done

for required in     'compile_requires_--authorize-c3-compile'     'BUILD_AUTHORIZED=YES_C3_SYSTEMIMAGE_ONLY'     'IMAGE_BUILD_AUTHORIZED=YES_C3_SYSTEMIMAGE_ONLY'     'TARGET_FILES_BUILD_AUTHORIZED=NO'     'OTA_BUILD_AUTHORIZED=NO'     'NETWORK_FETCH_AUTHORIZED=NO'     'DEVICE_CONTACT_AUTHORIZED=NO'     'FLASH_AUTHORIZED=NO'     'PRODUCTION_SIGNING_AUTHORIZED=NO'     'bash "$STAGE_DRIVER" verify'     'N1D_C3_PRODUCT_PARSE=PASS'     'build_sandbox_nsjail_unavailable'     'N1D_C3_BUILD_SANDBOX_PREFLIGHT=PASS_NSJAIL'     'c3_out_created_by_sandbox_probe='     'm -j"$JOBS" systemimage'     'N1D_C3_BUILD_SANDBOX_SYSTEMIMAGE=PASS_NSJAIL'     'N1D_C3_SYSTEMIMAGE_BUILD=PASS'     'N1D_C3_POST_BUILD_BASE_HEADS=PASS_EXACT'     'N1D_C3_FIRST_COMPILE_NO_TARGET_FILES_OTA=PASS'     'N1D_C3_FIRST_COMPILE_SOURCE_INTEGRITY=PASS'     'N1D_C3_FIRST_COMPILE=PASS'
do
    grep -Fq -- "$required" "$DRIVER" || fail "driver_missing=$required"
done

if grep -Eq 'repo[[:space:]]+sync|curl[[:space:]]|wget[[:space:]]|git[[:space:]]+fetch' "$DRIVER"; then
    fail "network_command_present"
fi

if grep -Eq '^[[:space:]]*(adb|fastboot)([[:space:]]|$)' "$DRIVER"; then
    fail "device_command_present"
fi

if grep -Eq 'target-files-package|otatools|dist([[:space:]]|$)' "$DRIVER"; then
    fail "unauthorized_packaging_goal_present"
fi

compile_lines="$(grep -Ec '^[[:space:]]*m[[:space:]].*systemimage' "$DRIVER" || true)"
[[ "$compile_lines" == 1 ]] || fail "systemimage_compile_invocation_count=$compile_lines"

echo "N1D_C3_FIRST_COMPILE_SHELL_SYNTAX=PASS"
echo "N1D_C3_FIRST_COMPILE_PROFILE_BINDING=PASS"
echo "N1D_C3_FIRST_COMPILE_PARSE_BINDING=PASS"
echo "N1D_C3_FIRST_COMPILE_EXPLICIT_AUTH=PASS"
echo "N1D_C3_FIRST_COMPILE_SYSTEMIMAGE_ONLY=PASS"
echo "N1D_C3_FIRST_COMPILE_SANDBOX_REQUIRED=PASS"
echo "N1D_C3_FIRST_COMPILE_NO_DEVICE_NETWORK=PASS"
echo "N1D_C3_FIRST_COMPILE_POST_BUILD_INTEGRITY=PASS"
echo "N1D_C3_FIRST_COMPILE_CONTRACT=PASS"
