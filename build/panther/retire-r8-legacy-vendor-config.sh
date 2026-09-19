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
            ! -path "$target" \
            -print0 \
        | xargs -0 -r grep -nH -E \
            'vendor/sable/config(/common\.mk)?|sable/config/common\.mk' \
            >> "$out" || true
    fi

    if [[ -d "$ws/vendor/sable" ]]; then
        find "$ws/vendor/sable" \
            -type f \
            \( -name '*.mk' -o -name '*.bp' -o -name 'AndroidProducts.mk' \) \
            ! -path "$target" \
            -print0 \
        | xargs -0 -r grep -nH -E \
            '(^|[^[:alnum:]_])(\.\.?/)*config/common\.mk' \
            >> "$out" || true
    fi

    sort -u -o "$out" "$out"
}

retire_config() {
    local ws="$1"
    local target="$ws/vendor/sable/config/common.mk"
    local parent="$ws/vendor/sable/config"
    local refs
    local extra

    [[ -d "$ws/.repo" ]] || {
        echo "R8_LEGACY_VENDOR_CONFIG=FAIL_WORKSPACE path=$ws"
        return 3
    }

    [[ "$target" == "$ws/vendor/sable/config/common.mk" ]] || {
        echo "R8_LEGACY_VENDOR_CONFIG=FAIL_PATH_MISMATCH path=$target"
        return 4
    }

    if [[ -L "$parent" ]]; then
        echo "R8_LEGACY_VENDOR_CONFIG=FAIL_PARENT_SYMLINK path=$parent"
        return 5
    fi

    if [[ -L "$target" ]]; then
        echo "R8_LEGACY_VENDOR_CONFIG=FAIL_SYMLINK path=$target"
        return 6
    fi

    if [[ -d "$parent" ]]; then
        extra="$(
            find "$parent" -mindepth 1 -maxdepth 1 \
                ! -name common.mk -print | sort
        )"
        if [[ -n "$extra" ]]; then
            echo "R8_LEGACY_VENDOR_CONFIG=FAIL_EXTRA_CONTENT"
            printf '%s\n' "$extra"
            return 7
        fi
    elif [[ -e "$parent" ]]; then
        echo "R8_LEGACY_VENDOR_CONFIG=FAIL_PARENT_NOT_DIRECTORY path=$parent"
        return 8
    fi

    if [[ -e "$target" ]]; then
        [[ -f "$target" ]] || {
            echo "R8_LEGACY_VENDOR_CONFIG=FAIL_NOT_REGULAR path=$target"
            return 9
        }

        refs="$(mktemp)"
        scan_references "$ws" "$target" "$refs"

        if [[ -s "$refs" ]]; then
            echo "R8_LEGACY_VENDOR_CONFIG=FAIL_REFERENCED path=$target"
            cat "$refs"
            rm -f "$refs"
            return 10
        fi
        rm -f "$refs"

        echo "R8_LEGACY_VENDOR_CONFIG_SHA256=$(sha256sum "$target" | awk '{print $1}')"
        echo "R8_LEGACY_VENDOR_CONFIG_CONTENT_BEGIN"
        cat "$target"
        echo "R8_LEGACY_VENDOR_CONFIG_CONTENT_END"

        rm -f -- "$target"

        [[ ! -e "$target" && ! -L "$target" ]] || {
            echo "R8_LEGACY_VENDOR_CONFIG=FAIL_REMOVE path=$target"
            return 11
        }

        echo "R8_LEGACY_VENDOR_CONFIG=REMOVED_UNREFERENCED"
    else
        echo "R8_LEGACY_VENDOR_CONFIG=PASS_ABSENT"
    fi

    if [[ -d "$parent" ]]; then
        if find "$parent" -mindepth 1 -print -quit | grep -q .; then
            echo "R8_LEGACY_VENDOR_CONFIG=FAIL_PARENT_NONEMPTY path=$parent"
            return 12
        fi
        rmdir -- "$parent"
        echo "R8_LEGACY_VENDOR_CONFIG_PARENT=REMOVED_EMPTY"
    else
        echo "R8_LEGACY_VENDOR_CONFIG_PARENT=PASS_ABSENT"
    fi

    [[ ! -e "$parent" && ! -L "$parent" ]] || {
        echo "R8_LEGACY_VENDOR_CONFIG=FAIL_POSTCHECK path=$parent"
        return 13
    }

    echo "R8_LEGACY_VENDOR_CONFIG=PASS"
}

self_test() {
    local td ws ref rc
    td="$(mktemp -d)"
    trap 'rm -rf "$td"' RETURN
    ws="$td/ws"

    mkdir -p "$ws/.repo" "$ws/vendor/sable/config" "$ws/vendor/google_devices/panther"
    printf '# historical Sable config\n' > "$ws/vendor/sable/config/common.mk"
    printf 'PRODUCT_NAME := panther\n' > "$ws/vendor/google_devices/panther/panther.mk"

    retire_config "$ws"
    [[ ! -e "$ws/vendor/sable/config" ]]

    mkdir -p "$ws/vendor/sable/config"
    printf '# historical Sable config\n' > "$ws/vendor/sable/config/common.mk"
    printf '\$(call inherit-product, vendor/sable/config/common.mk)\n' \
        > "$ws/vendor/google_devices/panther/panther.mk"

    set +e
    retire_config "$ws" > "$td/referenced.log" 2>&1
    rc=$?
    set -e

    [[ "$rc" -ne 0 ]]
    grep -Fq 'R8_LEGACY_VENDOR_CONFIG=FAIL_REFERENCED' "$td/referenced.log"
    [[ -f "$ws/vendor/sable/config/common.mk" ]]

    echo "R8_LEGACY_VENDOR_CONFIG_SELF_TEST_UNREFERENCED=PASS_REMOVED"
    echo "R8_LEGACY_VENDOR_CONFIG_SELF_TEST_REFERENCED=PASS_REFUSED"
    echo "R8_LEGACY_VENDOR_CONFIG_SELF_TEST=PASS"
}

if [[ "${1:-}" == "--self-test" ]]; then
    self_test
    exit 0
fi

if [[ "$SOURCE_MUTATION_AUTHORIZED" != YES ]]; then
    echo "R8_LEGACY_VENDOR_CONFIG=REFUSED_SOURCE_MUTATION_NOT_AUTHORIZED"
    exit 2
fi

[[ -n "$WS" ]] || {
    echo "R8_LEGACY_VENDOR_CONFIG=FAIL_WORKSPACE_UNSET"
    exit 3
}

echo "===== R8 LEGACY VENDOR CONFIG RETIREMENT ====="
echo "SOURCE_MUTATION_AUTHORIZED=YES_EXACT_PATH_ONLY"
echo "GENERAL_DELETE_AUTHORIZED=NO"
echo "TARGET=$WS/vendor/sable/config/common.mk"

retire_config "$WS"
