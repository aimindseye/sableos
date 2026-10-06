#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DRIVER="$ROOT/build/titan2/run-n1i-c2-cellular-mvp.sh"
TEST="$ROOT/tests/titan2/n1i-c2/test-cellular-mvp-implementation.py"
INSTALL_COLLISION_AUDIT="$ROOT/build/titan2/audit-n1i-c2-install-collisions.py"
INSTALL_COLLISION_TEST="$ROOT/tests/titan2/n1i-c2/test-install-collision-audit.py"
NATIVE_PREFLIGHT="$ROOT/build/titan2/run-n1i-c2-native-install-preflight.sh"
BASELINE_PROBE="$ROOT/build/titan2/probe-n1i-c2-c1-native-baseline.sh"
NATIVE_INSTALL_PLANNER="$ROOT/build/titan2/plan-n1i-c2-native-install.py"
NATIVE_INSTALL_PLAN_TEST="$ROOT/tests/titan2/n1i-c2/test-native-install-plan.py"
BUILD_REGRESSION="$ROOT/build/gates/build-regression-contract.py"
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

for f in "$DRIVER" "$TEST" "$INSTALL_COLLISION_AUDIT" "$INSTALL_COLLISION_TEST" "$NATIVE_PREFLIGHT" "$BASELINE_PROBE" "$NATIVE_INSTALL_PLANNER" "$NATIVE_INSTALL_PLAN_TEST" "$BUILD_REGRESSION" "$BP" "$MK" "$SCRIPT" "$RC" "$MARKER" "$PHH_PATCH"; do
    [[ -f "$f" ]] || fail "missing_file=$f"
done

echo "===== N1I-C2 CELLULAR MVP IMPLEMENTATION CONTRACT ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO_BY_CONTRACT"
echo "BUILD_AUTHORIZED=NO_BY_CONTRACT"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "REBOOT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "N1I_C2_BUILD_RETRY_AUTHORIZED=NO_PENDING_NATIVE_PREFLIGHT_ADMISSION"

for shell_file in "$DRIVER" "$SCRIPT" "$NATIVE_PREFLIGHT" "$BASELINE_PROBE"; do
    bash -n "$shell_file" || fail "shell_syntax=$shell_file"
done
echo "N1I_C2_IMPLEMENTATION_CONTRACT_SHELL_SYNTAX=PASS"

PYTHONPYCACHEPREFIX="${TMPDIR:-/tmp}/sable-pycache"     python3 -m py_compile "$TEST" "$INSTALL_COLLISION_AUDIT" "$INSTALL_COLLISION_TEST" "$NATIVE_INSTALL_PLANNER" "$NATIVE_INSTALL_PLAN_TEST"
echo "N1I_C2_IMPLEMENTATION_CONTRACT_PYTHON_SYNTAX=PASS"

python3 - "$DRIVER" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
lines = path.read_text(encoding="utf-8").splitlines()
blocks = []
i = 0
while i < len(lines):
    line = lines[i]
    if "<<'PY'" not in line:
        i += 1
        continue
    start = i + 1
    i += 1
    body = []
    while i < len(lines) and lines[i] != "PY":
        body.append(lines[i])
        i += 1
    if i >= len(lines):
        raise SystemExit(f"unterminated_python_heredoc_at_line={start}")
    source = "\n".join(body) + "\n"
    compile(source, f"{path}:heredoc:{start}", "exec")
    blocks.append(start)
    i += 1

if len(blocks) != 4:
    raise SystemExit(f"unexpected_python_heredoc_count={len(blocks)} starts={blocks}")
