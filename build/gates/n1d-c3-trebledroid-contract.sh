#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROFILE="$ROOT/build/titan2/n1d-c3-trebledroid.env"
PRODUCT="$ROOT/build/titan2/n1d-product-contract.env"
BOUNDARY="$ROOT/build/titan2/n1d-restless-security-boundary.env"
MANIFEST="$ROOT/build/titan2/n1d-c3-trebledroid-manifest.xml"
ROM="$ROOT/build/titan2/n1d-c3-sable-rom.mk"
TIERS="$ROOT/build/titan2/n1d-c3-control-patch-tiers.tsv"
BUILD_ALLOW="$ROOT/build/titan2/n1d-c3-build-patch-allowlist.txt"
RUNTIME_ALLOW="$ROOT/build/titan2/n1d-c3-runtime-patch-allowlist.txt"
BUILD_PATCH_DIR="$ROOT/patches/android-16-n1d-trebledroid/build-make"
DRIVER="$ROOT/build/titan2/prepare-n1d-c3-trebledroid.sh"

fail() {
    echo "N1D_C3_TREBLEDROID_CONTRACT=FAIL $*" >&2
    exit 1
}

for f in "$PROFILE" "$PRODUCT" "$BOUNDARY" "$MANIFEST" "$ROM"     "$TIERS" "$BUILD_ALLOW" "$RUNTIME_ALLOW" "$DRIVER"
do
    [[ -f "$f" ]] || fail "missing_file=$f"
done
[[ -d "$BUILD_PATCH_DIR" ]] || fail "missing_build_patch_dir=$BUILD_PATCH_DIR"

bash -n "$PROFILE" "$PRODUCT" "$BOUNDARY" "$DRIVER"

require_line() {
    local file="$1" line="$2"
    grep -Fxq "$line" "$file" || fail "missing_line=$line file=$file"
}

for required in     'N1D_C3_TREBLEDROID_VERSION=2'     'N1D_C3_GRAPHENEOS_TAG=2026061600'     'N1D_C3_GRAPHENEOS_BUILD_COMMIT=e1c27e0172987898adfcf8416186baf28c693842'     'N1D_C3_RESTLESS_TAG=16.0.0-202606230923'     'N1D_C3_RESTLESS_COMMIT=4adc5766f457849ca37e0b318bced65aef5a2233'     'N1D_C3_GENERATOR=device/phh/treble/generate.sh'     'N1D_C3_GENERATOR_CONFIG=rom'     'N1D_C3_GENERATED_PRODUCT=treble_arm64_bvN'     'N1D_C3_RELEASE_CONFIG=bp4a'     'N1D_C3_FIRST_VARIANT=user'     'N1D_C3_FIRST_GOAL=systemimage'     'N1D_C3_TREBLE_APP_BUILD_REQUIRED=YES_RELEASE_PREBUILD'     'N1D_C3_TREBLE_APP_BUILD_COMMAND=bash_build.sh_release'     'N1D_C3_TREBLE_APP_NETWORK_REQUIRES_EXPLICIT_AUTH=YES'     'N1D_C3_SCAFFOLD_PROJECT_COUNT=12'     'N1D_C3_SCAFFOLD_PIN_PROVENANCE=RECONSTRUCTED_RELEASE_TIME_BRANCH_TIPS_NO_PUBLISHED_MANIFEST'     'N1D_C3_CONTROL_PATCH_TIER_COUNT=5'     'N1D_C3_CONTROL_PATCH_COUNT=369'     'N1D_C3_BUILD_MAKE_PATCH_COUNT=9'     'N1D_C3_RUNTIME_PATCH_ALLOWLIST_COUNT=0'     'N1D_C3_PHH_BUILD_SCAFFOLD_ALLOWED=YES_PINNED_ONLY'     'N1D_C3_CONTROL_FULL_RESTLESS_PATCH_STACK_ALLOWED=YES_PINNED_CONTROL_ONLY'     'N1D_C3_PHH_RUNTIME_PATCH_AUTOAPPLY_ALLOWED=NO_FOR_RELEASE'     'N1D_C3_RESTLESS_RUNTIME_PATCH_AUTOAPPLY_ALLOWED=NO_FOR_RELEASE'     'N1D_C3_PRIVATE_VENDOR_ALLOWED=NO'     'N1D_C3_RELEASE_ELIGIBLE_BY_REBASELINE=NO'     'N1D_C3_TREBLEDROID_PROFILE=PASS'
do
    require_line "$PROFILE" "$required"
done

for required in     'N1D_PRODUCT_CONTRACT_VERSION=4'     'N1D_C3_PRODUCT_GENERATION_MODE=PINNED_TREBLEDROID_GENERATOR'     'N1D_PRODUCT_NAME=treble_arm64_bvN'     'N1D_PRODUCT_GENERATOR=device/phh/treble/generate.sh'     'N1D_DEVICE_PHH_TREBLE_GENERATOR_USED=YES_PINNED'     'N1D_DIRECT_HANDCRAFTED_GSI_PRODUCT_ALLOWED=NO'     'N1D_CONTROL_FULL_RESTLESS_PATCH_TIERS=YES_PINNED_CONTROL_ONLY'     'N1D_RESTLESS_FULL_PATCH_TIERS_AUTOAPPLY_ALLOWED_FOR_RELEASE=NO'     'N1D_CONTROL_PATCH_TIER_COUNT=5'     'N1D_CONTROL_PATCH_COUNT=369'     'N1D_RUNTIME_PATCH_ALLOWLIST_COUNT=0'     'N1D_C3_RELEASE_ELIGIBLE=NO'     'N1D_C3_RUNTIME_SECURITY_AUDIT_REQUIRED=YES'
do
    require_line "$PRODUCT" "$required"
