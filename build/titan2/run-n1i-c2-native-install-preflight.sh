#!/usr/bin/env bash
# Titan 2 N1I-C2 native install ownership preflight.
#
# Read-only host qualification. Binds:
#   * exact sealed C1 system image,
#   * exact frozen 33-native C2 materialization,
#   * retained failed C2 Kati install graph.
#
# It does not mutate Android source, build, use the network, contact a device,
# reboot, or flash.
set -u
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/build/config/storage.env"

C1_SHA="137bc8771c817c0afb3122d9f03e7a94575e03bcccc643b56235edd1075f2160"
C1_CONTROL_DIR="$SABLE_ARTIFACTS_ROOT/titan2/n1i-c1-cellular-isolation/20261005T133622Z-a745c7daa082-postbuild"
C1_CONTROL="$C1_CONTROL_DIR/system.img"

MATERIALIZED="/srv/data/sable-build/titan2/artifacts/n1i-c2-cellular-mvp-stock/20261005T231205Z"
MATERIALIZATION_SOURCE_COMMIT="adb57fa5bffb24e2fe24f4f0afc6b5550bb570f3"

PRIOR_FAILED_SOURCE_COMMIT="36b53950faebc954cadb30756833ae5ec857f054"
PRIOR_FAILED_OUT="$SABLE_WORKSPACES_ROOT/titan2-n1d/out-n1i-c2-36b53950faeb"
PRIOR_FAILED_PRODUCT_OUT="$PRIOR_FAILED_OUT/target/product/tdgsi_arm64_ab"
PRIOR_FAILED_INSTALLS="$PRIOR_FAILED_OUT/soong/installs-treble_arm64_bvN.mk"

A4="$ROOT/product/titan2/n1i-c1/a4-native-superset.txt"
AUDIT="$ROOT/build/titan2/audit-n1i-c2-install-collisions.py"
BASELINE_PROBE="$ROOT/build/titan2/probe-n1i-c2-c1-native-baseline.sh"
PLANNER="$ROOT/build/titan2/plan-n1i-c2-native-install.py"

KNOWN_KATI_COLLISION_ID="M029"
KNOWN_KATI_COLLISION_TARGET="/system/lib64/android.hardware.drm-V1-ndk.so"

OUT=""

fail() {
    echo "N1I_C2_NATIVE_INSTALL_PREFLIGHT=FAIL reason=$1" >&2
    return "${2:-1}"
}

