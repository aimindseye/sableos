#!/usr/bin/env bash
# Titan 2 N1I-C2 native install ownership preflight.
#
# Read-only host qualification. It binds the frozen 33-native materialization
# to the sealed C1 system image and the retained failed C2 Kati install graph.
# It never mutates Android source, builds, uses the network, contacts a device,
# reboots, or flashes.
set -u
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/build/config/storage.env"
source "$ROOT/build/config/host-tools.env"

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
PLANNER="$ROOT/build/titan2/plan-n1i-c2-native-install.py"
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

No source/build/device/network/reboot/flash authority is required or granted.
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

[[ -f "$C1_CONTROL" ]] || { fail c1_system_missing 64; exit $?; }
[[ "$(sha256sum "$C1_CONTROL" | awk '{print $1}')" == "$C1_SHA" ]] ||
    { fail c1_system_sha 65; exit $?; }
[[ -f "$C1_CONTROL_DIR/SHA256SUMS.txt" ]] ||
    { fail c1_seal_missing 65; exit $?; }
(
    cd "$C1_CONTROL_DIR" || exit 1
    sha256sum -c SHA256SUMS.txt >/dev/null
)
C1_SEAL_RC=$?
[[ "$C1_SEAL_RC" -eq 0 ]] || { fail c1_seal 65; exit $?; }

for file in \
    "$MATERIALIZED/CELLULAR_MVP_STOCK_MATERIALIZATION.tsv" \
    "$MATERIALIZED/CELLULAR_MVP_MATERIALIZATION_SUMMARY.env" \
    "$MATERIALIZED/SHA256SUMS.txt" \
    "$PRIOR_FAILED_INSTALLS" \
    "$A4" \
    "$AUDIT" \
    "$PLANNER"
do
    [[ -f "$file" ]] || { fail "required_file_missing=$file" 64; exit $?; }
done

(
    cd "$MATERIALIZED" || exit 1
    sha256sum -c SHA256SUMS.txt >/dev/null
)
MAT_SEAL_RC=$?
[[ "$MAT_SEAL_RC" -eq 0 ]] || { fail materialization_seal 65; exit $?; }

grep -Fxq 'N1I_C2_MATERIALIZATION_NATIVE_FILE_COUNT=33' \
    "$MATERIALIZED/CELLULAR_MVP_MATERIALIZATION_SUMMARY.env" ||
    { fail materialization_native_count 65; exit $?; }

[[ -d "$PRIOR_FAILED_OUT/soong" && -d "$PRIOR_FAILED_PRODUCT_OUT" ]] ||
    { fail prior_failed_graph_missing 65; exit $?; }

bash "$ROOT/build/host/verify-host-tools.sh" aosp-host >/dev/null
HOST_RC=$?
[[ "$HOST_RC" -eq 0 ]] || { fail "host_tools_rc=$HOST_RC" 65; exit $?; }
command -v debugfs >/dev/null 2>&1 ||
    { fail debugfs_missing 65; exit $?; }

if [[ -z "$OUT" ]]; then
    STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
    OUT="$SABLE_EVIDENCE_ROOT/titan2/n1i-c2-native-install-preflight/$STAMP"
fi
OUT="$(realpath -m "$OUT")"
[[ ! -e "$OUT" ]] || { fail "out_exists=$OUT" 64; exit $?; }
mkdir -p "$OUT" || { fail out_create 66; exit $?; }

WORK="$OUT/work"
mkdir -p "$WORK" || { fail work_create 66; exit $?; }

cleanup() {
    rm -rf --one-file-system "$WORK" >/dev/null 2>&1 || true
}
trap cleanup EXIT

python3 - \
    "$MATERIALIZED/CELLULAR_MVP_STOCK_MATERIALIZATION.tsv" \
    "$A4" \
    "$OUT/stock-native-map.tsv" <<'PY'
import csv
import pathlib
import sys

materialization = pathlib.Path(sys.argv[1])
a4 = pathlib.Path(sys.argv[2])
out = pathlib.Path(sys.argv[3])

