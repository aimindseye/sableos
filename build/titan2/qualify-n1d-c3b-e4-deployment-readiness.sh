#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"

SYSTEM_IMG="/srv/sable-build/workspaces/titan2-n1d-c3b/out-c3b-engineering/e3-systemimage/20261003T014638Z/target/product/tdgsi_arm64_ab/system.img"
PHASE11_JSON="/srv/data/sable-build/evidence/titan2/n1b-phase-11-lp-super-sizing/20260928_195308/fastbootd-lp-sizing/phase11-fastbootd-lp-sizing.json"
STOCK_REF_DIR="/srv/data/sable-build/titan2/artifacts/stock-firmware/unihertz-device-fota-20260922/inspection/bit-equivalence/TEE14-large-reference"
STOCK_SUPER_IMG=""
STOCK_BOOT_IMG=""
STOCK_VENDOR_BOOT_IMG=""
STOCK_INIT_BOOT_IMG=""
STOCK_VBMETA_IMG=""
STOCK_VBMETA_SYSTEM_IMG=""
STOCK_VBMETA_VENDOR_IMG=""
STOCK_SUPER_EVID="/srv/data/sable-build/evidence/titan2/n1c-stock-super-restore-artifact-r1c-20260930_200124"
BOOT_AVB_EVID="/srv/data/sable-build/evidence/titan2/n1c-restore-tee14-boot-avb-direct-20260930_204335"
EVIDENCE_DIR="/srv/sable-build/evidence/titan2/n1d-c3b-e4-deployment-readiness/$STAMP"
AVBTOOL=""

EXPECTED_SHA256="998a8b99cd4d1a631006291a96c6f0160c5a4400c4bf6bba62c319c4ed3c82a5"
EXPECTED_BYTES="2994405376"
ALIGNMENT_BYTES="1048576"
SYSTEM_MARGIN_BYTES="268435456"
MIN_REMAINING_SUPER_HEADROOM_BYTES="536870912"

usage() {
  cat <<'EOF'
usage:
  bash build/titan2/qualify-n1d-c3b-e4-deployment-readiness.sh [options]

Options:
  --system-image PATH
  --phase11-json PATH
  --stock-ref-dir DIR
  --stock-super-image PATH
  --stock-boot-image PATH
  --stock-vendor-boot-image PATH
  --stock-init-boot-image PATH
  --stock-vbmeta-image PATH
  --stock-vbmeta-system-image PATH
  --stock-vbmeta-vendor-image PATH
  --stock-super-evidence DIR
  --boot-avb-evidence DIR
  --avbtool PATH
  --evidence-dir DIR

E4 is offline/read-only. It never runs adb or fastboot and never reboots, flashes,
erases, unlocks, changes slots, mutates AVB, resizes logical partitions, builds
Android, signs artifacts, or performs network access.
EOF
}

while (($#)); do
  case "$1" in
    --system-image) SYSTEM_IMG="$2"; shift 2 ;;
    --phase11-json) PHASE11_JSON="$2"; shift 2 ;;
    --stock-ref-dir) STOCK_REF_DIR="$2"; shift 2 ;;
    --stock-super-image) STOCK_SUPER_IMG="$2"; shift 2 ;;
    --stock-boot-image) STOCK_BOOT_IMG="$2"; shift 2 ;;
    --stock-vendor-boot-image) STOCK_VENDOR_BOOT_IMG="$2"; shift 2 ;;
    --stock-init-boot-image) STOCK_INIT_BOOT_IMG="$2"; shift 2 ;;
    --stock-vbmeta-image) STOCK_VBMETA_IMG="$2"; shift 2 ;;
    --stock-vbmeta-system-image) STOCK_VBMETA_SYSTEM_IMG="$2"; shift 2 ;;
    --stock-vbmeta-vendor-image) STOCK_VBMETA_VENDOR_IMG="$2"; shift 2 ;;
    --stock-super-evidence) STOCK_SUPER_EVID="$2"; shift 2 ;;
    --boot-avb-evidence) BOOT_AVB_EVID="$2"; shift 2 ;;
    --avbtool) AVBTOOL="$2"; shift 2 ;;
    --evidence-dir) EVIDENCE_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "N1D_C3B_E4_DEPLOYMENT_READINESS=FAIL_UNKNOWN_ARG arg=$1" >&2; usage >&2; exit 64 ;;
  esac
