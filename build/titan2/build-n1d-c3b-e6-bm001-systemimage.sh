#!/usr/bin/env bash
# Build one Titan 2 N1D C3B E6 boot-compat candidate.
#
# Physical evidence admitted by this lane:
#   successful system_a write + successful userdata/metadata wipe + boot loop.
#
# The only new runtime behavior is BM-001: remove init.vndk-nodef.rc and its
# import/package wiring. No VNDK-28 policy, other Restless runtime patch,
# device contact, flash, target-files, OTA or signing is authorized here.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STORAGE="$ROOT/build/config/storage.env"
HOST="$ROOT/build/config/host-tools.env"
TRANSITION="$ROOT/build/titan2/n1d-c3b-transition.env"
PROFILE="$ROOT/build/titan2/n1d-c3b-e2-product-composition.env"
COMPAT_DRIVER="$ROOT/build/titan2/build-n1d-c3b-systemimage.sh"
E2_QUALIFIER="$ROOT/build/titan2/qualify-n1d-c3b-e2-product-composition.sh"
TRANSFORM="$ROOT/build/titan2/apply-n1d-c3b-e6-bm001-boot-compat.py"
STORAGE_VERIFY="$ROOT/build/host/verify-storage-root.sh"

AUTHORIZED=NO
JOBS=16

fail() {
    echo "N1D_C3B_E6_SYSTEMIMAGE=FAIL $*" >&2
    exit 1
}

