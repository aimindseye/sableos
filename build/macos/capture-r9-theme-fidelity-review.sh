#!/usr/bin/env bash
set -euo pipefail

[[ "$(uname -s)" == "Darwin" ]] || {
    echo "R9_THEME_FIDELITY_CAPTURE=FAIL_HOST_NOT_MACOS"
    exit 2
}

MODE="${1:-}"
case "$MODE" in
    light|dark) ;;
    *)
        echo "usage: bash build/macos/capture-r9-theme-fidelity-review.sh <light|dark> [evidence-dir]" >&2
        exit 64
        ;;
esac

SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
[[ -n "$SDK_ROOT" ]] || {
    echo "R9_THEME_FIDELITY_CAPTURE=FAIL_ANDROID_SDK_UNSET"
    exit 3
}

ADB="$SDK_ROOT/platform-tools/adb"
[[ -x "$ADB" ]] || {
    echo "R9_THEME_FIDELITY_CAPTURE=FAIL_ADB path=$ADB"
    exit 4
}

LAST_DIR_FILE="$HOME/Library/Caches/sableos/r9-launcher-visual-review-last-dir"
EVIDENCE_DIR="${2:-}"
if [[ -z "$EVIDENCE_DIR" && -f "$LAST_DIR_FILE" ]]; then
    EVIDENCE_DIR="$(cat "$LAST_DIR_FILE")"
fi
[[ -n "$EVIDENCE_DIR" && -d "$EVIDENCE_DIR" ]] || {
    echo "R9_THEME_FIDELITY_CAPTURE=FAIL_EVIDENCE_DIR"
    exit 5
}

SERIAL="${ANDROID_SERIAL:-$("$ADB" devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')}"
[[ -n "$SERIAL" ]] || {
    echo "R9_THEME_FIDELITY_CAPTURE=FAIL_NO_DEVICE"
    exit 6
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "===== R9 SABLE APP THEME FIDELITY CAPTURE ====="
echo "SOURCE_COMMIT=$(git -C "$ROOT" rev-parse HEAD)"
echo "EXPECTED_MODE=$MODE"
echo "SERIAL=$SERIAL"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "PLATFORM_NIGHT_MODE_PROOF=DEFERRED_PHYSICAL_PANTHER"
echo "VANADIUM_PROOF=DEFERRED_PHYSICAL_PANTHER"

bash "$ROOT/build/macos/audit-r9-launcher-review-fidelity.sh" "$MODE"

"$ADB" -s "$SERIAL" shell am force-stop org.sableos.start.visualreview
"$ADB" -s "$SERIAL" shell am start -W \
    -n org.sableos.start.visualreview/.R9LauncherVisualReviewActivity \
    --es appearanceMode "$MODE" >/dev/null
sleep 1

START_PNG="$EVIDENCE_DIR/04-theme-$MODE-start.png"
"$ADB" -s "$SERIAL" exec-out screencap -p > "$START_PNG"

"$ADB" -s "$SERIAL" shell am force-stop org.sableos.hub
"$ADB" -s "$SERIAL" shell am start -W     -n org.sableos.hub/.MainActivity >/dev/null
sleep 1

HUB_PNG="$EVIDENCE_DIR/05-theme-$MODE-sable-messages.png"
"$ADB" -s "$SERIAL" exec-out screencap -p > "$HUB_PNG"

{
    echo "mode=$MODE"
    echo "source_commit=$(git -C "$ROOT" rev-parse HEAD)"
    echo "serial=$SERIAL"
    echo "start_png=$START_PNG"
    echo "hub_png=$HUB_PNG"
    echo "review_mode=$MODE"
    echo "appearance_provider=RETIRED_SYSTEM_AUTHORITY_PHYSICAL_ONLY"
} > "$EVIDENCE_DIR/theme-$MODE-fidelity.state.txt"

if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$START_PNG" "$HUB_PNG" |
        tee "$EVIDENCE_DIR/theme-$MODE-fidelity.sha256"
else
    shasum -a 256 "$START_PNG" "$HUB_PNG" |
        tee "$EVIDENCE_DIR/theme-$MODE-fidelity.sha256"
fi

echo "R9_THEME_FIDELITY_REVIEW_MODE=PASS_LOCAL_DESIGN_HOST value=$MODE"
echo "R9_THEME_FIDELITY_PROVIDER_MODE=RETIRED_SYSTEM_AUTHORITY_PHYSICAL_ONLY"
echo "R9_THEME_FIDELITY_START_CAPTURE=PASS"
echo "R9_THEME_FIDELITY_SABLE_MESSAGES_CAPTURE=PASS"
echo "R9_THEME_FIDELITY_CROSS_APP_VISUAL_REVIEW=PENDING_USER_REVIEW"
echo "R9_THEME_FIDELITY_PLATFORM_NIGHT_MODE=DEFERRED_PHYSICAL_PANTHER"
echo "R9_THEME_FIDELITY_VANADIUM=DEFERRED_PHYSICAL_PANTHER"
echo "R9_THEME_FIDELITY_CAPTURE=PASS"
