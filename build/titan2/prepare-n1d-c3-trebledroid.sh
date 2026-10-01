#!/usr/bin/env bash
# Prepare the N1D C3 TrebleDroid-generated product from the sealed Graphene base.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STORAGE_PROFILE="$ROOT/build/config/storage.env"
HOST_PROFILE="$ROOT/build/config/host-tools.env"
SOURCE_LOCK="$ROOT/build/titan2/n1d-source-lock.env"
FRESH_PROFILE="$ROOT/build/titan2/n1d-fresh-source.env"
TD_PROFILE="$ROOT/build/titan2/n1d-c3-trebledroid.env"
MANIFEST_SRC="$ROOT/build/titan2/n1d-c3-trebledroid-manifest.xml"
ROM_SRC="$ROOT/build/titan2/n1d-c3-sable-rom.mk"
BUILD_ALLOWLIST="$ROOT/build/titan2/n1d-c3-build-patch-allowlist.txt"
RUNTIME_ALLOWLIST="$ROOT/build/titan2/n1d-c3-runtime-patch-allowlist.txt"
PATCH_DIR="$ROOT/patches/android-16-n1d-trebledroid/build-make"
STORAGE_VERIFY="$ROOT/build/host/verify-storage-root.sh"
SOURCE_GATE="$ROOT/build/gates/n1d-source-lock-contract.sh"

fail() {
    echo "N1D_C3_TREBLEDROID_PREP=FAIL $*" >&2
    exit 1
}

for f in     "$STORAGE_PROFILE" "$HOST_PROFILE" "$SOURCE_LOCK" "$FRESH_PROFILE"     "$TD_PROFILE" "$MANIFEST_SRC" "$ROM_SRC" "$BUILD_ALLOWLIST"     "$RUNTIME_ALLOWLIST" "$STORAGE_VERIFY" "$SOURCE_GATE"
do
    [[ -f "$f" ]] || fail "missing_file=$f"
done
[[ -d "$PATCH_DIR" ]] || fail "missing_patch_dir=$PATCH_DIR"

# shellcheck source=/dev/null
source "$STORAGE_PROFILE"
# shellcheck source=/dev/null
source "$HOST_PROFILE"
# shellcheck source=/dev/null
source "$SOURCE_LOCK"
# shellcheck source=/dev/null
source "$FRESH_PROFILE"
# shellcheck source=/dev/null
source "$TD_PROFILE"

