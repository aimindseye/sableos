#!/usr/bin/env bash
# Host-only N1I-C1 sealed runtime-layout audit.
# Compares stock V01.00.14, C1 PRODUCT_OUT, and the exact sealed/flashed system.img.
# No build, source mutation, adb, fastboot, reboot, flash, mount, or device contact.
set -u
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STORAGE_PROFILE="$ROOT/build/config/storage.env"
HOST_TOOLS_PROFILE="$ROOT/build/config/host-tools.env"

[[ -f "$STORAGE_PROFILE" ]] || {
  echo "N1I_C1_SEALED_RUNTIME_AUDIT=FAIL reason=storage_profile_missing" >&2
  exit 64
}
[[ -f "$HOST_TOOLS_PROFILE" ]] || {
  echo "N1I_C1_SEALED_RUNTIME_AUDIT=FAIL reason=host_tools_profile_missing" >&2
  exit 64
}

source "$STORAGE_PROFILE"
source "$HOST_TOOLS_PROFILE"

ARTIFACT_DIR=""
PRODUCT_OUT=""

EXPECTED_SOURCE="a745c7daa08267d851f45785a5bb7ff762ed4604"
EXPECTED_SYSTEM_SHA="137bc8771c817c0afb3122d9f03e7a94575e03bcccc643b56235edd1075f2160"
EXPECTED_SYSTEM_BYTES="3210661888"
EXPECTED_STOCK_SYSTEM_SHA="b2074e20afb6b1dccb87f804ec93b2b8cc64ac6f2366b8d3e6d52522f7f431bd"
EXPECTED_STOCK_SYSTEM_EXT_SHA="1d9d25921def9b7e4e767c00a1f34d19ef5e7320138e3522545f2a2f2047d170"
EXPECTED_COMMON_SHA="511b674b91dd29e84e06c8e46c718e35650745c0359edd665d5fb3e88e6ed549"
EXPECTED_IMS_BASE_SHA="bb5769a098b59f9d299495981e87500da32e0667cf6a22931de2894d324a82ab"

fail() {
  echo "N1I_C1_SEALED_RUNTIME_AUDIT=FAIL reason=$1" >&2
  exit "${2:-1}"
}

usage() {
  cat <<'EOF'
Usage:
  bash build/titan2/audit-n1i-c1-sealed-runtime-layout.sh \
    --artifact-dir <sealed C1 postbuild artifact dir> \
    --product-out <original tdgsi_arm64_ab PRODUCT_OUT>
EOF
}

while (($#)); do
  case "$1" in
    --artifact-dir)
      [[ "$#" -ge 2 ]] || fail missing_artifact_dir 64
      ARTIFACT_DIR="$2"; shift 2 ;;
    --product-out)
      [[ "$#" -ge 2 ]] || fail missing_product_out 64
      PRODUCT_OUT="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      usage >&2
      fail "unknown_argument=$1" 64 ;;
  esac
done

[[ -d "$ARTIFACT_DIR" ]] || fail artifact_dir_missing 64
[[ -d "$PRODUCT_OUT" ]] || fail product_out_missing 64

ARTIFACT_DIR="$(cd "$ARTIFACT_DIR" && pwd -P)"
PRODUCT_OUT="$(cd "$PRODUCT_OUT" && pwd -P)"

SYSTEM_IMG="$ARTIFACT_DIR/system.img"
ARTIFACT_ENV="$ARTIFACT_DIR/artifact.env"
ARTIFACT_SUMS="$ARTIFACT_DIR/SHA256SUMS.txt"

[[ -f "$SYSTEM_IMG" && -f "$ARTIFACT_ENV" && -f "$ARTIFACT_SUMS" ]] ||
  fail sealed_artifact_incomplete 65

(
  cd "$ARTIFACT_DIR" || exit 1
  sha256sum -c SHA256SUMS.txt >/dev/null
) || fail artifact_seal_invalid 65

grep -Fxq "SOURCE_COMMIT=$EXPECTED_SOURCE" "$ARTIFACT_ENV" ||
  fail source_binding_mismatch 65
