#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STORAGE_PROFILE="$ROOT/build/config/storage.env"
HOST_TOOLS_PROFILE="$ROOT/build/config/host-tools.env"
N1I_A_AUDIT="$ROOT/build/titan2/audit-n1i-a-v010014-oem-ims.sh"
DERIVER="$ROOT/build/titan2/derive-n1i-c1-runtime-classpath.py"
AUDIT="$ROOT/build/titan2/audit-n1i-c1-runtime-linkage.py"
APEX_PARITY="$ROOT/build/titan2/audit-n1i-c1-apex-runtime-parity.py"

source "$STORAGE_PROFILE"
source "$HOST_TOOLS_PROFILE"

PRODUCT_OUT=""
OUT=""

ACCEPTED_N1I_A="/srv/sable-build/evidence/titan2/n1i-a-oem-ims/20261005T002256Z"
C3A_HISTORY="/srv/sable-build/artifacts/titan2/c3a-boot-qualified/20261003T221350Z"
STOCK_REF_AUTHORITY="N1I_A_AUTO_RESOLVE_CONFIGURED_TEE14"

EXPECTED_N1I_A_AUDIT_BLOB="02f7b7330b468a31be8cfc60551673cad127313e"
EXPECTED_C3A_SHA="4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16"
EXPECTED_C3A_BYTES="3146977280"
EXPECTED_C1_SHA="137bc8771c817c0afb3122d9f03e7a94575e03bcccc643b56235edd1075f2160"
EXPECTED_C1_BYTES="3210661888"

fail() {
  echo "N1I_C1_RUNTIME_LINKAGE_DRIVER=FAIL reason=$1" >&2
  exit "${2:-2}"
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --product-out)
      [[ "$#" -ge 2 ]] || fail missing_product_out_value 64
      PRODUCT_OUT="$2"; shift 2 ;;
    --out)
      [[ "$#" -ge 2 ]] || fail missing_out_value 64
      OUT="$2"; shift 2 ;;
    *)
      fail "unknown_argument=$1" 64 ;;
  esac
done

[[ -n "$PRODUCT_OUT" ]] || fail product_out_required 64
[[ -d "$PRODUCT_OUT" ]] || fail "product_out_missing=$PRODUCT_OUT" 64
PRODUCT_OUT="$(cd "$PRODUCT_OUT" && pwd -P)"

for path in \
  "$HOST_TOOLS_PROFILE" \
  "$N1I_A_AUDIT" \
  "$DERIVER" \
  "$AUDIT" \
  "$APEX_PARITY" \
  "$ACCEPTED_N1I_A/n1i-a-v010014-oem-ims.env" \
  "$ACCEPTED_N1I_A/a3-framework-jars.tsv" \
  "$C3A_HISTORY/system.img" \
  "$C3A_HISTORY/SHA256SUMS.txt"
do
  [[ -f "$path" ]] || fail "required_file_missing=$path" 64
done

[[ -d "$PRODUCT_OUT/system/apex" ]] || fail "c1_packaged_apex_missing=$PRODUCT_OUT/system/apex" 65

for tool in git sha256sum stat cmp tee awk grep; do
  command -v "$tool" >/dev/null 2>&1 || fail "required_tool_missing=$tool" 64
done

[[ -x "$SABLE_PYTHON" ]] || fail "canonical_python_missing=$SABLE_PYTHON" 64
AAPT2="$SABLE_ANDROID_BUILD_TOOLS/aapt2"
[[ -x "$AAPT2" ]] || fail "canonical_aapt2_missing=$AAPT2" 64
[[ -x "$SABLE_SIMG2IMG" ]] || fail "canonical_simg2img_missing=$SABLE_SIMG2IMG" 64

N1I_A_BLOB="$(git -C "$ROOT" hash-object "$N1I_A_AUDIT")"
[[ "$N1I_A_BLOB" == "$EXPECTED_N1I_A_AUDIT_BLOB" ]] ||
  fail "n1i_a_audit_blob_mismatch=expected:$EXPECTED_N1I_A_AUDIT_BLOB:actual:$N1I_A_BLOB" 65

(
  cd "$C3A_HISTORY"
  sha256sum -c SHA256SUMS.txt >/dev/null
) || fail c3a_history_seal_invalid 65

C3A_SYSTEM="$C3A_HISTORY/system.img"
[[ "$(sha256sum "$C3A_SYSTEM" | awk '{print $1}')" == "$EXPECTED_C3A_SHA" ]] ||
  fail c3a_history_system_sha_mismatch 65
[[ "$(stat -c '%s' "$C3A_SYSTEM")" == "$EXPECTED_C3A_BYTES" ]] ||
  fail c3a_history_system_bytes_mismatch 65

