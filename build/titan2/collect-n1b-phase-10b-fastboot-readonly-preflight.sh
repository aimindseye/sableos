#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVIDENCE_ROOT="${SABLE_N1B_PHASE_10_EVIDENCE_ROOT:-/srv/data/sable-build/evidence/titan2/n1b-phase-10-readonly-preflight}"
STAMP="$(date -u +%Y%m%d_%H%M%S)"
EVIDENCE_DIR="$EVIDENCE_ROOT/$STAMP/10b-fastboot"
TITAN_FASTBOOT_SERIAL="${TITAN_FASTBOOT_SERIAL:-}"

usage() {
  cat >&2 <<'EOF'
usage:
  bash build/titan2/collect-n1b-phase-10b-fastboot-readonly-preflight.sh [--serial <fastboot serial>]

Environment:
  TITAN_FASTBOOT_SERIAL=<fastboot serial> may be used instead of --serial.

This script assumes Titan2 is already in bootloader fastboot or fastbootd.
It collects read-only fastboot getvar metadata only.
It does not reboot, flash, erase, format, unlock, run OEM commands, or change slots.
EOF
}

while (($#)); do
  case "$1" in
    --serial) TITAN_FASTBOOT_SERIAL="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "N1B_PHASE_10B_FASTBOOT_READONLY_PREFLIGHT=FAIL_UNKNOWN_ARG arg=$1" >&2; usage; exit 64 ;;
  esac
done

mkdir -p "$EVIDENCE_DIR"
LOG="$EVIDENCE_DIR/phase10b-fastboot-readonly-preflight.log"
JSON_OUT="$EVIDENCE_DIR/phase10b-fastboot-readonly-preflight.json"

exec > >(tee "$LOG") 2>&1

echo "===== N1B PHASE 10B TITAN2 FASTBOOT READ-ONLY PREFLIGHT ====="
echo "ROOT=$ROOT"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "DEVICE=titan2"
echo "RELEASE=N1B"
echo "DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY"
echo "ADB_COMMANDS_RUN=NO"
echo "FASTBOOT_COMMANDS_AUTHORIZED=YES_READ_ONLY"
echo "REBOOT_COMMANDS_RUN=NO"
echo "FLASH_AUTHORIZED=NO"
echo "FLASH_COMMANDS_RUN=NO"
echo "ERASE_COMMANDS_RUN=NO"
echo "UNLOCK_COMMANDS_RUN=NO"
echo "PUBLIC_RELEASE=NO"
echo "PRODUCTION_SIGNING=NO"

command -v fastboot >/dev/null || {
  echo "N1B_PHASE_10B_FASTBOOT=FAIL_FASTBOOT_NOT_FOUND"
  exit 1
}

fastboot devices | tee "$EVIDENCE_DIR/fastboot-devices.txt"

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
    print("N1B_PHASE_10B_FASTBOOT_SERIAL=FAIL_EXPECTED_ONE_DEVICE", file=sys.stderr)
    print(f"FASTBOOT_DEVICE_COUNT={len(serials)}", file=sys.stderr)
    raise SystemExit(2)

print(serials[0])
PY

SERIAL="$(cat "$EVIDENCE_DIR/fastboot-serial.txt")"
echo "EXPLICIT_TITAN_FASTBOOT_SERIAL=$SERIAL"
FASTBOOT=(fastboot -s "$SERIAL")

"${FASTBOOT[@]}" getvar all > "$EVIDENCE_DIR/getvar-all.txt" 2>&1 || true

GETVARS=(
  current-slot
  is-userspace
  unlocked
  secure
  product
  slot-count
  partition-size:system
  partition-size:system_a
  partition-size:system_b
  partition-size:super
  has-slot:system
  super-partition-name
)

: > "$EVIDENCE_DIR/getvar-selected.txt"
for key in "${GETVARS[@]}"; do
  {
    echo "===== getvar $key ====="
    "${FASTBOOT[@]}" getvar "$key" 2>&1 || true
  } >> "$EVIDENCE_DIR/getvar-selected.txt"
done

python3 - "$EVIDENCE_DIR" "$SERIAL" "$JSON_OUT" <<'PY'
from __future__ import annotations

import json
import pathlib
import re
import sys

evidence = pathlib.Path(sys.argv[1])
serial = sys.argv[2]
json_out = pathlib.Path(sys.argv[3])

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
is_userspace = get_value("is-userspace") or "UNKNOWN"
unlocked = get_value("unlocked") or "UNKNOWN"
secure = get_value("secure") or "UNKNOWN"
product = get_value("product") or "UNKNOWN"
slot_count = get_value("slot-count") or "UNKNOWN"

sizes = [
    parse_int(get_value("partition-size:system")),
    parse_int(get_value("partition-size:system_a")),
    parse_int(get_value("partition-size:system_b")),
]
system_current_bytes = max(sizes) if sizes else 0

metadata = {
    "active_slot": current_slot,
    "avb_action": "NO_AVB_MUTATION_PHASE10_READ_ONLY",
    "bootloader_preflight": f"READ_ONLY_GETVAR product={product} unlocked={unlocked} secure={secure} slot_count={slot_count}",
    "explicit_titan_serial": serial,
    "fastbootd_preflight": f"READ_ONLY_GETVAR is_userspace={is_userspace}",
    "lp_action": "NO_LP_METADATA_MUTATION_PHASE10_READ_ONLY",
    "system_current_bytes": str(system_current_bytes),
    "userdata_policy": "PRESERVE_NO_ERASE",
}

result = {
    "phase": "N1B_PHASE_10B_FASTBOOT_READONLY_PREFLIGHT",
    "device": "titan2",
    "release": "N1B",
    "device_contact_authorized": "YES_READ_ONLY",
    "adb_commands_run": "NO",
    "fastboot_commands_run": "YES_READ_ONLY",
    "reboot_commands_run": "NO",
    "flash_authorized": "NO",
    "flash_commands_run": "NO",
    "erase_commands_run": "NO",
    "unlock_commands_run": "NO",
    "evidence_dir": str(evidence),
    "metadata": metadata,
}

json_out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")

print("N1B_PHASE_10B_FASTBOOT_READONLY_PREFLIGHT=PASS")
print(f"EXPLICIT_TITAN_FASTBOOT_SERIAL={serial}")
print(f"CURRENT_SLOT={current_slot}")
print(f"IS_USERSPACE={is_userspace}")
print(f"UNLOCKED={unlocked}")
print(f"SECURE={secure}")
print(f"SYSTEM_CURRENT_BYTES={system_current_bytes}")
print(f"N1B_PHASE_10B_PREFLIGHT_JSON={json_out}")
PY

echo "===== N1B PHASE 10B RESULT ====="
echo "N1B_PHASE_10B_DEVICE_CONTACT=PASS_READ_ONLY"
echo "N1B_PHASE_10B_EVIDENCE_DIR=$EVIDENCE_DIR"
