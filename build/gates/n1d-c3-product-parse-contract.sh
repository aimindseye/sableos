#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DRIVER="$ROOT/build/titan2/qualify-n1d-c3-product-parse.sh"
C3_PROFILE="$ROOT/build/titan2/n1d-c3-composition.env"
PRODUCT="$ROOT/build/titan2/n1d-product-contract.env"

fail() {
    echo "N1D_C3_PRODUCT_PARSE_CONTRACT=FAIL $*" >&2
    exit 1
}

for f in "$DRIVER" "$C3_PROFILE" "$PRODUCT"; do
    [[ -f "$f" ]] || fail "missing_file=$f"
done

bash -n "$DRIVER"

for token in \
    'PRODUCT_PARSE_AUTHORIZED=YES_EXPLICIT' \
    'ANDROID_TARGET_COMPILATION_AUTHORIZED=NO' \
    'NINJA_BUILD_AUTHORIZED=NO' \
    'TARGET_ARTIFACT_BUILD_AUTHORIZED=NO' \
    'NETWORK_FETCH_AUTHORIZED=NO' \
    'DEVICE_CONTACT_AUTHORIZED=NO' \
    'FLASH_AUTHORIZED=NO' \
    'SIGNING_AUTHORIZED=NO' \
    '--authorize-product-parse' \
    'bash "$STAGE_DRIVER" verify' \
    'lunch "$LUNCH_TARGET"' \
    '--dumpvars-mode' \
    'build/make/core/config.mk' \
    'soong_config_set_bool_filter_true_missing' \
    'android_soong_config_vars.mk' \
    'target/product/gsi/Android.bp' \
    'BUILDING_GSI := false' \
    'soong_config_set_bool,gsi,building_gsi' \
    'soong_config_variable("gsi", "building_gsi")' \
    'N1D_C3_SOONG_GSI_SELECTOR_SOURCE_PROOF=PASS' \
        'N1D_C3_PRIOR_BUILD_OUT=PRESENT_ISOLATED' \
    'N1D_C3_PRODUCT_PARSE_IDENTITY=PASS' \
    'N1D_C3_PRODUCT_PARSE_SOONG_GSI_SELECTOR=PASS_DISABLED' \
    'N1D_C3_PRODUCT_PARSE_GRAPHENE_GSI_ADAPTATION=PASS' \
    'N1D_C3_PRODUCT_PARSE_NO_TARGET_ARTIFACTS=PASS' \
    'N1D_C3_PRODUCT_PARSE=PASS'
do
    grep -Fq -- "$token" "$DRIVER" || fail "driver_missing=$token"
done

for token in \
    'N1D_C3_PRODUCT_NAME=sable_titan2_n1d_arm64' \
    'N1D_C3_RELEASE_CONFIG=bp4a' \
    'N1D_C3_FIRST_BUILD_VARIANT=userdebug' \
    'N1D_C3_PRODUCT_DEVICE=gsi_arm64' \
    'N1D_C3_BUILDING_GSI_VALUE=false'
do
    grep -Fxq "$token" "$C3_PROFILE" || fail "profile_missing=$token"
done

for token in \
    'N1D_PRODUCT_CONTRACT_VERSION=4' \
    'N1D_PRODUCT_NAME=sable_titan2_n1d_arm64' \
    'N1D_C3_FIRST_BUILD_RELEASE_CONFIG=bp4a' \
    'N1D_C3_FIRST_BUILD_VARIANT=userdebug' \
    'N1D_C3_BUILD_AUTHORIZED_BY_COMPOSITION_STAGE=NO' \
    'N1D_C3_PRODUCT_DEVICE=gsi_arm64' \
    'N1D_C3_BUILDING_GSI_VALUE=false' \
    'N1D_C3_SOONG_GSI_BUILDING_GSI_ENABLED=NO' \
    'N1D_C3_SOONG_AOSP_SYSTEM_IMAGE_ENABLED=NO'
do
    grep -Fxq "$token" "$PRODUCT" || fail "product_contract_missing=$token"
done

if grep -Eq '^[[:space:]]*(m|make|ninja|adb|fastboot)([[:space:]]|$)' "$DRIVER"; then
    fail "target_build_or_device_command_present"
fi

if grep -Eq 'repo[[:space:]]+sync|curl[[:space:]]|wget[[:space:]]|git[[:space:]]+fetch' "$DRIVER"; then
    fail "network_command_present"
fi

echo "N1D_C3_PRODUCT_PARSE_SHELL_SYNTAX=PASS"
echo "N1D_C3_PRODUCT_PARSE_EXPLICIT_AUTH=PASS"
echo "N1D_C3_PRODUCT_PARSE_STAGE_BINDING=PASS"
echo "N1D_C3_PRODUCT_PARSE_RELEASE_BINDING=PASS"
echo "N1D_C3_PRODUCT_PARSE_GRAPHENE_GSI_BINDING=PASS"
echo "N1D_C3_PRODUCT_PARSE_SOONG_SOURCE_BINDING=PASS"
echo "N1D_C3_PRODUCT_PARSE_NO_TARGET_BUILD=PASS"
echo "N1D_C3_PRODUCT_PARSE_NO_DEVICE_NETWORK=PASS"
echo "N1D_C3_PRODUCT_PARSE_CONTRACT=PASS"
