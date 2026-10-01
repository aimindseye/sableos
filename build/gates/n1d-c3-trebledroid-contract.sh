#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROFILE="$ROOT/build/titan2/n1d-c3-trebledroid.env"
PRODUCT="$ROOT/build/titan2/n1d-product-contract.env"
BOUNDARY="$ROOT/build/titan2/n1d-restless-security-boundary.env"
MANIFEST="$ROOT/build/titan2/n1d-c3-trebledroid-manifest.xml"
ROM="$ROOT/build/titan2/n1d-c3-sable-rom.mk"
BUILD_ALLOW="$ROOT/build/titan2/n1d-c3-build-patch-allowlist.txt"
RUNTIME_ALLOW="$ROOT/build/titan2/n1d-c3-runtime-patch-allowlist.txt"
PATCH_DIR="$ROOT/patches/android-16-n1d-trebledroid/build-make"
DRIVER="$ROOT/build/titan2/prepare-n1d-c3-trebledroid.sh"

fail() {
    echo "N1D_C3_TREBLEDROID_CONTRACT=FAIL $*" >&2
    exit 1
}

for f in "$PROFILE" "$PRODUCT" "$BOUNDARY" "$MANIFEST" "$ROM"     "$BUILD_ALLOW" "$RUNTIME_ALLOW" "$DRIVER"
do
    [[ -f "$f" ]] || fail "missing_file=$f"
done
[[ -d "$PATCH_DIR" ]] || fail "missing_patch_dir=$PATCH_DIR"

bash -n "$PROFILE" "$PRODUCT" "$BOUNDARY" "$DRIVER"

require_line() {
    local file="$1" line="$2"
    grep -Fxq "$line" "$file" || fail "missing_line=$line file=$file"
}

for required in     'N1D_C3_TREBLEDROID_VERSION=1'     'N1D_C3_GRAPHENEOS_TAG=2026061600'     'N1D_C3_GRAPHENEOS_BUILD_COMMIT=e1c27e0172987898adfcf8416186baf28c693842'     'N1D_C3_RESTLESS_TAG=16.0.0-202606230923'     'N1D_C3_RESTLESS_COMMIT=4adc5766f457849ca37e0b318bced65aef5a2233'     'N1D_C3_GENERATOR=device/phh/treble/generate.sh'     'N1D_C3_GENERATOR_CONFIG=sable'     'N1D_C3_GENERATED_PRODUCT=treble_arm64_bvN'     'N1D_C3_RELEASE_CONFIG=bp4a'     'N1D_C3_FIRST_VARIANT=user'     'N1D_C3_FIRST_GOAL=systemimage'     'N1D_C3_SCAFFOLD_PROJECT_COUNT=12'     'N1D_C3_BUILD_MAKE_PATCH_COUNT=9'     'N1D_C3_RUNTIME_PATCH_ALLOWLIST_COUNT=0'     'N1D_C3_PHH_BUILD_SCAFFOLD_ALLOWED=YES_PINNED_ONLY'     'N1D_C3_PHH_RUNTIME_PATCH_AUTOAPPLY_ALLOWED=NO'     'N1D_C3_RESTLESS_RUNTIME_PATCH_AUTOAPPLY_ALLOWED=NO'     'N1D_C3_PRIVATE_VENDOR_ALLOWED=NO'     'N1D_C3_RELEASE_ELIGIBLE_BY_REBASELINE=NO'     'N1D_C3_TREBLEDROID_PROFILE=PASS'
do
    require_line "$PROFILE" "$required"
done

for required in     'N1D_PRODUCT_CONTRACT_VERSION=4'     'N1D_C3_PRODUCT_GENERATION_MODE=PINNED_TREBLEDROID_GENERATOR'     'N1D_PRODUCT_NAME=treble_arm64_bvN'     'N1D_PRODUCT_GENERATOR=device/phh/treble/generate.sh'     'N1D_DEVICE_PHH_TREBLE_GENERATOR_USED=YES_PINNED'     'N1D_DIRECT_HANDCRAFTED_GSI_PRODUCT_ALLOWED=NO'     'N1D_RESTLESS_FULL_PATCH_TIERS_AUTOAPPLY_ALLOWED=NO'     'N1D_RUNTIME_PATCH_ALLOWLIST_COUNT=0'     'N1D_BUILD_MAKE_PATCH_ALLOWLIST_COUNT=9'     'N1D_C3_RELEASE_ELIGIBLE=NO'     'N1D_C3_RUNTIME_SECURITY_AUDIT_REQUIRED=YES'
do
    require_line "$PRODUCT" "$required"
done

for required in     'N1D_RESTLESS_SECURITY_BOUNDARY_VERSION=3'     'N1D_C3_BUILD_TOPOLOGY=PINNED_TREBLEDROID_GENERATED_PRODUCT'     'N1D_C3_PHH_BUILD_SCAFFOLD_ALLOWED=YES_PINNED_ONLY'     'N1D_C3_DEVICE_PHH_TREBLE_COMMIT=39ba82ef89ff5bf6b22ca8f147dbf317bffa20ed'     'N1D_C3_DEVICE_PHH_TREBLE_GENERATOR_USED=YES'     'N1D_C3_GENERATED_PRODUCT=treble_arm64_bvN'     'N1D_C3_BUILD_MAKE_PATCH_COUNT=9'     'N1D_C3_RUNTIME_PATCH_ALLOWLIST_COUNT=0'     'N1D_C3_PRIVATE_RESTLESS_VENDOR_ALLOWED=NO'     'N1D_C3_PHH_BASE_RUNTIME_SECURITY_TRUST=NO'     'N1D_C3_PHH_INSECURE_DEFAULTS_REQUIRE_AUDIT=YES'     'N1D_C3_RELEASE_ELIGIBLE=NO'
do
    require_line "$BOUNDARY" "$required"
