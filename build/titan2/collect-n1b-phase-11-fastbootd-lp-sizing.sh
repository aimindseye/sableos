#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVIDENCE_ROOT="${SABLE_N1B_PHASE_11_EVIDENCE_ROOT:-/srv/data/sable-build/evidence/titan2/n1b-phase-11-lp-super-sizing}"
STAMP="$(date -u +%Y%m%d_%H%M%S)"
EVIDENCE_DIR="$EVIDENCE_ROOT/$STAMP/fastbootd-lp-sizing"
TITAN_FASTBOOT_SERIAL="${TITAN_FASTBOOT_SERIAL:-}"
REQUIRE_FASTBOOTD=NO
COMMAND_TIMEOUT_SECONDS="${COMMAND_TIMEOUT_SECONDS:-30}"

usage() {
  cat >&2 <<'EOF'
usage:
  bash build/titan2/collect-n1b-phase-11-fastbootd-lp-sizing.sh [--serial <fastboot serial>] [--require-fastbootd]

Environment:
  TITAN_FASTBOOT_SERIAL=<fastboot serial> may be used instead of --serial.
  COMMAND_TIMEOUT_SECONDS=<seconds> defaults to 30.

This script assumes Titan2 is already in userspace fastbootd.
It collects read-only fastboot getvar LP/super sizing metadata only.
It does not reboot, flash, erase, format, unlock, run OEM commands, change slots, or mutate logical partitions.
EOF
}

while (($#)); do
  case "$1" in
    --serial) TITAN_FASTBOOT_SERIAL="$2"; shift 2 ;;
    --require-fastbootd) REQUIRE_FASTBOOTD=YES; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "N1B_PHASE_11_FASTBOOTD_LP_SIZING=FAIL_UNKNOWN_ARG arg=$1" >&2; usage; exit 64 ;;
  esac
done

mkdir -p "$EVIDENCE_DIR"
LOG="$EVIDENCE_DIR/phase11-fastbootd-lp-sizing.log"
JSON_OUT="$EVIDENCE_DIR/phase11-fastbootd-lp-sizing.json"

exec > >(tee "$LOG") 2>&1

echo "===== N1B PHASE 11 TITAN2 FASTBOOTD LP/SUPER SIZING ====="
echo "ROOT=$ROOT"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "DEVICE=titan2"
echo "RELEASE=N1B"
echo "DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY_FASTBOOTD"
echo "ADB_COMMANDS_RUN=NO"
echo "FASTBOOT_COMMANDS_AUTHORIZED=YES_READ_ONLY_GETVAR_ONLY"
echo "REBOOT_COMMANDS_RUN=NO"
echo "FLASH_AUTHORIZED=NO"
echo "FLASH_COMMANDS_RUN=NO"
echo "ERASE_COMMANDS_RUN=NO"
echo "UNLOCK_COMMANDS_RUN=NO"
echo "LP_MUTATION_AUTHORIZED=NO"
echo "AVB_MUTATION_AUTHORIZED=NO"
echo "PUBLIC_RELEASE=NO"
echo "PRODUCTION_SIGNING=NO"
echo "REQUIRE_FASTBOOTD=$REQUIRE_FASTBOOTD"
echo "COMMAND_TIMEOUT_SECONDS=$COMMAND_TIMEOUT_SECONDS"

command -v fastboot >/dev/null || {
  echo "N1B_PHASE_11_FASTBOOTD_LP_SIZING=FAIL_FASTBOOT_NOT_FOUND"
  exit 1
}

run_fastboot() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "$COMMAND_TIMEOUT_SECONDS" fastboot "$@"
  else
    fastboot "$@"
  fi
}

run_fastboot devices | tee "$EVIDENCE_DIR/fastboot-devices.txt"

python3 - "$TITAN_FASTBOOT_SERIAL" "$EVIDENCE_DIR/fastboot-devices.txt" > "$EVIDENCE_DIR/fastboot-serial.txt" <<'PY'
from __future__ import annotations

import sys

