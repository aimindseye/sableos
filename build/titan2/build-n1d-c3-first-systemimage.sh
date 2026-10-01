#!/usr/bin/env bash
# First Titan 2 N1D C3 target compilation: systemimage only.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STORAGE_PROFILE="$ROOT/build/config/storage.env"
HOST_PROFILE="$ROOT/build/config/host-tools.env"
SOURCE_LOCK="$ROOT/build/titan2/n1d-source-lock.env"
FRESH_PROFILE="$ROOT/build/titan2/n1d-fresh-source.env"
C3_PROFILE="$ROOT/build/titan2/n1d-c3-composition.env"
COMPILE_PROFILE="$ROOT/build/titan2/n1d-c3-compile.env"
STAGE_DRIVER="$ROOT/build/titan2/stage-n1d-c3-product.sh"
STORAGE_VERIFY="$ROOT/build/host/verify-storage-root.sh"
SOURCE_GATE="$ROOT/build/gates/n1d-source-lock-contract.sh"

fail() {
    echo "N1D_C3_FIRST_COMPILE=FAIL $*" >&2
    exit 1
}

for f in     "$STORAGE_PROFILE"     "$HOST_PROFILE"     "$SOURCE_LOCK"     "$FRESH_PROFILE"     "$C3_PROFILE"     "$COMPILE_PROFILE"     "$STAGE_DRIVER"     "$STORAGE_VERIFY"     "$SOURCE_GATE"
do
    [[ -f "$f" ]] || fail "missing_file=$f"
done

# shellcheck source=/dev/null
source "$STORAGE_PROFILE"
# shellcheck source=/dev/null
source "$HOST_PROFILE"
# shellcheck source=/dev/null
source "$SOURCE_LOCK"
# shellcheck source=/dev/null
source "$FRESH_PROFILE"
# shellcheck source=/dev/null
source "$C3_PROFILE"
# shellcheck source=/dev/null
source "$COMPILE_PROFILE"

COMPILE_AUTHORIZED=NO
FAILED_OUT_RETIREMENT_AUTHORIZED=NO
JOBS="$(nproc --all)"

