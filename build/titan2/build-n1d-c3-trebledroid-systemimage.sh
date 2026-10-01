#!/usr/bin/env bash
# First N1D C3 compile using the pinned Restless/TrebleDroid-generated product.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STORAGE_PROFILE="$ROOT/build/config/storage.env"
HOST_PROFILE="$ROOT/build/config/host-tools.env"
FRESH_PROFILE="$ROOT/build/titan2/n1d-fresh-source.env"
TD_PROFILE="$ROOT/build/titan2/n1d-c3-trebledroid.env"
PHASE_PROFILE="$ROOT/build/titan2/n1d-c3-phase-split.env"
PRODUCT_PROFILE="$ROOT/build/titan2/n1d-product-contract.env"
PREP="$ROOT/build/titan2/prepare-n1d-c3-trebledroid.sh"
STORAGE_VERIFY="$ROOT/build/host/verify-storage-root.sh"
HOST_LAYOUT_PATCH="$ROOT/patches/android-16-n1d-trebledroid/host-layout/0001-soong-ci-tests-skip-out-of-tree-host-paths.patch"
DEXPREOPT_OUTDIR_PATCH="$ROOT/patches/android-16-n1d-trebledroid/host-layout/0002-soong-dexpreopt-gen-support-out-of-tree-product-packages.patch"

fail() { echo "N1D_C3A_TREBLEDROID_BUILD=FAIL $*" >&2; exit 1; }

for f in "$STORAGE_PROFILE" "$HOST_PROFILE" "$FRESH_PROFILE" "$TD_PROFILE" "$PHASE_PROFILE" "$PRODUCT_PROFILE" "$PREP" "$STORAGE_VERIFY" "$HOST_LAYOUT_PATCH" "$DEXPREOPT_OUTDIR_PATCH"; do
    [[ -f "$f" ]] || fail "missing_file=$f"
done

# shellcheck source=/dev/null
source "$STORAGE_PROFILE"
# shellcheck source=/dev/null
source "$HOST_PROFILE"
# shellcheck source=/dev/null
source "$FRESH_PROFILE"
# shellcheck source=/dev/null
source "$TD_PROFILE"
# shellcheck source=/dev/null
source "$PRODUCT_PROFILE"
# shellcheck source=/dev/null
source "$PHASE_PROFILE"
[[ "$N1D_C3A_ROLE" == RESTLESS_TREBLEDROID_REPRODUCTION_CONTROL ]] || fail c3a_role_mismatch
[[ "$N1D_C3A_RELEASE_ELIGIBLE" == NO ]] || fail c3a_release_boundary_mismatch
[[ "$N1D_C3B_BUILD_AUTHORIZED" == NO_UNTIL_C3A_CONTROL_EVIDENCE ]] || fail c3b_build_boundary_mismatch
[[ "$N1D_C3_RELEASE_ELIGIBLE" == NO ]] || fail c3_release_boundary_mismatch
[[ "$N1D_C3_TREBLE_APP_JDK_MAJOR" == 17 ]] || fail treble_app_jdk_major_mismatch
[[ "$N1D_C3_TREBLE_APP_JDK_SOURCE" == SABLE_JDK17 ]] || fail treble_app_jdk_source_mismatch

