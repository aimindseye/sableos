#!/usr/bin/env bash
set -euo pipefail

DEVICE_CONTACT_AUTHORIZED="${DEVICE_CONTACT_AUTHORIZED:-NO}"
DEVICE_REBOOT_AUTHORIZED="${DEVICE_REBOOT_AUTHORIZED:-NO}"
FLASH_AUTHORIZED="${FLASH_AUTHORIZED:-NO}"
SLOT_CHANGE_AUTHORIZED="${SLOT_CHANGE_AUTHORIZED:-NO}"

for pair in \
    "DEVICE_CONTACT_AUTHORIZED:$DEVICE_CONTACT_AUTHORIZED" \
    "DEVICE_REBOOT_AUTHORIZED:$DEVICE_REBOOT_AUTHORIZED" \
    "FLASH_AUTHORIZED:$FLASH_AUTHORIZED" \
    "SLOT_CHANGE_AUTHORIZED:$SLOT_CHANGE_AUTHORIZED"
do
    name="${pair%%:*}"
    value="${pair#*:}"
    if [[ "$value" != YES ]]; then
        echo "Refusing device operation. Set $name=YES explicitly."
        exit 2
    fi
done

IMAGE_ZIP="${1:-${SABLEOS_UI_PREVIEW_FASTBOOT_ZIP:-}}"
if [[ -z "$IMAGE_ZIP" ]]; then
    echo "Usage: bash build/panther/flash-ui-preview-inactive-slot.sh /path/to/sable_panther-ui-preview-images.zip"
    exit 2
fi
IMAGE_ZIP="$(readlink -f "$IMAGE_ZIP")"
LEDGER="$IMAGE_ZIP.sha256"

[[ -f "$IMAGE_ZIP" ]] || { echo "MISSING=$IMAGE_ZIP"; exit 3; }
[[ -f "$LEDGER" ]] || { echo "MISSING=$LEDGER"; exit 3; }

(
    cd "$(dirname "$IMAGE_ZIP")"
    sha256sum -c "$(basename "$LEDGER")"
)

ZIP_LIST="$(mktemp)"
FASTBOOT_INFO="$(mktemp)"
trap 'rm -f "$ZIP_LIST" "$FASTBOOT_INFO"' EXIT
unzip -Z1 "$IMAGE_ZIP" > "$ZIP_LIST"
unzip -p "$IMAGE_ZIP" fastboot-info.txt > "$FASTBOOT_INFO"

required_members=(
    android-info.txt
    fastboot-info.txt
    boot.img
    init_boot.img
    dtbo.img
    vendor_kernel_boot.img
    pvmfw.img
    vendor_boot.img
    vbmeta.img
    super_empty.img
    system.img
    system_dlkm.img
    system_ext.img
    product.img
    vendor.img
    vendor_dlkm.img
)
for member in "${required_members[@]}"; do
    grep -Fxq "$member" "$ZIP_LIST" || {
        echo "FASTBOOT_PACKAGE_MEMBER_MISSING=$member"
        exit 3
    }
done

required_fastboot_lines=(
    "flash boot"
    "flash init_boot"
    "flash dtbo"
    "flash vendor_kernel_boot"
    "flash pvmfw"
    "flash vendor_boot"
    "flash --apply-vbmeta vbmeta"
    "reboot fastboot"
    "update-super"
    "flash system"
    "flash system_dlkm"
    "flash system_ext"
    "flash product"
    "flash vendor"
    "flash vendor_dlkm"
    "if-wipe erase userdata"
    "if-wipe erase metadata"
)
for line in "${required_fastboot_lines[@]}"; do
    grep -Fxq "$line" "$FASTBOOT_INFO" || {
        echo "FASTBOOT_INFO_REQUIRED_LINE_MISSING=$line"
        exit 3
    }
done
echo "FASTBOOT_PACKAGE_CONTRACT=PASS"

FASTBOOT="${FASTBOOT:-fastboot}"
ADB="${ADB:-adb}"
command -v "$FASTBOOT" >/dev/null || {
    echo "FASTBOOT_NOT_FOUND=$FASTBOOT"
    exit 3
}

fastboot_version="$("$FASTBOOT" --version 2>/dev/null | awk '/^fastboot version / {print $3; exit}' | cut -d- -f1)"
if [[ -z "$fastboot_version" ]]; then
    echo "FASTBOOT_VERSION_UNREADABLE"
    exit 3
fi
minimum_fastboot=35.0.1
if [[ "$(printf '%s\n' "$minimum_fastboot" "$fastboot_version" | sort -V | head -n1)" != "$minimum_fastboot" ]]; then
    echo "FASTBOOT_VERSION=$fastboot_version"
    echo "FASTBOOT_MINIMUM_REQUIRED=$minimum_fastboot"
    echo "FASTBOOT_VERSION_GATE=FAIL"
    exit 3
fi
echo "FASTBOOT_VERSION=$fastboot_version"
echo "FASTBOOT_VERSION_GATE=PASS"

wait_fastboot() {
    local attempts=90
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
    command -v "$ADB" >/dev/null || {
        echo "ADB_NOT_FOUND=$ADB"
        exit 3
    }
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
    "${FB[@]}" getvar "$key" 2>&1 \
        | sed -nE "s/^.*$key: *//p" \
        | tail -n1 \
        | tr -d '\r'
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
[[ -z "$snapshot" || "$snapshot" == none ]] || {
    echo "SNAPSHOT_UPDATE_ACTIVE=$snapshot"
    exit 5
}

if [[ "$current_slot" == a ]]; then
    target_slot=b
else
    target_slot=a
fi
echo "TARGET_INACTIVE_SLOT=$target_slot"
echo "ROLLBACK_SLOT_PRESERVED=$current_slot"

echo "FASTBOOT_UPDATE_WIPE=NO"
echo "FASTBOOT_UPDATE_SKIP_SECONDARY=YES"
echo "FASTBOOT_UPDATE_TARGET_SLOT=$target_slot"

"${FB[@]}" \
    --slot="$target_slot" \
    --skip-secondary \
    --skip-reboot \
    update "$IMAGE_ZIP"

echo "FASTBOOT_UPDATE=PASS"

post_userspace="$(getvar is-userspace || true)"
if [[ "$post_userspace" == yes ]]; then
    echo "RETURNING_TO_BOOTLOADER_FOR_POST_FLASH_VALIDATION=YES"
    "${FB[@]}" reboot bootloader
    wait_fastboot
fi

post_slot="$(getvar current-slot)"
echo "POST_FLASH_CURRENT_SLOT=$post_slot"
[[ "$post_slot" == "$target_slot" ]] || {
    echo "POST_FLASH_SLOT_MISMATCH"
    exit 6
}

echo "USERDATA_WIPE=NONE"
echo "METADATA_WIPE=NONE"
echo "ROLLBACK_SLOT_UNTOUCHED_BY_SECONDARY_FLASH=$current_slot"
echo "PREVIEW_SLOT_NOW=$target_slot"

"${FB[@]}" reboot
echo "UI_PREVIEW_FASTBOOT_UPDATE=PASS"
echo "RUNTIME_BOOT_VALIDATION=REQUIRED"
