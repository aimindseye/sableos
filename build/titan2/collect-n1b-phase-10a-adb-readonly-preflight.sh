#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVIDENCE_ROOT="${SABLE_N1B_PHASE_10_EVIDENCE_ROOT:-/srv/data/sable-build/evidence/titan2/n1b-phase-10-readonly-preflight}"
STAMP="$(date -u +%Y%m%d_%H%M%S)"
EVIDENCE_DIR="$EVIDENCE_ROOT/$STAMP/10a-adb"
TITAN_SERIAL="${TITAN_SERIAL:-}"

usage() {
  cat >&2 <<'EOF'
usage:
  bash build/titan2/collect-n1b-phase-10a-adb-readonly-preflight.sh [--serial <adb serial>]

Environment:
  TITAN_SERIAL=<adb serial> may be used instead of --serial.

This script contacts Titan2 through ADB for read-only metadata collection only.
It does not reboot, root, remount, push, install, erase, unlock, or flash.
EOF
}

while (($#)); do
  case "$1" in
    --serial) TITAN_SERIAL="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "N1B_PHASE_10A_ADB_READONLY_PREFLIGHT=FAIL_UNKNOWN_ARG arg=$1" >&2; usage; exit 64 ;;
  esac
done

mkdir -p "$EVIDENCE_DIR"
LOG="$EVIDENCE_DIR/phase10a-adb-readonly-preflight.log"
JSON_OUT="$EVIDENCE_DIR/phase10a-adb-readonly-preflight.json"

exec > >(tee "$LOG") 2>&1

echo "===== N1B PHASE 10A TITAN2 ADB READ-ONLY PREFLIGHT ====="
echo "ROOT=$ROOT"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "DEVICE=titan2"
echo "RELEASE=N1B"
echo "DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY"
echo "ADB_COMMANDS_AUTHORIZED=YES_READ_ONLY"
echo "FASTBOOT_COMMANDS_RUN=NO"
echo "REBOOT_COMMANDS_RUN=NO"
echo "FLASH_AUTHORIZED=NO"
echo "FLASH_COMMANDS_RUN=NO"
echo "ERASE_COMMANDS_RUN=NO"
echo "UNLOCK_COMMANDS_RUN=NO"
echo "PUBLIC_RELEASE=NO"
echo "PRODUCTION_SIGNING=NO"

command -v adb >/dev/null || {
  echo "N1B_PHASE_10A_ADB=FAIL_ADB_NOT_FOUND"
  exit 1
}

adb start-server >/dev/null
adb devices -l | tee "$EVIDENCE_DIR/adb-devices-l.txt"

python3 - "$TITAN_SERIAL" "$EVIDENCE_DIR/adb-devices-l.txt" > "$EVIDENCE_DIR/adb-serial.txt" <<'PY'
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
    if not line or line.startswith("List of devices"):
        continue
    parts = line.split()
    if len(parts) >= 2 and parts[1] == "device":
        serials.append(parts[0])

if len(serials) != 1:
    print("N1B_PHASE_10A_ADB_SERIAL=FAIL_EXPECTED_ONE_AUTHORIZED_DEVICE", file=sys.stderr)
    print(f"AUTHORIZED_DEVICE_COUNT={len(serials)}", file=sys.stderr)
    raise SystemExit(2)

print(serials[0])
PY

SERIAL="$(cat "$EVIDENCE_DIR/adb-serial.txt")"
echo "EXPLICIT_TITAN_SERIAL=$SERIAL"
ADB=(adb -s "$SERIAL")

"${ADB[@]}" shell getprop > "$EVIDENCE_DIR/getprop.txt"
"${ADB[@]}" shell 'id; uname -a; cat /proc/cmdline 2>/dev/null || true' > "$EVIDENCE_DIR/basic-device.txt"
"${ADB[@]}" shell 'ls -l /dev/block/by-name 2>/dev/null || true' > "$EVIDENCE_DIR/by-name.txt"
"${ADB[@]}" shell 'cat /proc/mounts 2>/dev/null || true' > "$EVIDENCE_DIR/proc-mounts.txt"
"${ADB[@]}" shell 'df -h 2>/dev/null || true' > "$EVIDENCE_DIR/df-h.txt"
"${ADB[@]}" shell 'getprop ro.boot.slot_suffix' | tr -d '\r' > "$EVIDENCE_DIR/active-slot.txt"
"${ADB[@]}" shell 'getprop ro.build.fingerprint' | tr -d '\r' > "$EVIDENCE_DIR/stock-baseline-fingerprint.txt"
"${ADB[@]}" shell 'getprop ro.product.board; getprop ro.board.platform; getprop ro.product.device; getprop ro.product.vendor.device' | tr -d '\r' > "$EVIDENCE_DIR/device-identity.txt"
"${ADB[@]}" shell 'getprop ro.virtual_ab.enabled; getprop ro.virtual_ab.compression.enabled; getprop ro.boot.dynamic_partitions' | tr -d '\r' > "$EVIDENCE_DIR/virtual-ab-dynamic.txt"
"${ADB[@]}" shell 'snapshotctl status 2>/dev/null || true' | tr -d '\r' > "$EVIDENCE_DIR/snapshotctl-status.txt"
"${ADB[@]}" shell 'dumpsys update_engine 2>/dev/null || true' | tr -d '\r' > "$EVIDENCE_DIR/update-engine.txt"
"${ADB[@]}" shell '
  for p in \
    /dev/block/by-name/system \
    /dev/block/by-name/system_a \
    /dev/block/by-name/system_b \
    /dev/block/mapper/system \
    /dev/block/mapper/system_a \
    /dev/block/mapper/system_b
  do
    if [ -e "$p" ]; then
      echo "CANDIDATE=$p"
      blockdev --getsize64 "$p" 2>/dev/null || true
    fi
  done
' | tr -d '\r' > "$EVIDENCE_DIR/system-block-size-candidates.txt"

python3 - "$EVIDENCE_DIR" "$SERIAL" "$JSON_OUT" <<'PY'
from __future__ import annotations

import json
import pathlib
import re
import sys

evidence = pathlib.Path(sys.argv[1])
serial = sys.argv[2]
json_out = pathlib.Path(sys.argv[3])


def read(name: str) -> str:
    path = evidence / name
    if not path.exists():
        return ""
    return path.read_text(errors="replace").strip()

slot = read("active-slot.txt")
fingerprint = read("stock-baseline-fingerprint.txt")
snapshot = read("snapshotctl-status.txt") or read("update-engine.txt")

system_sizes: list[int] = []
for line in read("system-block-size-candidates.txt").splitlines():
    line = line.strip()
    if re.fullmatch(r"[0-9]+", line):
        system_sizes.append(int(line))

system_current_bytes = max(system_sizes) if system_sizes else 0

restore_root = pathlib.Path("/srv/data/sable-build/artifacts/titan2/stock-firmware")
restore_candidates = []
if restore_root.exists():
    restore_candidates = sorted(str(p) for p in restore_root.glob("*") if p.is_dir())

restore_path_verified = "YES" if restore_candidates else "NO"
restore_report = restore_candidates[-1] if restore_candidates else "MISSING_STOCK_FIRMWARE_RESTORE_PATH"

metadata = {
    "active_slot": slot or "UNKNOWN",
    "avb_action": "NO_AVB_MUTATION_PHASE10_READ_ONLY",
    "bootloader_preflight": "NOT_COLLECTED_ADB_ONLY",
    "explicit_titan_serial": serial,
    "fastbootd_preflight": "NOT_COLLECTED_ADB_ONLY",
    "lp_action": "NO_LP_METADATA_MUTATION_PHASE10_READ_ONLY",
    "restore_path_verified": restore_path_verified,
    "restore_report": restore_report,
    "snapshot_update_status": snapshot or "UNKNOWN",
    "stock_baseline": fingerprint or "UNKNOWN",
    "system_current_bytes": str(system_current_bytes),
    "userdata_policy": "PRESERVE_NO_ERASE",
}

result = {
    "phase": "N1B_PHASE_10A_ADB_READONLY_PREFLIGHT",
    "device": "titan2",
    "release": "N1B",
    "device_contact_authorized": "YES_READ_ONLY",
    "adb_commands_run": "YES_READ_ONLY",
    "fastboot_commands_run": "NO",
    "reboot_commands_run": "NO",
    "flash_authorized": "NO",
    "flash_commands_run": "NO",
    "erase_commands_run": "NO",
    "unlock_commands_run": "NO",
    "evidence_dir": str(evidence),
    "metadata": metadata,
}

json_out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")

print("N1B_PHASE_10A_ADB_READONLY_PREFLIGHT=PASS")
print(f"EXPLICIT_TITAN_SERIAL={serial}")
print(f"ACTIVE_SLOT={metadata['active_slot']}")
print(f"STOCK_BASELINE={metadata['stock_baseline']}")
print(f"SYSTEM_CURRENT_BYTES={metadata['system_current_bytes']}")
print(f"RESTORE_PATH_VERIFIED={metadata['restore_path_verified']}")
print(f"RESTORE_REPORT={metadata['restore_report']}")
print(f"N1B_PHASE_10A_PREFLIGHT_JSON={json_out}")
PY

echo "===== N1B PHASE 10A RESULT ====="
echo "N1B_PHASE_10A_DEVICE_CONTACT=PASS_READ_ONLY"
echo "N1B_PHASE_10A_EVIDENCE_DIR=$EVIDENCE_DIR"