grep -Fxq "SYSTEM_SHA256=$EXPECTED_SYSTEM_SHA" "$ARTIFACT_ENV" ||
  fail image_sha_binding_mismatch 65
grep -Fxq "SYSTEM_BYTES=$EXPECTED_SYSTEM_BYTES" "$ARTIFACT_ENV" ||
  fail image_bytes_binding_mismatch 65

[[ "$(sha256sum "$SYSTEM_IMG" | awk '{print $1}')" == "$EXPECTED_SYSTEM_SHA" ]] ||
  fail image_sha_mismatch 65
[[ "$(stat -c '%s' "$SYSTEM_IMG")" == "$EXPECTED_SYSTEM_BYTES" ]] ||
  fail image_bytes_mismatch 65

STOCK_REF="$SABLE_TITAN2_ROOT/artifacts/stock-firmware/unihertz-device-fota-20260922/inspection/bit-equivalence/TEE14-large-reference"
STOCK_SYSTEM="$STOCK_REF/system.img"
STOCK_SYSTEM_EXT="$STOCK_REF/system_ext.img"

[[ -f "$STOCK_SYSTEM" && -f "$STOCK_SYSTEM_EXT" ]] ||
  fail stock_images_missing 65
[[ "$(sha256sum "$STOCK_SYSTEM" | awk '{print $1}')" == "$EXPECTED_STOCK_SYSTEM_SHA" ]] ||
  fail stock_system_sha_mismatch 65
[[ "$(sha256sum "$STOCK_SYSTEM_EXT" | awk '{print $1}')" == "$EXPECTED_STOCK_SYSTEM_EXT_SHA" ]] ||
  fail stock_system_ext_sha_mismatch 65

SIMG2IMG="$SABLE_SIMG2IMG"
PYTHON="$SABLE_PYTHON"
HOST_TOOL_RESOLUTION_MODE="CANONICAL_PROFILE_ONLY"

[[ -x "$SIMG2IMG" ]] || fail "canonical_simg2img_missing=$SIMG2IMG" 64
[[ -x "$PYTHON" ]] || fail "canonical_python_missing=$PYTHON" 64

DEBUGFS="$(command -v debugfs 2>/dev/null || true)"
FSCK_EROFS="$(command -v fsck.erofs 2>/dev/null || true)"
[[ -n "$DEBUGFS" && -x "$DEBUGFS" ]] || fail debugfs_missing 64

run_host_tool() {
  local exe tool_root
  exe="$1"
  shift
  tool_root="${exe%/bin/*}"
  if [[ "$tool_root" != "$exe" && ( -d "$tool_root/lib64" || -d "$tool_root/lib" ) ]]; then
    LD_LIBRARY_PATH="$tool_root/lib64:$tool_root/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" "$exe" "$@"
  else
    "$exe" "$@"
  fi
}

for tool in sha256sum cmp od stat mktemp cp find; do
  command -v "$tool" >/dev/null 2>&1 || fail "tool_missing=$tool" 64
done

echo "===== N1I-C1 SEALED RUNTIME AUDIT PREFLIGHT ====="
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "N1I_C1_HOST_TOOLS_PROFILE=$HOST_TOOLS_PROFILE"
echo "N1I_C1_HOST_TOOL_RESOLUTION_MODE=$HOST_TOOL_RESOLUTION_MODE"
echo "N1I_C1_TOOL_SIMG2IMG=$SIMG2IMG"
echo "N1I_C1_TOOL_PYTHON=$PYTHON"
echo "N1I_C1_TOOL_DEBUGFS=$DEBUGFS"
echo "N1I_C1_TOOL_FSCK_EROFS=${FSCK_EROFS:-UNAVAILABLE_UNLESS_EROFS}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

hexat() {
  od -An -tx1 -j "$2" -N "$3" "$1" 2>/dev/null | tr -d ' \n'
}

image_type() {
  if [[ "$(hexat "$1" 0 4)" == "3aff26ed" ]]; then
    echo sparse
  elif [[ "$(hexat "$1" 1080 2)" == "53ef" ]]; then
    echo ext4
  elif [[ "$(hexat "$1" 1024 4)" == "e2e1f5e0" ]]; then
    echo erofs
  else
    echo unknown
  fi
}

