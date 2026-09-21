#!/usr/bin/env bash
set -euo pipefail

[[ "$(uname -s)" == "Darwin" ]] || {
    echo "R9_VISUAL_FIDELITY_AUDIT=FAIL_HOST_NOT_MACOS"
    exit 2
}

EXPECTED_MODE="${1:-}"
case "$EXPECTED_MODE" in
    ""|follow-system|light|dark) ;;
    *)
        echo "usage: bash build/macos/audit-r9-launcher-review-fidelity.sh [follow-system|light|dark]" >&2
        exit 64
        ;;
esac

SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
[[ -n "$SDK_ROOT" ]] || {
    echo "R9_VISUAL_FIDELITY_AUDIT=FAIL_ANDROID_SDK_UNSET"
    exit 3
}

ADB="$SDK_ROOT/platform-tools/adb"
[[ -x "$ADB" ]] || {
    echo "R9_VISUAL_FIDELITY_AUDIT=FAIL_ADB path=$ADB"
    exit 4
}

SERIAL="${ANDROID_SERIAL:-$("$ADB" devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')}"
[[ -n "$SERIAL" ]] || {
    echo "R9_VISUAL_FIDELITY_AUDIT=FAIL_NO_DEVICE"
    exit 5
}

provider_row="$(
    "$ADB" -s "$SERIAL" shell content query         --uri content://org.sableos.start.appearance/appearance 2>/dev/null |
        tr -d '\r'
)"

[[ -n "$provider_row" ]] || {
    echo "R9_VISUAL_FIDELITY_APPEARANCE_PROVIDER=FAIL_EMPTY"
    exit 6
}

echo "R9_VISUAL_FIDELITY_APPEARANCE_PROVIDER=PASS"
echo "R9_VISUAL_FIDELITY_APPEARANCE_ROW=$provider_row"

if [[ -n "$EXPECTED_MODE" ]]; then
    printf '%s\n' "$provider_row" |
        grep -Fq "mode=$EXPECTED_MODE" || {
            echo "R9_VISUAL_FIDELITY_EXPECTED_MODE=FAIL expected=$EXPECTED_MODE row=$provider_row"
            exit 7
        }
    echo "R9_VISUAL_FIDELITY_EXPECTED_MODE=PASS value=$EXPECTED_MODE"
else
    echo "R9_VISUAL_FIDELITY_EXPECTED_MODE=NOT_ASSERTED"
fi

chrome_path="$(
    "$ADB" -s "$SERIAL" shell pm path com.android.chrome 2>/dev/null |
        tr -d '\r' |
        head -n 1 || true
)"
google_messages_path="$(
    "$ADB" -s "$SERIAL" shell pm path com.google.android.apps.messaging 2>/dev/null |
        tr -d '\r' |
        head -n 1 || true
)"
vanadium_path="$(
    "$ADB" -s "$SERIAL" shell pm path app.vanadium.browser 2>/dev/null |
        tr -d '\r' |
        head -n 1 || true
)"

echo "R9_VISUAL_FIDELITY_BROWSER_IDENTITY=HOST_AVD_NONAUTHORITATIVE"
if [[ -n "$chrome_path" ]]; then
    echo "R9_VISUAL_FIDELITY_HOST_CHROME=DETECTED_FILTERED"
else
    echo "R9_VISUAL_FIDELITY_HOST_CHROME=ABSENT"
fi
if [[ -n "$google_messages_path" ]]; then
    echo "R9_VISUAL_FIDELITY_HOST_GOOGLE_MESSAGES=DETECTED_FILTERED"
else
    echo "R9_VISUAL_FIDELITY_HOST_GOOGLE_MESSAGES=ABSENT"
fi
if [[ -n "$vanadium_path" ]]; then
    echo "R9_VISUAL_FIDELITY_HOST_VANADIUM=DETECTED_NONAUTHORITATIVE"
else
    echo "R9_VISUAL_FIDELITY_HOST_VANADIUM=ABSENT_EXPECTED"
fi

ui_mode="$(
    "$ADB" -s "$SERIAL" shell cmd uimode night 2>/dev/null |
        tr -d '\r' |
        tail -n 1 || true
)"
echo "R9_VISUAL_FIDELITY_HOST_SYSTEM_NIGHT_MODE=$ui_mode"
echo "R9_VISUAL_FIDELITY_PLATFORM_NIGHT_MODE_PROOF=DEFERRED_PHYSICAL_PANTHER"
echo "R9_VISUAL_FIDELITY_VANADIUM_PROOF=DEFERRED_PHYSICAL_PANTHER"
echo "R9_VISUAL_FIDELITY_AUDIT=PASS"
