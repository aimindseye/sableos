#!/usr/bin/env bash
# Physical Panther R9 runtime-audit driver.
#
# Operator safety:
# - must be executed, never sourced;
# - strict-shell failures terminate only this script process;
# - all adb invocations read stdin from /dev/null so they cannot consume
#   interactive input or a caller-provided script stream.

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    echo "R9_RUNTIME_DRIVER=REFUSED_SOURCED_SCRIPT" >&2
    echo "Run with: bash ${BASH_SOURCE[0]}" >&2
    return 64
fi

set -euo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# This runner may be materialized into /tmp or an evidence directory, so its
# own path is not a reliable repository locator. Prefer an explicit repo root;
# fall back to the canonical SableOS integration checkout.
ROOT="${R9_REPO:-/srv/data/sable-build/sableos/repo}"

[[ -d "$ROOT/.git" ]] || {
    echo "R9_REPO=FAIL path=$ROOT" >&2
    echo "R9_RUNTIME_DRIVER=FAIL" >&2
    echo "RETURNING_TO_OPERATOR_SHELL=YES" >&2
    exit 12
}

echo "R9_REPO=$ROOT"

ADB="${ADB:-/srv/data/sable-host-tools/android/r8/sdk/platform-tools/adb}"
SERIAL="${SERIAL:-${ANDROID_SERIAL:-}}"
EXPECTED_SLOT_SUFFIX="${EXPECTED_SLOT_SUFFIX:-}"
IMAGE_SOURCE="${IMAGE_SOURCE:-d35a1c9f79da1d7a0d114602f8b41fd4f799df35}"
AUDIT_REF="${R9_RUNTIME_AUDIT_REF:-039423fa7b299f75326f39911138073d6be2f453}"
EVIDENCE_ROOT="${R9_RUNTIME_EVIDENCE_ROOT:-/srv/data/sable-build/evidence/panther/r9-physical/20260921_221930}"
STAMP="$(date +%Y%m%d_%H%M%S)"
EVIDENCE_DIR="${R9_RUNTIME_EVIDENCE_DIR:-$EVIDENCE_ROOT/runtime-$STAMP}"

mkdir -p "$EVIDENCE_DIR"

fail() {
    echo "$1=FAIL ${2:-}" >&2
    echo "R9_RUNTIME_DRIVER=FAIL" >&2
    echo "RETURNING_TO_OPERATOR_SHELL=YES" >&2
    exit "${3:-1}"
}

adb_raw() {
    "$ADB" "$@" </dev/null
}

adb_cmd() {
    "$ADB" -s "$SERIAL" "$@" </dev/null
}

echo "===== R9 PANTHER PHYSICAL RUNTIME PRECHECK ====="
echo "IMAGE_SOURCE=$IMAGE_SOURCE"
echo "RUNTIME_AUDIT_REF=$AUDIT_REF"
echo "RUNTIME_EVIDENCE=$EVIDENCE_DIR"
echo "OPERATOR_PARENT_SHELL_MUTATION=NO"
echo "ADB_STDIN=/dev/null"

[[ -x "$ADB" ]] || fail R9_ADB "missing=$ADB" 10
"$ADB" version </dev/null | head -n2

echo
echo "===== DEVICE BOOT READINESS ====="

if [[ -n "$SERIAL" ]]; then
    adb_cmd wait-for-device
else
    adb_raw wait-for-device
    mapfile -t devices < <(
        "$ADB" devices </dev/null |
            awk 'NR > 1 && $2 == "device" {print $1}'
    )
    [[ "${#devices[@]}" -eq 1 ]] ||
        fail R9_ADB_DEVICE_COUNT "count=${#devices[@]}" 11
    SERIAL="${devices[0]}"
fi

echo "R9_ADB_DEVICE_SELECTED=PASS"

boot_completed=""
for _ in $(seq 1 210); do
    boot_completed="$(
        adb_cmd shell getprop sys.boot_completed 2>/dev/null |
            tr -d '\r' || true
    )"
    [[ "$boot_completed" == 1 ]] && break
    sleep 2
done

[[ "$boot_completed" == 1 ]] ||
    fail R9_BOOT_COMPLETED "value=${boot_completed:-UNAVAILABLE}" 20
echo "R9_BOOT_COMPLETED=PASS"

product="$(
    adb_cmd shell getprop ro.product.device 2>/dev/null |
        tr -d '\r'
)"
slot="$(
    adb_cmd shell getprop ro.boot.slot_suffix 2>/dev/null |
        tr -d '\r'
)"