while (($#)); do
    case "$1" in
        --authorize-e6-systemimage)
            AUTHORIZED=YES
            shift
            ;;
        --jobs)
            [[ $# -ge 2 && "$2" =~ ^[1-9][0-9]*$ ]] || fail invalid_jobs
            JOBS="$2"
            shift 2
            ;;
        *)
            fail "unknown_arg=$1"
            ;;
    esac
done

[[ "$AUTHORIZED" == YES ]] || fail explicit_e6_systemimage_authority_required

for f in "$STORAGE" "$HOST" "$TRANSITION" "$PROFILE" "$COMPAT_DRIVER" "$E2_QUALIFIER" "$TRANSFORM" "$STORAGE_VERIFY"; do
    [[ -f "$f" ]] || fail "missing_file=$f"
done

# shellcheck source=/dev/null
source "$STORAGE"
# shellcheck source=/dev/null
source "$HOST"
# shellcheck source=/dev/null
source "$TRANSITION"
# shellcheck source=/dev/null
source "$PROFILE"

ANDROID_ROOT="$SABLE_BUILD_ROOT/$N1D_C3B_ANDROID_ROOT_REL"
OUT_ROOT="$SABLE_BUILD_ROOT/$N1D_C3B_OUT_ROOT_REL"
BUILD_MAKE_ROOT="$ANDROID_ROOT/build/make"
EVIDENCE_ROOT="$SABLE_EVIDENCE_ROOT/titan2/n1d-c3b-e6-bm001"
LUNCH_TARGET="$N1D_C3B_E2_PRODUCT_NAME-$N1D_C3B_RELEASE_CONFIG-$N1D_C3B_ENGINEERING_VARIANT"
CURRENT_HEAD="$(git -C "$ROOT" rev-parse HEAD)"
BM001_CONTROL_PATCH="$ROOT/patches/android-16-n1d-trebledroid/build-make/0001-Remove-init.vndk-nodef.rc.patch"
BM001_CONTROL_BLOB_EXPECTED=29bc98c8a69291e198fdcf169473e7506256b5d4

[[ -d "$ANDROID_ROOT/.repo" ]] || fail "android_workspace_missing=$ANDROID_ROOT"
[[ -d "$BUILD_MAKE_ROOT/.git" || -f "$BUILD_MAKE_ROOT/.git" ]] ||
    fail "build_make_repo_missing=$BUILD_MAKE_ROOT"
[[ -f "$BM001_CONTROL_PATCH" ]] || fail bm001_control_patch_missing
[[ "$(git hash-object "$BM001_CONTROL_PATCH")" == "$BM001_CONTROL_BLOB_EXPECTED" ]] ||
    fail bm001_control_patch_blob_mismatch

echo "===== TITAN 2 N1D C3B E6 BM-001 BOOT-COMPAT SYSTEMIMAGE ====="
echo "CANONICAL_HEAD=$CURRENT_HEAD"
echo "BUILD_AUTHORIZED=YES_SYSTEMIMAGE_ONLY"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "ANDROID_WORKSPACE_SOURCE_MUTATION_AUTHORIZED=YES_BOUNDED_BM001"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "TARGET_FILES_AUTHORIZED=NO"
echo "OTA_AUTHORIZED=NO"
echo "SIGNING_AUTHORIZED=NO"
echo "VNDK28_SEPOLICY_ADMISSION=NO_DEFERRED"
echo "RESTLESS_RUNTIME_PATCH_ADMISSION_COUNT=1"
echo "RUNTIME_PATCH=BM-001_REMOVE_INIT_VNDK_NODEF"

bash "$STORAGE_VERIFY" runtime

echo
echo "===== STEP 1: REESTABLISH QUALIFIED C3B BASELINE ====="
bash "$COMPAT_DRIVER" \
    --preflight-only \
    --authorize-host-layout-source-mutation \
    --authorize-scaffold-compat-source-mutation \
    --authorize-build-compat-source-mutation \
    --jobs "$JOBS"

echo
echo "===== STEP 2: RESTAGE/QUALIFY UNCHANGED SABLE PRODUCT COMPOSITION ====="
bash "$E2_QUALIFIER" \
    --authorize-composition-qualification \
    --jobs "$JOBS"

echo
echo "===== STEP 3: APPLY ONLY BM-001 BOOT COMPAT ====="
"$SABLE_PYTHON" "$TRANSFORM" apply --repo "$BUILD_MAKE_ROOT"
"$SABLE_PYTHON" "$TRANSFORM" verify --repo "$BUILD_MAKE_ROOT"

if grep -Fq 'import /system/system_ext/etc/gsi/init.vndk-'     "$BUILD_MAKE_ROOT/target/product/gsi/init.gsi.rc"; then
    fail bm001_import_still_present
fi
[[ ! -e "$BUILD_MAKE_ROOT/target/product/gsi/init.vndk-nodef.rc" ]] ||
    fail bm001_nodef_file_still_present

echo "N1D_C3B_E6_BM001_RUNTIME_COMPAT=PASS_APPLIED_ONLY"

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR_E6="$OUT_ROOT/e6-bm001-systemimage/$stamp"
EVIDENCE_DIR="$EVIDENCE_ROOT/$stamp"
mkdir -p "$OUT_DIR_E6" "$EVIDENCE_DIR"

git -C "$BUILD_MAKE_ROOT" status --porcelain --untracked-files=all     > "$EVIDENCE_DIR/build-make-status.txt"
git -C "$BUILD_MAKE_ROOT" diff --     target/product/gsi/Android.bp     target/product/gsi/init.gsi.rc     target/product/gsi/init.vndk-nodef.rc     target/product/gsi_release.mk     > "$EVIDENCE_DIR/bm001-build-make.diff"

exec > >(tee "$EVIDENCE_DIR/e6.log") 2>&1

echo
echo "===== STEP 4: FRESH E6 SYSTEMIMAGE BUILD ====="
(
    cd "$ANDROID_ROOT"
    export OUT_DIR="$OUT_DIR_E6"

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
    find "$OUT_DIR_E6" -type f \
        \( -name '*target_files*.zip' -o -name '*-ota-*.zip' -o -name '*-ota.zip' \) \
        -print -quit
)"
[[ -z "$unexpected_package" ]] ||
    fail "unauthorized_packaging_artifact=$unexpected_package"

modules=(
    SableTitan2Keyboard
    SableTitan2Camera
    SableTitan2DisplayCompat
    SableTitan2Setup
    SableTitan2RadioDiag
)
for module in "${modules[@]}"; do
    [[ -f "$PRODUCT_OUT/system/product/app/$module/$module.apk" ]] ||
        fail "sable_module_missing=$module"
done

sha="$(sha256sum "$SYSTEM_IMG" | awk '{print $1}')"
bytes="$(stat -c '%s' "$SYSTEM_IMG")"
transform_blob="$(git hash-object "$TRANSFORM")"

{
    echo "N1D_C3B_E6_SYSTEMIMAGE=PASS"
    echo "N1D_C3B_E6_CANONICAL_HEAD=$CURRENT_HEAD"
    echo "N1D_C3B_E6_RUNTIME_PATCH_COUNT=1"
    echo "N1D_C3B_E6_RUNTIME_PATCH=BM-001_REMOVE_INIT_VNDK_NODEF"
    echo "N1D_C3B_E6_BM001_CONTROL_BLOB=$BM001_CONTROL_BLOB_EXPECTED"
    echo "N1D_C3B_E6_TRANSFORM_BLOB=$transform_blob"
    echo "N1D_C3B_E6_VNDK28_SEPOLICY_ADMISSION=NO"
    echo "N1D_C3B_E6_SYSTEM_IMG=$SYSTEM_IMG"
    echo "N1D_C3B_E6_SYSTEM_SHA256=$sha"
    echo "N1D_C3B_E6_SYSTEM_BYTES=$bytes"
    echo "N1D_C3B_E6_SABLE_MODULE_COUNT=5"
    echo "N1D_C3B_E6_DEVICE_CONTACT_AUTHORIZED=NO"
    echo "N1D_C3B_E6_FLASH_AUTHORIZED=NO"
    echo "N1D_C3B_E6_TARGET_FILES_AUTHORIZED=NO"
    echo "N1D_C3B_E6_OTA_AUTHORIZED=NO"
} > "$EVIDENCE_DIR/e6-state.env"

(
    cd "$EVIDENCE_DIR"
    find . -type f ! -name SHA256SUMS.txt -print0 |
        LC_ALL=C sort -z |
        xargs -0 sha256sum > SHA256SUMS.txt
    sha256sum -c SHA256SUMS.txt >/dev/null
)

echo "N1D_C3B_E6_SYSTEM_IMG=$SYSTEM_IMG"
echo "N1D_C3B_E6_SYSTEM_SHA256=$sha"
echo "N1D_C3B_E6_SYSTEM_BYTES=$bytes"
echo "N1D_C3B_E6_SABLE_MODULE_COUNT=PASS value=5"
echo "N1D_C3B_E6_SYSTEMIMAGE=PASS"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