explicit = sys.argv[1].strip()
path = sys.argv[2]
if explicit:
    print(explicit)
    raise SystemExit(0)

serials: list[str] = []
for line in open(path, encoding="utf-8", errors="replace"):
    line = line.strip()
    if not line:
        continue
    parts = line.split()
    if parts:
        serials.append(parts[0])

if len(serials) != 1:
    print("N1B_PHASE_11_FASTBOOT_SERIAL=FAIL_EXPECTED_ONE_DEVICE", file=sys.stderr)
    print(f"FASTBOOT_DEVICE_COUNT={len(serials)}", file=sys.stderr)
    raise SystemExit(2)

print(serials[0])
PY

SERIAL="$(cat "$EVIDENCE_DIR/fastboot-serial.txt")"
echo "EXPLICIT_TITAN_FASTBOOT_SERIAL=$SERIAL"
FASTBOOT=(-s "$SERIAL")

run_fastboot "${FASTBOOT[@]}" getvar all > "$EVIDENCE_DIR/getvar-all.txt" 2>&1 || true

GETVARS=(
  current-slot
  is-userspace
  unlocked
  secure
  product
  slot-count
  max-download-size
  logical-block-size
  super-partition-name
  partition-size:super
  partition-size:system
  partition-size:system_a
  partition-size:system_b
  partition-size:system_ext
  partition-size:system_ext_a
  partition-size:system_ext_b
  partition-size:product
  partition-size:product_a
  partition-size:product_b
  partition-size:vendor
  partition-size:vendor_a
  partition-size:vendor_b
  partition-size:odm
  partition-size:odm_a
  partition-size:odm_b
  partition-size:system_dlkm
  partition-size:system_dlkm_a
  partition-size:system_dlkm_b
  partition-size:vendor_dlkm
  partition-size:vendor_dlkm_a
  partition-size:vendor_dlkm_b
  partition-size:odm_dlkm
  partition-size:odm_dlkm_a
  partition-size:odm_dlkm_b
  has-slot:system
  has-slot:vendor
  has-slot:product
  has-slot:system_ext
  has-slot:odm
  is-logical:system
  is-logical:system_a
  is-logical:system_b
  is-logical:vendor
  is-logical:vendor_a
  is-logical:vendor_b
  is-logical:product
  is-logical:product_a
  is-logical:product_b
)

: > "$EVIDENCE_DIR/getvar-selected.txt"
for key in "${GETVARS[@]}"; do
  {
    echo "===== getvar $key ====="
    run_fastboot "${FASTBOOT[@]}" getvar "$key" 2>&1 || true
  } >> "$EVIDENCE_DIR/getvar-selected.txt"
done

python3 - "$EVIDENCE_DIR" "$SERIAL" "$JSON_OUT" "$REQUIRE_FASTBOOTD" <<'PY'
from __future__ import annotations

import json
import pathlib
import re
import sys

evidence = pathlib.Path(sys.argv[1])
serial = sys.argv[2]
json_out = pathlib.Path(sys.argv[3])
require_fastbootd = sys.argv[4]

text = ""
for name in ("getvar-all.txt", "getvar-selected.txt"):
    path = evidence / name
    if path.exists():
        text += "\n" + path.read_text(errors="replace")


def get_value(key: str) -> str:
    pattern = re.compile(rf"(?:^|\n)\s*{re.escape(key)}:\s*([^\n\r]+)")
    match = pattern.search(text)
    if not match:
        return ""
    return match.group(1).strip()


def parse_int(value: str) -> int:
    value = value.strip()
    if not value:
        return 0
    value = value.split()[0]
    try:
        return int(value, 0)
    except ValueError:
        return 0

current_slot = get_value("current-slot") or "UNKNOWN"
slot_suffix = current_slot if current_slot.startswith("_") else f"_{current_slot}"
slot_letter = slot_suffix[1:] if slot_suffix.startswith("_") else slot_suffix
is_userspace = get_value("is-userspace") or "UNKNOWN"

