#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT/build/config/panther-grapheneos-2026081300.env"

BUILD_AUTHORIZED="${BUILD_AUTHORIZED:-NO}"
WS="${WS:-$SABLEOS_UPSTREAM}"
OUT_DIR="${OUT_DIR:-out_sable_ui_final_qual}"
JOBS="${JOBS:-8}"

if [[ "$BUILD_AUTHORIZED" != YES ]]; then
    echo "R8_FINAL_BUILD=REFUSED_BUILD_NOT_AUTHORIZED"
    exit 2
fi

[[ -d "$WS/.repo" ]] || {
    echo "R8_ANDROID_WORKSPACE=FAIL path=$WS"
    exit 3
}

if [[ "$OUT_DIR" == /* ]]; then
    OUT_ABS="$OUT_DIR"
else
    OUT_ABS="$WS/$OUT_DIR"
fi

STAMP="$(date +%Y%m%d_%H%M%S)"
EVIDENCE_DIR="${EVIDENCE_DIR:-/srv/data/sable-build/evidence/panther/r8-final-ui/$STAMP}"
mkdir -p "$EVIDENCE_DIR"

echo "===== R8 FINAL PANTHER UI BUILD ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=YES"
echo "CLEAN_AUTHORIZED=NO"
echo "CLOBBER_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "WORKSPACE=$WS"
echo "OUT_DIR=$OUT_DIR"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"

echo
echo "===== PRE-BUILD PRODUCT COMPOSITION ====="

WS="$WS" SABLEOS_UPSTREAM="$WS"     bash "$ROOT/build/gates/r8-final-product-composition.sh"     | tee "$EVIDENCE_DIR/prebuild-composition.log"

grep -Fxq 'R8_FINAL_UI_PRODUCT_COMPOSITION=PASS'     "$EVIDENCE_DIR/prebuild-composition.log"     || {
        echo "R8_FINAL_BUILD=FAIL_PREBUILD_COMPOSITION"
        exit 4
    }

grep -Fxq 'NEXT_FULL_PANTHER_BUILD_AUTHORIZED=YES' \
    "$EVIDENCE_DIR/prebuild-composition.log" || {
        echo "R9_L6_VISUAL_REVIEW_STATUS=PENDING"
        echo "R8_FINAL_BUILD=BLOCKED_R9_VISUAL_REVIEW"
        exit 5
    }

echo
echo "===== SABLESTART SIGNING SOURCE POLICY ====="

SIGNING_POLICY="$ROOT/build/gates/r8-sablestart-signing-policy.py"
SABLESTART_BP="$WS/packages/apps/SableStart/Android.bp"

set +e
python3 "$SIGNING_POLICY" \
    --source-bp "$SABLESTART_BP" \
    2>&1 | tee "$EVIDENCE_DIR/sablestart-signing-source.log"
SABLESTART_SIGNING_SOURCE_RC=${PIPESTATUS[0]}
set -e

echo "R8_SABLESTART_SIGNING_SOURCE_RC=$SABLESTART_SIGNING_SOURCE_RC"

if [[ "$SABLESTART_SIGNING_SOURCE_RC" -ne 0 ]]; then
    echo "R8_SABLESTART_SIGNING_SOURCE_POLICY=FAIL"
    echo "R8_FINAL_BUILD=FAIL_SABLESTART_SIGNING_SOURCE"
    exit 4
fi

echo "R8_SABLESTART_SIGNING_SOURCE_POLICY=PASS"

echo
echo "===== ANDROID BUILD ENVIRONMENT ====="

cd "$WS"

# Never inherit historical D3/preview build identity into the final R8 build.
unset BUILD_DATETIME
unset BUILD_NUMBER
unset SABLEOS_UI_PREVIEW_BUILD_NUMBER

source build/envsetup.sh

export OUT_DIR
export SOONG_NINJA=ninja
export SOONG_INCREMENTAL_ANALYSIS=false

echo
echo "===== LUNCH PANTHER USERDEBUG ====="

# IMPORTANT: lunch mutates the current shell environment. Do not pipe lunch
# directly into tee, because Bash would execute it in a pipeline subshell and
# lose TARGET_PRODUCT/TARGET_RELEASE/TARGET_BUILD_VARIANT before m runs.
set +e
lunch "$SABLEOS_LUNCH_TARGET" > >(tee "$EVIDENCE_DIR/lunch.log") 2>&1
LUNCH_RC=$?
set -e

echo "R8_LUNCH_RC=$LUNCH_RC"

if [[ "$LUNCH_RC" -ne 0 ]]; then
    echo "R8_LUNCH=FAIL"
    echo "R8_FINAL_BUILD=FAIL_LUNCH"
    exit 5
fi

[[ "${TARGET_PRODUCT:-}" == panther ]] || {
    echo "R8_TARGET_PRODUCT=FAIL actual=${TARGET_PRODUCT:-UNSET}"
    exit 5
}
[[ "${TARGET_RELEASE:-}" == cur ]] || {
    echo "R8_TARGET_RELEASE=FAIL actual=${TARGET_RELEASE:-UNSET}"
    exit 5
}
[[ "${TARGET_BUILD_VARIANT:-}" == userdebug ]] || {
    echo "R8_TARGET_BUILD_VARIANT=FAIL actual=${TARGET_BUILD_VARIANT:-UNSET}"
    exit 5
}

echo "R8_TARGET_PRODUCT=PASS value=$TARGET_PRODUCT"
echo "R8_TARGET_RELEASE=PASS value=$TARGET_RELEASE"
echo "R8_TARGET_BUILD_VARIANT=PASS value=$TARGET_BUILD_VARIANT"
echo "R8_LUNCH=PASS"

echo
echo "===== SABLESTART SOONG PREFLIGHT ====="

set +e
m -j"$JOBS" SableStart 2>&1 | tee "$EVIDENCE_DIR/sablestart-soong-preflight.log"
SABLESTART_RC=${PIPESTATUS[0]}
set -e

echo "R8_SABLESTART_SOONG_PREFLIGHT_RC=$SABLESTART_RC"

if [[ "$SABLESTART_RC" -ne 0 ]]; then
    echo "R8_SABLESTART_SOONG_PREFLIGHT=FAIL"
    echo "R8_FINAL_BUILD=FAIL_SABLESTART_PREFLIGHT"
    exit 5
fi

echo "R8_SABLESTART_SOONG_PREFLIGHT=PASS"

echo
echo "===== COMBINED UI MODULE COMPILE GATE ====="

set +e
m -j"$JOBS"     SableStart     SableCalculator     SableSudoku     SableMinesweeper     Sable2048     SableMedia     SableReader     SableHub     SableMail     SetupWizard2     Settings     SystemUI     2>&1 | tee "$EVIDENCE_DIR/ui-module-build.log"
MODULE_RC=${PIPESTATUS[0]}
set -e

echo "R8_UI_MODULE_BUILD_RC=$MODULE_RC"

if [[ "$MODULE_RC" -ne 0 ]]; then
    echo "R8_UI_MODULE_BUILD=FAIL"
    echo "R8_FINAL_BUILD=FAIL_MODULE_GATE"
    exit 5
fi

echo "R8_UI_MODULE_BUILD=PASS"

echo
echo "===== FULL TARGET-FILES BUILD ====="

set +e
m -j"$JOBS"     target-files-package     otatools-package     2>&1 | tee "$EVIDENCE_DIR/full-build.log"
FULL_RC=${PIPESTATUS[0]}
set -e

echo "R8_FULL_BUILD_RC=$FULL_RC"

if [[ "$FULL_RC" -ne 0 ]]; then
    echo "R8_FULL_BUILD=FAIL"
    echo "R8_FINAL_BUILD=FAIL"
    exit 6
fi

echo "R8_FULL_BUILD=PASS"

if grep -Fq 'Build sandboxing disabled due to nsjail error'     "$EVIDENCE_DIR/full-build.log"; then
    echo "R8_BUILD_SANDBOX=FAIL"
    echo "R8_FINAL_BUILD=FAIL_SANDBOX"
    exit 7
fi

echo "R8_BUILD_SANDBOX=PASS"

echo
echo "===== TARGET-FILES COMPOSITION ====="

TF="$(
    find "$OUT_ABS/target/product/panther/obj/PACKAGING/target_files_intermediates"         -maxdepth 1         -type f         \( -name '*target_files*.zip' -o -name '*target-files*.zip' \)         -printf '%T@ %p\n'         | sort -nr         | head -n1         | cut -d' ' -f2-
)"

[[ -n "$TF" && -f "$TF" ]] || {
    echo "R8_TARGET_FILES=FAIL_MISSING"
    echo "R8_FINAL_BUILD=FAIL"
    exit 8
}

TF_SHA="$(sha256sum "$TF" | awk '{print $1}')"

echo "R8_TARGET_FILES=$TF"
echo "R8_TARGET_FILES_SHA256=$TF_SHA"

echo
echo "===== SABLESTART SIGNING TARGET-FILES POLICY ====="

set +e
python3 "$SIGNING_POLICY" \
    --source-bp "$SABLESTART_BP" \
    --target-files "$TF" \
    2>&1 | tee "$EVIDENCE_DIR/sablestart-signing-target-files.log"
SABLESTART_SIGNING_TARGET_RC=${PIPESTATUS[0]}
set -e

echo "R8_SABLESTART_SIGNING_TARGET_RC=$SABLESTART_SIGNING_TARGET_RC"

if [[ "$SABLESTART_SIGNING_TARGET_RC" -ne 0 ]]; then
    echo "R8_SABLESTART_SIGNING_TARGET_FILES_POLICY=FAIL"
    echo "R8_FINAL_BUILD=FAIL_SABLESTART_SIGNING_TARGET"
    exit 9
fi

echo "R8_SABLESTART_SIGNING_TARGET_FILES_POLICY=PASS"

WS="$WS" OUT_DIR="$OUT_DIR" TF="$TF"     bash "$ROOT/build/gates/r8-final-target-files.sh"     | tee "$EVIDENCE_DIR/target-files-composition.log"

grep -Fxq 'R8_FINAL_TARGET_FILES=PASS'     "$EVIDENCE_DIR/target-files-composition.log"     || {
        echo "R8_FINAL_BUILD=FAIL_TARGET_FILES_COMPOSITION"
        exit 9
    }

echo
echo "===== R8 FINAL BUILD RESULT ====="
echo "R8_FINAL_UI_PRODUCT_COMPOSITION=PASS"
echo "R8_UI_MODULE_BUILD=PASS"
echo "R8_FULL_BUILD=PASS"
echo "R8_BUILD_SANDBOX=PASS"
echo "R8_FINAL_TARGET_FILES=PASS"
echo "PANTHER_FINAL_UI_BUILD=PASS"
echo "TARGET_FILES=$TF"
echo "TARGET_FILES_SHA256=$TF_SHA"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
