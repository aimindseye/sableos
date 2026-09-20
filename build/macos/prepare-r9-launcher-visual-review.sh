#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

[[ "$(uname -s)" == "Darwin" ]] || {
    echo "R9_VISUAL_REVIEW=FAIL_HOST_NOT_MACOS"
    exit 2
}

SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
[[ -n "$SDK_ROOT" ]] || {
    echo "R9_VISUAL_REVIEW=FAIL_ANDROID_SDK_UNSET"
    exit 3
}

ADB="$SDK_ROOT/platform-tools/adb"
EMULATOR="$SDK_ROOT/emulator/emulator"
[[ -x "$ADB" ]] || {
    echo "R9_VISUAL_REVIEW=FAIL_ADB path=$ADB"
    exit 4
}
[[ -x "$EMULATOR" ]] || {
    echo "R9_VISUAL_REVIEW=FAIL_EMULATOR path=$EMULATOR"
    exit 5
}

EVIDENCE_ROOT="${SABLE_VISUAL_EVIDENCE_ROOT:-$HOME/sableos-evidence/r9-launcher-visual-review}"
RUN_ID="${SABLE_VISUAL_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)-$(git -C "$ROOT" rev-parse --short=12 HEAD)}"
EVIDENCE_DIR="$EVIDENCE_ROOT/$RUN_ID"
mkdir -p "$EVIDENCE_DIR"

CACHE_DIR="$HOME/Library/Caches/sableos"
LAST_DIR_FILE="$CACHE_DIR/r9-launcher-visual-review-last-dir"
mkdir -p "$CACHE_DIR"

exec > >(tee "$EVIDENCE_DIR/prepare.log") 2>&1

echo "===== R9L9 MAC MINI / PIXEL 7 VISUAL REVIEW PREP ====="
echo "SOURCE_COMMIT=$(git -C "$ROOT" rev-parse HEAD)"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "NETWORK_FETCH_AUTHORIZED=${NETWORK_FETCH_AUTHORIZED:-NO}"
echo "FULL_PANTHER_BUILD_AUTHORIZED=NO"
echo "DEVICE_FLASH_AUTHORIZED=NO"
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
        echo "R9_VISUAL_REVIEW=FAIL_NO_PIXEL7_AVD"
        echo "Set AVD_NAME to the established Pixel 7 AVD on the Mac mini."
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
    echo "R9_VISUAL_REVIEW=FAIL_NO_DEVICE"
    exit 7
}

export ANDROID_SERIAL="$SERIAL"
ACTUAL_AVD="$("$ADB" -s "$SERIAL" emu avd name 2>/dev/null | tr -d '\r' | head -n 1 || true)"
echo "ANDROID_SERIAL=$SERIAL"
echo "ACTUAL_AVD=$ACTUAL_AVD"

if [[ "${ALLOW_NON_PIXEL7_AVD:-NO}" != "YES" ]]; then
    if ! printf '%s' "$ACTUAL_AVD" | grep -Eiq 'pixel[_ -]?7|panther'; then
        echo "R9_VISUAL_REVIEW=FAIL_NOT_PIXEL7_AVD actual=$ACTUAL_AVD"
        echo "Set ALLOW_NON_PIXEL7_AVD=YES only for an explicitly reviewed exception."
        exit 8
    fi
fi

if [[ "${NETWORK_FETCH_AUTHORIZED:-NO}" == "YES" ]]; then
    GRADLE_OFFLINE=NO
else
    GRADLE_OFFLINE=YES
fi

GRADLE_LOG="$EVIDENCE_DIR/gradle-visual-review.log"
set +e
(
    cd "$ROOT/apps/r8/android"

    if [[ "$GRADLE_OFFLINE" == "YES" ]]; then
        ./gradlew --offline \
            :sablestart-presentation-check:compileDebugKotlin \
            :sablestart-visual-review:assembleDebug \
            :sablestart-visual-review:lintDebug \
            --stacktrace \
            --console=plain \
            --no-daemon
    else
        ./gradlew \
            :sablestart-presentation-check:compileDebugKotlin \
            :sablestart-visual-review:assembleDebug \
            :sablestart-visual-review:lintDebug \
            --stacktrace \
            --console=plain \
            --no-daemon
    fi
) 2>&1 | tee "$GRADLE_LOG"
gradle_rc=${PIPESTATUS[0]}
set -e

