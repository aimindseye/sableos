#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DRIVER="$ROOT/build/titan2/run-n1i-c2-cellular-mvp.sh"
TEST="$ROOT/tests/titan2/n1i-c2/test-cellular-mvp-implementation.py"
BP="$ROOT/product/titan2/n1i-c2/Android.bp"
MK="$ROOT/product/titan2/n1i-c2/sable-titan2-n1i-c2.mk"
SCRIPT="$ROOT/product/titan2/n1i-c2/sable-titan2-cellular.sh"
RC="$ROOT/product/titan2/n1i-c2/sable-titan2-cellular.rc"
MARKER="$ROOT/product/titan2/n1i-c2/titan2-cellular-mvp"
PHH_PATCH="$ROOT/patches/android-16-n1i-c2/phh/0001-phh-preserve-mtk-ims-for-titan2-cellular-mvp.patch"

fail() {
    echo "N1I_C2_CELLULAR_MVP_IMPLEMENTATION_CONTRACT=FAIL reason=$*" >&2
    exit 1
}

marker() {
    local name="$1" file="$2" value="$3"
    grep -Fq -- "$value" "$file" || fail "missing_marker=$name"
    echo "N1I_C2_IMPLEMENTATION_CONTRACT_$name=PASS"
}

for f in "$DRIVER" "$TEST" "$BP" "$MK" "$SCRIPT" "$RC" "$MARKER" "$PHH_PATCH"; do
    [[ -f "$f" ]] || fail "missing_file=$f"
done

echo "===== N1I-C2 CELLULAR MVP IMPLEMENTATION CONTRACT ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO_BY_CONTRACT"
echo "BUILD_AUTHORIZED=NO_BY_CONTRACT"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "REBOOT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"

bash -n "$DRIVER" "$SCRIPT"
echo "N1I_C2_IMPLEMENTATION_CONTRACT_SHELL_SYNTAX=PASS"

PYTHONPYCACHEPREFIX="${TMPDIR:-/tmp}/sable-pycache"     python3 -m py_compile "$TEST"
echo "N1I_C2_IMPLEMENTATION_CONTRACT_PYTHON_SYNTAX=PASS"

marker C1_INHERIT "$MK" 'vendor/sable/titan2/n1i-c1/sable-titan2-n1i-c1.mk'
marker INCOMING_PROPERTY "$MK" 'ro.telephony.block_binder_thread_on_incoming_calls=false'
marker INTEGRATION_PACKAGE "$MK" 'SableTitan2Cellular'
marker HEALER_ENABLE_FILE "$SCRIPT" '/data/local/tmp/sable-titan2-cellular-healer.enable'
marker IMS_PROVIDER_QUERY "$SCRIPT" 'cmd phone ims get-ims-service'
marker IMS_PROVIDER_REBIND "$SCRIPT" 'cmd phone ims set-ims-service'
marker IMS_ENABLE "$SCRIPT" 'cmd phone ims enable'
marker ACTIVE_CALL_SAFE "$SCRIPT" 'active_or_emergency_call'
marker RATE_LIMIT "$SCRIPT" 'COOLDOWN_SECONDS=300'
marker UA_OBSERVE "$SCRIPT" 'OBSERVE_READINESS'
marker INIT_BOOT_COMPLETED "$RC" 'on property:sys.boot_completed=1'
marker INIT_ONESHOT "$RC" 'oneshot'
marker HEALER_DEFAULT "$MARKER" 'HEALER_DEFAULT=DISABLED'
marker PHH_MARKER_GUARD "$PHH_PATCH" '/system_ext/etc/sable/titan2-cellular-mvp'
marker PHH_NON_C2_BEHAVIOR_RETAINED "$PHH_PATCH" 'setprop persist.mtk_ims_support 0'
marker MATERIALIZATION_PIN "$DRIVER" '20261005T231205Z'
marker MATERIALIZATION_SOURCE_PIN "$DRIVER" 'adb57fa5bffb24e2fe24f4f0afc6b5550bb570f3'
marker PHH_BASE_BLOB "$DRIVER" '9f65610762fec239638bb269b8c72d6cabfc6d7e'
marker INCOMING_BASE_BLOB "$DRIVER" '5f97183b6f8c80859adf3f4922b3f9f56687bab5'
marker SYSTEM_GROUP_CEILING "$DRIVER" 'SYSTEM_GROUP_SAFE_CEILING=3263168512'
marker SOURCE_AUTH_REQUIRED "$DRIVER" 'source_mutation_requires_authorization'
marker BUILD_AUTH_REQUIRED "$DRIVER" 'build_requires_authorization'
marker SOURCE_RESTORE "$DRIVER" 'N1I_C2_SOURCE_RESTORE=PASS'
marker POSTBUILD_LINKAGE "$DRIVER" 'N1I_C2_READY_FOR_POSTBUILD_LINKAGE=YES'

