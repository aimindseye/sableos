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
SCAFFOLD_COMPAT_PATCH="$ROOT/patches/android-16-n1d-trebledroid/scaffold-compat/0001-vendor-interfaces-quarantine-lge-vibrator.patch"
PHH_LGE_COMPAT_PATCH="$ROOT/patches/android-16-n1d-trebledroid/scaffold-compat/0002-device-phh-quarantine-vibrator-lge-helper.patch"
BUILD_MAKE_COMPAT_PATCH_1="$ROOT/patches/android-16-n1d-trebledroid/c3b-compat/0001-build-make-graphene-treble-graph.patch"
BUILD_MAKE_COMPAT_PATCH_2="$ROOT/patches/android-16-n1d-trebledroid/c3b-compat/0002-build-make-preserve-adb-auth.patch"

fail() {
    echo "N1D_C3B_SYSTEMIMAGE_BUILD=FAIL $*" >&2
    exit 1
}

for f in     "$STORAGE_PROFILE"     "$TRANSITION"     "$PREP"     "$STORAGE_VERIFY"     "$HOST_PATCH_1"     "$HOST_PATCH_2"     "$SCAFFOLD_COMPAT_PATCH"     "$PHH_LGE_COMPAT_PATCH"     "$BUILD_MAKE_COMPAT_PATCH_1"     "$BUILD_MAKE_COMPAT_PATCH_2"
do
    [[ -f "$f" ]] || fail "missing_file=$f"
done

# shellcheck source=/dev/null
source "$STORAGE_PROFILE"
# shellcheck source=/dev/null
source "$TRANSITION"

BUILD_AUTHORIZED=NO
HOST_LAYOUT_MUTATION_AUTHORIZED=NO
SCAFFOLD_COMPAT_MUTATION_AUTHORIZED=NO
BUILD_COMPAT_MUTATION_AUTHORIZED=NO
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
        --authorize-scaffold-compat-source-mutation)
            SCAFFOLD_COMPAT_MUTATION_AUTHORIZED=YES
            shift
            ;;
        --authorize-build-compat-source-mutation)
            BUILD_COMPAT_MUTATION_AUTHORIZED=YES
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
PHH_ROOT="$ANDROID_ROOT/device/phh/treble"
VENDOR_INTERFACES_ROOT="$ANDROID_ROOT/vendor/interfaces"
BUILD_MAKE_ROOT="$ANDROID_ROOT/build/make"
LUNCH_TARGET="$N1D_C3B_GENERATED_PRODUCT-$N1D_C3B_RELEASE_CONFIG-$N1D_C3B_ENGINEERING_VARIANT"

echo "===== N1D C3B ENGINEERING SYSTEMIMAGE BUILD ====="
echo "BUILD_AUTHORIZED=YES_SYSTEMIMAGE_ONLY"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "HOST_LAYOUT_SOURCE_MUTATION_AUTHORIZED=$HOST_LAYOUT_MUTATION_AUTHORIZED"
echo "SCAFFOLD_COMPAT_SOURCE_MUTATION_AUTHORIZED=$SCAFFOLD_COMPAT_MUTATION_AUTHORIZED"
echo "BUILD_COMPAT_SOURCE_MUTATION_AUTHORIZED=$BUILD_COMPAT_MUTATION_AUTHORIZED"
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

