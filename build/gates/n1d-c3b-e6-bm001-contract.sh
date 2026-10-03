#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TRANSFORM="$ROOT/build/titan2/apply-n1d-c3b-e6-bm001-boot-compat.py"
BUILD="$ROOT/build/titan2/build-n1d-c3b-e6-bm001-systemimage.sh"
CONTROL="$ROOT/patches/android-16-n1d-trebledroid/build-make/0001-Remove-init.vndk-nodef.rc.patch"

fail() {
    echo "N1D_C3B_E6_BM001_CONTRACT=FAIL $*" >&2
    exit 1
}

for f in "$TRANSFORM" "$BUILD" "$CONTROL"; do
    [[ -f "$f" ]] || fail "missing_file=$f"
done

bash -n "$BUILD" || fail build_shell_syntax
PYTHONPYCACHEPREFIX="${TMPDIR:-/tmp}/sable-pycache" \
    python3 -m py_compile "$TRANSFORM" || fail transform_python_syntax
python3 "$TRANSFORM" self-test || fail transform_self_test

control_blob="$(git hash-object "$CONTROL")"
[[ "$control_blob" == 29bc98c8a69291e198fdcf169473e7506256b5d4 ]] ||
    fail "control_blob=$control_blob"

for token in \
    'RUNTIME_PATCH=BM-001_REMOVE_INIT_VNDK_NODEF' \
    'VNDK28_SEPOLICY_ADMISSION=NO_DEFERRED' \
    'RESTLESS_RUNTIME_PATCH_ADMISSION_COUNT=1' \
    '"$SABLE_PYTHON" "$TRANSFORM" apply --repo "$BUILD_MAKE_ROOT"' \
    'N1D_C3B_E6_BM001_RUNTIME_COMPAT=PASS_APPLIED_ONLY' \
    'make systemimage -j"$JOBS"' \
    'N1D_C3B_E6_SABLE_MODULE_COUNT=PASS value=5' \
    'N1D_C3B_E6_SYSTEMIMAGE=PASS'
do
    grep -Fq -- "$token" "$BUILD" || fail "build_missing=$token"
done

for token in \
    'PREBUILT_BLOCK' \
    'init.vndk-nodef.rc' \
    'import /system/system_ext/etc/gsi/init.vndk-${ro.vndk.version:-nodef}.rc' \
    'exec - root -- /system/bin/reboot bootloader' \
    'N1D_C3B_E6_BM001=PASS_APPLIED' \
    'N1D_C3B_E6_BM001_SELF_TEST=PASS'
do
    grep -Fq -- "$token" "$TRANSFORM" || fail "transform_missing=$token"
done

systemimage_count="$(grep -Ec '^[[:space:]]*make[[:space:]]+systemimage[[:space:]]' "$BUILD" || true)"
[[ "$systemimage_count" -eq 1 ]] || fail "systemimage_count=$systemimage_count"

if grep -Fq '0003-Include-vndk-v28-sepolicy-support.patch' "$BUILD" "$TRANSFORM"; then
    fail vndk28_patch_unexpectedly_admitted
fi
if grep -Eq '^[[:space:]]*(adb|fastboot)([[:space:]]|$)' "$BUILD"; then
    fail device_command_present
fi
if grep -Eq 'repo[[:space:]]+sync|curl[[:space:]]|wget[[:space:]]|git[[:space:]]+(fetch|pull|clone)' "$BUILD"; then
    fail network_command_present
fi
if grep -Eq '(^|[[:space:]])(clean|clobber)([[:space:]]|$)|rm[[:space:]]+-rf' "$BUILD"; then
    fail destructive_build_command_present
fi
if grep -Eq 'target-files-package|otatools|(^|[[:space:]])dist([[:space:]]|$)' "$BUILD"; then
    fail release_packaging_goal_present
fi

echo "N1D_C3B_E6_BM001_SCRIPT_SYNTAX=PASS"
echo "N1D_C3B_E6_BM001_SELF_TEST=PASS"
echo "N1D_C3B_E6_BM001_CONTROL_BLOB=PASS"
echo "N1D_C3B_E6_BM001_RUNTIME_SCOPE=PASS_EXACT_ONE"
echo "N1D_C3B_E6_VNDK28_SEPOLICY=PASS_DEFERRED"
echo "N1D_C3B_E6_BUILD_SCOPE=PASS_ONE_SYSTEMIMAGE"
echo "N1D_C3B_E6_DEVICE_NETWORK_RELEASE_SCOPE=PASS_BLOCKED"
echo "N1D_C3B_E6_BM001_CONTRACT=PASS"
