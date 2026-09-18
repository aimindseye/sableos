#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Allow callers to override SABLEOS_ROOT / SABLEOS_UPSTREAM / SABLEOS_OUT before sourcing.
source "$REPO_ROOT/build/config/panther-grapheneos-2026081300.env"

SOURCE_MUTATION_AUTHORIZED="${SOURCE_MUTATION_AUTHORIZED:-NO}"
BUILD_AUTHORIZED="${BUILD_AUTHORIZED:-NO}"

if [[ "$SOURCE_MUTATION_AUTHORIZED" != YES ]]; then
    echo "Refusing preview source preparation. Set SOURCE_MUTATION_AUTHORIZED=YES explicitly."
    exit 2
fi
if [[ "$BUILD_AUTHORIZED" != YES ]]; then
    echo "Refusing preview image build. Set BUILD_AUTHORIZED=YES explicitly."
    exit 2
fi

if [[ ! -d "$SABLEOS_UPSTREAM/.repo" ]]; then
    echo "NOT_ANDROID_REPO_ROOT=$SABLEOS_UPSTREAM"
    exit 3
fi

PREVIEW_OUT="${SABLEOS_UI_PREVIEW_OUT:-out_sable_ui_preview}"
PREVIEW_EVIDENCE="${SABLEOS_UI_PREVIEW_EVIDENCE:-$SABLEOS_EVIDENCE/ui-preview}"

