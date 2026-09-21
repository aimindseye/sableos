#!/usr/bin/env bash
set -euo pipefail

ADB="${ADB:-adb}"
SERIAL="${1:-${ANDROID_SERIAL:-}}"

adb_cmd() {
    if [[ -n "$SERIAL" ]]; then
        "$ADB" -s "$SERIAL" "$@"
    else
        "$ADB" "$@"
    fi
}

fail() {
    echo "$1=FAIL ${2:-}"
    exit 1
}

package_path() {
    adb_cmd shell pm path "$1" 2>/dev/null |
        tr -d '\r' |
        sed -n 's/^package://p' |
        head -n 1
}

echo "===== R9 FINAL UI RUNTIME AUDIT ====="
echo "DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY"
echo "PACKAGE_MUTATION_AUTHORIZED=NO"
echo "ROLE_MUTATION_AUTHORIZED=NO"
echo "THEME_MUTATION_AUTHORIZED=NO"

adb_cmd get-state >/dev/null ||
    fail R9_FINAL_UI_DEVICE_REACHABLE
echo "R9_FINAL_UI_DEVICE_REACHABLE=PASS"

VANADIUM_PATH="$(package_path app.vanadium.browser)"
[[ -n "$VANADIUM_PATH" ]] ||
    fail R9_FINAL_UI_VANADIUM_PACKAGE "missing=app.vanadium.browser"
echo "R9_FINAL_UI_VANADIUM_PACKAGE=PASS path=$VANADIUM_PATH"

GRAPHENE_MESSAGES_PATH="$(package_path com.android.messaging)"
[[ -n "$GRAPHENE_MESSAGES_PATH" ]] ||
    fail R9_FINAL_UI_GRAPHENE_MESSAGING_PACKAGE "missing=com.android.messaging"
echo "R9_FINAL_UI_GRAPHENE_MESSAGING_PACKAGE=PASS path=$GRAPHENE_MESSAGES_PATH"

SABLE_MESSAGES_PATH="$(package_path org.sableos.hub)"
[[ -n "$SABLE_MESSAGES_PATH" ]] ||
    fail R9_FINAL_UI_SABLE_MESSAGES_PACKAGE "missing=org.sableos.hub"
echo "R9_FINAL_UI_SABLE_MESSAGES_PACKAGE=PASS path=$SABLE_MESSAGES_PATH"

CHROME_PATH="$(package_path com.android.chrome)"
if [[ -n "$CHROME_PATH" ]]; then
    case "$CHROME_PATH" in
        /data/app/*)
            echo "R9_FINAL_UI_GOOGLE_CHROME_PRELOAD=PASS_NOT_SYSTEM path=$CHROME_PATH"
            ;;
        *)
            fail R9_FINAL_UI_GOOGLE_CHROME_PRELOAD "system_path=$CHROME_PATH"
            ;;
    esac
else
    echo "R9_FINAL_UI_GOOGLE_CHROME_PRELOAD=PASS_ABSENT"
fi

GOOGLE_MESSAGES_PATH="$(package_path com.google.android.apps.messaging)"
if [[ -n "$GOOGLE_MESSAGES_PATH" ]]; then
    case "$GOOGLE_MESSAGES_PATH" in
        /data/app/*)
            echo "R9_FINAL_UI_GOOGLE_MESSAGES_PRELOAD=PASS_NOT_SYSTEM path=$GOOGLE_MESSAGES_PATH"
            ;;
        *)
            fail R9_FINAL_UI_GOOGLE_MESSAGES_PRELOAD "system_path=$GOOGLE_MESSAGES_PATH"
            ;;
    esac
else
    echo "R9_FINAL_UI_GOOGLE_MESSAGES_PRELOAD=PASS_ABSENT"
fi

BROWSER_RESOLVED="$(
    adb_cmd shell cmd package resolve-activity --brief         -a android.intent.action.VIEW         -c android.intent.category.BROWSABLE         -d https://example.com 2>/dev/null |
        tr -d '\r' |
        tail -n 1
)"

printf '%s\n' "$BROWSER_RESOLVED" |
    grep -Fq 'app.vanadium.browser/' ||
    fail R9_FINAL_UI_DEFAULT_BROWSER "resolved=$BROWSER_RESOLVED"
echo "R9_FINAL_UI_DEFAULT_BROWSER=PASS_VANADIUM resolved=$BROWSER_RESOLVED"

SMS_ROLE="$(
    adb_cmd shell cmd role get-role-holders         android.app.role.SMS         --user 0 2>/dev/null |
        tr -d '\r'
)"

printf '%s\n' "$SMS_ROLE" |
    grep -Fxq 'com.android.messaging' ||
    fail R9_FINAL_UI_SMS_ROLE "holders=$SMS_ROLE"
echo "R9_FINAL_UI_SMS_ROLE=PASS_GRAPHENE_MESSAGING"

UI_MODE="$(
    adb_cmd shell cmd uimode night 2>/dev/null |
        tr -d '\r' |
        tail -n 1
)"
echo "R9_FINAL_UI_SYSTEM_NIGHT_MODE_STATE=$UI_MODE"

echo "R9_FINAL_UI_APPEARANCE_SABLE_APPS=PENDING_VISUAL_DEVICE_REVIEW"
echo "R9_FINAL_UI_APPEARANCE_PLATFORM_APPS=PENDING_VISUAL_DEVICE_REVIEW"
echo "R9_FINAL_UI_RUNTIME_IDENTITY_AUDIT=PASS"