PREPARED_IMAGE=""
PREPARED_TYPE=""
PREPARED_TREE=""

prepare_fs_view() {
  local image="$1"
  local label="$2"
  local input_type normalized_type raw tree

  input_type="$(image_type "$image")"
  echo "N1I_C1_${label}_INPUT_TYPE=$input_type"
  PREPARED_IMAGE="$image"
  PREPARED_TYPE="$input_type"
  PREPARED_TREE=""

  case "$input_type" in
    sparse)
      raw="$TMP/${label,,}.raw.img"
      run_host_tool "$SIMG2IMG" "$image" "$raw" >/dev/null ||
        fail "simg2img_failed=$label" 65
      [[ -s "$raw" ]] || fail "simg2img_empty_output=$label" 65
      normalized_type="$(image_type "$raw")"
      case "$normalized_type" in
        ext4|erofs) ;;
        *) fail "normalized_image_unsupported=$label:$normalized_type" 65 ;;
      esac
      PREPARED_IMAGE="$raw"
      PREPARED_TYPE="$normalized_type"
      ;;
    ext4|erofs)
      ;;
    *)
      fail "unsupported_stock_image_type=$label:$input_type" 65
      ;;
  esac

  echo "N1I_C1_${label}_NORMALIZED_TYPE=$PREPARED_TYPE"

  if [[ "$PREPARED_TYPE" == erofs ]]; then
    [[ -n "$FSCK_EROFS" && -x "$FSCK_EROFS" ]] ||
      fail "fsck_erofs_missing_for=$label" 64
    tree="$TMP/${label,,}.erofs-tree"
    mkdir -p "$tree" || fail "erofs_tree_create_failed=$label" 65
    "$FSCK_EROFS" --extract="$tree" "$PREPARED_IMAGE" >/dev/null 2>"$tree.extract.log" ||
      fail "erofs_extract_failed=$label" 65
    if grep -qiE 'corrupt|short read|cannot open|not a valid|i/o error|error:' "$tree.extract.log" 2>/dev/null; then
      fail "erofs_extract_reported_error=$label" 65
    fi
    [[ -n "$(find "$tree" -mindepth 1 -print -quit)" ]] ||
      fail "erofs_extract_empty=$label" 65
    PREPARED_TREE="$tree"
  fi
}

dump_view_file() {
  local kind="$1"
  local image="$2"
  local tree="$3"
  local dest="$4"
  shift 4
  local candidate log source

  rm -f "$dest"

  case "$kind" in
    ext4)
      for candidate in "$@"; do
        log="$dest.debugfs.log"
        rm -f "$dest" "$log"
        "$DEBUGFS" -R "dump -p $candidate $dest" "$image" >/dev/null 2>"$log"
        if [[ -s "$dest" ]]; then
          printf '%s\n' "$candidate"
          rm -f "$log"
          return 0
        fi
      done
      ;;
    erofs)
      [[ -d "$tree" ]] || return 1
      for candidate in "$@"; do
        source="$tree/${candidate#/}"
        if [[ -f "$source" ]]; then
          cp -p "$source" "$dest" || return 1
          [[ -s "$dest" ]] || return 1
          printf '%s\n' "$candidate"
          return 0
        fi
      done
      ;;
    *)
      return 1
      ;;
  esac

  return 1
}

# Read only the required stock runtime files directly from the exact SHA-pinned
# stock images. Sparse images are normalized with the canonical Sable
# SABLE_SIMG2IMG tool. The resulting filesystem may be ext4 or EROFS.
prepare_fs_view "$STOCK_SYSTEM" STOCK_SYSTEM
STOCK_SYSTEM_INPUT_TYPE="$(image_type "$STOCK_SYSTEM")"
STOCK_SYSTEM_READ="$PREPARED_IMAGE"
STOCK_SYSTEM_READ_TYPE="$PREPARED_TYPE"
STOCK_SYSTEM_TREE="$PREPARED_TREE"

