#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PREFLIGHT="$ROOT/build/titan2/run-n1i-c2-native-install-preflight.sh"
BASELINE_PROBE="$ROOT/build/titan2/probe-n1i-c2-c1-native-baseline.sh"
AUDIT="$ROOT/build/titan2/audit-n1i-c2-install-collisions.py"
AUDIT_TEST="$ROOT/tests/titan2/n1i-c2/test-install-collision-audit.py"
PLANNER="$ROOT/build/titan2/plan-n1i-c2-native-install.py"
PLANNER_TEST="$ROOT/tests/titan2/n1i-c2/test-native-install-plan.py"
A4="$ROOT/product/titan2/n1i-c1/a4-native-superset.txt"
DRIVER="$ROOT/build/titan2/run-n1i-c2-cellular-mvp.sh"

fail() {
    echo "N1I_C2_NATIVE_INSTALL_PREFLIGHT_CONTRACT=FAIL reason=$*" >&2
    exit 1
}

marker() {
    local name="$1"
    local file="$2"
    local value="$3"
    grep -Fq -- "$value" "$file" || fail "missing_marker=$name"
    echo "N1I_C2_NATIVE_PREFLIGHT_CONTRACT_$name=PASS"
}

for file in     "$PREFLIGHT"     "$BASELINE_PROBE"     "$AUDIT"     "$AUDIT_TEST"     "$PLANNER"     "$PLANNER_TEST"     "$A4"     "$DRIVER"
do
    [[ -f "$file" ]] || fail "missing_file=$file"
done

echo "===== N1I-C2 NATIVE INSTALL PREFLIGHT CONTRACT ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "REBOOT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"

for shell_file in "$PREFLIGHT" "$BASELINE_PROBE"; do
    bash -n "$shell_file" || fail "shell_syntax=$shell_file"
done
echo "N1I_C2_NATIVE_PREFLIGHT_CONTRACT_SHELL_SYNTAX=PASS"

PYTHONPYCACHEPREFIX="${TMPDIR:-/tmp}/sable-pycache"     python3 -m py_compile "$AUDIT" "$AUDIT_TEST" "$PLANNER" "$PLANNER_TEST"
echo "N1I_C2_NATIVE_PREFLIGHT_CONTRACT_PYTHON_SYNTAX=PASS"

marker C1_SHA "$PREFLIGHT"     '137bc8771c817c0afb3122d9f03e7a94575e03bcccc643b56235edd1075f2160'
marker MATERIALIZATION "$PREFLIGHT"     'n1i-c2-cellular-mvp-stock/20261005T231205Z'
marker FAILED_SOURCE "$PREFLIGHT"     '36b53950faebc954cadb30756833ae5ec857f054'
marker FAILED_GRAPH "$PREFLIGHT"     'out-n1i-c2-36b53950faeb'
marker KNOWN_COLLISION_ID "$PREFLIGHT"     'KNOWN_KATI_COLLISION_ID="M029"'
marker KNOWN_COLLISION_TARGET "$PREFLIGHT"     'KNOWN_KATI_COLLISION_TARGET="/system/lib64/android.hardware.drm-V1-ndk.so"'
marker BASELINE_PROBE "$PREFLIGHT"     'probe-n1i-c2-c1-native-baseline.sh'
marker COMPLETE_GRAPH "$PREFLIGHT"     'INSTALL_COLLISIONS.tsv'
marker COMPLETE_COMPOSITION "$PREFLIGHT"     'NATIVE_COMPOSITION.tsv'
marker GENERATED_PACKAGES "$PREFLIGHT"     'native-packages.mk'
marker GENERATED_ADMISSION "$PREFLIGHT"     'native-admission.txt'
marker READ_ONLY_RESULT "$PREFLIGHT"     'N1I_C2_NATIVE_INSTALL_PREFLIGHT=PASS_READ_ONLY_ANALYSIS'
marker BLOCKED_RESULT "$PREFLIGHT"     'BLOCKED_EXPLICIT_DECISION_REQUIRED'
marker PASS_RESULT "$PREFLIGHT"     'PASS_CANDIDATE_ADMISSION_READY'

if grep -Eq -- '(^|[^A-Za-z_])(adb|fastboot)[[:space:](]'     "$PREFLIGHT" "$BASELINE_PROBE" "$AUDIT" "$PLANNER"; then
    fail device_command_surface
fi
echo "N1I_C2_NATIVE_PREFLIGHT_CONTRACT_NO_DEVICE_COMMANDS=PASS"

if grep -Eq --     'curl|wget|requests|urllib|socket|git[[:space:]]+(fetch|pull|clone)|https?://'     "$PREFLIGHT" "$BASELINE_PROBE" "$AUDIT" "$PLANNER"; then
    fail network_surface
fi
echo "N1I_C2_NATIVE_PREFLIGHT_CONTRACT_NO_NETWORK=PASS"

if grep -Eq --     '(^|[[:space:]])(m|mm|mmm|make|ninja|soong_ui\.bash)([[:space:]]|$)'     "$PREFLIGHT" "$BASELINE_PROBE"; then
    fail build_surface
fi
echo "N1I_C2_NATIVE_PREFLIGHT_CONTRACT_NO_BUILD=PASS"

