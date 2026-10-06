#!/usr/bin/env bash
# Titan 2 N1I-D0-0H host input materializer.
# Read-only inputs; writes only below --out.
set -u
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/build/config/storage.env" || exit 64
source "$ROOT/build/config/host-tools.env" || exit 64

N1F_SYSTEM_DEFAULT="/srv/sable-build/artifacts/titan2/n1f-c3a-derived-c3b5/20261003T221350Z/system.img"
C2_SYSTEM_DEFAULT="/srv/data/sable-build/titan2/artifacts/n1i-c2-cellular-mvp/20261006T112224Z/system.img"
STOCK_REF_DEFAULT="$SABLE_TITAN2_ROOT/artifacts/stock-firmware/unihertz-device-fota-20260922/inspection/bit-equivalence/TEE14-large-reference"

EXPECTED_N1F_SHA="dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a"
EXPECTED_N1F_BYTES="3200540672"
EXPECTED_C2_SHA="630db78ef3f888b961640d17c5237495e673a953d67f1d52fabe056cbb76bb50"
EXPECTED_C2_BYTES="3218440192"
EXPECTED_STOCK_SYSTEM_SHA="b2074e20afb6b1dccb87f804ec93b2b8cc64ac6f2366b8d3e6d52522f7f431bd"
EXPECTED_STOCK_SYSTEM_EXT_SHA="1d9d25921def9b7e4e767c00a1f34d19ef5e7320138e3522545f2a2f2047d170"
EXPECTED_STOCK_PRODUCT_SHA="de1fdecab38b3c5ad7f30beea13f1afb46fa02d98b6cc78d57749b34513aad37"
EXPECTED_STOCK_VENDOR_SHA="cfeacc74b4289e56921016fedf35a45a995121b874be3cd2f1561b8ed2d61ada"

N1F_SYSTEM="$N1F_SYSTEM_DEFAULT"
C2_SYSTEM="$C2_SYSTEM_DEFAULT"
STOCK_REF="$STOCK_REF_DEFAULT"
OUT=""
REUSE=NO

fail() {
  echo "N1I_D0_INPUT_PREP=FAIL reason=$1" >&2
  exit "${2:-1}"
}

usage() {
  cat <<'EOF'
Usage:
  bash build/titan2/prepare-n1i-d0-0h-inputs.sh \
    --out <directory> \
    [--n1f-system <system.img>] \
    [--c2-system <system.img>] \
    [--stock-ref-dir <V01.00.14 TEE14 reference>] \
    [--reuse]

Host-only. No build, network, adb, fastboot, reboot or flash.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --out)
      [[ "$#" -ge 2 ]] || fail missing_out 64
      OUT="$2"; shift 2 ;;
    --n1f-system)
      [[ "$#" -ge 2 ]] || fail missing_n1f_system 64
      N1F_SYSTEM="$2"; shift 2 ;;
    --c2-system)
      [[ "$#" -ge 2 ]] || fail missing_c2_system 64
      C2_SYSTEM="$2"; shift 2 ;;
    --stock-ref-dir)
      [[ "$#" -ge 2 ]] || fail missing_stock_ref 64
      STOCK_REF="$2"; shift 2 ;;
    --reuse)
      REUSE=YES; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      fail "unknown_argument=$1" 64 ;;
  esac
done

[[ -n "$OUT" ]] || fail out_required 64
for p in "$N1F_SYSTEM" "$C2_SYSTEM"; do
  [[ -f "$p" ]] || fail "image_missing=$p" 64
done
[[ -d "$STOCK_REF" ]] || fail "stock_ref_missing=$STOCK_REF" 64

for t in sha256sum stat od tr find sort awk sed grep cp mkdir rm; do
  command -v "$t" >/dev/null 2>&1 || fail "host_tool_missing=$t" 64
done
[[ -x "$SABLE_SIMG2IMG" ]] || fail "simg2img_missing=$SABLE_SIMG2IMG" 64
[[ -x "$SABLE_SECILC" ]] || fail "secilc_missing=$SABLE_SECILC" 64

