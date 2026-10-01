#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOCK="$ROOT/build/titan2/n1d-source-lock.env"
PRODUCT="$ROOT/build/titan2/n1d-product-contract.env"
PROFILE="$ROOT/build/titan2/n1d-c3-trebledroid.env"
ADD_MANIFEST="$ROOT/build/titan2/n1d-c3a-trebledroid-add.xml"
REMOVE_MANIFEST="$ROOT/build/titan2/n1d-c3a-trebledroid-remove.xml"
REMOVE_MAP="$ROOT/build/titan2/n1d-c3a-remove-projects.tsv"

fail() {
    echo "N1D_SOURCE_LOCK_CONTRACT=FAIL $*" >&2
    exit 1
}

for f in "$LOCK" "$PRODUCT" "$PROFILE" "$ADD_MANIFEST" "$REMOVE_MANIFEST" "$REMOVE_MAP"; do
    [[ -f "$f" ]] || fail "missing_file=$f"
done
bash -n "$LOCK" "$PRODUCT" "$PROFILE"

require_line() {
    local file="$1" line="$2"
    grep -Fxq "$line" "$file" || fail "missing_line=$line file=$file"
}

for required in     'N1D_SOURCE_LOCK_VERSION=2'     'N1D_ANDROID_MAJOR=16'     'N1D_PLATFORM_SDK=36'     'N1D_AOSP_REVISION=android-16.0.0_r4'     'N1D_RELEASE_CONFIG=bp4a'     'N1D_GRAPHENEOS_TAG=2026061600'     'N1D_GRAPHENEOS_TAG_OBJECT=d1d40ac250f31b1a92989d06fa524425c264081d'     'N1D_GRAPHENEOS_MANIFEST_COMMIT=5d82aa9610855bc0b43b9eb7ca4470d30455cfeb'     'N1D_GRAPHENEOS_REVISION_BRANCH=16-qpr2'     'N1D_RESTLESS_TAG=16.0.0-202606230923'     'N1D_RESTLESS_COMMIT=4adc5766f457849ca37e0b318bced65aef5a2233'     'N1D_RESTLESS_DEFAULT_BRANCH_ALLOWED=NO'     'N1D_RESTLESS_DYNAMIC_GRAPHENE_TAG_ALLOWED=NO'     'N1D_RESTLESS_UPSTREAM_SYNC_SCRIPT_ALLOWED=NO'     'N1D_RESTLESS_PUBLIC_ONLY_REQUIRED=YES'     'N1D_RESTLESS_PRIVATE_VENDOR_ALLOWED=NO'     'N1D_PATCH_APPLICATION_MODE=PHASE_SCOPED'     'N1D_C3A_PATCH_APPLICATION_MODE=PINNED_RESTLESS_CONTROL_RECIPE'     'N1D_C3A_PATCH_TIER_AUTOAPPLY_ALLOWED=YES_PINNED_CONTROL_ONLY'     'N1D_C3B_PATCH_APPLICATION_MODE=REPO_OWNED_REVIEWED_ALLOWLIST'     'N1D_C3B_PATCH_TIER_AUTOAPPLY_ALLOWED=NO'     'N1D_ANDROID17_SOURCE_ALLOWED=NO'     'N1D_SOURCE_SYNC_MUST_EMIT_PINNED_MANIFEST=YES'     'N1D_SOURCE_LOCK=PASS'
do
    require_line "$LOCK" "$required"
done

if grep -Eiq '=(latest|stable|main|master)$|resolve.*latest|current.*tag' "$LOCK"; then
    fail floating_source_reference
fi
if grep -Eq 'android-17|2026061800|202609[0-9]{4}' "$LOCK"; then
    fail android17_source_reference_present
fi

