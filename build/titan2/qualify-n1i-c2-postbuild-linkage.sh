#!/usr/bin/env bash
# Read-only N1I-C2 post-build linkage/content qualification.
# No Android build, source mutation, network fetch, device contact, reboot, or flash.
set -euo pipefail
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/build/config/storage.env"
source "$ROOT/build/config/host-tools.env"

SOURCE_COMMIT=""
OUT_DIR=""
ARTIFACT_DIR=""
EXPECTED_SYSTEM_SHA=""
EXPECTED_SYSTEM_BYTES=""

SYSTEM_GROUP_SAFE_CEILING=3263168512
GSI_INFO="$ROOT/build/deploy/gsi_image_info.py"
LINKAGE_DRIVER="$ROOT/build/titan2/run-n1i-c1-runtime-linkage-audit.sh"
AGENTPREMAIN_CLASSIFIER="$ROOT/build/titan2/classify-n1i-c2-agentpremain-gap.py"
AAPT2="$SABLE_ANDROID_BUILD_TOOLS/aapt2"
APKSIGNER="$SABLE_ANDROID_BUILD_TOOLS/apksigner"

fail() {
  echo "N1I_C2_POSTBUILD_LINKAGE_QUALIFICATION=FAIL reason=$1" >&2
  exit "${2:-1}"
}

usage() {
  cat <<'EOF'
Usage:
  bash build/titan2/qualify-n1i-c2-postbuild-linkage.sh \
    --source-commit <40-hex-build-source> \
    --out-dir <existing-N1I-C2-OUT_DIR> \
    --artifact-dir <sealed-N1I-C2-artifact-dir> \
    --expected-system-sha <64-hex-system-sha256> \
    --expected-system-bytes <decimal-bytes>
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --source-commit)
      [[ "$#" -ge 2 ]] || fail missing_source_commit_value 64
      SOURCE_COMMIT="$2"; shift 2 ;;
    --out-dir)
      [[ "$#" -ge 2 ]] || fail missing_out_dir_value 64
      OUT_DIR="$2"; shift 2 ;;
    --artifact-dir)
      [[ "$#" -ge 2 ]] || fail missing_artifact_dir_value 64
      ARTIFACT_DIR="$2"; shift 2 ;;
    --expected-system-sha)
      [[ "$#" -ge 2 ]] || fail missing_expected_system_sha_value 64
      EXPECTED_SYSTEM_SHA="$2"; shift 2 ;;
    --expected-system-bytes)
      [[ "$#" -ge 2 ]] || fail missing_expected_system_bytes_value 64
      EXPECTED_SYSTEM_BYTES="$2"; shift 2 ;;
    -h|--help)
      usage
      exit 0 ;;
    *)
      fail "unknown_argument=$1" 64 ;;
  esac
done

[[ "$SOURCE_COMMIT" =~ ^[0-9a-f]{40}$ ]] || fail invalid_source_commit 64
[[ "$EXPECTED_SYSTEM_SHA" =~ ^[0-9a-f]{64}$ ]] || fail invalid_expected_system_sha 64
[[ "$EXPECTED_SYSTEM_BYTES" =~ ^[0-9]+$ ]] || fail invalid_expected_system_bytes 64
[[ -d "$OUT_DIR" ]] || fail out_dir_missing 64
[[ -d "$ARTIFACT_DIR" ]] || fail artifact_dir_missing 64

OUT_DIR="$(cd "$OUT_DIR" && pwd -P)"
ARTIFACT_DIR="$(cd "$ARTIFACT_DIR" && pwd -P)"

EXPECTED_OUT_BASENAME="out-n1i-c2-${SOURCE_COMMIT:0:12}"
[[ "$(basename "$OUT_DIR")" == "$EXPECTED_OUT_BASENAME" ]] ||
  fail "out_dir_source_binding=$(basename "$OUT_DIR") expected=$EXPECTED_OUT_BASENAME" 64