done

project_count="$(grep -c '<project ' "$MANIFEST")"
[[ "$project_count" == 12 ]] || fail "manifest_project_count=$project_count"

for forbidden in     'cawilliamson-priv'     'vendor/cawilliamson-priv'     'vendor/pixel/gsans'
do
    if grep -Fq "$forbidden" "$MANIFEST"; then
        fail "manifest_forbidden=$forbidden"
    fi
done

for required in     'revision="39ba82ef89ff5bf6b22ca8f147dbf317bffa20ed"'     'revision="dc599b67cc1e7e9a62ca15eef605e3b2546d0d42"'     'revision="204f1bad00aaf480ba33233f7b8c2ddaa03155dd"'     'revision="bef5d37dda9360940964f097d612c8032e140961"'     'revision="5f9884aa352825291757dfd6694b874ad8c1805e"'     'revision="96acf04e74d42a08cc841688686ad3c5d8bd5790"'     'revision="bb0bbb9e1314e5312f718ca1d3ea320137d14370"'     'revision="a2271d260e226e8de5cb1e8c15a229dc90c007dd"'
do
    grep -Fq "$required" "$MANIFEST" || fail "manifest_pin_missing=$required"
done

build_count="$(awk 'NF && $1 !~ /^#/ {c++} END {print c+0}' "$BUILD_ALLOW")"
runtime_count="$(awk 'NF && $1 !~ /^#/ {c++} END {print c+0}' "$RUNTIME_ALLOW")"
[[ "$build_count" == 9 ]] || fail "build_allow_count=$build_count"
[[ "$runtime_count" == 0 ]] || fail "runtime_allow_count=$runtime_count"

while IFS= read -r patch; do
    [[ -z "$patch" || "$patch" == #* ]] && continue
    [[ -f "$PATCH_DIR/$patch" ]] || fail "patch_missing=$patch"
done < "$BUILD_ALLOW"

grep -Fq '"TrichromeWebView"'     "$PATCH_DIR/0006-Configure-build-for-GrapheneOS-GSI-apps-and-packages.patch"     || fail vanadium_webview_patch_missing
grep -Fq '"TrichromeChrome"'     "$PATCH_DIR/0006-Configure-build-for-GrapheneOS-GSI-apps-and-packages.patch"     || fail vanadium_browser_patch_missing
for removed in Browser2 Camera2 messaging QuickSearchBox; do
    grep -Fq -- "-        \"$removed\""         "$PATCH_DIR/0006-Configure-build-for-GrapheneOS-GSI-apps-and-packages.patch"         || fail "graphene_gsi_removal_missing=$removed"
done

grep -Fq 'ro.adb.secure=0'     "$PATCH_DIR/0009-Do-not-disable-adb-authentication-in-GSI-system_ext-.patch"     || fail adb_auth_patch_missing

grep -Fq 'WITH_DEXPREOPT_BOOT_IMG_AND_SYSTEM_SERVER_ONLY := true' "$ROM"     || fail sable_rom_config_missing

for required in     'stage_requires_--authorize-source-mutation'     'stage_requires_--authorize-network'     'SOURCE_MUTATION_AUTHORIZED=YES_PINNED_TREBLEDROID_SCAFFOLD_ONLY'     'NETWORK_FETCH_AUTHORIZED=YES_PINNED_SCAFFOLD_SYNC_ONLY'     'git am "$PATCH_DIR/$patch"'     'bash generate.sh sable'     'N1D_C3_GENERATED_PRODUCT=PASS product=treble_arm64_bvN'     'N1D_C3_RUNTIME_PATCH_ALLOWLIST=PASS_ZERO'     'N1D_C3_TREBLEDROID_STAGE=PASS'
do
    grep -Fq -- "$required" "$DRIVER" || fail "driver_token_missing=$required"
done

if grep -Eq '^[[:space:]]*(m|make|adb|fastboot)([[:space:]]|$)' "$DRIVER"; then
    fail build_or_device_command_in_prep
fi

if grep -Fq 'sable_titan2_n1d_arm64' "$PRODUCT" "$PROFILE" "$DRIVER"; then
    fail retired_handcrafted_product_reintroduced
fi

echo "N1D_C3_TREBLEDROID_SOURCE_PINS=PASS"
echo "N1D_C3_TREBLEDROID_BUILD_PATCHES=PASS count=9"
echo "N1D_C3_TREBLEDROID_RUNTIME_PATCHES=PASS_ZERO"
echo "N1D_C3_TREBLEDROID_PRIVATE_VENDOR=PASS_ABSENT"
echo "N1D_C3_TREBLEDROID_GENERATOR=PASS"
echo "N1D_C3_TREBLEDROID_SECURITY_SEPARATION=PASS"
echo "N1D_C3_TREBLEDROID_CONTRACT=PASS"