for required in     'N1D_PRODUCT_CONTRACT_VERSION=5'     'N1D_SOURCE_SUBSTRATE=GRAPHENEOS_A16_PINNED'     'N1D_RESTLESS_ROLE=C2_CONTROL_C3A_REPRODUCTION_REFERENCE_C3B_PATCH_SOURCE_ONLY'     'N1D_C3_PRODUCT_GENERATION_MODE=PINNED_TREBLEDROID_GENERATOR'     'N1D_PRODUCT_NAME=treble_arm64_bvN'     'N1D_PRODUCT_GENERATOR=device/phh/treble/generate.sh'     'N1D_C3A_ADD_MANIFEST=build/titan2/n1d-c3a-trebledroid-add.xml'     'N1D_C3A_REMOVE_MANIFEST=build/titan2/n1d-c3a-trebledroid-remove.xml'     'N1D_C3A_REMOVE_PROJECT_MAP=build/titan2/n1d-c3a-remove-projects.tsv'     'N1D_C3A_ADD_PROJECT_COUNT=12'     'N1D_C3A_REMOVE_PROJECT_COUNT=54'     'N1D_C3A_MANAGED_PROJECT_COUNT=991'     'N1D_C3A_CONTROL_FIDELITY=PUBLIC_FUNCTIONAL_REPRODUCTION'     'N1D_CONTROL_PATCH_COUNT=369'     'N1D_RUNTIME_PATCH_ALLOWLIST_COUNT=0'     'N1D_C3_RELEASE_ELIGIBLE=NO'     'N1D_C3_ACTIVE_PHASE=C3A_CONTROL'     'N1D_C3B_RESTLESS_FULL_PATCH_STACK_ALLOWED=NO'     'N1D_PRODUCT_CONTRACT=PASS'
do
    require_line "$PRODUCT" "$required"
done

for required in     'N1D_C3_GRAPHENEOS_TAG=2026061600'     'N1D_C3_GRAPHENEOS_BUILD_COMMIT=e1c27e0172987898adfcf8416186baf28c693842'     'N1D_C3_RESTLESS_TAG=16.0.0-202606230923'     'N1D_C3_RESTLESS_COMMIT=4adc5766f457849ca37e0b318bced65aef5a2233'     'N1D_C3_SCAFFOLD_PROJECT_COUNT=12'     'N1D_C3A_ADD_PROJECT_COUNT=12'     'N1D_C3A_REMOVE_PROJECT_COUNT=54'     'N1D_C3A_RETAINED_GRAPHENE_PROJECT_COUNT=979'     'N1D_C3A_MANAGED_PROJECT_COUNT=991'     'N1D_C3A_CONTROL_FIDELITY=PUBLIC_FUNCTIONAL_REPRODUCTION'     'N1D_C3_CONTROL_PATCH_COUNT=369'     'N1D_C3_PRIVATE_VENDOR_ALLOWED=NO'
do
    require_line "$PROFILE" "$required"
done

if grep -Fq 'vendor/cawilliamson-priv' "$ADD_MANIFEST"; then
    fail private_restless_vendor_present
fi

add_count="$(grep -c '<project ' "$ADD_MANIFEST")"
remove_count="$(grep -c '<remove-project ' "$REMOVE_MANIFEST")"
map_count="$(awk 'NF && $1 !~ /^#/ {c++} END {print c+0}' "$REMOVE_MAP")"
[[ "$add_count" == 12 ]] || fail "c3a_add_manifest_count=$add_count"
[[ "$remove_count" == 54 ]] || fail "c3a_remove_manifest_count=$remove_count"
[[ "$map_count" == 54 ]] || fail "c3a_remove_map_count=$map_count"

bash "$ROOT/build/gates/n1d-c3-phase-split-contract.sh"
bash "$ROOT/build/gates/n1d-c3-trebledroid-contract.sh"
bash "$ROOT/build/gates/n1d-restless-security-boundary-contract.sh"

echo "N1D_SOURCE_LOCK_ANDROID16=PASS"
echo "N1D_SOURCE_LOCK_GRAPHENE_PIN=PASS"
echo "N1D_SOURCE_LOCK_RESTLESS_PIN=PASS"
echo "N1D_SOURCE_LOCK_C3A_SOURCE_GRAPH=PASS add=12 remove=54 managed=991"
echo "N1D_SOURCE_LOCK_TREBLEDROID_PINS=PASS"
echo "N1D_SOURCE_LOCK_C3A_ADD_REMOVE_GRAPH=PASS add=12 remove=54 managed=991"
echo "N1D_SOURCE_LOCK_NO_FLOATING_TAG=PASS"
echo "N1D_SOURCE_LOCK_PUBLIC_ONLY=PASS"
echo "N1D_SOURCE_LOCK_C3A_PATCH_POLICY=PASS_PINNED_CONTROL_ONLY"
echo "N1D_SOURCE_LOCK_C3B_PATCH_POLICY=PASS_REVIEWED_ALLOWLIST_ONLY"
echo "N1D_SOURCE_LOCK_CONTROL_PATCH_STACK=PASS_PINNED"
echo "N1D_SOURCE_LOCK_RELEASE_RUNTIME_ADMISSION=PASS_ZERO"
echo "N1D_SOURCE_LOCK_C3A_C3B_SPLIT=PASS"
echo "N1D_SOURCE_LOCK_PRODUCT_GRAPH_ALIGNMENT=PASS"
echo "N1D_SOURCE_LOCK_CONTRACT=PASS"
