#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DRIVER="$ROOT/build/titan2/run-n1i-d0-image-build.sh"
BP="$ROOT/product/titan2/n1i-d0/Android.bp"
MK="$ROOT/product/titan2/n1i-d0/sable-titan2-n1i-d0.mk"
MARKER="$ROOT/product/titan2/n1i-d0/n1i-d0-image"

fail() {
    echo "N1I_D0_IMAGE_BUILD_CONTRACT=FAIL reason=$1" >&2
    exit 1
}

for path in "$DRIVER" "$BP" "$MK" "$MARKER"; do
    [[ -f "$path" ]] || fail "required_file_missing=$path"
done

bash -n "$DRIVER" || fail driver_shell_syntax

if grep -Eq '^[[:space:]]*set[[:space:]]+-[^[:space:]]*e|^[[:space:]]*set[[:space:]]+-o[[:space:]]+pipefail' "$DRIVER"; then
    fail forbidden_top_level_strict_shell
fi

[[ "$(grep -Ec '(^|[[:space:]])make[[:space:]]+systemimage([[:space:]]|$)' "$DRIVER")" == 1 ]] ||
    fail systemimage_build_count

if grep -Eq '(^|[[:space:]])(adb|fastboot)([[:space:]]|$)' "$DRIVER"; then
    fail device_command_surface_present
fi
if grep -Eq '(^|[[:space:]])(curl|wget)([[:space:]]|$)|git[[:space:]]+(fetch|pull|clone)|repo[[:space:]]+sync' "$DRIVER"; then
    fail network_command_surface_present
fi
if grep -Eq '(^|[[:space:]])(make|m|mm|mmm)[[:space:]]+(clean|clobber)([[:space:]]|$)|(^|[[:space:]])rm[[:space:]]+-rf[[:space:]]+[^"]*out' "$DRIVER"; then
    fail clean_clobber_surface_present
fi

marker() {
    local label="$1" file="$2" value="$3"
    grep -Fq -- "$value" "$file" || fail "missing_marker=$label:$value"
    echo "N1I_D0_IMAGE_BUILD_CONTRACT_${label}=PASS"
}

marker BUILD_REGRESSION "$DRIVER" 'build-regression-contract.py'
marker BUILD_AUTH "$DRIVER" 'BUILD_AUTHORIZED=YES_ONE_SYSTEMIMAGE'
marker DEVICE_NO "$DRIVER" 'DEVICE_CONTACT_AUTHORIZED=NO'
marker FLASH_NO "$DRIVER" 'FLASH_AUTHORIZED=NO'
marker BASELINE "$DRIVER" 'BASELINE=N1F_BOOT_QUALIFIED'
marker NO_CELLULAR "$DRIVER" 'CELLULAR_DELTA=C1_C2_NOT_INCLUDED'
marker SOURCE_RESTORE "$DRIVER" 'N1I_D0_IMAGE_SOURCE_RESTORE=PASS'
marker BUILD_PASS "$DRIVER" 'N1I_D0_IMAGE_BUILD=PASS'
marker MODULE "$BP" 'name: "SableTitan2N1ID0Marker"'
marker PRODUCT_SPECIFIC "$BP" 'product_specific: true'
marker MK_MODULE "$MK" 'SableTitan2N1ID0Marker'
marker MARKER_ROLE "$MARKER" 'ROLE=N1I_D0_IMG0_BUILD_PATH_CLOSURE'

trap_line="$(grep -nF 'trap cleanup_on_exit EXIT' "$DRIVER" | cut -d: -f1)"
stage_line="$(grep -nF 'mkdir -p "$C3B_STAGE/prebuilt" "$D0_STAGE"' "$DRIVER" | cut -d: -f1)"
[[ "$trap_line" =~ ^[0-9]+$ && "$stage_line" =~ ^[0-9]+$ && "$trap_line" -lt "$stage_line" ]] ||
    fail cleanup_trap_not_before_source_mutation

echo "N1I_D0_IMAGE_BUILD_CONTRACT=PASS"