PRODUCT_OUT="$OUT_DIR/target/product/tdgsi_arm64_ab"
SYSTEM="$PRODUCT_OUT/system.img"
ARTIFACT_SYSTEM="$ARTIFACT_DIR/system.img"
ARTIFACT_ENV="$ARTIFACT_DIR/artifact.env"
ARTIFACT_SUMS="$ARTIFACT_DIR/SHA256SUMS.txt"
RECEIPT="$ARTIFACT_DIR/CELLULAR_MVP_IMPLEMENTATION_RECEIPT.tsv"
PROVIDER_OUTPUTS="$ARTIFACT_DIR/ANDROID_PLATFORM_PROVIDER_OUTPUTS.tsv"

for path in \
  "$SYSTEM" \
  "$ARTIFACT_SYSTEM" \
  "$ARTIFACT_ENV" \
  "$ARTIFACT_SUMS" \
  "$RECEIPT" \
  "$PROVIDER_OUTPUTS" \
  "$GSI_INFO" \
  "$LINKAGE_DRIVER" \
  "$AGENTPREMAIN_CLASSIFIER"
do
  [[ -f "$path" ]] || fail "required_file_missing=$path" 64
done

for tool in git sha256sum stat cmp awk grep tee; do
  command -v "$tool" >/dev/null 2>&1 || fail "required_tool_missing=$tool" 64
done
[[ -x "$AAPT2" ]] || fail "aapt2_missing=$AAPT2" 64
[[ -x "$APKSIGNER" ]] || fail "apksigner_missing=$APKSIGNER" 64
[[ -x "$SABLE_PYTHON" ]] || fail "canonical_python_missing=$SABLE_PYTHON" 64

TOOL_SOURCE_COMMIT="$(git -C "$ROOT" rev-parse HEAD)"
[[ -z "$(git -C "$ROOT" status --porcelain=v1 --untracked-files=all)" ]] ||
  fail tool_source_worktree_not_clean 64

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE="$SABLE_EVIDENCE_ROOT/titan2/n1i-c2-postbuild-linkage/${STAMP}-${SOURCE_COMMIT:0:12}"
[[ ! -e "$EVIDENCE" ]] || fail "evidence_dir_exists=$EVIDENCE" 64
mkdir -p "$EVIDENCE"
exec > >(tee "$EVIDENCE/qualify.log") 2>&1

echo "===== TITAN 2 N1I-C2 POST-BUILD LINKAGE / CONTENT QUALIFICATION ====="
echo "TOOL_SOURCE_COMMIT=$TOOL_SOURCE_COMMIT"
echo "BUILD_SOURCE_COMMIT=$SOURCE_COMMIT"
echo "OUT_DIR=$OUT_DIR"
echo "ARTIFACT_DIR=$ARTIFACT_DIR"
echo "EXPECTED_SYSTEM_SHA=$EXPECTED_SYSTEM_SHA"
echo "EXPECTED_SYSTEM_BYTES=$EXPECTED_SYSTEM_BYTES"
echo "BUILD_AUTHORIZED=NO"
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "REBOOT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"

echo
echo "===== VERIFY SEALED BUILD ARTIFACT ====="
(
  cd "$ARTIFACT_DIR"
  sha256sum -c SHA256SUMS.txt >/dev/null
) || fail artifact_seal_invalid 65

for expected in \
  'ROLE=N1I_C2_CELLULAR_MVP' \
  "SOURCE_COMMIT=$SOURCE_COMMIT" \
  'ANDROID_PLATFORM=16' \
  'FROZEN_MUTATION_COUNT=41' \
  'FROZEN_NATIVE_COUNT=33' \
  'C1_NATIVE_REUSE_COUNT=0' \
  'ANDROID_PLATFORM_PROVIDER_COUNT=5' \
  'NATIVE_IMPORT_COUNT=28' \
  'IMPLEMENTATION_RECEIPT_ROWS=41' \
  'OEM_IMS_PLATFORM_RESIGNED=YES' \
  "SYSTEM_SHA256=$EXPECTED_SYSTEM_SHA" \
  "SYSTEM_BYTES=$EXPECTED_SYSTEM_BYTES" \
  'DEVICE_CONTACT=NONE' \
  'FLASH=NONE'
do
  grep -Fxq -- "$expected" "$ARTIFACT_ENV" ||
    fail "artifact_authority_missing=$expected" 65
done
echo "N1I_C2_POSTBUILD_ARTIFACT_AUTHORITY=PASS"