BUILD_AUTHORIZED=NO
NETWORK_FETCH_AUTHORIZED=NO
RESUME_FAILED_BUILD_AUTHORIZED=NO
HOST_LAYOUT_SOURCE_MUTATION_AUTHORIZED=NO
JOBS="$(nproc --all)"
while (($#)); do
    case "$1" in
        --authorize-c3-compile) BUILD_AUTHORIZED=YES; shift ;;
        --authorize-network) NETWORK_FETCH_AUTHORIZED=YES; shift ;;
        --resume-failed-c3-build) RESUME_FAILED_BUILD_AUTHORIZED=YES; shift ;;
        --authorize-host-layout-source-mutation) HOST_LAYOUT_SOURCE_MUTATION_AUTHORIZED=YES; shift ;;
        --jobs)
            [[ $# -ge 2 ]] || fail jobs_value_missing
            JOBS="$2"
            shift 2
            ;;
        *) fail "unknown_arg=$1" ;;
    esac
done

[[ "$BUILD_AUTHORIZED" == YES ]] || fail compile_requires_--authorize-c3-compile
[[ "$NETWORK_FETCH_AUTHORIZED" == YES ]] || fail build_requires_--authorize-network_for_treble_app
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || fail "invalid_jobs=$JOBS"

ANDROID_ROOT="$SABLE_BUILD_ROOT/$N1D_ANDROID_ROOT_REL"
OUT_C3="$SABLE_BUILD_ROOT/$N1D_ANDROID_WORKSPACE_REL/out-c3a-td"
BUILD_SOONG_ROOT="$ANDROID_ROOT/$N1D_C3A_HOST_LAYOUT_TARGET_PROJECT"
PARSE_EVIDENCE_ROOT="$SABLE_EVIDENCE_ROOT/titan2/n1d-c3a-trebledroid-parse"
BUILD_EVIDENCE_ROOT="$SABLE_EVIDENCE_ROOT/titan2/n1d-c3a-trebledroid-build"
LUNCH_TARGET="${N1D_C3_GENERATED_PRODUCT}-${N1D_C3_RELEASE_CONFIG}-${N1D_C3_FIRST_VARIANT}"

echo "===== N1D C3A RESTLESS/TREBLEDROID CONTROL SYSTEMIMAGE BUILD ====="
echo "BUILD_AUTHORIZED=YES_SYSTEMIMAGE_ONLY"
echo "TARGET_FILES_BUILD_AUTHORIZED=NO"
echo "OTA_BUILD_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=YES_TREBLE_APP_GRADLE_ONLY"
echo "RESUME_FAILED_BUILD_AUTHORIZED=$RESUME_FAILED_BUILD_AUTHORIZED"
echo "HOST_LAYOUT_SOURCE_MUTATION_AUTHORIZED=$HOST_LAYOUT_SOURCE_MUTATION_AUTHORIZED"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "PRODUCTION_SIGNING_AUTHORIZED=NO"
echo "RELEASE_ELIGIBLE=NO"
echo "N1D_C3_ACTIVE_PHASE=C3A_CONTROL"
echo "N1D_C3A_RELEASE_ELIGIBLE=$N1D_C3A_RELEASE_ELIGIBLE"
echo "N1D_C3B_BUILD_AUTHORIZED=$N1D_C3B_BUILD_AUTHORIZED"
echo "N1D_C3_RELEASE_ELIGIBLE=$N1D_C3_RELEASE_ELIGIBLE"
echo "LUNCH_TARGET=$LUNCH_TARGET"

bash "$STORAGE_VERIFY" runtime
[[ -x "$SABLE_JDK17/bin/java" ]] || fail "canonical_jdk17_java_missing=$SABLE_JDK17/bin/java"
[[ -x "$SABLE_JDK17/bin/jlink" ]] || fail "canonical_jdk17_jlink_missing=$SABLE_JDK17/bin/jlink"
[[ -d "$SABLE_GRADLE_USER_HOME" ]] || fail "canonical_gradle_user_home_missing=$SABLE_GRADLE_USER_HOME"
treble_jdk_spec="$("$SABLE_JDK17/bin/java" -XshowSettings:properties -version 2>&1 | awk -F'= ' '/^[[:space:]]*java\.specification\.version = / {print $2; exit}')"
[[ "$treble_jdk_spec" == "$N1D_C3_TREBLE_APP_JDK_MAJOR" ]] \
    || fail "canonical_jdk17_spec expected=$N1D_C3_TREBLE_APP_JDK_MAJOR actual=${treble_jdk_spec:-unset}"
echo "N1D_C3_TREBLE_APP_JDK=PASS source=$N1D_C3_TREBLE_APP_JDK_SOURCE major=$treble_jdk_spec home=$SABLE_JDK17"

check_host_layout_patch_state() {
    local target="$1"
    local patch="$2"
    local expected_base_blob="$3"
    local expected_post_blob="$4"
    local expected_patch_blob="$5"
    local label="$6"
    local base_blob
    local current_blob
    local patch_blob

    base_blob="$(git -C "$BUILD_SOONG_ROOT" rev-parse "HEAD:$target")"
    [[ "$base_blob" == "$expected_base_blob" ]] \
        || fail "${label}_base_blob expected=$expected_base_blob actual=$base_blob"

    patch_blob="$(git hash-object "$patch")"
    [[ "$patch_blob" == "$expected_patch_blob" ]] \
        || fail "${label}_patch_blob expected=$expected_patch_blob actual=$patch_blob"

    current_blob="$(git hash-object "$BUILD_SOONG_ROOT/$target")"
    if [[ "$current_blob" == "$expected_post_blob" ]]; then
        git -C "$BUILD_SOONG_ROOT" apply --reverse --check "$patch" \
            || fail "${label}_post_blob_reverse_check"
        echo "N1D_C3A_HOST_LAYOUT_PATCH_STATE=PASS_PRESENT label=$label file=$target"
        return 0
    fi
    if [[ "$current_blob" == "$expected_base_blob" ]]; then
        return 1
    fi

    fail "${label}_unexpected_blob expected_base=$expected_base_blob expected_post=$expected_post_blob actual=$current_blob"
}

apply_host_layout_fixes() {
    local status_file
    local status_count

    if ! check_host_layout_patch_state \
        "$N1D_C3A_HOST_LAYOUT_TARGET_FILE" \
        "$HOST_LAYOUT_PATCH" \
        "$N1D_C3A_HOST_LAYOUT_TARGET_BASE_BLOB" \
        "$N1D_C3A_HOST_LAYOUT_TARGET_POST_BLOB" \
        "$N1D_C3A_HOST_LAYOUT_PATCH_BLOB_SHA" \
        ci_tests_outdir
    then
        [[ "$HOST_LAYOUT_SOURCE_MUTATION_AUTHORIZED" == YES ]] \
            || fail host_layout_fix_requires_--authorize-host-layout-source-mutation
        [[ -z "$(git -C "$BUILD_SOONG_ROOT" status --porcelain --untracked-files=all)" ]] \
            || {
                git -C "$BUILD_SOONG_ROOT" status --short
                fail build_soong_dirty_before_primary_host_layout_fix
            }
        git -C "$BUILD_SOONG_ROOT" apply --check "$HOST_LAYOUT_PATCH" \
            || fail primary_host_layout_fix_apply_check
        git -C "$BUILD_SOONG_ROOT" apply "$HOST_LAYOUT_PATCH" \
            || fail primary_host_layout_fix_apply
        check_host_layout_patch_state \
            "$N1D_C3A_HOST_LAYOUT_TARGET_FILE" \
            "$HOST_LAYOUT_PATCH" \
            "$N1D_C3A_HOST_LAYOUT_TARGET_BASE_BLOB" \
            "$N1D_C3A_HOST_LAYOUT_TARGET_POST_BLOB" \
            "$N1D_C3A_HOST_LAYOUT_PATCH_BLOB_SHA" \
            ci_tests_outdir
        echo "N1D_C3A_HOST_LAYOUT_FIX_APPLY=PASS_APPLIED_EXACT patch=1"
    else
        echo "N1D_C3A_HOST_LAYOUT_FIX_APPLY=PASS_ALREADY_PRESENT patch=1"
    fi

    if ! check_host_layout_patch_state \
        "$N1D_C3A_DEXPREOPT_OUTDIR_TARGET_FILE" \
        "$DEXPREOPT_OUTDIR_PATCH" \
        "$N1D_C3A_DEXPREOPT_OUTDIR_TARGET_BASE_BLOB" \
        "$N1D_C3A_DEXPREOPT_OUTDIR_TARGET_POST_BLOB" \
        "$N1D_C3A_DEXPREOPT_OUTDIR_PATCH_BLOB_SHA" \
        dexpreopt_product_packages_outdir
    then
        [[ "$HOST_LAYOUT_SOURCE_MUTATION_AUTHORIZED" == YES ]] \
            || fail host_layout_fix_requires_--authorize-host-layout-source-mutation

        status_file="$(mktemp)"
        git -C "$BUILD_SOONG_ROOT" status --porcelain --untracked-files=all > "$status_file"
        status_count="$(grep -cve '^$' "$status_file" || true)"
        [[ "$status_count" == 1 ]] || {
            cat "$status_file"
            rm -f "$status_file"
            fail "build_soong_dirty_before_dexpreopt_fix expected=1 actual=$status_count"
        }
        grep -Fxq " M $N1D_C3A_HOST_LAYOUT_TARGET_FILE" "$status_file" || {
            cat "$status_file"
            rm -f "$status_file"
            fail build_soong_primary_fix_missing_before_dexpreopt_fix
        }
        rm -f "$status_file"

        git -C "$BUILD_SOONG_ROOT" apply --check "$DEXPREOPT_OUTDIR_PATCH" \
            || fail dexpreopt_outdir_fix_apply_check
        git -C "$BUILD_SOONG_ROOT" apply "$DEXPREOPT_OUTDIR_PATCH" \
            || fail dexpreopt_outdir_fix_apply
        check_host_layout_patch_state \
            "$N1D_C3A_DEXPREOPT_OUTDIR_TARGET_FILE" \
            "$DEXPREOPT_OUTDIR_PATCH" \
            "$N1D_C3A_DEXPREOPT_OUTDIR_TARGET_BASE_BLOB" \
            "$N1D_C3A_DEXPREOPT_OUTDIR_TARGET_POST_BLOB" \
            "$N1D_C3A_DEXPREOPT_OUTDIR_PATCH_BLOB_SHA" \
            dexpreopt_product_packages_outdir
        echo "N1D_C3A_HOST_LAYOUT_FIX_APPLY=PASS_APPLIED_EXACT patch=2"
    else
        echo "N1D_C3A_HOST_LAYOUT_FIX_APPLY=PASS_ALREADY_PRESENT patch=2"
    fi

    echo "N1D_C3A_HOST_LAYOUT_FIX_APPLY=PASS_COMPLETE patches=$N1D_C3A_HOST_LAYOUT_PATCH_COUNT"
}

BUILD_RESUME_MODE=FRESH
if [[ -e "$OUT_C3" ]]; then
    [[ "$RESUME_FAILED_BUILD_AUTHORIZED" == YES ]] \
        || fail "out_already_exists_requires_--resume-failed-c3-build path=$OUT_C3"

    mapfile -t prior_builds < <(
        find "$BUILD_EVIDENCE_ROOT" -mindepth 1 -maxdepth 1 -type d \
            -name '*-trebledroid-systemimage' -print 2>/dev/null | LC_ALL=C sort
    )
    (("${#prior_builds[@]}" > 0)) || fail failed_build_evidence_missing_for_resume
    PRIOR_BUILD_EVIDENCE="${prior_builds[-1]}"
    [[ -f "$PRIOR_BUILD_EVIDENCE/build.log" ]] || fail prior_build_log_missing
    grep -Fq 'N1D_C3_TREBLE_APP_BUILD=START' "$PRIOR_BUILD_EVIDENCE/build.log" \
        || fail prior_build_did_not_reach_treble_app

    treble_app_passed=NO
    [[ ! -f "$PRIOR_BUILD_EVIDENCE/treble-app.sha256" ]] \
        || treble_app_passed=YES

    if [[ "$treble_app_passed" == NO && ! -e "$PRIOR_BUILD_EVIDENCE/systemimage-command.log" ]]; then
        BUILD_RESUME_MODE=FAILED_TREBLE_APP_ONLY
    elif [[ "$treble_app_passed" == YES && -e "$PRIOR_BUILD_EVIDENCE/systemimage-command.log" ]]; then
        BUILD_RESUME_MODE=FAILED_SYSTEMIMAGE_PRE_ARTIFACT

        [[ -f "$PRIOR_BUILD_EVIDENCE/product-out.txt" ]] \
            || fail prior_systemimage_build_product_out_evidence_missing
        prior_product_out="$(cat "$PRIOR_BUILD_EVIDENCE/product-out.txt")"
        [[ -n "$prior_product_out" ]] \
            || fail prior_systemimage_build_product_out_evidence_empty
        case "$prior_product_out" in
            "$OUT_C3"/target/product/*) ;;
            *) fail "prior_product_out_outside_c3_out path=$prior_product_out" ;;
        esac

        if [[ -f "$prior_product_out/system.img" ]]; then
            fail "prior_final_system_img_exists_resume_not_allowed path=$prior_product_out/system.img"
        fi

        echo "N1D_C3A_RESUME_FINAL_SYSTEM_IMG=PASS_ABSENT path=$prior_product_out/system.img"
        intermediate_system_img_count="$(find "$OUT_C3" -type f -name 'system.img' ! -path "$prior_product_out/system.img" -print | wc -l | tr -d ' ')"
        echo "N1D_C3A_RESUME_INTERMEDIATE_SYSTEM_IMAGES=INFO count=$intermediate_system_img_count"
    else
        fail prior_build_resume_state_inconsistent
    fi

    if find "$OUT_C3" -type f \
        \( -name '*target_files*.zip' -o -name '*ota*.zip' \) \
        -print -quit | grep -q .
    then
        fail prior_output_contains_packaging_artifact_resume_not_allowed
    fi

    echo "N1D_C3A_BUILD_RESUME=PASS mode=$BUILD_RESUME_MODE prior_evidence=$PRIOR_BUILD_EVIDENCE"
elif [[ "$RESUME_FAILED_BUILD_AUTHORIZED" == YES ]]; then
    fail resume_requested_but_out_missing
else
    echo "N1D_C3A_BUILD_RESUME=PASS mode=$BUILD_RESUME_MODE"
fi

apply_host_layout_fixes

PREP_VERIFY_ARGS=(verify --allow-c3a-host-layout-fix)
if [[ -n "$(git -C "$ANDROID_ROOT/treble_app" status --porcelain --untracked-files=all)" ]]; then
    PREP_VERIFY_ARGS+=(--allow-treble-app-build-residue)
fi
bash "$PREP" "${PREP_VERIFY_ARGS[@]}"

mapfile -t parses < <(
    find "$PARSE_EVIDENCE_ROOT" -mindepth 1 -maxdepth 1 -type d         -name '*-trebledroid-parse' -print 2>/dev/null | LC_ALL=C sort
)
(("${#parses[@]}" > 0)) || fail parse_evidence_missing
PARSE_EVIDENCE="${parses[-1]}"
(
    cd "$PARSE_EVIDENCE"
    sha256sum -c SHA256SUMS.txt >/dev/null
) || fail parse_evidence_invalid
grep -Fxq 'N1D_C3A_TREBLEDROID_PARSE=PASS' "$PARSE_EVIDENCE/parse-state.env"     || fail parse_not_passed

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="$BUILD_EVIDENCE_ROOT/$stamp-trebledroid-systemimage"
mkdir -p "$EVIDENCE_DIR"
git -C "$BUILD_SOONG_ROOT" status --porcelain --untracked-files=all \
    > "$EVIDENCE_DIR/build-soong-host-layout-status.txt"
git -C "$BUILD_SOONG_ROOT" diff -- \
    "$N1D_C3A_HOST_LAYOUT_TARGET_FILE" \
    "$N1D_C3A_DEXPREOPT_OUTDIR_TARGET_FILE" \
    > "$EVIDENCE_DIR/build-soong-host-layout.diff"
if [[ -n "$(git -C "$ANDROID_ROOT/treble_app" status --porcelain --untracked-files=all)" ]]; then
    git -C "$ANDROID_ROOT/treble_app" status --porcelain --untracked-files=all \
        > "$EVIDENCE_DIR/treble-app-resume-status.txt"
fi
exec > >(tee "$EVIDENCE_DIR/build.log") 2>&1

(
    cd "$ANDROID_ROOT"
    export OUT_DIR="$OUT_C3"

    set +e +u
    # shellcheck source=/dev/null
    source build/envsetup.sh
    envsetup_rc=$?
    set -euo pipefail
    [[ "$envsetup_rc" -eq 0 ]] || fail "envsetup_rc=$envsetup_rc"

    set +e +u
    lunch "$LUNCH_TARGET"
    lunch_rc=$?
    set -euo pipefail
    [[ "$lunch_rc" -eq 0 ]] || fail "lunch_rc=$lunch_rc"

    echo "N1D_C3_TREBLE_APP_BUILD=START"
    (
        cd treble_app
        export JAVA_HOME="$SABLE_JDK17"
        export PATH="$SABLE_JDK17/bin:$PATH"
        export GRADLE_USER_HOME="$SABLE_GRADLE_USER_HOME"

        java_spec="$("$JAVA_HOME/bin/java" -XshowSettings:properties -version 2>&1 | awk -F'= ' '/^[[:space:]]*java\.specification\.version = / {print $2; exit}')"
        [[ "$java_spec" == "$N1D_C3_TREBLE_APP_JDK_MAJOR" ]] \
            || fail "treble_app_java_spec expected=$N1D_C3_TREBLE_APP_JDK_MAJOR actual=${java_spec:-unset}"
        [[ "$JAVA_HOME" == "$SABLE_JDK17" ]] || fail treble_app_java_home_not_canonical

        printf '%s\n' "$JAVA_HOME" > "$EVIDENCE_DIR/treble-app-java-home.txt"
        "$JAVA_HOME/bin/java" -version > "$EVIDENCE_DIR/treble-app-java-version.txt" 2>&1
        echo "N1D_C3_TREBLE_APP_JAVA=PASS major=$java_spec home=$JAVA_HOME"
        bash build.sh release
    )
    [[ -f treble_app/TrebleApp.apk ]] || fail treble_app_apk_missing
    treble_app_sha="$(sha256sum treble_app/TrebleApp.apk | awk '{print $1}')"
    treble_app_bytes="$(stat -c '%s' treble_app/TrebleApp.apk)"
    printf '%s\n' "$treble_app_sha" > "$EVIDENCE_DIR/treble-app.sha256"
    printf '%s\n' "$treble_app_bytes" > "$EVIDENCE_DIR/treble-app.bytes"
    echo "N1D_C3_TREBLE_APP_BUILD=PASS sha256=$treble_app_sha bytes=$treble_app_bytes"

    set +e +u
    product_out="$(get_build_var PRODUCT_OUT)"
    product_out_rc=$?
    set -euo pipefail
    [[ "$product_out_rc" -eq 0 ]] || fail "product_out_rc=$product_out_rc"
    printf '%s\n' "$product_out" > "$EVIDENCE_DIR/product-out.txt"

    echo "N1D_C3A_TREBLEDROID_BUILD_RECIPE=TREBLE_APP_RELEASE_THEN_SYSTEMIMAGE"
    echo "N1D_C3A_TREBLEDROID_BUILD_GOAL=systemimage"
    set +e +u
    make systemimage -j"$JOBS" 2>&1 | tee "$EVIDENCE_DIR/systemimage-command.log"
    build_rc="${PIPESTATUS[0]}"
    set -euo pipefail
    [[ "$build_rc" -eq 0 ]] || fail "systemimage_build_rc=$build_rc"
)

PRODUCT_OUT="$(cat "$EVIDENCE_DIR/product-out.txt")"
SYSTEM_IMG="$PRODUCT_OUT/system.img"
[[ -f "$SYSTEM_IMG" ]] || fail "system_img_missing=$SYSTEM_IMG"

if find "$OUT_C3" -type f     \( -name '*target_files*.zip' -o -name '*ota*.zip' \)     -print -quit | grep -q .
then
    fail unauthorized_packaging_artifact
fi

sha="$(sha256sum "$SYSTEM_IMG" | awk '{print $1}')"
bytes="$(stat -c '%s' "$SYSTEM_IMG")"

{
    echo "N1D_C3A_TREBLEDROID_BUILD=PASS"
    echo "N1D_C3_PRODUCT=$N1D_C3_GENERATED_PRODUCT"
    echo "N1D_C3_RELEASE_CONFIG=$N1D_C3_RELEASE_CONFIG"
    echo "N1D_C3_VARIANT=$N1D_C3_FIRST_VARIANT"
    echo "N1D_C3_SYSTEM_IMG=$SYSTEM_IMG"
    echo "N1D_C3_SYSTEM_SHA256=$sha"
    echo "N1D_C3_SYSTEM_BYTES=$bytes"
    echo "N1D_C3_TREBLE_APP_SHA256=$(cat "$EVIDENCE_DIR/treble-app.sha256")"
    echo "N1D_C3_TREBLE_APP_BYTES=$(cat "$EVIDENCE_DIR/treble-app.bytes")"
    echo "N1D_C3_TREBLE_APP_JDK_MAJOR=$N1D_C3_TREBLE_APP_JDK_MAJOR"
    echo "N1D_C3_TREBLE_APP_JAVA_HOME=$(cat "$EVIDENCE_DIR/treble-app-java-home.txt")"
    echo "N1D_C3A_BUILD_RESUME_MODE=$BUILD_RESUME_MODE"
    echo "N1D_C3A_HOST_LAYOUT_PATCH_BLOB_SHA=$N1D_C3A_HOST_LAYOUT_PATCH_BLOB_SHA"
    echo "N1D_C3A_DEXPREOPT_OUTDIR_PATCH_BLOB_SHA=$N1D_C3A_DEXPREOPT_OUTDIR_PATCH_BLOB_SHA"
    echo "N1D_C3A_RELEASE_ELIGIBLE=$N1D_C3A_RELEASE_ELIGIBLE"
    echo "N1D_C3B_BUILD_AUTHORIZED=$N1D_C3B_BUILD_AUTHORIZED"
    echo "N1D_C3_RELEASE_ELIGIBLE=$N1D_C3_RELEASE_ELIGIBLE"
    echo "DEVICE_CONTACT_AUTHORIZED=NO"
    echo "FLASH_AUTHORIZED=NO"
} > "$EVIDENCE_DIR/build-state.env"

(
    cd "$EVIDENCE_DIR"
    find . -type f ! -name SHA256SUMS.txt ! -name build.log ! -name systemimage-command.log -print0         | LC_ALL=C sort -z         | xargs -0 sha256sum > SHA256SUMS.txt
    sha256sum -c SHA256SUMS.txt >/dev/null
)

echo "SYSTEM_IMG=$SYSTEM_IMG"
echo "SYSTEM_SHA256=$sha"
echo "SYSTEM_BYTES=$bytes"
echo "N1D_C3A_TREBLEDROID_SYSTEMIMAGE=PASS"
echo "N1D_C3_RELEASE_ELIGIBLE=$N1D_C3_RELEASE_ELIGIBLE"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
