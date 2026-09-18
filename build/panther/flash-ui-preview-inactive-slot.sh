#!/usr/bin/env bash
set -euo pipefail

DEVICE_CONTACT_AUTHORIZED="${DEVICE_CONTACT_AUTHORIZED:-NO}"
DEVICE_REBOOT_AUTHORIZED="${DEVICE_REBOOT_AUTHORIZED:-NO}"
FLASH_AUTHORIZED="${FLASH_AUTHORIZED:-NO}"
SLOT_CHANGE_AUTHORIZED="${SLOT_CHANGE_AUTHORIZED:-NO}"

for pair in     "DEVICE_CONTACT_AUTHORIZED:$DEVICE_CONTACT_AUTHORIZED"     "DEVICE_REBOOT_AUTHORIZED:$DEVICE_REBOOT_AUTHORIZED"     "FLASH_AUTHORIZED:$FLASH_AUTHORIZED"     "SLOT_CHANGE_AUTHORIZED:$SLOT_CHANGE_AUTHORIZED"
do
    name="${pair%%:*}"
    value="${pair#*:}"
    if [[ "$value" != YES ]]; then
        echo "Refusing device operation. Set $name=YES explicitly."
        exit 2
    fi
done

IMAGE_DIR="${1:-${SABLEOS_UI_PREVIEW_IMAGE_DIR:-}}"
if [[ -z "$IMAGE_DIR" ]]; then
    echo "Usage: bash build/panther/flash-ui-preview-inactive-slot.sh /path/to/out/target/product/panther"
    exit 2
fi
IMAGE_DIR="$(cd "$IMAGE_DIR" && pwd)"

required=(system.img product.img system_ext.img vbmeta.img UI_PREVIEW_IMAGES.sha256)
for item in "${required[@]}"; do
    [[ -f "$IMAGE_DIR/$item" ]] || { echo "MISSING=$IMAGE_DIR/$item"; exit 3; }
done

(
    cd "$IMAGE_DIR"
    sha256sum -c UI_PREVIEW_IMAGES.sha256
)

FASTBOOT="${FASTBOOT:-fastboot}"
ADB="${ADB:-adb}"
command -v "$FASTBOOT" >/dev/null
command -v "$ADB" >/dev/null

wait_fastboot() {
    local attempts=60
    while (( attempts > 0 )); do
        if "$FASTBOOT" devices 2>/dev/null | awk 'NF {print $1}' | grep -q .; then
            return 0
        fi
        sleep 1
        ((attempts--))
    done
    echo "FASTBOOT_DEVICE_TIMEOUT"
    return 1
}

if ! "$FASTBOOT" devices 2>/dev/null | awk 'NF {print $1}' | grep -q .; then
    echo "FASTBOOT_DEVICE_NOT_PRESENT=TRYING_ADB_REBOOT_BOOTLOADER"
    "$ADB" reboot bootloader
    wait_fastboot
fi

mapfile -t serials < <("$FASTBOOT" devices | awk 'NF {print $1}')
if [[ "${#serials[@]}" -ne 1 ]]; then
    echo "FASTBOOT_DEVICE_COUNT=${#serials[@]}"
    echo "Exactly one fastboot device is required."
    exit 4
fi
SERIAL="${serials[0]}"
FB=("$FASTBOOT" -s "$SERIAL")

getvar() {
    local key="$1"
    "${FB[@]}" getvar "$key" 2>&1         | sed -nE "s/^.*${key}: *//p"         | tail -n1         | tr -d '\r'
}

product="$(getvar product)"
current_slot="$(getvar current-slot)"
unlocked="$(getvar unlocked)"
snapshot="$(getvar snapshot-update-status)"

echo "FASTBOOT_SERIAL=$SERIAL"
echo "PRODUCT=$product"
echo "CURRENT_SLOT=$current_slot"
echo "UNLOCKED=$unlocked"
echo "SNAPSHOT_UPDATE_STATUS=$snapshot"

[[ "$product" == panther ]] || { echo "DEVICE_PRODUCT_MISMATCH"; exit 5; }
[[ "$current_slot" == a || "$current_slot" == b ]] || { echo "CURRENT_SLOT_INVALID"; exit 5; }
[[ "$unlocked" == yes ]] || { echo "BOOTLOADER_NOT_UNLOCKED"; exit 5; }
[[ -z "$snapshot" || "$snapshot" == none ]] || { echo "SNAPSHOT_UPDATE_ACTIVE=$snapshot"; exit 5; }

if [[ "$current_slot" == a ]]; then
    target_slot=b
else
    target_slot=a
fi
echo "TARGET_INACTIVE_SLOT=$target_slot"

is_userspace="$(getvar is-userspace || true)"
if [[ "$is_userspace" != yes ]]; then
    echo "ENTERING_FASTBOOTD=YES"
    "${FB[@]}" reboot fastboot
    wait_fastboot
fi

# Flash the complete Android userspace set carrying the UI preview.
# vbmeta is intentionally deferred until after returning to bootloader fastboot.
"${FB[@]}" flash "system_$target_slot" "$IMAGE_DIR/system.img"
"${FB[@]}" flash "product_$target_slot" "$IMAGE_DIR/product.img"
"${FB[@]}" flash "system_ext_$target_slot" "$IMAGE_DIR/system_ext.img"

echo "RETURNING_TO_BOOTLOADER_FOR_VBMETA=YES"
"${FB[@]}" reboot bootloader
wait_fastboot

"${FB[@]}" flash "vbmeta_$target_slot" "$IMAGE_DIR/vbmeta.img"
"${FB[@]}" set_active "$target_slot"

echo "FLASH_SET=system_$target_slot,product_$target_slot,system_ext_$target_slot,vbmeta_$target_slot"
echo "VBMETA_WRITTEN_LAST=PASS"
echo "USERDATA_WIPE=NONE"
echo "METADATA_WIPE=NONE"
echo "ACTIVE_SLOT_WAS=$current_slot"
echo "PREVIEW_SLOT_NOW=$target_slot"

"${FB[@]}" reboot
echo "UI_PREVIEW_FLASH=PASS_COMMAND_SEQUENCE"
echo "RUNTIME_BOOT_VALIDATION=REQUIRED"