prepare_fs_view "$STOCK_SYSTEM_EXT" STOCK_SYSTEM_EXT
STOCK_SYSTEM_EXT_INPUT_TYPE="$(image_type "$STOCK_SYSTEM_EXT")"
STOCK_SYSTEM_EXT_READ="$PREPARED_IMAGE"
STOCK_SYSTEM_EXT_READ_TYPE="$PREPARED_TYPE"
STOCK_SYSTEM_EXT_TREE="$PREPARED_TREE"

STOCK_BOOT="$TMP/stock-bootclasspath.pb"
STOCK_COMMON="$TMP/stock-mediatek-common.jar"
STOCK_IMSBASE="$TMP/stock-mediatek-ims-base.jar"
STOCK_IMS="$TMP/stock-ImsService.apk"

STOCK_BOOT_IMAGE_PATH="$(dump_view_file "$STOCK_SYSTEM_READ_TYPE" "$STOCK_SYSTEM_READ" "$STOCK_SYSTEM_TREE" "$STOCK_BOOT" \
  /etc/classpaths/bootclasspath.pb \
  /system/etc/classpaths/bootclasspath.pb)" ||
  fail stock_bootclasspath_missing 65

STOCK_COMMON_IMAGE_PATH="$(dump_view_file "$STOCK_SYSTEM_EXT_READ_TYPE" "$STOCK_SYSTEM_EXT_READ" "$STOCK_SYSTEM_EXT_TREE" "$STOCK_COMMON" \
  /framework/mediatek-common.jar \
  /system_ext/framework/mediatek-common.jar \
  /system/system_ext/framework/mediatek-common.jar)" ||
  fail stock_common_missing 65

STOCK_IMSBASE_IMAGE_PATH="$(dump_view_file "$STOCK_SYSTEM_EXT_READ_TYPE" "$STOCK_SYSTEM_EXT_READ" "$STOCK_SYSTEM_EXT_TREE" "$STOCK_IMSBASE" \
  /framework/mediatek-ims-base.jar \
  /system_ext/framework/mediatek-ims-base.jar \
  /system/system_ext/framework/mediatek-ims-base.jar)" ||
  fail stock_ims_base_missing 65

STOCK_IMS_IMAGE_PATH="$(dump_view_file "$STOCK_SYSTEM_EXT_READ_TYPE" "$STOCK_SYSTEM_EXT_READ" "$STOCK_SYSTEM_EXT_TREE" "$STOCK_IMS" \
  /priv-app/ImsService/ImsService.apk \
  /system_ext/priv-app/ImsService/ImsService.apk \
  /system/system_ext/priv-app/ImsService/ImsService.apk)" ||
  fail stock_ims_apk_missing 65

[[ "$(sha256sum "$STOCK_COMMON" | awk '{print $1}')" == "$EXPECTED_COMMON_SHA" ]] ||
  fail stock_common_sha_mismatch 65
[[ "$(sha256sum "$STOCK_IMSBASE" | awk '{print $1}')" == "$EXPECTED_IMS_BASE_SHA" ]] ||
  fail stock_ims_base_sha_mismatch 65

# PRODUCT_OUT paths are exactly what the original postbuild qualifier inspected.
PO_BOOT="$PRODUCT_OUT/system/etc/classpaths/bootclasspath.pb"
PO_COMMON="$PRODUCT_OUT/system/system_ext/framework/mediatek-common.jar"
PO_IMSBASE="$PRODUCT_OUT/system/system_ext/framework/mediatek-ims-base.jar"
PO_IMS="$PRODUCT_OUT/system/system_ext/priv-app/ImsService/ImsService.apk"
PO_PROP="$PRODUCT_OUT/system/system_ext/etc/selinux/system_ext_property_contexts"
PO_SVC="$PRODUCT_OUT/system/system_ext/etc/selinux/system_ext_service_contexts"

for p in "$PO_BOOT" "$PO_COMMON" "$PO_IMSBASE" "$PO_IMS" "$PO_PROP" "$PO_SVC"; do
  [[ -f "$p" ]] || fail "product_out_missing=$p" 65
done

