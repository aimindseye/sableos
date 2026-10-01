#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROFILE="$ROOT/build/titan2/n1d-c3-composition.env"
PRODUCT_CONTRACT="$ROOT/build/titan2/n1d-product-contract.env"
BOUNDARY="$ROOT/build/titan2/n1d-restless-security-boundary.env"
BUNDLE="$ROOT/build/titan2/n1d-c3-product"
DRIVER="$ROOT/build/titan2/stage-n1d-c3-product.sh"

fail() { echo "N1D_C3_PRODUCT_COMPOSITION_CONTRACT=FAIL $*" >&2; exit 1; }

for f in "$PROFILE" "$PRODUCT_CONTRACT" "$BOUNDARY" "$DRIVER"; do
    [[ -f "$f" ]] || fail "missing_file=$f"
done
[[ -d "$BUNDLE" ]] || fail "missing_bundle=$BUNDLE"

bash -n "$PROFILE" "$PRODUCT_CONTRACT" "$BOUNDARY" "$DRIVER"

for required in \
    'N1D_C3_COMPOSITION_VERSION=2' \
    'N1D_C3_BASE_SEAL_SHA256=365780be847eba999a72603c501a0f3afcac30dc61f71ce35165d8271dfbf830' \
    'N1D_C3_BASE_PROJECT_COUNT=1033' \
    'N1D_C3_SOURCE_BUNDLE_REL=build/titan2/n1d-c3-product' \
    'N1D_C3_STAGE_TARGET_REL=vendor/sable/n1d' \
    'N1D_C3_PRODUCT_NAME=sable_titan2_n1d_arm64' \
    'N1D_C3_PRODUCT_DEVICE=gsi_arm64' \
    'N1D_C3_BUILDING_GSI_VALUE=false' \
    'N1D_C3_REFRESH_FILE_COUNT=1' \
    'N1D_C3_REQUIRED_STAGE_FILE_COUNT=5' \
    'N1D_C3_INITIAL_TREBLE_COMPAT_ITEM_COUNT=0' \
    'N1D_C3_INITIAL_RESTLESS_PATCH_ALLOWLIST_COUNT=0' \
    'N1D_C3_RELEASE_CONFIG=bp4a' \
    'N1D_C3_FIRST_BUILD_VARIANT=userdebug' \
    'N1D_C3_RELEASE_VARIANT=user' \
    'N1D_C3_BUILD_AUTHORIZED=NO' \
    'N1D_C3_DEVICE_CONTACT_AUTHORIZED=NO' \
    'N1D_C3_FLASH_AUTHORIZED=NO' \
    'N1D_C3_SIGNING_AUTHORIZED=NO' \
    'N1D_C3_NETWORK_FETCH_AUTHORIZED=NO' \
    'N1D_C3_COMPOSITION_CONTRACT=PASS'
do
    grep -Fxq "$required" "$PROFILE" || fail "profile_missing=$required"
done

for required in \
    'N1D_PRODUCT_CONTRACT_VERSION=4' \
    'N1D_RESTLESS_ROLE=REFERENCE_AND_C2_PREBUILT_DIAGNOSTIC_CONTROL' \
    'N1D_C3_PRODUCT_SOURCE_BUNDLE=build/titan2/n1d-c3-product' \
    'N1D_C3_PRODUCT_DEVICE=gsi_arm64' \
    'N1D_C3_GSI_BOARD=build/make/target/board/gsi_arm64/BoardConfig.mk' \
    'N1D_C3_BUILDING_GSI_VALUE=false' \
    'N1D_C3_SOONG_AOSP_SYSTEM_IMAGE_ENABLED=NO' \
    'N1D_C3_PRODUCT_STAGE_TARGET=vendor/sable/n1d' \
    'N1D_C3_STAGE_REQUIRES_BASE_SEAL=YES' \
    'N1D_C3_STAGE_REQUIRES_C2_CONTROL_HASH=YES' \
    'N1D_C3_INITIAL_TREBLE_COMPAT_ITEM_COUNT=0' \
    'N1D_C3_FIRST_BUILD_RELEASE_CONFIG=bp4a' \
    'N1D_C3_FIRST_BUILD_VARIANT=userdebug' \
    'N1D_C3_RELEASE_VARIANT=user' \
    'N1D_C3_BUILD_AUTHORIZED_BY_COMPOSITION_STAGE=NO'
do
    grep -Fxq "$required" "$PRODUCT_CONTRACT" || fail "product_contract_missing=$required"
done

for required in \
    'N1D_RESTLESS_SECURITY_BOUNDARY_VERSION=2' \
    'N1D_RESTLESS_ROLE=REFERENCE_AND_C2_PREBUILT_DIAGNOSTIC_CONTROL' \
    'N1D_C2_CONTROL_MODE=PINNED_PREBUILT_RESTLESS_GSI' \
    'N1D_C2_CONTROL_ARTIFACT_SHA256=52ea47d794faf6eafbb49a5f0d2301508757be0e30d1b73e033e1d5185bb492c' \
    'N1D_C2_EXACT_SOURCE_RECONSTRUCTION=BLOCKED_PUBLIC_SOURCE_OBJECT_UNAVAILABLE' \
    'N1D_C3_INITIAL_RESTLESS_PATCH_ALLOWLIST_COUNT=0' \
    'N1D_C3_SELINUX_ENFORCING_REQUIRED=YES' \
    'N1D_C3_NEVERALLOW_ENFORCEMENT_REQUIRED=YES' \
    'N1D_C3_ADB_AUTH_REQUIRED=YES'
do
    grep -Fxq "$required" "$BOUNDARY" || fail "boundary_missing=$required"
done

