#!/usr/bin/env bash
# Build the first Titan 2 N1D C3B engineering system image.
#
# Scope: pinned Graphene base + minimal Treble scaffold + exact C3B PHH base
# hardening + two proven out-of-tree Soong host-layout fixes.
#
# No Restless runtime patches, network fetch, target-files, OTA, signing,
# device contact, physical runtime, or flash are authorized here.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STORAGE_PROFILE="$ROOT/build/config/storage.env"
TRANSITION="$ROOT/build/titan2/n1d-c3b-transition.env"
PREP="$ROOT/build/titan2/prepare-n1d-c3b-engineering.sh"
STORAGE_VERIFY="$ROOT/build/host/verify-storage-root.sh"
HOST_PATCH_1="$ROOT/patches/android-16-n1d-trebledroid/host-layout/0001-soong-ci-tests-skip-out-of-tree-host-paths.patch"
HOST_PATCH_2="$ROOT/patches/android-16-n1d-trebledroid/host-layout/0002-soong-dexpreopt-gen-support-out-of-tree-product-packages.patch"

fail() {
    echo "N1D_C3B_SYSTEMIMAGE_BUILD=FAIL $*" >&2
    exit 1
}

for f in     "$STORAGE_PROFILE"     "$TRANSITION"     "$PREP"     "$STORAGE_VERIFY"     "$HOST_PATCH_1"     "$HOST_PATCH_2"
do
    [[ -f "$f" ]] || fail "missing_file=$f"
done

# shellcheck source=/dev/null
source "$STORAGE_PROFILE"
# shellcheck source=/dev/null
source "$TRANSITION"