while (($#)); do
    case "$1" in
        --authorize-c3-compile)
            COMPILE_AUTHORIZED=YES
            shift
            ;;
        --authorize-failed-out-retirement)
            FAILED_OUT_RETIREMENT_AUTHORIZED=YES
            shift
            ;;
        --jobs)
            [[ $# -ge 2 ]] || fail "jobs_value_missing"
            JOBS="$2"
            shift 2
            ;;
        *)
            fail "unknown_arg=$1"
            ;;
    esac
done

[[ "$COMPILE_AUTHORIZED" == YES ]] || fail "compile_requires_--authorize-c3-compile"
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || fail "invalid_jobs=$JOBS"

ANDROID_ROOT="$SABLE_BUILD_ROOT/$N1D_ANDROID_ROOT_REL"
OUT_C2="$SABLE_BUILD_ROOT/$N1D_OUT_C2_REL"
OUT_C3="$SABLE_BUILD_ROOT/$N1D_C3_COMPILE_OUT_REL"
BASE_SEAL="$SABLE_BUILD_ROOT/$N1D_C3_BASE_SEAL_REL"
BASE_HEADS="$BASE_SEAL/all-project-heads.tsv"
SOURCE_BUNDLE="$ROOT/$N1D_C3_SOURCE_BUNDLE_REL"
STAGE_TARGET="$ANDROID_ROOT/$N1D_C3_STAGE_TARGET_REL"
PARSE_EVIDENCE_ROOT="$SABLE_BUILD_ROOT/$N1D_C3_PARSE_EVIDENCE_REL"
COMPILE_EVIDENCE_ROOT="$SABLE_BUILD_ROOT/$N1D_C3_COMPILE_EVIDENCE_REL"
FAILED_OUT_ARCHIVE_ROOT="$SABLE_BUILD_ROOT/$N1D_C3_FAILED_OUT_ARCHIVE_REL"
FAILED_OUT_RETIREMENT_EVIDENCE_ROOT="$SABLE_BUILD_ROOT/$N1D_C3_FAILED_OUT_RETIREMENT_EVIDENCE_REL"
LUNCH_TARGET="${N1D_C3_COMPILE_PRODUCT}-${N1D_C3_COMPILE_RELEASE_CONFIG}-${N1D_C3_COMPILE_VARIANT}"

echo "===== TITAN 2 N1D C3 FIRST SYSTEMIMAGE COMPILE ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=YES_C3_SYSTEMIMAGE_ONLY"
echo "IMAGE_BUILD_AUTHORIZED=YES_C3_SYSTEMIMAGE_ONLY"
echo "TARGET_FILES_BUILD_AUTHORIZED=NO"
echo "OTA_BUILD_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "PRODUCTION_SIGNING_AUTHORIZED=NO"
echo "FAILED_OUT_RETIREMENT_AUTHORIZED=$FAILED_OUT_RETIREMENT_AUTHORIZED"
echo "LUNCH_TARGET=$LUNCH_TARGET"
echo "BUILD_GOAL=$N1D_C3_FIRST_COMPILE_GOAL"
echo "JOBS=$JOBS"

[[ "$N1D_C3_COMPILE_PRODUCT" == "$N1D_C3_PRODUCT_NAME" ]]     || fail "compile_product_profile_mismatch"
[[ "$N1D_C3_COMPILE_RELEASE_CONFIG" == "$N1D_C3_RELEASE_CONFIG" ]]     || fail "compile_release_profile_mismatch"
[[ "$N1D_C3_COMPILE_VARIANT" == "$N1D_C3_FIRST_BUILD_VARIANT" ]]     || fail "compile_variant_profile_mismatch"
[[ "$N1D_C3_COMPILE_PRODUCT_DEVICE" == "$N1D_C3_PRODUCT_DEVICE" ]]     || fail "compile_device_profile_mismatch"
[[ "$N1D_C3_COMPILE_BUILDING_GSI" == "$N1D_C3_BUILDING_GSI_VALUE" ]]     || fail "compile_building_gsi_profile_mismatch"
[[ "$N1D_C3_FIRST_COMPILE_GOAL" == systemimage ]]     || fail "unexpected_compile_goal=$N1D_C3_FIRST_COMPILE_GOAL"
[[ "$N1D_C3_BUILD_SANDBOX_POLICY" == ADVISORY_HOST_DEPENDENT ]]     || fail "unexpected_build_sandbox_policy=$N1D_C3_BUILD_SANDBOX_POLICY"

bash "$STORAGE_VERIFY" runtime
bash "$SOURCE_GATE"
bash "$STAGE_DRIVER" verify

[[ -d "$ANDROID_ROOT" ]] || fail "android_root_missing=$ANDROID_ROOT"
[[ -f "$ANDROID_ROOT/build/envsetup.sh" ]] || fail "envsetup_missing=$ANDROID_ROOT/build/envsetup.sh"
[[ ! -e "$OUT_C2" ]] || fail "unexpected_c2_out=$OUT_C2"

mapfile -t parse_candidates < <(
    find "$PARSE_EVIDENCE_ROOT"         -mindepth 1         -maxdepth 1         -type d         -name '*-c3-product-parse'         -print 2>/dev/null | LC_ALL=C sort
)
(("${#parse_candidates[@]}" > 0)) || fail "parse_evidence_missing=$PARSE_EVIDENCE_ROOT"
PARSE_EVIDENCE="${parse_candidates[-1]}"

[[ -f "$PARSE_EVIDENCE/SHA256SUMS.txt" ]]     || fail "parse_evidence_seal_missing=$PARSE_EVIDENCE"
(
    cd "$PARSE_EVIDENCE"
    sha256sum -c SHA256SUMS.txt >/dev/null
) || fail "parse_evidence_seal_invalid=$PARSE_EVIDENCE"

for required in     'N1D_C3_PRODUCT_PARSE=PASS'     "N1D_C3_PRODUCT_NAME=$N1D_C3_COMPILE_PRODUCT"     "N1D_C3_PRODUCT_DEVICE=$N1D_C3_COMPILE_PRODUCT_DEVICE"     "N1D_C3_BUILDING_GSI=$N1D_C3_COMPILE_BUILDING_GSI"     'N1D_C3_SOONG_AOSP_SYSTEM_IMAGE_ENABLED=NO'     "N1D_C3_RELEASE_CONFIG=$N1D_C3_COMPILE_RELEASE_CONFIG"     "N1D_C3_BUILD_VARIANT=$N1D_C3_COMPILE_VARIANT"     'ANDROID_TARGET_COMPILATION_AUTHORIZED=NO'     'NINJA_BUILD_AUTHORIZED=NO'     'TARGET_ARTIFACT_BUILD_AUTHORIZED=NO'     'DEVICE_CONTACT_AUTHORIZED=NO'     'FLASH_AUTHORIZED=NO'
do
    grep -Fxq "$required" "$PARSE_EVIDENCE/parse-state.env"         || fail "parse_state_missing=$required"
done

RETIRED_OUT=NONE
if [[ -e "$OUT_C3" ]]; then
    [[ "$FAILED_OUT_RETIREMENT_AUTHORIZED" == YES ]]         || fail "c3_out_exists_retry_requires_--authorize-failed-out-retirement"

    active_builds="$(
        ps -eo pid=,args=             | grep -E 'soong_ui|soong_build|ninja'             | grep -F "$OUT_C3"             | grep -v grep             || true
    )"
    if [[ -n "$active_builds" ]]; then
        printf '%s\n' "$active_builds" >&2
        fail "c3_out_has_active_build_process"
    fi

    retire_stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    RETIRED_OUT="$FAILED_OUT_ARCHIVE_ROOT/$retire_stamp-first-compile-failed"
    RETIRE_EVIDENCE="$FAILED_OUT_RETIREMENT_EVIDENCE_ROOT/$retire_stamp-first-compile-failed"

    [[ ! -e "$RETIRED_OUT" ]] || fail "failed_out_archive_exists=$RETIRED_OUT"
    mkdir -p "$FAILED_OUT_ARCHIVE_ROOT" "$RETIRE_EVIDENCE"

    mv "$OUT_C3" "$RETIRED_OUT"

    retired_bytes="$(du -sb "$RETIRED_OUT" | awk '{print $1}')"
    {
        echo "N1D_C3_FAILED_OUT_RETIREMENT=PASS"
        echo "N1D_C3_FAILED_OUT_ORIGINAL=$OUT_C3"
        echo "N1D_C3_FAILED_OUT_RETIRED=$RETIRED_OUT"
        echo "N1D_C3_FAILED_OUT_BYTES=$retired_bytes"
        echo "N1D_C3_FAILED_OUT_REASON=GRAPHENE_GSI_SOONG_MODULE_GRAPH_MISMATCH"
        echo "SOURCE_MUTATION_AUTHORIZED=NO"
        echo "NETWORK_FETCH_AUTHORIZED=NO"
        echo "DEVICE_CONTACT_AUTHORIZED=NO"
        echo "FLASH_AUTHORIZED=NO"
    } > "$RETIRE_EVIDENCE/retirement-state.env"
    (
        cd "$RETIRE_EVIDENCE"
        sha256sum retirement-state.env > SHA256SUMS.txt
        sha256sum -c SHA256SUMS.txt >/dev/null
    )

    echo "N1D_C3_FAILED_OUT_RETIREMENT=PASS"
    echo "RETIRED_OUT=$RETIRED_OUT"
    echo "RETIREMENT_EVIDENCE=$RETIRE_EVIDENCE"
