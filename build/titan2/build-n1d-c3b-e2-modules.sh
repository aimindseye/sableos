#!/usr/bin/env bash
# Build exactly the five E2 Sable app-import modules in the canonical Android tree.
# This is not a systemimage, target-files, OTA, device or release build.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STORAGE_PROFILE="$ROOT/build/config/storage.env"
TRANSITION="$ROOT/build/titan2/n1d-c3b-transition.env"
PROFILE="$ROOT/build/titan2/n1d-c3b-e2-product-composition.env"
COMPOSITION_GATE="$ROOT/build/gates/n1d-c3b-e2-product-composition-contract.sh"
HOST_TOOLS="$ROOT/build/config/host-tools.env"
STORAGE_VERIFY="$ROOT/build/host/verify-storage-root.sh"

AUTHORIZE_MODULE_BUILD=NO
JOBS=16

fail() {
    echo "N1D_C3B_E2_MODULE_BUILD=FAIL $*" >&2
    exit 1
}

while (($#)); do
    case "$1" in
        --authorize-module-build)
            AUTHORIZE_MODULE_BUILD=YES
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

[[ "$AUTHORIZE_MODULE_BUILD" == YES ]] || fail explicit_module_build_authority_required

for f in "$STORAGE_PROFILE" "$TRANSITION" "$PROFILE" "$COMPOSITION_GATE" "$HOST_TOOLS" "$STORAGE_VERIFY"; do
    [[ -f "$f" ]] || fail "missing_file=$f"
done

# shellcheck source=/dev/null
source "$STORAGE_PROFILE"
# shellcheck source=/dev/null
source "$TRANSITION"
# shellcheck source=/dev/null
source "$PROFILE"
# shellcheck source=/dev/null
source "$HOST_TOOLS"

bash "$STORAGE_VERIFY" runtime
bash "$COMPOSITION_GATE"

ANDROID_ROOT="$SABLE_BUILD_ROOT/$N1D_C3B_ANDROID_ROOT_REL"
OUT_ROOT="$SABLE_BUILD_ROOT/$N1D_C3B_OUT_ROOT_REL"
STAGE_ROOT="$ANDROID_ROOT/$N1D_C3B_E2_ANDROID_STAGE_ROOT"
EVIDENCE_ROOT="$SABLE_EVIDENCE_ROOT/titan2/n1d-c3b-e2-module-build"
LUNCH_TARGET="$N1D_C3B_E2_LUNCH_TARGET"

[[ -d "$ANDROID_ROOT/.repo" ]] || fail "android_workspace_missing=$ANDROID_ROOT"
[[ -f "$STAGE_ROOT/source-binding.env" ]] || fail "product_stage_missing=$STAGE_ROOT"
grep -Fxq "N1D_C3B_E2_SOURCE_IMPORT_COMMIT=$N1D_C3B_E2_SOURCE_IMPORT_COMMIT" "$STAGE_ROOT/source-binding.env" ||
    fail staged_source_binding

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR_BUILD="$OUT_ROOT/e2-modules/$stamp"
EVIDENCE_DIR="$EVIDENCE_ROOT/$stamp"
mkdir -p "$OUT_DIR_BUILD" "$EVIDENCE_DIR"

exec > >(tee "$EVIDENCE_DIR/module-build.log") 2>&1

echo "===== N1D C3B E2 FOCUSED MODULE BUILD ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=YES_EXACT_5_MODULES"
echo "FULL_IMAGE_BUILD_AUTHORIZED=NO"
echo "TARGET_FILES_AUTHORIZED=NO"
echo "OTA_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "PRODUCTION_SIGNING_AUTHORIZED=NO"
echo "LUNCH_TARGET=$LUNCH_TARGET"
echo "OUT_DIR=$OUT_DIR_BUILD"

modules=(
    SableTitan2Keyboard
    SableTitan2Camera
    SableTitan2DisplayCompat
    SableTitan2Setup
    SableTitan2RadioDiag
)

(
    cd "$ANDROID_ROOT"
    export OUT_DIR="$OUT_DIR_BUILD"

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

    [[ "${TARGET_PRODUCT:-}" == "$N1D_C3B_E2_PRODUCT_NAME" ]] ||
        fail "target_product=${TARGET_PRODUCT:-unset}"

    m -j"$JOBS" "${modules[@]}"
)

PRODUCT_OUT="$OUT_DIR_BUILD/target/product/$N1D_C3B_E2_PRODUCT_DEVICE"
AAPT2="$SABLE_ANDROID_BUILD_TOOLS/aapt2"
APKSIGNER="$SABLE_ANDROID_BUILD_TOOLS/apksigner"
[[ -x "$AAPT2" ]] || fail "missing_aapt2=$AAPT2"
[[ -x "$APKSIGNER" ]] || fail "missing_apksigner=$APKSIGNER"

declare -A packages=(
    [SableTitan2Keyboard]=org.sableos.titan2.keyboard
    [SableTitan2Camera]=org.sableos.titan2.camera
    [SableTitan2DisplayCompat]=org.sableos.titan2.displaycompat
    [SableTitan2Setup]=org.sableos.titan2.setup
    [SableTitan2RadioDiag]=org.sableos.titan2.radiodiag
)

MANIFEST="$EVIDENCE_DIR/module-artifacts.tsv"
printf 'module\tpackage\tapk\tsha256\tbytes\tsigned\n' > "$MANIFEST"

for module in "${modules[@]}"; do
    apk="$PRODUCT_OUT/product/app/$module/$module.apk"
    [[ -f "$apk" ]] || fail "installed_module_apk_missing module=$module path=$apk"
    actual_package="$("$AAPT2" dump badging "$apk" | sed -n "s/^package: name='\([^']*\)'.*/\1/p" | head -n1)"
    [[ "$actual_package" == "${packages[$module]}" ]] ||
        fail "package_mismatch module=$module expected=${packages[$module]} actual=$actual_package"
    "$APKSIGNER" verify "$apk" >/dev/null 2>&1 ||
        fail "android_import_apk_not_signed module=$module"
    sha="$(sha256sum "$apk" | awk '{print $1}')"
    bytes="$(stat -c '%s' "$apk")"
    printf '%s\t%s\t%s\t%s\t%s\tYES\n' "$module" "$actual_package" "$apk" "$sha" "$bytes" >> "$MANIFEST"
done

if find "$OUT_DIR_BUILD" -type f \( -name 'system.img' -o -name '*target_files*.zip' -o -name '*-ota*.zip' \) -print -quit | grep -q .; then
    fail unexpected_full_image_or_release_artifact
fi

(
    cd "$EVIDENCE_DIR"
    find . -type f ! -name SHA256SUMS.txt ! -name module-build.log -print0 |
        LC_ALL=C sort -z |
        xargs -0 sha256sum > SHA256SUMS.txt
    sha256sum -c SHA256SUMS.txt >/dev/null
)

echo "N1D_C3B_E2_MODULE_BUILD_PRODUCT=PASS_SABLE_TITAN2"
echo "N1D_C3B_E2_MODULE_BUILD_COUNT=PASS value=5"
echo "N1D_C3B_E2_MODULE_BUILD_PACKAGE_IDS=PASS count=5"
echo "N1D_C3B_E2_MODULE_BUILD_DEV_SIGNING=PASS count=5"
echo "N1D_C3B_E2_MODULE_BUILD_FULL_IMAGE=PASS_ABSENT"
echo "N1D_C3B_E2_MODULE_BUILD=PASS"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "PRODUCT_OUT=$PRODUCT_OUT"
