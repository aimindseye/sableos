#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

[[ "$(uname -s)" == "Darwin" ]] || {
    echo "R9_START_TILES_FINAL_CAPTURE=FAIL_HOST_NOT_MACOS"
    exit 2
}

SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
[[ -n "$SDK_ROOT" ]] || {
    echo "R9_START_TILES_FINAL_CAPTURE=FAIL_ANDROID_SDK_UNSET"
    exit 3
}

ADB="$SDK_ROOT/platform-tools/adb"
[[ -x "$ADB" ]] || {
    echo "R9_START_TILES_FINAL_CAPTURE=FAIL_ADB path=$ADB"
    exit 4
}

SERIAL="${ANDROID_SERIAL:-}"
if [[ -z "$SERIAL" ]]; then
    SERIAL="$(
        "$ADB" devices |
            awk 'NR > 1 && $2 == "device" { print $1; exit }'
    )"
fi

[[ -n "$SERIAL" ]] || {
    echo "R9_START_TILES_FINAL_CAPTURE=FAIL_NO_DEVICE"
    exit 5
}

LAST_DIR_FILE="$HOME/Library/Caches/sableos/r9-launcher-visual-review-last-dir"
[[ -f "$LAST_DIR_FILE" ]] || {
    echo "R9_START_TILES_FINAL_CAPTURE=FAIL_NO_REVIEW_EVIDENCE_POINTER"
    exit 6
}

EVIDENCE_DIR="${1:-$(cat "$LAST_DIR_FILE")}"
mkdir -p "$EVIDENCE_DIR"

PACKAGE="org.sableos.start.visualreview"
COMPONENT="$PACKAGE/.R9LauncherVisualReviewActivity"

capture() {
    local frame="$1"
    "$ADB" -s "$SERIAL" exec-out screencap -p > "$EVIDENCE_DIR/$frame.png"
    echo "CAPTURED=$frame"
}

echo "===== R9 FINAL START TILE VISUAL REVIEW ====="
echo "SOURCE_COMMIT=$(git -C "$ROOT" rev-parse HEAD)"
echo "SERIAL=$SERIAL"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"

if ! "$ADB" -s "$SERIAL" shell pm path org.sableos.weather.visualreview |
    grep -q '^package:'
then
    echo "R9_START_WEATHER_VISUAL_FIXTURE=FAIL_NOT_INSTALLED"
    echo "Reinstall/run the approved Sable Weather visual-review APK on this AVD first."
    exit 7
fi

echo "R9_START_WEATHER_VISUAL_FIXTURE=PASS_INSTALLED"

"$ADB" -s "$SERIAL" shell am force-stop "$PACKAGE"
"$ADB" -s "$SERIAL" shell am start -W \
    -n "$COMPONENT" \
    --ez extendedStartTiles true \
    >/dev/null
sleep 1

echo "R9_START_SCROLL_FIXTURE=EXTENDED_14_TILES"
capture 00-start-tiles-top

"$ADB" -s "$SERIAL" shell input swipe 540 1900 540 900 450
sleep 1
capture 01-start-tiles-mid-scroll

"$ADB" -s "$SERIAL" shell input swipe 540 1900 540 700 500
sleep 1
capture 02-start-tiles-lower-scroll

echo
echo "Return to Start top if needed, then LONG-PRESS any visible Start tile."
echo "Sable Peek must visibly show independent Start and Favorites actions."
printf 'Press ENTER only when Sable Peek is visible: '
read -r _
capture 03-start-tile-peek

echo
echo "===== HASH INTEGRITY ====="

FINAL_FRAMES=(
    "$EVIDENCE_DIR/00-start-tiles-top.png"
    "$EVIDENCE_DIR/01-start-tiles-mid-scroll.png"
    "$EVIDENCE_DIR/02-start-tiles-lower-scroll.png"
    "$EVIDENCE_DIR/03-start-tile-peek.png"
)

for frame in "${FINAL_FRAMES[@]}"; do
    test -s "$frame" || {
        echo "R9_START_TILES_FINAL_CAPTURE_INTEGRITY=FAIL_MISSING frame=$frame"
        exit 8
    }
done

if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${FINAL_FRAMES[@]}" |
        tee "$EVIDENCE_DIR/start-tiles-final.sha256"
else
    shasum -a 256 "${FINAL_FRAMES[@]}" |
        tee "$EVIDENCE_DIR/start-tiles-final.sha256"
fi

TOP_HASH="$(awk '$2 ~ /00-start-tiles-top\\.png$/ {print $1}' "$EVIDENCE_DIR/start-tiles-final.sha256")"
MID_HASH="$(awk '$2 ~ /01-start-tiles-mid-scroll\\.png$/ {print $1}' "$EVIDENCE_DIR/start-tiles-final.sha256")"
LOWER_HASH="$(awk '$2 ~ /02-start-tiles-lower-scroll\\.png$/ {print $1}' "$EVIDENCE_DIR/start-tiles-final.sha256")"
PEEK_HASH="$(awk '$2 ~ /03-start-tile-peek\\.png$/ {print $1}' "$EVIDENCE_DIR/start-tiles-final.sha256")"

UNIQUE_HASHES="$(
    awk '{print $1}' "$EVIDENCE_DIR/start-tiles-final.sha256" |
        sort -u |
        wc -l |
        tr -d ' '
)"

echo "R9_START_TILES_FINAL_UNIQUE_HASHES=$UNIQUE_HASHES"

if [[ -z "$TOP_HASH" || -z "$MID_HASH" || -z "$LOWER_HASH" || -z "$PEEK_HASH" ]]; then
    echo "R9_START_TILES_FINAL_CAPTURE_INTEGRITY=FAIL_HASH_RESOLUTION"
    exit 8
fi

if [[ "$TOP_HASH" == "$MID_HASH" ]]; then
    echo "R9_START_SCROLL_VISUAL_PROOF=FAIL_NO_SCROLL_DELTA"
    exit 8
fi

if [[ "$PEEK_HASH" == "$TOP_HASH" || "$PEEK_HASH" == "$MID_HASH" || "$PEEK_HASH" == "$LOWER_HASH" ]]; then
    echo "R9_START_PEEK_VISUAL_PROOF=FAIL_NOT_DISTINCT"
    exit 8
fi

echo "R9_START_SCROLL_VISUAL_PROOF=PASS_TOP_TO_SCROLLED"

if [[ "$MID_HASH" == "$LOWER_HASH" ]]; then
    echo "R9_START_SCROLL_LOWER_BOUND=PASS_STABLE_AFTER_SECOND_SWIPE"
else
    echo "R9_START_SCROLL_LOWER_BOUND=PASS_ADDITIONAL_SCROLL"
fi

if [[ "$UNIQUE_HASHES" -lt 3 ]]; then
    echo "R9_START_TILES_FINAL_CAPTURE_INTEGRITY=FAIL_EXPECTED_AT_LEAST_3_UNIQUE"
    exit 8
fi

echo "R9_START_TILES_FINAL_CAPTURE_INTEGRITY=PASS"
echo "R9_START_PEEK_VISUAL_PROOF=PENDING_IMAGE_REVIEW"
echo "FULL_PANTHER_BUILD_PERFORMED=NO"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
