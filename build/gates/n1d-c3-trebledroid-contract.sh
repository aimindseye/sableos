#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROFILE="$ROOT/build/titan2/n1d-c3-trebledroid.env"
PRODUCT="$ROOT/build/titan2/n1d-product-contract.env"
BOUNDARY="$ROOT/build/titan2/n1d-restless-security-boundary.env"
ADD_MANIFEST="$ROOT/build/titan2/n1d-c3a-trebledroid-add.xml"
REMOVE_MANIFEST="$ROOT/build/titan2/n1d-c3a-trebledroid-remove.xml"
REMOVE_MAP="$ROOT/build/titan2/n1d-c3a-remove-projects.tsv"
ROM="$ROOT/build/titan2/n1d-c3a-control-rom.mk"
TIERS="$ROOT/build/titan2/n1d-c3-control-patch-tiers.tsv"
BUILD_AUDIT_SET="$ROOT/build/titan2/n1d-c3a-build-make-audit-set.txt"
BUILD_AUDIT_BLOBS="$ROOT/build/titan2/n1d-c3a-build-make-audit-blobs.tsv"
C3B_RUNTIME_ALLOWLIST="$ROOT/build/titan2/n1d-c3b-runtime-patch-allowlist.txt"
BUILD_PATCH_DIR="$ROOT/patches/android-16-n1d-trebledroid/build-make"
DRIVER="$ROOT/build/titan2/prepare-n1d-c3-trebledroid.sh"

fail() {
    echo "N1D_C3_TREBLEDROID_CONTRACT=FAIL $*" >&2
    exit 1
}

for f in     "$PROFILE" "$PRODUCT" "$BOUNDARY"     "$ADD_MANIFEST" "$REMOVE_MANIFEST" "$REMOVE_MAP"     "$ROM" "$TIERS" "$BUILD_AUDIT_SET" "$BUILD_AUDIT_BLOBS"     "$C3B_RUNTIME_ALLOWLIST" "$DRIVER"
do
    [[ -f "$f" ]] || fail "missing_file=$f"
done
[[ -d "$BUILD_PATCH_DIR" ]] || fail "missing_build_patch_dir=$BUILD_PATCH_DIR"

for f in "$PROFILE" "$PRODUCT" "$BOUNDARY" "$DRIVER"; do
    bash -n "$f" || fail "syntax=$f"
done

require_line() {
    local file="$1"
    local line="$2"
    grep -Fxq "$line" "$file" || fail "missing_line=$line file=$file"
}

for required in     'N1D_C3_TREBLEDROID_VERSION=6'     'N1D_C3_GRAPHENEOS_TAG=2026061600'     'N1D_C3_GRAPHENEOS_BUILD_COMMIT=e1c27e0172987898adfcf8416186baf28c693842'     'N1D_C3_RESTLESS_TAG=16.0.0-202606230923'     'N1D_C3_RESTLESS_COMMIT=4adc5766f457849ca37e0b318bced65aef5a2233'     'N1D_C3_GENERATOR=device/phh/treble/generate.sh'     'N1D_C3_GENERATOR_CONFIG=rom'     'N1D_C3_GENERATED_PRODUCT=treble_arm64_bvN'     'N1D_C3_RELEASE_CONFIG=bp4a'     'N1D_C3_FIRST_VARIANT=user'     'N1D_C3_FIRST_GOAL=systemimage'     'N1D_C3_TREBLE_APP_BUILD_REQUIRED=YES_RELEASE_PREBUILD'     'N1D_C3_TREBLE_APP_BUILD_COMMAND=bash_build.sh_release'     'N1D_C3_TREBLE_APP_NETWORK_REQUIRES_EXPLICIT_AUTH=YES'     'N1D_C3_TREBLE_APP_JDK_MAJOR=17'     'N1D_C3_TREBLE_APP_JDK_SOURCE=SABLE_JDK17'     'N1D_C3_TREBLE_APP_BUILD_RESIDUE_POLICY=SDK_METADATA_AND_LICENSES_ONLY'     'N1D_C3_TREBLE_APP_KNOWN_PACKAGES_BASE_BLOB=7b27183be84845e00318dbbd3aeb60b5d291216b'     'N1D_C3_SCAFFOLD_PROJECT_COUNT=12'     'N1D_C3A_ADD_PROJECT_COUNT=12'     'N1D_C3A_ADD_MANIFEST_BLOB_SHA=654f0dcc8f7a46a1cc7aaa49efafdc2dc5402a1b'     'N1D_C3A_REMOVE_PROJECT_COUNT=54'     'N1D_C3A_RESTLESS_REMOVE_MANIFEST_BLOB_SHA=0bbfce1b7693e755629504fbea876ee073f2c544'     'N1D_C3A_CONTROL_ROM_BLOB_SHA=7ca70d4899d33a50624d0e9b5eaf406ee6f5f4a8'     'N1D_C3A_RETAINED_GRAPHENE_PROJECT_COUNT=979'     'N1D_C3A_MANAGED_PROJECT_COUNT=991'     'N1D_C3A_CONTROL_FIDELITY=PUBLIC_FUNCTIONAL_REPRODUCTION'     'N1D_C3A_PRIVATE_RESTLESS_VENDOR=OMITTED'     'N1D_C3A_PIXEL_GSANS=OMITTED_UNPINNED_NONFUNCTIONAL'     'N1D_C3_CONTROL_PATCH_TIER_COUNT=5'     'N1D_C3_CONTROL_PATCH_COUNT=369'     'N1D_C3_BUILD_MAKE_PATCH_COUNT=9'     'N1D_C3_RUNTIME_PATCH_ALLOWLIST_COUNT=0'     'N1D_C3_PHH_BUILD_SCAFFOLD_ALLOWED=YES_PINNED_ONLY'     'N1D_C3_CONTROL_FULL_RESTLESS_PATCH_STACK_ALLOWED=YES_PINNED_CONTROL_ONLY'     'N1D_C3_PRIVATE_VENDOR_ALLOWED=NO'     'N1D_C3_RELEASE_ELIGIBLE_BY_REBASELINE=NO'     'N1D_C3_TREBLEDROID_PROFILE=PASS'
do
    require_line "$PROFILE" "$required"