C1_SYSTEM="$PRODUCT_OUT/system.img"
[[ -f "$C1_SYSTEM" ]] || fail "c1_system_missing=$C1_SYSTEM" 65
[[ "$(sha256sum "$C1_SYSTEM" | awk '{print $1}')" == "$EXPECTED_C1_SHA" ]] ||
  fail c1_system_sha_mismatch 65
[[ "$(stat -c '%s' "$C1_SYSTEM")" == "$EXPECTED_C1_BYTES" ]] ||
  fail c1_system_bytes_mismatch 65

ACCEPTED_ENV="$ACCEPTED_N1I_A/n1i-a-v010014-oem-ims.env"
for expected in \
  'N1I_A_V010014_OEM_IMS_DEPENDENCY_CLOSURE=PASS' \
  'N1I_A_FRAMEWORK_DEPENDENCY_CLOSURE=PASS' \
  'REQUIRED_JARS="/system_ext/framework/mediatek-common.jar /system_ext/framework/mediatek-ims-base.jar"' \
  'OPTIONAL_JARS=NONE' \
  'APK_REFS_UNRESOLVED_COUNT=0' \
  'APK_REFS_UNRESOLVED_MEDIATEK_COUNT=0' \
  'APK_REFS_INTO_STOCK_AOSP_FRAMEWORK_JARS_NOT_IN_C3A=0'
do
  grep -Fxq -- "$expected" "$ACCEPTED_ENV" ||
    fail "accepted_n1i_a_authority_missing=$expected" 65
done

if [[ -z "$OUT" ]]; then
  OUT="$SABLE_EVIDENCE_ROOT/titan2/n1i-c1-runtime-linkage-v6/$(date -u +%Y%m%dT%H%M%SZ)"
fi
[[ ! -e "$OUT" ]] || fail "evidence_dir_already_exists=$OUT" 64
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd -P)"

REPLAY="$OUT/n1i-a-replay"
REPLAY_LOG="$OUT/n1i-a-replay.log"
MANIFEST="$OUT/bootclasspath-materialized.tsv"
BOOT_HASHES="$OUT/bootclasspath-sha256.tsv"
BADGING="$OUT/ims-badging.txt"
DERIVE_LOG="$OUT/runtime-classpath-derivation.txt"
RESULT="$OUT/runtime-linkage.txt"
STOCK_REF_RECORD="$OUT/stock-ref-resolution.txt"
APEX_PARITY_DIR="$OUT/apex-runtime-parity"
APEX_PARITY_LOG="$OUT/apex-runtime-parity.log"

echo "===== N1I-C1 RUNTIME LINKAGE V6 ====="
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "PRODUCT_OUT=$PRODUCT_OUT"
echo "ACCEPTED_N1I_A=$ACCEPTED_N1I_A"
echo "C3A_HISTORY=$C3A_HISTORY"
echo "N1I_C1_STOCK_REF_AUTHORITY=$STOCK_REF_AUTHORITY"
echo "N1I_C1_RUNTIME_LINKAGE_CONTROL=SEALED_C3A_HISTORY_PLUS_PROVEN_N1I_A_REPLAY"
echo "N1I_C1_N1I_A_AUDIT_BLOB=$N1I_A_BLOB"
echo "N1I_C1_C3A_HISTORY_SEAL=PASS"
echo "N1I_C1_C3A_HISTORY_SYSTEM_SHA=PASS"
echo "N1I_C1_C1_SYSTEM_SHA=PASS"
echo "EVIDENCE_DIR=$OUT"
echo "SABLE_PYTHON=$SABLE_PYTHON"
echo "AAPT2=$AAPT2"
echo "N1I_C1_AAPT2_AUTHORITY=SABLE_ANDROID_BUILD_TOOLS"

echo
echo "===== REPLAY PROVEN N1I-A AGAINST SEALED C3A HISTORY ====="
set +e
bash "$N1I_A_AUDIT" \
  --c3a-system "$C3A_SYSTEM" \
  --out "$REPLAY" 2>&1 | tee "$REPLAY_LOG"
REPLAY_RC="${PIPESTATUS[0]}"
set -e
[[ "$REPLAY_RC" -eq 0 ]] || fail "n1i_a_replay_rc=$REPLAY_RC" 66

REPLAY_ENV="$REPLAY/n1i-a-v010014-oem-ims.env"
[[ -f "$REPLAY_ENV" ]] || fail replay_env_missing 66
[[ -f "$REPLAY/a3-framework-jars.tsv" ]] || fail replay_a3_framework_missing 66
[[ -f "$REPLAY/inputs.tsv" ]] || fail replay_inputs_missing 66
[[ -d "$REPLAY/work/c3a/system_img" ]] || fail replay_c3a_work_missing 66
[[ -d "$REPLAY/work/apex/c3a" ]] || fail replay_apex_work_missing 66