BUILD_AUTHORIZED=NO
HOST_LAYOUT_MUTATION_AUTHORIZED=NO
JOBS="$(nproc --all)"
while (($#)); do
    case "$1" in
        --authorize-c3b-compile)
            BUILD_AUTHORIZED=YES
            shift
            ;;
        --authorize-host-layout-source-mutation)
            HOST_LAYOUT_MUTATION_AUTHORIZED=YES
            shift
            ;;
        --jobs)
            [[ $# -ge 2 ]] || fail jobs_value_missing
            JOBS="$2"
            shift 2
            ;;
        *)
            fail "unknown_arg=$1"
            ;;
    esac
done

[[ "$BUILD_AUTHORIZED" == YES ]] ||
    fail compile_requires_--authorize-c3b-compile
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || fail "invalid_jobs=$JOBS"
[[ "$N1D_C3_CURRENT_ACTIVE_PHASE" == C3B_ENGINEERING ]] ||
    fail active_phase_mismatch
[[ "$N1D_C3B_ENGINEERING_BUILD_AUTHORIZED" == YES_SYSTEMIMAGE_ONLY_AFTER_STAGE_AND_PARSE ]] ||
    fail engineering_build_boundary_mismatch
[[ "$N1D_C3B_RUNTIME_PATCH_ALLOWLIST_COUNT" == 0 ]] ||
    fail runtime_allowlist_not_zero
[[ "$N1D_C3B_RESTLESS_PATCH_COUNT" == 0 ]] ||
    fail restless_patch_count_not_zero

ANDROID_ROOT="$SABLE_BUILD_ROOT/$N1D_C3B_ANDROID_ROOT_REL"
OUT_ROOT="$SABLE_BUILD_ROOT/$N1D_C3B_OUT_ROOT_REL"
PARSE_EVIDENCE_ROOT="$SABLE_EVIDENCE_ROOT/titan2/n1d-c3b-product-parse"
BUILD_EVIDENCE_ROOT="$SABLE_EVIDENCE_ROOT/titan2/n1d-c3b-systemimage"
SOONG_ROOT="$ANDROID_ROOT/build/soong"
LUNCH_TARGET="$N1D_C3B_GENERATED_PRODUCT-$N1D_C3B_RELEASE_CONFIG-$N1D_C3B_ENGINEERING_VARIANT"

echo "===== N1D C3B ENGINEERING SYSTEMIMAGE BUILD ====="
echo "BUILD_AUTHORIZED=YES_SYSTEMIMAGE_ONLY"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "HOST_LAYOUT_SOURCE_MUTATION_AUTHORIZED=$HOST_LAYOUT_MUTATION_AUTHORIZED"
echo "TARGET_FILES_BUILD_AUTHORIZED=NO"
echo "OTA_BUILD_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "SIGNING_AUTHORIZED=NO"
echo "PRODUCTION_SIGNING_AUTHORIZED=NO"
echo "PHYSICAL_RUNTIME_AUTHORIZED=NO"
echo "RELEASE_ELIGIBLE=NO"
echo "N1D_C3_ACTIVE_PHASE=$N1D_C3_CURRENT_ACTIVE_PHASE"
echo "N1D_C3B_RUNTIME_PATCH_ALLOWLIST_COUNT=$N1D_C3B_RUNTIME_PATCH_ALLOWLIST_COUNT"
echo "LUNCH_TARGET=$LUNCH_TARGET"

bash "$STORAGE_VERIFY" runtime

# Require a fully staged C3B source graph before any build/Soong source mutation.
bash "$PREP" verify

mapfile -t parses < <(
    find "$PARSE_EVIDENCE_ROOT" -mindepth 1 -maxdepth 1 -type d         -name '*-c3b-parse' -print 2>/dev/null | LC_ALL=C sort
)
(("${#parses[@]}" > 0)) || fail c3b_parse_evidence_missing
PARSE_EVIDENCE="${parses[-1]}"

(
    cd "$PARSE_EVIDENCE"
    sha256sum -c SHA256SUMS.txt >/dev/null
) || fail c3b_parse_evidence_invalid
grep -Fxq 'N1D_C3B_PRODUCT_PARSE=PASS' "$PARSE_EVIDENCE/parse-state.env" ||
    fail c3b_parse_not_passed
grep -Fxq "N1D_C3B_VARIANT=$N1D_C3B_ENGINEERING_VARIANT" "$PARSE_EVIDENCE/parse-state.env" ||
    fail c3b_parse_variant_mismatch
grep -Fxq 'N1D_C3B_RUNTIME_PATCH_ALLOWLIST_COUNT=0' "$PARSE_EVIDENCE/parse-state.env" ||
    fail c3b_parse_runtime_allowlist_not_zero

check_patch_state() {
    local target="$1"
    local patch="$2"
    local expected_base="$3"
    local expected_post="$4"
    local expected_patch="$5"
    local label="$6"
    local base_blob current_blob patch_blob

    base_blob="$(git -C "$SOONG_ROOT" rev-parse "HEAD:$target")"
    [[ "$base_blob" == "$expected_base" ]] ||
        fail "${label}_base_blob expected=$expected_base actual=$base_blob"

    patch_blob="$(git hash-object "$patch")"
    [[ "$patch_blob" == "$expected_patch" ]] ||
        fail "${label}_patch_blob expected=$expected_patch actual=$patch_blob"

    current_blob="$(git hash-object "$SOONG_ROOT/$target")"
    if [[ "$current_blob" == "$expected_post" ]]; then
        git -C "$SOONG_ROOT" apply --reverse --check "$patch" ||
            fail "${label}_reverse_check"
        return 0
    fi
    if [[ "$current_blob" == "$expected_base" ]]; then
        return 1
    fi

    fail "${label}_unexpected_blob expected_base=$expected_base expected_post=$expected_post actual=$current_blob"
}

validate_soong_dirty_subset() {
    local status_file line count
    local file1="ci_tests/ci_test_package_zip.go"
    local file2="dexpreopt/dexpreopt_gen/dexpreopt_gen.go"

    status_file="$(mktemp)"
    git -C "$SOONG_ROOT" status --porcelain --untracked-files=all > "$status_file"
    count="$(grep -cve '^$' "$status_file" || true)"
    [[ "$count" -le 2 ]] || {
        cat "$status_file"
        rm -f "$status_file"
        fail "build_soong_dirty_count=$count"
    }

    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        case "$line" in
            " M $file1"|" M $file2") ;;
            *)
                cat "$status_file"
                rm -f "$status_file"
                fail "unexpected_build_soong_dirty_entry=$line"
                ;;
        esac
    done < "$status_file"

    rm -f "$status_file"

    # Each target must be either its exact pinned base or exact approved post blob.
    check_patch_state         "$file1"         "$HOST_PATCH_1"         "$N1D_C3B_HOST_LAYOUT_PATCH_1_BASE_BLOB"         "$N1D_C3B_HOST_LAYOUT_PATCH_1_POST_BLOB"         "$N1D_C3B_HOST_LAYOUT_PATCH_1_BLOB_SHA"         host_layout_1 || true
    check_patch_state         "$file2"         "$HOST_PATCH_2"         "$N1D_C3B_HOST_LAYOUT_PATCH_2_BASE_BLOB"         "$N1D_C3B_HOST_LAYOUT_PATCH_2_POST_BLOB"         "$N1D_C3B_HOST_LAYOUT_PATCH_2_BLOB_SHA"         host_layout_2 || true

    echo "N1D_C3B_HOST_LAYOUT_DIRTY_SUBSET=PASS count=$count"
}

