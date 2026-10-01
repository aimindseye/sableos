#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROFILE="$ROOT/build/config/storage.env"

fail() {
    echo "SABLE_STORAGE_VERIFY=FAIL $*" >&2
    exit 1
}

[[ -f "$PROFILE" ]] || fail "missing_profile=$PROFILE"
# shellcheck source=/dev/null
source "$PROFILE"

MODE="${1:-runtime}"
case "$MODE" in
    config|runtime) ;;
    *) fail "invalid_mode=$MODE" ;;
esac

for value in \
    "$SABLE_BUILD_ROOT" \
    "$SABLE_BUILD_LEGACY_ROOT" \
    "$SABLE_WORKSPACES_ROOT" \
    "$SABLE_EVIDENCE_ROOT" \
    "$SABLE_ARTIFACTS_ROOT" \
    "$SABLE_RELEASE_REGISTRY_ROOT"
do
    [[ "$value" == /* ]] || fail "non_absolute_path=$value"
done

[[ "$SABLE_BUILD_ROOT" != "$SABLE_BUILD_LEGACY_ROOT" ]] ||
    fail "canonical_and_legacy_roots_must_differ"

echo "SABLE_STORAGE_CONFIG=PASS"
echo "SABLE_BUILD_ROOT=$SABLE_BUILD_ROOT"
echo "SABLE_BUILD_LEGACY_ROOT=$SABLE_BUILD_LEGACY_ROOT"

[[ "$MODE" == runtime ]] || {
    echo "SABLE_STORAGE_VERIFY=PASS_CONFIG_ONLY"
    exit 0
}

[[ -d "$SABLE_BUILD_ROOT" ]] ||
    fail "canonical_root_missing=$SABLE_BUILD_ROOT"

findmnt -M "$SABLE_BUILD_ROOT" >/dev/null 2>&1 ||
    fail "canonical_root_not_mountpoint=$SABLE_BUILD_ROOT"

source_spec="$(findmnt -n -o SOURCE -M "$SABLE_BUILD_ROOT")"
fstype="$(findmnt -n -o FSTYPE -M "$SABLE_BUILD_ROOT")"

[[ -n "$source_spec" ]] || fail "canonical_source_unresolved"
[[ "$fstype" == "$SABLE_BUILD_FS_TYPE_EXPECTED" ]] ||
    fail "fstype expected=$SABLE_BUILD_FS_TYPE_EXPECTED actual=$fstype"

block_source="${source_spec%%[*}"
if [[ "$block_source" != /dev/* ]]; then
    if findmnt -M "$SABLE_BUILD_LEGACY_ROOT" >/dev/null 2>&1; then
        legacy_source="$(findmnt -n -o SOURCE -M "$SABLE_BUILD_LEGACY_ROOT")"
        block_source="${legacy_source%%[*}"
    fi
fi

[[ "$block_source" == /dev/* ]] ||
    fail "block_source_unresolved source=$source_spec"

label="$(lsblk -n -o LABEL "$block_source" 2>/dev/null | head -1 | tr -d '[:space:]')"
[[ "$label" == "$SABLE_BUILD_FS_LABEL_EXPECTED" ]] ||
    fail "label expected=$SABLE_BUILD_FS_LABEL_EXPECTED actual=${label:--} source=$block_source"

free_bytes="$(df -B1 --output=avail "$SABLE_BUILD_ROOT" | tail -1 | tr -d ' ')"
[[ "$free_bytes" =~ ^[0-9]+$ ]] || fail "free_bytes_unresolved"

min_bytes=$((SABLE_BUILD_MIN_FREE_GIB * 1024 * 1024 * 1024))
(( free_bytes >= min_bytes )) ||
    fail "free_space below_minimum actual=$free_bytes required=$min_bytes"

if [[ "$SABLE_STORAGE_COMPATIBILITY_ALIAS_REQUIRED" == YES ]]; then
    [[ -d "$SABLE_BUILD_LEGACY_ROOT" ]] ||
        fail "legacy_alias_missing=$SABLE_BUILD_LEGACY_ROOT"

    canonical_dev="$(stat -c '%d' "$SABLE_BUILD_ROOT")"
    legacy_dev="$(stat -c '%d' "$SABLE_BUILD_LEGACY_ROOT")"
    [[ "$canonical_dev" == "$legacy_dev" ]] ||
        fail "legacy_alias_different_filesystem canonical_dev=$canonical_dev legacy_dev=$legacy_dev"

    echo "SABLE_STORAGE_COMPATIBILITY_ALIAS=PASS"
fi

echo "SABLE_BUILD_FS_SOURCE=$block_source"
echo "SABLE_BUILD_FS_TYPE=$fstype"
echo "SABLE_BUILD_FS_LABEL=$label"
echo "SABLE_BUILD_FREE_BYTES=$free_bytes"
echo "SABLE_BUILD_MIN_FREE_BYTES=$min_bytes"
echo "SABLE_STORAGE_RUNTIME=PASS"
echo "SABLE_STORAGE_VERIFY=PASS"