done

fail() {
  echo "N1D_C3B_E4_DEPLOYMENT_READINESS=FAIL reason=$1" >&2
  exit 1
}

echo "===== TITAN 2 N1D C3B E4 DEPLOYMENT READINESS ====="
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "ADB_COMMANDS_RUN=NO"
echo "FASTBOOT_COMMANDS_RUN=NO"
echo "REBOOT_COMMANDS_RUN=NO"
echo "FLASH_AUTHORIZED=NO"
echo "FLASH_COMMANDS_RUN=NO"
echo "ERASE_COMMANDS_RUN=NO"
echo "UNLOCK_COMMANDS_RUN=NO"
echo "LP_MUTATION_AUTHORIZED=NO"
echo "AVB_MUTATION_AUTHORIZED=NO"
echo "SLOT_MUTATION_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "PRODUCTION_SIGNING_AUTHORIZED=NO"
echo "RELEASE_ELIGIBLE=NO"

bash "$ROOT/build/gates/n1d-c3b-e3-systemimage-evidence-contract.sh"

[[ -f "$SYSTEM_IMG" ]] || fail "system_image_missing path=$SYSTEM_IMG"
[[ -f "$PHASE11_JSON" ]] || fail "phase11_json_missing path=$PHASE11_JSON"
[[ -d "$STOCK_REF_DIR" ]] || fail "stock_ref_dir_missing path=$STOCK_REF_DIR"
[[ -d "$STOCK_SUPER_EVID" ]] || fail "stock_super_evidence_missing path=$STOCK_SUPER_EVID"
[[ -d "$BOOT_AVB_EVID" ]] || fail "boot_avb_evidence_missing path=$BOOT_AVB_EVID"

mkdir -p "$EVIDENCE_DIR"
LOG="$EVIDENCE_DIR/e4-deployment-readiness.log"
exec > >(tee "$LOG") 2>&1

echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "SYSTEM_IMG=$SYSTEM_IMG"
echo "PHASE11_JSON=$PHASE11_JSON"
echo "STOCK_REF_DIR=$STOCK_REF_DIR"
echo "STOCK_SUPER_EVID=$STOCK_SUPER_EVID"
echo "BOOT_AVB_EVID=$BOOT_AVB_EVID"

actual_sha="$(sha256sum "$SYSTEM_IMG" | awk '{print $1}')"
actual_bytes="$(stat -c '%s' "$SYSTEM_IMG")"
[[ "$actual_sha" == "$EXPECTED_SHA256" ]] || fail "system_sha256 expected=$EXPECTED_SHA256 actual=$actual_sha"
[[ "$actual_bytes" == "$EXPECTED_BYTES" ]] || fail "system_bytes expected=$EXPECTED_BYTES actual=$actual_bytes"
echo "N1D_C3B_E4_E3_IMAGE_SEAL=PASS"
echo "N1D_C3B_E4_SYSTEM_SHA256=$actual_sha"
echo "N1D_C3B_E4_SYSTEM_BYTES=$actual_bytes"

file "$SYSTEM_IMG" | tee "$EVIDENCE_DIR/system-image-file.txt"

if [[ -z "$AVBTOOL" ]]; then
  out_root="${SYSTEM_IMG%%/target/product/*}"
  candidate="$out_root/host/linux-x86/bin/avbtool"
  if [[ -x "$candidate" ]]; then
    AVBTOOL="$candidate"
  elif command -v avbtool >/dev/null 2>&1; then
    AVBTOOL="$(command -v avbtool)"
  fi
fi
[[ -n "$AVBTOOL" && -x "$AVBTOOL" ]] || fail "avbtool_unavailable"
"$AVBTOOL" info_image --image "$SYSTEM_IMG" > "$EVIDENCE_DIR/system-avb-info.txt" 2>&1 ||
  fail "system_avb_info_image_failed"
