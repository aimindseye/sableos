#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

[[ "$(uname -s)" == "Darwin" ]] || {
    echo "R9_PHONE_CONTACTS_VISUAL=FAIL_HOST_NOT_MACOS"
    exit 2
}

SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
[[ -n "$SDK_ROOT" ]] || {
    echo "R9_PHONE_CONTACTS_VISUAL=FAIL_ANDROID_SDK_UNSET"
    exit 3
}

ADB="$SDK_ROOT/platform-tools/adb"
EMULATOR="$SDK_ROOT/emulator/emulator"

[[ -x "$ADB" ]] || {
    echo "R9_PHONE_CONTACTS_VISUAL=FAIL_ADB path=$ADB"
    exit 4
}

[[ -x "$EMULATOR" ]] || {
    echo "R9_PHONE_CONTACTS_VISUAL=FAIL_EMULATOR path=$EMULATOR"
    exit 5
}

python3 "$ROOT/build/gates/r9-phone-contacts-visual-review-contract.py"

EVIDENCE_ROOT="${SABLE_VISUAL_EVIDENCE_ROOT:-$HOME/sableos-evidence/r9-phone-contacts-visual-review}"
RUN_ID="${SABLE_VISUAL_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)-$(git -C "$ROOT" rev-parse --short=12 HEAD)}"
EVIDENCE_DIR="$EVIDENCE_ROOT/$RUN_ID"
mkdir -p "$EVIDENCE_DIR"

CACHE_DIR="$HOME/Library/Caches/sableos"
LAST_DIR_FILE="$CACHE_DIR/r9-phone-contacts-visual-review-last-dir"
mkdir -p "$CACHE_DIR"

exec > >(tee "$EVIDENCE_DIR/prepare.log") 2>&1

echo "===== R9 PHONE + CONTACTS MAC VISUAL REVIEW ====="
echo "SOURCE_COMMIT=$(git -C "$ROOT" rev-parse HEAD)"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "NETWORK_FETCH_AUTHORIZED=${NETWORK_FETCH_AUTHORIZED:-NO}"
echo "PLATFORM_SOURCE_MUTATION_AUTHORIZED=NO"
echo "FULL_PANTHER_BUILD_AUTHORIZED=NO"
echo "REVIEW_APK_PRODUCT_INCLUSION=NO"

"$ADB" start-server >/dev/null

select_serial() {
    if [[ -n "${ANDROID_SERIAL:-}" ]]; then
        printf '%s\n' "$ANDROID_SERIAL"
        return
    fi

    "$ADB" devices |
        awk 'NR > 1 && $2 == "device" { print $1; exit }'
}

SERIAL="$(select_serial)"