else
    echo "N1D_C3_FAILED_OUT_RETIREMENT=NOT_REQUIRED"
fi

[[ ! -e "$OUT_C3" ]] || fail "c3_out_not_clean_after_retirement=$OUT_C3"

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="$COMPILE_EVIDENCE_ROOT/$stamp-c3-first-compile"
mkdir -p "$EVIDENCE_DIR"

exec > >(tee "$EVIDENCE_DIR/build.log") 2>&1

echo "PARSE_EVIDENCE=$PARSE_EVIDENCE"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "OUT_DIR=$OUT_C3"
echo "N1D_C3_BUILD_SANDBOX_POLICY=$N1D_C3_BUILD_SANDBOX_POLICY"

capture_heads() {
    local out="$1"
    (
        cd "$ANDROID_ROOT"
        "$SABLE_REPO_TOOL" forall -c             'printf "%s\t%s\n" "$REPO_PATH" "$(git rev-parse HEAD)"'
    ) > "$out"
}

capture_dirty() {
    local out="$1"
    (
        cd "$ANDROID_ROOT"
        "$SABLE_REPO_TOOL" forall -c             'status="$(git status --porcelain --untracked-files=all)"; if [ -n "$status" ]; then printf "%s\n" "$REPO_PATH"; fi'
    ) > "$out"
}