echo "N1D_C3B_E4_SYSTEM_AVB_INFO=PASS"

resolve_stock_super() {
  local explicit="$1"
  local ref_dir="$2"
  local evidence_dir="$3"
  local -a raw=()
  local -a unique=()
  local -A seen=()
  local item resolved

  if [[ -n "$explicit" ]]; then
    [[ -f "$explicit" ]] || fail "stock_super_explicit_missing path=$explicit"
    realpath "$explicit"
    return 0
  fi

  if [[ -f "$ref_dir/super.img" ]]; then
    realpath "$ref_dir/super.img"
    return 0
  fi

  while IFS= read -r item; do
    [[ -n "$item" ]] && raw+=("$item")
  done < <(
    {
      find "$evidence_dir" -type f \( -iname '*super*.img' -o -iname '*super*.sparse.img' \) -print 2>/dev/null || true
      grep -RhoE "/[^[:space:]\"']*super[^[:space:]\"']*\.img" "$evidence_dir" 2>/dev/null || true
    } | sort -u
  )

  for item in "${raw[@]:-}"; do
    [[ -f "$item" ]] || continue
    resolved="$(realpath "$item")"
    if [[ -z "${seen[$resolved]+x}" ]]; then
      unique+=("$resolved")
      seen["$resolved"]=1
    fi
  done

  if [[ "${#unique[@]}" -ne 1 ]]; then
    {
      echo "N1D_C3B_E4_STOCK_SUPER_RESOLUTION=FAIL candidate_count=${#unique[@]}"
      printf 'candidate=%s\n' "${unique[@]:-}"
      echo "Use --stock-super-image PATH only after identifying the exact proven stock restore artifact."
    } >&2
    return 1
  fi

  printf '%s\n' "${unique[0]}"
}

STOCK_SUPER_IMG="$(resolve_stock_super "$STOCK_SUPER_IMG" "$STOCK_REF_DIR" "$STOCK_SUPER_EVID")" ||
  fail "stock_super_resolution_failed"
echo "STOCK_SUPER_IMG=$STOCK_SUPER_IMG"
echo "N1D_C3B_E4_STOCK_SUPER_RESOLUTION=PASS"
sha256sum "$STOCK_SUPER_IMG" | tee "$EVIDENCE_DIR/stock-super.sha256"

resolve_evidence_exact() {
  local current="$1"
  local evidence="$2"
  local base="$3"
  local -a hits=()

  if [[ -n "$current" && -f "$current" ]]; then
    realpath "$current"
    return 0
  fi

  if [[ -f "$STOCK_REF_DIR/$base" ]]; then
    realpath "$STOCK_REF_DIR/$base"
    return 0
  fi

  [[ -d "$evidence" ]] || return 1

  mapfile -t hits < <(
    find "$evidence" -type f -name "$base" -print 2>/dev/null |
      xargs -r -n1 realpath 2>/dev/null |
      sort -u
  )
  if [[ "${#hits[@]}" -eq 1 ]]; then
    printf '%s\n' "${hits[0]}"
    return 0
  fi

  mapfile -t hits < <(
    grep -RhoE "/[^[:space:]\"']*/$base" "$evidence" 2>/dev/null |
      sort -u |
      while IFS= read -r p; do
        [[ -f "$p" ]] && realpath "$p"
      done |
      sort -u
  )
  [[ "${#hits[@]}" -eq 1 ]] || return 1
  printf '%s\n' "${hits[0]}"
}

resolve_boot_avb_component() {
  local var_name="$1"
  local base="$2"
  local current="${!var_name:-}"
  local resolved

  if ! resolved="$(resolve_evidence_exact "$current" "$BOOT_AVB_EVID" "$base")"; then
    echo "N1D_C3B_E4_BOOT_AVB_COMPONENT_RESOLUTION=FAIL component=$base" >&2
    return 1
  fi

  printf -v "$var_name" '%s' "$resolved"
  echo "N1D_C3B_E4_BOOT_AVB_COMPONENT=PASS component=$base path=$resolved"
  sha256sum "$resolved" >> "$EVIDENCE_DIR/stock-boot-avb.sha256"
}

