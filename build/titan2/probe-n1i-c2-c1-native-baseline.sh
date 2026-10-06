#!/usr/bin/env bash
# Read-only probe of the exact sealed C1 system image against the 33 frozen
# N1I-C2 native compatibility targets.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/build/config/storage.env"
source "$ROOT/build/config/host-tools.env"

C1_SHA="137bc8771c817c0afb3122d9f03e7a94575e03bcccc643b56235edd1075f2160"
EXPECTED_NATIVE_COUNT=33

C1_SYSTEM=""
MATERIALIZED=""
OUT=""

fail() {
    echo "N1I_C2_C1_NATIVE_BASELINE_PROBE=FAIL reason=$1" >&2
    return "${2:-1}"
}

usage() {
    cat <<'EOF'
Usage:
  probe-n1i-c2-c1-native-baseline.sh \
    --c1-system FILE \
    --materialized DIR \
    --out DIR

Read-only host probe. No Android-source mutation, build, network, device
contact, reboot, or flash is performed.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
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

echo "===== N1I-C2 C1 NATIVE BASELINE PROBE ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "REBOOT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"

[[ -n "$C1_SYSTEM" && -f "$C1_SYSTEM" ]] ||
    { fail c1_system_missing 64; exit $?; }
[[ -n "$MATERIALIZED" && -d "$MATERIALIZED" ]] ||
    { fail materialized_missing 64; exit $?; }
[[ -n "$OUT" ]] || { fail out_missing 64; exit $?; }
[[ ! -e "$OUT" ]] || { fail "out_exists=$OUT" 64; exit $?; }

for file in \
    "$MATERIALIZED/CELLULAR_MVP_STOCK_MATERIALIZATION.tsv" \
    "$MATERIALIZED/CELLULAR_MVP_MATERIALIZATION_SUMMARY.env" \
    "$MATERIALIZED/SHA256SUMS.txt"
do
    [[ -f "$file" ]] ||
        { fail "required_materialization_file=$file" 64; exit $?; }
done

C1_ACTUAL_SHA="$(sha256sum "$C1_SYSTEM" | awk '{print $1}')"
[[ "$C1_ACTUAL_SHA" == "$C1_SHA" ]] ||
    { fail "c1_sha expected=$C1_SHA actual=$C1_ACTUAL_SHA" 65; exit $?; }

(
    cd "$MATERIALIZED" || exit 1
    sha256sum -c SHA256SUMS.txt >/dev/null
)
SEAL_RC=$?
[[ "$SEAL_RC" -eq 0 ]] || { fail materialization_seal 65; exit $?; }

grep -Fxq \
    "N1I_C2_MATERIALIZATION_NATIVE_FILE_COUNT=$EXPECTED_NATIVE_COUNT" \
    "$MATERIALIZED/CELLULAR_MVP_MATERIALIZATION_SUMMARY.env" ||
    { fail materialization_native_count 65; exit $?; }

bash "$ROOT/build/host/verify-host-tools.sh" aosp-host >/dev/null
HOST_RC=$?
[[ "$HOST_RC" -eq 0 ]] || { fail "host_tools_rc=$HOST_RC" 65; exit $?; }

image_type() {
    local img="$1"
    if [[ "$(od -An -tx1 -j 0 -N 4 "$img" 2>/dev/null | tr -d ' \n')" == 3aff26ed ]]; then
        echo sparse
    elif [[ "$(od -An -tx1 -j 1080 -N 2 "$img" 2>/dev/null | tr -d ' \n')" == 53ef ]]; then
        echo ext4
    elif [[ "$(od -An -tx1 -j 1024 -N 4 "$img" 2>/dev/null | tr -d ' \n')" == e2e1f5e0 ]]; then
        echo erofs
    else
        echo unknown
    fi
}

extract_fs() {
    local img="$1"
    local dest="$2"
    local kind raw rc
    kind="$(image_type "$img")"
    mkdir -p "$dest" || return 1
    case "$kind" in
        sparse)
            raw="$dest.raw.img"
            "$SABLE_SIMG2IMG" "$img" "$raw" >/dev/null 2>&1
            rc=$?
            [[ "$rc" -eq 0 ]] || return "$rc"
            extract_fs "$raw" "$dest"
            rc=$?
            rm -f "$raw"
            return "$rc"
            ;;
        ext4)
            debugfs -R "rdump / $dest" "$img" >/dev/null 2>"$dest.debugfs.log"
            return $?
            ;;
        erofs)
            fsck.erofs --extract="$dest" "$img" >/dev/null 2>"$dest.erofs.log"
            return $?
            ;;
        *)
            return 1
            ;;
    esac
}

OUT="$(realpath -m "$OUT")"
mkdir -p "$OUT" || { fail out_create 66; exit $?; }
WORK="$(mktemp -d "$OUT/.work.XXXXXX")"
[[ -d "$WORK" ]] || { fail work_create 66; exit $?; }

