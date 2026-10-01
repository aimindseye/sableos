#!/usr/bin/env bash
# SableOS Titan 2 N1D C0 — offline root-cause and control qualification.
# Host-only. No adb, no fastboot, no build, no flash, no network fetch.
set -euo pipefail

SCRIPT_VERSION="1.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="$SCRIPT_DIR/n1d-c0-inspect.py"
CONFIG=""
OUT=""
KEEP_WORK=0

usage() {
  cat <<'EOF'
Usage:
  qualify-n1d-c0-offline.sh --config FILE [--out DIR] [--keep-work]

Required policy:
  DEVICE_CONTACT_AUTHORIZED=NO
  BUILD_AUTHORIZED=NO
  FLASH_AUTHORIZED=NO
  NETWORK_FETCH_AUTHORIZED=NO

The config supplies local artifact/workspace paths. The script is read-only with
respect to all inputs and writes only beneath --out.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config) CONFIG="${2:-}"; shift 2 ;;
    --out) OUT="${2:-}"; shift 2 ;;
    --keep-work) KEEP_WORK=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done
[[ -n "$CONFIG" && -f "$CONFIG" ]] || { echo "ERROR: --config FILE is required" >&2; exit 2; }
[[ -f "$HELPER" ]] || { echo "ERROR: missing helper $HELPER" >&2; exit 3; }

# shellcheck disable=SC1090
source "$CONFIG"

: "${DEVICE_CONTACT_AUTHORIZED:=NO}"
: "${BUILD_AUTHORIZED:=NO}"
: "${FLASH_AUTHORIZED:=NO}"
: "${NETWORK_FETCH_AUTHORIZED:=NO}"
[[ "$DEVICE_CONTACT_AUTHORIZED" == "NO" ]] || { echo "ERROR: C0 requires DEVICE_CONTACT_AUTHORIZED=NO" >&2; exit 2; }
[[ "$BUILD_AUTHORIZED" == "NO" ]] || { echo "ERROR: C0 requires BUILD_AUTHORIZED=NO" >&2; exit 2; }
[[ "$FLASH_AUTHORIZED" == "NO" ]] || { echo "ERROR: C0 requires FLASH_AUTHORIZED=NO" >&2; exit 2; }
[[ "$NETWORK_FETCH_AUTHORIZED" == "NO" ]] || { echo "ERROR: C0 requires NETWORK_FETCH_AUTHORIZED=NO" >&2; exit 2; }

TS="$(date +%Y%m%d_%H%M%S)"
OUT="${OUT:-${EVIDENCE_ROOT:-/srv/data/sable-build/evidence/titan2}/n1d-c0-offline-${TS}}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
[[ "$OUT" != "/" ]] || { echo "ERROR: invalid output root /" >&2; exit 2; }
WORK="$OUT/work"
mkdir -p "$WORK" "$OUT/logs" "$OUT/reports" "$OUT/inventory"
SUMMARY="$OUT/N1D_C0_OFFLINE_SUMMARY.env"
GATES="$OUT/N1D_C0_GATES.tsv"
: > "$SUMMARY"
printf 'gate\tstatus\tdetail\n' > "$GATES"

declare -A GSTAT GDETAIL
BLOCKING_GATES=(C0_02_MOUNT_MODEL C0_03_FRAMEWORK_VIEW C0_04_GSI_CONTRACT C0_05_VINTF C0_06_SEPOLICY C0_07_AVB_CHAIN C0_08_AVB_BOUNDARY C0_09_LP_METADATA C0_10_CONTROL_DIFF C0_12_TOOLCHAIN_SEAL)

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
record() { printf '%s=%s\n' "$1" "$2" >> "$SUMMARY"; }
gate() {
  local name="$1" status="$2" detail="${3:-}"
  GSTAT["$name"]="$status"; GDETAIL["$name"]="$detail"
  printf '%s\t%s\t%s\n' "$name" "$status" "${detail//$'\t'/ }" >> "$GATES"
  printf '%s=%s\n' "$name" "$status" >> "$SUMMARY"
}