# The exact sealed C1 image is raw ext4 in the qualified artifact.
magic="$(od -An -tx1 -j 1080 -N 2 "$SYSTEM_IMG" 2>/dev/null | tr -d ' \n')"
[[ "$magic" == 53ef ]] || fail "sealed_image_not_ext4 magic=$magic" 65

C1_BOOT="$TMP/c1-bootclasspath.pb"
C1_COMMON="$TMP/c1-mediatek-common.jar"
C1_IMSBASE="$TMP/c1-mediatek-ims-base.jar"
C1_IMS="$TMP/c1-ImsService.apk"
C1_PROP="$TMP/c1-system_ext_property_contexts"
C1_SVC="$TMP/c1-system_ext_service_contexts"

C1_BOOT_IMAGE_PATH="$(dump_view_file ext4 "$SYSTEM_IMG" "" "$C1_BOOT" \
  /etc/classpaths/bootclasspath.pb /system/etc/classpaths/bootclasspath.pb)" ||
  fail sealed_bootclasspath_missing 66
C1_COMMON_IMAGE_PATH="$(dump_view_file ext4 "$SYSTEM_IMG" "" "$C1_COMMON" \
  /system_ext/framework/mediatek-common.jar \
  /system/system_ext/framework/mediatek-common.jar)" ||
  fail sealed_common_missing 66
C1_IMSBASE_IMAGE_PATH="$(dump_view_file ext4 "$SYSTEM_IMG" "" "$C1_IMSBASE" \
  /system_ext/framework/mediatek-ims-base.jar \
  /system/system_ext/framework/mediatek-ims-base.jar)" ||
  fail sealed_ims_base_missing 66
C1_IMS_IMAGE_PATH="$(dump_view_file ext4 "$SYSTEM_IMG" "" "$C1_IMS" \
  /system_ext/priv-app/ImsService/ImsService.apk \
  /system/system_ext/priv-app/ImsService/ImsService.apk)" ||
  fail sealed_ims_apk_missing 66
C1_PROP_IMAGE_PATH="$(dump_view_file ext4 "$SYSTEM_IMG" "" "$C1_PROP" \
  /system_ext/etc/selinux/system_ext_property_contexts \
  /system/system_ext/etc/selinux/system_ext_property_contexts)" ||
  fail sealed_property_contexts_missing 66
C1_SVC_IMAGE_PATH="$(dump_view_file ext4 "$SYSTEM_IMG" "" "$C1_SVC" \
  /system_ext/etc/selinux/system_ext_service_contexts \
  /system/system_ext/etc/selinux/system_ext_service_contexts)" ||
  fail sealed_service_contexts_missing 66

echo "===== N1I-C1 SEALED RUNTIME LAYOUT AUDIT ====="
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "ARTIFACT_DIR=$ARTIFACT_DIR"
echo "PRODUCT_OUT=$PRODUCT_OUT"
echo "N1I_C1_HOST_TOOLS_PROFILE=$HOST_TOOLS_PROFILE"
echo "N1I_C1_HOST_TOOL_RESOLUTION_MODE=$HOST_TOOL_RESOLUTION_MODE"
echo "N1I_C1_TOOL_SIMG2IMG=$SIMG2IMG"
echo "N1I_C1_TOOL_PYTHON=$PYTHON"
echo "N1I_C1_TOOL_DEBUGFS=$DEBUGFS"
echo "N1I_C1_TOOL_FSCK_EROFS=${FSCK_EROFS:-UNAVAILABLE_NOT_NEEDED_FOR_EXT4}"
echo "N1I_C1_SEALED_IMAGE_SHA=PASS"
echo "N1I_C1_SEALED_IMAGE_BYTES=PASS"
echo "N1I_C1_STOCK_SYSTEM_IMAGE_TYPE=$STOCK_SYSTEM_INPUT_TYPE"
echo "N1I_C1_STOCK_SYSTEM_NORMALIZED_TYPE=$STOCK_SYSTEM_READ_TYPE"
echo "N1I_C1_STOCK_SYSTEM_EXT_IMAGE_TYPE=$STOCK_SYSTEM_EXT_INPUT_TYPE"
echo "N1I_C1_STOCK_SYSTEM_EXT_NORMALIZED_TYPE=$STOCK_SYSTEM_EXT_READ_TYPE"
echo "N1I_C1_STOCK_BOOTCLASSPATH_PATH=$STOCK_BOOT_IMAGE_PATH"
echo "N1I_C1_STOCK_COMMON_PATH=$STOCK_COMMON_IMAGE_PATH"
echo "N1I_C1_STOCK_IMS_BASE_PATH=$STOCK_IMSBASE_IMAGE_PATH"
echo "N1I_C1_STOCK_IMS_APK_PATH=$STOCK_IMS_IMAGE_PATH"
echo "N1I_C1_SEALED_BOOTCLASSPATH_PATH=$C1_BOOT_IMAGE_PATH"
echo "N1I_C1_SEALED_COMMON_PATH=$C1_COMMON_IMAGE_PATH"
echo "N1I_C1_SEALED_IMS_BASE_PATH=$C1_IMSBASE_IMAGE_PATH"
echo "N1I_C1_SEALED_IMS_APK_PATH=$C1_IMS_IMAGE_PATH"
echo "N1I_C1_SEALED_PROPERTY_CONTEXTS_PATH=$C1_PROP_IMAGE_PATH"
echo "N1I_C1_SEALED_SERVICE_CONTEXTS_PATH=$C1_SVC_IMAGE_PATH"