apply_one_patch() {
    local target="$1"
    local patch="$2"
    local expected_base="$3"
    local expected_post="$4"
    local expected_patch="$5"
    local label="$6"

    if check_patch_state         "$target" "$patch" "$expected_base" "$expected_post" "$expected_patch" "$label"
    then
        echo "N1D_C3B_HOST_LAYOUT_PATCH=PASS_ALREADY_PRESENT label=$label"
        return
    fi

    [[ "$HOST_LAYOUT_MUTATION_AUTHORIZED" == YES ]] ||
        fail host_layout_patch_requires_--authorize-host-layout-source-mutation

    git -C "$SOONG_ROOT" apply --check "$patch" ||
        fail "${label}_apply_check"
    git -C "$SOONG_ROOT" apply "$patch" ||
        fail "${label}_apply"

    check_patch_state         "$target" "$patch" "$expected_base" "$expected_post" "$expected_patch" "$label"

    echo "N1D_C3B_HOST_LAYOUT_PATCH=PASS_APPLIED label=$label"
}

validate_soong_dirty_subset

apply_one_patch     ci_tests/ci_test_package_zip.go     "$HOST_PATCH_1"     "$N1D_C3B_HOST_LAYOUT_PATCH_1_BASE_BLOB"     "$N1D_C3B_HOST_LAYOUT_PATCH_1_POST_BLOB"     "$N1D_C3B_HOST_LAYOUT_PATCH_1_BLOB_SHA"     host_layout_1

apply_one_patch     dexpreopt/dexpreopt_gen/dexpreopt_gen.go     "$HOST_PATCH_2"     "$N1D_C3B_HOST_LAYOUT_PATCH_2_BASE_BLOB"     "$N1D_C3B_HOST_LAYOUT_PATCH_2_POST_BLOB"     "$N1D_C3B_HOST_LAYOUT_PATCH_2_BLOB_SHA"     host_layout_2

validate_soong_dirty_subset
bash "$PREP" verify

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR_C3B="$OUT_ROOT/build-$stamp"
EVIDENCE_DIR="$BUILD_EVIDENCE_ROOT/$stamp-c3b-systemimage"

[[ ! -e "$OUT_DIR_C3B" ]] || fail "fresh_out_required=$OUT_DIR_C3B"
mkdir -p "$OUT_DIR_C3B" "$EVIDENCE_DIR"

git -C "$SOONG_ROOT" status --porcelain --untracked-files=all     > "$EVIDENCE_DIR/build-soong-host-layout-status.txt"
git -C "$SOONG_ROOT" diff --     ci_tests/ci_test_package_zip.go     dexpreopt/dexpreopt_gen/dexpreopt_gen.go     > "$EVIDENCE_DIR/build-soong-host-layout.diff"

exec > >(tee "$EVIDENCE_DIR/build.log") 2>&1

