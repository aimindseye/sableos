#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DRIVER="$ROOT/build/titan2/build-n1d-c3-trebledroid-systemimage.sh"
PROFILE="$ROOT/build/titan2/n1d-c3-trebledroid.env"
PRODUCT="$ROOT/build/titan2/n1d-product-contract.env"

fail() {
    echo "N1D_C3_TREBLEDROID_BUILD_CONTRACT=FAIL $*" >&2
    exit 1
}

for f in "$DRIVER" "$PROFILE" "$PRODUCT"; do
    [[ -f "$f" ]] || fail "missing_file=$f"
done
bash -n "$DRIVER" "$PROFILE" "$PRODUCT"

for token in     'compile_requires_--authorize-c3-compile'     'BUILD_AUTHORIZED=YES_SYSTEMIMAGE_ONLY'     'TARGET_FILES_BUILD_AUTHORIZED=NO'     'OTA_BUILD_AUTHORIZED=NO'     'NETWORK_FETCH_AUTHORIZED=NO'     'DEVICE_CONTACT_AUTHORIZED=NO'     'FLASH_AUTHORIZED=NO'     'PRODUCTION_SIGNING_AUTHORIZED=NO'     'RELEASE_ELIGIBLE=NO'     'bash "$PREP" verify'     'N1D_C3_GENERATED_PRODUCT=treble_arm64_bvN'     'N1D_C3_RELEASE_CONFIG=bp4a'     'N1D_C3_FIRST_VARIANT=user'     'm -j"$JOBS" systemimage'     'N1D_C3_TREBLEDROID_SYSTEMIMAGE=PASS'
do
    grep -Fq -- "$token" "$DRIVER" "$PROFILE" || fail "missing_token=$token"
done

for token in     'N1D_PRODUCT_CONTRACT_VERSION=4'     'N1D_PRODUCT_NAME=treble_arm64_bvN'     'N1D_C3_FIRST_BUILD_VARIANT=user'     'N1D_C3_FIRST_BUILD_GOAL=systemimage'     'N1D_C3_RELEASE_ELIGIBLE=NO'
do
    grep -Fxq "$token" "$PRODUCT" || fail "product_missing=$token"
done

compile_count="$(grep -Ec '^[[:space:]]*m[[:space:]].*systemimage' "$DRIVER" || true)"
[[ "$compile_count" == 1 ]] || fail "systemimage_invocation_count=$compile_count"

if grep -Eq 'target-files-package|otatools|(^|[[:space:]])dist([[:space:]]|$)' "$DRIVER"; then
    fail unauthorized_packaging_goal_present
fi
if grep -Eq '^[[:space:]]*(adb|fastboot)([[:space:]]|$)' "$DRIVER"; then
    fail device_command_present
fi
if grep -Eq 'repo[[:space:]]+sync|curl[[:space:]]|wget[[:space:]]|git[[:space:]]+fetch' "$DRIVER"; then
    fail network_command_present
fi
if grep -Fq 'sable_titan2_n1d_arm64' "$DRIVER" "$PROFILE" "$PRODUCT"; then
    fail retired_handcrafted_product_present
fi

echo "N1D_C3_TREBLEDROID_BUILD_SYSTEMIMAGE_ONLY=PASS"
echo "N1D_C3_TREBLEDROID_BUILD_NO_PACKAGING=PASS"
echo "N1D_C3_TREBLEDROID_BUILD_NO_DEVICE_NETWORK=PASS"
echo "N1D_C3_TREBLEDROID_BUILD_NON_RELEASE=PASS"
echo "N1D_C3_TREBLEDROID_BUILD_CONTRACT=PASS"