: > "$EVIDENCE_DIR/stock-boot-avb.sha256"
resolve_boot_avb_component STOCK_BOOT_IMG boot.img ||
  fail "stock_boot_avb_resolution_failed component=boot.img"
resolve_boot_avb_component STOCK_VENDOR_BOOT_IMG vendor_boot.img ||
  fail "stock_boot_avb_resolution_failed component=vendor_boot.img"
resolve_boot_avb_component STOCK_INIT_BOOT_IMG init_boot.img ||
  fail "stock_boot_avb_resolution_failed component=init_boot.img"
resolve_boot_avb_component STOCK_VBMETA_IMG vbmeta.img ||
  fail "stock_boot_avb_resolution_failed component=vbmeta.img"
resolve_boot_avb_component STOCK_VBMETA_SYSTEM_IMG vbmeta_system.img ||
  fail "stock_boot_avb_resolution_failed component=vbmeta_system.img"
resolve_boot_avb_component STOCK_VBMETA_VENDOR_IMG vbmeta_vendor.img ||
  fail "stock_boot_avb_resolution_failed component=vbmeta_vendor.img"

echo "N1D_C3B_E4_STOCK_BOOT_AVB_RESOLUTION=PASS count=6"
echo "N1D_C3B_E4_STOCK_REFERENCE_COMPONENTS=PASS"

POSTMORTEM="$ROOT/docs/titan2/N1C_FIRST_WRITE_POSTMORTEM_20260930.md"
[[ -f "$POSTMORTEM" ]] || fail "n1c_postmortem_missing"
grep -Fq 'STOCK_SUPER_RESTORE=PASS' "$POSTMORTEM" ||
  fail "stock_super_restore_proof_missing"
grep -Fq 'TEE14_BOOT_AVB_RESTORE=PASS' "$POSTMORTEM" ||
  fail "tee14_boot_avb_restore_proof_missing"
echo "N1D_C3B_E4_STOCK_RESTORE_PROOF=PASS"

python3 -   "$PHASE11_JSON"   "$actual_bytes"   "$ALIGNMENT_BYTES"   "$SYSTEM_MARGIN_BYTES"   "$MIN_REMAINING_SUPER_HEADROOM_BYTES"   "$EVIDENCE_DIR/e4-sizing.json" <<'PY'
from __future__ import annotations

import json
import math
import pathlib
import sys
from typing import Any

src = pathlib.Path(sys.argv[1])
required = int(sys.argv[2])
alignment = int(sys.argv[3])
margin = int(sys.argv[4])
min_remaining = int(sys.argv[5])
out = pathlib.Path(sys.argv[6])
data = json.loads(src.read_text(encoding="utf-8"))

def walk(obj: Any):
    if isinstance(obj, dict):
        yield obj
        for value in obj.values():
            yield from walk(value)
    elif isinstance(obj, list):
        for value in obj:
            yield from walk(value)

def lookup(*keys: str, default: Any = None) -> Any:
    wanted = {key.lower() for key in keys}
    for node in walk(data):
        for key, value in node.items():
            if key.lower() in wanted:
                return value
    return default

def as_int(*keys: str) -> int:
    value = lookup(*keys, default=0)
    if value in (None, "", "UNKNOWN"):
        return 0
    return int(str(value).split()[0], 0)

def as_str(*keys: str) -> str:
    value = lookup(*keys, default="UNKNOWN")
    if value in (None, ""):
        return "UNKNOWN"
    return str(value)

current_slot = as_str("current_slot", "active_slot").lstrip("_")
is_userspace = as_str("is_userspace", "is-userspace")
system_current = as_int("system_current_bytes")
super_bytes = as_int("super_bytes")
selected_dynamic = as_int("total_selected_dynamic_current_bytes")
super_headroom = as_int("super_headroom_estimate_bytes")

if current_slot not in {"a", "b"}:
    raise SystemExit("N1D_C3B_E4_SIZING=FAIL_CURRENT_SLOT_UNKNOWN")
