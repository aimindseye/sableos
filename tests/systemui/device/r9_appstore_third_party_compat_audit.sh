#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

SERIAL="${SERIAL:-}"
ADB_BIN="${ADB_BIN:-adb}"
PHASE="${PHASE:-baseline}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="${EVIDENCE_DIR:-/srv/data/sable-build/evidence/panther/r9-physical/${STAMP}_appstore-${PHASE}}"

case "$PHASE" in
    baseline|play|providers) ;;
    *)
        echo "R9_APPSTORE_AUDIT=FAIL_PHASE value=$PHASE"
        exit 64
        ;;
esac

[[ -n "$SERIAL" ]] || {
    echo "R9_APPSTORE_AUDIT=FAIL_SERIAL_REQUIRED"
    exit 64
}

mkdir -p "$EVIDENCE_DIR"

adb_cmd() {
    "$ADB_BIN" -s "$SERIAL" "$@" </dev/null
}

fail() {
    echo "$1=FAIL"
    echo "R9_APPSTORE_AUDIT=FAIL"
    exit "${2:-1}"
}

package_present() {
    adb_cmd shell pm path "$1" 2>/dev/null | tr -d '\r' | grep -q '^package:'
}

require_package() {
    local package="$1"
    if ! package_present "$package"; then
        echo "R9_PACKAGE=FAIL_MISSING package=$package"
        fail R9_APPSTORE_REQUIRED_PACKAGE
    fi
    local version
    version="$(
        adb_cmd shell dumpsys package "$package" 2>/dev/null |
            tr -d '\r' |
            sed -n 's/^[[:space:]]*versionName=//p' |
            head -n1
    )"
    echo "R9_PACKAGE=PASS package=$package versionName=${version:-UNKNOWN}"
}

forbid_package() {
    local package="$1"
    if package_present "$package"; then
        echo "R9_PACKAGE=FAIL_UNEXPECTED package=$package"
        fail R9_APPSTORE_FORBIDDEN_PACKAGE
    fi
    echo "R9_PACKAGE=PASS_ABSENT package=$package"
}

echo "===== R9 PANTHER APPSTORE / THIRD-PARTY COMPATIBILITY AUDIT ====="
echo "DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY"
echo "DEVICE_MUTATION_AUTHORIZED=NO"
echo "APP_INSTALL_AUTHORIZED=NO"
echo "SETTINGS_MUTATION_AUTHORIZED=NO"
echo "PHASE=$PHASE"
echo "SERIAL=$SERIAL"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"

adb_cmd get-state | tee "$EVIDENCE_DIR/adb-state.txt"
[[ "$(tr -d '\r' < "$EVIDENCE_DIR/adb-state.txt")" == device ]] ||
    fail R9_APPSTORE_ADB_STATE 2

PRODUCT="$(adb_cmd shell getprop ro.product.device | tr -d '\r')"
echo "R9_DEVICE_PRODUCT=$PRODUCT"
[[ "$PRODUCT" == panther ]] || fail R9_APPSTORE_DEVICE_PRODUCT 2

require_package app.grapheneos.apps
echo "R9_APPSTORE_PACKAGE=PASS"

for package in     app.grapheneos.gmscompat     app.grapheneos.gmscompat.lib     app.grapheneos.gmscompat.config
do
    require_package "$package"
done
echo "R9_GMSCOMPAT_RUNTIME=PASS"

case "$PHASE" in
    baseline)
        for package in             com.android.vending             com.google.android.gms             com.google.android.gsf
        do
            forbid_package "$package"
        done
        echo "R9_GOOGLE_PLAY_RUNTIME=PASS_ABSENT_USER_OPTIONAL"
        ;;
    play|providers)
        for package in \
            com.android.vending \
            com.google.android.gms
        do
            require_package "$package"
        done
        forbid_package com.google.android.gsf
        echo "R9_GOOGLE_PLAY_RUNTIME=PASS_USER_INSTALLED_SANDBOXED_ANDROID15_PLUS_NO_GSF"
        ;;
esac

if [[ "$PHASE" == providers ]]; then
    for package in         com.whatsapp         org.thoughtcrime.securesms         org.telegram.messenger         com.linkedin.android
    do
        require_package "$package"
    done
    echo "R9_THIRD_PARTY_PROVIDER_INSTALLATION=PASS_FOUR_APP_SET"
fi

UI_MODE="$(
    adb_cmd shell cmd uimode night 2>/dev/null |
        tr -d '\r' |
        tail -n1
)"
echo "R9_SYSTEM_NIGHT_MODE_STATE=$UI_MODE"

ENABLED_NOTIFICATION_LISTENERS="$(
    adb_cmd shell settings get secure enabled_notification_listeners 2>/dev/null |
        tr -d '\r'
)"
printf '%s\n' "$ENABLED_NOTIFICATION_LISTENERS"     > "$EVIDENCE_DIR/enabled-notification-listeners.txt"

if grep -Fq     'org.sableos.hub/org.sableos.hub.notifications.SableNotificationListenerService'     <<<"$ENABLED_NOTIFICATION_LISTENERS"
then
    echo "R9_SABLE_MESSAGES_NOTIFICATION_ACCESS=PASS_USER_AUTHORIZED"
else
    echo "R9_SABLE_MESSAGES_NOTIFICATION_ACCESS=PENDING_USER_AUTHORIZATION"
fi

adb_cmd shell pm list packages -3 |
    tr -d '\r' |
    LC_ALL=C sort     > "$EVIDENCE_DIR/third-party-packages.txt"

{
    echo "PHASE=$PHASE"
    echo "DEVICE=$PRODUCT"
    echo "APPSTORE=app.grapheneos.apps"
    echo "UI_MODE=$UI_MODE"
    echo "AUDIT_TIME_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$EVIDENCE_DIR/summary.txt"

(
    cd "$EVIDENCE_DIR"
    find . -type f ! -name SHA256SUMS.txt -print0 |
        LC_ALL=C sort -z |
        xargs -0 sha256sum > SHA256SUMS.txt
)

echo "R9_APPSTORE_APPEARANCE=REQUIRES_PHYSICAL_LIGHT_DARK_REVIEW"
if [[ "$PHASE" == providers ]]; then
    echo "R9_THIRD_PARTY_APPEARANCE=REQUIRES_PHYSICAL_LIGHT_DARK_REVIEW"
    echo "R9_SABLE_MESSAGES_PROVIDER_CAPABILITY=REQUIRES_REAL_NOTIFICATION_REPLY_TEST"
fi
echo "R9_APPSTORE_AUDIT=PASS_READ_ONLY_RUNTIME_STATE"
echo "EVIDENCE_SEAL_SHA256=$(sha256sum "$EVIDENCE_DIR/SHA256SUMS.txt" | awk '{print $1}')"
