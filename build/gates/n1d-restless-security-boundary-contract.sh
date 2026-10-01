#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BOUNDARY="$ROOT/build/titan2/n1d-restless-security-boundary.env"
PRODUCT="$ROOT/build/titan2/n1d-product-contract.env"
DOC="$ROOT/docs/titan2/N1D_RESTLESS_SECURITY_BOUNDARY_R1.md"

fail() {
    echo "N1D_RESTLESS_SECURITY_BOUNDARY_CONTRACT=FAIL $*"
    exit 1
}

for f in "$BOUNDARY" "$PRODUCT" "$DOC"; do
    [[ -f "$f" ]] || fail "missing_file=$f"
done

bash -n "$BOUNDARY"
bash -n "$PRODUCT"

require_line() {
    local file="$1" line="$2"
    grep -Fxq "$line" "$file" || fail "missing_line=$line file=$file"
}

for required in \
    'N1D_RESTLESS_SECURITY_BOUNDARY_VERSION=2' \
    'N1D_RESTLESS_ROLE=REFERENCE_AND_C2_PREBUILT_DIAGNOSTIC_CONTROL' \
    'N1D_C2_CONTROL_MODE=PINNED_PREBUILT_RESTLESS_GSI' \
    'N1D_C2_CONTROL_SOURCE=PINNED_PUBLISHED_RESTLESS_ANDROID16_GSI' \
    'N1D_C2_CONTROL_TAG=16.0.0-202606230923' \
    'N1D_C2_CONTROL_COMMIT=4adc5766f457849ca37e0b318bced65aef5a2233' \
    'N1D_C2_CONTROL_ARTIFACT_SHA256=52ea47d794faf6eafbb49a5f0d2301508757be0e30d1b73e033e1d5185bb492c' \
    'N1D_C2_EXACT_SOURCE_RECONSTRUCTION=BLOCKED_PUBLIC_SOURCE_OBJECT_UNAVAILABLE' \
    'N1D_C2_CONTROL_SECURITY_CLAIM=NO' \
    'N1D_C2_CONTROL_SABLE_RELEASE_ARTIFACT=NO' \
    'N1D_C3_PRODUCT_OWNER=SABLEOS' \
    'N1D_C3_AOSP_GSI_BASE=build/make/target/product/generic_system_arm64.mk' \
    'N1D_C3_GSI_RELEASE_INCLUDE=build/make/target/product/gsi_release.mk' \
    'N1D_C3_TREBLE_COMPAT_DELTA=vendor/sable/n1d/treble_compat.mk' \
    'N1D_C3_DIRECT_DEVICE_PHH_TREBLE_BASE_INHERIT=NO' \
    'N1D_C3_DEVICE_PHH_TREBLE_GENERATOR_USED=NO' \
    'N1D_C3_RESTLESS_ROM_MK_DIRECT_INHERIT=NO' \
    'N1D_C3_RESTLESS_PATCH_POLICY=DENY_BY_DEFAULT_EVIDENCE_ADMIT' \
    'N1D_C3_INITIAL_RESTLESS_PATCH_ALLOWLIST_COUNT=0' \
    'N1D_C3_SELINUX_ENFORCING_REQUIRED=YES' \
    'N1D_C3_NEVERALLOW_ENFORCEMENT_REQUIRED=YES' \
    'N1D_C3_SELINUX_IGNORE_NEVERALLOWS_ALLOWED=NO' \
    'N1D_C3_PERMISSIVE_DOMAINS_ALLOWED=NO' \
    'N1D_C3_ADB_AUTH_REQUIRED=YES' \
    'N1D_C3_RO_ADB_SECURE_ZERO_ALLOWED=NO' \
    'N1D_C3_DEFAULT_USB_ADB_ALLOWED=NO' \
    'N1D_C3_PHHSU_ALLOWED=NO' \
    'N1D_C3_RESETPROP_PHH_ALLOWED=NO' \
    'N1D_C3_PHH_SECURIZE_ALLOWED=NO' \
    'N1D_C3_PHH_OTA_ALLOWED=NO' \
    'N1D_C3_PHH_REMOTE_DEBUG_ALLOWED=NO' \
    'N1D_C3_TREBLEAPP_ALLOWED=NO' \
    'N1D_C3_LEGACY_VNDK_28_29_ALLOWED=NO' \
    'N1D_C3_VENDOR_MAGISK_ALLOWED=NO' \
    'N1D_C3_QCRILAM_ALLOWED=NO' \
    'N1D_C3_PRIVATE_RESTLESS_VENDOR_ALLOWED=NO' \
    'N1D_RESTLESS_SECURITY_BOUNDARY=PASS'
do
    require_line "$BOUNDARY" "$required"
done

