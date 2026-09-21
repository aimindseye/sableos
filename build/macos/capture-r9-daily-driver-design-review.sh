#!/usr/bin/env bash
set -euo pipefail

[[ "$(uname -s)" == "Darwin" ]] || {
    echo "R9_DAILY_DRIVER_VISUAL_REVIEW=FAIL_HOST_NOT_MACOS"
    exit 2
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
[[ -n "$SDK_ROOT" ]] || {
    echo "R9_DAILY_DRIVER_VISUAL_REVIEW=FAIL_ANDROID_SDK_UNSET"
    exit 3
}

ADB="$SDK_ROOT/platform-tools/adb"
[[ -x "$ADB" ]] || {
    echo "R9_DAILY_DRIVER_VISUAL_REVIEW=FAIL_ADB path=$ADB"
    exit 4
}

SERIAL="${ANDROID_SERIAL:-$("$ADB" devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')}"
[[ -n "$SERIAL" ]] || {
    echo "R9_DAILY_DRIVER_VISUAL_REVIEW=FAIL_NO_DEVICE"
    exit 5
}

ACTUAL_AVD="$("$ADB" -s "$SERIAL" emu avd name 2>/dev/null | tr -d '\r' | head -n 1 || true)"
if [[ "${ALLOW_NON_PIXEL7_AVD:-NO}" != "YES" ]]; then
    printf '%s' "$ACTUAL_AVD" | grep -Eiq 'pixel[_ -]?7|panther' || {
        echo "R9_DAILY_DRIVER_VISUAL_REVIEW=FAIL_NOT_PIXEL7_AVD actual=$ACTUAL_AVD"
        exit 6
    }
fi

SOURCE_COMMIT="$(git -C "$ROOT" rev-parse HEAD)"
RUN_ID="${SABLE_VISUAL_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)-$(printf '%s' "$SOURCE_COMMIT" | cut -c1-12)}"
EVIDENCE_ROOT="${SABLE_DAILY_DRIVER_EVIDENCE_ROOT:-$HOME/sableos-evidence/r9-daily-driver-design-review}"
EVIDENCE_DIR="$EVIDENCE_ROOT/$RUN_ID"
mkdir -p "$EVIDENCE_DIR"

exec > >(tee "$EVIDENCE_DIR/review.log") 2>&1

echo "===== R9 DAILY-DRIVER MAC VISUAL DESIGN REVIEW ====="
echo "SOURCE_COMMIT=$SOURCE_COMMIT"
echo "SERIAL=$SERIAL"
echo "AVD=$ACTUAL_AVD"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "PRODUCTION_SOURCE_MUTATION_AUTHORIZED=NO"
echo "PANTHER_PRODUCT_PLUMBING_AUTHORIZED=NO"
echo "FULL_PANTHER_BUILD_AUTHORIZED=NO"
echo "STATIC_FIXTURE_DATA=YES"

python3 "$ROOT/build/gates/r9-daily-driver-design-review-contract.py"

if [[ "${NETWORK_FETCH_AUTHORIZED:-NO}" == "YES" ]]; then
    GRADLE_OFFLINE=NO
else
    GRADLE_OFFLINE=YES
fi

set +e
(
    cd "$ROOT/apps/r8/android"
    if [[ "$GRADLE_OFFLINE" == "YES" ]]; then
        ./gradlew --offline \
            :sablestart-visual-review:assembleDebug \
            --stacktrace \
            --console=plain \
            --no-daemon
    else
        ./gradlew \
            :sablestart-visual-review:assembleDebug \
            --stacktrace \
            --console=plain \
            --no-daemon
    fi
) 2>&1 | tee "$EVIDENCE_DIR/gradle.log"
GRADLE_RC=${PIPESTATUS[0]}
set -e

[[ "$GRADLE_RC" -eq 0 ]] || {
    echo "R9_DAILY_DRIVER_VISUAL_REVIEW_GRADLE=FAIL rc=$GRADLE_RC"
    exit "$GRADLE_RC"
}

APK="$ROOT/apps/r8/android/sablestart-visual-review/build/outputs/apk/debug/sablestart-visual-review-debug.apk"
[[ -f "$APK" ]] || {
    echo "R9_DAILY_DRIVER_VISUAL_REVIEW=FAIL_APK_MISSING path=$APK"
    exit 7
}

"$ADB" -s "$SERIAL" install -r "$APK"

if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$APK" | tee "$EVIDENCE_DIR/review-apk.sha256"
else
    shasum -a 256 "$APK" | tee "$EVIDENCE_DIR/review-apk.sha256"
fi

FRAMES="
icons
start-dark
start-light
live
calendar
clock
camera
files
photos
browser
messages
"

INDEX=0
: > "$EVIDENCE_DIR/frames.tsv"
printf 'frame\tfile\tsha256\n' >> "$EVIDENCE_DIR/frames.tsv"

for FRAME in $FRAMES; do
    FILE="$(printf '%02d-%s.png' "$INDEX" "$FRAME")"
    DEST="$EVIDENCE_DIR/$FILE"

    "$ADB" -s "$SERIAL" shell am force-stop org.sableos.start.visualreview
    "$ADB" -s "$SERIAL" shell am start -W \
        -n org.sableos.start.visualreview/.R9DailyDriverDesignReviewActivity \
        --es frame "$FRAME" >/dev/null

    sleep 1
    "$ADB" -s "$SERIAL" exec-out screencap -p > "$DEST"

    if command -v sha256sum >/dev/null 2>&1; then
        DIGEST="$(sha256sum "$DEST" | awk '{print $1}')"
    else
        DIGEST="$(shasum -a 256 "$DEST" | awk '{print $1}')"
    fi

    printf '%s\t%s\t%s\n' "$FRAME" "$FILE" "$DIGEST" | tee -a "$EVIDENCE_DIR/frames.tsv"
    INDEX=$((INDEX + 1))
done

{
    echo "source_commit=$SOURCE_COMMIT"
    echo "serial=$SERIAL"
    echo "avd=$ACTUAL_AVD"
    echo "product=$("$ADB" -s "$SERIAL" shell getprop ro.product.name | tr -d '\r')"
    echo "model=$("$ADB" -s "$SERIAL" shell getprop ro.product.model | tr -d '\r')"
    echo "sdk=$("$ADB" -s "$SERIAL" shell getprop ro.build.version.sdk | tr -d '\r')"
    echo "release=$("$ADB" -s "$SERIAL" shell getprop ro.build.version.release | tr -d '\r')"
    echo "wm_size=$("$ADB" -s "$SERIAL" shell wm size | tr -d '\r')"
    echo "wm_density=$("$ADB" -s "$SERIAL" shell wm density | tr -d '\r')"
} > "$EVIDENCE_DIR/device.txt"

echo "R9_DAILY_DRIVER_REVIEW_FRAME_COUNT=$INDEX"
echo "R9_DAILY_DRIVER_ICON_SOURCE=PHOSPHOR_CORE_PINNED_MIT"
echo "R9_DAILY_DRIVER_STATIC_FIXTURES=PASS"
echo "R9_DAILY_DRIVER_PRODUCT_GRAPH_INCLUSION=NO"
echo "R9_DAILY_DRIVER_VISUAL_DESIGN=PENDING_USER_REVIEW"
echo "R9_DAILY_DRIVER_PRODUCTION_PLUMBING_AUTHORIZED=NO"
echo "NEXT_FULL_PANTHER_BUILD_AUTHORIZED=NO"
echo "R9_DAILY_DRIVER_VISUAL_REVIEW_CAPTURE=PASS"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