verify_post_build_source() {
    local manifest_head count dirty
    manifest_head="$(git -C "$ANDROID_ROOT/.repo/manifests" rev-parse HEAD)"
    [[ "$manifest_head" == "$N1D_GRAPHENE_MANIFEST_COMMIT" ]]         || fail "post_build_manifest_head expected=$N1D_GRAPHENE_MANIFEST_COMMIT actual=$manifest_head"

    if [[ -d "$ANDROID_ROOT/.repo/local_manifests" ]]         && [[ -n "$(find "$ANDROID_ROOT/.repo/local_manifests" -mindepth 1 -maxdepth 1 -type f -print -quit)" ]]
    then
        fail "post_build_local_manifest_present"
    fi

    for path in         device/phh/treble         packages/apps/QcRilAm         prebuilts/vndk/v28         prebuilts/vndk/v29         prebuilts/vndk/v30         treble_app         vendor/apn         vendor/hardware_overlay         vendor/interfaces         vendor/lptools         vendor/magisk         vendor/pixel/gsans         vendor/vndk-tests
    do
        [[ ! -e "$ANDROID_ROOT/$path" ]]             || fail "post_build_retired_c2_path_present=$path"
    done

    capture_heads "$EVIDENCE_DIR/post-build-heads.tsv"
    capture_dirty "$EVIDENCE_DIR/post-build-dirty.tsv"

    count="$(grep -cve '^$' "$EVIDENCE_DIR/post-build-heads.tsv" || true)"
    dirty="$(grep -cve '^$' "$EVIDENCE_DIR/post-build-dirty.tsv" || true)"

    [[ "$count" == "$N1D_C3_BASE_PROJECT_COUNT" ]]         || fail "post_build_project_count expected=$N1D_C3_BASE_PROJECT_COUNT actual=$count"
    [[ "$dirty" == 0 ]]         || fail "post_build_dirty_project_count=$dirty"

    LC_ALL=C sort "$BASE_HEADS" > "$EVIDENCE_DIR/expected-heads.sorted.tsv"
    LC_ALL=C sort "$EVIDENCE_DIR/post-build-heads.tsv" > "$EVIDENCE_DIR/post-build-heads.sorted.tsv"
    cmp -s         "$EVIDENCE_DIR/expected-heads.sorted.tsv"         "$EVIDENCE_DIR/post-build-heads.sorted.tsv"         || fail "post_build_base_heads_mismatch"

    for name in         AndroidProducts.mk         sable_titan2_n1d_arm64.mk         treble_compat.mk         sable_n1d_product_delta.mk         restless-patch-allowlist.txt
    do
        cmp -s "$SOURCE_BUNDLE/$name" "$STAGE_TARGET/$name"             || fail "post_build_staged_file_mismatch=$name"
    done

    echo "N1D_C3_POST_BUILD_PROJECT_COUNT=PASS value=$count"
    echo "N1D_C3_POST_BUILD_DIRTY_PROJECT_COUNT=PASS_ZERO"
    echo "N1D_C3_POST_BUILD_BASE_HEADS=PASS_EXACT"
    echo "N1D_C3_POST_BUILD_STAGED_BUNDLE=PASS"
}