mapfile -t STOCK_PRODUCT_PATHS < <(
  awk -F '\t' '$1 == "product.img" {print $2}' "$REPLAY/inputs.tsv"
)
[[ "${#STOCK_PRODUCT_PATHS[@]}" -eq 1 ]] ||
  fail "replay_stock_product_path_count=${#STOCK_PRODUCT_PATHS[@]}" 66
STOCK_PRODUCT_PATH="${STOCK_PRODUCT_PATHS[0]}"
case "$STOCK_PRODUCT_PATH" in
  */product.img) STOCK_REF="${STOCK_PRODUCT_PATH%/product.img}" ;;
  *) fail "replay_stock_product_path_invalid=$STOCK_PRODUCT_PATH" 66 ;;
esac
for stock_name in product.img system.img system_ext.img vendor.img; do
  [[ -f "$STOCK_REF/$stock_name" ]] ||
    fail "replay_stock_input_missing=$STOCK_REF/$stock_name" 66
done
{
  echo "N1I_C1_STOCK_REF_AUTHORITY=$STOCK_REF_AUTHORITY"
  echo "N1I_C1_STOCK_REF_RESOLVED=$STOCK_REF"
  awk -F '\t' '
    NR == 1 || $1 == "product.img" || $1 == "stock-system.img" ||
    $1 == "system_ext.img" || $1 == "vendor.img"
  ' "$REPLAY/inputs.tsv"
} > "$STOCK_REF_RECORD"
echo "N1I_C1_STOCK_REF_RESOLVED=$STOCK_REF"

for expected in \
  'N1I_A_V010014_OEM_IMS_DEPENDENCY_CLOSURE=PASS' \
  'N1I_A_FRAMEWORK_DEPENDENCY_CLOSURE=PASS' \
  'REQUIRED_JARS="/system_ext/framework/mediatek-common.jar /system_ext/framework/mediatek-ims-base.jar"' \
  'OPTIONAL_JARS=NONE' \
  'APK_REFS_UNRESOLVED_COUNT=0' \
  'APK_REFS_UNRESOLVED_MEDIATEK_COUNT=0' \
  'APK_REFS_INTO_STOCK_AOSP_FRAMEWORK_JARS_NOT_IN_C3A=0'
do
  grep -Fxq -- "$expected" "$REPLAY_ENV" ||
    fail "replayed_n1i_a_authority_mismatch=$expected" 66
done

cmp -s "$ACCEPTED_N1I_A/a3-framework-jars.tsv" "$REPLAY/a3-framework-jars.tsv" ||
  fail n1i_a_replay_a3_framework_differs_from_accepted 66

"$SABLE_PYTHON" - "$ACCEPTED_ENV" "$REPLAY_ENV" <<'PY'
from pathlib import Path
import sys

keys = (
    "C3A_APEX_JAVALIB_JARS_INDEXED",
    "OEM_MTKIMS_PORT_FEASIBILITY",
    "APK_REFS_UNRESOLVED_COUNT",
    "APK_REFS_UNRESOLVED_MEDIATEK_COUNT",
    "APK_REFS_INTO_STOCK_AOSP_FRAMEWORK_JARS_NOT_IN_C3A",
)

def read(path):
    out = {}
    for raw in Path(path).read_text(encoding="utf-8").splitlines():
        if "=" in raw:
            key, value = raw.split("=", 1)
            out[key] = value
    return out

accepted = read(sys.argv[1])
replay = read(sys.argv[2])

for key in keys:
    if key not in accepted or key not in replay:
        raise SystemExit(f"missing_replay_parity_key={key}")
    if accepted[key] != replay[key]:
        raise SystemExit(
            f"replay_parity_mismatch={key}:"
            f"accepted={accepted[key]}:replay={replay[key]}"
        )

count = int(replay["C3A_APEX_JAVALIB_JARS_INDEXED"])
if count <= 0:
    raise SystemExit("replay_apex_javalib_count_not_positive")

print("N1I_C1_N1I_A_REPLAY_PARITY=PASS")
print(f"N1I_C1_REPLAY_APEX_JAVALIB_JARS_INDEXED={count}")
PY

echo "N1I_C1_N1I_A_REPLAY=PASS"
echo "N1I_C1_N1I_A_A3_FRAMEWORK_PARITY=PASS_EXACT"

echo
echo "===== EXACT C1 APEX JAVA RUNTIME PARITY ====="
set +e
"$SABLE_PYTHON" "$APEX_PARITY" \
  --repo "$ROOT" \
  --v6-evidence "$OUT" \
  --product-out "$PRODUCT_OUT" \
  --out "$APEX_PARITY_DIR" 2>&1 | tee "$APEX_PARITY_LOG"