done

tier_count="$(awk 'NF && $1 !~ /^#/ {c++} END {print c+0}' "$TIERS")"
tier_total="$(awk 'NF && $1 !~ /^#/ {s+=$2} END {print s+0}' "$TIERS")"
build_count="$(awk 'NF && $1 !~ /^#/ {c++} END {print c+0}' "$BUILD_ALLOW")"
runtime_count="$(awk 'NF && $1 !~ /^#/ {c++} END {print c+0}' "$RUNTIME_ALLOW")"

[[ "$tier_count" == 5 ]] || fail "tier_count=$tier_count"
[[ "$tier_total" == 369 ]] || fail "tier_total=$tier_total"
[[ "$build_count" == 9 ]] || fail "build_patch_count=$build_count"
[[ "$runtime_count" == 0 ]] || fail "release_runtime_patch_count=$runtime_count"

project_count="$(grep -c '<project ' "$MANIFEST")"
[[ "$project_count" == 12 ]] || fail "manifest_project_count=$project_count"

for forbidden in 'vendor/cawilliamson-priv' 'cawilliamson-priv'; do
    if grep -Fq "$forbidden" "$MANIFEST"; then
        fail "private_source_present=$forbidden"
    fi
done

while IFS= read -r patch; do
    [[ -z "$patch" || "$patch" == #* ]] && continue
    [[ -f "$BUILD_PATCH_DIR/$patch" ]] || fail "focused_build_patch_missing=$patch"
done < "$BUILD_ALLOW"

grep -Fq '"TrichromeWebView"'     "$BUILD_PATCH_DIR/0006-Configure-build-for-GrapheneOS-GSI-apps-and-packages.patch"     || fail vanadium_webview_patch_missing
grep -Fq '"TrichromeChrome"'     "$BUILD_PATCH_DIR/0006-Configure-build-for-GrapheneOS-GSI-apps-and-packages.patch"     || fail vanadium_browser_patch_missing
for removed in Browser2 Camera2 messaging QuickSearchBox; do
    grep -Fq -- "-        \"$removed\""         "$BUILD_PATCH_DIR/0006-Configure-build-for-GrapheneOS-GSI-apps-and-packages.patch"         || fail "graphene_gsi_removal_missing=$removed"
done

grep -Fq '$(call inherit-product-if-exists, vendor/pixel/gsans/common/common-vendor.mk)' "$ROM"     || fail control_rom_optional_gsans_missing
grep -Fq 'WITH_DEXPREOPT_BOOT_IMG_AND_SYSTEM_SERVER_ONLY := true' "$ROM"     || fail control_rom_dexpreopt_missing

for required in     'stage_requires_--authorize-source-mutation'     'stage_requires_--authorize-network'     'SOURCE_MUTATION_AUTHORIZED=YES_PINNED_RESTLESS_CONTROL_RECIPE_ONLY'     'NETWORK_FETCH_AUTHORIZED=YES_PINNED_RECIPE_AND_SCAFFOLD_ONLY'     'N1D_C3_CONTROL_PATCH_STACK=PASS count=$applied'     'bash generate.sh rom'     'N1D_C3_GENERATED_PRODUCT=PASS product=treble_arm64_bvN'     'N1D_C3_RELEASE_RUNTIME_PATCH_ALLOWLIST=PASS_ZERO'     'N1D_C3_TREBLEDROID_STAGE=PASS'
do
    grep -Fq -- "$required" "$DRIVER" || fail "driver_token_missing=$required"
done

if grep -Eq '^[[:space:]]*(m|make|adb|fastboot)([[:space:]]|$)' "$DRIVER"; then
    fail build_or_device_command_in_prep
fi
if grep -Fq 'sable_titan2_n1d_arm64' "$PROFILE" "$PRODUCT" "$DRIVER"; then
    fail retired_handcrafted_product_reintroduced
fi

echo "N1D_C3_TREBLEDROID_SOURCE_PINS=PASS"
echo "N1D_C3_TREBLEDROID_CONTROL_PATCH_TIERS=PASS count=5"
echo "N1D_C3_TREBLEDROID_CONTROL_PATCH_STACK=PASS count=369"
echo "N1D_C3_TREBLEDROID_BUILD_PATCH_AUDIT_SET=PASS count=9"
echo "N1D_C3_TREBLEDROID_RELEASE_RUNTIME_PATCHES=PASS_ZERO"
echo "N1D_C3_TREBLEDROID_PRIVATE_VENDOR=PASS_ABSENT"
echo "N1D_C3_TREBLEDROID_GENERATOR=PASS"
echo "N1D_C3_TREBLEDROID_SECURITY_SEPARATION=PASS"
echo "N1D_C3_TREBLEDROID_CONTRACT=PASS"
