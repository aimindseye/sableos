#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT/build/config/r8-release.env"
source "$ROOT/build/config/panther-grapheneos-2026081300.env"

BUILD_AUTHORIZED="${BUILD_AUTHORIZED:-NO}"
WS="${WS:-$SABLEOS_UPSTREAM}"
OUT_DIR="${OUT_DIR:-out_sable_ui_final_qual}"
JOBS="${JOBS:-8}"
REQUIRE_FRESH_OUT="${REQUIRE_FRESH_OUT:-NO}"
SABLE_BUILD_STAGE="${SABLE_BUILD_STAGE:-full}"

case "$SABLE_BUILD_STAGE" in
    full|modules) ;;
    *)
        echo "R8_FINAL_BUILD=FAIL_BUILD_STAGE value=$SABLE_BUILD_STAGE"
        exit 2
        ;;
esac

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

if [[ "$SABLE_BUILD_STAGE" == modules && "$REQUIRE_FRESH_OUT" == YES ]]; then
    echo "R9_MODULE_QUALIFICATION_OUT_POLICY=FAIL_FRESH_OUT_FORBIDDEN"
    echo "R8_FINAL_BUILD=FAIL_MODULE_QUALIFICATION_OUT_POLICY"
    exit 3
fi

if [[ "$REQUIRE_FRESH_OUT" == YES ]]; then
    if [[ -e "$OUT_ABS" ]]; then
        echo "R9_FRESH_FULL_BUILD_OUT_PRECONDITION=FAIL_PRESENT path=$OUT_ABS"
        echo "R9_FRESH_FULL_BUILD=FAIL"
        exit 3
    fi
    echo "R9_FRESH_FULL_BUILD_OUT_PRECONDITION=PASS_ABSENT path=$OUT_ABS"
else
    echo "R9_FRESH_FULL_BUILD_OUT_PRECONDITION=NOT_REQUIRED"
fi

if [[ "$SABLE_BUILD_STAGE" == modules ]]; then
    [[ -d "$OUT_ABS/target/product/panther" ]] || {
        echo "R9_MODULE_QUALIFICATION_WARM_OUT=FAIL_PRODUCT_TREE path=$OUT_ABS"
        echo "R8_FINAL_BUILD=FAIL_MODULE_QUALIFICATION_WARM_OUT"
        exit 3
    }

    warm_graph=NO
    [[ -f "$OUT_ABS/build.ninja" ]] && warm_graph=YES
    [[ -f "$OUT_ABS/soong/build.ninja" ]] && warm_graph=YES
    compgen -G "$OUT_ABS/build-*panther*.ninja" >/dev/null && warm_graph=YES
    compgen -G "$OUT_ABS/combined-*panther*.ninja" >/dev/null && warm_graph=YES

    [[ "$warm_graph" == YES ]] || {
        echo "R9_MODULE_QUALIFICATION_WARM_OUT=FAIL_NINJA_GRAPH path=$OUT_ABS"
        echo "R8_FINAL_BUILD=FAIL_MODULE_QUALIFICATION_WARM_OUT"
        exit 3
    }

    echo "R9_MODULE_QUALIFICATION_OUT_POLICY=PASS_WARM_REUSE"
    echo "R9_MODULE_QUALIFICATION_WARM_OUT=PASS path=$OUT_ABS"
fi

R9_FULL_BUILD_START_EPOCH="$(date +%s)"
echo "R9_FULL_BUILD_START_EPOCH=$R9_FULL_BUILD_START_EPOCH"

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
echo "REQUIRE_FRESH_OUT=$REQUIRE_FRESH_OUT"
echo "SABLE_BUILD_STAGE=$SABLE_BUILD_STAGE"

echo
echo "===== PRE-BUILD PRODUCT COMPOSITION ====="

if [[ "$SABLE_BUILD_STAGE" == modules ]]; then
    COMPOSITION_QUALIFICATION_ONLY=YES
else
    COMPOSITION_QUALIFICATION_ONLY=NO
fi

SABLE_QUALIFICATION_ONLY="$COMPOSITION_QUALIFICATION_ONLY" \
WS="$WS" SABLEOS_UPSTREAM="$WS" \
    bash "$ROOT/build/gates/r8-final-product-composition.sh" \
    | tee "$EVIDENCE_DIR/prebuild-composition.log"

grep -Fxq 'R8_FINAL_UI_PRODUCT_COMPOSITION=PASS'     "$EVIDENCE_DIR/prebuild-composition.log"     || {
        echo "R8_FINAL_BUILD=FAIL_PREBUILD_COMPOSITION"
        exit 4
    }

if [[ "$SABLE_BUILD_STAGE" == full ]]; then
    grep -Fxq 'NEXT_FULL_PANTHER_BUILD_AUTHORIZED=YES' \
        "$EVIDENCE_DIR/prebuild-composition.log" || {
            echo "R9_L6_VISUAL_REVIEW_STATUS=PENDING"
            echo "R8_FINAL_BUILD=BLOCKED_R9_VISUAL_REVIEW"
            exit 5
        }
else
    echo "R9_L6_VISUAL_REVIEW_STATUS=PENDING_ALLOWED_FOR_MODULE_QUALIFICATION"
fi

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
echo "===== SABLE HOME + QUICKSTEP RECENTS PREFLIGHT ====="

set +e
m -j"$JOBS" SableLauncher Launcher3QuickStep \
    2>&1 | tee "$EVIDENCE_DIR/sable-home-quickstep-preflight.log"
HOME_RC=${PIPESTATUS[0]}
set -e

echo "R9_SABLE_HOME_QUICKSTEP_PREFLIGHT_RC=$HOME_RC"