SYSTEM_SHA="$(sha256sum "$SYSTEM" | awk '{print $1}')"
SYSTEM_BYTES="$(stat -c '%s' "$SYSTEM")"
ARTIFACT_SHA="$(sha256sum "$ARTIFACT_SYSTEM" | awk '{print $1}')"
ARTIFACT_BYTES="$(stat -c '%s' "$ARTIFACT_SYSTEM")"

[[ "$SYSTEM_SHA" == "$EXPECTED_SYSTEM_SHA" ]] ||
  fail "product_system_sha=$SYSTEM_SHA" 65
[[ "$ARTIFACT_SHA" == "$EXPECTED_SYSTEM_SHA" ]] ||
  fail "artifact_system_sha=$ARTIFACT_SHA" 65
[[ "$SYSTEM_BYTES" == "$EXPECTED_SYSTEM_BYTES" ]] ||
  fail "product_system_bytes=$SYSTEM_BYTES" 65
[[ "$ARTIFACT_BYTES" == "$EXPECTED_SYSTEM_BYTES" ]] ||
  fail "artifact_system_bytes=$ARTIFACT_BYTES" 65
[[ "$SYSTEM_BYTES" -le "$SYSTEM_GROUP_SAFE_CEILING" ]] ||
  fail "system_group_ceiling=$SYSTEM_BYTES" 65
cmp -s "$SYSTEM" "$ARTIFACT_SYSTEM" ||
  fail artifact_system_differs_from_product_out 65

python3 "$GSI_INFO" --image "$SYSTEM" > "$EVIDENCE/system-image-info.txt"
grep -Fxq 'SABLE_GSI_IMAGE_INFO=PASS' "$EVIDENCE/system-image-info.txt" ||
  fail gsi_image_info 65

echo "N1I_C2_POSTBUILD_SYSTEMIMAGE=PASS sha256=$SYSTEM_SHA bytes=$SYSTEM_BYTES"

echo
echo "===== VERIFY 41-ROW RECEIPT / 33 NATIVE OUTPUTS ====="
"$SABLE_PYTHON" - "$RECEIPT" "$PROVIDER_OUTPUTS" "$PRODUCT_OUT" "$EXPECTED_SYSTEM_SHA" "$EXPECTED_SYSTEM_BYTES" <<'PY'
from __future__ import annotations

import csv
import hashlib
from pathlib import Path
import sys

