#!/usr/bin/env bash
set -euo pipefail

DEVICE_CONTACT_AUTHORIZED="${DEVICE_CONTACT_AUTHORIZED:-NO}"
if [[ "$DEVICE_CONTACT_AUTHORIZED" != YES ]]; then
    echo "Refusing device contact. Set DEVICE_CONTACT_AUTHORIZED=YES explicitly."
    exit 2
fi

ADB="${ADB:-adb}"
command -v "$ADB" >/dev/null

EVIDENCE_DIR="${SABLEOS_UI_PREVIEW_RUNTIME_EVIDENCE:-/tmp/sable-ui-preview-runtime}"
mkdir -p "$EVIDENCE_DIR"

"$ADB" wait-for-device

attempts=180
while (( attempts > 0 )); do
    boot="$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
    if [[ "$boot" == 1 ]]; then
        break
    fi
    sleep 1
    ((attempts--))
done
[[ "${boot:-}" == 1 ]] || { echo "ANDROID_BOOT_TIMEOUT"; exit 3; }

slot="$("$ADB" shell getprop ro.boot.slot_suffix | tr -d '\r')"
build_id="$("$ADB" shell getprop ro.build.id | tr -d '\r')"
incremental="$("$ADB" shell getprop ro.build.version.incremental | tr -d '\r')"
crypto="$("$ADB" shell getprop ro.crypto.state | tr -d '\r')"

systemui_path="$("$ADB" shell pm path com.android.systemui | tr -d '\r')"
sablestart_path="$("$ADB" shell pm path org.sableos.start | tr -d '\r')"

[[ -n "$systemui_path" ]] || { echo "SYSTEMUI_RUNTIME_PACKAGE=FAIL"; exit 4; }
[[ -n "$sablestart_path" ]] || { echo "SABLESTART_RUNTIME_PACKAGE=FAIL"; exit 4; }

{
    echo "BOOT_COMPLETED=$boot"
    echo "SLOT_SUFFIX=$slot"
    echo "BUILD_ID=$build_id"
    echo "BUILD_INCREMENTAL=$incremental"
    echo "CRYPTO_STATE=$crypto"
    echo "SYSTEMUI_PATH=$systemui_path"
    echo "SABLESTART_PATH=$sablestart_path"
} | tee "$EVIDENCE_DIR/runtime-identity.txt"

if [[ "${CAPTURE_UI:-NO}" == YES ]]; then
    "$ADB" shell cmd statusbar expand-settings
    sleep 1
    "$ADB" exec-out screencap -p > "$EVIDENCE_DIR/quick-settings.png"
    "$ADB" shell cmd statusbar collapse

    "$ADB" shell am start -W -n org.sableos.start/.SableStartActivity         > "$EVIDENCE_DIR/sablestart-launch.txt"
    sleep 1
    "$ADB" exec-out screencap -p > "$EVIDENCE_DIR/sablestart.png"

    echo "UI_CAPTURE_QUICK_SETTINGS=$EVIDENCE_DIR/quick-settings.png"
    echo "UI_CAPTURE_SABLESTART=$EVIDENCE_DIR/sablestart.png"
fi

echo "UI_PREVIEW_RUNTIME_IDENTITY=PASS"
echo "UI4R4_HUMAN_VISUAL_REVIEW=REQUIRED"