usage() {
    cat <<'EOF'
Usage:
  run-n1i-c2-native-install-preflight.sh [--out DIR]

This command is read-only. It grants no source/build/device/network/reboot/
flash authority.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --out)
            [[ $# -ge 2 ]] || { fail missing_out_value 64; exit $?; }
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

echo "===== N1I-C2 NATIVE INSTALL OWNERSHIP PREFLIGHT ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "REBOOT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"

for file in     "$C1_CONTROL"     "$C1_CONTROL_DIR/SHA256SUMS.txt"     "$MATERIALIZED/CELLULAR_MVP_STOCK_MATERIALIZATION.tsv"     "$MATERIALIZED/CELLULAR_MVP_MATERIALIZATION_SUMMARY.env"     "$MATERIALIZED/SHA256SUMS.txt"     "$PRIOR_FAILED_INSTALLS"     "$A4"     "$AUDIT"     "$BASELINE_PROBE"     "$PLANNER"
do
    [[ -f "$file" ]] || { fail "required_file_missing=$file" 64; exit $?; }
done

[[ "$(sha256sum "$C1_CONTROL" | awk '{print $1}')" == "$C1_SHA" ]] ||
    { fail c1_system_sha 65; exit $?; }

(
    cd "$C1_CONTROL_DIR" || exit 1
    sha256sum -c SHA256SUMS.txt >/dev/null
)
C1_SEAL_RC=$?
[[ "$C1_SEAL_RC" -eq 0 ]] || { fail c1_seal 65; exit $?; }

(
    cd "$MATERIALIZED" || exit 1
    sha256sum -c SHA256SUMS.txt >/dev/null
)
MAT_SEAL_RC=$?
[[ "$MAT_SEAL_RC" -eq 0 ]] || { fail materialization_seal 65; exit $?; }

grep -Fxq 'N1I_C2_MATERIALIZATION_NATIVE_FILE_COUNT=33'     "$MATERIALIZED/CELLULAR_MVP_MATERIALIZATION_SUMMARY.env" ||
    { fail materialization_native_count 65; exit $?; }

[[ -d "$PRIOR_FAILED_OUT/soong" && -d "$PRIOR_FAILED_PRODUCT_OUT" ]] ||
    { fail prior_failed_graph_missing 65; exit $?; }

if [[ -z "$OUT" ]]; then
    STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
    OUT="$SABLE_EVIDENCE_ROOT/titan2/n1i-c2-native-install-preflight/$STAMP"
fi
OUT="$(realpath -m "$OUT")"
[[ ! -e "$OUT" ]] || { fail "out_exists=$OUT" 64; exit $?; }
mkdir -p "$OUT" || { fail out_create 66; exit $?; }

echo
echo "===== HASH RETAINED FAILED INSTALL GRAPH ====="

sha256sum "$PRIOR_FAILED_INSTALLS" > "$OUT/prior-failed-install-graph.sha256"
GRAPH_HASH_RC=$?
[[ "$GRAPH_HASH_RC" -eq 0 && -s "$OUT/prior-failed-install-graph.sha256" ]] ||
    { fail prior_graph_hash 66; exit $?; }

echo "N1I_C2_PRIOR_FAILED_GRAPH=PASS_HASHED_EXACT file=$PRIOR_FAILED_INSTALLS"

echo
echo "===== PROBE EXACT SEALED C1 BASELINE ====="

bash "$BASELINE_PROBE"     --c1-system "$C1_CONTROL"     --materialized "$MATERIALIZED"     --out "$OUT/c1-baseline"     > >(tee "$OUT/c1-baseline.log") 2>&1
BASELINE_RC=$?
[[ "$BASELINE_RC" -eq 0 ]] ||
    { fail "baseline_probe_rc=$BASELINE_RC" 67; exit $?; }

echo
echo "===== ENUMERATE COMPLETE RETAINED KATI OWNERSHIP GRAPH ====="

python3 "$AUDIT" \
    --out-dir "$PRIOR_FAILED_OUT" \
    --product-out "$PRIOR_FAILED_PRODUCT_OUT" \
    --target-list "$A4" \
    --installs-file "$PRIOR_FAILED_INSTALLS" \
    --tsv-out "$OUT/INSTALL_COLLISIONS.tsv" \
    --report-only \
    > >(tee "$OUT/install-collision-audit.log") 2>&1
AUDIT_RC=$?
[[ "$AUDIT_RC" -eq 0 ]] ||
    { fail "collision_audit_rc=$AUDIT_RC" 67; exit $?; }

echo
echo "===== PLAN COMPLETE COLLISION-QUALIFIED NATIVE COMPOSITION ====="

python3 "$PLANNER"     --probe-tsv "$OUT/c1-baseline/NATIVE_BASELINE_PROBE.tsv"     --collision-tsv "$OUT/INSTALL_COLLISIONS.tsv"     --a4-reference "$A4"     --composition-out "$OUT/NATIVE_COMPOSITION.tsv"     --packages-out "$OUT/native-packages.mk"     --admission-out "$OUT/native-admission.txt"     > >(tee "$OUT/native-plan.log") 2>&1
PLAN_RC=$?

COLLISION_COUNT="$(
    sed -n 's/^N1I_C2_INSTALL_COLLISION_COUNT=//p'         "$OUT/install-collision-audit.log" |
        tail -1
)"
SINGLE_OWNER_COUNT="$(
    sed -n 's/^N1I_C2_INSTALL_SINGLE_OWNER_COUNT=//p'         "$OUT/install-collision-audit.log" |
        tail -1
)"
UNCLAIMED_COUNT="$(
    sed -n 's/^N1I_C2_INSTALL_UNCLAIMED_COUNT=//p'         "$OUT/install-collision-audit.log" |
        tail -1
)"

[[ "$COLLISION_COUNT" =~ ^[0-9]+$ ]] ||
    { fail collision_count_parse 68; exit $?; }
[[ "$SINGLE_OWNER_COUNT" =~ ^[0-9]+$ ]] ||
    { fail single_owner_count_parse 68; exit $?; }
[[ "$UNCLAIMED_COUNT" =~ ^[0-9]+$ ]] ||
    { fail unclaimed_count_parse 68; exit $?; }
[[ $((COLLISION_COUNT + SINGLE_OWNER_COUNT + UNCLAIMED_COUNT)) -eq 33 ]] ||
    { fail install_graph_count_total 68; exit $?; }

BASELINE_SUMMARY="$OUT/c1-baseline/NATIVE_BASELINE_SUMMARY.env"
[[ -f "$BASELINE_SUMMARY" ]] ||
    { fail baseline_summary_missing 68; exit $?; }

