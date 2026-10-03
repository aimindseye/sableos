#!/usr/bin/env bash
# Build the first Sable-composed Titan 2 C3B E3 engineering system image.
#
# The long systemimage build is entered only after:
#   1. the proven C3B compatibility set is present;
#   2. source-bound E2 app build/staging/product parse succeeds;
#   3. exactly five Sable product modules build successfully; and
#   4. TARGET_COPY_OUT_PRODUCT resolves to system/product for the GSI.
#
# Target-files, OTA, device contact, flash, production signing and release are
# deliberately outside this driver.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STORAGE_PROFILE="$ROOT/build/config/storage.env"
HOST_TOOLS="$ROOT/build/config/host-tools.env"
TRANSITION="$ROOT/build/titan2/n1d-c3b-transition.env"
PROFILE="$ROOT/build/titan2/n1d-c3b-e2-product-composition.env"
COMPOSITION_GATE="$ROOT/build/gates/n1d-c3b-e2-product-composition-contract.sh"
E3_GATE="$ROOT/build/gates/n1d-c3b-e3-systemimage-contract.sh"
COMPAT_DRIVER="$ROOT/build/titan2/build-n1d-c3b-systemimage.sh"
E2_QUALIFIER="$ROOT/build/titan2/qualify-n1d-c3b-e2-product-composition.sh"
STORAGE_VERIFY="$ROOT/build/host/verify-storage-root.sh"

AUTHORIZE_E3_SYSTEMIMAGE=NO
JOBS=16

fail() {
    echo "N1D_C3B_E3_SYSTEMIMAGE=FAIL $*" >&2
    exit 1
}