DEBUGFS="$(command -v debugfs 2>/dev/null || true)"
FSCK_EROFS="$(command -v fsck.erofs 2>/dev/null || true)"
READELF="$(command -v readelf 2>/dev/null || true)"
[[ -n "$DEBUGFS" && -x "$DEBUGFS" ]] || fail debugfs_missing 64
[[ -n "$READELF" && -x "$READELF" ]] || fail readelf_missing 64

OUT="$(mkdir -p "$OUT" && cd "$OUT" && pwd -P)" || fail out_resolve 64
ROOTS="$OUT/roots"
RAW="$OUT/raw"
mkdir -p "$ROOTS" "$RAW" || fail out_create 64

repo_status="$(git -C "$ROOT" status --porcelain=v1 --untracked-files=all)" ||
  fail repo_status 64
[[ -z "$repo_status" ]] || fail repo_dirty_before_input_prep 64
TOOL_SOURCE_COMMIT="$(git -C "$ROOT" rev-parse HEAD)" || fail repo_head 64

sha_file() {
  sha256sum "$1" | awk '{print $1}'
}

bytes_file() {
  stat -c '%s' "$1"
}

verify_exact() {
  local label="$1" path="$2" expected_sha="$3" expected_bytes="${4:-}"
  local sha bytes
  sha="$(sha_file "$path")" || return 1
  [[ "$sha" == "$expected_sha" ]] ||
    fail "${label}_sha=expected:$expected_sha:actual:$sha" 65
  bytes="$(bytes_file "$path")" || return 1
  if [[ -n "$expected_bytes" && "$bytes" != "$expected_bytes" ]]; then
    fail "${label}_bytes=expected:$expected_bytes:actual:$bytes" 65
  fi
  echo "N1I_D0_INPUT_${label}_SHA256=$sha"
  echo "N1I_D0_INPUT_${label}_BYTES=$bytes"
}

verify_exact N1F_SYSTEM "$N1F_SYSTEM" "$EXPECTED_N1F_SHA" "$EXPECTED_N1F_BYTES"
verify_exact C2_SYSTEM "$C2_SYSTEM" "$EXPECTED_C2_SHA" "$EXPECTED_C2_BYTES"

STOCK_SYSTEM="$STOCK_REF/system.img"
STOCK_SYSTEM_EXT="$STOCK_REF/system_ext.img"
STOCK_PRODUCT="$STOCK_REF/product.img"
STOCK_VENDOR="$STOCK_REF/vendor.img"
STOCK_ODM="$STOCK_REF/odm.img"

verify_exact STOCK_SYSTEM "$STOCK_SYSTEM" "$EXPECTED_STOCK_SYSTEM_SHA"
verify_exact STOCK_SYSTEM_EXT "$STOCK_SYSTEM_EXT" "$EXPECTED_STOCK_SYSTEM_EXT_SHA"
verify_exact STOCK_PRODUCT "$STOCK_PRODUCT" "$EXPECTED_STOCK_PRODUCT_SHA"
verify_exact STOCK_VENDOR "$STOCK_VENDOR" "$EXPECTED_STOCK_VENDOR_SHA"

STOCK_ODM_STATUS=UNKNOWN_NOT_PRESENT_OR_UNPINNED
STOCK_ODM_SHA=""
STOCK_ODM_BYTES=""
if [[ -f "$STOCK_ODM" ]]; then
  STOCK_ODM_SHA="$(sha_file "$STOCK_ODM")" || fail stock_odm_sha 65
  STOCK_ODM_BYTES="$(bytes_file "$STOCK_ODM")" || fail stock_odm_bytes 65
  pin_manifest=""
  for candidate in "$STOCK_REF/SHA256SUMS.txt" "$STOCK_REF/SHA256SUMS" "$STOCK_REF/sha256sums.txt"; do
    if [[ -f "$candidate" ]]; then
      pin_manifest="$candidate"
      break
    fi
  done
  if [[ -n "$pin_manifest" ]] &&
     grep -Eq "^${STOCK_ODM_SHA}[[:space:]]+[*]?\.?/?odm\.img$" "$pin_manifest"; then
    STOCK_ODM_STATUS=PASS_PINNED_BY_STOCK_MANIFEST
  else
    STOCK_ODM_STATUS=UNKNOWN_UNPINNED
  fi