if [[ -z "$SERIAL" ]]; then
    AVD_NAME="${AVD_NAME:-}"
    if [[ -z "$AVD_NAME" ]]; then
        AVD_NAME="$(
            "$EMULATOR" -list-avds |
                grep -Ei 'pixel[_ -]?7|panther' |
                head -n 1 || true
        )"
    fi

    [[ -n "$AVD_NAME" ]] || {
        echo "R9_PHONE_CONTACTS_VISUAL=FAIL_NO_PIXEL7_AVD"
        "$EMULATOR" -list-avds || true
        exit 6
    }

    echo "STARTING_AVD=$AVD_NAME"
    nohup "$EMULATOR"         -avd "$AVD_NAME"         -no-boot-anim         -no-snapshot-save         > "$EVIDENCE_DIR/emulator.log" 2>&1 &

    "$ADB" wait-for-device
    attempt=0
    while (( attempt < 180 )); do
        SERIAL="$(select_serial)"
        if [[ -n "$SERIAL" ]] &&
            [[ "$("$ADB" -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]; then
            break
        fi
        attempt=$((attempt + 1))
        sleep 1
    done
fi

[[ -n "$SERIAL" ]] || {
    echo "R9_PHONE_CONTACTS_VISUAL=FAIL_NO_DEVICE"
    exit 7
}

export ANDROID_SERIAL="$SERIAL"
ACTUAL_AVD="$("$ADB" -s "$SERIAL" emu avd name 2>/dev/null | tr -d '\r' | head -n 1 || true)"

echo "ANDROID_SERIAL=$SERIAL"
echo "ACTUAL_AVD=$ACTUAL_AVD"

if [[ "${ALLOW_NON_PIXEL7_AVD:-NO}" != "YES" ]]; then
    if ! printf '%s' "$ACTUAL_AVD" | grep -Eiq 'pixel[_ -]?7|panther'; then
        echo "R9_PHONE_CONTACTS_VISUAL=FAIL_NOT_PIXEL7_AVD actual=$ACTUAL_AVD"
        exit 8
    fi
fi

GRADLE_LOG="$EVIDENCE_DIR/gradle-phone-contacts-review.log"

set +e
(
    cd "$ROOT/apps/r8/android"
    if [[ "${NETWORK_FETCH_AUTHORIZED:-NO}" == "YES" ]]; then
        ./gradlew             :phone-contacts-visual-review:assembleDebug             --stacktrace             --console=plain             --no-daemon
    else
        ./gradlew --offline             :phone-contacts-visual-review:assembleDebug             --stacktrace             --console=plain             --no-daemon
    fi
) 2>&1 | tee "$GRADLE_LOG"
gradle_rc=${PIPESTATUS[0]}
set -e

if [[ "$gradle_rc" -ne 0 ]]; then
    if [[ "${NETWORK_FETCH_AUTHORIZED:-NO}" != "YES" ]] &&
        grep -Fq "No cached version of" "$GRADLE_LOG" &&
        grep -Fq "available for offline mode" "$GRADLE_LOG"; then
        echo "R9_PHONE_CONTACTS_VISUAL_DEPENDENCY_CACHE=MISS"
        echo "RETRY=NETWORK_FETCH_AUTHORIZED=YES bash build/macos/prepare-r9-phone-contacts-visual-review.sh"
        exit 10
    fi

    echo "R9_PHONE_CONTACTS_VISUAL_GRADLE=FAIL rc=$gradle_rc log=$GRADLE_LOG"
    exit "$gradle_rc"
fi

APK="$ROOT/apps/r8/android/phone-contacts-visual-review/build/outputs/apk/debug/phone-contacts-visual-review-debug.apk"
[[ -f "$APK" ]] || {
    echo "R9_PHONE_CONTACTS_VISUAL=FAIL_APK_MISSING path=$APK"
    exit 9
}

if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$APK" | tee "$EVIDENCE_DIR/review-apk.sha256"
else
    shasum -a 256 "$APK" | tee "$EVIDENCE_DIR/review-apk.sha256"
fi

"$ADB" -s "$SERIAL" install -r "$APK"

PACKAGE="org.sableos.phonecontacts.visualreview"
COMPONENT="$PACKAGE/.PhoneContactsVisualReviewActivity"

capture_frame() {
    local frame="$1"
    local app="$2"
    local surface="$3"
    local dark="$4"

    echo
    echo "===== CAPTURE $frame ====="

    "$ADB" -s "$SERIAL" shell am force-stop "$PACKAGE"
    "$ADB" -s "$SERIAL" shell am start -W         -n "$COMPONENT"         --es app "$app"         --es surface "$surface"         --ez dark "$dark"

    sleep 1

    "$ADB" -s "$SERIAL" exec-out screencap -p > "$EVIDENCE_DIR/$frame.png"

    {
        echo "frame=$frame"
        echo "app=$app"
        echo "surface=$surface"
        echo "dark=$dark"
        echo "focused_activity:"
        "$ADB" -s "$SERIAL" shell dumpsys activity activities |
            grep -E 'mResumedActivity|topResumedActivity' |
            head -n 4 || true
    } > "$EVIDENCE_DIR/$frame.state.txt"
}

capture_frame 00-phone-recents-light phone recents false
capture_frame 01-phone-dialpad-light phone dialpad false
capture_frame 02-phone-in-call-light phone in-call false
capture_frame 03-contacts-list-light contacts list false
capture_frame 04-contact-detail-light contacts detail false
capture_frame 05-phone-recents-dark phone recents true
capture_frame 06-contacts-list-dark contacts list true

{
    echo "source_commit=$(git -C "$ROOT" rev-parse HEAD)"
    echo "serial=$SERIAL"
    echo "avd=$ACTUAL_AVD"
    echo "sdk=$("$ADB" -s "$SERIAL" shell getprop ro.build.version.sdk | tr -d '\r')"
    echo "release=$("$ADB" -s "$SERIAL" shell getprop ro.build.version.release | tr -d '\r')"
    echo "wm_size=$("$ADB" -s "$SERIAL" shell wm size | tr -d '\r')"
    echo "wm_density=$("$ADB" -s "$SERIAL" shell wm density | tr -d '\r')"
} | tee "$EVIDENCE_DIR/device.txt"

if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$EVIDENCE_DIR"/*.png | tee "$EVIDENCE_DIR/screenshots.sha256"
else
    shasum -a 256 "$EVIDENCE_DIR"/*.png | tee "$EVIDENCE_DIR/screenshots.sha256"
fi

printf '%s\n' "$EVIDENCE_DIR" > "$LAST_DIR_FILE"

echo
echo "R9_PHONE_CONTACTS_VISUAL_APK_BUILD=PASS"
echo "R9_PHONE_CONTACTS_VISUAL_PIXEL7_AVD=PASS"
echo "R9_PHONE_CONTACTS_VISUAL_INSTALL=PASS"
echo "R9_PHONE_CONTACTS_VISUAL_CAPTURE_SET=PASS"
echo "R9_PHONE_CONTACTS_VISUAL_REVIEW_STATUS=PENDING_USER_REVIEW"
echo "PLATFORM_SOURCE_MUTATION_PERFORMED=NO"
echo "FULL_PANTHER_BUILD_PERFORMED=NO"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