cleanup() {
    rm -rf --one-file-system "$WORK" >/dev/null 2>&1 || true
}
trap cleanup EXIT

extract_fs "$C1_SYSTEM" "$WORK/c1"
EXTRACT_RC=$?
[[ "$EXTRACT_RC" -eq 0 ]] || { fail "c1_extract_rc=$EXTRACT_RC" 66; exit $?; }

if [[ -f "$WORK/c1/system/build.prop" ]]; then
    C1_ROOT="$WORK/c1/system"
else
    C1_ROOT="$WORK/c1"
fi

python3 - \
    "$MATERIALIZED/CELLULAR_MVP_STOCK_MATERIALIZATION.tsv" \
    "$C1_ROOT" \
    "$OUT/NATIVE_BASELINE_PROBE.tsv" \
    "$OUT/NATIVE_BASELINE_SUMMARY.env" <<'PY'
import csv
import hashlib
import pathlib
import sys

materialization = pathlib.Path(sys.argv[1])
c1_root = pathlib.Path(sys.argv[2])
out_tsv = pathlib.Path(sys.argv[3])
out_env = pathlib.Path(sys.argv[4])


def sha256(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fp:
        for chunk in iter(lambda: fp.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


with materialization.open(encoding="utf-8", newline="") as fp:
    rows = [
        row
        for row in csv.DictReader(fp, delimiter="\t")
        if row.get("kind") == "NATIVE"
    ]

if len(rows) != 33:
    raise SystemExit(
        f"N1I_C2_C1_NATIVE_BASELINE_PROBE=FAIL_NATIVE_ROWS count={len(rows)}"
    )


def image_path(target: str) -> pathlib.Path:
    if target.startswith("/system_ext/"):
        return c1_root / "system_ext" / target.removeprefix("/system_ext/")
    if target.startswith("/product/"):
        return c1_root / "product" / target.removeprefix("/product/")
    if target.startswith("/system/"):
        return c1_root / target.removeprefix("/system/")
    raise ValueError(target)


out_rows = []
present = absent = identical = different = 0
for row in rows:
    mid = row["mutation_id"]
    target = row["target"]
    stock_sha = row["sha256"]
    path = image_path(target)
    if path.is_file():
        status = "PRESENT"
        c1_sha = sha256(path)
        present += 1
        if c1_sha == stock_sha:
            identical += 1
        else:
            different += 1
    else:
        status = "ABSENT"
        c1_sha = "-"
        absent += 1
    out_rows.append(
        {
            "id": mid,
            "target": target,
            "module": f"SableN1IC2Native{mid}",
            "stock_sha256": stock_sha,
            "c1_status": status,
            "c1_sha256": c1_sha,
            "c1_image_path": str(path),
        }
    )

fields = [
    "id",
    "target",
    "module",
    "stock_sha256",
    "c1_status",
    "c1_sha256",
    "c1_image_path",
]
with out_tsv.open("w", encoding="utf-8", newline="") as fp:
    writer = csv.DictWriter(
        fp,
        fieldnames=fields,
        delimiter="\t",
        lineterminator="\n",
    )
    writer.writeheader()
    writer.writerows(out_rows)

summary = {
    "N1I_C2_C1_NATIVE_TARGET_COUNT": str(len(out_rows)),
    "N1I_C2_C1_NATIVE_PRESENT_COUNT": str(present),
    "N1I_C2_C1_NATIVE_ABSENT_COUNT": str(absent),
    "N1I_C2_C1_NATIVE_IDENTICAL_COUNT": str(identical),
    "N1I_C2_C1_NATIVE_DIFFERENT_COUNT": str(different),
    "N1I_C2_C1_NATIVE_BASELINE_PROBE": "PASS",
}
with out_env.open("w", encoding="utf-8") as fp:
    for key, value in summary.items():
        fp.write(f"{key}={value}\n")

for key, value in summary.items():
    print(f"{key}={value}")
PY
PROBE_RC=$?
[[ "$PROBE_RC" -eq 0 ]] || { fail "probe_python_rc=$PROBE_RC" 67; exit $?; }

(
    cd "$OUT" || exit 1
    sha256sum NATIVE_BASELINE_PROBE.tsv NATIVE_BASELINE_SUMMARY.env > SHA256SUMS.txt
    sha256sum -c SHA256SUMS.txt >/dev/null
)
OUT_SEAL_RC=$?
[[ "$OUT_SEAL_RC" -eq 0 ]] || { fail output_seal 67; exit $?; }

cleanup
trap - EXIT

cat "$OUT/NATIVE_BASELINE_SUMMARY.env"
echo "N1I_C2_C1_NATIVE_BASELINE_PROBE=PASS"
echo "N1I_C2_C1_NATIVE_BASELINE_OUT=$OUT"