done

for required in     'N1D_PRODUCT_CONTRACT_VERSION=5'     'N1D_C3_PRODUCT_GENERATION_MODE=PINNED_TREBLEDROID_GENERATOR'     'N1D_PRODUCT_NAME=treble_arm64_bvN'     'N1D_PRODUCT_GENERATOR=device/phh/treble/generate.sh'     'N1D_PRODUCT_GENERATOR_CONFIG=rom'     'N1D_C3A_ADD_MANIFEST=build/titan2/n1d-c3a-trebledroid-add.xml'     'N1D_C3A_REMOVE_MANIFEST=build/titan2/n1d-c3a-trebledroid-remove.xml'     'N1D_C3A_REMOVE_PROJECT_MAP=build/titan2/n1d-c3a-remove-projects.tsv'     'N1D_C3A_BUILD_MAKE_AUDIT_SET=build/titan2/n1d-c3a-build-make-audit-set.txt'     'N1D_C3A_BUILD_MAKE_AUDIT_BLOBS=build/titan2/n1d-c3a-build-make-audit-blobs.tsv'     'N1D_C3B_RUNTIME_PATCH_ALLOWLIST=build/titan2/n1d-c3b-runtime-patch-allowlist.txt'     'N1D_DEVICE_PHH_TREBLE_GENERATOR_USED=YES_PINNED'     'N1D_DIRECT_HANDCRAFTED_GSI_PRODUCT_ALLOWED=NO'     'N1D_CONTROL_PATCH_TIER_COUNT=5'     'N1D_CONTROL_PATCH_COUNT=369'     'N1D_RUNTIME_PATCH_ALLOWLIST_COUNT=0'     'N1D_C3A_BUILD_MAKE_AUDIT_SET_COUNT=9'     'N1D_C3A_MANAGED_PROJECT_COUNT=991'     'N1D_C3A_CONTROL_FIDELITY=PUBLIC_FUNCTIONAL_REPRODUCTION'     'N1D_C3A_RELEASE_ELIGIBLE=NO'     'N1D_C3B_RESTLESS_FULL_PATCH_STACK_ALLOWED=NO'     'N1D_C3B_BUILD_AUTHORIZED=NO_UNTIL_C3A_CONTROL_EVIDENCE'     'N1D_C3_RELEASE_ELIGIBLE=NO'
do
    require_line "$PRODUCT" "$required"
done

tier_count="$(awk 'NF && $1 !~ /^#/ {c++} END {print c+0}' "$TIERS")"
tier_total="$(awk 'NF && $1 !~ /^#/ {s+=$2} END {print s+0}' "$TIERS")"
audit_count="$(awk 'NF && $1 !~ /^#/ {c++} END {print c+0}' "$BUILD_AUDIT_SET")"
blob_count="$(awk 'NF && $1 !~ /^#/ {c++} END {print c+0}' "$BUILD_AUDIT_BLOBS")"
runtime_count="$(awk 'NF && $1 !~ /^#/ {c++} END {print c+0}' "$C3B_RUNTIME_ALLOWLIST")"
add_count="$(grep -c '<project ' "$ADD_MANIFEST")"
remove_count="$(grep -c '<remove-project ' "$REMOVE_MANIFEST")"
map_count="$(awk 'NF && $1 !~ /^#/ {c++} END {print c+0}' "$REMOVE_MAP")"