if is_userspace != "yes":
    raise SystemExit("N1D_C3B_E4_SIZING=FAIL_PHASE11_NOT_FASTBOOTD")
if system_current <= 0 or super_headroom <= 0:
    raise SystemExit("N1D_C3B_E4_SIZING=FAIL_INCOMPLETE_HISTORICAL_SIZE_EVIDENCE")

target = math.ceil((required + margin) / alignment) * alignment
growth = max(0, target - system_current)
remaining = super_headroom - growth
direct_fit = system_current >= required
capacity = remaining >= min_remaining

if direct_fit:
    classification = "PASS_DIRECT_FIT_REVIEW_REQUIRED"
elif capacity:
    classification = "PASS_RESIZE_CAPACITY_APPEARS_AVAILABLE_REVIEW_REQUIRED"
else:
    classification = "BLOCKED_INSUFFICIENT_SUPER_HEADROOM"

result = {
    "schema": 1,
    "phase": "N1D_C3B_E4_DEPLOYMENT_READINESS",
    "evidence_basis": "HISTORICAL_READ_ONLY_FASTBOOTD_PHASE11",
    "historical_current_slot": current_slot,
    "historical_is_userspace": is_userspace,
    "target_logical_partition": f"system_{current_slot}",
    "required_system_bytes": required,
    "historical_system_current_bytes": system_current,
    "system_margin_bytes": margin,
    "alignment_bytes": alignment,
    "planned_system_target_bytes": target,
    "planned_growth_bytes": growth,
    "historical_super_bytes": super_bytes,
    "historical_selected_dynamic_bytes": selected_dynamic,
    "historical_super_headroom_estimate_bytes": super_headroom,
    "estimated_remaining_super_headroom_bytes": remaining,
    "minimum_remaining_super_headroom_bytes": min_remaining,
    "direct_fit": direct_fit,
    "capacity_appears_available": capacity,
    "classification": classification,
    "fresh_device_revalidation_required_before_mutation": True,
    "flash_authorized": False,
    "lp_mutation_authorized": False,
}
out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")

print(f"N1D_C3B_E4_HISTORICAL_CURRENT_SLOT={current_slot}")
print(f"N1D_C3B_E4_HISTORICAL_SYSTEM_CURRENT_BYTES={system_current}")
print(f"N1D_C3B_E4_REQUIRED_SYSTEM_BYTES={required}")
print(f"N1D_C3B_E4_PLANNED_SYSTEM_TARGET_BYTES={target}")
print(f"N1D_C3B_E4_PLANNED_SYSTEM_GROWTH_BYTES={growth}")
print(f"N1D_C3B_E4_HISTORICAL_SUPER_HEADROOM_BYTES={super_headroom}")
print(f"N1D_C3B_E4_ESTIMATED_REMAINING_SUPER_HEADROOM_BYTES={remaining}")
print(f"N1D_C3B_E4_DIRECT_FIT={'YES' if direct_fit else 'NO'}")
print(f"N1D_C3B_E4_PARTITION_FIT={classification}")
if classification.startswith("BLOCKED"):
    raise SystemExit(4)
PY

echo "N1D_C3B_E4_FASTBOOTD_PLAN=PASS_HISTORICAL_EVIDENCE_FRESH_REVALIDATION_REQUIRED"
echo "N1D_C3B_E4_RESTORE_PATH=PASS_STOCK_SUPER_AND_BOOT_AVB_PROVEN"
echo "N1D_C3B_E4_DEVICE_CONTACT_AUTHORIZED=NO"
echo "N1D_C3B_E4_FLASH_AUTHORIZED=NO"
echo "N1D_C3B_E4_LP_MUTATION_AUTHORIZED=NO"
echo "N1D_C3B_E4_AVB_MUTATION_AUTHORIZED=NO"
echo "N1D_C3B_E4_RELEASE_ELIGIBLE=NO"
echo "N1D_C3B_E4_DEPLOYMENT_READINESS=PASS_REVIEW_READY"
echo "N1D_C3B_E4_EVIDENCE_DIR=$EVIDENCE_DIR"