receipt_path = Path(sys.argv[1])
provider_path = Path(sys.argv[2])
product_out = Path(sys.argv[3])
expected_system_sha = sys.argv[4]
expected_system_bytes = sys.argv[5]


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fp:
        for chunk in iter(lambda: fp.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def host_path(target: str) -> Path:
    if target.startswith("/system_ext/"):
        return product_out / "system/system_ext" / target.removeprefix("/system_ext/")
    if target.startswith("/product/"):
        return product_out / "system/product" / target.removeprefix("/product/")
    if target.startswith("/system/"):
        return product_out / "system" / target.removeprefix("/system/")
    raise SystemExit(f"unsupported_native_target={target}")


with receipt_path.open(encoding="utf-8", newline="") as fp:
    rows = list(csv.DictReader(fp, delimiter="\t"))

expected_ids = [f"M{i:03d}" for i in range(1, 42)]
if [row["id"] for row in rows] != expected_ids:
    raise SystemExit("receipt_id_order_drift")
if len(rows) != 41:
    raise SystemExit(f"receipt_row_count={len(rows)}")

for row in rows:
    if row["system_sha256"] != expected_system_sha:
        raise SystemExit(f"receipt_system_sha_drift={row['id']}")
    if row["system_bytes"] != expected_system_bytes:
        raise SystemExit(f"receipt_system_bytes_drift={row['id']}")

with provider_path.open(encoding="utf-8", newline="") as fp:
    provider_rows = list(csv.DictReader(fp, delimiter="\t"))

providers = {row["id"]: row for row in provider_rows}
expected_provider_ids = {"M008", "M017", "M029", "M038", "M039"}
if set(providers) != expected_provider_ids:
    raise SystemExit(
        "provider_id_set_drift="
        + ",".join(sorted(set(providers) ^ expected_provider_ids))
    )

frozen_count = 0
provider_count = 0

for index in range(7, 40):
    mid = f"M{index:03d}"
    row = rows[index - 1]
    if row["id"] != mid:
        raise SystemExit(f"native_receipt_index_drift={mid}")
    target = row["target"]
    path = host_path(target)
    if not path.is_file():
        raise SystemExit(f"native_output_missing={mid}:{target}:{path}")
    actual = sha256(path)

    status = row["implementation_status"]
    if status == "IMPLEMENTED_EXACT_FROZEN_HASH":
        if actual != row["authority_sha_or_blob"]:
            raise SystemExit(
                f"frozen_native_hash_mismatch={mid}:"
                f"expected:{row['authority_sha_or_blob']}:actual:{actual}"
            )
        frozen_count += 1
    elif status == "IMPLEMENTED_ANDROID_PLATFORM_PROVIDER":
        provider = providers.get(mid)
        if provider is None:
            raise SystemExit(f"provider_receipt_missing={mid}")
        if provider["target"] != target:
            raise SystemExit(f"provider_target_mismatch={mid}")
        if provider["sha256"] != actual:
            raise SystemExit(
                f"provider_hash_mismatch={mid}:"
                f"sealed:{provider['sha256']}:actual:{actual}"
            )
        token = f"PRODUCT_OUT_HASH={actual};"
        if token not in row["implementation_evidence"]:
            raise SystemExit(f"provider_receipt_hash_evidence_mismatch={mid}")
        provider_count += 1
    else:
        raise SystemExit(f"unexpected_native_status={mid}:{status}")

if frozen_count != 28 or provider_count != 5:
    raise SystemExit(
        f"native_status_counts=frozen:{frozen_count}:provider:{provider_count}"
    )

print("N1I_C2_POSTBUILD_RECEIPT=PASS rows=41")
print(
    "N1I_C2_POSTBUILD_NATIVE_AUTHORITY=PASS "
    "count=33 frozen_stock=28 android_platform=5"
)
PY

echo
echo "===== VERIFY IMS / BOOTCLASSPATH / C2 CONTENT ====="
COPYOUT="system/system_ext"
IMS="$PRODUCT_OUT/$COPYOUT/priv-app/ImsService/ImsService.apk"
FRAMEWORK_RES="$PRODUCT_OUT/system/framework/framework-res.apk"
BOOTPB="$PRODUCT_OUT/system/etc/classpaths/bootclasspath.pb"
COMMON="$PRODUCT_OUT/$COPYOUT/framework/mediatek-common.jar"
IMSBASE="$PRODUCT_OUT/$COPYOUT/framework/mediatek-ims-base.jar"

for path in "$IMS" "$FRAMEWORK_RES" "$BOOTPB" "$COMMON" "$IMSBASE"; do
  [[ -f "$path" ]] || fail "required_built_content_missing=$path" 66
done

apk_package="$("$AAPT2" dump badging "$IMS" |
  sed -n "s/^package: name='\([^']*\)'.*/\1/p" |
  sed -n '1p')"
[[ "$apk_package" == com.mediatek.ims ]] ||
  fail "ims_package=$apk_package" 66

ims_uid="$("$AAPT2" dump xmltree --file AndroidManifest.xml "$IMS" |
  sed -n 's/.*sharedUserId[^=]*="\([^"]*\)".*/\1/p' |
  sed -n '1p')"
[[ "$ims_uid" == android.uid.phone ]] ||
  fail "ims_shared_uid=$ims_uid" 66

ims_cert="$("$APKSIGNER" verify --print-certs "$IMS" |
  sed -n 's/^Signer #1 certificate SHA-256 digest: //p' |
  sed -n '1p')"
platform_cert="$("$APKSIGNER" verify --print-certs "$FRAMEWORK_RES" |
  sed -n 's/^Signer #1 certificate SHA-256 digest: //p' |
  sed -n '1p')"
[[ -n "$ims_cert" && "$ims_cert" == "$platform_cert" ]] ||
  fail ims_platform_signature_mismatch 66

grep -aFq '/system_ext/framework/mediatek-common.jar' "$BOOTPB" ||
  fail mediatek_common_bootclasspath_missing 66