for required in \
    'N1D_PRODUCT_CONTRACT_VERSION=4' \
    'N1D_RESTLESS_SECURITY_BOUNDARY_FILE=build/titan2/n1d-restless-security-boundary.env' \
    'N1D_SOURCE_SUBSTRATE=GRAPHENEOS_A16_PINNED' \
    'N1D_RESTLESS_ROLE=REFERENCE_AND_C2_PREBUILT_DIAGNOSTIC_CONTROL' \
    'N1D_RESTLESS_PATCH_POLICY=DENY_BY_DEFAULT_EVIDENCE_ADMIT' \
    'N1D_PRODUCT_NAME=sable_titan2_n1d_arm64' \
  'N1D_C3_PRODUCT_DEVICE=gsi_arm64' \
  'N1D_C3_GSI_BOARD=build/make/target/board/gsi_arm64/BoardConfig.mk' \
  'N1D_C3_BUILDING_GSI_VALUE=false' \
  'N1D_C3_SOONG_AOSP_SYSTEM_IMAGE_ENABLED=NO' \
    'N1D_AOSP_GSI_BASE=build/make/target/product/generic_system_arm64.mk' \
    'N1D_GSI_RELEASE_INCLUDE=build/make/target/product/gsi_release.mk' \
    'N1D_TREBLE_COMPAT_REFERENCE=device/phh/treble' \
    'N1D_TREBLE_COMPAT_DELTA=vendor/sable/n1d/treble_compat.mk' \
    'N1D_SABLE_DELTA=vendor/sable/n1d/sable_n1d_product_delta.mk' \
    'N1D_C3_COMPOSITION_PROFILE_FILE=build/titan2/n1d-c3-composition.env' \
    'N1D_C3_PRODUCT_SOURCE_BUNDLE=build/titan2/n1d-c3-product' \
    'N1D_C3_PRODUCT_STAGE_TARGET=vendor/sable/n1d' \
    'N1D_C3_STAGE_REQUIRES_BASE_SEAL=YES' \
    'N1D_C3_STAGE_REQUIRES_C2_CONTROL_HASH=YES' \
    'N1D_C3_INITIAL_TREBLE_COMPAT_ITEM_COUNT=0' \
    'N1D_C3_BUILD_AUTHORIZED_BY_COMPOSITION_STAGE=NO' \
    'N1D_DIRECT_DEVICE_PHH_TREBLE_BASE_INHERIT=NO' \
    'N1D_DEVICE_PHH_TREBLE_GENERATOR_USED=NO' \
    'N1D_RESTLESS_ROM_MK_DIRECT_INHERIT=NO' \
    'N1D_INITIAL_RESTLESS_PATCH_ALLOWLIST_COUNT=0' \
    'N1D_SELINUX_ENFORCING_REQUIRED=YES' \
    'N1D_NEVERALLOW_ENFORCEMENT_REQUIRED=YES' \
    'N1D_ADB_AUTH_REQUIRED=YES' \
    'N1D_PRODUCT_CONTRACT=PASS'
do
    require_line "$PRODUCT" "$required"
done

# C3/N1D must not silently fall back to the historical universal-Treble product.
for forbidden in \
    'N1D_BASE_PRODUCT=treble_arm64_bvN' \
    'N1D_PRODUCT_GENERATOR=device/phh/treble/generate.sh' \
    'N1D_TREBLE_BASE=device/phh/treble/base.mk' \
    'N1D_RESTLESS_DELTA=device/phh/treble/rom.mk'
do
    if grep -Fxq "$forbidden" "$PRODUCT"; then
        fail "legacy_direct_treble_product_contract=$forbidden"
    fi
done

# These compatibility mechanisms are explicitly outside the C3 product baseline.
for forbidden in \
    'SELINUX_IGNORE_NEVERALLOWS := true' \
    'ro.adb.secure=0' \
    'persist.sys.usb.config=adb' \
    'resetprop_phh' \
    'phh-securize.sh' \
    'phh-ota' \
    'phh-remotectl' \
    'vendor/magisk' \
    'QcRilAm'
do
    if grep -Fq "$forbidden" "$PRODUCT" "$BOUNDARY"; then
        fail "forbidden_c3_mechanism_token=$forbidden"
    fi
done

echo "N1D_RESTLESS_C2_CONTROL_SEPARATION=PASS"
echo "N1D_RESTLESS_C3_SABLE_PRODUCT_OWNERSHIP=PASS"
echo "N1D_RESTLESS_C3_NO_DIRECT_PHH_BASE=PASS"
echo "N1D_RESTLESS_C3_DENY_BY_DEFAULT_PATCH_POLICY=PASS"
echo "N1D_RESTLESS_C3_SELINUX_BOUNDARY=PASS"
echo "N1D_RESTLESS_C3_ADB_BOUNDARY=PASS"
echo "N1D_RESTLESS_C3_LEGACY_COMPAT_EXCLUSION=PASS"
echo "N1D_RESTLESS_SECURITY_BOUNDARY_CONTRACT=PASS"