if [[ "$gradle_rc" -ne 0 ]]; then
    if [[ "${NETWORK_FETCH_AUTHORIZED:-NO}" != "YES" ]] &&
        grep -Fq "No cached version of" "$GRADLE_LOG" &&
        grep -Fq "available for offline mode" "$GRADLE_LOG"; then
        echo "R9_VISUAL_REVIEW_DEPENDENCY_CACHE=MISS"
        echo "R9_VISUAL_REVIEW_NETWORK_BOOTSTRAP_REQUIRED=YES"
        echo "RETRY=NETWORK_FETCH_AUTHORIZED=YES bash build/macos/prepare-r9-launcher-visual-review.sh"
        exit 10
    fi

    if grep -Fq "Dependency verification failed" "$GRADLE_LOG"; then
        echo "R9_VISUAL_REVIEW_DEPENDENCY_VERIFICATION=FAIL"
        echo "R9_VISUAL_REVIEW_DEPENDENCY_VERIFICATION_ACTION=DO_NOT_DISABLE_VERIFICATION"
    fi

    echo "R9_VISUAL_REVIEW_GRADLE=FAIL rc=$gradle_rc log=$GRADLE_LOG"
    exit "$gradle_rc"
fi

echo "R9_VISUAL_REVIEW_DEPENDENCY_CACHE=READY"

APK="$ROOT/apps/r8/android/sablestart-visual-review/build/outputs/apk/debug/sablestart-visual-review-debug.apk"
[[ -f "$APK" ]] || {
    echo "R9_VISUAL_REVIEW=FAIL_APK_MISSING path=$APK"
    exit 9
}

if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$APK" | tee "$EVIDENCE_DIR/review-apk.sha256"
else
    shasum -a 256 "$APK" | tee "$EVIDENCE_DIR/review-apk.sha256"
fi

"$ADB" -s "$SERIAL" install -r "$APK"
"$ADB" -s "$SERIAL" shell am force-stop org.sableos.start.visualreview
"$ADB" -s "$SERIAL" shell am start -W     -n org.sableos.start.visualreview/.R9LauncherVisualReviewActivity

sleep 1

{
    echo "source_commit=$(git -C "$ROOT" rev-parse HEAD)"
    echo "serial=$SERIAL"
    echo "avd=$ACTUAL_AVD"
    echo "product=$("$ADB" -s "$SERIAL" shell getprop ro.product.name | tr -d '\r')"
    echo "model=$("$ADB" -s "$SERIAL" shell getprop ro.product.model | tr -d '\r')"
    echo "sdk=$("$ADB" -s "$SERIAL" shell getprop ro.build.version.sdk | tr -d '\r')"
    echo "release=$("$ADB" -s "$SERIAL" shell getprop ro.build.version.release | tr -d '\r')"
    echo "wm_size=$("$ADB" -s "$SERIAL" shell wm size | tr -d '\r')"
    echo "wm_density=$("$ADB" -s "$SERIAL" shell wm density | tr -d '\r')"
} | tee "$EVIDENCE_DIR/device.txt"

"$ADB" -s "$SERIAL" exec-out screencap -p > "$EVIDENCE_DIR/00-start-initial.png"

printf '%s\n' "$EVIDENCE_DIR" > "$LAST_DIR_FILE"

echo "R9_VISUAL_REVIEW_APK_BUILD=PASS"
echo "R9_VISUAL_REVIEW_PIXEL7_AVD=PASS"
echo "R9_VISUAL_REVIEW_INSTALL=PASS"
echo "R9_VISUAL_REVIEW_INITIAL_CAPTURE=PASS"
echo "R9_L6_VISUAL_REVIEW_STATUS=PENDING_USER_REVIEW"
echo "NEXT_FULL_PANTHER_BUILD_AUTHORIZED=NO"
echo
echo "Capture additional frames with:"
echo "  bash build/macos/capture-r9-launcher-visual-review.sh <frame-name>"
echo "Evidence:"
echo "  $EVIDENCE_DIR"
