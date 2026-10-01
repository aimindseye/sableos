#!/usr/bin/env bash
# SableOS canonical build-root migration helper.
#
# Runtime migration intentionally uses a bind mount first so active nested
# evidence mounts are not disturbed. Persistent fstab conversion is emitted as
# a plan for explicit administrator review; this script never edits /etc/fstab.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROFILE="$ROOT/build/config/storage.env"
VERIFY="$ROOT/build/host/verify-storage-root.sh"

fail() {
    echo "SABLE_STORAGE_MIGRATION=FAIL $*" >&2
    exit 1
}

[[ -f "$PROFILE" ]] || fail "missing_profile=$PROFILE"
# shellcheck source=/dev/null
source "$PROFILE"

ACTION="${1:-preflight}"
if (($#)); then shift; fi

AUTHORIZED=NO
while (($#)); do
    case "$1" in
        --authorize) AUTHORIZED=YES; shift ;;
        *) fail "unknown_arg=$1" ;;
    esac
done

resolve_underlying_source() {
    local mountpoint="$1" source
    source="$(findmnt -n -o SOURCE -M "$mountpoint" 2>/dev/null || true)"
    printf '%s\n' "${source%%[*}"
}

preflight() {
    echo "===== SABLE STORAGE ROOT MIGRATION PREFLIGHT ====="
    echo "SOURCE_MUTATION_AUTHORIZED=NO"
    echo "BUILD_AUTHORIZED=NO"
    echo "DEVICE_CONTACT_AUTHORIZED=NO"
    echo "FLASH_AUTHORIZED=NO"
    echo "FSTAB_MUTATION_AUTHORIZED=NO"
    echo "CANONICAL_ROOT=$SABLE_BUILD_ROOT"
    echo "LEGACY_ROOT=$SABLE_BUILD_LEGACY_ROOT"

    [[ -d "$SABLE_BUILD_LEGACY_ROOT" ]] ||
        fail "legacy_root_missing=$SABLE_BUILD_LEGACY_ROOT"

    findmnt -M "$SABLE_BUILD_LEGACY_ROOT" >/dev/null 2>&1 ||
        fail "legacy_root_not_mountpoint=$SABLE_BUILD_LEGACY_ROOT"

    local source fstype label uuid
    source="$(resolve_underlying_source "$SABLE_BUILD_LEGACY_ROOT")"
    fstype="$(findmnt -n -o FSTYPE -M "$SABLE_BUILD_LEGACY_ROOT")"

    [[ "$source" == /dev/* ]] ||
        fail "legacy_block_source_unresolved source=$source"

    label="$(lsblk -n -o LABEL "$source" 2>/dev/null | head -1 | tr -d '[:space:]')"

    [[ "$fstype" == "$SABLE_BUILD_FS_TYPE_EXPECTED" ]] ||
        fail "fstype expected=$SABLE_BUILD_FS_TYPE_EXPECTED actual=$fstype"
    [[ "$label" == "$SABLE_BUILD_FS_LABEL_EXPECTED" ]] ||
        fail "label expected=$SABLE_BUILD_FS_LABEL_EXPECTED actual=${label:--}"

    if findmnt -M "$SABLE_BUILD_ROOT" >/dev/null 2>&1; then
        canonical_source="$(resolve_underlying_source "$SABLE_BUILD_ROOT")"
        [[ "$canonical_source" == "$source" ]] ||
            fail "canonical_root_already_mounted_from_other_source source=$canonical_source"
        echo "CANONICAL_ROOT_ALREADY_BOUND=YES"
    else
        [[ ! -e "$SABLE_BUILD_ROOT" || -d "$SABLE_BUILD_ROOT" ]] ||
            fail "canonical_root_exists_not_directory=$SABLE_BUILD_ROOT"
        if [[ -d "$SABLE_BUILD_ROOT" ]]; then
            [[ -z "$(find "$SABLE_BUILD_ROOT" -mindepth 1 -maxdepth 1 -print -quit)" ]] ||
                fail "canonical_root_not_empty=$SABLE_BUILD_ROOT"
        fi
        echo "CANONICAL_ROOT_ALREADY_BOUND=NO"
    fi

    uuid="$(lsblk -n -o UUID "$source" 2>/dev/null | head -1 | tr -d '[:space:]')"
    [[ -n "$uuid" ]] || fail "uuid_unresolved source=$source"

    echo "SABLE_BUILD_FS_SOURCE=$source"
    echo "SABLE_BUILD_FS_UUID=$uuid"
    echo "SABLE_BUILD_FS_TYPE=$fstype"
    echo "SABLE_BUILD_FS_LABEL=$label"
    echo "SABLE_STORAGE_MIGRATION_PREFLIGHT=PASS"
}

live_bind() {
    [[ "$AUTHORIZED" == YES ]] ||
        fail "live_bind_requires_--authorize"

    preflight

    if findmnt -M "$SABLE_BUILD_ROOT" >/dev/null 2>&1; then
        echo "SABLE_STORAGE_LIVE_BIND=PASS_ALREADY_PRESENT"
        bash "$VERIFY" runtime
        return
    fi

    sudo mkdir -p "$SABLE_BUILD_ROOT"
    sudo mount --bind "$SABLE_BUILD_LEGACY_ROOT" "$SABLE_BUILD_ROOT"

    canonical_dev="$(stat -c '%d' "$SABLE_BUILD_ROOT")"
    legacy_dev="$(stat -c '%d' "$SABLE_BUILD_LEGACY_ROOT")"
    [[ "$canonical_dev" == "$legacy_dev" ]] || {
        sudo umount "$SABLE_BUILD_ROOT" || true
        fail "bind_device_mismatch"
    }

    echo "SABLE_STORAGE_LIVE_BIND=PASS"
    echo "SABLE_STORAGE_RUNTIME_TRANSITION=OLD_NATIVE_NEW_BIND_UNTIL_REBOOT"
    bash "$VERIFY" runtime
}

fstab_plan() {
    preflight

    local source uuid fstype
    source="$(resolve_underlying_source "$SABLE_BUILD_LEGACY_ROOT")"
    uuid="$(lsblk -n -o UUID "$source" 2>/dev/null | head -1 | tr -d '[:space:]')"
    fstype="$(findmnt -n -o FSTYPE -M "$SABLE_BUILD_LEGACY_ROOT")"

    echo
    echo "===== PROPOSED /etc/fstab TARGET STATE ====="
    echo "# Review existing mount options before applying."
    printf 'UUID=%s %s %s defaults 0 2\n' "$uuid" "$SABLE_BUILD_ROOT" "$fstype"
    printf '%s %s none bind,x-systemd.requires-mounts-for=%s 0 0\n' \
        "$SABLE_BUILD_ROOT" \
        "$SABLE_BUILD_LEGACY_ROOT" \
        "$SABLE_BUILD_ROOT"
    echo
    echo "FSTAB_MUTATION_PERFORMED=NO"
    echo "SABLE_STORAGE_FSTAB_PLAN=PASS"
}

case "$ACTION" in
    preflight) preflight ;;
    live-bind) live_bind ;;
    fstab-plan) fstab_plan ;;
    *) fail "unknown_action=$ACTION" ;;
esac