(
    cd "$ANDROID_ROOT"
    export OUT_DIR="$OUT_DIR_C3B"

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

    set +e +u
    product_out="$(get_build_var PRODUCT_OUT)"
    product_out_rc=$?
    set -euo pipefail
    [[ "$product_out_rc" -eq 0 ]] || fail "product_out_rc=$product_out_rc"
    printf '%s\n' "$product_out" > "$EVIDENCE_DIR/product-out.txt"

    echo "N1D_C3B_BUILD_GOAL=systemimage"

    set +e +u
    make systemimage -j"$JOBS" 2>&1 | tee "$EVIDENCE_DIR/systemimage-command.log"
    build_rc="${PIPESTATUS[0]}"
    set -euo pipefail
    [[ "$build_rc" -eq 0 ]] || fail "systemimage_build_rc=$build_rc"
)

PRODUCT_OUT="$(cat "$EVIDENCE_DIR/product-out.txt")"
SYSTEM_IMG="$PRODUCT_OUT/system.img"
[[ -f "$SYSTEM_IMG" ]] || fail "system_img_missing=$SYSTEM_IMG"

if find "$OUT_DIR_C3B" -type f -name '*target_files*.zip' -print -quit | grep -q .; then
    fail unauthorized_target_files_artifact
fi
if find "$OUT_DIR_C3B" -type f -name '*-ota-*.zip' -print -quit | grep -q .; then
    fail unauthorized_ota_artifact
fi
if find "$OUT_DIR_C3B" -type f -name '*-ota.zip' -print -quit | grep -q .; then
    fail unauthorized_ota_artifact
fi

sha="$(sha256sum "$SYSTEM_IMG" | awk '{print $1}')"
bytes="$(stat -c '%s' "$SYSTEM_IMG")"

{
    echo "N1D_C3B_SYSTEMIMAGE=PASS"
    echo "N1D_C3B_PRODUCT=$N1D_C3B_GENERATED_PRODUCT"
    echo "N1D_C3B_RELEASE_CONFIG=$N1D_C3B_RELEASE_CONFIG"
    echo "N1D_C3B_VARIANT=$N1D_C3B_ENGINEERING_VARIANT"
    echo "N1D_C3B_SYSTEM_IMG=$SYSTEM_IMG"
    echo "N1D_C3B_SYSTEM_SHA256=$sha"
    echo "N1D_C3B_SYSTEM_BYTES=$bytes"
    echo "N1D_C3B_RUNTIME_PATCH_ALLOWLIST_COUNT=$N1D_C3B_RUNTIME_PATCH_ALLOWLIST_COUNT"
    echo "N1D_C3B_RESTLESS_PATCH_COUNT=$N1D_C3B_RESTLESS_PATCH_COUNT"
    echo "N1D_C3B_PHH_BASE_SECURITY_TRANSFORM_COUNT=$N1D_C3B_PHH_BASE_SECURITY_TRANSFORM_COUNT"
    echo "N1D_C3B_HOST_LAYOUT_PATCH_COUNT=$N1D_C3B_HOST_LAYOUT_PATCH_COUNT"
    echo "N1D_C3B_DEVICE_CONTACT_AUTHORIZED=NO"
    echo "N1D_C3B_FLASH_AUTHORIZED=NO"
    echo "N1D_C3B_SIGNING_AUTHORIZED=NO"
    echo "N1D_C3B_PHYSICAL_RUNTIME_AUTHORIZED=NO"
    echo "N1D_C3B_RELEASE_ELIGIBLE=NO"
} > "$EVIDENCE_DIR/build-state.env"

(
    cd "$EVIDENCE_DIR"
    find . -type f         ! -name SHA256SUMS.txt         ! -name build.log         ! -name systemimage-command.log         -print0 |
        LC_ALL=C sort -z |
        xargs -0 sha256sum > SHA256SUMS.txt
    sha256sum -c SHA256SUMS.txt >/dev/null
)

echo "N1D_C3B_POSTBUILD_PACKAGING_ARTIFACTS=PASS_ABSENT"
echo "SYSTEM_IMG=$SYSTEM_IMG"
echo "SYSTEM_SHA256=$sha"
echo "SYSTEM_BYTES=$bytes"
echo "N1D_C3B_SYSTEMIMAGE=PASS"
echo "N1D_C3B_PHYSICAL_RUNTIME_AUTHORIZED=NO"
echo "N1D_C3B_RELEASE_ELIGIBLE=NO"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