print(f"N1I_C2_IMPLEMENTATION_CONTRACT_EMBEDDED_PYTHON_SYNTAX=PASS blocks={len(blocks)}")
PY

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
marker UA_START_MODE "$SCRIPT" 'SABLE_TITAN2_VENDOR_UA_START_MODE'
marker UA_AUTO_START_READY "$SCRIPT" 'UA_OK=YES'
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
marker C1_IMAGE_PIN "$DRIVER" '137bc8771c817c0afb3122d9f03e7a94575e03bcccc643b56235edd1075f2160'
marker MMTEL_OVERLAY_MODULE "$DRIVER" 'treble-overlay-telephony-mtk-ims'
marker MMTEL_OVERLAY_PACKAGE "$DRIVER" 'me.phh.treble.overlay.mtkims_telephony'
marker IMPLEMENTATION_RECEIPT "$DRIVER" 'CELLULAR_MVP_IMPLEMENTATION_RECEIPT.tsv'
marker IMPLEMENTATION_RECEIPT_ROWS "$DRIVER" 'IMPLEMENTATION_RECEIPT_ROWS=41'
marker STOCK_MAP_A4_EXACT "$DRIVER" 'N1I_C2_STOCK_MAP=FAIL_A4_TARGET_SET'
marker PLATFORM_RESIGN "$DRIVER" 'N1I_C2_OEM_IMS_PLATFORM_RESIGN=PASS'
marker EMERGENCY_SOURCE_RESTORE "$DRIVER" 'N1I_C2_EMERGENCY_SOURCE_RESTORE=PASS'
marker PLATFORM_RESIGN_ARTIFACT "$DRIVER" 'OEM_IMS_PLATFORM_RESIGNED=YES'
marker BUILD_REGRESSION_PREFLIGHT "$DRIVER" 'N1I_C2_BUILD_REGRESSION_PREFLIGHT=PASS'
marker RETRY_BLOCKED_PENDING_ADMISSION "$DRIVER" 'NATIVE_ADMISSION_INTEGRATED=NO'
marker RETRY_BLOCK_REASON "$DRIVER" 'native_admission_not_integrated'
marker INSTALL_COLLISION_AUDIT "$NATIVE_PREFLIGHT" 'audit-n1i-c2-install-collisions.py'
marker NATIVE_INSTALL_PLANNER "$NATIVE_PREFLIGHT" 'plan-n1i-c2-native-install.py'
marker NATIVE_BASELINE_PROBE "$NATIVE_PREFLIGHT" 'NATIVE_BASELINE_PROBE.tsv'
marker NATIVE_COMPOSITION "$NATIVE_PREFLIGHT" 'NATIVE_COMPOSITION.tsv'
marker BASELINE_PROBE_C1_SHA "$BASELINE_PROBE" '137bc8771c817c0afb3122d9f03e7a94575e03bcccc643b56235edd1075f2160'
marker BASELINE_PROBE_OUTPUT "$BASELINE_PROBE" 'NATIVE_BASELINE_PROBE.tsv'
marker BASELINE_PROBE_PASS "$BASELINE_PROBE" 'N1I_C2_C1_NATIVE_BASELINE_PROBE=PASS'
marker NATIVE_PACKAGES_GENERATED "$MK" 'vendor/sable/titan2/n1i-c2/native-packages.mk'
marker SEALED_C1_BASELINE "$NATIVE_PREFLIGHT" 'n1i-c1-cellular-isolation/20261005T133622Z-a745c7daa082-postbuild'
marker PRIOR_FAILED_GRAPH "$NATIVE_PREFLIGHT" '36b53950faebc954cadb30756833ae5ec857f054'
marker KNOWN_KATI_TARGET "$NATIVE_PREFLIGHT" '/system/lib64/android.hardware.drm-V1-ndk.so'
marker PREFLIGHT_PASS "$NATIVE_PREFLIGHT" 'N1I_C2_NATIVE_INSTALL_PREFLIGHT=PASS'
marker SOURCE_AUTH_REQUIRED "$DRIVER" 'source_mutation_requires_authorization'
marker BUILD_AUTH_REQUIRED "$DRIVER" 'build_requires_authorization'
marker SOURCE_RESTORE "$DRIVER" 'N1I_C2_SOURCE_RESTORE=PASS'
marker C3A_FULL_RESTORE "$DRIVER" 'N1I_C2_C3A_SOURCE_RESTORE=PASS_EXACT'
marker POSTBUILD_LINKAGE "$DRIVER" 'N1I_C2_READY_FOR_POSTBUILD_LINKAGE=YES'
marker EVIDENCE_SEAL "$DRIVER" 'N1I_C2_EVIDENCE_SEAL=PASS_EXCLUDES_BUILD_LOG'
marker SCOPED_TMETRICS_DIFF "$DRIVER" 'diff --check -- "$TMETRICS_REL"'
marker SCOPED_PHH_DIFF "$DRIVER" 'diff --check -- "$PHH_REL"'

PHH_BLOB="$(git -C "$ROOT" hash-object "$PHH_PATCH")"
[[ "$PHH_BLOB" == d78f41da30514920ff2165d8fe6dea15d0bb5d76 ]] ||
    fail "phh_patch_blob=$PHH_BLOB"
echo "N1I_C2_IMPLEMENTATION_CONTRACT_PHH_PATCH_BLOB=PASS"

[[ "$(grep -c '^diff --git ' "$PHH_PATCH")" -eq 1 ]] ||
    fail phh_patch_not_single_file
grep -Fq 'diff --git a/phh-on-boot.sh b/phh-on-boot.sh' "$PHH_PATCH" ||
    fail phh_patch_wrong_target
echo "N1I_C2_IMPLEMENTATION_CONTRACT_PHH_PATCH_SCOPE=PASS"