targets = [
    line.strip()
    for line in a4.read_text(encoding="utf-8").splitlines()
    if line.strip() and not line.lstrip().startswith("#")
]
if len(targets) != 33 or len(set(targets)) != 33:
    raise SystemExit(
        f"N1I_C2_NATIVE_INSTALL_PREFLIGHT=FAIL_A4 count={len(targets)}"
    )

with materialization.open(encoding="utf-8", newline="") as fp:
    rows = [
        row for row in csv.DictReader(fp, delimiter="\t")
        if row.get("kind") == "NATIVE"
    ]

if len(rows) != 33:
    raise SystemExit(
        f"N1I_C2_NATIVE_INSTALL_PREFLIGHT=FAIL_MATERIALIZATION count={len(rows)}"
    )

by_target = {row["target"]: row for row in rows}
if set(by_target) != set(targets):
    raise SystemExit("N1I_C2_NATIVE_INSTALL_PREFLIGHT=FAIL_TARGET_SET")

with out.open("w", encoding="utf-8", newline="") as fp:
    writer = csv.DictWriter(
        fp,
        fieldnames=["id", "target", "module", "stock_sha256"],
        delimiter="\t",
        lineterminator="\n",
    )
    writer.writeheader()
    for target in targets:
        row = by_target[target]
        writer.writerow({
            "id": row["mutation_id"],
            "target": target,
            "module": f"SableN1IC2Native{row['mutation_id']}",
            "stock_sha256": row["sha256"],
        })

print("N1I_C2_NATIVE_STOCK_MAP=PASS count=33")
PY
MAP_RC=$?
[[ "$MAP_RC" -eq 0 ]] || { fail "stock_map_rc=$MAP_RC" 67; exit $?; }