check_vendor_interfaces_quarantine_state() {
    local target="$N1D_C3B_VENDOR_INTERFACES_LGE_VIBRATOR_TARGET"
    local base_blob patch_blob status

    base_blob="$(git -C "$VENDOR_INTERFACES_ROOT" rev-parse "HEAD:$target")"
    [[ "$base_blob" == "$N1D_C3B_VENDOR_INTERFACES_LGE_VIBRATOR_BASE_BLOB" ]] ||
        fail "vendor_interfaces_lge_vibrator_base_blob expected=$N1D_C3B_VENDOR_INTERFACES_LGE_VIBRATOR_BASE_BLOB actual=$base_blob"

    patch_blob="$(git hash-object "$SCAFFOLD_COMPAT_PATCH")"
    [[ "$patch_blob" == "$N1D_C3B_VENDOR_INTERFACES_LGE_VIBRATOR_QUARANTINE_PATCH_BLOB_SHA" ]] ||
        fail "vendor_interfaces_lge_vibrator_patch_blob expected=$N1D_C3B_VENDOR_INTERFACES_LGE_VIBRATOR_QUARANTINE_PATCH_BLOB_SHA actual=$patch_blob"

    status="$(git -C "$VENDOR_INTERFACES_ROOT" status --porcelain --untracked-files=all)"
    if [[ -z "$status" ]]; then
        [[ -f "$VENDOR_INTERFACES_ROOT/$target" ]] ||
            fail vendor_interfaces_lge_vibrator_target_missing_clean
        return 1
    fi

    [[ "$status" == " D $target" ]] || {
        printf '%s\n' "$status"
        fail vendor_interfaces_unexpected_dirty_state
    }
    [[ ! -e "$VENDOR_INTERFACES_ROOT/$target" ]] ||
        fail vendor_interfaces_lge_vibrator_target_still_present
    git -C "$VENDOR_INTERFACES_ROOT" apply --reverse --check "$SCAFFOLD_COMPAT_PATCH" ||
        fail vendor_interfaces_lge_vibrator_reverse_check
    return 0
}

apply_vendor_interfaces_quarantine() {
    if check_vendor_interfaces_quarantine_state; then
        echo "N1D_C3B_VENDOR_INTERFACES_LGE_VIBRATOR=PASS_ALREADY_QUARANTINED"
        return
    fi

    [[ "$SCAFFOLD_COMPAT_MUTATION_AUTHORIZED" == YES ]] ||
        fail scaffold_compat_patch_requires_--authorize-scaffold-compat-source-mutation

    git -C "$VENDOR_INTERFACES_ROOT" apply --check "$SCAFFOLD_COMPAT_PATCH" ||
        fail vendor_interfaces_lge_vibrator_apply_check
    git -C "$VENDOR_INTERFACES_ROOT" apply "$SCAFFOLD_COMPAT_PATCH" ||
        fail vendor_interfaces_lge_vibrator_apply

    check_vendor_interfaces_quarantine_state ||
        fail vendor_interfaces_lge_vibrator_post_apply_state

    echo "N1D_C3B_VENDOR_INTERFACES_LGE_VIBRATOR=PASS_APPLIED"
}

check_device_phh_lge_quarantine_state() {
    local target="$N1D_C3B_DEVICE_PHH_LGE_VIBRATOR_TARGET"
    local base_blob patch_blob status numstat expected_numstat

    base_blob="$(git -C "$PHH_ROOT" rev-parse "HEAD:$target")"
    [[ "$base_blob" == "$N1D_C3B_DEVICE_PHH_LGE_VIBRATOR_BASE_BLOB" ]] ||
        fail "device_phh_lge_vibrator_base_blob expected=$N1D_C3B_DEVICE_PHH_LGE_VIBRATOR_BASE_BLOB actual=$base_blob"

    patch_blob="$(git hash-object "$PHH_LGE_COMPAT_PATCH")"
    [[ "$patch_blob" == "$N1D_C3B_DEVICE_PHH_LGE_VIBRATOR_QUARANTINE_PATCH_BLOB_SHA" ]] ||
        fail "device_phh_lge_vibrator_patch_blob expected=$N1D_C3B_DEVICE_PHH_LGE_VIBRATOR_QUARANTINE_PATCH_BLOB_SHA actual=$patch_blob"

    status="$(git -C "$PHH_ROOT" status --porcelain --untracked-files=all -- "$target")"
    if [[ -z "$status" ]]; then
        grep -Fq 'name: "vibrator-lge"' "$PHH_ROOT/$target" ||
            fail device_phh_lge_vibrator_clean_module_missing
        return 1
    fi

    [[ "$status" == " M $target" ]] || {
        printf '%s\n' "$status"
        fail device_phh_lge_vibrator_unexpected_dirty_state
    }
    git -C "$PHH_ROOT" apply --reverse --check "$PHH_LGE_COMPAT_PATCH" ||
        fail device_phh_lge_vibrator_reverse_check
    numstat="$(git -C "$PHH_ROOT" diff --numstat -- "$target")"
    printf -v expected_numstat '0\t12\t%s' "$target"
    [[ "$numstat" == "$expected_numstat" ]] ||
        fail "device_phh_lge_vibrator_numstat=$numstat"
    if grep -Fq 'name: "vibrator-lge"' "$PHH_ROOT/$target"; then
        fail device_phh_lge_vibrator_module_still_present
    fi
    if grep -Fq 'vendor.lge.hardware.vibrator@1.0' "$PHH_ROOT/$target"; then
        fail device_phh_lge_vibrator_dependency_still_present
    fi
    return 0
}

