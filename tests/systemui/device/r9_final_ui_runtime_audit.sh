#!/usr/bin/env bash
# Operator safety: this script must execute in a child Bash process. Refuse
# sourcing before changing shell options so an audit failure cannot terminate
# or alter the caller's interactive SSH shell.
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    echo "R9_RUNTIME_AUDIT=REFUSED_SOURCED_SCRIPT" >&2
    echo "Run with: bash ${BASH_SOURCE[0]} [serial]" >&2
    return 64
fi

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
    local raw
    raw="$(adb_cmd shell pm path "$1" 2>/dev/null || true)"
    awk '
        /^package:/ {
            sub(/^package:/, "")
            print
            exit
        }
    ' <<<"$raw"
}

assert_preload_absent() {
    local marker="$1"
    local package="$2"
    local path

    path="$(package_path "$package")"
    if [[ -n "$path" ]]; then
        case "$path" in
            /data/app/*)
                echo "$marker=PASS_NOT_SYSTEM path=$path"
                ;;
            *)
                fail "$marker" "system_path=$path"
                ;;
        esac
    else
        echo "$marker=PASS_ABSENT"
    fi
}

echo "===== R9 FINAL UI RUNTIME AUDIT ====="
echo "DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY"
echo "PACKAGE_MUTATION_AUTHORIZED=NO"
echo "ROLE_MUTATION_AUTHORIZED=NO"
echo "THEME_MUTATION_AUTHORIZED=NO"
echo "OPERATOR_PARENT_SHELL_MUTATION=NO"

adb_cmd get-state >/dev/null ||
    fail R9_FINAL_UI_DEVICE_REACHABLE
echo "R9_FINAL_UI_DEVICE_REACHABLE=PASS"

PRODUCT="$(adb_cmd shell getprop ro.product.device | tr -d '\r')"
SLOT_SUFFIX="$(adb_cmd shell getprop ro.boot.slot_suffix | tr -d '\r')"
BOOT_COMPLETED="$(adb_cmd shell getprop sys.boot_completed | tr -d '\r')"
FINGERPRINT="$(adb_cmd shell getprop ro.build.fingerprint | tr -d '\r')"
BUILD_ID="$(adb_cmd shell getprop ro.build.id | tr -d '\r')"
VERIFIED_BOOT="$(adb_cmd shell getprop ro.boot.verifiedbootstate | tr -d '\r')"
VBMETA_STATE="$(adb_cmd shell getprop ro.boot.vbmeta.device_state | tr -d '\r')"

[[ "$PRODUCT" == panther ]] ||
    fail R9_FINAL_UI_DEVICE_PRODUCT "actual=$PRODUCT"
[[ "$SLOT_SUFFIX" =~ ^_[ab]$ ]] ||
    fail R9_FINAL_UI_SLOT "actual=$SLOT_SUFFIX"
[[ "$BOOT_COMPLETED" == 1 ]] ||
    fail R9_FINAL_UI_BOOT_COMPLETED "actual=$BOOT_COMPLETED"

echo "R9_FINAL_UI_DEVICE_PRODUCT=PASS value=$PRODUCT"
echo "R9_FINAL_UI_SLOT=PASS value=$SLOT_SUFFIX"
echo "R9_FINAL_UI_BOOT_COMPLETED=PASS"
echo "R9_FINAL_UI_BUILD_ID=$BUILD_ID"
echo "R9_FINAL_UI_BUILD_FINGERPRINT=$FINGERPRINT"
echo "R9_FINAL_UI_VERIFIED_BOOT_STATE=$VERIFIED_BOOT"
echo "R9_FINAL_UI_VBMETA_DEVICE_STATE=$VBMETA_STATE"

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

SABLE_CALENDAR_PATH="$(package_path org.sableos.calendar)"
[[ -n "$SABLE_CALENDAR_PATH" ]] ||
    fail R9_FINAL_UI_SABLE_CALENDAR_PACKAGE "missing=org.sableos.calendar"
echo "R9_FINAL_UI_SABLE_CALENDAR_PACKAGE=PASS path=$SABLE_CALENDAR_PATH"

assert_preload_absent     R9_FINAL_UI_GOOGLE_CHROME_PRELOAD     com.android.chrome

assert_preload_absent     R9_FINAL_UI_GOOGLE_MESSAGES_PRELOAD     com.google.android.apps.messaging

assert_preload_absent     R9_FINAL_UI_PLATFORM_CALENDAR_PRELOAD     com.android.calendar

BROWSER_RAW="$(
    adb_cmd shell cmd package resolve-activity --brief         -a android.intent.action.VIEW         -c android.intent.category.BROWSABLE         -d https://example.com 2>/dev/null || true
)"
BROWSER_RESOLVED="$(tail -n1 <<<"$BROWSER_RAW" | tr -d '\r')"

grep -Fq 'app.vanadium.browser/' <<<"$BROWSER_RESOLVED" ||
    fail R9_FINAL_UI_DEFAULT_BROWSER "resolved=$BROWSER_RESOLVED"
echo "R9_FINAL_UI_DEFAULT_BROWSER=PASS_VANADIUM resolved=$BROWSER_RESOLVED"

SMS_ROLE="$(
    adb_cmd shell cmd role get-role-holders         --user 0         android.app.role.SMS 2>/dev/null |
        tr -d '\r'
)"

grep -Fxq 'com.android.messaging' <<<"$SMS_ROLE" ||
    fail R9_FINAL_UI_SMS_ROLE "holders=$SMS_ROLE"
echo "R9_FINAL_UI_SMS_ROLE=PASS_GRAPHENE_MESSAGING"

HUB_DUMP="$(adb_cmd shell pm dump org.sableos.hub 2>/dev/null || true)"
capsules=(
    .web.WhatsAppCapsuleActivity
    .web.InstagramCapsuleActivity
    .web.MessengerCapsuleActivity
    .web.LinkedInCapsuleActivity
)

capsule_count=0
for capsule in "${capsules[@]}"; do
    if grep -Fq "$capsule" <<<"$HUB_DUMP"; then
        echo "R9_FINAL_UI_PROVIDER_CAPSULE=PASS component=$capsule"
        ((capsule_count+=1))
    else
        fail R9_FINAL_UI_PROVIDER_CAPSULE "missing=$capsule"
    fi
done

[[ "$capsule_count" -eq 4 ]] ||
    fail R9_FINAL_UI_PROVIDER_CAPSULES "count=$capsule_count"
echo "R9_FINAL_UI_PROVIDER_CAPSULES=PASS_4"

echo
echo "===== LIVE PROVIDER UNRELATED-CALLER NEGATIVE PROBE ====="

provider_specs=(
    "org.sableos.weather:org.sableos.weather.snapshot"
    "org.sableos.calendar:org.sableos.calendar.snapshot"
    "org.sableos.hub:org.sableos.hub.snapshot"
    "org.sableos.mail:org.sableos.mail.snapshot"
    "org.sableos.media:org.sableos.media.snapshot"
)

provider_boundary_count=0

for spec in "${provider_specs[@]}"; do
    package="${spec%%:*}"
    authority="${spec#*:}"

    pkg_dump="$(adb_cmd shell pm dump "$package" 2>/dev/null || true)"
    grep -Fq "$authority" <<<"$pkg_dump" ||
        fail R9_FINAL_UI_LIVE_PROVIDER_REGISTERED             "package=$package authority=$authority"

    set +e
    probe="$(
        adb_cmd shell content query             --uri "content://$authority/current"             2>&1
    )"
    probe_rc=$?
    set -e

    if grep -Eq         'SecurityException|Permission Denial|No result found'         <<<"$probe"
    then
        echo "R9_FINAL_UI_LIVE_PROVIDER_SHELL_REJECT=PASS authority=$authority rc=$probe_rc"
        ((provider_boundary_count+=1))
        continue
    fi

    if [[ "$probe_rc" -ne 0 ]] &&
       ! grep -Eq            'No content provider found|Unknown URI|Unknown authority'            <<<"$probe"
    then
        echo "R9_FINAL_UI_LIVE_PROVIDER_SHELL_REJECT=PASS authority=$authority rc=$probe_rc"
        ((provider_boundary_count+=1))
        continue
    fi

    echo "R9_FINAL_UI_LIVE_PROVIDER_PROBE_OUTPUT authority=$authority"
    printf '%s\n' "$probe"
    fail R9_FINAL_UI_LIVE_PROVIDER_CALLER_BOUNDARY         "authority=$authority unexpectedly-readable-or-unregistered"
done

[[ "$provider_boundary_count" -eq 5 ]] ||
    fail R9_FINAL_UI_LIVE_PROVIDER_CALLER_BOUNDARY         "protected=$provider_boundary_count expected=5"

echo "R9_FINAL_UI_LIVE_PROVIDER_CALLER_BOUNDARY=PASS"

UI_MODE="$(
    adb_cmd shell cmd uimode night 2>/dev/null |
        tr -d '\r' |
        tail -n 1
)"
echo "R9_FINAL_UI_SYSTEM_NIGHT_MODE_STATE=$UI_MODE"

echo "R9_FINAL_UI_APPEARANCE_SABLE_APPS=PENDING_VISUAL_DEVICE_REVIEW"
echo "R9_FINAL_UI_APPEARANCE_PLATFORM_APPS=PENDING_VISUAL_DEVICE_REVIEW"
echo "R9_FINAL_UI_ALL_APPS_PERMISSION_SUMMARIES=PENDING_VISUAL_DEVICE_REVIEW"
echo "R9_FINAL_UI_RUNTIME_IDENTITY_AUDIT=PASS"