(
    cd "$ANDROID_ROOT"
    export OUT_DIR="$OUT_C3"

    set +e +u
    # shellcheck source=/dev/null
    source build/envsetup.sh
    envsetup_rc=$?
    set -euo pipefail
    [[ "$envsetup_rc" -eq 0 ]] || fail "envsetup_source_rc=$envsetup_rc"
    echo "N1D_C3_COMPILE_ENVSETUP=PASS"

    set +e +u
    lunch "$LUNCH_TARGET" > "$EVIDENCE_DIR/compile-lunch.log" 2>&1
    lunch_rc=$?
    set -euo pipefail
    cat "$EVIDENCE_DIR/compile-lunch.log"
    [[ "$lunch_rc" -eq 0 ]] || fail "lunch_rc=$lunch_rc"
    if grep -Fq "Build sandboxing disabled due to nsjail error." "$EVIDENCE_DIR/compile-lunch.log"; then
        echo "N1D_C3_BUILD_SANDBOX_LUNCH=WARN_UNAVAILABLE_HOST_POLICY"
    else
        echo "N1D_C3_BUILD_SANDBOX_LUNCH=PASS_NSJAIL"
    fi
    echo "N1D_C3_COMPILE_LUNCH=PASS target=$LUNCH_TARGET"

    [[ "${TARGET_PRODUCT:-}" == "$N1D_C3_COMPILE_PRODUCT" ]]         || fail "target_product expected=$N1D_C3_COMPILE_PRODUCT actual=${TARGET_PRODUCT:-unset}"
    [[ "${TARGET_RELEASE:-}" == "$N1D_C3_COMPILE_RELEASE_CONFIG" ]]         || fail "target_release expected=$N1D_C3_COMPILE_RELEASE_CONFIG actual=${TARGET_RELEASE:-unset}"
    [[ "${TARGET_BUILD_VARIANT:-}" == "$N1D_C3_COMPILE_VARIANT" ]]         || fail "target_variant expected=$N1D_C3_COMPILE_VARIANT actual=${TARGET_BUILD_VARIANT:-unset}"

    set +e +u
    product_out="$(get_build_var PRODUCT_OUT)"
    product_out_rc=$?
    set -euo pipefail
    [[ "$product_out_rc" -eq 0 ]] || fail "get_product_out_rc=$product_out_rc"
    [[ -n "$product_out" ]] || fail "product_out_empty"
    printf '%s\n' "$product_out" > "$EVIDENCE_DIR/product-out.txt"
    echo "N1D_C3_COMPILE_PRODUCT_OUT=$product_out"

    echo "N1D_C3_COMPILE_GOALS=systemimage"
    set +e +u
    m -j"$JOBS" systemimage 2>&1 | tee "$EVIDENCE_DIR/systemimage-command.log"
    build_rc="${PIPESTATUS[0]}"
    set -euo pipefail
    [[ "$build_rc" -eq 0 ]] || fail "systemimage_build_rc=$build_rc"
    if grep -Fq "Build sandboxing disabled due to nsjail error." "$EVIDENCE_DIR/systemimage-command.log"; then
        echo "N1D_C3_BUILD_SANDBOX_SYSTEMIMAGE=WARN_UNAVAILABLE_HOST_POLICY"
    else
        echo "N1D_C3_BUILD_SANDBOX_SYSTEMIMAGE=PASS_NSJAIL"
    fi
    echo "N1D_C3_SYSTEMIMAGE_BUILD=PASS"
)