# Three-way byte identity: retained stock -> PRODUCT_OUT -> sealed image.
[[ "$(sha256sum "$PO_COMMON" | awk '{print $1}')" == "$EXPECTED_COMMON_SHA" ]] ||
  fail product_out_common_sha_mismatch 67
[[ "$(sha256sum "$PO_IMSBASE" | awk '{print $1}')" == "$EXPECTED_IMS_BASE_SHA" ]] ||
  fail product_out_ims_base_sha_mismatch 67
[[ "$(sha256sum "$C1_COMMON" | awk '{print $1}')" == "$EXPECTED_COMMON_SHA" ]] ||
  fail sealed_common_sha_mismatch 67
[[ "$(sha256sum "$C1_IMSBASE" | awk '{print $1}')" == "$EXPECTED_IMS_BASE_SHA" ]] ||
  fail sealed_ims_base_sha_mismatch 67

cmp -s "$PO_BOOT" "$C1_BOOT" || fail sealed_bootclasspath_differs_from_product_out 67
cmp -s "$PO_COMMON" "$C1_COMMON" || fail sealed_common_differs_from_product_out 67
cmp -s "$PO_IMSBASE" "$C1_IMSBASE" || fail sealed_ims_base_differs_from_product_out 67
cmp -s "$PO_IMS" "$C1_IMS" || fail sealed_ims_apk_differs_from_product_out 67
cmp -s "$PO_PROP" "$C1_PROP" || fail sealed_property_contexts_differs_from_product_out 67
cmp -s "$PO_SVC" "$C1_SVC" || fail sealed_service_contexts_differs_from_product_out 67

echo "N1I_C1_STOCK_TO_PRODUCT_OUT_COMMON=PASS_EXACT"
echo "N1I_C1_STOCK_TO_PRODUCT_OUT_IMS_BASE=PASS_EXACT"
echo "N1I_C1_PRODUCT_OUT_TO_SEALED_BOOTCLASSPATH=PASS_EXACT"
echo "N1I_C1_PRODUCT_OUT_TO_SEALED_COMMON=PASS_EXACT"
echo "N1I_C1_PRODUCT_OUT_TO_SEALED_IMS_BASE=PASS_EXACT"
echo "N1I_C1_PRODUCT_OUT_TO_SEALED_IMS_APK=PASS_EXACT"
echo "N1I_C1_PRODUCT_OUT_TO_SEALED_PROPERTY_CONTEXTS=PASS_EXACT"
echo "N1I_C1_PRODUCT_OUT_TO_SEALED_SERVICE_CONTEXTS=PASS_EXACT"

"$PYTHON" - "$STOCK_BOOT" "$C1_BOOT" <<'PY'
from pathlib import Path
import re
import sys

