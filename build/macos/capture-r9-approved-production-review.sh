#!/usr/bin/env bash
set -euo pipefail

[[ "$(uname -s)" == "Darwin" ]] || {
    echo "R9_APPROVED_PRODUCTION_REVIEW=FAIL_HOST_NOT_MACOS"
    exit 2
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
[[ -n "$SDK_ROOT" ]] || {
    echo "R9_APPROVED_PRODUCTION_REVIEW=FAIL_ANDROID_SDK_UNSET"
    exit 3
}
ADB="$SDK_ROOT/platform-tools/adb"
SERIAL="${ANDROID_SERIAL:-$("$ADB" devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')}"
[[ -n "$SERIAL" ]] || {
    echo "R9_APPROVED_PRODUCTION_REVIEW=FAIL_NO_DEVICE"
    exit 4
}

LAST_DIR_FILE="$HOME/Library/Caches/sableos/r9-launcher-visual-review-last-dir"
[[ -f "$LAST_DIR_FILE" ]] || {
    echo "R9_APPROVED_PRODUCTION_REVIEW=FAIL_NO_REVIEW_EVIDENCE_POINTER"
    exit 5
}
EVIDENCE_DIR="${1:-$(cat "$LAST_DIR_FILE")}"
mkdir -p "$EVIDENCE_DIR"

START_PACKAGE="org.sableos.start.visualreview"
START_COMPONENT="$START_PACKAGE/.R9LauncherVisualReviewActivity"
CALENDAR_COMPONENT="org.sableos.calendar/.MainActivity"
MESSAGES_COMPONENT="org.sableos.hub/.MainActivity"
REFERENCE_COMPONENT="$START_PACKAGE/.R9DailyDriverDesignReviewActivity"

capture() {
    local frame="$1"
    sleep "${R9_VISUAL_CAPTURE_SETTLE_SECONDS:-1}"
    "$ADB" -s "$SERIAL" exec-out screencap -p > "$EVIDENCE_DIR/$frame.png"
    echo "CAPTURED=$frame"
}

launch_start() {
    local mode="$1"
    local screen="$2"
    "$ADB" -s "$SERIAL" shell am force-stop "$START_PACKAGE"
    "$ADB" -s "$SERIAL" shell am start -W \
        -n "$START_COMPONENT" \
        --es appearanceMode "$mode" \
        --es initialScreen "$screen" \
        >/dev/null
}

echo "===== R9 APPROVED PRODUCTION VISUAL REVIEW ====="
echo "SOURCE_COMMIT=$(git -C "$ROOT" rev-parse HEAD)"
echo "SERIAL=$SERIAL"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"

echo
echo "===== PRODUCTION-RENDERED SABLE SURFACES ====="
launch_start dark start
capture 20-production-start-dark

launch_start dark live
capture 21-production-live-dark

"$ADB" -s "$SERIAL" shell am force-stop org.sableos.calendar
"$ADB" -s "$SERIAL" shell am start -W -n "$CALENDAR_COMPONENT" >/dev/null
capture 22-production-calendar-dark

"$ADB" -s "$SERIAL" shell am force-stop org.sableos.hub
"$ADB" -s "$SERIAL" shell am start -W -n "$MESSAGES_COMPONENT" >/dev/null
capture 23-production-messages-dark

launch_start light start
capture 24-production-start-light

echo
echo "R9_APPROVED_PRODUCTION_START_DARK=CAPTURED"
echo "R9_APPROVED_PRODUCTION_LIVE=CAPTURED"
echo "R9_APPROVED_PRODUCTION_CALENDAR=CAPTURED"
echo "R9_APPROVED_PRODUCTION_MESSAGES=CAPTURED"
echo "R9_APPROVED_PRODUCTION_START_LIGHT=CAPTURED"

echo
echo "===== BOUNDED APPROVED REFERENCE SURFACES ====="
echo "These frames are the approved design contract for apps whose Panther"
echo "implementation is owned by the AOSP/GrapheneOS product workspace."
echo "They are not represented as Mac product-runtime proof."

for spec in \
    "25-approved-icons-reference:icons" \
    "26-approved-clock-reference:clock" \
    "27-approved-camera-reference:camera" \
    "28-approved-files-reference:files" \
    "29-approved-photos-reference:photos" \
    "30-approved-vanadium-reference:browser"
do
    file="${spec%%:*}"
    frame="${spec#*:}"
    "$ADB" -s "$SERIAL" shell am force-stop "$START_PACKAGE"
    "$ADB" -s "$SERIAL" shell am start -W \
        -n "$REFERENCE_COMPONENT" \
        --es frame "$frame" \
        >/dev/null
    capture "$file"
done

echo
echo "===== HASH INTEGRITY ====="
FILES=(
    "$EVIDENCE_DIR/20-production-start-dark.png"
    "$EVIDENCE_DIR/21-production-live-dark.png"
    "$EVIDENCE_DIR/22-production-calendar-dark.png"
    "$EVIDENCE_DIR/23-production-messages-dark.png"
    "$EVIDENCE_DIR/24-production-start-light.png"
    "$EVIDENCE_DIR/25-approved-icons-reference.png"
    "$EVIDENCE_DIR/26-approved-clock-reference.png"
    "$EVIDENCE_DIR/27-approved-camera-reference.png"
    "$EVIDENCE_DIR/28-approved-files-reference.png"
    "$EVIDENCE_DIR/29-approved-photos-reference.png"
    "$EVIDENCE_DIR/30-approved-vanadium-reference.png"
)

for file in "${FILES[@]}"; do
    test -s "$file" || {
        echo "R9_APPROVED_PRODUCTION_REVIEW=FAIL_MISSING frame=$file"
        exit 6
    }
done

if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${FILES[@]}" | tee "$EVIDENCE_DIR/approved-production.sha256"
else
    shasum -a 256 "${FILES[@]}" | tee "$EVIDENCE_DIR/approved-production.sha256"
fi

echo "R9_APPROVED_PRODUCTION_FRAME_COUNT=5"
echo "R9_APPROVED_BOUNDED_REFERENCE_FRAME_COUNT=6"
echo "R9_APPROVED_START_SETTINGS_ICON=EXPECTED_PHOSPHOR_GEAR"
echo "R9_APPROVED_START_APPEARANCE_SHORTCUT=EXPECTED_ABSENT"
echo "R9_APPROVED_PRODUCTION_REVIEW=PENDING_USER_VISUAL_REVIEW"
echo "NEXT_FULL_PANTHER_BUILD_AUTHORIZED=NO"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
