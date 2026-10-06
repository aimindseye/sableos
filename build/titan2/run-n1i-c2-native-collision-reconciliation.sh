#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COLLISION_AUDIT="$ROOT/build/titan2/audit-n1i-c2-install-collisions.py"
BASELINE_PROBE="$ROOT/build/titan2/probe-n1i-c2-c1-native-baseline.sh"
PLANNER="$ROOT/build/titan2/plan-n1i-c2-native-install.py"
A4_REFERENCE="$ROOT/product/titan2/n1i-c1/a4-native-superset.txt"

FAILED_OUT=""
PRODUCT_OUT=""
C1_SYSTEM=""
MATERIALIZED=""
OUT=""

fail() {
    echo "N1I_C2_NATIVE_COLLISION_RECONCILIATION=FAIL reason=$1" >&2
    return "${2:-1}"
}

usage() {
    cat <<'EOF'
Usage:
  run-n1i-c2-native-collision-reconciliation.sh \
    --failed-out DIR \
    --product-out DIR \
    --c1-system FILE \
    --materialized DIR \
    --out DIR

Host-only/read-only. Reuses the failed C2 Kati graph and sealed images.
No Android-source mutation, build, network fetch, device contact, reboot, or
flash is performed.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --failed-out)
            [[ $# -ge 2 ]] || { fail missing_failed_out 64; exit $?; }
            FAILED_OUT="$2"
            shift 2
            ;;
        --product-out)
            [[ $# -ge 2 ]] || { fail missing_product_out 64; exit $?; }
            PRODUCT_OUT="$2"
            shift 2
            ;;
        --c1-system)
            [[ $# -ge 2 ]] || { fail missing_c1_system 64; exit $?; }
            C1_SYSTEM="$2"
            shift 2
            ;;
        --materialized)
            [[ $# -ge 2 ]] || { fail missing_materialized 64; exit $?; }
            MATERIALIZED="$2"
            shift 2
            ;;
        --out)
            [[ $# -ge 2 ]] || { fail missing_out 64; exit $?; }
            OUT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "unknown_argument=$1" 64
            exit $?
            ;;
    esac
done

echo "===== N1I-C2 NATIVE COLLISION RECONCILIATION ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "REBOOT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"

for f in "$COLLISION_AUDIT" "$BASELINE_PROBE" "$PLANNER" "$A4_REFERENCE"; do
    [[ -f "$f" ]] || { fail "required_file_missing=$f" 64; exit $?; }
done
[[ -n "$FAILED_OUT" && -d "$FAILED_OUT" ]] || { fail failed_out_missing 64; exit $?; }
[[ -n "$PRODUCT_OUT" && -d "$PRODUCT_OUT" ]] || { fail product_out_missing 64; exit $?; }
[[ -n "$C1_SYSTEM" && -f "$C1_SYSTEM" ]] || { fail c1_system_missing 64; exit $?; }
[[ -n "$MATERIALIZED" && -d "$MATERIALIZED" ]] || { fail materialized_missing 64; exit $?; }
[[ -n "$OUT" ]] || { fail out_missing 64; exit $?; }
[[ ! -e "$OUT" ]] || { fail "out_exists=$OUT" 64; exit $?; }

mkdir -p "$OUT" || { fail out_create 65; exit $?; }

echo
echo "===== ENUMERATE ALL KATI INSTALL COLLISIONS ====="
python3 "$COLLISION_AUDIT"     --out-dir "$FAILED_OUT"     --product-out "$PRODUCT_OUT"     --target-list "$A4_REFERENCE"     --tsv-out "$OUT/INSTALL_COLLISIONS.tsv"     --report-only     > >(tee "$OUT/install-collision-audit.log") 2>&1
COLLISION_RC=$?
[[ "$COLLISION_RC" -eq 0 ]] ||
    { fail "collision_audit_rc=$COLLISION_RC" 66; exit $?; }

echo
echo "===== PROBE SEALED C1 BASELINE ====="
bash "$BASELINE_PROBE"     --c1-system "$C1_SYSTEM"     --materialized "$MATERIALIZED"     --out "$OUT/c1-baseline"     > >(tee "$OUT/c1-baseline-probe.log") 2>&1
BASELINE_RC=$?
[[ "$BASELINE_RC" -eq 0 ]] ||
    { fail "baseline_probe_rc=$BASELINE_RC" 67; exit $?; }

echo
echo "===== PLAN COLLISION-QUALIFIED ADMISSION ====="
python3 "$PLANNER"     --probe-tsv "$OUT/c1-baseline/NATIVE_BASELINE_PROBE.tsv"     --collision-tsv "$OUT/INSTALL_COLLISIONS.tsv"     --a4-reference "$A4_REFERENCE"     --composition-out "$OUT/NATIVE_COMPOSITION.tsv"     --packages-out "$OUT/native-packages.mk"     --admission-out "$OUT/native-admission.txt"     > >(tee "$OUT/native-plan.log") 2>&1
PLAN_RC=$?

echo "N1I_C2_NATIVE_RECONCILIATION_COLLISION_RC=$COLLISION_RC"
echo "N1I_C2_NATIVE_RECONCILIATION_BASELINE_RC=$BASELINE_RC"
echo "N1I_C2_NATIVE_RECONCILIATION_PLAN_RC=$PLAN_RC"

{
    echo "N1I_C2_NATIVE_RECONCILIATION_COLLISION_RC=$COLLISION_RC"
    echo "N1I_C2_NATIVE_RECONCILIATION_BASELINE_RC=$BASELINE_RC"
    echo "N1I_C2_NATIVE_RECONCILIATION_PLAN_RC=$PLAN_RC"
    grep -E '^N1I_C2_INSTALL_(COLLISION|SINGLE_OWNER|UNCLAIMED)_COUNT='         "$OUT/install-collision-audit.log" || true
    cat "$OUT/c1-baseline/NATIVE_BASELINE_SUMMARY.env"
    if [[ -f "$OUT/NATIVE_COMPOSITION.tsv" ]]; then
        echo "N1I_C2_NATIVE_RECONCILIATION_COMPOSITION=AVAILABLE"
    else
        echo "N1I_C2_NATIVE_RECONCILIATION_COMPOSITION=BLOCKED"
    fi
} > "$OUT/RECONCILIATION_SUMMARY.env"

(
    cd "$OUT" || exit 1
    find . -type f ! -name SHA256SUMS.txt -print0 |
        LC_ALL=C sort -z |
        xargs -0 sha256sum > SHA256SUMS.txt
    sha256sum -c SHA256SUMS.txt >/dev/null
)
SEAL_RC=$?
[[ "$SEAL_RC" -eq 0 ]] || { fail evidence_seal 68; exit $?; }

cat "$OUT/RECONCILIATION_SUMMARY.env"

if [[ "$PLAN_RC" -ne 0 ]]; then
    echo "N1I_C2_NATIVE_COLLISION_RECONCILIATION=BLOCKED_EXPLICIT_DECISION_REQUIRED"
    echo "N1I_C2_NATIVE_COLLISION_RECONCILIATION_OUT=$OUT"
    exit 3
fi

echo "N1I_C2_NATIVE_COLLISION_RECONCILIATION=PASS_CANDIDATE_ADMISSION_READY"
echo "N1I_C2_NATIVE_COLLISION_RECONCILIATION_OUT=$OUT"
