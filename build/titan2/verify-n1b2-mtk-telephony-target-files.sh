#!/usr/bin/env bash
set -euo pipefail

TARGET_FILES="${TARGET_FILES:-}"
MANIFEST="${MANIFEST:-}"
EVIDENCE_DIR="${EVIDENCE_DIR:-/tmp/SABLE_N1B2_MTK_TARGET_FILES_VERIFY_$(date -u +%Y%m%dT%H%M%SZ)}"

usage() {
  cat >&2 <<'EOF'
Usage:
  build/titan2/verify-n1b2-mtk-telephony-target-files.sh \
    --target-files ZIP \
    --manifest TSV \
    [--evidence-dir DIR]

Verifies that the staged stock-derived Titan 2 MTK telephony/IMS payload is
present in a built N1B2 target_files zip and that each zip entry hash matches the
local stock payload manifest.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-files) TARGET_FILES="$2"; shift 2 ;;
    --target-files=*) TARGET_FILES="${1#*=}"; shift ;;
    --manifest) MANIFEST="$2"; shift 2 ;;
    --manifest=*) MANIFEST="${1#*=}"; shift ;;
    --evidence-dir) EVIDENCE_DIR="$2"; shift 2 ;;
    --evidence-dir=*) EVIDENCE_DIR="${1#*=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "UNKNOWN_ARG=$1" >&2; usage; exit 2 ;;
  esac
done

[[ -f "$TARGET_FILES" ]] || { echo "N1B2_MTK_TARGET_FILES=FAIL_TARGET_FILES_REQUIRED path=$TARGET_FILES"; exit 2; }
[[ -f "$MANIFEST" ]] || { echo "N1B2_MTK_TARGET_FILES=FAIL_MANIFEST_REQUIRED path=$MANIFEST"; exit 2; }
mkdir -p "$EVIDENCE_DIR"
EVIDENCE_DIR="$(cd "$EVIDENCE_DIR" && pwd)"

REPORT="$EVIDENCE_DIR/n1b2-mtk-target-files-report.tsv"
MARKERS="$EVIDENCE_DIR/n1b2-mtk-target-files-markers.txt"

python3 - "$TARGET_FILES" "$MANIFEST" "$REPORT" <<'PY'
from __future__ import annotations
import csv
import hashlib
import sys
import zipfile

zip_path, manifest_path, report_path = sys.argv[1:4]

def target_zip_path(rel: str) -> str:
    if rel.startswith("system_ext/"):
        return "SYSTEM/system_ext/" + rel.removeprefix("system_ext/")
    if rel.startswith("product/"):
        return "SYSTEM/product/" + rel.removeprefix("product/")
    if rel.startswith("system/"):
        return "SYSTEM/" + rel.removeprefix("system/")
    raise ValueError(f"unsupported target path: {rel}")

rows = []
with open(manifest_path, "r", encoding="utf-8", newline="") as fp:
    reader = csv.DictReader(fp, delimiter="\t")
    for row in reader:
        rows.append(row)

missing = []
mismatch = []
checked = 0
with zipfile.ZipFile(zip_path) as zf, open(report_path, "w", encoding="utf-8", newline="") as out:
    writer = csv.writer(out, delimiter="\t")
    writer.writerow(["target_path", "zip_path", "expected_sha256", "actual_sha256", "status"])
    names = set(zf.namelist())
    for row in rows:
        target = row["target_path"]
        expected = row["sha256"]
        zip_entry = target_zip_path(target)
        if zip_entry not in names:
            writer.writerow([target, zip_entry, expected, "MISSING", "MISSING"])
            missing.append(zip_entry)
            continue
        actual = hashlib.sha256(zf.read(zip_entry)).hexdigest()
        checked += 1
        if actual != expected:
            writer.writerow([target, zip_entry, expected, actual, "SHA_MISMATCH"])
            mismatch.append(zip_entry)
        else:
            writer.writerow([target, zip_entry, expected, actual, "PASS"])

print(f"N1B2_MTK_TARGET_FILES_CHECKED_COUNT={checked}")
print(f"N1B2_MTK_TARGET_FILES_MISSING_COUNT={len(missing)}")
print(f"N1B2_MTK_TARGET_FILES_SHA_MISMATCH_COUNT={len(mismatch)}")
if missing:
    for item in missing:
        print(f"N1B2_MTK_TARGET_FILES_MISSING={item}")
if mismatch:
    for item in mismatch:
        print(f"N1B2_MTK_TARGET_FILES_SHA_MISMATCH={item}")
if missing or mismatch:
    print("N1B2_MTK_TARGET_FILES_PAYLOAD=FAIL")
    raise SystemExit(1)
print("N1B2_MTK_TARGET_FILES_PAYLOAD=PASS")
PY

python_rc=$?
{
  echo "N1B2_MTK_TARGET_FILES_ZIP=$TARGET_FILES"
  echo "N1B2_MTK_TARGET_FILES_MANIFEST=$MANIFEST"
  echo "N1B2_MTK_TARGET_FILES_REPORT=$REPORT"
  if [[ "$python_rc" -eq 0 ]]; then
    echo "N1B2_MTK_TARGET_FILES_VERIFY=PASS"
  else
    echo "N1B2_MTK_TARGET_FILES_VERIFY=FAIL"
  fi
} | tee "$MARKERS"

exit "$python_rc"