apply_device_phh_lge_quarantine() {
    if check_device_phh_lge_quarantine_state; then
        echo "N1D_C3B_DEVICE_PHH_LGE_VIBRATOR=PASS_ALREADY_QUARANTINED"
        return
    fi

    [[ "$SCAFFOLD_COMPAT_MUTATION_AUTHORIZED" == YES ]] ||
        fail scaffold_compat_patch_requires_--authorize-scaffold-compat-source-mutation

    git -C "$PHH_ROOT" apply --check "$PHH_LGE_COMPAT_PATCH" ||
        fail device_phh_lge_vibrator_apply_check
    git -C "$PHH_ROOT" apply "$PHH_LGE_COMPAT_PATCH" ||
        fail device_phh_lge_vibrator_apply

    check_device_phh_lge_quarantine_state ||
        fail device_phh_lge_vibrator_post_apply_state

    echo "N1D_C3B_DEVICE_PHH_LGE_VIBRATOR=PASS_APPLIED"
}

check_build_make_compat_state() {
    local generic_target="$N1D_C3B_BUILD_MAKE_COMPAT_PATCH_1_GENERIC_TARGET"
    local gsi_target="$N1D_C3B_BUILD_MAKE_COMPAT_PATCH_1_GSI_TARGET"
    local adb_target="$N1D_C3B_BUILD_MAKE_COMPAT_PATCH_2_TARGET"
    local generic_head gsi_head adb_head generic_blob gsi_blob adb_blob
    local patch1_blob patch2_blob

    generic_head="$(git -C "$BUILD_MAKE_ROOT" rev-parse "HEAD:$generic_target")"
    gsi_head="$(git -C "$BUILD_MAKE_ROOT" rev-parse "HEAD:$gsi_target")"
    adb_head="$(git -C "$BUILD_MAKE_ROOT" rev-parse "HEAD:$adb_target")"

    [[ "$generic_head" == "$N1D_C3B_BUILD_MAKE_COMPAT_PATCH_1_GENERIC_BASE_BLOB" ]] ||
        fail "build_make_generic_head_blob expected=$N1D_C3B_BUILD_MAKE_COMPAT_PATCH_1_GENERIC_BASE_BLOB actual=$generic_head"
    [[ "$gsi_head" == "$N1D_C3B_BUILD_MAKE_COMPAT_PATCH_1_GSI_BASE_BLOB" ]] ||
        fail "build_make_gsi_head_blob expected=$N1D_C3B_BUILD_MAKE_COMPAT_PATCH_1_GSI_BASE_BLOB actual=$gsi_head"
    [[ "$adb_head" == "$N1D_C3B_BUILD_MAKE_COMPAT_PATCH_2_BASE_BLOB" ]] ||
        fail "build_make_adb_head_blob expected=$N1D_C3B_BUILD_MAKE_COMPAT_PATCH_2_BASE_BLOB actual=$adb_head"

    patch1_blob="$(git hash-object "$BUILD_MAKE_COMPAT_PATCH_1")"
    patch2_blob="$(git hash-object "$BUILD_MAKE_COMPAT_PATCH_2")"
    [[ "$patch1_blob" == "$N1D_C3B_BUILD_MAKE_COMPAT_PATCH_1_BLOB_SHA" ]] ||
        fail "build_make_compat_patch_1_blob expected=$N1D_C3B_BUILD_MAKE_COMPAT_PATCH_1_BLOB_SHA actual=$patch1_blob"
    [[ "$patch2_blob" == "$N1D_C3B_BUILD_MAKE_COMPAT_PATCH_2_BLOB_SHA" ]] ||
        fail "build_make_compat_patch_2_blob expected=$N1D_C3B_BUILD_MAKE_COMPAT_PATCH_2_BLOB_SHA actual=$patch2_blob"

    generic_blob="$(git hash-object "$BUILD_MAKE_ROOT/$generic_target")"
    gsi_blob="$(git hash-object "$BUILD_MAKE_ROOT/$gsi_target")"
    adb_blob="$(git hash-object "$BUILD_MAKE_ROOT/$adb_target")"

    if [[ "$generic_blob" == "$N1D_C3B_BUILD_MAKE_COMPAT_PATCH_1_GENERIC_POST_BLOB" &&
          "$gsi_blob" == "$N1D_C3B_BUILD_MAKE_COMPAT_PATCH_1_GSI_POST_BLOB" &&
          "$adb_blob" == "$N1D_C3B_BUILD_MAKE_COMPAT_PATCH_2_POST_BLOB" ]]; then
        git -C "$BUILD_MAKE_ROOT" apply --reverse --check             "$BUILD_MAKE_COMPAT_PATCH_2" "$BUILD_MAKE_COMPAT_PATCH_1" ||
            fail build_make_compat_reverse_check
        return 0
    fi

    if [[ "$generic_blob" == "$N1D_C3B_BUILD_MAKE_COMPAT_PATCH_1_GENERIC_BASE_BLOB" &&
          "$gsi_blob" == "$N1D_C3B_BUILD_MAKE_COMPAT_PATCH_1_GSI_BASE_BLOB" &&
          "$adb_blob" == "$N1D_C3B_BUILD_MAKE_COMPAT_PATCH_2_BASE_BLOB" ]]; then
        return 1
    fi

    fail "build_make_compat_partial_state generic=$generic_blob gsi=$gsi_blob adb=$adb_blob"
}

