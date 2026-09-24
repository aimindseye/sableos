#!/usr/bin/env bash
set -euo pipefail

[[ "$(uname -s)" == "Darwin" ]] || {
    echo "R9_PRODUCTION_VISUAL=FAIL_HOST_NOT_MACOS"
    exit 2
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
[[ -n "$SDK_ROOT" ]] || {
    echo "R9_PRODUCTION_VISUAL=FAIL_ANDROID_SDK_UNSET"
    exit 3
}

ADB="$SDK_ROOT/platform-tools/adb"
[[ -x "$ADB" ]] || {
    echo "R9_PRODUCTION_VISUAL=FAIL_ADB path=$ADB"
    exit 4
}

LAST_DIR_FILE="$HOME/Library/Caches/sableos/r9-launcher-visual-review-last-dir"
[[ -f "$LAST_DIR_FILE" ]] || {
    echo "R9_PRODUCTION_VISUAL=FAIL_NO_PREPARED_EVIDENCE_DIR"
    echo "Run build/macos/prepare-r9-launcher-visual-review.sh first."
    exit 5
}
EVIDENCE_DIR="$(cat "$LAST_DIR_FILE")"
[[ -d "$EVIDENCE_DIR" ]] || {
    echo "R9_PRODUCTION_VISUAL=FAIL_EVIDENCE_DIR path=$EVIDENCE_DIR"
    exit 6
}

CURRENT_SOURCE_COMMIT="$(git -C "$ROOT" rev-parse HEAD)"
READY_FILE="$EVIDENCE_DIR/prepare-ready.txt"
[[ -f "$READY_FILE" ]] || {
    echo "R9_PRODUCTION_VISUAL=FAIL_PREPARE_NOT_READY evidence=$EVIDENCE_DIR"
    exit 8
}
grep -Fxq "source_commit=$CURRENT_SOURCE_COMMIT" "$READY_FILE" || {
    echo "R9_PRODUCTION_VISUAL=FAIL_STALE_PREPARE expected=$CURRENT_SOURCE_COMMIT"
    cat "$READY_FILE"
    exit 9
}
grep -Fxq "status=READY" "$READY_FILE" || {
    echo "R9_PRODUCTION_VISUAL=FAIL_PREPARE_STATUS"
    cat "$READY_FILE"
    exit 10
}

SERIAL="${ANDROID_SERIAL:-$("$ADB" devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')}"
[[ -n "$SERIAL" ]] || {
    echo "R9_PRODUCTION_VISUAL=FAIL_NO_DEVICE"
    exit 7
}
export ANDROID_SERIAL="$SERIAL"

CAPTURE="$ROOT/build/macos/capture-r9-launcher-visual-review.sh"

on_error() {
    local rc=$?
    echo
    echo "R9_PRODUCTION_VISUAL=FAIL rc=$rc"
    echo "R9_PRODUCTION_VISUAL_EVIDENCE=$EVIDENCE_DIR"
    echo "The calling Terminal/SSH shell remains active; fix the reported error and rerun."
}
trap on_error ERR

launch_review() {
    local screen="$1"
    local appearance="$2"
    "$ADB" -s "$SERIAL" shell am force-stop org.sableos.start.visualreview
    "$ADB" -s "$SERIAL" shell am start -W         -n org.sableos.start.visualreview/.R9LauncherVisualReviewActivity         --es initialScreen "$screen"         --es appearanceMode "$appearance" >/dev/null
}

echo "===== R9 PRODUCTION VISUAL APPROVAL ====="
echo "SOURCE_COMMIT=$CURRENT_SOURCE_COMMIT"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "MAC_SCOPE=PRODUCTION_SABLE_OWNED_UI_ONLY"
echo "PANTHER_PLATFORM_PROOF=DEFERRED"

launch_review start dark
bash "$CAPTURE" 20-production-start-dark "$EVIDENCE_DIR"

launch_review start light
bash "$CAPTURE" 21-production-start-light "$EVIDENCE_DIR"

launch_review live dark
bash "$CAPTURE" 22-production-live-dark "$EVIDENCE_DIR"

"$ADB" -s "$SERIAL" shell am force-stop org.sableos.calendar
"$ADB" -s "$SERIAL" shell am start -W     -n org.sableos.calendar/.MainActivity >/dev/null
bash "$CAPTURE" 23-production-calendar-dark "$EVIDENCE_DIR"

"$ADB" -s "$SERIAL" shell am force-stop org.sableos.hub
"$ADB" -s "$SERIAL" shell am start -W     -n org.sableos.hub/.MainActivity >/dev/null
bash "$CAPTURE" 24-production-messages-dark "$EVIDENCE_DIR"

echo "R9_PRODUCTION_VISUAL_START_DARK=CAPTURED"
echo "R9_PRODUCTION_VISUAL_START_LIGHT=CAPTURED"
echo "R9_PRODUCTION_VISUAL_LIVE=CAPTURED"
echo "R9_PRODUCTION_VISUAL_CALENDAR=CAPTURED"
echo "R9_PRODUCTION_VISUAL_MESSAGES=CAPTURED"
echo "R9_PRODUCTION_VISUAL_CORE_PLATFORM_APPS=DEFERRED_PANTHER"
echo "R9_PRODUCTION_VISUAL=PASS_CAPTURE_COMPLETE"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