if [[ "$PREVIEW_OUT" = /* ]]; then
    echo "UI_PREVIEW_OUT_MUST_BE_SOURCE_RELATIVE=$PREVIEW_OUT"
    echo "Use a relative OUT_DIR such as out_sable_ui_preview to preserve Soong path semantics."
    exit 3
fi
PREVIEW_LUNCH_TARGET="${SABLEOS_UI_PREVIEW_LUNCH_TARGET:-panther-cur-userdebug}"
PREVIEW_BUILD_NUMBER="${SABLEOS_UI_PREVIEW_BUILD_NUMBER:-2026091801}"
JOBS="${JOBS:-$(nproc)}"

mkdir -p "$PREVIEW_EVIDENCE"

echo "===== SABLE UI PREVIEW BUILD ====="
echo "SABLEOS_UPSTREAM=$SABLEOS_UPSTREAM"
echo "PREVIEW_OUT=$PREVIEW_OUT"
echo "PREVIEW_EVIDENCE=$PREVIEW_EVIDENCE"
echo "PREVIEW_LUNCH_TARGET=$PREVIEW_LUNCH_TARGET"
echo "PREVIEW_BUILD_NUMBER=$PREVIEW_BUILD_NUMBER"
echo "SOURCE_MUTATION_AUTHORIZED=YES"
echo "BUILD_AUTHORIZED=YES"
echo "FLASH_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"

UI4_APPLICATOR="$REPO_ROOT/patches/android-17-grapheneos-2026081300/apply_ui4_systemui.py"

python3 "$UI4_APPLICATOR" --self-test

if python3 "$UI4_APPLICATOR" --source "$SABLEOS_UPSTREAM" verify >/dev/null 2>&1; then
    echo "UI4_R1_R2_R3_SOURCE_STATE=ALREADY_APPLIED"
    python3 "$UI4_APPLICATOR" --source "$SABLEOS_UPSTREAM" verify
else
    echo "UI4_R1_R2_R3_SOURCE_STATE=APPLYING"
    python3 "$UI4_APPLICATOR" --source "$SABLEOS_UPSTREAM" apply
fi

# UI1 SableStart consumes a shared Soong filegroup outside the SableStart directory.
DESIGN_SRC="$REPO_ROOT/src/android/shared/sabledesign"
DESIGN_DST="$SABLEOS_UPSTREAM/packages/apps/SableDesign"
if [[ ! -f "$DESIGN_SRC/Android.bp" ]]; then
    echo "SABLE_DESIGN_SHARED_SOURCE_MISSING=$DESIGN_SRC/Android.bp"
    exit 4
fi
mkdir -p "$DESIGN_DST"
rsync -a --delete "$DESIGN_SRC/" "$DESIGN_DST/"
echo "SABLE_DESIGN_SHARED_SYNC=PASS"

SOURCE_MUTATION_AUTHORIZED=YES     bash "$REPO_ROOT/build/panther/sync-sablestart.sh"

cd "$SABLEOS_UPSTREAM"
mkdir -p "$PREVIEW_OUT"
source build/envsetup.sh

export OUT_DIR="$PREVIEW_OUT"
export BUILD_NUMBER="$PREVIEW_BUILD_NUMBER"
export SOONG_NINJA=ninja
export SOONG_INCREMENTAL_ANALYSIS=false

lunch "$PREVIEW_LUNCH_TARGET"

STAMP="$(date +%Y%m%d_%H%M%S)"
LOG="$PREVIEW_EVIDENCE/ui-preview-build-$STAMP.log"

set +e
m -j"$JOBS"     SableStart     SystemUI     vendorbootimage     vendorkernelbootimage     target-files-package     2>&1 | tee "$LOG"
rc=${PIPESTATUS[0]}
set -e

echo "BUILD_LOG=$LOG"
echo "BUILD_RC=$rc"
if [[ "$rc" -ne 0 ]]; then
    exit "$rc"
fi

PRODUCT_OUT="$PREVIEW_OUT/target/product/panther"
TARGET_FILES_DIR="$PRODUCT_OUT/obj/PACKAGING/target_files_intermediates"
TARGET_FILES="$(
    find "$TARGET_FILES_DIR" -maxdepth 1 -type f \(         -name '*target_files*.zip' -o -name '*target-files*.zip'     \) -printf '%T@ %p\n' 2>/dev/null     | sort -nr     | head -n1     | cut -d' ' -f2-
)"

if [[ -z "$TARGET_FILES" || ! -f "$TARGET_FILES" ]]; then
    echo "UI_PREVIEW_TARGET_FILES=NOT_FOUND"
    exit 5
fi

echo "TARGET_FILES=$TARGET_FILES"

TARGET_LIST="$PREVIEW_EVIDENCE/ui-preview-target-files-list-$STAMP.txt"
unzip -Z1 "$TARGET_FILES" > "$TARGET_LIST"

if ! grep -Eq '(^|/)SystemUI\.apk$' "$TARGET_LIST"; then
    echo "UI_PREVIEW_SYSTEMUI_PACKAGED=FAIL"
    exit 6
fi
echo "UI_PREVIEW_SYSTEMUI_PACKAGED=PASS"

if ! grep -Eq '(^|/)SableStart\.apk$' "$TARGET_LIST"; then
    echo "UI_PREVIEW_SABLESTART_PACKAGED=FAIL_PRODUCT_WIRING_REQUIRED"
    exit 7
fi
echo "UI_PREVIEW_SABLESTART_PACKAGED=PASS"

required_images=(system.img product.img system_ext.img vbmeta.img)
for image in "${required_images[@]}"; do
    if [[ ! -f "$PRODUCT_OUT/$image" ]]; then
        echo "UI_PREVIEW_IMAGE_MISSING=$PRODUCT_OUT/$image"
        exit 8
    fi
done

(
    cd "$PRODUCT_OUT"
    sha256sum system.img product.img system_ext.img vbmeta.img         | tee UI_PREVIEW_IMAGES.sha256
)
sha256sum "$TARGET_FILES" | tee "$PREVIEW_EVIDENCE/ui-preview-target-files-$STAMP.sha256"

WARNING_CANDIDATES="$PREVIEW_EVIDENCE/ui-preview-warning-candidates-$STAMP.txt"
grep -Ein     'warning|warn:|error|fatal|failed to read|deprecated|undefined reference|neverallow'     "$LOG" > "$WARNING_CANDIDATES" || true

echo "PRODUCT_OUT=$PRODUCT_OUT"
echo "IMAGE_LEDGER=$PRODUCT_OUT/UI_PREVIEW_IMAGES.sha256"
echo "WARNING_CANDIDATES=$WARNING_CANDIDATES"
echo "UI_PREVIEW_BUILD=PASS"
echo "UI_PREVIEW_READY_FOR_INACTIVE_SLOT_FLASH=YES"