while (($#)); do
    case "$1" in
        --authorize-e3-systemimage)
            AUTHORIZE_E3_SYSTEMIMAGE=YES
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

[[ "$AUTHORIZE_E3_SYSTEMIMAGE" == YES ]] ||
    fail explicit_e3_systemimage_authority_required

for f in \
    "$STORAGE_PROFILE" \
    "$HOST_TOOLS" \
    "$TRANSITION" \
    "$PROFILE" \
    "$COMPOSITION_GATE" \
    "$E3_GATE" \
    "$COMPAT_DRIVER" \
    "$E2_QUALIFIER" \
    "$STORAGE_VERIFY"
do
    [[ -f "$f" ]] || fail "missing_file=$f"
done

# shellcheck source=/dev/null
source "$STORAGE_PROFILE"
# shellcheck source=/dev/null
source "$HOST_TOOLS"
# shellcheck source=/dev/null
source "$TRANSITION"
# shellcheck source=/dev/null
source "$PROFILE"

[[ "$N1D_C3_CURRENT_ACTIVE_PHASE" == C3B_ENGINEERING ]] ||
    fail "active_phase=$N1D_C3_CURRENT_ACTIVE_PHASE"
[[ "$N1D_C3B_E2_BUILD_GOAL" == systemimage ]] ||
    fail "e2_build_goal=$N1D_C3B_E2_BUILD_GOAL"
[[ "$N1D_C3B_E2_PRODUCT_NAME" == sable_titan2 ]] ||
    fail "product=$N1D_C3B_E2_PRODUCT_NAME"
[[ "$N1D_C3B_E2_PRODUCT_DEVICE" == tdgsi_arm64_ab ]] ||
    fail "device=$N1D_C3B_E2_PRODUCT_DEVICE"
[[ "$N1D_C3B_RUNTIME_PATCH_ALLOWLIST_COUNT" == 0 ]] ||
    fail runtime_patch_allowlist_not_zero
[[ "$N1D_C3B_E2_DEVICE_CONTACT_AUTHORIZED" == NO ]] ||
    fail device_contact_boundary_changed
[[ "$N1D_C3B_E2_FLASH_AUTHORIZED" == NO ]] ||
    fail flash_boundary_changed
[[ "$N1D_C3B_E2_TARGET_FILES_AUTHORIZED" == NO ]] ||
    fail target_files_boundary_changed
[[ "$N1D_C3B_E2_OTA_AUTHORIZED" == NO ]] ||
    fail ota_boundary_changed
[[ "$N1D_C3B_E2_PRODUCTION_SIGNING_AUTHORIZED" == NO ]] ||
    fail production_signing_boundary_changed
[[ "$N1D_C3B_E2_RELEASE_ELIGIBLE" == NO ]] ||
    fail release_boundary_changed

CURRENT_HEAD="$(git -C "$ROOT" rev-parse HEAD)"
git -C "$ROOT" merge-base --is-ancestor "$N1D_C3B_E2_SOURCE_IMPORT_COMMIT" "$CURRENT_HEAD" ||
    fail "source_import_not_ancestor=$N1D_C3B_E2_SOURCE_IMPORT_COMMIT"

ANDROID_ROOT="$SABLE_BUILD_ROOT/$N1D_C3B_ANDROID_ROOT_REL"
OUT_ROOT="$SABLE_BUILD_ROOT/$N1D_C3B_OUT_ROOT_REL"
STAGE_ROOT="$ANDROID_ROOT/$N1D_C3B_E2_ANDROID_STAGE_ROOT"
BUILD_EVIDENCE_ROOT="$SABLE_EVIDENCE_ROOT/titan2/n1d-c3b-e3-systemimage"

[[ -d "$ANDROID_ROOT/.repo" ]] || fail "android_workspace_missing=$ANDROID_ROOT"

bash "$STORAGE_VERIFY" runtime
bash "$COMPOSITION_GATE"
bash "$E3_GATE"

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="$BUILD_EVIDENCE_ROOT/$stamp"
mkdir -p "$EVIDENCE_DIR"

exec > >(tee "$EVIDENCE_DIR/e3.log") 2>&1

echo "===== N1D C3B E3 SABLE SYSTEMIMAGE ====="
echo "CANONICAL_HEAD=$CURRENT_HEAD"
echo "SOURCE_IMPORT_COMMIT=$N1D_C3B_E2_SOURCE_IMPORT_COMMIT"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "ANDROID_WORKSPACE_SOURCE_MUTATION_AUTHORIZED=YES_BOUNDED_COMPAT_AND_VENDOR_SABLE_TITAN2_STAGE"
echo "BUILD_AUTHORIZED=YES_SABLE_TITAN2_SYSTEMIMAGE_AFTER_PREFLIGHT"
echo "TARGET_FILES_AUTHORIZED=NO"
echo "OTA_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "PRODUCTION_SIGNING_AUTHORIZED=NO"
echo "RELEASE_ELIGIBLE=NO"

echo
echo "===== STEP 1: PROVEN C3B COMPATIBILITY PREFLIGHT ====="
COMPAT_LOG="$EVIDENCE_DIR/compat-preflight.log"
set +e
bash "$COMPAT_DRIVER" \
    --preflight-only \
    --authorize-host-layout-source-mutation \
    --authorize-scaffold-compat-source-mutation \
    --authorize-build-compat-source-mutation \
    --jobs "$JOBS" \
    2>&1 | tee "$COMPAT_LOG"
compat_rc="${PIPESTATUS[0]}"
set -e
[[ "$compat_rc" -eq 0 ]] || fail "compat_preflight_rc=$compat_rc"
grep -Fxq 'N1D_C3B_SYSTEMIMAGE_PREFLIGHT=PASS' "$COMPAT_LOG" ||
    fail compat_preflight_pass_marker_missing

echo
echo "===== STEP 2: SOURCE-BOUND E2 COMPOSITION QUALIFICATION ====="
E2_LOG="$EVIDENCE_DIR/e2-composition-qualification.log"
set +e
bash "$E2_QUALIFIER" \
    --authorize-composition-qualification \
    --jobs "$JOBS" \
    2>&1 | tee "$E2_LOG"
e2_rc="${PIPESTATUS[0]}"
set -e
[[ "$e2_rc" -eq 0 ]] || fail "e2_qualification_rc=$e2_rc"

E2_EVIDENCE="$(sed -n 's/^EVIDENCE_DIR=//p' "$E2_LOG" | tail -n1)"
[[ -n "$E2_EVIDENCE" && "$E2_EVIDENCE" = /* ]] ||
    fail "e2_evidence_not_reported=$E2_EVIDENCE"
[[ -f "$E2_EVIDENCE/qualification-state.env" ]] ||
    fail "e2_state_missing=$E2_EVIDENCE/qualification-state.env"
(
    cd "$E2_EVIDENCE"
    sha256sum -c SHA256SUMS.txt >/dev/null
) || fail e2_evidence_hash_invalid

grep -Fxq 'N1D_C3B_E2_PRODUCT_COMPOSITION_QUALIFICATION=PASS' "$E2_EVIDENCE/qualification-state.env" ||
    fail e2_qualification_not_pass
grep -Fxq "N1D_C3B_E2_CANONICAL_HEAD=$CURRENT_HEAD" "$E2_EVIDENCE/qualification-state.env" ||
    fail e2_qualification_head_mismatch
grep -Fxq "N1D_C3B_E2_SOURCE_IMPORT_COMMIT=$N1D_C3B_E2_SOURCE_IMPORT_COMMIT" "$E2_EVIDENCE/qualification-state.env" ||
    fail e2_qualification_source_import_mismatch
grep -Fxq 'N1D_C3B_E2_MODULE_COUNT=5' "$E2_EVIDENCE/qualification-state.env" ||
    fail e2_qualification_module_count
grep -Fxq 'N1D_C3B_E2_FULL_IMAGE_BUILD_AUTHORIZED=NO' "$E2_EVIDENCE/qualification-state.env" ||
    fail e2_qualification_boundary_mismatch

[[ -f "$STAGE_ROOT/source-binding.env" ]] ||
    fail "stage_binding_missing=$STAGE_ROOT/source-binding.env"
grep -Fxq "N1D_C3B_E2_CANONICAL_BUILD_HEAD=$CURRENT_HEAD" "$STAGE_ROOT/source-binding.env" ||
    fail staged_head_mismatch
grep -Fxq "N1D_C3B_E2_PRODUCT_NAME=$N1D_C3B_E2_PRODUCT_NAME" "$STAGE_ROOT/source-binding.env" ||
    fail staged_product_mismatch
grep -Fxq "N1D_C3B_E2_MODULE_COUNT=5" "$STAGE_ROOT/source-binding.env" ||
    fail staged_module_count

echo
echo "===== STEP 3: FINAL PRE-BUILD PRODUCT ROUTING ====="
OUT_DIR_E3="$OUT_ROOT/e3-systemimage/$stamp"
[[ ! -e "$OUT_DIR_E3" ]] || fail "fresh_out_required=$OUT_DIR_E3"
mkdir -p "$OUT_DIR_E3"

PRODUCT_OUT_FILE="$EVIDENCE_DIR/product-out.txt"
PRODUCT_COPY_OUT_FILE="$EVIDENCE_DIR/product-copy-out.txt"
PRODUCT_PACKAGES_FILE="$EVIDENCE_DIR/product-packages.txt"

modules=(
    SableTitan2Keyboard
    SableTitan2Camera
    SableTitan2DisplayCompat
    SableTitan2Setup
    SableTitan2RadioDiag
)

(
    cd "$ANDROID_ROOT"
    export OUT_DIR="$OUT_DIR_E3"

    set +e +u
    # shellcheck source=/dev/null
    source build/envsetup.sh
    envsetup_rc=$?
    set -euo pipefail
    [[ "$envsetup_rc" -eq 0 ]] || fail "envsetup_rc=$envsetup_rc"

    set +e +u
    lunch "$N1D_C3B_E2_LUNCH_TARGET"
    lunch_rc=$?
    set -euo pipefail
    [[ "$lunch_rc" -eq 0 ]] || fail "lunch_rc=$lunch_rc"

    [[ "${TARGET_PRODUCT:-}" == "$N1D_C3B_E2_PRODUCT_NAME" ]] ||
        fail "target_product=${TARGET_PRODUCT:-unset}"
    [[ "${TARGET_RELEASE:-}" == "$N1D_C3B_E2_RELEASE_CONFIG" ]] ||
        fail "target_release=${TARGET_RELEASE:-unset}"
    [[ "${TARGET_BUILD_VARIANT:-}" == "$N1D_C3B_E2_BUILD_VARIANT" ]] ||
        fail "target_variant=${TARGET_BUILD_VARIANT:-unset}"

    product_out="$(get_build_var PRODUCT_OUT)"
    product_copy_out="$(get_build_var TARGET_COPY_OUT_PRODUCT)"
    product_packages="$(get_build_var PRODUCT_PACKAGES)"

    [[ "$product_copy_out" == "system/product" ]] ||
        fail "target_copy_out_product=$product_copy_out"

    for module in "${modules[@]}"; do
        grep -Eq "(^|[[:space:]])${module}([[:space:]]|$)" <<<"$product_packages" ||
            fail "module_not_in_product_packages=${module}"
    done
    for forbidden in SableTitan2Screens SableTitan2Home; do
        if grep -Eq "(^|[[:space:]])${forbidden}([[:space:]]|$)" <<<"$product_packages"; then
            fail "forbidden_module_in_product_packages=${forbidden}"
        fi
    done

    printf '%s\n' "$product_out" > "$PRODUCT_OUT_FILE"
    printf '%s\n' "$product_copy_out" > "$PRODUCT_COPY_OUT_FILE"
    printf '%s\n' "$product_packages" > "$PRODUCT_PACKAGES_FILE"
)

grep -Fxq 'system/product' "$PRODUCT_COPY_OUT_FILE" ||
    fail product_route_not_system_product
echo "N1D_C3B_E3_PREBUILD_PRODUCT_ROUTE=PASS_SYSTEM_PRODUCT"
echo "N1D_C3B_E3_PREBUILD_PRODUCT_PACKAGES=PASS_EXACT_REQUIRED_5"

echo
echo "===== STEP 4: LONG SABLE TITAN 2 SYSTEMIMAGE BUILD ====="
(
    cd "$ANDROID_ROOT"
    export OUT_DIR="$OUT_DIR_E3"

    set +e +u
    # shellcheck source=/dev/null
    source build/envsetup.sh
    envsetup_rc=$?
    set -euo pipefail
    [[ "$envsetup_rc" -eq 0 ]] || fail "envsetup_build_rc=$envsetup_rc"

    set +e +u
    lunch "$N1D_C3B_E2_LUNCH_TARGET"
    lunch_rc=$?
    set -euo pipefail
    [[ "$lunch_rc" -eq 0 ]] || fail "lunch_build_rc=$lunch_rc"

    set +e +u
    make systemimage -j"$JOBS" 2>&1 | tee "$EVIDENCE_DIR/systemimage-command.log"
    build_rc="${PIPESTATUS[0]}"
    set -euo pipefail
    [[ "$build_rc" -eq 0 ]] || fail "systemimage_build_rc=$build_rc"
)

PRODUCT_OUT="$(cat "$PRODUCT_OUT_FILE")"
PRODUCT_COPY_OUT="$(cat "$PRODUCT_COPY_OUT_FILE")"
SYSTEM_IMG="$PRODUCT_OUT/system.img"
[[ -f "$SYSTEM_IMG" ]] || fail "system_img_missing=$SYSTEM_IMG"

declare -A packages=(
    [SableTitan2Keyboard]=org.sableos.titan2.keyboard
    [SableTitan2Camera]=org.sableos.titan2.camera
    [SableTitan2DisplayCompat]=org.sableos.titan2.displaycompat
    [SableTitan2Setup]=org.sableos.titan2.setup
    [SableTitan2RadioDiag]=org.sableos.titan2.radiodiag
)

AAPT2="$SABLE_ANDROID_BUILD_TOOLS/aapt2"
APKSIGNER="$SABLE_ANDROID_BUILD_TOOLS/apksigner"
[[ -x "$AAPT2" ]] || fail "missing_aapt2=$AAPT2"
[[ -x "$APKSIGNER" ]] || fail "missing_apksigner=$APKSIGNER"

MODULE_MANIFEST="$EVIDENCE_DIR/system-product-apps.tsv"
printf 'module\tpackage\tapk\tsha256\tbytes\tsigned\n' > "$MODULE_MANIFEST"
for module in "${modules[@]}"; do
    apk="$PRODUCT_OUT/$PRODUCT_COPY_OUT/app/$module/$module.apk"
    [[ -f "$apk" ]] || fail "system_product_apk_missing module=$module path=$apk"
    actual_package="$("$AAPT2" dump badging "$apk" | sed -n "s/^package: name='\([^']*\)'.*/\1/p" | head -n1)"
    [[ "$actual_package" == "${packages[$module]}" ]] ||
        fail "package_mismatch module=$module expected=${packages[$module]} actual=$actual_package"
    "$APKSIGNER" verify "$apk" >/dev/null 2>&1 ||
        fail "system_product_apk_not_signed module=$module"
    apk_sha="$(sha256sum "$apk" | awk '{print $1}')"
    apk_bytes="$(stat -c '%s' "$apk")"
    printf '%s\t%s\t%s\t%s\t%s\tYES\n' \
        "$module" "$actual_package" "$apk" "$apk_sha" "$apk_bytes" >> "$MODULE_MANIFEST"
done

unexpected_package="$(
    find "$OUT_DIR_E3" -type f \
        \( -name '*target_files*.zip' -o -name '*-ota-*.zip' -o -name '*-ota.zip' \) \
        -print -quit
)"
[[ -z "$unexpected_package" ]] ||
    fail "unauthorized_packaging_artifact=$unexpected_package"

system_sha="$(sha256sum "$SYSTEM_IMG" | awk '{print $1}')"
system_bytes="$(stat -c '%s' "$SYSTEM_IMG")"

{
    echo "N1D_C3B_E3_SYSTEMIMAGE=PASS"
    echo "N1D_C3B_E3_CANONICAL_HEAD=$CURRENT_HEAD"
    echo "N1D_C3B_E3_SOURCE_IMPORT_COMMIT=$N1D_C3B_E2_SOURCE_IMPORT_COMMIT"
    echo "N1D_C3B_E3_E2_QUALIFICATION_EVIDENCE=$E2_EVIDENCE"
    echo "N1D_C3B_E3_PRODUCT=$N1D_C3B_E2_PRODUCT_NAME"
    echo "N1D_C3B_E3_PRODUCT_DEVICE=$N1D_C3B_E2_PRODUCT_DEVICE"
    echo "N1D_C3B_E3_RELEASE_CONFIG=$N1D_C3B_E2_RELEASE_CONFIG"
    echo "N1D_C3B_E3_VARIANT=$N1D_C3B_E2_BUILD_VARIANT"
    echo "N1D_C3B_E3_TARGET_COPY_OUT_PRODUCT=$PRODUCT_COPY_OUT"
    echo "N1D_C3B_E3_MODULE_COUNT=5"
    echo "N1D_C3B_E3_SYSTEM_IMG=$SYSTEM_IMG"
    echo "N1D_C3B_E3_SYSTEM_SHA256=$system_sha"
    echo "N1D_C3B_E3_SYSTEM_BYTES=$system_bytes"
    echo "N1D_C3B_E3_TARGET_FILES_AUTHORIZED=NO"
    echo "N1D_C3B_E3_OTA_AUTHORIZED=NO"
    echo "N1D_C3B_E3_DEVICE_CONTACT_AUTHORIZED=NO"
    echo "N1D_C3B_E3_FLASH_AUTHORIZED=NO"
    echo "N1D_C3B_E3_PRODUCTION_SIGNING_AUTHORIZED=NO"
    echo "N1D_C3B_E3_RELEASE_ELIGIBLE=NO"
} > "$EVIDENCE_DIR/build-state.env"

(
    cd "$EVIDENCE_DIR"
    find . -type f \
        ! -name SHA256SUMS.txt \
        ! -name e3.log \
        ! -name compat-preflight.log \
        ! -name e2-composition-qualification.log \
        ! -name systemimage-command.log \
        -print0 |
        LC_ALL=C sort -z |
        xargs -0 sha256sum > SHA256SUMS.txt
    sha256sum -c SHA256SUMS.txt >/dev/null
)

echo
echo "N1D_C3B_E3_COMPATIBILITY_PREFLIGHT=PASS"
echo "N1D_C3B_E3_E2_COMPOSITION_QUALIFICATION=PASS"
echo "N1D_C3B_E3_PRODUCT_ROUTE=PASS_SYSTEM_PRODUCT"
echo "N1D_C3B_E3_MODULES_IN_SYSTEM_TREE=PASS count=5"
echo "N1D_C3B_E3_POSTBUILD_PACKAGING_ARTIFACTS=PASS_ABSENT"
echo "SYSTEM_IMG=$SYSTEM_IMG"
echo "SYSTEM_SHA256=$system_sha"
echo "SYSTEM_BYTES=$system_bytes"
echo "N1D_C3B_E3_SYSTEMIMAGE=PASS"
echo "N1D_C3B_E3_DEVICE_CONTACT_AUTHORIZED=NO"
echo "N1D_C3B_E3_RELEASE_ELIGIBLE=NO"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
