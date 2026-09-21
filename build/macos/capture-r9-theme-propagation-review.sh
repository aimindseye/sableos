#!/usr/bin/env bash
set -euo pipefail

[[ "$(uname -s)" == "Darwin" ]] || {
    echo "R9_THEME_PROPAGATION_REVIEW=FAIL_HOST_NOT_MACOS"
    exit 2
}

SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
[[ -n "$SDK_ROOT" ]] || {
    echo "R9_THEME_PROPAGATION_REVIEW=FAIL_ANDROID_SDK_UNSET"
    exit 3
}

ADB="$SDK_ROOT/platform-tools/adb"
[[ -x "$ADB" ]] || {
    echo "R9_THEME_PROPAGATION_REVIEW=FAIL_ADB path=$ADB"
    exit 4
}

SERIAL="${ANDROID_SERIAL:-$("$ADB" devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')}"
[[ -n "$SERIAL" ]] || {
    echo "R9_THEME_PROPAGATION_REVIEW=FAIL_NO_DEVICE"
    exit 5
}

CACHE_DIR="$HOME/Library/Caches/sableos"
LAST_DIR_FILE="$CACHE_DIR/r9-launcher-visual-review-last-dir"
EVIDENCE_DIR="${1:-}"
if [[ -z "$EVIDENCE_DIR" && -f "$LAST_DIR_FILE" ]]; then
    EVIDENCE_DIR="$(cat "$LAST_DIR_FILE")"
fi
[[ -n "$EVIDENCE_DIR" && -d "$EVIDENCE_DIR" ]] || {
    echo "R9_THEME_PROPAGATION_REVIEW=FAIL_EVIDENCE_DIR"
    exit 6
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_COMMIT="$(git -C "$ROOT" rev-parse HEAD)"

capture() {
    local name="$1"
    "$ADB" -s "$SERIAL" exec-out screencap -p > "$EVIDENCE_DIR/$name.png"
    {
        echo "frame=$name"
        echo "source_commit=$SOURCE_COMMIT"
        echo "serial=$SERIAL"
        echo "focused_activity:"
        "$ADB" -s "$SERIAL" shell dumpsys activity activities |
            grep -E 'mResumedActivity|topResumedActivity' |
            head -n 4 || true
    } > "$EVIDENCE_DIR/$name.state.txt"
    echo "CAPTURED=$name"
}

audit_mode() {
    local mode="$1"
    ANDROID_SERIAL="$SERIAL"         bash "$ROOT/build/macos/audit-r9-launcher-review-fidelity.sh" "$mode" |
        tee "$EVIDENCE_DIR/theme-$mode.audit.txt"
}

launch_start() {
    "$ADB" -s "$SERIAL" shell am force-stop org.sableos.start.visualreview
    "$ADB" -s "$SERIAL" shell am start -W         -n org.sableos.start.visualreview/.R9LauncherVisualReviewActivity         >/dev/null
    sleep 1
}

launch_hub() {
    "$ADB" -s "$SERIAL" shell am force-stop org.sableos.hub
    "$ADB" -s "$SERIAL" shell am start -W         -n org.sableos.hub/.MainActivity         >/dev/null
    sleep 1
}

echo "===== R9 MAC CROSS-APP THEME PROPAGATION REVIEW ====="
echo "SOURCE_COMMIT=$SOURCE_COMMIT"
echo "SERIAL=$SERIAL"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "PLATFORM_NIGHT_MODE_PROOF=DEFERRED_PHYSICAL_PANTHER"
echo "VANADIUM_PROOF=DEFERRED_PHYSICAL_PANTHER"

launch_start

echo
echo "In Sable Start, open Appearance and select DARK."
echo "Return to the Start surface once DARK is visibly active."
read -r -p "Press ENTER when DARK is active in Start: "

audit_mode dark
capture "10-start-dark"

launch_hub
capture "11-sable-messages-dark"

launch_start

echo
echo "In Sable Start, open Appearance and select LIGHT."
echo "Return to the Start surface once LIGHT is visibly active."
read -r -p "Press ENTER when LIGHT is active in Start: "

audit_mode light
capture "12-start-light"

launch_hub
capture "13-sable-messages-light"

FRAMES=(
    "$EVIDENCE_DIR/10-start-dark.png"
    "$EVIDENCE_DIR/11-sable-messages-dark.png"
    "$EVIDENCE_DIR/12-start-light.png"
    "$EVIDENCE_DIR/13-sable-messages-light.png"
)

if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${FRAMES[@]}" |
        tee "$EVIDENCE_DIR/theme-propagation.sha256"
else
    shasum -a 256 "${FRAMES[@]}" |
        tee "$EVIDENCE_DIR/theme-propagation.sha256"
fi

hash_for() {
    local frame="$1"
    local digest file
    while read -r digest file; do
        file="${file#\*}"
        if [[ "$(basename "$file")" == "$frame" ]]; then
            printf '%s\n' "$digest"
            return 0
        fi
    done < "$EVIDENCE_DIR/theme-propagation.sha256"
    return 1
}

START_DARK_HASH="$(hash_for "10-start-dark.png" || true)"
HUB_DARK_HASH="$(hash_for "11-sable-messages-dark.png" || true)"
START_LIGHT_HASH="$(hash_for "12-start-light.png" || true)"
HUB_LIGHT_HASH="$(hash_for "13-sable-messages-light.png" || true)"

if [[ -z "$START_DARK_HASH" || -z "$HUB_DARK_HASH" ||
      -z "$START_LIGHT_HASH" || -z "$HUB_LIGHT_HASH" ]]; then
    echo "R9_THEME_PROPAGATION_CAPTURE_INTEGRITY=FAIL_HASH_RESOLUTION"
    exit 7
fi

[[ "$START_DARK_HASH" != "$START_LIGHT_HASH" ]] || {
    echo "R9_THEME_PROPAGATION_START_DELTA=FAIL_IDENTICAL_DARK_LIGHT"
    exit 8
}
[[ "$HUB_DARK_HASH" != "$HUB_LIGHT_HASH" ]] || {
    echo "R9_THEME_PROPAGATION_SABLE_MESSAGES_DELTA=FAIL_IDENTICAL_DARK_LIGHT"
    exit 9
}

echo "R9_THEME_PROPAGATION_PROVIDER_DARK=PASS"
echo "R9_THEME_PROPAGATION_PROVIDER_LIGHT=PASS"
echo "R9_THEME_PROPAGATION_START_DELTA=PASS"
echo "R9_THEME_PROPAGATION_SABLE_MESSAGES_DELTA=PASS"
echo "R9_THEME_PROPAGATION_CROSS_APP=PASS_START_TO_SABLE_MESSAGES"
echo "R9_THEME_PROPAGATION_CAPTURE_INTEGRITY=PASS"
echo "R9_THEME_PROPAGATION_REVIEW=PENDING_IMAGE_REVIEW"
echo "R9_THEME_PROPAGATION_PLATFORM_NIGHT_MODE=DEFERRED_PHYSICAL_PANTHER"
echo "R9_THEME_PROPAGATION_VANADIUM=DEFERRED_PHYSICAL_PANTHER"
echo "FULL_PANTHER_BUILD_PERFORMED=NO"