expected_files=(AndroidProducts.mk sable_titan2_n1d_arm64.mk treble_compat.mk sable_n1d_product_delta.mk restless-patch-allowlist.txt)
actual_count="$(find "$BUNDLE" -maxdepth 1 -type f | wc -l | tr -d " ")"
[[ "$actual_count" == 5 ]] || fail "bundle_file_count=$actual_count"
for name in "${expected_files[@]}"; do
    [[ -f "$BUNDLE/$name" ]] || fail "bundle_file_missing=$name"
done

grep -Fq '$(LOCAL_DIR)/sable_titan2_n1d_arm64.mk' "$BUNDLE/AndroidProducts.mk" || fail android_products_registration

python3 - "$BUNDLE/sable_titan2_n1d_arm64.mk" <<'PY'
from pathlib import Path
import sys
text = Path(sys.argv[1]).read_text(encoding="utf-8")
ordered = [
    "$(call inherit-product, $(SRC_TARGET_DIR)/product/generic_system_arm64.mk)",
    "$(call inherit-product, $(SRC_TARGET_DIR)/product/gsi_release.mk)",
    "$(call inherit-product, vendor/sable/n1d/treble_compat.mk)",
    "$(call inherit-product, vendor/sable/n1d/sable_n1d_product_delta.mk)",
]
indices = []
for token in ordered:
    if text.count(token) != 1:
        raise SystemExit(f"N1D_C3_PRODUCT_INHERITANCE=FAIL token={token}")
    indices.append(text.index(token))
if indices != sorted(indices):
    raise SystemExit("N1D_C3_PRODUCT_INHERITANCE=FAIL order")
print("N1D_C3_PRODUCT_INHERITANCE=PASS")
PY

for required in \
    'PRODUCT_NAME := sable_titan2_n1d_arm64' \
    'BUILDING_GSI := false' \
    'PRODUCT_DEVICE := gsi_arm64' \
    'PRODUCT_BRAND := SableOS' \
    'PRODUCT_MODEL := SableOS Titan 2 N1D' \
    'PRODUCT_MANUFACTURER := SableOS'
do
    grep -Fxq "$required" "$BUNDLE/sable_titan2_n1d_arm64.mk" || fail "product_identity_missing=$required"
done

compat_count="$(awk 'NF && $1 !~ /^#/ { count++ } END { print count+0 }' "$BUNDLE/treble_compat.mk")"
allow_count="$(awk 'NF && $1 !~ /^#/ { count++ } END { print count+0 }' "$BUNDLE/restless-patch-allowlist.txt")"
[[ "$compat_count" == 0 ]] || fail "initial_treble_compat_nonzero=$compat_count"
[[ "$allow_count" == 0 ]] || fail "initial_restless_allowlist_nonzero=$allow_count"

for forbidden in \
    'device/phh/treble/base.mk' \
    'device/phh/treble/rom.mk' \
    'SELINUX_IGNORE_NEVERALLOWS' \
    'ro.adb.secure=0' \
    'persist.sys.usb.config=adb' \
    'resetprop_phh' \
    'phh-securize' \
    'phh-ota' \
    'phh-remotectl' \
    'vendor/magisk' \
    'QcRilAm' \
    'treble_app'
do
    if grep -R -Fq "$forbidden" "$BUNDLE"; then
        fail "forbidden_c3_bundle_token=$forbidden"
    fi
done

grep -Fq 'stage_requires_--authorize-source-mutation' "$DRIVER" || fail source_mutation_guard_missing
grep -Fq 'SOURCE_MUTATION_AUTHORIZED=YES_EXACT_C3_PRODUCT_BUNDLE_ONLY' "$DRIVER" || fail source_mutation_scope_missing
grep -Fq 'N1D_C3_C2_CONTROL_BINDING=PASS' "$DRIVER" || fail c2_control_binding_missing
grep -Fq 'N1D_C3_BASE_HEADS=PASS_EXACT' "$DRIVER" || fail base_head_binding_missing
grep -Fq 'N1D_C3_STAGED_BUNDLE=PASS' "$DRIVER" || fail staged_bundle_verify_missing
grep -Fq 'N1D_C3_PRODUCT_STAGE=PASS' "$DRIVER" || fail stage_pass_missing

if grep -Eq '(^|[[:space:]])(adb|fastboot|lunch|m|make)([[:space:]]|$)' "$DRIVER"; then
    fail build_or_device_command_present
fi
if grep -Eq 'repo[[:space:]]+sync|curl[[:space:]]|wget[[:space:]]' "$DRIVER"; then
    fail network_command_present
fi
if grep -Fq '/srv/data/sable-build' "$PROFILE" "$DRIVER"; then
    fail legacy_build_root_hardcoded
fi

echo "N1D_C3_PRODUCT_COMPOSITION_SHELL_SYNTAX=PASS"
echo "N1D_C3_PRODUCT_COMPOSITION_BASE_BINDING=PASS"
echo "N1D_C3_PRODUCT_COMPOSITION_C2_CONTROL_BINDING=PASS"
echo "N1D_C3_PRODUCT_COMPOSITION_PRODUCT_REGISTRATION=PASS"
echo "N1D_C3_PRODUCT_COMPOSITION_ZERO_COMPAT_DELTA=PASS"
echo "N1D_C3_PRODUCT_COMPOSITION_ZERO_RESTLESS_PATCHES=PASS"
echo "N1D_C3_PRODUCT_COMPOSITION_SECURITY_EXCLUSIONS=PASS"
echo "N1D_C3_PRODUCT_COMPOSITION_NO_BUILD_DEVICE_NETWORK=PASS"
echo "N1D_C3_PRODUCT_COMPOSITION_CONTRACT=PASS"
