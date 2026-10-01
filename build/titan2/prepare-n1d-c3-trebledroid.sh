#!/usr/bin/env bash
# Prepare the N1D C3A Restless/TrebleDroid reproduction control from the
# sealed GrapheneOS base. This stages source only; it does not build Android.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STORAGE_PROFILE="$ROOT/build/config/storage.env"
HOST_PROFILE="$ROOT/build/config/host-tools.env"
SOURCE_LOCK="$ROOT/build/titan2/n1d-source-lock.env"
FRESH_PROFILE="$ROOT/build/titan2/n1d-fresh-source.env"
TD_PROFILE="$ROOT/build/titan2/n1d-c3-trebledroid.env"
PHASE_PROFILE="$ROOT/build/titan2/n1d-c3-phase-split.env"
COMPOSITION_PROFILE="$ROOT/build/titan2/n1d-c3-composition.env"
MANIFEST_SRC="$ROOT/build/titan2/n1d-c3-trebledroid-manifest.xml"
ROM_SRC="$ROOT/build/titan2/n1d-c3-sable-rom.mk"
TIER_FILE="$ROOT/build/titan2/n1d-c3-control-patch-tiers.tsv"
BUILD_AUDIT_SET="$ROOT/build/titan2/n1d-c3a-build-make-audit-set.txt"
C3B_RUNTIME_ALLOWLIST="$ROOT/build/titan2/n1d-c3b-runtime-patch-allowlist.txt"
BUILD_PATCH_DIR="$ROOT/patches/android-16-n1d-trebledroid/build-make"
STORAGE_VERIFY="$ROOT/build/host/verify-storage-root.sh"
SOURCE_GATE="$ROOT/build/gates/n1d-source-lock-contract.sh"

fail() {
    echo "N1D_C3A_TREBLEDROID_PREP=FAIL $*" >&2
    exit 1
}

for f in \
    "$STORAGE_PROFILE" \
    "$HOST_PROFILE" \
    "$SOURCE_LOCK" \
    "$FRESH_PROFILE" \
    "$TD_PROFILE" \
    "$PHASE_PROFILE" \
    "$COMPOSITION_PROFILE" \
    "$MANIFEST_SRC" \
    "$ROM_SRC" \
    "$TIER_FILE" \
    "$BUILD_AUDIT_SET" \
    "$C3B_RUNTIME_ALLOWLIST" \
    "$STORAGE_VERIFY" \
    "$SOURCE_GATE"
do
    [[ -f "$f" ]] || fail "missing_file=$f"
done
[[ -d "$BUILD_PATCH_DIR" ]] || fail "missing_build_patch_dir=$BUILD_PATCH_DIR"

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
# shellcheck source=/dev/null
source "$PHASE_PROFILE"
# shellcheck source=/dev/null
source "$COMPOSITION_PROFILE"

[[ "$N1D_C3A_ROLE" == RESTLESS_TREBLEDROID_REPRODUCTION_CONTROL ]] \
    || fail c3a_role_mismatch
[[ "$N1D_C3B_BUILD_AUTHORIZED" == NO_UNTIL_C3A_CONTROL_EVIDENCE ]] \
    || fail c3b_build_boundary_mismatch