dump_c1_target() {
    local target="$1"
    local dest="$2"
    local candidate
    local -a candidates=()

    case "$target" in
        /system/*)
            candidates=("${target#/system}" "$target")
            ;;
        /system_ext/*)
            candidates=("$target" "/system$target")
            ;;
        /product/*)
            candidates=("$target" "/system$target")
            ;;
        *)
            return 2
            ;;
    esac

    for candidate in "${candidates[@]}"; do
        rm -f "$dest" "$dest.debugfs.log"
        debugfs -R "dump -p $candidate $dest" "$C1_CONTROL" \
            >/dev/null 2>"$dest.debugfs.log"
        if [[ -s "$dest" ]]; then
            rm -f "$dest.debugfs.log"
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    rm -f "$dest" "$dest.debugfs.log"
    return 1
}

printf 'id\ttarget\tmodule\tstock_sha256\tc1_status\tc1_sha256\tc1_image_path\n' \
    > "$OUT/native-baseline-probe.tsv"

{
    IFS= read -r _header
    while IFS=$'\t' read -r id target module stock_sha; do
        [[ -n "$id" ]] || continue
        c1_file="$WORK/$id.bin"
        c1_path="$(dump_c1_target "$target" "$c1_file")"
        DUMP_RC=$?
        if [[ "$DUMP_RC" -eq 0 ]]; then
            c1_sha="$(sha256sum "$c1_file" | awk '{print $1}')"
            printf '%s\t%s\t%s\t%s\tPRESENT\t%s\t%s\n' \
                "$id" "$target" "$module" "$stock_sha" "$c1_sha" "$c1_path"
        elif [[ "$DUMP_RC" -eq 1 ]]; then
            printf '%s\t%s\t%s\t%s\tABSENT\t-\t-\n' \
                "$id" "$target" "$module" "$stock_sha"
        else
            exit 1
        fi
    done
} < "$OUT/stock-native-map.tsv" >> "$OUT/native-baseline-probe.tsv"
PROBE_RC=$?
[[ "$PROBE_RC" -eq 0 ]] || { fail "baseline_probe_rc=$PROBE_RC" 67; exit $?; }

find "$PRIOR_FAILED_OUT/soong" -maxdepth 1 -type f -name 'installs-*.mk' -print0 |
    LC_ALL=C sort -z |
    xargs -0 sha256sum > "$OUT/prior-failed-install-graph.sha256"
GRAPH_HASH_RC=$?
[[ "$GRAPH_HASH_RC" -eq 0 && -s "$OUT/prior-failed-install-graph.sha256" ]] ||
    { fail prior_graph_hash 67; exit $?; }

python3 "$AUDIT" \
    --out-dir "$PRIOR_FAILED_OUT" \
    --product-out "$PRIOR_FAILED_PRODUCT_OUT" \
    --target-list "$A4" \
    --report-only \
    --tsv-out "$OUT/install-collision-prior.tsv" \
    > "$OUT/install-collision-prior.log" 2>&1
AUDIT_RC=$?
cat "$OUT/install-collision-prior.log"
[[ "$AUDIT_RC" -eq 0 ]] || { fail "collision_audit_rc=$AUDIT_RC" 67; exit $?; }

python3 "$PLANNER" \
    --probe-tsv "$OUT/native-baseline-probe.tsv" \
    --collision-tsv "$OUT/install-collision-prior.tsv" \
    --a4-reference "$A4" \
    --composition-out "$OUT/native-composition.tsv" \
    --packages-out "$OUT/native-packages.mk" \
    --admission-out "$OUT/native-admission.txt"
PLAN_RC=$?
[[ "$PLAN_RC" -eq 0 ]] || { fail "native_plan_rc=$PLAN_RC" 68; exit $?; }

ROWS="$(awk 'NR>1 {c++} END {print c+0}' "$OUT/native-composition.tsv")"
REUSE="$(awk -F '\t' 'NR>1 && $11=="REUSE_C1_IDENTICAL" {c++} END {print c+0}' "$OUT/native-composition.tsv")"
IMPORTS="$(awk -F '\t' 'NR>1 && $11=="IMPORT_FROZEN_STOCK" {c++} END {print c+0}' "$OUT/native-composition.tsv")"
[[ "$ROWS" -eq 33 && $((REUSE + IMPORTS)) -eq 33 ]] ||
    { fail "composition_count rows=$ROWS reuse=$REUSE imports=$IMPORTS" 68; exit $?; }

KNOWN_ROW="$(awk -F '\t' -v t="$KNOWN_KATI_COLLISION_TARGET" \
    'NR>1 && $2==t {print $0}' "$OUT/native-composition.tsv")"
[[ -n "$KNOWN_ROW" ]] || { fail known_kati_target_missing 68; exit $?; }

echo "N1I_C2_KNOWN_KATI_COLLISION_CLASSIFICATION=$KNOWN_ROW"
echo "N1I_C2_NATIVE_BASELINE_REUSE_COUNT=$REUSE"
echo "N1I_C2_NATIVE_IMPORT_COUNT=$IMPORTS"

cleanup
trap - EXIT

cat > "$OUT/PREFLIGHT_SUMMARY.env" <<EOF
N1I_C2_NATIVE_INSTALL_PREFLIGHT_VERSION=1
N1I_C2_C1_SYSTEM_SHA256=$C1_SHA
N1I_C2_MATERIALIZATION_SOURCE_COMMIT=$MATERIALIZATION_SOURCE_COMMIT
N1I_C2_PRIOR_FAILED_SOURCE_COMMIT=$PRIOR_FAILED_SOURCE_COMMIT
N1I_C2_NATIVE_TARGET_COUNT=33
N1I_C2_NATIVE_BASELINE_REUSE_COUNT=$REUSE
N1I_C2_NATIVE_IMPORT_COUNT=$IMPORTS
N1I_C2_KNOWN_KATI_COLLISION_TARGET=$KNOWN_KATI_COLLISION_TARGET
N1I_C2_NATIVE_INSTALL_PREFLIGHT=PASS
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

echo "N1I_C2_NATIVE_INSTALL_PREFLIGHT=PASS"
echo "N1I_C2_NATIVE_INSTALL_PREFLIGHT_OUT=$OUT"