fi

hexat() {
  od -An -tx1 -j "$2" -N "$3" "$1" 2>/dev/null | tr -d ' 
'
}

image_type() {
  local image="$1"
  if [[ "$(hexat "$image" 0 4)" == "3aff26ed" ]]; then
    echo sparse
  elif [[ "$(hexat "$image" 1080 2)" == "53ef" ]]; then
    echo ext4
  elif [[ "$(hexat "$image" 1024 4)" == "e2e1f5e0" ]]; then
    echo erofs
  else
    echo unknown
  fi
}

run_aosp_tool() {
  local exe="$1"
  shift
  LD_LIBRARY_PATH="$SABLE_AOSP_HOST_LIBRARY_PATH${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"     "$exe" "$@"
}

materialize_image() {
  local label="$1" image="$2" dest="$3"
  local input_type normalized raw extract_log

  if [[ "$REUSE" == YES && -f "$dest/.n1i-d0-materialized" ]]; then
    expected="$(sed -n 's/^IMAGE_SHA256=//p' "$dest/.n1i-d0-materialized")"
    actual="$(sha_file "$image")"
    if [[ "$expected" == "$actual" ]]; then
      echo "N1I_D0_INPUT_${label}_MATERIALIZE=REUSE"
      return 0
    fi
    fail "${label}_reuse_binding_mismatch" 65
  fi

  rm -rf "$dest"
  mkdir -p "$dest" || fail "${label}_dest_create" 65

  input_type="$(image_type "$image")"
  normalized="$image"
  case "$input_type" in
    sparse)
      raw="$RAW/${label,,}.raw.img"
      rm -f "$raw"
      run_aosp_tool "$SABLE_SIMG2IMG" "$image" "$raw" >/dev/null ||
        fail "${label}_simg2img" 65
      normalized="$raw"
      input_type="$(image_type "$normalized")"
      ;;
  esac

  case "$input_type" in
    ext4)
      "$DEBUGFS" -R "rdump / $dest" "$normalized" >/dev/null 2>"$OUT/${label}.debugfs.log" ||
        fail "${label}_debugfs_rdump" 65
      ;;
    erofs)
      [[ -n "$FSCK_EROFS" && -x "$FSCK_EROFS" ]] ||
        fail "${label}_fsck_erofs_missing" 64
      extract_log="$OUT/${label}.erofs.log"
      "$FSCK_EROFS" --extract="$dest" "$normalized" >"$extract_log" 2>&1 ||
        fail "${label}_erofs_extract" 65
      ;;
    *)
      fail "${label}_unsupported_image_type=$input_type" 65 ;;
  esac

  [[ -n "$(find "$dest" -mindepth 1 -print -quit)" ]] ||
    fail "${label}_materialize_empty" 65

  {
    echo "IMAGE_SHA256=$(sha_file "$image")"
    echo "IMAGE_BYTES=$(bytes_file "$image")"
    echo "IMAGE_TYPE=$input_type"
    echo "SOURCE_PATH=$image"
  } > "$dest/.n1i-d0-materialized"

  echo "N1I_D0_INPUT_${label}_MATERIALIZE=PASS type=$input_type"
}

echo "===== N1I-D0-0H INPUT MATERIALIZATION ====="
echo "TOOL_SOURCE_COMMIT=$TOOL_SOURCE_COMMIT"
echo "BUILD_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "MODE_TRANSITION_AUTHORIZED=NO"
echo "REBOOT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"