[[ "$product" == panther ]] ||
    fail R9_DEVICE_PRODUCT "expected=panther actual=$product" 21
[[ "$slot" =~ ^_[ab]$ ]] ||
    fail R9_ACTIVE_SLOT "actual=$slot" 22

echo "R9_DEVICE_PRODUCT=PASS value=$product"
echo "R9_ACTIVE_SLOT=PASS value=$slot"

if [[ -n "$EXPECTED_SLOT_SUFFIX" && "$slot" != "$EXPECTED_SLOT_SUFFIX" ]]; then
    fail R9_EXPECTED_SLOT         "expected=$EXPECTED_SLOT_SUFFIX actual=$slot" 23
fi
if [[ -n "$EXPECTED_SLOT_SUFFIX" ]]; then
    echo "R9_EXPECTED_SLOT=PASS value=$slot"
fi

echo
echo "===== CREDENTIAL-ENCRYPTED DATA READINESS ====="

ce="$(
    adb_cmd shell getprop sys.user.0.ce_available 2>/dev/null |
        tr -d '\r' || true
)"

if [[ "$ce" != 1 && "$ce" != true ]]; then
    echo "USER_ACTION=UNLOCK_DEVICE_WITH_EXISTING_CREDENTIAL"
    for _ in $(seq 1 150); do
        ce="$(
            adb_cmd shell getprop sys.user.0.ce_available 2>/dev/null |
                tr -d '\r' || true
        )"
        [[ "$ce" == 1 || "$ce" == true ]] && break
        sleep 2
    done
fi

[[ "$ce" == 1 || "$ce" == true ]] ||
    fail R9_CE_AVAILABLE "value=${ce:-UNAVAILABLE}" 24
echo "R9_CE_AVAILABLE=PASS"

echo
echo "===== INITIAL BOOT IDENTITY ====="

{
    for prop in         ro.product.device         ro.boot.slot_suffix         ro.build.id         ro.build.fingerprint         ro.boot.verifiedbootstate         ro.boot.vbmeta.device_state         ro.boot.flash.locked
    do
        value="$(
            adb_cmd shell getprop "$prop" 2>/dev/null |
                tr -d '\r'
        )"
        echo "$prop=$value"
    done
} | tee "$EVIDENCE_DIR/boot-identity.txt"

echo
echo "===== MATERIALIZE SOURCE-BOUND RUNTIME AUDIT ====="

git -C "$ROOT" cat-file -e "${AUDIT_REF}^{commit}" ||
    fail R9_RUNTIME_AUDIT_REF "missing=$AUDIT_REF" 30

AUDIT_SCRIPT="$EVIDENCE_DIR/r9_final_ui_runtime_audit.sh"
git -C "$ROOT" show     "$AUDIT_REF:tests/systemui/device/r9_final_ui_runtime_audit.sh"     > "$AUDIT_SCRIPT"

chmod 0700 "$AUDIT_SCRIPT"
bash -n "$AUDIT_SCRIPT" ||
    fail R9_RUNTIME_AUDIT_SCRIPT_SYNTAX "" 31

sha256sum "$AUDIT_SCRIPT" |
    tee "$EVIDENCE_DIR/runtime-audit-script.sha256"

echo "R9_RUNTIME_AUDIT_SCRIPT=PASS"

echo
echo "===== R9 FINAL UI RUNTIME AUDIT ====="

set +e
ADB="$ADB" ANDROID_SERIAL="$SERIAL" bash "$AUDIT_SCRIPT"     </dev/null     2>&1 |
    tee "$EVIDENCE_DIR/r9-final-ui-runtime-audit.log"
AUDIT_RC=${PIPESTATUS[0]}
set -e

echo "R9_RUNTIME_AUDIT_RC=$AUDIT_RC" |
    tee "$EVIDENCE_DIR/runtime-audit-result.txt"

if [[ "$AUDIT_RC" -ne 0 ]]; then
    echo "R9_PHYSICAL_RUNTIME_IDENTITY=FAIL"
    echo "DEVICE_MUTATION_PERFORMED=NO"
    echo "RETURNING_TO_OPERATOR_SHELL=YES"
    exit "$AUDIT_RC"
fi

echo "R9_PHYSICAL_RUNTIME_IDENTITY=PASS"
echo "DEVICE_MUTATION_PERFORMED=NO"
echo "RUNTIME_EVIDENCE=$EVIDENCE_DIR"
echo "R9_RUNTIME_DRIVER=PASS"
echo "RETURNING_TO_OPERATOR_SHELL=YES"