[[ "$tier_count" == 5 ]] || fail "tier_count=$tier_count"
[[ "$tier_total" == 369 ]] || fail "tier_total=$tier_total"
[[ "$audit_count" == 9 ]] || fail "build_audit_count=$audit_count"
[[ "$blob_count" == 9 ]] || fail "build_audit_blob_count=$blob_count"
[[ "$runtime_count" == 0 ]] || fail "c3b_runtime_patch_count=$runtime_count"
[[ "$add_count" == 12 ]] || fail "add_manifest_count=$add_count"
[[ "$remove_count" == 54 ]] || fail "remove_manifest_count=$remove_count"
[[ "$map_count" == 54 ]] || fail "remove_map_count=$map_count"

add_blob="$(git hash-object "$ADD_MANIFEST")"
remove_blob="$(git hash-object "$REMOVE_MANIFEST")"
rom_blob="$(git hash-object "$ROM")"

require_line "$PROFILE" "N1D_C3A_ADD_MANIFEST_BLOB_SHA=$add_blob"
require_line "$PROFILE" "N1D_C3A_RESTLESS_REMOVE_MANIFEST_BLOB_SHA=$remove_blob"
require_line "$PROFILE" "N1D_C3A_CONTROL_ROM_BLOB_SHA=$rom_blob"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

grep -o 'remove-project name="[^"]*"' "$REMOVE_MANIFEST"     | sed -e 's/^remove-project name="//' -e 's/"$//'     | LC_ALL=C sort > "$tmp/remove-manifest-names.txt"
awk 'NF && $1 !~ /^#/ {print $1}' "$REMOVE_MAP"     | LC_ALL=C sort > "$tmp/remove-map-names.txt"

cmp -s "$tmp/remove-manifest-names.txt" "$tmp/remove-map-names.txt"     || {
        diff -u "$tmp/remove-manifest-names.txt" "$tmp/remove-map-names.txt" || true
        fail remove_manifest_map_name_mismatch
    }

awk 'NF && $1 !~ /^#/ {print $1}' "$BUILD_AUDIT_BLOBS"     | LC_ALL=C sort > "$tmp/blob-names.txt"
awk 'NF && $1 !~ /^#/ {print $1}' "$BUILD_AUDIT_SET"     | LC_ALL=C sort > "$tmp/audit-names.txt"

cmp -s "$tmp/blob-names.txt" "$tmp/audit-names.txt"     || {
        diff -u "$tmp/audit-names.txt" "$tmp/blob-names.txt" || true
        fail build_audit_blob_name_mismatch
    }

