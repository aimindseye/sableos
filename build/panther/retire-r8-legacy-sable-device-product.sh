#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SOURCE_MUTATION_AUTHORIZED="${SOURCE_MUTATION_AUTHORIZED:-NO}"
WS="${SABLEOS_UPSTREAM:-${WS:-}}"

scan_references() {
    local ws="$1"
    local target="$2"
    local out="$3"
    local roots=()
    local candidate

    : > "$out"

    for candidate in vendor device build product system; do
        [[ -d "$ws/$candidate" ]] && roots+=("$ws/$candidate")
    done

    if [[ "${#roots[@]}" -gt 0 ]]; then
        find "${roots[@]}" \
            -type f \
            \( -name '*.mk' -o -name '*.bp' -o -name 'AndroidProducts.mk' \) \
            ! -path "$target/*" \
            -print0 \
        | xargs -0 -r grep -nH -E \
            'vendor/sable_devices/sable_panther|sable_devices/sable_panther|(^|[^[:alnum:]_])sable_panther\.mk([^[:alnum:]_]|$)' \
            >> "$out" || true
    fi

    sort -u -o "$out" "$out"
}

retire_legacy_device_product() {
    local ws="$1"
    local parent="$ws/vendor/sable_devices"
    local target="$parent/sable_panther"
    local refs
    local extras

    [[ -d "$ws/.repo" ]] || {
        echo "R8_LEGACY_SABLE_DEVICE_PRODUCT=FAIL_WORKSPACE path=$ws"
        return 3
    }

    [[ "$target" == "$ws/vendor/sable_devices/sable_panther" ]] || {
        echo "R8_LEGACY_SABLE_DEVICE_PRODUCT=FAIL_PATH_MISMATCH path=$target"
        return 4
    }

    if [[ -L "$parent" ]]; then
        echo "R8_LEGACY_SABLE_DEVICE_PRODUCT=FAIL_PARENT_SYMLINK path=$parent"
        return 5
    fi

    if [[ -L "$target" ]]; then
        echo "R8_LEGACY_SABLE_DEVICE_PRODUCT=FAIL_SYMLINK path=$target"
        return 6
    fi

    if [[ -d "$parent" ]]; then
        extras="$(
            find "$parent" -mindepth 1 -maxdepth 1 \
                ! -name sable_panther -print | sort
        )"
        if [[ -n "$extras" ]]; then
            echo "R8_LEGACY_SABLE_DEVICE_PRODUCT=FAIL_EXTRA_PARENT_CONTENT"
            printf '%s\n' "$extras"
            return 7
        fi
    elif [[ -e "$parent" ]]; then
        echo "R8_LEGACY_SABLE_DEVICE_PRODUCT=FAIL_PARENT_NOT_DIRECTORY path=$parent"
        return 8
    fi

    if [[ -e "$target" ]]; then
        [[ -d "$target" ]] || {
            echo "R8_LEGACY_SABLE_DEVICE_PRODUCT=FAIL_NOT_DIRECTORY path=$target"
            return 9
        }

        refs="$(mktemp)"
        scan_references "$ws" "$target" "$refs"

        if [[ -s "$refs" ]]; then
            echo "R8_LEGACY_SABLE_DEVICE_PRODUCT=FAIL_REFERENCED path=$target"
            cat "$refs"
            rm -f "$refs"
            return 10
        fi
        rm -f "$refs"

        echo "R8_LEGACY_SABLE_DEVICE_PRODUCT_INVENTORY_BEGIN"
        find "$target" -xdev -mindepth 1 -maxdepth 6 -print | sort
        echo "R8_LEGACY_SABLE_DEVICE_PRODUCT_INVENTORY_END"

        rm -rf --one-file-system -- "$target"

        [[ ! -e "$target" && ! -L "$target" ]] || {
            echo "R8_LEGACY_SABLE_DEVICE_PRODUCT=FAIL_REMOVE path=$target"
            return 11
        }

        echo "R8_LEGACY_SABLE_DEVICE_PRODUCT=REMOVED_UNREFERENCED"
    else
        echo "R8_LEGACY_SABLE_DEVICE_PRODUCT=PASS_ABSENT"
    fi

    if [[ -d "$parent" ]]; then
        if find "$parent" -mindepth 1 -print -quit | grep -q .; then
            echo "R8_LEGACY_SABLE_DEVICE_PRODUCT=FAIL_PARENT_NONEMPTY path=$parent"
            find "$parent" -mindepth 1 -maxdepth 3 -print | sort
            return 12
        fi
        rmdir -- "$parent"
        echo "R8_LEGACY_SABLE_DEVICE_PARENT=REMOVED_EMPTY"
    else
        echo "R8_LEGACY_SABLE_DEVICE_PARENT=PASS_ABSENT"
    fi

    [[ ! -e "$parent" && ! -L "$parent" ]] || {
        echo "R8_LEGACY_SABLE_DEVICE_PRODUCT=FAIL_POSTCHECK path=$parent"
        return 13
    }

    echo "R8_LEGACY_SABLE_DEVICE_PRODUCT=PASS"
}