grep -aFq '/system_ext/framework/mediatek-ims-base.jar' "$BOOTPB" ||
  fail mediatek_ims_base_bootclasspath_missing 66

BUILD_PROP="$PRODUCT_OUT/system/build.prop"
[[ -f "$BUILD_PROP" ]] || fail system_build_prop_missing 66
grep -Fxq 'ro.telephony.block_binder_thread_on_incoming_calls=false' "$BUILD_PROP" ||
  fail incoming_call_property_missing 66

for path in \
  "$PRODUCT_OUT/$COPYOUT/bin/sable-titan2-cellular" \
  "$PRODUCT_OUT/$COPYOUT/etc/init/sable-titan2-cellular.rc" \
  "$PRODUCT_OUT/$COPYOUT/etc/sable/titan2-cellular.conf" \
  "$PRODUCT_OUT/$COPYOUT/etc/sable/titan2-cellular-mvp"
do
  [[ -f "$path" ]] || fail "integration_output_missing=$path" 66
done
grep -Fq 'HEALER_DEFAULT=DISABLED'   "$PRODUCT_OUT/$COPYOUT/etc/sable/titan2-cellular-mvp" ||
  fail healer_default_not_disabled 66

BUILT_PHH="$PRODUCT_OUT/system/bin/phh-on-boot.sh"
[[ -f "$BUILT_PHH" ]] || fail phh_on_boot_missing 66
grep -Fq '/system_ext/etc/sable/titan2-cellular-mvp' "$BUILT_PHH" ||
  fail phh_titan_marker_guard_missing 66
grep -Fq 'setprop persist.mtk_ims_support 0' "$BUILT_PHH" ||
  fail phh_non_titan_behavior_missing 66

OVERLAY="$PRODUCT_OUT/system/product/overlay/treble-overlay-telephony-mtk-ims.apk"
[[ -f "$OVERLAY" ]] || fail mmtel_overlay_missing 66
overlay_package="$("$AAPT2" dump badging "$OVERLAY" |
  sed -n "s/^package: name='\([^']*\)'.*/\1/p" |
  sed -n '1p')"
[[ "$overlay_package" == me.phh.treble.overlay.mtkims_telephony ]] ||
  fail "mmtel_overlay_package=$overlay_package" 66

echo "N1I_C2_POSTBUILD_IMS_IDENTITY=PASS package=$apk_package shared_uid=$ims_uid"
echo "N1I_C2_POSTBUILD_IMS_PLATFORM_RESIGN=PASS cert=$ims_cert"
echo "N1I_C2_POSTBUILD_BOOTCLASSPATH=PASS"
echo "N1I_C2_POSTBUILD_CELLULAR_CONTENT=PASS"

echo
echo "===== SEALED JAVA / APEX RUNTIME LINKAGE ====="
LINKAGE_OUT="$EVIDENCE/runtime-linkage"
set +e
bash "$LINKAGE_DRIVER" \
  --product-out "$PRODUCT_OUT" \
  --out "$LINKAGE_OUT" \
  --expected-system-sha "$EXPECTED_SYSTEM_SHA" \
  --expected-system-bytes "$EXPECTED_SYSTEM_BYTES"
LINKAGE_RC=$?
set -e

[[ -f "$LINKAGE_OUT/SHA256SUMS.txt" ]] ||
  fail runtime_linkage_seal_missing 67
(
  cd "$LINKAGE_OUT"
  sha256sum -c SHA256SUMS.txt >/dev/null
) || fail runtime_linkage_seal_invalid 67

grep -Fxq 'N1I_C1_APEX_JAVA_BOOT_RUNTIME_PARITY=PASS' \
  "$LINKAGE_OUT/apex-runtime-parity/summary.env" ||
  fail apex_java_runtime_parity_not_pass 67