if [[ "$HOME_RC" -ne 0 ]]; then
    echo "R9_SABLE_HOME_QUICKSTEP_PREFLIGHT=FAIL"
    echo "R8_FINAL_BUILD=FAIL_SABLE_HOME_QUICKSTEP_PREFLIGHT"
    exit 5
fi

echo "R9_SABLELAUNCHER_MODULE_BUILD=PASS"
echo "R9_QUICKSTEP_RECENTS_MODULE_BUILD=PASS"
echo "R9_SABLE_HOME_QUICKSTEP_PREFLIGHT=PASS"

echo
echo "===== COMBINED UI MODULE COMPILE GATE ====="

set +e
m -j"$JOBS"     SableLauncher     Launcher3QuickStep     AppStore     Dialer     Contacts     DeskClock     DocumentsUI     Gallery2     SableCalculator     SableSudoku     SableMinesweeper     Sable2048     SableMedia     SableTextReader     SableReader     SableHub     SableMail     SableWeather     SableCalendar     SetupWizard2     Settings     SystemUI     framework-minus-apex     2>&1 | tee "$EVIDENCE_DIR/ui-module-build.log"
MODULE_RC=${PIPESTATUS[0]}
set -e

echo "R8_UI_MODULE_BUILD_RC=$MODULE_RC"

if [[ "$MODULE_RC" -ne 0 ]]; then
    echo "R8_UI_MODULE_BUILD=FAIL"
    echo "R8_FINAL_BUILD=FAIL_MODULE_GATE"
    exit 5
fi

echo "R8_UI_MODULE_BUILD=PASS"
echo "R9_PHONE_MODULE_BUILD=PASS"
echo "R9_CONTACTS_MODULE_BUILD=PASS"
echo "R9_CLOCK_MODULE_BUILD=PASS"
echo "R9_FILES_MODULE_BUILD=PASS"
echo "R9_PHOTOS_MODULE_BUILD=PASS"
echo "R9_SABLE_WEATHER_MODULE_BUILD=PASS"
echo "R9_SABLE_CALENDAR_MODULE_BUILD=PASS"
echo "R9_SABLE_TEXT_READER_MODULE_BUILD=PASS"
echo "R9_SABLELAUNCHER_MODULE_BUILD=PASS"
echo "R9_QUICKSTEP_RECENTS_MODULE_BUILD=PASS"
echo "R9_APPSTORE_MODULE_BUILD=PASS"
echo "R9_FRAMEWORK_ADB_NOTIFICATION_MODULE_BUILD=PASS"

if [[ "$SABLE_BUILD_STAGE" == modules ]]; then
    echo
    echo "===== MODULE-ONLY QUALIFICATION RESULT ====="
    echo "R9_SABLE_HOME_QUICKSTEP_PREFLIGHT=PASS"
    echo "R8_UI_MODULE_BUILD=PASS"
    echo "R9_PHYSICAL_UX_MODULE_QUALIFICATION=PASS"
    echo "FULL_TARGET_FILES_BUILD_PERFORMED=NO"
    echo "R9_FRESH_FULL_BUILD=NOT_PROVEN"
    echo "EVIDENCE_DIR=$EVIDENCE_DIR"
    exit 0
fi

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
TF_MTIME_EPOCH="$(stat -c %Y "$TF")"

echo "R8_TARGET_FILES=$TF"
echo "R8_TARGET_FILES_SHA256=$TF_SHA"
echo "R9_TARGET_FILES_MTIME_EPOCH=$TF_MTIME_EPOCH"

if [[ "$REQUIRE_FRESH_OUT" == YES ]]; then
    [[ "$TF_MTIME_EPOCH" -ge "$R9_FULL_BUILD_START_EPOCH" ]] || {
        echo "R9_TARGET_FILES_FRESHNESS=FAIL start=$R9_FULL_BUILD_START_EPOCH mtime=$TF_MTIME_EPOCH"
        echo "R9_FRESH_FULL_BUILD=FAIL"
        exit 8
    }
    echo "R9_TARGET_FILES_FRESHNESS=PASS"
fi

WS="$WS" OUT_DIR="$OUT_DIR" TF="$TF"     bash "$ROOT/build/gates/r8-final-target-files.sh"     | tee "$EVIDENCE_DIR/target-files-composition.log"

grep -Fxq 'R8_FINAL_TARGET_FILES=PASS'     "$EVIDENCE_DIR/target-files-composition.log"     || {
        echo "R8_FINAL_BUILD=FAIL_TARGET_FILES_COMPOSITION"
        exit 9
    }

echo
echo "===== R8 FINAL BUILD RESULT ====="
echo "R8_FINAL_UI_PRODUCT_COMPOSITION=PASS"
echo "R9_SABLE_HOME_QUICKSTEP_PREFLIGHT=PASS"
echo "R9_STANDALONE_SABLELAUNCHER_PRODUCT=PASS_PRESENT"
echo "R9_LAUNCHER3_HOME_ELIGIBILITY=PASS_ABSENT"
echo "R8_UI_MODULE_BUILD=PASS"
echo "R8_FULL_BUILD=PASS"
echo "R8_BUILD_SANDBOX=PASS"
echo "R8_FINAL_TARGET_FILES=PASS"
if [[ "$REQUIRE_FRESH_OUT" == YES ]]; then
    echo "R9_FRESH_FULL_BUILD=PASS"
    echo "R9_FULL_BUILD_CAUSALITY=PASS_ABSENT_OUT_TO_FRESH_TARGET_FILES"
else
    echo "R9_FRESH_FULL_BUILD=NOT_PROVEN"
fi
echo "PANTHER_FINAL_UI_BUILD=PASS"
echo "TARGET_FILES=$TF"
echo "TARGET_FILES_SHA256=$TF_SHA"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
