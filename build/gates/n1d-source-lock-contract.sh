#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOCK="$ROOT/build/titan2/n1d-source-lock.env"
PRODUCT="$ROOT/build/titan2/n1d-product-contract.env"

fail() {
    echo "N1D_SOURCE_LOCK_CONTRACT=FAIL $*"
    exit 1
}

[[ -f "$LOCK" ]] || fail "missing_lock=$LOCK"
[[ -f "$PRODUCT" ]] || fail "missing_product_contract=$PRODUCT"

bash -n "$LOCK"

require_line() {
    local file="$1" line="$2"
    grep -Fxq "$line" "$file" || fail "missing_line=$line file=$file"
}

for required in \
    'N1D_SOURCE_LOCK_VERSION=1' \
    'N1D_ANDROID_MAJOR=16' \
    'N1D_PLATFORM_SDK=36' \
    'N1D_AOSP_REVISION=android-16.0.0_r4' \
    'N1D_RELEASE_CONFIG=bp4a' \
    'N1D_GRAPHENEOS_TAG=2026061600' \
    'N1D_GRAPHENEOS_TAG_OBJECT=d1d40ac250f31b1a92989d06fa524425c264081d' \
    'N1D_GRAPHENEOS_MANIFEST_COMMIT=5d82aa9610855bc0b43b9eb7ca4470d30455cfeb' \
    'N1D_GRAPHENEOS_REVISION_BRANCH=16-qpr2' \
    'N1D_RESTLESS_TAG=16.0.0-202606230923' \
    'N1D_RESTLESS_COMMIT=4adc5766f457849ca37e0b318bced65aef5a2233' \
    'N1D_RESTLESS_REFERENCE_BRANCH=android-16.2' \
    'N1D_RESTLESS_SOURCE_ROLE=PINNED_TREBLE_COMPATIBILITY_REFERENCE' \
    'N1D_RESTLESS_DEFAULT_BRANCH_ALLOWED=NO' \
    'N1D_RESTLESS_DYNAMIC_GRAPHENE_TAG_ALLOWED=NO' \
    'N1D_RESTLESS_UPSTREAM_SYNC_SCRIPT_ALLOWED=NO' \
    'N1D_RESTLESS_PUBLIC_ONLY_REQUIRED=YES' \
    'N1D_RESTLESS_PRIVATE_VENDOR_ALLOWED=NO' \
    'N1D_PATCH_APPLICATION_MODE=REPO_OWNED_REVIEWED_ALLOWLIST' \
    'N1D_PATCH_TIER_AUTOAPPLY_ALLOWED=NO' \
    'N1D_SELINUX_PERMISSIVE_DOMAINS_ALLOWED=NO' \
    'N1D_ANDROID17_SOURCE_ALLOWED=NO' \
    'N1D_SOURCE_SYNC_MUST_EMIT_PINNED_MANIFEST=YES' \
    'N1D_SOURCE_DIRTY_PROJECT_COUNT_REQUIRED=0' \
    'N1D_PREEXISTING_ANDROID_OUT_ALLOWED=NO' \
    'N1D_HISTORICAL_WORKSPACE_AS_SOURCE_ALLOWED=NO' \
    'N1D_BUILD_SPECIFIC_HOST_TOOLS_ALLOWED=NO' \
    'N1D_SOURCE_LOCK=PASS'
do
    require_line "$LOCK" "$required"
done

# The source lock must never encode floating resolution semantics.
if grep -Eiq '=(latest|stable|main|master)$|resolve.*latest|current.*tag' "$LOCK"; then
    fail "floating_source_reference"
fi

# N1D uses a Sable-owned GSI product. Restless/Treble is a pinned reference
# and diagnostic control rather than a directly inherited C3 product base.
for required in \
    'N1D_SOURCE_LOCK_FILE=build/titan2/n1d-source-lock.env' \
    'N1D_RESTLESS_SECURITY_BOUNDARY_FILE=build/titan2/n1d-restless-security-boundary.env' \
    'N1D_SOURCE_SUBSTRATE=GRAPHENEOS_A16_PINNED' \
    'N1D_RESTLESS_ROLE=REFERENCE_AND_C2_DIAGNOSTIC_CONTROL' \
    'N1D_RESTLESS_PATCH_POLICY=DENY_BY_DEFAULT_EVIDENCE_ADMIT' \
    'N1D_PRODUCT_NAME=sable_titan2_n1d_arm64' \
    'N1D_AOSP_GSI_BASE=build/make/target/product/generic_system_arm64.mk' \
    'N1D_GSI_RELEASE_INCLUDE=build/make/target/product/gsi_release.mk' \
    'N1D_TREBLE_COMPAT_REFERENCE=device/phh/treble' \
    'N1D_TREBLE_COMPAT_DELTA=vendor/sable/n1d/treble_compat.mk' \
    'N1D_SABLE_DELTA=vendor/sable/n1d/sable_n1d_product_delta.mk' \
    'N1D_DIRECT_DEVICE_PHH_TREBLE_BASE_INHERIT=NO' \
    'N1D_DEVICE_PHH_TREBLE_GENERATOR_USED=NO' \
    'N1D_RESTLESS_ROM_MK_DIRECT_INHERIT=NO' \
    'N1D_STOCK_VENDOR_PRESERVE=YES' \
    'N1D_PRODUCT_CONTRACT=PASS'
do
    require_line "$PRODUCT" "$required"
done

if grep -Eq 'android-17|2026061800|202609[0-9]{4}' "$LOCK"; then
    fail "android17_source_reference_present"
fi

if grep -Fq 'vendor/cawilliamson-priv' "$LOCK"; then
    fail "private_restless_vendor_present"
fi

echo "N1D_SOURCE_LOCK_ANDROID16=PASS"
echo "N1D_SOURCE_LOCK_GRAPHENE_PIN=PASS"
echo "N1D_SOURCE_LOCK_RESTLESS_PIN=PASS"
echo "N1D_SOURCE_LOCK_NO_FLOATING_TAG=PASS"
echo "N1D_SOURCE_LOCK_PUBLIC_ONLY=PASS"
echo "N1D_SOURCE_LOCK_PATCH_ALLOWLIST_POLICY=PASS"
echo "N1D_SOURCE_LOCK_PRODUCT_GRAPH_ALIGNMENT=PASS"
bash "$ROOT/build/gates/n1d-restless-security-boundary-contract.sh"
echo "N1D_SOURCE_LOCK_RESTLESS_SECURITY_BOUNDARY=PASS"
echo "N1D_SOURCE_LOCK_CONTRACT=PASS"