if require_fastbootd == "YES" and is_userspace != "yes":
    print("N1B_PHASE_11_FASTBOOTD_REQUIRED=FAIL_NOT_USERSPACE")
    print(f"IS_USERSPACE={is_userspace}")
    raise SystemExit(78)

partition_bases = [
    "system",
    "system_ext",
    "product",
    "vendor",
    "odm",
    "system_dlkm",
    "vendor_dlkm",
    "odm_dlkm",
]

partition_sizes: dict[str, int] = {}
for base in partition_bases:
    unsuffixed = parse_int(get_value(f"partition-size:{base}"))
    active = parse_int(get_value(f"partition-size:{base}_{slot_letter}"))
    a = parse_int(get_value(f"partition-size:{base}_a"))
    b = parse_int(get_value(f"partition-size:{base}_b"))
    selected = active or unsuffixed or max(a, b)
    partition_sizes[base] = selected

system_current_bytes = partition_sizes.get("system", 0)
super_bytes = parse_int(get_value("partition-size:super"))
selected_dynamic_total = sum(partition_sizes.values())
super_headroom_estimate = super_bytes - selected_dynamic_total if super_bytes else 0

metadata = {
    "active_slot": current_slot,
    "avb_action": "NO_AVB_MUTATION_PHASE11_READ_ONLY",
    "explicit_titan_serial": serial,
    "fastbootd_preflight": f"READ_ONLY_GETVAR is_userspace={is_userspace}",
    "is_userspace": is_userspace,
    "lp_action": "NO_LP_METADATA_MUTATION_PHASE11_READ_ONLY",
    "partition_sizes_current_slot_bytes": partition_sizes,
    "product": get_value("product") or "UNKNOWN",
    "secure": get_value("secure") or "UNKNOWN",
    "slot_count": get_value("slot-count") or "UNKNOWN",
    "super_bytes": str(super_bytes),
    "super_headroom_estimate_bytes": str(super_headroom_estimate),
    "super_partition_name": get_value("super-partition-name") or "UNKNOWN",
    "system_current_bytes": str(system_current_bytes),
    "total_selected_dynamic_current_bytes": str(selected_dynamic_total),
    "unlocked": get_value("unlocked") or "UNKNOWN",
    "userdata_policy": "PRESERVE_NO_ERASE",
}

result = {
    "phase": "N1B_PHASE_11_FASTBOOTD_LP_SUPER_SIZING",
    "device": "titan2",
    "release": "N1B",
    "device_contact_authorized": "YES_READ_ONLY_FASTBOOTD",
    "adb_commands_run": "NO",
    "fastboot_commands_run": "YES_READ_ONLY_GETVAR_ONLY",
    "reboot_commands_run": "NO",
    "flash_authorized": "NO",
    "flash_commands_run": "NO",
    "erase_commands_run": "NO",
    "unlock_commands_run": "NO",
    "lp_mutation_authorized": "NO",
    "avb_mutation_authorized": "NO",
    "evidence_dir": str(evidence),
    "metadata": metadata,
}

json_out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")

print("N1B_PHASE_11_FASTBOOTD_LP_SUPER_SIZING=PASS")
print(f"EXPLICIT_TITAN_FASTBOOT_SERIAL={serial}")
print(f"CURRENT_SLOT={current_slot}")
print(f"IS_USERSPACE={is_userspace}")
print(f"SYSTEM_CURRENT_BYTES={system_current_bytes}")
print(f"SUPER_BYTES={super_bytes}")
print(f"TOTAL_SELECTED_DYNAMIC_CURRENT_BYTES={selected_dynamic_total}")
print(f"SUPER_HEADROOM_ESTIMATE_BYTES={super_headroom_estimate}")
print(f"N1B_PHASE_11_LP_SIZING_JSON={json_out}")
PY

echo "===== N1B PHASE 11 FASTBOOTD LP/SUPER SIZING RESULT ====="
echo "N1B_PHASE_11_DEVICE_CONTACT=PASS_READ_ONLY_FASTBOOTD"
echo "N1B_PHASE_11_EVIDENCE_DIR=$EVIDENCE_DIR"