stock = Path(sys.argv[1]).read_bytes()
c1 = Path(sys.argv[2]).read_bytes()

pat = re.compile(
    rb"/(?:apex|system|system_ext|product)/"
    rb"[A-Za-z0-9_@.+\-/]+\.jar"
)

def ordered(data):
    out = []
    seen = set()
    for m in pat.finditer(data):
        s = m.group(0).decode("utf-8", "replace")
        if s not in seen:
            seen.add(s)
            out.append(s)
    return out

def emit(label, seq, needle):
    if needle not in seq:
        print(f"N1I_C1_{label}_MISSING={needle}")
        raise SystemExit(1)
    i = seq.index(needle)
    print(f"N1I_C1_{label}_INDEX={i}")
    lo = max(0, i - 4)
    hi = min(len(seq), i + 5)
    for pos in range(lo, hi):
        print(f"N1I_C1_{label}_WINDOW[{pos}]={seq[pos]}")

stock_seq = ordered(stock)
c1_seq = ordered(c1)

print(f"N1I_C1_STOCK_BOOTCLASSPATH_ENTRY_COUNT={len(stock_seq)}")
print(f"N1I_C1_C1_BOOTCLASSPATH_ENTRY_COUNT={len(c1_seq)}")

common = "/system_ext/framework/mediatek-common.jar"
ims = "/system_ext/framework/mediatek-ims-base.jar"

emit("STOCK_COMMON", stock_seq, common)
emit("STOCK_IMS_BASE", stock_seq, ims)
emit("C1_COMMON", c1_seq, common)
emit("C1_IMS_BASE", c1_seq, ims)

stock_pair = stock_seq.index(common) < stock_seq.index(ims)
c1_pair = c1_seq.index(common) < c1_seq.index(ims)

print(
    "N1I_C1_MTK_MUTUAL_ORDER="
    + ("PASS_SAME" if stock_pair == c1_pair else "FAIL_DIFFERENT")
)

if stock_pair != c1_pair:
    raise SystemExit(1)

stock_common_i = stock_seq.index(common)
stock_ims_i = stock_seq.index(ims)
c1_common_i = c1_seq.index(common)
c1_ims_i = c1_seq.index(ims)

print(f"N1I_C1_STOCK_COMMON_INDEX={stock_common_i}")
print(f"N1I_C1_STOCK_IMS_BASE_INDEX={stock_ims_i}")
print(f"N1I_C1_C1_COMMON_INDEX={c1_common_i}")
print(f"N1I_C1_C1_IMS_BASE_INDEX={c1_ims_i}")

# Report, but do not fail solely because absolute position differs: the GSI
# bootclasspath is not expected to be globally identical to stock.
print(
    "N1I_C1_MTK_ABSOLUTE_POSITION="
    + (
        "SAME"
        if (stock_common_i, stock_ims_i) == (c1_common_i, c1_ims_i)
        else "DIFFERENT_REVIEW_REQUIRED"
    )
)
PY
ORDER_RC=$?
[[ "$ORDER_RC" -eq 0 ]] || fail bootclasspath_order_parse 68

# Ensure only the bounded C1 context additions of interest survived into the
# sealed image. These are exact markers, not a broad permissive policy check.
for marker in \
  'vendor.ril.imsconfig.force.notify' \
  'persist.vendor.mtk_clientapi_support'
do
  grep -Fq "$marker" "$C1_PROP" || fail "sealed_property_marker_missing=$marker" 68
done
for marker in \
  'vendor.mediatek.hardware.mtkradioex.ims.IMtkRadioExIms/slot1' \
  'vendor.mediatek.hardware.mtkradioex.ims.IMtkRadioExIms/slot2'
do
  grep -Fq "$marker" "$C1_SVC" || fail "sealed_service_marker_missing=$marker" 68
done

echo "N1I_C1_SEALED_SELINUX_MARKERS=PASS"

echo "N1I_C1_SEALED_RUNTIME_AUDIT=PASS"
echo "N1I_C1_DEVICE_CONTACT=NONE"
echo "N1I_C1_FLASH=NONE"
