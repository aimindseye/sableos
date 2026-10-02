#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DRIVER="$ROOT/build/titan2/qualify-n1d-c3-product-parse.sh"
PROFILE="$ROOT/build/titan2/n1d-c3-trebledroid.env"
PHASE="$ROOT/build/titan2/n1d-c3-phase-split.env"
PRODUCT="$ROOT/build/titan2/n1d-product-contract.env"
PREP="$ROOT/build/titan2/prepare-n1d-c3-trebledroid.sh"

fail() {
    echo "N1D_C3_PRODUCT_PARSE_CONTRACT=FAIL $*" >&2
    exit 1
}

for f in "$DRIVER" "$PROFILE" "$PHASE" "$PRODUCT" "$PREP"; do
    [[ -f "$f" ]] || fail "missing_file=$f"
    bash -n "$f" || fail "syntax=$f"
done

for token in \
    'PRODUCT_PARSE_AUTHORIZED=YES_EXPLICIT' \
    'ANDROID_TARGET_COMPILATION_AUTHORIZED=NO' \
    'NETWORK_FETCH_AUTHORIZED=NO' \
    'DEVICE_CONTACT_AUTHORIZED=NO' \
    'FLASH_AUTHORIZED=NO' \
    '--authorize-product-parse' \
    'bash "$PREP" verify' \
    'lunch "$LUNCH_TARGET"' \
    '--dumpvars-mode' \
    "PRODUCT_DEVICE='tdgsi_arm64_ab'" \
    "PRODUCT_BRAND='google'" \
    "PRODUCT_MODEL='TrebleDroid vanilla'" \
    'N1D_C3A_RELEASE_ELIGIBLE=$N1D_C3A_RELEASE_ELIGIBLE' \
    'N1D_C3B_BUILD_AUTHORIZED=$N1D_C3B_BUILD_AUTHORIZED' \
    'N1D_C3_RELEASE_ELIGIBLE=$N1D_C3_RELEASE_ELIGIBLE' \
    'N1D_C3A_TREBLEDROID_PARSE=PASS'
do
    grep -Fq -- "$token" "$DRIVER" || fail "driver_missing=$token"
done

for token in \
    'N1D_C3_GENERATED_PRODUCT=treble_arm64_bvN' \
    'N1D_C3_RELEASE_CONFIG=bp4a' \
    'N1D_C3_FIRST_VARIANT=user'
do
    grep -Fxq "$token" "$PROFILE" || fail "profile_missing=$token"
done

for token in \
    'N1D_C3A_STATUS=SEALED_COMPLETE' \
    'N1D_C3A_RELEASE_ELIGIBLE=NO' \
    'N1D_C3B_BUILD_AUTHORIZED=YES_SYSTEMIMAGE_ONLY_AFTER_STAGE_AND_PARSE'
do
    grep -Fxq "$token" "$PHASE" || fail "phase_missing=$token"
done

for token in \
    'N1D_PRODUCT_CONTRACT_VERSION=6' \
    'N1D_C3_FIRST_BUILD_RELEASE_CONFIG=bp4a' \
    'N1D_C3_FIRST_BUILD_VARIANT=userdebug' \
    'N1D_C3_RELEASE_ELIGIBLE=NO'
do
    grep -Fxq "$token" "$PRODUCT" || fail "product_missing=$token"
done

if grep -Eq '^[[:space:]]*(m|make|ninja|adb|fastboot)([[:space:]]|$)' "$DRIVER"; then
    fail target_build_or_device_command_present
fi
if grep -Eq 'repo[[:space:]]+sync|curl[[:space:]]|wget[[:space:]]|git[[:space:]]+fetch' "$DRIVER"; then
    fail network_command_present
fi
if grep -Fq 'sable_titan2_n1d_arm64' "$DRIVER" "$PROFILE" "$PHASE" "$PRODUCT"; then
    fail retired_handcrafted_product_present
fi

echo "N1D_C3_PRODUCT_PARSE_POLICY_OWNERSHIP=PASS"
echo "N1D_C3_PRODUCT_PARSE_GENERATED_PRODUCT_BINDING=PASS"
echo "N1D_C3_PRODUCT_PARSE_USER_VARIANT_BINDING=PASS"
echo "N1D_C3_PRODUCT_PARSE_NO_TARGET_BUILD=PASS"
echo "N1D_C3_PRODUCT_PARSE_NO_DEVICE_NETWORK=PASS"
echo "N1D_C3_PRODUCT_PARSE_NON_RELEASE=PASS"
echo "N1D_C3A_PRODUCT_PARSE_CONTRACT=PASS_HISTORICAL"
echo "N1D_C3_PRODUCT_PARSE_CONTRACT=PASS"