ACTION="${1:-preflight}"
if (($#)); then shift; fi

SOURCE_MUTATION_AUTHORIZED=NO
NETWORK_FETCH_AUTHORIZED=NO

while (($#)); do
    case "$1" in
        --authorize-source-mutation)
            SOURCE_MUTATION_AUTHORIZED=YES
            shift
            ;;
        --authorize-network)
            NETWORK_FETCH_AUTHORIZED=YES
            shift
            ;;
        *)
            fail "unknown_arg=$1"
            ;;
    esac
done

ANDROID_ROOT="$SABLE_BUILD_ROOT/$N1D_ANDROID_ROOT_REL"
BASE_SEAL="$SABLE_BUILD_ROOT/evidence/titan2/n1d-source-prep/20261001T045509Z-graphene-base"
BASE_HEADS="$BASE_SEAL/all-project-heads.tsv"
LOCAL_MANIFEST_DIR="$ANDROID_ROOT/.repo/local_manifests"
LOCAL_MANIFEST="$LOCAL_MANIFEST_DIR/n1d-c3-trebledroid.xml"
TD_ROOT="$ANDROID_ROOT/device/phh/treble"
BUILD_MAKE="$ANDROID_ROOT/build/make"
OLD_PRODUCT="$ANDROID_ROOT/vendor/sable/n1d"
EVIDENCE_ROOT="$SABLE_EVIDENCE_ROOT/titan2/n1d-c3-trebledroid-prep"

scaffold_paths=(
    device/phh/treble
    packages/apps/QcRilAm
    prebuilts/vndk/v28
    prebuilts/vndk/v29
    prebuilts/vndk/v30
    treble_app
    vendor/apn
    vendor/hardware_overlay
    vendor/interfaces
    vendor/lptools
    vendor/magisk
    vendor/vndk-tests
)

declare -A expected_heads=(
    [device/phh/treble]="$N1D_C3_TD_DEVICE_PHH_COMMIT"
    [packages/apps/QcRilAm]="$N1D_C3_TD_QCRILAM_COMMIT"
    [prebuilts/vndk/v28]="$N1D_C3_TD_VNDK28_COMMIT"
    [prebuilts/vndk/v29]="$N1D_C3_TD_VNDK29_COMMIT"
    [prebuilts/vndk/v30]="$N1D_C3_TD_VNDK30_COMMIT"
    [treble_app]="$N1D_C3_TD_TREBLE_APP_COMMIT"
    [vendor/apn]="$N1D_C3_TD_APN_COMMIT"
    [vendor/hardware_overlay]="$N1D_C3_TD_HARDWARE_OVERLAY_COMMIT"
    [vendor/interfaces]="$N1D_C3_TD_INTERFACES_COMMIT"
    [vendor/lptools]="$N1D_C3_TD_LPTOOLS_COMMIT"
    [vendor/magisk]="$N1D_C3_TD_MAGISK_COMMIT"
    [vendor/vndk-tests]="$N1D_C3_TD_VNDK_TESTS_COMMIT"
)

count_allowlist() {
    awk 'NF && $1 !~ /^#/ { count++ } END { print count+0 }' "$1"
}

verify_contract_inputs() {
    local build_count runtime_count
    build_count="$(count_allowlist "$BUILD_ALLOWLIST")"
    runtime_count="$(count_allowlist "$RUNTIME_ALLOWLIST")"
    [[ "$build_count" == "$N1D_C3_BUILD_MAKE_PATCH_COUNT" ]]         || fail "build_patch_count expected=$N1D_C3_BUILD_MAKE_PATCH_COUNT actual=$build_count"
    [[ "$runtime_count" == "$N1D_C3_RUNTIME_PATCH_ALLOWLIST_COUNT" ]]         || fail "runtime_patch_count expected=$N1D_C3_RUNTIME_PATCH_ALLOWLIST_COUNT actual=$runtime_count"

    while IFS= read -r patch; do
        [[ -z "$patch" || "$patch" == #* ]] && continue
        [[ -f "$PATCH_DIR/$patch" ]] || fail "build_patch_missing=$patch"
    done < "$BUILD_ALLOWLIST"

    echo "N1D_C3_BUILD_PATCH_ALLOWLIST=PASS count=$build_count"
    echo "N1D_C3_RUNTIME_PATCH_ALLOWLIST=PASS_ZERO"
}

verify_graphene_base_pre_stage() {
    [[ -d "$ANDROID_ROOT/.repo/manifests/.git" ]] || fail manifest_checkout_missing
    local manifest_head count dirty tmp
    manifest_head="$(git -C "$ANDROID_ROOT/.repo/manifests" rev-parse HEAD)"
    [[ "$manifest_head" == "$N1D_GRAPHENE_MANIFEST_COMMIT" ]]         || fail "manifest_head expected=$N1D_GRAPHENE_MANIFEST_COMMIT actual=$manifest_head"

    if [[ -d "$LOCAL_MANIFEST_DIR" ]]         && [[ -n "$(find "$LOCAL_MANIFEST_DIR" -mindepth 1 -maxdepth 1 -type f -print -quit)" ]]
    then
        fail local_manifest_present_before_trebledroid_stage
    fi

    tmp="$(mktemp -d)"
    (
        cd "$ANDROID_ROOT"
        "$SABLE_REPO_TOOL" forall -c             'printf "%s\t%s\n" "$REPO_PATH" "$(git rev-parse HEAD)"'
    ) > "$tmp/current.tsv"
    (
        cd "$ANDROID_ROOT"
        "$SABLE_REPO_TOOL" forall -c             's="$(git status --porcelain --untracked-files=all)"; [ -z "$s" ] || printf "%s\n" "$REPO_PATH"'
    ) > "$tmp/dirty.tsv"

    count="$(grep -cve '^$' "$tmp/current.tsv" || true)"
    dirty="$(grep -cve '^$' "$tmp/dirty.tsv" || true)"
    [[ "$count" == 1033 ]] || { rm -rf "$tmp"; fail "base_project_count=$count"; }
    [[ "$dirty" == 0 ]] || { cat "$tmp/dirty.tsv"; rm -rf "$tmp"; fail "base_dirty_project_count=$dirty"; }

    LC_ALL=C sort "$BASE_HEADS" > "$tmp/expected.tsv"
    LC_ALL=C sort "$tmp/current.tsv" > "$tmp/current.sorted.tsv"
    cmp -s "$tmp/expected.tsv" "$tmp/current.sorted.tsv"         || { diff -u "$tmp/expected.tsv" "$tmp/current.sorted.tsv" || true; rm -rf "$tmp"; fail base_heads_mismatch; }
    rm -rf "$tmp"

    echo "N1D_C3_PRE_REBASELINE_PROJECT_COUNT=PASS value=1033"
    echo "N1D_C3_PRE_REBASELINE_DIRTY_PROJECT_COUNT=PASS_ZERO"
    echo "N1D_C3_PRE_REBASELINE_HEADS=PASS_EXACT"
}

verify_scaffold_heads() {
    local path actual
    for path in "${scaffold_paths[@]}"; do
        [[ -d "$ANDROID_ROOT/$path/.git" || -f "$ANDROID_ROOT/$path/.git" ]]             || fail "scaffold_project_missing=$path"
        actual="$(git -C "$ANDROID_ROOT/$path" rev-parse HEAD)"
        [[ "$actual" == "${expected_heads[$path]}" ]]             || fail "scaffold_head path=$path expected=${expected_heads[$path]} actual=$actual"
    done
    echo "N1D_C3_TREBLEDROID_SCAFFOLD_HEADS=PASS_EXACT count=${#scaffold_paths[@]}"
}

verify_build_make_stack() {
    local head count
    head="$(git -C "$BUILD_MAKE" rev-parse HEAD)"
    git -C "$BUILD_MAKE" merge-base --is-ancestor "$N1D_C3_GRAPHENEOS_BUILD_COMMIT" "$head"         || fail "build_make_base_not_ancestor=$head"
    count="$(git -C "$BUILD_MAKE" rev-list --count "$N1D_C3_GRAPHENEOS_BUILD_COMMIT..$head")"
    [[ "$count" == "$N1D_C3_BUILD_MAKE_PATCH_COUNT" ]]         || fail "build_make_patch_commit_count expected=$N1D_C3_BUILD_MAKE_PATCH_COUNT actual=$count"
    [[ -z "$(git -C "$BUILD_MAKE" status --porcelain --untracked-files=all)" ]]         || fail build_make_dirty
    echo "N1D_C3_BUILD_MAKE_PATCH_STACK=PASS count=$count"
}

verify_generated_product() {
    local product="$TD_ROOT/treble_arm64_bvN.mk"
    [[ -f "$TD_ROOT/AndroidProducts.mk" ]] || fail generated_android_products_missing
    [[ -f "$product" ]] || fail generated_product_missing
    grep -Fq 'include build/make/target/product/aosp_arm64.mk' "$product"         || fail generated_aosp_arm64_base_missing
    grep -Fq '$(call inherit-product, device/phh/treble/base.mk)' "$product"         || fail generated_phh_base_missing
    grep -Fq '$(call inherit-product, device/phh/treble/sable.mk)' "$product"         || fail generated_sable_config_missing
    grep -Fq 'PRODUCT_NAME := treble_arm64_bvN' "$product"         || fail generated_product_name_missing
    grep -Fq 'PRODUCT_DEVICE := tdgsi_arm64_ab' "$product"         || fail generated_product_device_missing
    echo "N1D_C3_GENERATED_PRODUCT=PASS product=treble_arm64_bvN"
}

verify_td_dirty_scope() {
    local line path
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        path="${line:3}"
        case "$path" in
            AndroidProducts.mk|sable.mk|treble_*.mk) ;;
            *) fail "unexpected_device_phh_dirty_path=$path" ;;
        esac
    done < <(git -C "$TD_ROOT" status --porcelain --untracked-files=all)
    echo "N1D_C3_DEVICE_PHH_GENERATED_DIRTY_SCOPE=PASS"
}

preflight() {
    echo "===== N1D C3 TREBLEDROID REBASELINE PREFLIGHT ====="
    echo "SOURCE_MUTATION_AUTHORIZED=NO"
    echo "NETWORK_FETCH_AUTHORIZED=NO"
    echo "BUILD_AUTHORIZED=NO"
    echo "DEVICE_CONTACT_AUTHORIZED=NO"
    echo "FLASH_AUTHORIZED=NO"
    bash "$STORAGE_VERIFY" runtime
    bash "$SOURCE_GATE"
    verify_contract_inputs
    verify_graphene_base_pre_stage
    if [[ -e "$OLD_PRODUCT" ]]; then
        echo "N1D_C3_HANDCRAFTED_PRODUCT=PRESENT_WILL_ARCHIVE"
    else
        echo "N1D_C3_HANDCRAFTED_PRODUCT=ABSENT"
    fi
    echo "N1D_C3_TREBLEDROID_REBASELINE_PREFLIGHT=PASS"
}

stage() {
    echo "===== N1D C3 TREBLEDROID REBASELINE STAGE ====="
    [[ "$SOURCE_MUTATION_AUTHORIZED" == YES ]]         || fail stage_requires_--authorize-source-mutation
    [[ "$NETWORK_FETCH_AUTHORIZED" == YES ]]         || fail stage_requires_--authorize-network

    echo "SOURCE_MUTATION_AUTHORIZED=YES_PINNED_TREBLEDROID_SCAFFOLD_ONLY"
    echo "NETWORK_FETCH_AUTHORIZED=YES_PINNED_SCAFFOLD_SYNC_ONLY"
    echo "BUILD_AUTHORIZED=NO"
    echo "DEVICE_CONTACT_AUTHORIZED=NO"
    echo "FLASH_AUTHORIZED=NO"

    bash "$STORAGE_VERIFY" runtime
    bash "$SOURCE_GATE"
    verify_contract_inputs
    verify_graphene_base_pre_stage

    local stamp evidence retired patch
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    evidence="$EVIDENCE_ROOT/$stamp-trebledroid-stage"
    mkdir -p "$evidence"

    if [[ -e "$OLD_PRODUCT" ]]; then
        retired="$evidence/retired-handcrafted-vendor-sable-n1d"
        mv "$OLD_PRODUCT" "$retired"
        echo "N1D_C3_HANDCRAFTED_PRODUCT_RETIREMENT=PASS path=$retired"
    fi

    mkdir -p "$LOCAL_MANIFEST_DIR"
    cp -a "$MANIFEST_SRC" "$LOCAL_MANIFEST"

    (
        cd "$ANDROID_ROOT"
        "$SABLE_REPO_TOOL" sync             --force-sync             --no-clone-bundle             --no-tags             --jobs=4             "${scaffold_paths[@]}"
    )

    verify_scaffold_heads

    [[ "$(git -C "$BUILD_MAKE" rev-parse HEAD)" == "$N1D_C3_GRAPHENEOS_BUILD_COMMIT" ]]         || fail "build_make_prepatch_head=$(git -C "$BUILD_MAKE" rev-parse HEAD)"

    while IFS= read -r patch; do
        [[ -z "$patch" || "$patch" == #* ]] && continue
        (
            cd "$BUILD_MAKE"
            git am "$PATCH_DIR/$patch"
        ) || {
            git -C "$BUILD_MAKE" am --abort >/dev/null 2>&1 || true
            fail "build_make_patch_apply=$patch"
        }
    done < "$BUILD_ALLOWLIST"

    verify_build_make_stack

    cp -a "$ROM_SRC" "$TD_ROOT/sable.mk"
    (
        cd "$TD_ROOT"
        bash generate.sh sable
    )

    verify_generated_product
    verify_td_dirty_scope

    cp -a "$MANIFEST_SRC" "$evidence/n1d-c3-trebledroid-manifest.xml"
    cp -a "$ROM_SRC" "$evidence/n1d-c3-sable-rom.mk"
    cp -a "$BUILD_ALLOWLIST" "$evidence/n1d-c3-build-patch-allowlist.txt"
    cp -a "$RUNTIME_ALLOWLIST" "$evidence/n1d-c3-runtime-patch-allowlist.txt"
    git -C "$BUILD_MAKE" log         --format='%H%x09%s'         "$N1D_C3_GRAPHENEOS_BUILD_COMMIT..HEAD"         > "$evidence/build-make-patch-commits.tsv"
    git -C "$TD_ROOT" status --porcelain --untracked-files=all         > "$evidence/device-phh-generated-status.txt"

    {
        echo "N1D_C3_TREBLEDROID_STAGE=PASS"
        echo "N1D_C3_GENERATED_PRODUCT=$N1D_C3_GENERATED_PRODUCT"
        echo "N1D_C3_RELEASE_CONFIG=$N1D_C3_RELEASE_CONFIG"
        echo "N1D_C3_FIRST_VARIANT=$N1D_C3_FIRST_VARIANT"
        echo "N1D_C3_BUILD_MAKE_PATCH_COUNT=$N1D_C3_BUILD_MAKE_PATCH_COUNT"
        echo "N1D_C3_RUNTIME_PATCH_ALLOWLIST_COUNT=$N1D_C3_RUNTIME_PATCH_ALLOWLIST_COUNT"
        echo "N1D_C3_RELEASE_ELIGIBLE=NO"
    } > "$evidence/stage-state.env"

    (
        cd "$evidence"
        find . -type f ! -name SHA256SUMS.txt -print0             | LC_ALL=C sort -z             | xargs -0 sha256sum > SHA256SUMS.txt
        sha256sum -c SHA256SUMS.txt >/dev/null
    )

    echo "N1D_C3_TREBLEDROID_STAGE=PASS"
    echo "EVIDENCE_DIR=$evidence"
}

verify() {
    echo "===== N1D C3 TREBLEDROID REBASELINE VERIFY ====="
    echo "SOURCE_MUTATION_AUTHORIZED=NO"
    echo "NETWORK_FETCH_AUTHORIZED=NO"
    echo "BUILD_AUTHORIZED=NO"
    echo "DEVICE_CONTACT_AUTHORIZED=NO"
    echo "FLASH_AUTHORIZED=NO"
    bash "$STORAGE_VERIFY" runtime
    bash "$SOURCE_GATE"
    verify_contract_inputs
    cmp -s "$MANIFEST_SRC" "$LOCAL_MANIFEST" || fail local_manifest_mismatch
    verify_scaffold_heads
    verify_build_make_stack
    verify_generated_product
    verify_td_dirty_scope
    echo "N1D_C3_RUNTIME_PATCH_ALLOWLIST=PASS_ZERO"
    echo "N1D_C3_TREBLEDROID_REBASELINE_VERIFY=PASS"
}

case "$ACTION" in
    preflight) preflight ;;
    stage) stage ;;
    verify) verify ;;
    *) fail "unknown_action=$ACTION" ;;
esac