while IFS=$'\t' read -r patch upstream_path expected_blob; do
    [[ -z "$patch" || "$patch" == \#* ]] && continue
    [[ "$upstream_path" == patches/*/platform_build/*.patch ]]         || fail "build_audit_upstream_path=$upstream_path"
    [[ -f "$BUILD_PATCH_DIR/$patch" ]]         || fail "focused_build_patch_missing=$patch"
    actual_blob="$(git hash-object "$BUILD_PATCH_DIR/$patch")"
    [[ "$actual_blob" == "$expected_blob" ]]         || fail "build_audit_blob patch=$patch expected=$expected_blob actual=$actual_blob"
done < "$BUILD_AUDIT_BLOBS"

if grep -Fq 'vendor/cawilliamson-priv' "$ADD_MANIFEST"; then
    fail private_restless_vendor_present
fi
if grep -Fq 'vendor/pixel/gsans' "$ADD_MANIFEST"; then
    fail unpinned_pixel_gsans_present
fi

GSI_PATCH="$BUILD_PATCH_DIR/0006-Configure-build-for-GrapheneOS-GSI-apps-and-packages.patch"
grep -Fq '"TrichromeWebView"' "$GSI_PATCH" || fail vanadium_webview_patch_missing
grep -Fq '"TrichromeChrome"' "$GSI_PATCH" || fail vanadium_browser_patch_missing

for removed in Browser2 Camera2 messaging QuickSearchBox; do
    grep -Fq -- "-        \"$removed\"" "$GSI_PATCH"         || fail "graphene_gsi_removal_missing=$removed"
done

grep -Fq '$(call inherit-product-if-exists, vendor/pixel/gsans/common/common-vendor.mk)' "$ROM"     || fail control_rom_optional_gsans_missing
grep -Fq 'WITH_DEXPREOPT_BOOT_IMG_AND_SYSTEM_SERVER_ONLY := true' "$ROM"     || fail control_rom_dexpreopt_missing

for required in     'stage_requires_--authorize-source-mutation'     'stage_requires_--authorize-network'     'SOURCE_MUTATION_AUTHORIZED=YES_PINNED_RESTLESS_CONTROL_RECIPE_ONLY'     'NETWORK_FETCH_AUTHORIZED=YES_PINNED_RECIPE_AND_SCAFFOLD_ONLY'     'N1D_C3A_INPUT_BLOBS=PASS add=$add_blob remove=$remove_blob rom=$rom_blob'     'N1D_C3A_RESTLESS_REMOVE_MANIFEST=PASS_EXACT'     'N1D_C3A_RESTLESS_CONTROL_ROM=PASS_EXACT'     'N1D_C3A_GRAPHENE_PROJECT_RETIREMENT=PASS count=$N1D_C3A_REMOVE_PROJECT_COUNT'     'N1D_C3A_REMOVED_PROJECT_PATHS=PASS_ABSENT count=$N1D_C3A_REMOVE_PROJECT_COUNT'     'N1D_C3A_MANAGED_PROJECT_COUNT=PASS value=$count'     'N1D_C3A_CONTROL_PATCH_TARGETS=PASS'     'git am "$patch"'     'patch -p1 --no-backup-if-mismatch < "$patch"'     'N1D_C3A_CONTROL_PATCH_STACK=PASS count=$applied'     'bash generate.sh rom'     'N1D_C3A_GENERATED_PRODUCT=PASS product=treble_arm64_bvN'     'N1D_C3A_TREBLE_APP_SDK_METADATA=PASS'     'N1D_C3A_TREBLE_APP_BUILD_RESIDUE=PASS_SDK_METADATA_AND_LICENSES_ONLY'     'N1D_C3A_POST_STAGE_DIRTY_PROJECTS=PASS_EXPECTED_GENERATED_PLUS_BUILD_RESIDUE'     'treble_app_build_residue_unexpected_entry'     '--allow-treble-app-build-residue'     'N1D_C3A_POST_STAGE_DIRTY_PROJECTS=PASS_EXPECTED_GENERATED_ONLY'     'device_phh_generated_status_mismatch'     'N1D_C3B_RUNTIME_PATCH_ALLOWLIST=PASS_ZERO'     'N1D_C3A_TREBLEDROID_STAGE=PASS'
do
    grep -Fq -- "$required" "$DRIVER" || fail "driver_token_missing=$required"
done

if grep -Eq '^[[:space:]]*(m|make|adb|fastboot)([[:space:]]|$)' "$DRIVER"; then
    fail build_or_device_command_in_prep
fi

if grep -Fq 'sable_titan2_n1d_arm64' "$PROFILE" "$PRODUCT" "$DRIVER"; then
    fail retired_handcrafted_product_reintroduced
fi

echo "N1D_C3A_INPUT_BLOBS=PASS_EXACT add=$add_blob remove=$remove_blob rom=$rom_blob"
echo "N1D_C3A_REMOVE_MANIFEST_MAP=PASS_EXACT_NAMES count=54"
echo "N1D_C3A_SOURCE_GRAPH=PASS add=12 remove=54 managed=991"
echo "N1D_C3A_CONTROL_FIDELITY=PASS_PUBLIC_FUNCTIONAL_REPRODUCTION"
echo "N1D_C3A_CONTROL_PATCH_TIERS=PASS count=5"
echo "N1D_C3A_CONTROL_PATCH_STACK=PASS count=369"
echo "N1D_C3A_BUILD_MAKE_AUDIT_SET=PASS count=9"
echo "N1D_C3A_BUILD_MAKE_AUDIT_BLOBS=PASS_EXACT count=9"
echo "N1D_C3B_RUNTIME_PATCH_ALLOWLIST=PASS_ZERO"
echo "N1D_C3A_PRIVATE_VENDOR=PASS_ABSENT"
echo "N1D_C3A_PIXEL_GSANS=PASS_OMITTED_UNPINNED_NONFUNCTIONAL"
echo "N1D_C3A_GENERATOR=PASS"
echo "N1D_C3A_SECURITY_SEPARATION=PASS"
echo "N1D_C3A_TREBLEDROID_CONTROL_CONTRACT=PASS"
echo "N1D_C3_TREBLEDROID_CONTRACT=PASS"