ACTION="${1:-preflight}"
if (($#)); then
    shift
fi

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
LOCAL_MANIFEST="$LOCAL_MANIFEST_DIR/n1d-c3a-trebledroid.xml"
TD_ROOT="$ANDROID_ROOT/device/phh/treble"
BUILD_MAKE="$ANDROID_ROOT/build/make"
OLD_PRODUCT="$ANDROID_ROOT/vendor/sable/n1d"
RECIPE_ROOT="$SABLE_BUILD_ROOT/artifacts/titan2/n1d-c3a-restless-recipe/$N1D_RESTLESS_TAG"
EVIDENCE_ROOT="$SABLE_EVIDENCE_ROOT/titan2/n1d-c3a-trebledroid-prep"

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

count_entries() {
    awk 'NF && $1 !~ /^#/ { count++ } END { print count+0 }' "$1"
}

map_patch_project() {
    local project="$1"
    local path

    # Keep this identical to RestlessOS patches/apply.sh.
    path="$(tr '_' '/' <<<"$project" | sed -e 's;platform/;;g')"
    [[ "$path" == build ]] && path=build/make
    [[ "$path" == testing ]] && path=platform_testing
    [[ "$path" == treble/app ]] && path=treble_app
    [[ "$path" == vendor/hardware/overlay ]] && path=vendor/hardware_overlay
    [[ "$path" == vendor/partner/gms ]] && path=vendor/partner_gms

    printf '%s\n' "$path"
}

capture_heads() {
    local out="$1"
    (
        cd "$ANDROID_ROOT"
        "$SABLE_REPO_TOOL" forall -c \
            'printf "%s\t%s\n" "$REPO_PATH" "$(git rev-parse HEAD)"'
    ) > "$out"
}

capture_dirty_projects() {
    local out="$1"
    (
        cd "$ANDROID_ROOT"
        "$SABLE_REPO_TOOL" forall -c \
            's="$(git status --porcelain --untracked-files=all)"; if [ -n "$s" ]; then printf "%s\n" "$REPO_PATH"; fi'
    ) > "$out"
}

verify_contract_inputs() {
    local audit_count
    local c3b_runtime_count
    local tier_count
    local tier_total

    audit_count="$(count_entries "$BUILD_AUDIT_SET")"
    c3b_runtime_count="$(count_entries "$C3B_RUNTIME_ALLOWLIST")"
    tier_count="$(awk 'NF && $1 !~ /^#/ {c++} END {print c+0}' "$TIER_FILE")"
    tier_total="$(awk 'NF && $1 !~ /^#/ {s+=$2} END {print s+0}' "$TIER_FILE")"

    [[ "$audit_count" == "$N1D_C3_BUILD_MAKE_PATCH_COUNT" ]] \
        || fail "c3a_build_make_audit_count expected=$N1D_C3_BUILD_MAKE_PATCH_COUNT actual=$audit_count"
    [[ "$c3b_runtime_count" == "$N1D_C3_RUNTIME_PATCH_ALLOWLIST_COUNT" ]] \
        || fail "c3b_runtime_patch_count expected=$N1D_C3_RUNTIME_PATCH_ALLOWLIST_COUNT actual=$c3b_runtime_count"
    [[ "$tier_count" == "$N1D_C3_CONTROL_PATCH_TIER_COUNT" ]] \
        || fail "c3a_control_tier_count expected=$N1D_C3_CONTROL_PATCH_TIER_COUNT actual=$tier_count"
    [[ "$tier_total" == "$N1D_C3_CONTROL_PATCH_COUNT" ]] \
        || fail "c3a_control_patch_count expected=$N1D_C3_CONTROL_PATCH_COUNT actual=$tier_total"

    while IFS= read -r patch; do
        [[ -z "$patch" || "$patch" == \#* ]] && continue
        [[ -f "$BUILD_PATCH_DIR/$patch" ]] \
            || fail "c3a_build_make_audit_patch_missing=$patch"
    done < "$BUILD_AUDIT_SET"

    echo "N1D_C3A_BUILD_MAKE_AUDIT_SET=PASS count=$audit_count"
    echo "N1D_C3A_CONTROL_PATCH_TIERS=PASS count=$tier_count patches=$tier_total"
    echo "N1D_C3B_RUNTIME_PATCH_ALLOWLIST=PASS_ZERO"
}

verify_graphene_base_pre_stage() {
    local manifest_head
    local count
    local dirty
    local tmp
    local path

    [[ -d "$ANDROID_ROOT/.repo/manifests/.git" ]] || fail manifest_checkout_missing
    [[ -f "$BASE_HEADS" ]] || fail "base_heads_missing=$BASE_HEADS"

    manifest_head="$(git -C "$ANDROID_ROOT/.repo/manifests" rev-parse HEAD)"
    [[ "$manifest_head" == "$N1D_GRAPHENEOS_MANIFEST_COMMIT" ]] \
        || fail "manifest_head expected=$N1D_GRAPHENEOS_MANIFEST_COMMIT actual=$manifest_head"

    if [[ -d "$LOCAL_MANIFEST_DIR" ]] \
        && [[ -n "$(find "$LOCAL_MANIFEST_DIR" -mindepth 1 -maxdepth 1 -type f -print -quit)" ]]
    then
        fail local_manifest_present_before_c3a_stage
    fi

    for path in "${scaffold_paths[@]}"; do
        [[ ! -e "$ANDROID_ROOT/$path" ]] || fail "preexisting_scaffold_path=$path"
    done

    tmp="$(mktemp -d)"
    capture_heads "$tmp/current.tsv"
    capture_dirty_projects "$tmp/dirty.tsv"

    count="$(grep -cve '^$' "$tmp/current.tsv" || true)"
    dirty="$(grep -cve '^$' "$tmp/dirty.tsv" || true)"

    [[ "$count" == "$N1D_C3_BASE_PROJECT_COUNT" ]] \
        || { rm -rf "$tmp"; fail "base_project_count expected=$N1D_C3_BASE_PROJECT_COUNT actual=$count"; }
    [[ "$dirty" == 0 ]] \
        || { cat "$tmp/dirty.tsv"; rm -rf "$tmp"; fail "base_dirty_project_count=$dirty"; }

    LC_ALL=C sort "$BASE_HEADS" > "$tmp/expected.tsv"
    LC_ALL=C sort "$tmp/current.tsv" > "$tmp/current.sorted.tsv"
    cmp -s "$tmp/expected.tsv" "$tmp/current.sorted.tsv" \
        || {
            diff -u "$tmp/expected.tsv" "$tmp/current.sorted.tsv" || true
            rm -rf "$tmp"
            fail base_heads_mismatch
        }

    rm -rf "$tmp"

    echo "N1D_C3A_PRE_STAGE_PROJECT_COUNT=PASS value=$count"
    echo "N1D_C3A_PRE_STAGE_DIRTY_PROJECT_COUNT=PASS_ZERO"
    echo "N1D_C3A_PRE_STAGE_HEADS=PASS_EXACT"
}

fetch_recipe() {
    if [[ -d "$RECIPE_ROOT/.git" ]]; then
        [[ "$(git -C "$RECIPE_ROOT" rev-parse HEAD)" == "$N1D_RESTLESS_COMMIT" ]] \
            || fail "recipe_existing_head=$(git -C "$RECIPE_ROOT" rev-parse HEAD)"
    else
        mkdir -p "$(dirname "$RECIPE_ROOT")"
        git init "$RECIPE_ROOT" >/dev/null
        git -C "$RECIPE_ROOT" remote add origin "$N1D_RESTLESS_REPO"
        git -C "$RECIPE_ROOT" fetch \
            --depth=1 \
            origin \
            "refs/tags/$N1D_RESTLESS_TAG:refs/tags/$N1D_RESTLESS_TAG"
        git -C "$RECIPE_ROOT" switch --detach "$N1D_RESTLESS_COMMIT"
    fi

    [[ -z "$(git -C "$RECIPE_ROOT" status --porcelain --untracked-files=all)" ]] \
        || fail recipe_dirty

    echo "N1D_C3A_RESTLESS_RECIPE=PASS commit=$N1D_RESTLESS_COMMIT"
}

verify_recipe_inventory() {
    local tier
    local expected_count
    local actual_count
    local total=0

    while IFS=$'\t' read -r tier expected_count; do
        [[ -z "$tier" || "$tier" == \#* ]] && continue

        actual_count="$(
            find "$RECIPE_ROOT/patches/$tier" \
                -type f -name '*.patch' -print \
                | wc -l \
                | tr -d ' '
        )"

        [[ "$actual_count" == "$expected_count" ]] \
            || fail "recipe_tier_count tier=$tier expected=$expected_count actual=$actual_count"

        total=$((total + actual_count))
    done < "$TIER_FILE"

    [[ "$total" == "$N1D_C3_CONTROL_PATCH_COUNT" ]] \
        || fail "recipe_patch_total expected=$N1D_C3_CONTROL_PATCH_COUNT actual=$total"

    echo "N1D_C3A_RESTLESS_RECIPE_PATCH_INVENTORY=PASS count=$total"
}

verify_scaffold_base_heads() {
    local path
    local actual

    for path in "${scaffold_paths[@]}"; do
        [[ -d "$ANDROID_ROOT/$path/.git" || -f "$ANDROID_ROOT/$path/.git" ]] \
            || fail "scaffold_project_missing=$path"

        actual="$(git -C "$ANDROID_ROOT/$path" rev-parse HEAD)"
        [[ "$actual" == "${expected_heads[$path]}" ]] \
            || fail "scaffold_head path=$path expected=${expected_heads[$path]} actual=$actual"

        [[ -z "$(git -C "$ANDROID_ROOT/$path" status --porcelain --untracked-files=all)" ]] \
            || fail "scaffold_dirty_before_patches=$path"
    done

    echo "N1D_C3A_TREBLEDROID_SCAFFOLD_HEADS=PASS_EXACT count=${#scaffold_paths[@]}"
}

verify_control_patch_targets() {
    local tier
    local expected_count
    local project
    local project_dir
    local missing=0

    while IFS=$'\t' read -r tier expected_count; do
        [[ -z "$tier" || "$tier" == \#* ]] && continue

        while IFS= read -r project; do
            [[ -z "$project" ]] && continue
            project_dir="$(map_patch_project "$project")"

            if [[ ! -d "$ANDROID_ROOT/$project_dir" ]]; then
                echo "N1D_C3A_CONTROL_PATCH_TARGET=FAIL tier=$tier project=$project path=$project_dir" >&2
                missing=$((missing + 1))
            fi
        done < <(
            find "$RECIPE_ROOT/patches/$tier" \
                -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
                | LC_ALL=C sort
        )
    done < "$TIER_FILE"

    [[ "$missing" == 0 ]] \
        || fail "control_patch_target_missing_count=$missing"

    echo "N1D_C3A_CONTROL_PATCH_TARGETS=PASS"
}

apply_control_patch_stack() {
    local tier
    local expected_count
    local project
    local project_dir
    local patch
    local applied=0

    while IFS=$'\t' read -r tier expected_count; do
        [[ -z "$tier" || "$tier" == \#* ]] && continue
        echo "N1D_C3A_CONTROL_PATCH_TIER=START tier=$tier expected=$expected_count"

        while IFS= read -r project; do
            [[ -z "$project" ]] && continue
            project_dir="$(map_patch_project "$project")"
            [[ -d "$ANDROID_ROOT/$project_dir" ]] \
                || fail "control_patch_project_missing tier=$tier project=$project path=$project_dir"

            while IFS= read -r patch; do
                [[ -z "$patch" ]] && continue

                if [[ -d "$ANDROID_ROOT/$project_dir/.git" || -f "$ANDROID_ROOT/$project_dir/.git" ]]; then
                    (
                        cd "$ANDROID_ROOT/$project_dir"
                        git am "$patch"
                    ) || {
                        git -C "$ANDROID_ROOT/$project_dir" am --abort >/dev/null 2>&1 || true
                        fail "control_patch_git_am tier=$tier project=$project patch=$(basename "$patch")"
                    }
                else
                    (
                        cd "$ANDROID_ROOT/$project_dir"
                        patch -p1 --no-backup-if-mismatch < "$patch"
                    ) || fail "control_patch_patch_p1 tier=$tier project=$project patch=$(basename "$patch")"
                fi

                applied=$((applied + 1))
            done < <(
                find "$RECIPE_ROOT/patches/$tier/$project" \
                    -maxdepth 1 -type f -name '*.patch' -print \
                    | LC_ALL=C sort
            )
        done < <(
            find "$RECIPE_ROOT/patches/$tier" \
                -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
                | LC_ALL=C sort
        )

        echo "N1D_C3A_CONTROL_PATCH_TIER=PASS tier=$tier"
    done < "$TIER_FILE"

    [[ "$applied" == "$N1D_C3_CONTROL_PATCH_COUNT" ]] \
        || fail "control_patch_applied expected=$N1D_C3_CONTROL_PATCH_COUNT actual=$applied"

    echo "N1D_C3A_CONTROL_PATCH_STACK=PASS count=$applied"
}

verify_postpatch_clean_and_count() {
    local heads="$1"
    local dirty="$2"
    local count
    local dirty_count

    capture_heads "$heads"
    capture_dirty_projects "$dirty"

    count="$(grep -cve '^$' "$heads" || true)"
    dirty_count="$(grep -cve '^$' "$dirty" || true)"

    [[ "$count" == 1045 ]] \
        || fail "postpatch_project_count expected=1045 actual=$count"
    [[ "$dirty_count" == 0 ]] \
        || { cat "$dirty"; fail "postpatch_dirty_count=$dirty_count"; }

    echo "N1D_C3A_POSTPATCH_PROJECT_COUNT=PASS value=1045"
    echo "N1D_C3A_POSTPATCH_DIRTY_PROJECT_COUNT=PASS_ZERO"
}

verify_build_make_patch_count() {
    local before="$1"
    local base
    local count

    base="$(awk -F '\t' '$1=="build/make"{print $2}' "$before")"
    [[ -n "$base" ]] || fail build_make_prepatch_head_missing

    count="$(git -C "$BUILD_MAKE" rev-list --count "$base..HEAD")"
    [[ "$count" == "$N1D_C3_BUILD_MAKE_PATCH_COUNT" ]] \
        || fail "build_make_patch_count expected=$N1D_C3_BUILD_MAKE_PATCH_COUNT actual=$count"

    echo "N1D_C3A_BUILD_MAKE_PATCH_STACK=PASS count=$count"
}

verify_generated_product() {
    local product="$TD_ROOT/treble_arm64_bvN.mk"

    [[ -f "$TD_ROOT/AndroidProducts.mk" ]] || fail generated_android_products_missing
    [[ -f "$product" ]] || fail generated_product_missing

    grep -Fq 'include build/make/target/product/aosp_arm64.mk' "$product" \
        || fail generated_aosp_arm64_base_missing
    grep -Fq '$(call inherit-product, device/phh/treble/base.mk)' "$product" \
        || fail generated_phh_base_missing
    grep -Fq '$(call inherit-product, device/phh/treble/rom.mk)' "$product" \
        || fail generated_rom_config_missing
    grep -Fq 'PRODUCT_NAME := treble_arm64_bvN' "$product" \
        || fail generated_product_name_missing
    grep -Fq 'PRODUCT_DEVICE := tdgsi_arm64_ab' "$product" \
        || fail generated_product_device_missing

    echo "N1D_C3A_GENERATED_PRODUCT=PASS product=treble_arm64_bvN"
}

verify_td_generated_dirty_scope() {
    local line
    local path

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        path="${line:3}"

        case "$path" in
            AndroidProducts.mk|rom.mk|treble_*.mk)
                ;;
            *)
                fail "unexpected_device_phh_dirty_path=$path"
                ;;
        esac
    done < <(git -C "$TD_ROOT" status --porcelain --untracked-files=all)

    echo "N1D_C3A_DEVICE_PHH_GENERATED_DIRTY_SCOPE=PASS"
}

latest_stage_evidence() {
    find "$EVIDENCE_ROOT" \
        -mindepth 1 -maxdepth 1 -type d -name '*-trebledroid-stage' \
        -print 2>/dev/null \
        | LC_ALL=C sort \
        | tail -1
}

preflight() {
    echo "===== N1D C3A RESTLESS/TREBLEDROID CONTROL PREFLIGHT ====="
    echo "SOURCE_MUTATION_AUTHORIZED=NO"
    echo "NETWORK_FETCH_AUTHORIZED=NO"
    echo "BUILD_AUTHORIZED=NO"
    echo "DEVICE_CONTACT_AUTHORIZED=NO"
    echo "FLASH_AUTHORIZED=NO"
    echo "N1D_C3_ACTIVE_PHASE=C3A_CONTROL"
    echo "C3A_RELEASE_ELIGIBLE=NO"
    echo "C3B_BUILD_AUTHORIZED=NO_UNTIL_C3A_CONTROL_EVIDENCE"

    bash "$STORAGE_VERIFY" runtime
    bash "$SOURCE_GATE"
    verify_contract_inputs
    verify_graphene_base_pre_stage

    if [[ -e "$OLD_PRODUCT" ]]; then
        echo "N1D_C3_HANDCRAFTED_PRODUCT=PRESENT_WILL_ARCHIVE"
    else
        echo "N1D_C3_HANDCRAFTED_PRODUCT=ABSENT"
    fi

    echo "N1D_C3A_TREBLEDROID_REBASELINE_PREFLIGHT=PASS"
}

stage() {
    local stamp
    local evidence
    local retired

    echo "===== N1D C3A RESTLESS/TREBLEDROID CONTROL STAGE ====="

    [[ "$SOURCE_MUTATION_AUTHORIZED" == YES ]] \
        || fail stage_requires_--authorize-source-mutation
    [[ "$NETWORK_FETCH_AUTHORIZED" == YES ]] \
        || fail stage_requires_--authorize-network

    echo "SOURCE_MUTATION_AUTHORIZED=YES_PINNED_RESTLESS_CONTROL_RECIPE_ONLY"
    echo "NETWORK_FETCH_AUTHORIZED=YES_PINNED_RECIPE_AND_SCAFFOLD_ONLY"
    echo "BUILD_AUTHORIZED=NO"
    echo "DEVICE_CONTACT_AUTHORIZED=NO"
    echo "FLASH_AUTHORIZED=NO"
    echo "N1D_C3_ACTIVE_PHASE=C3A_CONTROL"
    echo "C3A_RELEASE_ELIGIBLE=NO"
    echo "C3B_BUILD_AUTHORIZED=NO_UNTIL_C3A_CONTROL_EVIDENCE"

    bash "$STORAGE_VERIFY" runtime
    bash "$SOURCE_GATE"
    verify_contract_inputs
    verify_graphene_base_pre_stage
    fetch_recipe
    verify_recipe_inventory

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
        "$SABLE_REPO_TOOL" sync \
            --force-sync \
            --no-clone-bundle \
            --no-tags \
            --jobs=4 \
            "${scaffold_paths[@]}"
    )

    verify_scaffold_base_heads
    verify_control_patch_targets

    capture_heads "$evidence/prepatch-project-heads.tsv"
    capture_dirty_projects "$evidence/prepatch-dirty-projects.txt"
    [[ ! -s "$evidence/prepatch-dirty-projects.txt" ]] || fail prepatch_dirty

    apply_control_patch_stack

    verify_postpatch_clean_and_count \
        "$evidence/postpatch-project-heads.tsv" \
        "$evidence/postpatch-dirty-projects.txt"
    verify_build_make_patch_count "$evidence/prepatch-project-heads.tsv"

    cp -a "$ROM_SRC" "$TD_ROOT/rom.mk"
    (
        cd "$TD_ROOT"
        bash generate.sh rom
    )

    verify_generated_product
    verify_td_generated_dirty_scope

    cp -a "$MANIFEST_SRC" "$evidence/n1d-c3a-trebledroid-manifest.xml"
    cp -a "$ROM_SRC" "$evidence/rom.mk"
    cp -a "$TIER_FILE" "$evidence/control-patch-tiers.tsv"
    cp -a "$BUILD_AUDIT_SET" "$evidence/c3a-build-make-audit-set.txt"
    cp -a "$C3B_RUNTIME_ALLOWLIST" "$evidence/c3b-runtime-patch-allowlist.txt"
    git -C "$TD_ROOT" status --porcelain --untracked-files=all \
        > "$evidence/device-phh-generated-status.txt"

    {
        echo "N1D_C3A_TREBLEDROID_STAGE=PASS"
        echo "N1D_C3_ACTIVE_PHASE=C3A_CONTROL"
        echo "N1D_C3_RESTLESS_RECIPE_COMMIT=$N1D_RESTLESS_COMMIT"
        echo "N1D_C3A_CONTROL_PATCH_COUNT=$N1D_C3_CONTROL_PATCH_COUNT"
        echo "N1D_C3A_CONTROL_PATCH_TIER_COUNT=$N1D_C3_CONTROL_PATCH_TIER_COUNT"
        echo "N1D_C3A_GENERATED_PRODUCT=$N1D_C3_GENERATED_PRODUCT"
        echo "N1D_C3A_RELEASE_CONFIG=$N1D_C3_RELEASE_CONFIG"
        echo "N1D_C3A_VARIANT=$N1D_C3_FIRST_VARIANT"
        echo "N1D_C3B_RUNTIME_PATCH_ALLOWLIST_COUNT=$N1D_C3_RUNTIME_PATCH_ALLOWLIST_COUNT"
        echo "N1D_C3A_RELEASE_ELIGIBLE=NO"
        echo "N1D_C3B_BUILD_AUTHORIZED=NO_UNTIL_C3A_CONTROL_EVIDENCE"
    } > "$evidence/stage-state.env"

    (
        cd "$evidence"
        find . -type f ! -name SHA256SUMS.txt -print0 \
            | LC_ALL=C sort -z \
            | xargs -0 sha256sum > SHA256SUMS.txt
        sha256sum -c SHA256SUMS.txt >/dev/null
    )

    echo "N1D_C3A_TREBLEDROID_STAGE=PASS"
    echo "EVIDENCE_DIR=$evidence"
}

verify() {
    local evidence
    local count
    local current_heads

    echo "===== N1D C3A RESTLESS/TREBLEDROID CONTROL VERIFY ====="
    echo "SOURCE_MUTATION_AUTHORIZED=NO"
    echo "NETWORK_FETCH_AUTHORIZED=NO"
    echo "BUILD_AUTHORIZED=NO"
    echo "DEVICE_CONTACT_AUTHORIZED=NO"
    echo "FLASH_AUTHORIZED=NO"
    echo "N1D_C3_ACTIVE_PHASE=C3A_CONTROL"
    echo "C3A_RELEASE_ELIGIBLE=NO"
    echo "C3B_BUILD_AUTHORIZED=NO_UNTIL_C3A_CONTROL_EVIDENCE"

    bash "$STORAGE_VERIFY" runtime
    bash "$SOURCE_GATE"
    verify_contract_inputs

    [[ -d "$RECIPE_ROOT/.git" ]] || fail recipe_missing
    [[ "$(git -C "$RECIPE_ROOT" rev-parse HEAD)" == "$N1D_RESTLESS_COMMIT" ]] \
        || fail recipe_head_mismatch

    verify_recipe_inventory
    cmp -s "$MANIFEST_SRC" "$LOCAL_MANIFEST" || fail local_manifest_mismatch

    evidence="$(latest_stage_evidence)"
    [[ -n "$evidence" ]] || fail stage_evidence_missing
    (
        cd "$evidence"
        sha256sum -c SHA256SUMS.txt >/dev/null
    ) || fail stage_evidence_invalid

    current_heads="$(mktemp)"
    capture_heads "$current_heads"
    count="$(grep -cve '^$' "$current_heads" || true)"
    [[ "$count" == 1045 ]] \
        || { rm -f "$current_heads"; fail "current_project_count expected=1045 actual=$count"; }

    LC_ALL=C sort "$current_heads" > "$current_heads.sorted"
    LC_ALL=C sort "$evidence/postpatch-project-heads.tsv" > "$current_heads.expected"
    cmp -s "$current_heads.sorted" "$current_heads.expected" \
        || {
            diff -u "$current_heads.expected" "$current_heads.sorted" || true
            rm -f "$current_heads" "$current_heads.sorted" "$current_heads.expected"
            fail postpatch_heads_mismatch
        }

    rm -f "$current_heads" "$current_heads.sorted" "$current_heads.expected"

    verify_generated_product
    verify_td_generated_dirty_scope

    echo "N1D_C3A_POSTPATCH_HEADS=PASS_EXACT value=1045"
    echo "N1D_C3B_RUNTIME_PATCH_ALLOWLIST=PASS_ZERO"
    echo "N1D_C3A_TREBLEDROID_REBASELINE_VERIFY=PASS"
}

case "$ACTION" in
    preflight)
        preflight
        ;;
    stage)
        stage
        ;;
    verify)
        verify
        ;;
    *)
        fail "unknown_action=$ACTION"
        ;;
esac