APEX_PARITY_RC="${PIPESTATUS[0]}"
set -e
[[ "$APEX_PARITY_RC" -eq 0 ]] ||
  fail "apex_runtime_parity_rc=$APEX_PARITY_RC" 67

APEX_PARITY_SUMMARY="$APEX_PARITY_DIR/summary.env"
[[ -f "$APEX_PARITY_SUMMARY" ]] || fail apex_parity_summary_missing 67
[[ -f "$APEX_PARITY_DIR/SHA256SUMS.txt" ]] ||
  fail apex_parity_seal_missing 67
(
  cd "$APEX_PARITY_DIR"
  sha256sum -c SHA256SUMS.txt >/dev/null
) || fail apex_parity_seal_invalid 67

CURRENT_HEAD="$(git -C "$ROOT" rev-parse HEAD)"
for expected in \
  "TOOL_SOURCE_COMMIT=$CURRENT_HEAD" \
  "N1I_C1_APEX_PARITY_V6_EVIDENCE=$OUT" \
  "N1I_C1_APEX_PARITY_PRODUCT_OUT=$PRODUCT_OUT" \
  "N1I_C1_APEX_PARITY_C1_SYSTEM_SHA256=$EXPECTED_C1_SHA" \
  'N1I_C1_APEX_FRAGMENT_MISMATCH_COUNT=0' \
  'N1I_C1_APEX_BOOT_JAR_PATH_MISMATCH_COUNT=0' \
  'N1I_C1_APEX_BOOT_JAR_HASH_MISMATCH_COUNT=0' \
  'N1I_C1_APEX_JAVA_BOOT_RUNTIME_PARITY=PASS'
do
  grep -Fxq -- "$expected" "$APEX_PARITY_SUMMARY" ||
    fail "apex_parity_authority_mismatch=$expected" 67
done
echo "N1I_C1_APEX_JAVA_BOOT_RUNTIME_PARITY=PASS_EXACT_SEALED"

echo
echo "===== FULL RUNTIME CLASSPATH DERIVATION ====="
set +e
"$SABLE_PYTHON" "$DERIVER" \
  --product-out "$PRODUCT_OUT" \
  --n1i-a-evidence "$REPLAY" \
  --apex-parity-evidence "$APEX_PARITY_DIR" \
  --api-level 36 \
  --out "$MANIFEST" | tee "$DERIVE_LOG"
DERIVE_RC="${PIPESTATUS[0]}"
set -e
[[ "$DERIVE_RC" -eq 0 ]] || fail "runtime_classpath_derivation_rc=$DERIVE_RC" 67
[[ -s "$MANIFEST" ]] || fail runtime_classpath_manifest_empty 67

printf 'device_path\tsha256\thost_path\n' > "$BOOT_HASHES"
while IFS=$'\t' read -r device host; do
  [[ -n "$device" && -n "$host" && -f "$host" ]] ||
    fail "bad_materialized_bootclasspath_row=$device:$host" 67
  BOOT_SHA="$(sha256sum "$host" | awk '{print $1}')"
  printf '%s\t%s\t%s\n' "$device" "$BOOT_SHA" "$host" >> "$BOOT_HASHES"
  echo "N1I_C1_LINKAGE_BOOT_ENTRY=device=$device sha256=$BOOT_SHA host=$host"
done < "$MANIFEST"

IMS_APK="$PRODUCT_OUT/system/system_ext/priv-app/ImsService/ImsService.apk"
[[ -f "$IMS_APK" ]] || fail "ims_apk_missing=$IMS_APK" 67
"$AAPT2" dump badging "$IMS_APK" > "$BADGING" 2> "$OUT/ims-badging.stderr.txt" ||
  fail "aapt2_badging_failed=$IMS_APK" 67

echo
echo "===== EXACT MEMBER LINKAGE AGAINST FULL C1 RUNTIME ====="
set +e
"$SABLE_PYTHON" "$AUDIT" \
  --bootclasspath-manifest "$MANIFEST" \
  --ims-apk "$IMS_APK" \
  --badging "$BADGING" | tee "$RESULT"
RC="${PIPESTATUS[0]}"
set -e

(
  cd "$OUT"
  sha256sum \
    n1i-a-replay.log \
    stock-ref-resolution.txt \
    apex-runtime-parity.log \
    apex-runtime-parity/SHA256SUMS.txt \
    bootclasspath-materialized.tsv \
    bootclasspath-sha256.tsv \
    ims-badging.txt \
    runtime-classpath-derivation.txt \
    runtime-linkage.txt > SHA256SUMS.txt
)

echo "N1I_C1_RUNTIME_LINKAGE_EVIDENCE=$OUT"
echo "N1I_C1_RUNTIME_LINKAGE_DRIVER_RC=$RC"
exit "$RC"