self_test() {
    local td ws rc
    td="$(mktemp -d)"
    trap 'rm -rf "$td"' RETURN
    ws="$td/ws"

    mkdir -p "$ws/.repo" "$ws/vendor/sable_devices/sable_panther" "$ws/vendor/google_devices/panther"
    printf 'PRODUCT_NAME := sable_panther\n' > "$ws/vendor/sable_devices/sable_panther/sable_panther.mk"
    printf 'PRODUCT_NAME := panther\n' > "$ws/vendor/google_devices/panther/panther.mk"

    retire_legacy_device_product "$ws"
    [[ ! -e "$ws/vendor/sable_devices" ]]

    mkdir -p "$ws/vendor/sable_devices/sable_panther"
    printf 'PRODUCT_NAME := sable_panther\n' > "$ws/vendor/sable_devices/sable_panther/sable_panther.mk"
    printf '\$(call inherit-product, vendor/sable_devices/sable_panther/sable_panther.mk)\n' \
        > "$ws/vendor/google_devices/panther/panther.mk"

    set +e
    retire_legacy_device_product "$ws" > "$td/referenced.log" 2>&1
    rc=$?
    set -e

    [[ "$rc" -ne 0 ]]
    grep -Fq 'R8_LEGACY_SABLE_DEVICE_PRODUCT=FAIL_REFERENCED' "$td/referenced.log"
    [[ -d "$ws/vendor/sable_devices/sable_panther" ]]

    rm -f "$ws/vendor/google_devices/panther/panther.mk"
    mkdir -p "$ws/vendor/sable_devices/other_device"
    set +e
    retire_legacy_device_product "$ws" > "$td/extra.log" 2>&1
    rc=$?
    set -e

    [[ "$rc" -ne 0 ]]
    grep -Fq 'R8_LEGACY_SABLE_DEVICE_PRODUCT=FAIL_EXTRA_PARENT_CONTENT' "$td/extra.log"
    [[ -d "$ws/vendor/sable_devices/sable_panther" ]]
    [[ -d "$ws/vendor/sable_devices/other_device" ]]

    echo "R8_LEGACY_SABLE_DEVICE_PRODUCT_SELF_TEST_UNREFERENCED=PASS_REMOVED"
    echo "R8_LEGACY_SABLE_DEVICE_PRODUCT_SELF_TEST_REFERENCED=PASS_REFUSED"
    echo "R8_LEGACY_SABLE_DEVICE_PRODUCT_SELF_TEST_EXTRA_PARENT=PASS_REFUSED"
    echo "R8_LEGACY_SABLE_DEVICE_PRODUCT_SELF_TEST=PASS"
}

if [[ "${1:-}" == "--self-test" ]]; then
    self_test
    exit 0
fi

if [[ "$SOURCE_MUTATION_AUTHORIZED" != YES ]]; then
    echo "R8_LEGACY_SABLE_DEVICE_PRODUCT=REFUSED_SOURCE_MUTATION_NOT_AUTHORIZED"
    exit 2
fi

[[ -n "$WS" ]] || {
    echo "R8_LEGACY_SABLE_DEVICE_PRODUCT=FAIL_WORKSPACE_UNSET"
    exit 3
}

echo "===== R8 LEGACY SABLE DEVICE PRODUCT RETIREMENT ====="
echo "SOURCE_MUTATION_AUTHORIZED=YES_EXACT_PATH_ONLY"
echo "GENERAL_DELETE_AUTHORIZED=NO"
echo "TARGET=$WS/vendor/sable_devices/sable_panther"

retire_legacy_device_product "$WS"