RUNTIME_MEMBER_LINKAGE=""
case "$LINKAGE_RC" in
  0)
    grep -Fxq 'N1I_C1_RUNTIME_MEMBER_LINKAGE_AUDIT=PASS_ALL_RESOLVED' \
      "$LINKAGE_OUT/runtime-linkage.txt" ||
      fail runtime_member_linkage_success_marker_missing 67
    RUNTIME_MEMBER_LINKAGE="PASS_ALL_RESOLVED"
    ;;
  1)
    AGENT_CLASSIFICATION="$EVIDENCE/agentpremain-classification.txt"
    set +e
    "$SABLE_PYTHON" "$AGENTPREMAIN_CLASSIFIER" \
      --evidence "$LINKAGE_OUT" \
      --product-out "$PRODUCT_OUT" \
      --expected-system-sha "$EXPECTED_SYSTEM_SHA" \
      2>&1 | tee "$AGENT_CLASSIFICATION"
    AGENT_RC="${PIPESTATUS[0]}"
    set -e
    [[ "$AGENT_RC" -eq 0 ]] ||
      fail "agentpremain_classification_rc=$AGENT_RC" 67
    grep -Fxq \
      'N1I_C2_AGENTPREMAIN_CLASSIFICATION=PASS_EXACT_DORMANT_NON_ANDROID_DEBUG_AGENT' \
      "$AGENT_CLASSIFICATION" ||
      fail agentpremain_exact_classification_missing 67
    grep -Fxq \
      'N1I_C2_AGENTPREMAIN_BROAD_RUNTIME_FAILURE_SUPPRESSION=NO' \
      "$AGENT_CLASSIFICATION" ||
      fail agentpremain_no_suppression_marker_missing 67
    grep -Fxq \
      'N1I_C2_RUNTIME_MEMBER_LINKAGE=PASS_FULL_CLASSIFICATION_AGENTPREMAIN_8' \
      "$AGENT_CLASSIFICATION" ||
      fail agentpremain_full_classification_marker_missing 67
    RUNTIME_MEMBER_LINKAGE="PASS_FULL_CLASSIFICATION_AGENTPREMAIN_8"
    ;;
  *)
    fail "runtime_linkage_rc=$LINKAGE_RC" 67
    ;;
esac

echo "N1I_C2_POSTBUILD_RUNTIME_LINKAGE=$RUNTIME_MEMBER_LINKAGE"

cat > "$EVIDENCE/POSTBUILD_SUMMARY.env" <<EOF
TOOL_SOURCE_COMMIT=$TOOL_SOURCE_COMMIT
BUILD_SOURCE_COMMIT=$SOURCE_COMMIT
SYSTEM_SHA256=$EXPECTED_SYSTEM_SHA
SYSTEM_BYTES=$EXPECTED_SYSTEM_BYTES
ARTIFACT_DIR=$ARTIFACT_DIR
C1_NATIVE_REUSE_COUNT=0
ANDROID_PLATFORM_PROVIDER_COUNT=5
NATIVE_IMPORT_COUNT=28
IMPLEMENTATION_RECEIPT_ROWS=41
RUNTIME_MEMBER_LINKAGE=$RUNTIME_MEMBER_LINKAGE
APEX_JAVA_BOOT_RUNTIME_PARITY=PASS
AGENTPREMAIN_BROAD_RUNTIME_FAILURE_SUPPRESSION=NO
DEVICE_CONTACT=NONE
REBOOT=NONE
FLASH=NONE
EOF

(
  cd "$EVIDENCE"
  find . -type f ! -name qualify.log ! -name SHA256SUMS.txt -print0 |
    LC_ALL=C sort -z |
    xargs -0 sha256sum > SHA256SUMS.txt
  sha256sum -c SHA256SUMS.txt >/dev/null
) || fail evidence_seal_invalid 68

echo "N1I_C2_POSTBUILD_EVIDENCE_SEAL=PASS_EXCLUDES_QUALIFY_LOG"
echo "N1I_C2_POSTBUILD_LINKAGE_QUALIFICATION=PASS"
echo "N1I_C2_READY_FOR_MERGE_REVIEW=YES"
echo "N1I_C2_READY_FOR_FLASH_QUALIFICATION=YES"
echo "N1I_C2_DEVICE_CONTACT=NONE"
echo "N1I_C2_REBOOT=NONE"
echo "N1I_C2_FLASH=NONE"
echo "N1I_C2_POSTBUILD_EVIDENCE_DIR=$EVIDENCE"