apply_build_make_compat() {
    if check_build_make_compat_state; then
        echo "N1D_C3B_BUILD_MAKE_COMPAT=PASS_ALREADY_PRESENT count=2"
        return
    fi

    [[ "$BUILD_COMPAT_MUTATION_AUTHORIZED" == YES ]] ||
        fail build_compat_patch_requires_--authorize-build-compat-source-mutation

    git -C "$BUILD_MAKE_ROOT" apply --check         "$BUILD_MAKE_COMPAT_PATCH_1" "$BUILD_MAKE_COMPAT_PATCH_2" ||
        fail build_make_compat_apply_check
    git -C "$BUILD_MAKE_ROOT" apply         "$BUILD_MAKE_COMPAT_PATCH_1" "$BUILD_MAKE_COMPAT_PATCH_2" ||
        fail build_make_compat_apply

    check_build_make_compat_state ||
        fail build_make_compat_post_apply_state

    echo "N1D_C3B_BUILD_MAKE_COMPAT=PASS_APPLIED count=2"
}

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

apply_vendor_interfaces_quarantine
apply_device_phh_lge_quarantine

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
git -C "$VENDOR_INTERFACES_ROOT" status --porcelain --untracked-files=all     > "$EVIDENCE_DIR/vendor-interfaces-lge-vibrator-status.txt"
git -C "$VENDOR_INTERFACES_ROOT" diff --     "$N1D_C3B_VENDOR_INTERFACES_LGE_VIBRATOR_TARGET"     > "$EVIDENCE_DIR/vendor-interfaces-lge-vibrator.diff"
git -C "$PHH_ROOT" status --porcelain --untracked-files=all --     "$N1D_C3B_DEVICE_PHH_LGE_VIBRATOR_TARGET"     > "$EVIDENCE_DIR/device-phh-lge-vibrator-status.txt"
git -C "$PHH_ROOT" diff --     "$N1D_C3B_DEVICE_PHH_LGE_VIBRATOR_TARGET"     > "$EVIDENCE_DIR/device-phh-lge-vibrator.diff"

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

unexpected_package="$(
    find "$OUT_DIR_C3B" -type f \
        \( -name '*target_files*.zip' -o -name '*-ota-*.zip' -o -name '*-ota.zip' \) \
        -print -quit
)"
[[ -z "$unexpected_package" ]] ||
    fail "unauthorized_packaging_artifact=$unexpected_package"

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
    echo "N1D_C3B_SCAFFOLD_COMPAT_PATCH_COUNT=$N1D_C3B_SCAFFOLD_COMPAT_PATCH_COUNT"
    echo "N1D_C3B_SCAFFOLD_COMPAT_PATCH_ROLE=$N1D_C3B_SCAFFOLD_COMPAT_PATCH_ROLE"
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