PHH_BLOB="$(git -C "$ROOT" hash-object "$PHH_PATCH")"
[[ "$PHH_BLOB" == d78f41da30514920ff2165d8fe6dea15d0bb5d76 ]] ||
    fail "phh_patch_blob=$PHH_BLOB"
echo "N1I_C2_IMPLEMENTATION_CONTRACT_PHH_PATCH_BLOB=PASS"

[[ "$(grep -c '^diff --git ' "$PHH_PATCH")" -eq 1 ]] ||
    fail phh_patch_not_single_file
grep -Fq 'diff --git a/phh-on-boot.sh b/phh-on-boot.sh' "$PHH_PATCH" ||
    fail phh_patch_wrong_target
echo "N1I_C2_IMPLEMENTATION_CONTRACT_PHH_PATCH_SCOPE=PASS"

if grep -Eq -- '(^|[^A-Za-z_])(adb|fastboot)[[:space:](]' "$DRIVER" "$SCRIPT"; then
    fail device_command_surface
fi
echo "N1I_C2_IMPLEMENTATION_CONTRACT_NO_DEVICE_COMMANDS=PASS"

if grep -Eq -- 'curl|wget|requests|urllib|socket|git[[:space:]]+(fetch|pull|clone)|https?://' "$DRIVER" "$SCRIPT"; then
    fail network_surface
fi
echo "N1I_C2_IMPLEMENTATION_CONTRACT_NO_NETWORK=PASS"

if grep -Eq -- '(^|[[:space:]])(clean|clobber)([[:space:]]|$)|make[[:space:]]+(clean|clobber)' "$DRIVER"; then
    fail clean_clobber_surface
fi
echo "N1I_C2_IMPLEMENTATION_CONTRACT_NO_CLEAN_CLOBBER=PASS"

if grep -Eq -- 'git[[:space:]]+(reset|checkout|restore)[[:space:]]' "$DRIVER"; then
    fail broad_git_reset_surface
fi
echo "N1I_C2_IMPLEMENTATION_CONTRACT_NO_BROAD_GIT_RESET=PASS"

[[ "$(grep -c 'make systemimage ' "$DRIVER")" -eq 1 ]] ||
    fail systemimage_build_count
echo "N1I_C2_IMPLEMENTATION_CONTRACT_SINGLE_SYSTEMIMAGE_BUILD=PASS"

if UNAUTH_OUTPUT="$(bash "$DRIVER" 2>&1)"; then
    fail unauthorized_driver_was_accepted
else
    UNAUTH_RC=$?
fi
[[ "$UNAUTH_RC" -eq 64 ]] || fail "unauthorized_driver_rc=$UNAUTH_RC"
grep -Fq 'source_mutation_requires_authorization' <<<"$UNAUTH_OUTPUT" ||
    fail unauthorized_driver_reason
echo "N1I_C2_IMPLEMENTATION_CONTRACT_AUTHORIZATION_FAIL_CLOSED=PASS"

if TEST_OUTPUT="$(python3 "$TEST")"; then
    printf '%s\n' "$TEST_OUTPUT"
else
    fail implementation_regression
fi

for expected in     N1I_C2_IMPLEMENTATION_TEST_NATIVE_MODULE_SET=PASS     N1I_C2_IMPLEMENTATION_TEST_PRODUCT_COMPOSITION=PASS     N1I_C2_IMPLEMENTATION_TEST_INTEGRATION_SAFETY=PASS     N1I_C2_IMPLEMENTATION_TEST_INIT_MARKER=PASS     N1I_C2_IMPLEMENTATION_TEST_PATCH_AUTHORITY=PASS     N1I_C2_IMPLEMENTATION_TEST_DRIVER_AUTHORITY=PASS     N1I_C2_CELLULAR_MVP_IMPLEMENTATION_TEST=PASS
do
    grep -Fq "$expected" <<<"$TEST_OUTPUT" || fail "missing_test_marker=$expected"
done

echo "N1I_C2_IMPLEMENTATION_CONTRACT_REGRESSION=PASS"
echo "N1I_C2_CELLULAR_MVP_IMPLEMENTATION_CONTRACT=PASS"
