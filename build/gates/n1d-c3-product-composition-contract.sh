#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROFILE="$ROOT/build/titan2/n1d-c3-composition.env"
TRANSITION="$ROOT/build/titan2/n1d-c3b-transition.env"
MANIFEST="$ROOT/build/titan2/n1d-c3b-scaffold-add.xml"
DECISIONS="$ROOT/build/titan2/n1d-c3b-scaffold-decisions.tsv"
RUNTIME_ALLOWLIST="$ROOT/build/titan2/n1d-c3b-runtime-patch-allowlist.txt"

fail() {
    echo "N1D_C3_PRODUCT_COMPOSITION_CONTRACT=FAIL $*" >&2
    exit 1
}

for f in "$PROFILE" "$TRANSITION" "$MANIFEST" "$DECISIONS" "$RUNTIME_ALLOWLIST"; do
    [[ -f "$f" ]] || fail "missing_file=$f"
done
for f in "$PROFILE" "$TRANSITION"; do
    bash -n "$f" || fail "syntax=$f"
done

require_line() {
    local file="$1" line="$2"
    grep -Fxq "$line" "$file" || fail "missing_line=$line file=$file"
}

for required in     'N1D_C3_COMPOSITION_VERSION=5'     'N1D_C3_ACTIVE_PHASE=C3B_ENGINEERING'     'N1D_C3_COMPOSITION_MODE=PINNED_GRAPHENE_PLUS_MINIMAL_TREBLEDROID_SCAFFOLD'     'N1D_C3_STAGE_DRIVER=build/titan2/prepare-n1d-c3b-engineering.sh'     'N1D_C3_PARSE_DRIVER=build/titan2/qualify-n1d-c3b-product-parse.sh'     'N1D_C3_BUILD_DRIVER=build/titan2/build-n1d-c3b-systemimage.sh'     'N1D_C3_PRODUCT_NAME=treble_arm64_bvN'     'N1D_C3_PRODUCT_DEVICE=tdgsi_arm64_ab'     'N1D_C3_RELEASE_CONFIG=bp4a'     'N1D_C3_FIRST_BUILD_VARIANT=userdebug'     'N1D_C3_FIRST_BUILD_GOAL=systemimage'     'N1D_C3B_GRAPHENE_BASE_PROJECT_COUNT=1033'     'N1D_C3B_SCAFFOLD_PROJECT_COUNT=5'     'N1D_C3B_REMOVE_PROJECT_COUNT=0'     'N1D_C3B_MANAGED_PROJECT_COUNT=1038'     'N1D_C3B_RESTLESS_FULL_PATCH_STACK_ALLOWED=NO'     'N1D_C3B_RESTLESS_PATCH_COUNT=0'     'N1D_C3B_RUNTIME_PATCH_ALLOWLIST_INITIAL_COUNT=0'     'N1D_C3B_PHH_BASE_SECURITY_TRANSFORM_COUNT=14'     'N1D_C3B_HOST_LAYOUT_PATCH_COUNT=2'     'N1D_C3B_BUILD_AUTHORIZED=YES_SYSTEMIMAGE_ONLY_AFTER_STAGE_AND_PARSE'     'N1D_C3_HANDCRAFTED_PRODUCT_RETIRED=YES'     'N1D_C3_PRODUCT_IDENTITY_STATUS=ENGINEERING_GENERATED_TREBLEDROID_PENDING_E2'     'N1D_C3_DEVICE_CONTACT_AUTHORIZED=NO'     'N1D_C3_FLASH_AUTHORIZED=NO'     'N1D_C3_SIGNING_AUTHORIZED=NO'     'N1D_C3_PHYSICAL_RUNTIME_AUTHORIZED=NO'     'N1D_C3_RELEASE_ELIGIBLE=NO'     'N1D_C3_COMPOSITION_CONTRACT=PASS'
do
    require_line "$PROFILE" "$required"
done

for required in     'N1D_C3B_SCAFFOLD_PROJECT_COUNT=5'     'N1D_C3B_REMOVE_PROJECT_COUNT=0'     'N1D_C3B_MANAGED_PROJECT_COUNT=1038'     'N1D_C3B_RUNTIME_PATCH_ALLOWLIST_COUNT=0'     'N1D_C3B_PRODUCT_IDENTITY_STATUS=ENGINEERING_GENERATED_TREBLEDROID_PENDING_E2'     'N1D_C3B_RELEASE_ELIGIBLE=NO'
do
    require_line "$TRANSITION" "$required"
done

project_count="$(grep -c '<project ' "$MANIFEST")"
remove_count="$(grep -c '<remove-project ' "$MANIFEST" || true)"
runtime_count="$(awk 'NF && $1 !~ /^#/ {c++} END {print c+0}' "$RUNTIME_ALLOWLIST")"
decision_count="$(awk 'NF && $1 !~ /^#/ {c++} END {print c+0}' "$DECISIONS")"

[[ "$project_count" == 5 ]] || fail "scaffold_project_count=$project_count"
[[ "$remove_count" == 0 ]] || fail "remove_project_count=$remove_count"
[[ "$runtime_count" == 0 ]] || fail "runtime_patch_count=$runtime_count"
[[ "$decision_count" == 12 ]] || fail "scaffold_decision_count=$decision_count"

if [[ -d "$ROOT/build/titan2/n1d-c3-product" ]]; then
    fail retired_handcrafted_product_bundle_present
fi
if grep -Fq 'sable_titan2_n1d_arm64' "$PROFILE" "$TRANSITION"; then
    fail retired_handcrafted_product_reintroduced
fi

echo "N1D_C3_PRODUCT_COMPOSITION_ACTIVE_PHASE=PASS_C3B_ENGINEERING"
echo "N1D_C3_PRODUCT_COMPOSITION_SOURCE_GRAPH=PASS base=1033 add=5 remove=0 managed=1038"
echo "N1D_C3_PRODUCT_COMPOSITION_RUNTIME_PATCHES=PASS_ZERO"
echo "N1D_C3_PRODUCT_COMPOSITION_HANDCRAFTED_PATH=PASS_RETIRED"
echo "N1D_C3_PRODUCT_COMPOSITION_E2_BOUNDARY=PASS_PENDING"
echo "N1D_C3_PRODUCT_COMPOSITION_CONTRACT=PASS"