if [[ "$PLAN_RC" -eq 0 ]]; then
    [[ -f "$OUT/NATIVE_COMPOSITION.tsv" ]] ||
        { fail composition_missing 68; exit $?; }

    ROWS="$(awk 'NR>1 {c++} END {print c+0}' "$OUT/NATIVE_COMPOSITION.tsv")"
    REUSE="$(awk -F '\t' 'NR>1 && $11=="REUSE_C1_IDENTICAL" {c++} END {print c+0}' "$OUT/NATIVE_COMPOSITION.tsv")"
    IMPORTS="$(awk -F '\t' 'NR>1 && $11=="IMPORT_FROZEN_STOCK" {c++} END {print c+0}' "$OUT/NATIVE_COMPOSITION.tsv")"

    [[ "$ROWS" -eq 33 && $((REUSE + IMPORTS)) -eq 33 ]] ||
        { fail "composition_count rows=$ROWS reuse=$REUSE imports=$IMPORTS" 68; exit $?; }

    KNOWN_ROW="$(
        awk -F '\t'             -v id="$KNOWN_KATI_COLLISION_ID"             -v target="$KNOWN_KATI_COLLISION_TARGET"             'NR>1 && $1==id && $2==target {print $0}'             "$OUT/NATIVE_COMPOSITION.tsv"
    )"
    [[ -n "$KNOWN_ROW" ]] || { fail known_kati_target_missing 68; exit $?; }

    echo "N1I_C2_KNOWN_KATI_COLLISION_CLASSIFICATION=$KNOWN_ROW"
    echo "N1I_C2_NATIVE_BASELINE_REUSE_COUNT=$REUSE"
    echo "N1I_C2_NATIVE_IMPORT_COUNT=$IMPORTS"

    PLAN_STATE=PASS_CANDIDATE_ADMISSION_READY
else
    REUSE=BLOCKED
    IMPORTS=BLOCKED
    KNOWN_ROW=UNAVAILABLE_PLAN_BLOCKED
    PLAN_STATE=BLOCKED_EXPLICIT_DECISION_REQUIRED
fi

cat > "$OUT/PREFLIGHT_SUMMARY.env" <<EOF
N1I_C2_NATIVE_INSTALL_PREFLIGHT_VERSION=2
N1I_C2_C1_SYSTEM_SHA256=$C1_SHA
N1I_C2_MATERIALIZATION_SOURCE_COMMIT=$MATERIALIZATION_SOURCE_COMMIT
N1I_C2_PRIOR_FAILED_SOURCE_COMMIT=$PRIOR_FAILED_SOURCE_COMMIT
N1I_C2_NATIVE_TARGET_COUNT=33
N1I_C2_INSTALL_COLLISION_COUNT=$COLLISION_COUNT
N1I_C2_INSTALL_SINGLE_OWNER_COUNT=$SINGLE_OWNER_COUNT
N1I_C2_INSTALL_UNCLAIMED_COUNT=$UNCLAIMED_COUNT
N1I_C2_NATIVE_BASELINE_REUSE_COUNT=$REUSE
N1I_C2_NATIVE_IMPORT_COUNT=$IMPORTS
N1I_C2_KNOWN_KATI_COLLISION_ID=$KNOWN_KATI_COLLISION_ID
N1I_C2_KNOWN_KATI_COLLISION_TARGET=$KNOWN_KATI_COLLISION_TARGET
N1I_C2_NATIVE_INSTALL_PLAN_STATE=$PLAN_STATE
N1I_C2_NATIVE_INSTALL_PREFLIGHT=PASS_READ_ONLY_ANALYSIS
EOF

(
    cd "$OUT" || exit 1
    find . -type f ! -name SHA256SUMS.txt -print0 |
        LC_ALL=C sort -z |
        xargs -0 sha256sum > SHA256SUMS.txt
    sha256sum -c SHA256SUMS.txt >/dev/null
)
SEAL_RC=$?
[[ "$SEAL_RC" -eq 0 ]] || { fail output_seal 68; exit $?; }

echo
cat "$OUT/PREFLIGHT_SUMMARY.env"
echo "N1I_C2_NATIVE_INSTALL_PREFLIGHT_OUT=$OUT"

if [[ "$PLAN_RC" -ne 0 ]]; then
    echo "N1I_C2_NATIVE_INSTALL_PREFLIGHT=BLOCKED_EXPLICIT_DECISION_REQUIRED"
    exit 3
fi

echo "N1I_C2_NATIVE_INSTALL_PREFLIGHT=PASS_CANDIDATE_ADMISSION_READY"