materialize_image N1F_SYSTEM "$N1F_SYSTEM" "$ROOTS/n1f-system"
materialize_image C2_SYSTEM "$C2_SYSTEM" "$ROOTS/c2-system"
materialize_image STOCK_SYSTEM "$STOCK_SYSTEM" "$ROOTS/stock-system"
materialize_image STOCK_SYSTEM_EXT "$STOCK_SYSTEM_EXT" "$ROOTS/stock-system_ext"
materialize_image STOCK_PRODUCT "$STOCK_PRODUCT" "$ROOTS/stock-product"
materialize_image STOCK_VENDOR "$STOCK_VENDOR" "$ROOTS/stock-vendor"
if [[ -f "$STOCK_ODM" ]]; then
  materialize_image STOCK_ODM "$STOCK_ODM" "$ROOTS/stock-odm"
fi

tool_record() {
  local label="$1" path="$2"
  local version=""
  [[ -x "$path" ]] || return 0
  version="$("$path" --version 2>&1 | head -1 || true)"
  printf '%s\t%s\t%s\t%s\n' "$label" "$path" "$(sha_file "$path")" "$version"
}

{
  echo -e "tool\tpath\tsha256\tversion"
  tool_record simg2img "$SABLE_SIMG2IMG"
  tool_record secilc "$SABLE_SECILC"
  tool_record debugfs "$DEBUGFS"
  [[ -n "$FSCK_EROFS" ]] && tool_record fsck_erofs "$FSCK_EROFS"
  tool_record readelf "$READELF"
} > "$OUT/TOOLS.tsv"

cat > "$OUT/INPUTS.env" <<EOF
N1I_D0_INPUT_MANIFEST_VERSION=1
TOOL_SOURCE_COMMIT=$TOOL_SOURCE_COMMIT
C2_BUILD_SOURCE_COMMIT=27d671b004f5ae7394f147018fc4fffdf4d78498
B2_ANALYZER_PROVENANCE_COMMIT=1697f21989b8ed6f1db90f8886952894592c7d0f
N1F_SYSTEM_PATH=$N1F_SYSTEM
N1F_SYSTEM_SHA256=$EXPECTED_N1F_SHA
N1F_SYSTEM_BYTES=$EXPECTED_N1F_BYTES
C2_SYSTEM_PATH=$C2_SYSTEM
C2_SYSTEM_SHA256=$EXPECTED_C2_SHA
C2_SYSTEM_BYTES=$EXPECTED_C2_BYTES
STOCK_REF_DIR=$STOCK_REF
STOCK_SYSTEM_SHA256=$EXPECTED_STOCK_SYSTEM_SHA
STOCK_SYSTEM_EXT_SHA256=$EXPECTED_STOCK_SYSTEM_EXT_SHA
STOCK_PRODUCT_SHA256=$EXPECTED_STOCK_PRODUCT_SHA
STOCK_VENDOR_SHA256=$EXPECTED_STOCK_VENDOR_SHA
STOCK_ODM_STATUS=$STOCK_ODM_STATUS
STOCK_ODM_SHA256=${STOCK_ODM_SHA:-}
STOCK_ODM_BYTES=${STOCK_ODM_BYTES:-}
N1F_ROOT=$ROOTS/n1f-system
C2_ROOT=$ROOTS/c2-system
STOCK_SYSTEM_ROOT=$ROOTS/stock-system
STOCK_SYSTEM_EXT_ROOT=$ROOTS/stock-system_ext
STOCK_PRODUCT_ROOT=$ROOTS/stock-product
STOCK_VENDOR_ROOT=$ROOTS/stock-vendor
STOCK_ODM_ROOT=$ROOTS/stock-odm
EOF

(
  cd "$OUT" || exit 1
  sha256sum INPUTS.env TOOLS.tsv > SHA256SUMS.txt
  sha256sum -c SHA256SUMS.txt >/dev/null
) || fail input_manifest_seal 66

repo_status_after="$(git -C "$ROOT" status --porcelain=v1 --untracked-files=all)" ||
  fail repo_status_after 66
[[ -z "$repo_status_after" ]] || fail repo_mutated_by_input_prep 66

echo "N1I_D0_INPUT_MANIFEST=PASS"
echo "N1I_D0_INPUT_STOCK_ODM=$STOCK_ODM_STATUS"
echo "N1I_D0_INPUT_PREP=PASS"
echo "N1I_D0_INPUT_DIR=$OUT"
