#!/usr/bin/env bash
set -euo pipefail

[[ "$(uname -s)" == "Darwin" ]] || {
    echo "R9_VISUAL_CAPTURE=FAIL_HOST_NOT_MACOS"
    exit 2
}

FRAME="${1:-}"
[[ -n "$FRAME" ]] || {
    echo "usage: bash build/macos/capture-r9-launcher-visual-review.sh <frame-name> [evidence-dir]" >&2
    exit 64
}

SAFE_FRAME="$(printf '%s' "$FRAME" | tr -cs 'A-Za-z0-9._-' '-' | sed 's/^-//; s/-$//')"
[[ -n "$SAFE_FRAME" ]] || {
    echo "R9_VISUAL_CAPTURE=FAIL_FRAME_NAME"
    exit 3
}

SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
[[ -n "$SDK_ROOT" ]] || {
    echo "R9_VISUAL_CAPTURE=FAIL_ANDROID_SDK_UNSET"
    exit 4
}

ADB="$SDK_ROOT/platform-tools/adb"
[[ -x "$ADB" ]] || {
    echo "R9_VISUAL_CAPTURE=FAIL_ADB path=$ADB"
    exit 5
}

LAST_DIR_FILE="$HOME/Library/Caches/sableos/r9-launcher-visual-review-last-dir"
EVIDENCE_DIR="${2:-}"
if [[ -z "$EVIDENCE_DIR" && -f "$LAST_DIR_FILE" ]]; then
    EVIDENCE_DIR="$(cat "$LAST_DIR_FILE")"
fi
[[ -n "$EVIDENCE_DIR" && -d "$EVIDENCE_DIR" ]] || {
    echo "R9_VISUAL_CAPTURE=FAIL_EVIDENCE_DIR"
    exit 6
}

SERIAL="${ANDROID_SERIAL:-$("$ADB" devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')}"
[[ -n "$SERIAL" ]] || {
    echo "R9_VISUAL_CAPTURE=FAIL_NO_DEVICE"
    exit 7
}

PNG="$EVIDENCE_DIR/$SAFE_FRAME.png"
STATE="$EVIDENCE_DIR/$SAFE_FRAME.state.txt"

"$ADB" -s "$SERIAL" exec-out screencap -p > "$PNG"

{
    echo "frame=$SAFE_FRAME"
    echo "serial=$SERIAL"
    echo "avd=$("$ADB" -s "$SERIAL" emu avd name 2>/dev/null | tr -d '\r' | head -n 1 || true)"
    echo "focused_activity:"
    "$ADB" -s "$SERIAL" shell dumpsys activity activities |
        grep -E 'mResumedActivity|topResumedActivity' |
        head -n 4 || true
} > "$STATE"

if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$PNG" | tee "$PNG.sha256"
else
    shasum -a 256 "$PNG" | tee "$PNG.sha256"
fi

echo "R9_VISUAL_CAPTURE=PASS frame=$SAFE_FRAME"
echo "PNG=$PNG"
echo "STATE=$STATE"