cleanup() {
  local rc=$?
  trap - EXIT INT TERM
  if [[ "$KEEP_WORK" -ne 1 && -d "$WORK" ]]; then rm -rf "$WORK"; fi
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# ---------------------------- static authorization banner
cat <<EOF | tee "$OUT/00_POLICY.txt"
===== TITAN 2 N1D C0 OFFLINE QUALIFICATION =====
SCRIPT_VERSION=$SCRIPT_VERSION
DEVICE_CONTACT_AUTHORIZED=NO
BUILD_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
NETWORK_FETCH_AUTHORIZED=NO
SOURCE_MUTATION_AUTHORIZED=NO
INPUT_MUTATION_AUTHORIZED=NO
OUTPUT_MUTATION_AUTHORIZED=YES_EVIDENCE_DIR_ONLY
OUT=$OUT
EOF
record N1D_C0_SCRIPT_VERSION "$SCRIPT_VERSION"
record DEVICE_CONTACT_AUTHORIZED NO
record BUILD_AUTHORIZED NO
record FLASH_AUTHORIZED NO
record NETWORK_FETCH_AUTHORIZED NO
record OUTPUT "$OUT"

# ---------------------------- config defaults from N1C public checkpoint
: "${SABLE_REPO:=/srv/data/sable-build/sableos/repo}"
: "${TITAN2_REPO:=/srv/data/sable-build/titan2/repo}"
: "${N1C_WORKSPACE:=/srv/data/sable-build/workspaces/titan2-n1c-android16-hybrid-super-20260930_140947}"
: "${N1C_OUT_DIR:=$N1C_WORKSPACE/out_n1c_aosp_arm64_systemimage_apns_source_filter}"
: "${N1C_SYSTEM_IMG:=$N1C_OUT_DIR/target/product/generic_arm64/system.img}"
: "${N1C_SUPER_IMG:=/srv/data/sable-build/evidence/titan2/n1c-no-flash-hybrid-super-composition-r1f-20260930_185012/titan2-n1c-hybrid-super-r1f.sparse.img}"
: "${STOCK_REF_DIR:=/srv/data/sable-build/titan2/artifacts/stock-firmware/unihertz-device-fota-20260922/inspection/bit-equivalence/TEE14-large-reference}"
: "${STOCK_SUPER_IMG:=$STOCK_REF_DIR/super.img}"
: "${STOCK_VENDOR_BOOT_IMG:=$STOCK_REF_DIR/vendor_boot.img}"
: "${STOCK_INIT_BOOT_IMG:=$STOCK_REF_DIR/init_boot.img}"
: "${STOCK_VBMETA_IMG:=$STOCK_REF_DIR/vbmeta.img}"
: "${STOCK_VBMETA_SYSTEM_IMG:=$STOCK_REF_DIR/vbmeta_system.img}"
: "${STOCK_VBMETA_VENDOR_IMG:=$STOCK_REF_DIR/vbmeta_vendor.img}"
: "${STOCK_SUPER_ARTIFACT_EVID:=/srv/data/sable-build/evidence/titan2/n1c-stock-super-restore-artifact-r1c-20260930_200124}"
: "${TEE14_BOOT_AVB_EVID:=/srv/data/sable-build/evidence/titan2/n1c-restore-tee14-boot-avb-direct-20260930_204335}"
: "${RELEASE_REGISTRY:=/srv/data/sable-build/release-registry}"
: "${N1B_OUT_DIR:=/srv/data/sable-build/workspaces/titan2-n1b/out_sable_t2_n1_sable_gsi}"
: "${RESTLESS_SYSTEM_IMG:=}"
: "${N1B_CONTROL_SYSTEM_IMG:=$N1B_OUT_DIR/target/product/tdgsi_arm64_ab/system.img}"
: "${N1B_CONTROL_EXPECTED_SHA256:=bc550bfaf8463324c122abb490cf4aba956b89e7e4d42168a55f0f0f0f5b638e}"
: "${N1B_CONTROL_EXPECTED_BYTES:=3180666880}"
: "${N1B_BOOT_PROOF:=$SABLE_REPO/docs/titan2/N1B_FIRST_BOOT_LEDGER_AND_N1B2_HANDOFF.md}"
: "${N1B1_INPUT:=}"
: "${N1B2_INPUT:=}"
: "${N1D_PRODUCT_FILE:=}"
: "${N1D_PRODUCT_CONTRACT_FILE:=$SABLE_REPO/build/titan2/n1d-product-contract.env}"

if [[ -z "$N1D_PRODUCT_FILE" ]]; then
  mapfile -t N1D_PRODUCT_CANDIDATES < <(
    find /srv/data/sable-build/workspaces/titan2-n1b \
      -type f -path '*/device/phh/treble/treble_arm64_bvN.mk' -print 2>/dev/null | sort -u
  )
  if [[ ${#N1D_PRODUCT_CANDIDATES[@]} -eq 1 ]]; then
    N1D_PRODUCT_FILE="${N1D_PRODUCT_CANDIDATES[0]}"
  else
    mapfile -t N1D_PRODUCT_CANDIDATES < <(
      find /srv/data/sable-build/workspaces/titan2-n1b \
           /srv/data/sable-build/workspaces/titan2-n1c-android16-hybrid-super-* \
        -type f -path '*/device/phh/treble/treble_arm64_bvN.mk' -print 2>/dev/null | sort -u
    )
    if [[ ${#N1D_PRODUCT_CANDIDATES[@]} -eq 1 ]]; then
      N1D_PRODUCT_FILE="${N1D_PRODUCT_CANDIDATES[0]}"
    fi
  fi
fi
: "${STOCK_FIRST_STAGE_TREE:=}"
: "${SEPOLICY_VERSION:=30}"
: "${VINTF_FIRST_API_LEVEL:=}"
: "${VINTF_HARDWARE_SKU:=}"
: "${CELLULAR_AUDIT_TOOL:=$SABLE_REPO/build/titan2/audit-n1b2-cellular-stack.sh}"
: "${CAPTURE_TOOL:=$SABLE_REPO/build/titan2/capture-n1b2-cellular-runtime.sh}"
: "${CLASSIFIER_TOOL:=$SABLE_REPO/build/titan2/classify-n1b2-nr-state.py}"

N1C_EXPECTED_SYSTEM_SHA256="ed9edad3c65e4908028bb6087bbb712efff81bd4fe6601cc6cc6f0273b545c5d"
N1C_EXPECTED_SUPER_SHA256="d97e53f5e4b3f23245b600b311c6071eb9ab7897be093ea21dea83bbde3f3711"
ENG2_AUDIT_SHA256="b02d0da22de0f0cecca8a0793acd216ddecebafd9a51fae9c708936832c17c28"
ENG2_CAPTURE_SHA256="50344ffe5de82986299175587e152b493add8e930a90aa9dd55aba89351b721a"
ENG2_CLASSIFIER_SHA256="7833e2235a151f4ae2f628c597624c02d93cd81ed558da5af5eaa73a47f5a6e9"

sha() { sha256sum "$1" | awk '{print $1}'; }

resolve_evidence_exact() {
  local current evidence base
  current="$1"
  evidence="$2"
  base="$3"
  if [[ -f "$current" ]]; then
    printf '%s\n' "$current"
    return 0
  fi
  [[ -d "$evidence" ]] || return 1
  local -a hits=()
  mapfile -t hits < <(find "$evidence" -type f -name "$base" -print 2>/dev/null | sort -u)
  if [[ ${#hits[@]} -eq 1 ]]; then
    printf '%s\n' "${hits[0]}"
    return 0
  fi
  mapfile -t hits < <(
    grep -RhoE "/[^[:space:]\"']*/$base" "$evidence" 2>/dev/null |
      sort -u |
      while IFS= read -r p; do [[ -f "$p" ]] && printf '%s\n' "$p"; done
  )
  [[ ${#hits[@]} -eq 1 ]] || return 1
  printf '%s\n' "${hits[0]}"
}

resolve_n1b_control() {
  if [[ -f "$N1B_CONTROL_SYSTEM_IMG" ]] && [[ "$(sha "$N1B_CONTROL_SYSTEM_IMG")" == "$N1B_CONTROL_EXPECTED_SHA256" ]]; then
    printf '%s\n' "$N1B_CONTROL_SYSTEM_IMG"
    return 0
  fi
  if [[ -d "$RELEASE_REGISTRY/titan2/N1B" ]]; then
    local registry_hit
    registry_hit="$(python3 - "$RELEASE_REGISTRY/titan2/N1B" "$N1B_CONTROL_EXPECTED_SHA256" <<'PY'
import json, pathlib, sys
root=pathlib.Path(sys.argv[1]); expected=sys.argv[2]; hits=[]
for manifest in sorted(root.glob("*.json")):
    try:
        doc=json.loads(manifest.read_text())
    except Exception:
        continue
    for item in (doc.get("artifacts") or {}).values():
        if not isinstance(item, dict) or item.get("sha256") != expected:
            continue
        p=pathlib.Path(str(item.get("path","")))
        if p.is_file():
            hits.append(str(p.resolve()))
hits=sorted(set(hits))
if len(hits)==1:
    print(hits[0])
PY
)"
    if [[ -n "$registry_hit" ]]; then
      printf '%s\n' "$registry_hit"
      return 0
    fi
  fi
  local candidate tf extracted
  while IFS= read -r candidate; do
    [[ -f "$candidate" ]] || continue
    if [[ "$(sha "$candidate")" == "$N1B_CONTROL_EXPECTED_SHA256" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done < <(
    find /srv/data/sable-build/workspaces \
         /srv/data/sable-build/evidence/titan2 \
         /srv/data/sable-build/titan2/artifacts \
         /srv/data/sable-build/artifacts/titan2 \
      -type f -size "${N1B_CONTROL_EXPECTED_BYTES}c" \
      \( -name '*.img' -o -name 'system' \) -path '*titan2*' -print 2>/dev/null | sort -u
  )

  command -v unzip >/dev/null || return 1
  while IFS= read -r tf; do
    [[ -f "$tf" ]] || continue
    if unzip -Z1 "$tf" 2>/dev/null | grep -Fxq 'IMAGES/system.img'; then
      extracted="$WORK/n1b-control-from-target-files.img"
      rm -f "$extracted"
      unzip -p "$tf" IMAGES/system.img > "$extracted" || { rm -f "$extracted"; continue; }
      if [[ "$(stat -c '%s' "$extracted")" == "$N1B_CONTROL_EXPECTED_BYTES" ]] \
        && [[ "$(sha "$extracted")" == "$N1B_CONTROL_EXPECTED_SHA256" ]]; then
        record N1B_CONTROL_TARGET_FILES_SOURCE "$tf"
        printf '%s\n' "$extracted"
        return 0
      fi
      rm -f "$extracted"
    fi
  done < <(
    find /srv/data/sable-build/workspaces /srv/data/sable-build/evidence/titan2 /srv/data/sable-build/titan2/artifacts \
      -type f \( -iname '*target_files*.zip' -o -iname '*target-files*.zip' \) -path '*n1b*' -print 2>/dev/null | sort -u
  )
  return 1
}

if ! [[ -f "$N1B_CONTROL_SYSTEM_IMG" ]] || [[ "$(sha "$N1B_CONTROL_SYSTEM_IMG" 2>/dev/null || true)" != "$N1B_CONTROL_EXPECTED_SHA256" ]]; then
  N1B_CONTROL_SYSTEM_IMG="$(resolve_n1b_control || true)"
fi

STOCK_VBMETA_IMG="$(resolve_evidence_exact "$STOCK_VBMETA_IMG" "$TEE14_BOOT_AVB_EVID" vbmeta.img || printf '%s' "$STOCK_VBMETA_IMG")"
STOCK_VBMETA_SYSTEM_IMG="$(resolve_evidence_exact "$STOCK_VBMETA_SYSTEM_IMG" "$TEE14_BOOT_AVB_EVID" vbmeta_system.img || printf '%s' "$STOCK_VBMETA_SYSTEM_IMG")"
STOCK_VBMETA_VENDOR_IMG="$(resolve_evidence_exact "$STOCK_VBMETA_VENDOR_IMG" "$TEE14_BOOT_AVB_EVID" vbmeta_vendor.img || printf '%s' "$STOCK_VBMETA_VENDOR_IMG")"

# Resolve Android host tools, preferring direct OUT binaries. If a partial
# systemimage OUT omitted otatools, recover the host binaries from an existing
# local otatools.zip without building or fetching anything.
resolve_otatools_zip() {
  command -v unzip >/dev/null || return 1
  local z
  while IFS= read -r z; do
    [[ -f "$z" ]] || continue
    if unzip -Z1 "$z" 2>/dev/null | grep -Fxq 'bin/checkvintf' \
      && unzip -Z1 "$z" 2>/dev/null | grep -Fxq 'bin/lpdump' \
      && unzip -Z1 "$z" 2>/dev/null | grep -Fxq 'bin/lpunpack'; then
      printf '%s\n' "$z"
      return 0
    fi
  done < <(
    {
      find "$N1B_OUT_DIR" -type f -iname 'otatools*.zip' -print 2>/dev/null || true
      find /srv/data/sable-build/evidence/titan2 -type f -iname 'otatools*.zip' -path '*n1b*' -print 2>/dev/null || true
      find "$N1C_OUT_DIR" -type f -iname 'otatools*.zip' -print 2>/dev/null || true
      find /srv/data/sable-build/workspaces -maxdepth 10 -type f -iname 'otatools*.zip' -print 2>/dev/null || true
    } | sort -u
  )
  return 1
}

OTATOOLS_ZIP="$(resolve_otatools_zip || true)"
OTATOOLS_ROOT=""
if [[ -n "$OTATOOLS_ZIP" ]]; then
  OTATOOLS_ROOT="$WORK/otatools"
  mkdir -p "$OTATOOLS_ROOT"
  unzip -q "$OTATOOLS_ZIP" \
    'bin/checkvintf' 'bin/lpdump' 'bin/lpunpack' \
    'lib64/*' 'lib/*' -d "$OTATOOLS_ROOT" 2>"$OUT/logs/otatools-extract.log" || true
  chmod +x "$OTATOOLS_ROOT"/bin/checkvintf "$OTATOOLS_ROOT"/bin/lpdump "$OTATOOLS_ROOT"/bin/lpunpack 2>/dev/null || true
fi
record OTATOOLS_ZIP_RESOLVED "${OTATOOLS_ZIP:--}"

HOST_BIN="$N1C_OUT_DIR/host/linux-x86/bin"
resolve_tool() {
  local n override p root
  n="$1"
  override="${2:-}"
  if [[ -n "$override" && -x "$override" ]]; then printf '%s\n' "$override"; return 0; fi
  if [[ -x "$HOST_BIN/$n" ]]; then printf '%s\n' "$HOST_BIN/$n"; return 0; fi
  if [[ -x "$N1B_OUT_DIR/host/linux-x86/bin/$n" ]]; then printf '%s\n' "$N1B_OUT_DIR/host/linux-x86/bin/$n"; return 0; fi
  if [[ -n "$OTATOOLS_ROOT" && -x "$OTATOOLS_ROOT/bin/$n" ]]; then printf '%s\n' "$OTATOOLS_ROOT/bin/$n"; return 0; fi
  while IFS= read -r root; do
    [[ -x "$root" ]] || continue
    printf '%s\n' "$root"
    return 0
  done < <(
    find /srv/data/sable-build/workspaces \
      -maxdepth 8 -type f -path "*/host/linux-x86/bin/$n" -print 2>/dev/null | sort -u
  )
  p="$(command -v "$n" 2>/dev/null || true)"
  if [[ -n "$p" ]]; then printf '%s\n' "$p"; return 0; fi
  return 1
}
SIMG2IMG="$(resolve_tool simg2img "${SIMG2IMG_TOOL:-}" || true)"
LPUNPACK="$(resolve_tool lpunpack "${LPUNPACK_TOOL:-}" || true)"
LPDUMP="$(resolve_tool lpdump "${LPDUMP_TOOL:-}" || true)"
AVBTOOL="$(resolve_tool avbtool "${AVBTOOL_TOOL:-}" || true)"
CHECKVINTF="$(resolve_tool checkvintf "${CHECKVINTF_TOOL:-}" || true)"
SECILC="$(resolve_tool secilc "${SECILC_TOOL:-}" || true)"
UNPACK_BOOTIMG="$(resolve_tool unpack_bootimg "${UNPACK_BOOTIMG_TOOL:-}" || true)"

record TOOL_SIMG2IMG "${SIMG2IMG:--}"
record TOOL_LPUNPACK "${LPUNPACK:--}"
record TOOL_LPDUMP "${LPDUMP:--}"
record TOOL_AVBTOOL "${AVBTOOL:--}"
record TOOL_CHECKVINTF "${CHECKVINTF:--}"
record TOOL_SECILC "${SECILC:--}"
record TOOL_UNPACK_BOOTIMG "${UNPACK_BOOTIMG:--}"
record N1B_CONTROL_SYSTEM_IMG_RESOLVED "${N1B_CONTROL_SYSTEM_IMG:--}"
record STOCK_VBMETA_IMG_RESOLVED "${STOCK_VBMETA_IMG:--}"
record STOCK_VBMETA_SYSTEM_IMG_RESOLVED "${STOCK_VBMETA_SYSTEM_IMG:--}"
record STOCK_VBMETA_VENDOR_IMG_RESOLVED "${STOCK_VBMETA_VENDOR_IMG:--}"

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

# Image detection/extraction helpers. All writes are under WORK.
hexat() { od -An -tx1 -j "$2" -N "$3" "$1" 2>/dev/null | tr -d ' \n'; }
image_type() {
  local f="$1"
  [[ -f "$f" ]] || { echo none; return; }
  [[ "$(hexat "$f" 0 4)" == "3aff26ed" ]] && { echo sparse; return; }
  [[ "$(hexat "$f" 4096 4)" == "67446c61" ]] && { echo super; return; }
  [[ "$(hexat "$f" 1080 2)" == "53ef" ]] && { echo ext4; return; }
  [[ "$(hexat "$f" 1024 4)" == "e2e1f5e0" ]] && { echo erofs; return; }
  echo unknown
}

normalize_raw() {
  local src="$1" dst="$2" t
  t="$(image_type "$src")"
  if [[ "$t" == sparse ]]; then
    [[ -n "$SIMG2IMG" ]] || return 3
    run_host_tool "$SIMG2IMG" "$src" "$dst" >/dev/null
    echo "$dst"
  else
    echo "$src"
  fi
}

extract_fs() {
  local img="$1" dest="$2" t raw
  raw="$img"
  mkdir -p "$dest"
  t="$(image_type "$img")"
  if [[ "$t" == sparse ]]; then
    [[ -n "$SIMG2IMG" ]] || return 3
    raw="$dest.__raw.img"
    run_host_tool "$SIMG2IMG" "$img" "$raw" >/dev/null
    t="$(image_type "$raw")"
  fi
  case "$t" in
    ext4)
      command -v debugfs >/dev/null || return 3
      debugfs -R "rdump / $dest" "$raw" >"$dest.debugfs.stdout" 2>"$dest.debugfs.log" || return 4
      grep -qiE 'while trying to open|filesystem not open|bad magic|corrupt|short read|cannot open|not a valid|i/o error|error:' "$dest.debugfs.log" && return 4
      ;;
    erofs)
      if command -v fsck.erofs >/dev/null; then fsck.erofs --extract="$dest" "$raw" >"$dest.erofs.stdout" 2>"$dest.erofs.log" || return 4
      elif command -v extract.erofs >/dev/null; then extract.erofs -i "$raw" -o "$dest" -x >"$dest.erofs.stdout" 2>"$dest.erofs.log" || return 4
      else return 3; fi
      ;;
    *) return 4 ;;
  esac
  [[ -n "$(find "$dest" -mindepth 1 -print -quit 2>/dev/null)" ]] || return 4
  [[ "$raw" == "$img" ]] || rm -f "$raw"
}

system_root() {
  local d="$1"
  if [[ -f "$d/build.prop" ]]; then echo "$d"
  elif [[ -f "$d/system/build.prop" ]]; then echo "$d/system"
  else echo "$d"; fi
}

# Unpack Android boot/vendor_boot ramdisk fragments when possible.
unpack_cpio_blob() {
  local blob="$1" dest="$2" magic tmp="$WORK/ramdisk.tmp.$$"
  mkdir -p "$dest"
  magic="$(hexat "$blob" 0 4)"
  case "$magic" in
    1f8b*) gzip -dc "$blob" > "$tmp" || return 1 ;;
    04224d18|02214c18)
      command -v lz4 >/dev/null || return 1
      lz4 -dc "$blob" > "$tmp" 2>/dev/null || return 1 ;;
    30373037) cp "$blob" "$tmp" ;;
    *) return 1 ;;
  esac
  (cd "$dest" && cpio -idm --no-absolute-filenames < "$tmp" >/dev/null 2>&1) || { rm -f "$tmp"; return 1; }
  rm -f "$tmp"
}

# ---------------------------- C0_00 input and N1C seal
log "C0_00 preflight and immutable N1C artifact seal"
PREFAIL=0
for p in "$N1C_SYSTEM_IMG" "$N1C_SUPER_IMG" "$STOCK_REF_DIR"; do [[ -e "$p" ]] || PREFAIL=1; done
if [[ "$PREFAIL" -ne 0 ]]; then gate C0_00_PREFLIGHT FAIL "required N1C/stock input missing"; else gate C0_00_PREFLIGHT PASS "required N1C/stock roots present"; fi
if [[ -f "$N1C_SYSTEM_IMG" ]]; then
  h="$(sha "$N1C_SYSTEM_IMG")"; record N1C_SYSTEM_SHA256 "$h"
  [[ "$h" == "$N1C_EXPECTED_SYSTEM_SHA256" ]] || gate C0_00_N1C_SYSTEM_SEAL FAIL "N1C system hash mismatch"
fi
if [[ -z "${GSTAT[C0_00_N1C_SYSTEM_SEAL]:-}" ]]; then gate C0_00_N1C_SYSTEM_SEAL PASS "N1C system hash matches checkpoint"; fi
if [[ -f "$N1C_SUPER_IMG" ]]; then
  h="$(sha "$N1C_SUPER_IMG")"; record N1C_SUPER_SHA256 "$h"
  [[ "$h" == "$N1C_EXPECTED_SUPER_SHA256" ]] || gate C0_00_N1C_SUPER_SEAL FAIL "N1C super hash mismatch"
fi
if [[ -z "${GSTAT[C0_00_N1C_SUPER_SEAL]:-}" ]]; then gate C0_00_N1C_SUPER_SEAL PASS "N1C super hash matches checkpoint"; fi

# ---------------------------- C0_01 historical N1B evidence qualification
log "C0_01 historical N1B evidence search"
{
  echo "# Candidate N1B evidence and artifacts"
  for root in "/srv/data/sable-build/evidence/titan2" "/srv/data/sable-build/titan2/artifacts" "/srv/data/sable-build/workspaces"; do
    [[ -d "$root" ]] || continue
    find "$root" -maxdepth 5 \( -iname '*n1b*' -o -iname '*N1B*' \) -print 2>/dev/null | head -500
  done
} > "$OUT/reports/C0_01_N1B_CANDIDATES.txt"
if [[ -n "$N1B_CONTROL_SYSTEM_IMG" && -f "$N1B_CONTROL_SYSTEM_IMG" ]]; then
  n1bh="$(sha "$N1B_CONTROL_SYSTEM_IMG")"; record N1B_CONTROL_SYSTEM_SHA256 "$n1bh"
  if [[ -n "$N1B_CONTROL_EXPECTED_SHA256" && "$n1bh" == "$N1B_CONTROL_EXPECTED_SHA256" && -f "$N1B_BOOT_PROOF" ]] \
    && grep -Fq "SYSTEM_SHA256=$N1B_CONTROL_EXPECTED_SHA256" "$N1B_BOOT_PROOF" \
    && grep -Fq 'BOOT_COMPLETED=PASS' "$N1B_BOOT_PROOF" \
    && grep -Fq 'FIRST_N1B_BOOT=PASS' "$N1B_BOOT_PROOF" \
    && grep -Fq 'ro.boot.verifiedbootstate=orange' "$N1B_BOOT_PROOF"; then
    gate C0_01_N1B_CONTROL PASS "QUALIFIED_HISTORICAL"
    record N1B_CONTROL_CLASS QUALIFIED_HISTORICAL
  else
    gate C0_01_N1B_CONTROL PASS "UNQUALIFIED_HISTORICAL; fresh control required later"
    record N1B_CONTROL_CLASS UNQUALIFIED_HISTORICAL
  fi
else
  gate C0_01_N1B_CONTROL PASS "UNQUALIFIED_HISTORICAL; no hash-bound candidate supplied"
  record N1B_CONTROL_CLASS UNQUALIFIED_HISTORICAL
fi

# ---------------------------- extract N1C system and stock framework/vendor partitions
log "Extracting read-only offline views"
N1C_SYS_EX="$WORK/n1c-system"
if extract_fs "$N1C_SYSTEM_IMG" "$N1C_SYS_EX"; then :; else gate C0_02_MOUNT_MODEL FAIL "cannot extract N1C system.img"; fi
N1C_SYS_ROOT="$(system_root "$N1C_SYS_EX")"
python3 "$HELPER" system-report --root "$N1C_SYS_EX" --label n1c --out "$OUT/inventory/n1c-system.env" || true

extract_stock_part() {
  local part="$1" out img
  out="$WORK/stock-$part"
  img="$STOCK_REF_DIR/$part.img"
  [[ -f "$img" ]] || return 1
  extract_fs "$img" "$out" || return 1
  echo "$out"
}
STOCK_PRODUCT_EX="$(extract_stock_part product || true)"
STOCK_SYSTEM_EXT_EX="$(extract_stock_part system_ext || true)"
STOCK_VENDOR_EX="$(extract_stock_part vendor || true)"
STOCK_ODM_EX="$(extract_stock_part odm || true)"

# ---------------------------- C0_02 mount model: skip_mount + first-stage fstab evidence
if [[ -z "${GSTAT[C0_02_MOUNT_MODEL]:-}" ]]; then
  SKIP_CFG=""
  for p in "$N1C_SYS_ROOT/etc/init/config/skip_mount.cfg" "$N1C_SYS_ROOT/system_ext/etc/init/config/skip_mount.cfg"; do [[ -f "$p" ]] && SKIP_CFG="$p"; done
  if [[ -n "$SKIP_CFG" ]]; then cp "$SKIP_CFG" "$OUT/reports/C0_02_skip_mount.cfg"; fi
  SKIP_PRODUCT=NO; SKIP_SYSTEM_EXT=NO
  [[ -n "$SKIP_CFG" ]] && grep -Eq '^/product([/*]|$)' "$SKIP_CFG" && SKIP_PRODUCT=YES
  [[ -n "$SKIP_CFG" ]] && grep -Eq '^/system_ext([/*]|$)' "$SKIP_CFG" && SKIP_SYSTEM_EXT=YES
  record N1C_SKIP_PRODUCT "$SKIP_PRODUCT"; record N1C_SKIP_SYSTEM_EXT "$SKIP_SYSTEM_EXT"

  FSTAB_ROOT="$STOCK_FIRST_STAGE_TREE"
  if [[ -z "$FSTAB_ROOT" || ! -d "$FSTAB_ROOT" ]]; then
    BOOTEX="$WORK/stock-boot-extracted"; mkdir -p "$BOOTEX"
    if [[ -n "$UNPACK_BOOTIMG" && -f "$STOCK_VENDOR_BOOT_IMG" ]]; then
      VBOUT="$BOOTEX/vendor_boot"; mkdir -p "$VBOUT"
      run_host_tool "$UNPACK_BOOTIMG" --boot_img "$STOCK_VENDOR_BOOT_IMG" --out "$VBOUT" >"$OUT/logs/unpack_vendor_boot.log" 2>&1 || true
      mkdir -p "$BOOTEX/ramdisks"
      for blob in "$VBOUT"/vendor_ramdisk*; do
        [[ -f "$blob" ]] || continue
        unpack_cpio_blob "$blob" "$BOOTEX/ramdisks/$(basename "$blob")" || true
      done
    fi
    if [[ -n "$UNPACK_BOOTIMG" && -f "$STOCK_INIT_BOOT_IMG" ]]; then
      IBOUT="$BOOTEX/init_boot"; mkdir -p "$IBOUT"
      run_host_tool "$UNPACK_BOOTIMG" --boot_img "$STOCK_INIT_BOOT_IMG" --out "$IBOUT" >"$OUT/logs/unpack_init_boot.log" 2>&1 || true
      [[ -f "$IBOUT/ramdisk" ]] && unpack_cpio_blob "$IBOUT/ramdisk" "$BOOTEX/ramdisks/init_boot" || true
    fi
    FSTAB_ROOT="$BOOTEX/ramdisks"
  fi
  {
    echo "# first-stage / vendor ramdisk fstab candidates"
    if [[ -d "$FSTAB_ROOT" ]]; then find "$FSTAB_ROOT" -type f \( -name 'fstab*' -o -path '*/fstab/*' \) -print -exec sh -c 'echo "--- $1"; cat "$1"' _ {} \; 2>/dev/null; fi
    echo "# vendor partition fstab candidates"
    if [[ -n "$STOCK_VENDOR_EX" ]]; then find "$STOCK_VENDOR_EX" -type f -name 'fstab*' -print -exec sh -c 'echo "--- $1"; cat "$1"' _ {} \; 2>/dev/null; fi
  } > "$OUT/reports/C0_02_fstab_inventory.txt"
  if [[ "$SKIP_PRODUCT" == YES && "$SKIP_SYSTEM_EXT" == YES ]] && grep -Eq '(^|[[:space:]])/(product|system_ext)([[:space:]]|$)' "$OUT/reports/C0_02_fstab_inventory.txt"; then
    gate C0_02_MOUNT_MODEL PASS "N1C GSI skip_mount explicitly skips product/system_ext; stock fstab entries inventoried"
    record N1C_RUNTIME_PRODUCT_OWNER GSI_SYSTEM_IMAGE
    record N1C_RUNTIME_SYSTEM_EXT_OWNER GSI_SYSTEM_IMAGE
  else
    gate C0_02_MOUNT_MODEL FAIL "mount ownership not fully proven; inspect skip_mount/fstab report"
  fi
fi

# ---------------------------- C0_03 hidden/exposed framework view
if [[ -d "$N1C_SYS_ROOT/product" && -n "$STOCK_PRODUCT_EX" && -d "$STOCK_PRODUCT_EX" ]]; then
  python3 "$HELPER" framework-diff --gsi-root "$N1C_SYS_ROOT/product" --stock-root "$STOCK_PRODUCT_EX" --label product --out-tsv "$OUT/reports/C0_03_product_files.tsv" --out-md "$OUT/reports/C0_03_product_diff.md"
  P_OK=1
else P_OK=0; fi
if [[ -d "$N1C_SYS_ROOT/system_ext" && -n "$STOCK_SYSTEM_EXT_EX" && -d "$STOCK_SYSTEM_EXT_EX" ]]; then
  python3 "$HELPER" framework-diff --gsi-root "$N1C_SYS_ROOT/system_ext" --stock-root "$STOCK_SYSTEM_EXT_EX" --label system_ext --out-tsv "$OUT/reports/C0_03_system_ext_files.tsv" --out-md "$OUT/reports/C0_03_system_ext_diff.md"
  SE_OK=1
else SE_OK=0; fi
if [[ "$P_OK" -eq 1 && "$SE_OK" -eq 1 ]]; then gate C0_03_FRAMEWORK_VIEW PASS "GSI-vs-stock product/system_ext file views generated"; else gate C0_03_FRAMEWORK_VIEW FAIL "missing GSI embedded or stock product/system_ext extraction"; fi

# ---------------------------- C0_04 AOSP GSI product-contract comparison
AOSP_GSI_RELEASE="$N1C_WORKSPACE/build/make/target/product/gsi_release.mk"
if [[ ! -f "$AOSP_GSI_RELEASE" && -n "$N1D_PRODUCT_FILE" && -f "$N1D_PRODUCT_FILE" ]]; then
  PRODUCT_SOURCE_ROOT="$(cd "$(dirname "$N1D_PRODUCT_FILE")/../../.." && pwd)"
  for rel in build/make/target/product/gsi_release.mk build/target/product/gsi_release.mk; do
    if [[ -f "$PRODUCT_SOURCE_ROOT/$rel" ]]; then
      AOSP_GSI_RELEASE="$PRODUCT_SOURCE_ROOT/$rel"
      break
    fi
  done
fi
if [[ ! -f "$AOSP_GSI_RELEASE" ]]; then
  mapfile -t AOSP_GSI_CANDIDATES < <(
    find /srv/data/sable-build/workspaces/titan2-n1b          /srv/data/sable-build/workspaces/titan2-n1c-android16-hybrid-super-*       -type f \( -path '*/build/make/target/product/gsi_release.mk' -o -path '*/build/target/product/gsi_release.mk' \)       -print 2>/dev/null | sort -u
  )
  if [[ ${#AOSP_GSI_CANDIDATES[@]} -eq 1 ]]; then
    AOSP_GSI_RELEASE="${AOSP_GSI_CANDIDATES[0]}"
  fi
fi
record AOSP_GSI_RELEASE_RESOLVED "${AOSP_GSI_RELEASE:--}"
record N1D_PRODUCT_FILE_RESOLVED "${N1D_PRODUCT_FILE:--}"
record N1D_PRODUCT_CONTRACT_FILE_RESOLVED "${N1D_PRODUCT_CONTRACT_FILE:--}"
SABLE_CANDIDATES=()
if [[ -n "$N1D_PRODUCT_FILE" && -f "$N1D_PRODUCT_FILE" ]]; then SABLE_CANDIDATES+=("$N1D_PRODUCT_FILE"); fi
if [[ -d "$SABLE_REPO" ]]; then
  while IFS= read -r p; do SABLE_CANDIDATES+=("$p"); done < <(find "$SABLE_REPO" -maxdepth 6 -type f \( -iname '*titan2*.mk' -o -iname '*gsi*arm64*.mk' -o -iname '*n1c*.mk' \) 2>/dev/null | head -100)
fi
PRODUCT_CONTRACT_OK=YES
if [[ ! -f "$N1D_PRODUCT_CONTRACT_FILE" ]]; then
  PRODUCT_CONTRACT_OK=NO
else
  cp "$N1D_PRODUCT_CONTRACT_FILE" "$OUT/reports/C0_04_n1d_product_contract.env"
  for required in \
    'N1D_BASE_PRODUCT=treble_arm64_bvN' \
    'N1D_PRODUCT_GENERATOR=device/phh/treble/generate.sh' \
    'N1D_GENERATED_ARCH_INCLUDE=build/make/target/product/aosp_arm64.mk' \
    'N1D_TREBLE_BASE=device/phh/treble/base.mk' \
    'N1D_GSI_RELEASE_OWNER=device/phh/treble/base.mk' \
    'N1D_GSI_RELEASE_INCLUDE=build/make/target/product/gsi_release.mk' \
    'N1D_RESTLESS_DELTA=device/phh/treble/rom.mk' \
    'N1D_SABLE_DELTA=vendor/sable/n1d/sable_n1d_product_delta.mk' \
    'N1D_RUNTIME_PRODUCT_OWNER=GSI_SYSTEM_IMAGE' \
    'N1D_RUNTIME_SYSTEM_EXT_OWNER=GSI_SYSTEM_IMAGE' \
    'N1D_PRODUCT_CONTRACT=PASS'; do
    grep -Fxq "$required" "$N1D_PRODUCT_CONTRACT_FILE" || PRODUCT_CONTRACT_OK=NO
  done
fi

if [[ -f "$AOSP_GSI_RELEASE" ]]; then
  args=(gsi-contract --aosp "$AOSP_GSI_RELEASE" --out-json "$OUT/reports/C0_04_gsi_contract.json" --out-md "$OUT/reports/C0_04_gsi_contract.md")
  for p in "${SABLE_CANDIDATES[@]:-}"; do [[ -f "$p" ]] && args+=(--sable "$p"); done
  python3 "$HELPER" "${args[@]}"
  if [[ "$PRODUCT_CONTRACT_OK" == YES && "${GSTAT[C0_02_MOUNT_MODEL]:-}" == PASS ]]; then
    gate C0_04_GSI_CONTRACT PASS "N1D contract binds generated treble_arm64_bvN -> PHH base -> AOSP gsi_release with Sable delta; runtime skip_mount ownership already proven"
    record N1D_PRODUCT_CHAIN_MODE GENERATED_TREBLE_PLUS_SABLE_DELTA
  else
    gate C0_04_GSI_CONTRACT FAIL "N1D product-chain contract missing/incomplete or runtime GSI ownership not proven"
  fi
else gate C0_04_GSI_CONTRACT FAIL "AOSP gsi_release.mk unresolved from N1C/N1B source roots"; fi

# Build runtime partition view for VINTF / SELinux. If skip_mount passed, product/system_ext come from GSI.
RUNTIME_PRODUCT="$N1C_SYS_ROOT/product"
RUNTIME_SYSTEM_EXT="$N1C_SYS_ROOT/system_ext"
[[ "${GSTAT[C0_02_MOUNT_MODEL]:-}" == PASS ]] || { RUNTIME_PRODUCT="$STOCK_PRODUCT_EX"; RUNTIME_SYSTEM_EXT="$STOCK_SYSTEM_EXT_EX"; }

# ---------------------------- C0_05 checkvintf
if [[ -n "$CHECKVINTF" && -d "$N1C_SYS_ROOT" && -n "$STOCK_VENDOR_EX" && -d "$STOCK_VENDOR_EX" ]]; then
  VARGS=(--check-compat --dirmap "/system:$N1C_SYS_ROOT" --dirmap "/vendor:$STOCK_VENDOR_EX")
  [[ -d "$RUNTIME_PRODUCT" ]] && VARGS+=(--dirmap "/product:$RUNTIME_PRODUCT")
  [[ -d "$RUNTIME_SYSTEM_EXT" ]] && VARGS+=(--dirmap "/system_ext:$RUNTIME_SYSTEM_EXT")
  [[ -n "$STOCK_ODM_EX" && -d "$STOCK_ODM_EX" ]] && VARGS+=(--dirmap "/odm:$STOCK_ODM_EX")
  if [[ -z "$VINTF_FIRST_API_LEVEL" ]]; then
    for bp in "$STOCK_VENDOR_EX/build.prop" "$RUNTIME_PRODUCT/build.prop" "$N1C_SYS_ROOT/build.prop"; do
      [[ -f "$bp" ]] || continue
      v="$(grep -m1 '^ro.product.first_api_level=' "$bp" | cut -d= -f2- || true)"; [[ -n "$v" ]] && VINTF_FIRST_API_LEVEL="$v" && break
    done
  fi
  [[ -n "$VINTF_FIRST_API_LEVEL" ]] && VARGS+=(--property "ro.product.first_api_level=$VINTF_FIRST_API_LEVEL")
  [[ -n "$VINTF_HARDWARE_SKU" ]] && VARGS+=(--property "ro.boot.product.hardware.sku=$VINTF_HARDWARE_SKU")
  if run_host_tool "$CHECKVINTF" "${VARGS[@]}" >"$OUT/logs/C0_05_checkvintf.log" 2>&1; then gate C0_05_VINTF PASS "checkvintf --check-compat passed"; else gate C0_05_VINTF FAIL "checkvintf failed; see log"; fi
else gate C0_05_VINTF FAIL "checkvintf or extracted system/vendor view unavailable"; fi

# ---------------------------- C0_06 split SELinux compile using init's file ordering
if [[ -n "$SECILC" && -d "$N1C_SYS_ROOT/etc/selinux" && -f "$STOCK_VENDOR_EX/etc/selinux/plat_sepolicy_vers.txt" ]]; then
  VERS="$(head -1 "$STOCK_VENDOR_EX/etc/selinux/plat_sepolicy_vers.txt" | tr -d '\r\n')"
  record VENDOR_PLAT_SEPOLICY_VERS "$VERS"
  PLAT="$N1C_SYS_ROOT/etc/selinux/plat_sepolicy.cil"
  MAP="$N1C_SYS_ROOT/etc/selinux/mapping/$VERS.cil"
  ARGS=("$PLAT" -m -M true -G -N -c "$SEPOLICY_VERSION" "$MAP" -o "$WORK/sepolicy.compiled" -f /dev/null)
  for f in \
    "$N1C_SYS_ROOT/etc/selinux/mapping/$VERS.compat.cil" \
    "$RUNTIME_SYSTEM_EXT/etc/selinux/system_ext_sepolicy.cil" \
    "$RUNTIME_SYSTEM_EXT/etc/selinux/mapping/$VERS.cil" \
    "$RUNTIME_SYSTEM_EXT/etc/selinux/mapping/$VERS.compat.cil" \
    "$RUNTIME_PRODUCT/etc/selinux/product_sepolicy.cil" \
    "$RUNTIME_PRODUCT/etc/selinux/mapping/$VERS.cil" \
    "$STOCK_VENDOR_EX/etc/selinux/plat_pub_versioned.cil" \
    "$STOCK_VENDOR_EX/etc/selinux/vendor_sepolicy.cil" \
    "${STOCK_ODM_EX:+$STOCK_ODM_EX/etc/selinux/odm_sepolicy.cil}"; do [[ -n "$f" && -f "$f" ]] && ARGS+=("$f"); done
  if [[ ! -f "$PLAT" || ! -f "$MAP" || ! -f "$STOCK_VENDOR_EX/etc/selinux/vendor_sepolicy.cil" || ! -f "$STOCK_VENDOR_EX/etc/selinux/plat_pub_versioned.cil" ]]; then
    gate C0_06_SEPOLICY FAIL "required split-policy inputs missing for vendor mapping $VERS"
  elif run_host_tool "$SECILC" "${ARGS[@]}" >"$OUT/logs/C0_06_secilc.log" 2>&1; then
    gate C0_06_SEPOLICY PASS "split SELinux policy compiled with vendor mapping $VERS"
  else gate C0_06_SEPOLICY FAIL "secilc split-policy compile failed"; fi
else gate C0_06_SEPOLICY FAIL "secilc or split-policy inputs unavailable"; fi

# ---------------------------- normalize N1C/stock super once for LP + lpunpack
N1C_SUPER_RAW="$WORK/n1c-super.raw.img"
STOCK_SUPER_RAW="$WORK/stock-super.raw.img"
N1C_RAW_REF=""; STOCK_RAW_REF=""
if [[ -f "$N1C_SUPER_IMG" && -n "$LPDUMP" && -n "$LPUNPACK" ]]; then N1C_RAW_REF="$(normalize_raw "$N1C_SUPER_IMG" "$N1C_SUPER_RAW" || true)"; fi
if [[ -f "$STOCK_SUPER_IMG" && -n "$LPDUMP" && -n "$LPUNPACK" ]]; then STOCK_RAW_REF="$(normalize_raw "$STOCK_SUPER_IMG" "$STOCK_SUPER_RAW" || true)"; fi
if [[ -z "$STOCK_RAW_REF" && -n "$LPDUMP" && -n "$LPUNPACK" ]]; then
  # Prefer the exact N1C stock-super restore evidence, then broaden within Titan 2 evidence.
  mapfile -t STOCK_SUPER_CANDIDATES < <(
    {
      if [[ -d "$STOCK_SUPER_ARTIFACT_EVID" ]]; then
        find "$STOCK_SUPER_ARTIFACT_EVID" -type f \( -iname '*super*.img' -o -iname '*super*.sparse.img' \) -print 2>/dev/null
        grep -RhoE "/[^[:space:]\"']*super[^[:space:]\"']*\.img" "$STOCK_SUPER_ARTIFACT_EVID" 2>/dev/null || true
      fi
      find /srv/data/sable-build/evidence/titan2 -maxdepth 4 -type f \( -iname '*stock*super*.img' -o -iname '*stock*super*.sparse.img' \) -print 2>/dev/null
    } | sort -u
  )
  for c in "${STOCK_SUPER_CANDIDATES[@]:-}"; do
    [[ -f "$c" ]] || continue
    cr="$WORK/stock-candidate.raw.img"
    rr="$(normalize_raw "$c" "$cr" || true)"
    [[ -n "$rr" ]] || continue
    if run_host_tool "$LPDUMP" -j "$rr" >/dev/null 2>&1; then
      STOCK_SUPER_IMG="$c"
      STOCK_RAW_REF="$rr"
      break
    fi
    rm -f "$cr"
  done
fi
record STOCK_SUPER_IMG_RESOLVED "${STOCK_SUPER_IMG:--}"

N1C_LP="$WORK/n1c-lp"; mkdir -p "$N1C_LP"
if [[ -n "$N1C_RAW_REF" ]]; then
  run_host_tool "$LPDUMP" -j "$N1C_RAW_REF" > "$OUT/reports/C0_09_n1c_lpdump.json" 2>"$OUT/logs/C0_09_n1c_lpdump.err" || true
  run_host_tool "$LPUNPACK" "$N1C_RAW_REF" "$N1C_LP" >"$OUT/logs/C0_08_n1c_lpunpack.log" 2>&1 || true
fi

# ---------------------------- C0_07 AVB chain inventory
if [[ -n "$AVBTOOL" ]]; then
  AVB_FAIL=0
  for spec in "stock_vbmeta:$STOCK_VBMETA_IMG" "stock_vbmeta_system:$STOCK_VBMETA_SYSTEM_IMG" "stock_vbmeta_vendor:$STOCK_VBMETA_VENDOR_IMG" "n1c_system:$N1C_SYSTEM_IMG"; do
    label="${spec%%:*}"; path="${spec#*:}"
    if [[ -f "$path" ]]; then run_host_tool "$AVBTOOL" info_image --image "$path" >"$OUT/reports/C0_07_${label}_avb.txt" 2>&1 || { echo "INFO_IMAGE_FAILED" >>"$OUT/reports/C0_07_${label}_avb.txt"; [[ "$label" == stock_vbmeta* ]] && AVB_FAIL=1; }; else [[ "$label" == stock_vbmeta* ]] && AVB_FAIL=1; fi
  done
  [[ "$AVB_FAIL" -eq 0 ]] && gate C0_07_AVB_CHAIN PASS "stock vbmeta/vbmeta_system/vbmeta_vendor inspected" || gate C0_07_AVB_CHAIN FAIL "stock AVB chain input/info missing"
else gate C0_07_AVB_CHAIN FAIL "avbtool unavailable"; fi

# ---------------------------- C0_08 AVB footer/partition boundary RCA
N1C_EXTRACTED_SYSTEM=""
for f in "$N1C_LP/system_a.img" "$N1C_LP/system.img"; do [[ -s "$f" ]] && N1C_EXTRACTED_SYSTEM="$f" && break; done
if [[ -n "$AVBTOOL" && -n "$N1C_EXTRACTED_SYSTEM" ]]; then
  SRC_AVB=NO; EXT_AVB=NO
  N1C_SYSTEM_NORM="$WORK/n1c-system.normalized.img"
  SOURCE_SYSTEM_FOR_AVB="$(normalize_raw "$N1C_SYSTEM_IMG" "$N1C_SYSTEM_NORM" || true)"
  [[ -n "$SOURCE_SYSTEM_FOR_AVB" ]] || SOURCE_SYSTEM_FOR_AVB="$N1C_SYSTEM_IMG"
  run_host_tool "$AVBTOOL" info_image --image "$SOURCE_SYSTEM_FOR_AVB" >"$OUT/reports/C0_08_source_system_avb.txt" 2>&1 && SRC_AVB=YES || true
  run_host_tool "$AVBTOOL" info_image --image "$N1C_EXTRACTED_SYSTEM" >"$OUT/reports/C0_08_extracted_system_a_avb.txt" 2>&1 && EXT_AVB=YES || true
  SRC_BYTES="$(stat -c '%s' "$SOURCE_SYSTEM_FOR_AVB")"; EXT_BYTES="$(stat -c '%s' "$N1C_EXTRACTED_SYSTEM")"
  record N1C_SOURCE_SYSTEM_BYTES "$SRC_BYTES"; record N1C_EXTRACTED_SYSTEM_A_BYTES "$EXT_BYTES"
  record N1C_SOURCE_SYSTEM_AVB_FOOTER "$SRC_AVB"; record N1C_EXTRACTED_SYSTEM_A_AVB_FOOTER "$EXT_AVB"
  {
    echo "SOURCE_SYSTEM=$N1C_SYSTEM_IMG"; echo "SOURCE_NORMALIZED=$SOURCE_SYSTEM_FOR_AVB"; echo "SOURCE_BYTES=$SRC_BYTES"; echo "SOURCE_AVB=$SRC_AVB"
    echo "EXTRACTED_SYSTEM_A=$N1C_EXTRACTED_SYSTEM"; echo "EXTRACTED_BYTES=$EXT_BYTES"; echo "EXTRACTED_AVB=$EXT_AVB"
    if cmp -n "$SRC_BYTES" "$SOURCE_SYSTEM_FOR_AVB" "$N1C_EXTRACTED_SYSTEM" >/dev/null 2>&1; then echo "SOURCE_PREFIX_IDENTICAL=YES"; else echo "SOURCE_PREFIX_IDENTICAL=NO"; fi
  } > "$OUT/reports/C0_08_avb_boundary.env"
  if [[ "$SRC_AVB" == YES && "$EXT_AVB" == NO ]]; then
    record N1C_H4_AVB_BOUNDARY SUPPORTS_HYPOTHESIS
    gate C0_08_AVB_BOUNDARY PASS "resolved: source footer exists but composed system_a footer not valid at extracted boundary"
  elif [[ "$SRC_AVB" == YES && "$EXT_AVB" == YES ]]; then
    record N1C_H4_AVB_BOUNDARY DOES_NOT_SUPPORT_HYPOTHESIS
    gate C0_08_AVB_BOUNDARY PASS "resolved: AVB footer remains parseable after composition"
  else
    record N1C_H4_AVB_BOUNDARY NO_SOURCE_FOOTER
    gate C0_08_AVB_BOUNDARY PASS "resolved: N1C source system has no parseable AVB footer; footer-loss hypothesis not applicable as stated"
  fi
else gate C0_08_AVB_BOUNDARY FAIL "unable to inspect extracted N1C system_a and AVB footer"; fi

# ---------------------------- C0_09 stock vs N1C LP metadata
if [[ -n "$STOCK_RAW_REF" && -n "$N1C_RAW_REF" ]]; then
  STOCK_LP_OK=0; N1C_LP_OK=0
  run_host_tool "$LPDUMP" -j "$STOCK_RAW_REF" > "$OUT/reports/C0_09_stock_lpdump.json" 2>"$OUT/logs/C0_09_stock_lpdump.err" && STOCK_LP_OK=1 || true
  [[ -s "$OUT/reports/C0_09_n1c_lpdump.json" ]] && python3 -m json.tool "$OUT/reports/C0_09_n1c_lpdump.json" >/dev/null 2>&1 && N1C_LP_OK=1 || true
  if [[ "$STOCK_LP_OK" -eq 1 && "$N1C_LP_OK" -eq 1 ]] && python3 -m json.tool "$OUT/reports/C0_09_stock_lpdump.json" >/dev/null 2>&1; then
    python3 "$HELPER" lp-diff --stock-json "$OUT/reports/C0_09_stock_lpdump.json" --n1c-json "$OUT/reports/C0_09_n1c_lpdump.json" --out-json "$OUT/reports/C0_09_lp_diff.json" --out-md "$OUT/reports/C0_09_lp_diff.md"
    LP_DIFF_COUNT="$(python3 - "$OUT/reports/C0_09_stock_lpdump.json" "$OUT/reports/C0_09_n1c_lpdump.json" <<'PY'
import json,sys
s=json.load(open(sys.argv[1])); n=json.load(open(sys.argv[2]))
def idx(o): return {p.get('name'):p for p in o.get('partitions',[]) if p.get('name')}
S,N=idx(s),idx(n); names=['product','product_a','system_ext','system_ext_a','vendor','vendor_a','system_dlkm','system_dlkm_a','vendor_dlkm','vendor_dlkm_a','odm_dlkm','odm_dlkm_a']
count=0
for name in names:
    if name not in S or name not in N: continue
    for k in set(S[name])|set(N[name]):
        if k.startswith('fs_'): continue
        if S[name].get(k)!=N[name].get(k): count+=1
print(count)
PY
)"
    record LP_PRESERVED_METADATA_DIFF_COUNT "$LP_DIFF_COUNT"
    if [[ "$LP_DIFF_COUNT" == 0 ]]; then gate C0_09_LP_METADATA PASS "preserved partition metadata matches stock for comparable fields"; else gate C0_09_LP_METADATA FAIL "$LP_DIFF_COUNT preserved-partition metadata field differences; review before recomposition"; fi
  else
    gate C0_09_LP_METADATA FAIL "lpdump JSON generation/validation failed"
  fi
else gate C0_09_LP_METADATA FAIL "stock or N1C raw super unavailable for lpdump comparison"; fi

# ---------------------------- C0_10 known-booting control diff
RESTLESS_CAND="$OUT/reports/C0_10_restless_candidates.txt"
if [[ -z "$RESTLESS_SYSTEM_IMG" ]]; then
  find /srv/data/sable-build -maxdepth 6 -type f \( -iname '*restless*.img' -o -iname '*Restless*.img' \) -size +500M -print 2>/dev/null | head -200 > "$RESTLESS_CAND" || true
fi
REPORTS=("$OUT/inventory/n1c-system.env"); LABELS=(n1c)
CONTROL_PASS=NO
if [[ "${GDETAIL[C0_01_N1B_CONTROL]:-}" == QUALIFIED_HISTORICAL ]]; then
  if [[ -n "$N1B_CONTROL_SYSTEM_IMG" && -f "$N1B_CONTROL_SYSTEM_IMG" ]]; then
    N1B_EX="$WORK/n1b-control"
    if extract_fs "$N1B_CONTROL_SYSTEM_IMG" "$N1B_EX"; then
      python3 "$HELPER" system-report --root "$N1B_EX" --label n1b-control --out "$OUT/inventory/n1b-control.env"
      REPORTS+=("$OUT/inventory/n1b-control.env"); LABELS+=(n1b-control)
      gate C0_10_CONTROL_DIFF PASS "sealed known-booting N1B/Restless-derived system compared to N1C"
      CONTROL_PASS=YES
    fi
  fi
fi
if [[ "$CONTROL_PASS" != YES && -n "$RESTLESS_SYSTEM_IMG" && -f "$RESTLESS_SYSTEM_IMG" ]]; then
  REST_EX="$WORK/restless"
  if extract_fs "$RESTLESS_SYSTEM_IMG" "$REST_EX"; then
    python3 "$HELPER" system-report --root "$REST_EX" --label restless --out "$OUT/inventory/restless.env"
    REPORTS+=("$OUT/inventory/restless.env"); LABELS+=(restless)
    gate C0_10_CONTROL_DIFF PASS "known-booting Restless system compared to N1C"
    CONTROL_PASS=YES
  fi
fi
if [[ "$CONTROL_PASS" != YES ]]; then
  gate C0_10_CONTROL_DIFF FAIL "no qualified known-booting control available"
fi
if [[ ${#REPORTS[@]} -gt 1 ]]; then
  args=(compare-system-reports --out-md "$OUT/reports/C0_10_system_control_comparison.md")
  for i in "${!REPORTS[@]}"; do args+=(--report "${REPORTS[$i]}" --label "${LABELS[$i]}"); done
  python3 "$HELPER" "${args[@]}" || true
fi

# ---------------------------- C0_11 historical cellular static audit (non-blocking for boot architecture)
if [[ -x "$CELLULAR_AUDIT_TOOL" && -n "$N1B1_INPUT" && -e "$N1B1_INPUT" && -n "$N1B2_INPUT" && -e "$N1B2_INPUT" ]]; then
  COUT="$OUT/cellular-static"
  if "$CELLULAR_AUDIT_TOOL" --stock "$STOCK_REF_DIR" --n1b1 "$N1B1_INPUT" --n1b2 "$N1B2_INPUT" --out "$COUT" >"$OUT/logs/C0_11_cellular_audit.log" 2>&1; then gate C0_11_CELLULAR_STATIC PASS "historical static audit complete"; else gate C0_11_CELLULAR_STATIC INFO "historical audit ran but did not complete; not a boot-architecture gate"; fi
else gate C0_11_CELLULAR_STATIC INFO "historical N1B1/N1B2 inputs not supplied; defer to B0/PR207 evidence"; fi

# ---------------------------- C0_12 toolchain seal
TOOL_FAIL=0
for spec in "audit:$CELLULAR_AUDIT_TOOL:$ENG2_AUDIT_SHA256" "capture:$CAPTURE_TOOL:$ENG2_CAPTURE_SHA256" "classifier:$CLASSIFIER_TOOL:$ENG2_CLASSIFIER_SHA256"; do
  name="${spec%%:*}"; rem="${spec#*:}"; path="${rem%%:*}"; exp="${rem##*:}"
  if [[ -f "$path" ]]; then h="$(sha "$path")"; record "TOOL_${name^^}_SHA256" "$h"; [[ "$h" == "$exp" ]] || TOOL_FAIL=1
  else TOOL_FAIL=1; fi
done
SELF_SHA="$(sha "$0")"; HELPER_SHA="$(sha "$HELPER")"; record N1D_C0_DRIVER_SHA256 "$SELF_SHA"; record N1D_C0_HELPER_SHA256 "$HELPER_SHA"
if [[ "$TOOL_FAIL" -eq 0 ]]; then gate C0_12_TOOLCHAIN_SEAL PASS "Engineer-2 reviewed audit/capture/classifier hashes match"; else gate C0_12_TOOLCHAIN_SEAL FAIL "reviewed tooling missing or hash mismatch"; fi

# ---------------------------- final disposition
BLOCKED=0
for g in "${BLOCKING_GATES[@]}"; do [[ "${GSTAT[$g]:-MISSING}" == PASS ]] || BLOCKED=1; done
if [[ "${GSTAT[C0_00_PREFLIGHT]:-FAIL}" != PASS || "${GSTAT[C0_00_N1C_SYSTEM_SEAL]:-FAIL}" != PASS || "${GSTAT[C0_00_N1C_SUPER_SEAL]:-FAIL}" != PASS ]]; then BLOCKED=1; fi
if [[ "$BLOCKED" -eq 0 ]]; then
  record N1D_C0_COMPLETE YES
  record N1D_BUILD_READINESS PASS
else
  record N1D_C0_COMPLETE NO
  record N1D_BUILD_READINESS BLOCKED
fi
record N1D_BUILD_AUTHORIZED_BY_THIS_SCRIPT NO
record N1D_FLASH_AUTHORIZED NO
record N1D_DEVICE_CONTACT_AUTHORIZED NO

python3 - "$GATES" "$SUMMARY" "$OUT/reports/N1D_C0_OFFLINE_REPORT.md" <<'PY'
import sys
from pathlib import Path
gates, summary, out = map(Path, sys.argv[1:])
env={}
for line in summary.read_text().splitlines():
    if '=' in line:
        k,v=line.split('=',1); env[k]=v
rows=[]
for line in gates.read_text().splitlines()[1:]:
    if not line.strip(): continue
    c=line.split('\t',2); rows.append(c + ['']*(3-len(c)))
md=["# SableOS Titan 2 N1D C0 offline qualification", "",
    f"- `N1D_C0_COMPLETE={env.get('N1D_C0_COMPLETE','NO')}`",
    f"- `N1D_BUILD_READINESS={env.get('N1D_BUILD_READINESS','BLOCKED')}`",
    "- `N1D_BUILD_AUTHORIZED_BY_THIS_SCRIPT=NO`",
    "- `N1D_FLASH_AUTHORIZED=NO`", "",
    "## Gate results", "", "| gate | status | detail |", "|---|---|---|"]
for g,s,d in rows: md.append(f"| `{g}` | **{s}** | {d.replace('|','/')} |")
md += ["", "## Interpretation", "",
       "A PASS means the offline question was resolved with the supplied local evidence; it is not flash authorization.",
       "C0_01 may close as `UNQUALIFIED_HISTORICAL`: that means the old N1B record is not promoted to a cryptographic control and a fresh control must be reproduced later under the N1D device-side protocol.",
       "C0_11 is informational for the boot-architecture phase and becomes blocking only when entering the cellular/IMS restoration phase.",
       "", "## Evidence", "", "See `reports/`, `logs/`, `inventory/`, `N1D_C0_GATES.tsv`, and `N1D_C0_OFFLINE_SUMMARY.env`."]
out.write_text('\n'.join(md)+'\n')
PY

log "C0 result: $(grep '^N1D_C0_COMPLETE=' "$SUMMARY" | tail -1) / $(grep '^N1D_BUILD_READINESS=' "$SUMMARY" | tail -1)"
echo "SUMMARY=$SUMMARY"
echo "REPORT=$OUT/reports/N1D_C0_OFFLINE_REPORT.md"
[[ "$BLOCKED" -eq 0 ]] || exit 4