if grep -Eq -- '(^|[^A-Za-z_])(adb|fastboot)[[:space:](]' "$DRIVER" "$SCRIPT" "$NATIVE_PREFLIGHT"; then
    fail device_command_surface
fi
echo "N1I_C2_IMPLEMENTATION_CONTRACT_NO_DEVICE_COMMANDS=PASS"

if grep -Eq -- 'curl|wget|requests|urllib|socket|git[[:space:]]+(fetch|pull|clone)|https?://' "$DRIVER" "$SCRIPT" "$NATIVE_PREFLIGHT"; then
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

if BUILD_REGRESSION_OUTPUT="$(python3 "$BUILD_REGRESSION")"; then
    printf '%s\n' "$BUILD_REGRESSION_OUTPUT"
else
    printf '%s\n' "$BUILD_REGRESSION_OUTPUT"
    fail shared_build_regression_contract
fi
grep -Fq 'SABLE_BUILD_REGRESSION_CONTRACT=PASS' <<<"$BUILD_REGRESSION_OUTPUT" ||
    fail shared_build_regression_marker
echo "N1I_C2_IMPLEMENTATION_CONTRACT_SHARED_BUILD_REGRESSION=PASS"

if COLLISION_TEST_OUTPUT="$(python3 "$INSTALL_COLLISION_TEST")"; then
    printf '%s\n' "$COLLISION_TEST_OUTPUT"
else
    fail install_collision_audit_regression
fi
grep -Fq 'N1I_C2_INSTALL_COLLISION_AUDIT_TEST=PASS' <<<"$COLLISION_TEST_OUTPUT" ||
    fail install_collision_audit_marker
echo "N1I_C2_IMPLEMENTATION_CONTRACT_INSTALL_COLLISION_REGRESSION=PASS"

if NATIVE_PLAN_OUTPUT="$(python3 "$NATIVE_INSTALL_PLAN_TEST")"; then
    printf '%s\n' "$NATIVE_PLAN_OUTPUT"
else
    fail native_install_plan_regression
fi
grep -Fq 'N1I_C2_NATIVE_INSTALL_PLAN_KNOWN_KATI_COLLISION_REUSE=PASS' <<<"$NATIVE_PLAN_OUTPUT" ||
    fail native_install_known_kati_reuse_marker
grep -Fq 'N1I_C2_NATIVE_INSTALL_PLAN_GRAPH_COLLISION_FAIL_CLOSED=PASS' <<<"$NATIVE_PLAN_OUTPUT" ||
    fail native_install_graph_collision_marker
grep -Fq 'N1I_C2_NATIVE_INSTALL_PLAN_DIFFERENT_FAIL_CLOSED=PASS' <<<"$NATIVE_PLAN_OUTPUT" ||
    fail native_install_different_fail_closed_marker
grep -Fq 'N1I_C2_NATIVE_INSTALL_PLAN_OWNER_IDENTITY=PASS' <<<"$NATIVE_PLAN_OUTPUT" ||
    fail native_install_owner_identity_marker
grep -Fq 'N1I_C2_NATIVE_INSTALL_PLAN_TEST=PASS' <<<"$NATIVE_PLAN_OUTPUT" ||
    fail native_install_plan_marker
echo "N1I_C2_IMPLEMENTATION_CONTRACT_NATIVE_INSTALL_PLAN_REGRESSION=PASS"

if TEST_OUTPUT="$(python3 "$TEST")"; then
    printf '%s\n' "$TEST_OUTPUT"
else
    fail implementation_regression
fi

for expected in     N1I_C2_IMPLEMENTATION_TEST_NATIVE_MODULE_SET=PASS     N1I_C2_IMPLEMENTATION_TEST_PRODUCT_COMPOSITION=PASS     N1I_C2_IMPLEMENTATION_TEST_INTEGRATION_SAFETY=PASS     N1I_C2_IMPLEMENTATION_TEST_INIT_MARKER=PASS     N1I_C2_IMPLEMENTATION_TEST_PATCH_AUTHORITY=PASS     N1I_C2_IMPLEMENTATION_TEST_DRIVER_AUTHORITY=PASS     N1I_C2_IMPLEMENTATION_TEST_NATIVE_PREFLIGHT_AUTHORITY=PASS     N1I_C2_IMPLEMENTATION_TEST_RECEIPT_SEMANTICS=PASS     N1I_C2_CELLULAR_MVP_IMPLEMENTATION_TEST=PASS
do
    grep -Fq "$expected" <<<"$TEST_OUTPUT" || fail "missing_test_marker=$expected"
done

echo "N1I_C2_IMPLEMENTATION_CONTRACT_REGRESSION=PASS"
echo "N1I_C2_CELLULAR_MVP_IMPLEMENTATION_CONTRACT=PASS"