PRODUCT_OUT="$(cat "$EVIDENCE_DIR/product-out.txt")"
SYSTEM_IMG="$PRODUCT_OUT/system.img"

[[ -f "$SYSTEM_IMG" ]] || fail "system_img_missing=$SYSTEM_IMG"

if find "$OUT_C3" -type f     \( -name '*target_files*.zip' -o -name '*ota*.zip' \)     -print -quit | grep -q .
then
    fail "unauthorized_packaging_artifact_present=$OUT_C3"
fi

SYSTEM_SHA256="$(sha256sum "$SYSTEM_IMG" | awk '{print $1}')"
SYSTEM_BYTES="$(stat -c '%s' "$SYSTEM_IMG")"
SYSTEM_FILE_TYPE="$(file -b "$SYSTEM_IMG" 2>/dev/null || true)"

verify_post_build_source

{
    echo "N1D_C3_FIRST_COMPILE=PASS"
    echo "N1D_C3_COMPILE_PRODUCT=$N1D_C3_COMPILE_PRODUCT"
    echo "N1D_C3_COMPILE_RELEASE_CONFIG=$N1D_C3_COMPILE_RELEASE_CONFIG"
    echo "N1D_C3_COMPILE_VARIANT=$N1D_C3_COMPILE_VARIANT"
    echo "N1D_C3_FIRST_COMPILE_GOAL=$N1D_C3_FIRST_COMPILE_GOAL"
    echo "N1D_C3_PARSE_EVIDENCE=$PARSE_EVIDENCE"
    echo "N1D_C3_RETIRED_FAILED_OUT=$RETIRED_OUT"
    echo "N1D_C3_OUT_DIR=$OUT_C3"
    echo "N1D_C3_PRODUCT_OUT=$PRODUCT_OUT"
    echo "N1D_C3_SYSTEM_IMG=$SYSTEM_IMG"
    echo "N1D_C3_SYSTEM_SHA256=$SYSTEM_SHA256"
    echo "N1D_C3_SYSTEM_BYTES=$SYSTEM_BYTES"
    echo "N1D_C3_SYSTEM_FILE_TYPE=$SYSTEM_FILE_TYPE"
    echo "TARGET_FILES_BUILD_AUTHORIZED=NO"
    echo "OTA_BUILD_AUTHORIZED=NO"
    echo "NETWORK_FETCH_AUTHORIZED=NO"
    echo "DEVICE_CONTACT_AUTHORIZED=NO"
    echo "FLASH_AUTHORIZED=NO"
    echo "PRODUCTION_SIGNING_AUTHORIZED=NO"
    echo "N1D_C3_BUILD_SANDBOX_POLICY=$N1D_C3_BUILD_SANDBOX_POLICY"
    if grep -Fq "Build sandboxing disabled due to nsjail error." "$EVIDENCE_DIR/compile-lunch.log" "$EVIDENCE_DIR/systemimage-command.log"; then
        echo "N1D_C3_BUILD_SANDBOX_STATUS=WARN_UNAVAILABLE_HOST_POLICY"
    else
        echo "N1D_C3_BUILD_SANDBOX_STATUS=PASS_NSJAIL"
    fi
} > "$EVIDENCE_DIR/compile-state.env"

(
    cd "$EVIDENCE_DIR"
    find . -type f         ! -name SHA256SUMS.txt         ! -name build.log         -print0         | LC_ALL=C sort -z         | xargs -0 sha256sum > SHA256SUMS.txt
    sha256sum -c SHA256SUMS.txt >/dev/null
)

echo "SYSTEM_IMG=$SYSTEM_IMG"
echo "SYSTEM_SHA256=$SYSTEM_SHA256"
echo "SYSTEM_BYTES=$SYSTEM_BYTES"
echo "N1D_C3_FIRST_COMPILE_NO_TARGET_FILES_OTA=PASS"
echo "N1D_C3_FIRST_COMPILE_SOURCE_INTEGRITY=PASS"
echo "N1D_C3_FIRST_COMPILE=PASS"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