if grep -Eq --     'git[[:space:]]+(apply|reset|checkout|restore)|install[[:space:]]+-m'     "$PREFLIGHT" "$BASELINE_PROBE"; then
    fail source_mutation_surface
fi
echo "N1I_C2_NATIVE_PREFLIGHT_CONTRACT_NO_SOURCE_MUTATION=PASS"

if AUDIT_OUTPUT="$(python3 "$AUDIT_TEST")"; then
    printf '%s\n' "$AUDIT_OUTPUT"
else
    fail collision_audit_regression
fi
grep -Fq 'N1I_C2_INSTALL_COLLISION_AUDIT_TEST=PASS' <<<"$AUDIT_OUTPUT" ||
    fail collision_audit_regression_marker

if PLAN_OUTPUT="$(python3 "$PLANNER_TEST")"; then
    printf '%s\n' "$PLAN_OUTPUT"
else
    fail native_plan_regression
fi
for expected in     'N1I_C2_NATIVE_INSTALL_PLAN_KNOWN_KATI_COLLISION_REUSE=PASS'     'N1I_C2_NATIVE_INSTALL_PLAN_GRAPH_COLLISION_FAIL_CLOSED=PASS'     'N1I_C2_NATIVE_INSTALL_PLAN_DIFFERENT_BASELINE_FAIL_CLOSED=PASS'     'N1I_C2_NATIVE_INSTALL_PLAN_GENERATED_PACKAGES=PASS'     'N1I_C2_NATIVE_INSTALL_PLAN_OWNER_IDENTITY=PASS'     'N1I_C2_NATIVE_INSTALL_PLAN_TEST=PASS'
do
    grep -Fq "$expected" <<<"$PLAN_OUTPUT" ||
        fail "native_plan_regression_marker=$expected"
done

marker ADMISSION_INITIAL_STATE "$DRIVER" 'NATIVE_ADMISSION_INTEGRATED=NO'
marker ADMISSION_BOUND_TRANSITION "$DRIVER" 'NATIVE_ADMISSION_INTEGRATED=YES'
marker PREFLIGHT_BOUND_TO_BUILD "$DRIVER" 'N1I_C2_NATIVE_INSTALL_PREFLIGHT=PASS_BOUND_TO_BUILD'
marker GENERATED_PACKAGES_STAGE "$DRIVER" 'install -m 0644 "$NATIVE_PACKAGES" "$C2_STAGE/native-packages.mk"'

python3 - "$DRIVER" <<'PY'
import pathlib
import sys

text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
needles = {
    "preflight": 'echo "===== N1I-C2 NATIVE INSTALL COLLISION PREFLIGHT ====="',
    "admit": "NATIVE_ADMISSION_INTEGRATED=YES",
    "stage": 'echo "===== STAGE C3B + C1 + FROZEN C2 BUNDLE ====="',
    "mutate": 'echo "===== APPLY EXACT C2 SOURCE DELTA ====="',
    "build": 'echo "===== BUILD ONE ANDROID 16 CELLULAR MVP SYSTEMIMAGE ====="',
}
positions = {name: text.find(value) for name, value in needles.items()}
missing = [name for name, pos in positions.items() if pos < 0]
if missing:
    raise SystemExit("missing_order_marker=" + ",".join(missing))
if not (
    positions["preflight"]
    < positions["admit"]
    < positions["stage"]
    < positions["mutate"]
    < positions["build"]
):
    raise SystemExit(f"unsafe_preflight_order={positions}")
print("N1I_C2_NATIVE_PREFLIGHT_CONTRACT_ORDER=PASS_BEFORE_MUTATION_AND_BUILD")
PY

[[ "$(grep -c 'make systemimage ' "$DRIVER")" -eq 1 ]] ||
    fail implementation_driver_build_count
[[ "$(grep -c '^selfcheck() {' "$DRIVER")" -eq 1 ]] ||
    fail implementation_driver_selfcheck_count
[[ "$(grep -c '===== BUILD ONE ANDROID 16 CELLULAR MVP SYSTEMIMAGE =====' "$DRIVER")" -eq 1 ]] ||
    fail implementation_driver_build_marker_count

python3 - "$DRIVER" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
lines = path.read_text(encoding="utf-8").splitlines()
starts = []
i = 0
while i < len(lines):
    if "<<'PY'" not in lines[i]:
        i += 1
        continue
    start = i + 1
    starts.append(start)
    i += 1
    body = []
    while i < len(lines) and lines[i] != "PY":
        body.append(lines[i])
        i += 1
    if i >= len(lines):
        raise SystemExit(f"unterminated_python_heredoc={start}")
    compile("\n".join(body) + "\n", f"{path}:heredoc:{start}", "exec")
    i += 1

if len(starts) != 4:
    raise SystemExit(f"embedded_python_count={len(starts)} starts={starts}")
print("N1I_C2_NATIVE_PREFLIGHT_CONTRACT_RELEASE_DRIVER_SINGLE_PATH=PASS")
PY

echo "N1I_C2_NATIVE_PREFLIGHT_CONTRACT_REGRESSION=PASS"
echo "N1I_C2_NATIVE_INSTALL_PREFLIGHT_CONTRACT=PASS"
