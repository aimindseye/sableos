#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVIDENCE_ROOT="${SABLE_N1B_PHASE_10_EVIDENCE_ROOT:-/srv/data/sable-build/evidence/titan2/n1b-phase-10-readonly-preflight}"
STAMP="$(date -u +%Y%m%d_%H%M%S)"
EVIDENCE_DIR="$EVIDENCE_ROOT/$STAMP/10b-fastboot"

TITAN_FASTBOOT_SERIAL="${TITAN_FASTBOOT_SERIAL:-}"
TITAN_ADB_SERIAL="${TITAN_ADB_SERIAL:-${TITAN_SERIAL:-}}"
ALLOW_ADB_REBOOT_BOOTLOADER="${TITAN_ALLOW_ADB_REBOOT_BOOTLOADER:-NO}"
ALLOW_FASTBOOT_REBOOT_FASTBOOTD="${TITAN_ALLOW_FASTBOOT_REBOOT_FASTBOOTD:-NO}"
REQUIRE_FASTBOOTD="${TITAN_REQUIRE_FASTBOOTD:-NO}"
WAIT_SECONDS="${TITAN_FASTBOOT_WAIT_SECONDS:-75}"
COMMAND_TIMEOUT_SECONDS="${TITAN_FASTBOOT_COMMAND_TIMEOUT_SECONDS:-30}"

usage() {
  cat >&2 <<'EOF'
usage:
  bash build/titan2/collect-n1b-phase-10b-fastboot-readonly-preflight.sh [options]

Options:
  --serial <fastboot serial>
      Expected fastboot serial. May also be set with TITAN_FASTBOOT_SERIAL.

  --adb-serial <adb serial>
      Expected adb serial for optional Android -> bootloader transition.
      May also be set with TITAN_ADB_SERIAL or TITAN_SERIAL.

  --adb-reboot-bootloader-if-android
      If no matching fastboot device is visible, use adb reboot bootloader.
      This is an explicit mode-switch command. It is not enabled by default.

  --fastboot-reboot-fastbootd-if-bootloader
      If bootloader fastboot reports is-userspace=no, use fastboot reboot fastboot
      to enter userspace fastbootd, then recollect read-only getvar metadata.
      This is an explicit mode-switch command. It is not enabled by default.

  --require-fastbootd
      Fail if final fastboot mode is not userspace fastbootd.

  --wait-seconds <n>
      Wait time for mode transitions. Default: 75.

  --command-timeout-seconds <n>
      Per-fastboot-command timeout. Default: 30.

Environment:
  TITAN_FASTBOOT_SERIAL=<fastboot serial>
  TITAN_ADB_SERIAL=<adb serial>
  TITAN_ALLOW_ADB_REBOOT_BOOTLOADER=YES
  TITAN_ALLOW_FASTBOOT_REBOOT_FASTBOOTD=YES
  TITAN_REQUIRE_FASTBOOTD=YES

This script collects read-only fastboot getvar metadata.
It never flashes, erases, formats, unlocks, runs OEM commands, or changes slots.
Mode switching is allowed only when the explicit flags above are supplied.
EOF
}

while (($#)); do
  case "$1" in
    --serial) TITAN_FASTBOOT_SERIAL="$2"; shift 2 ;;
    --adb-serial) TITAN_ADB_SERIAL="$2"; shift 2 ;;
    --adb-reboot-bootloader-if-android) ALLOW_ADB_REBOOT_BOOTLOADER=YES; shift ;;
    --fastboot-reboot-fastbootd-if-bootloader) ALLOW_FASTBOOT_REBOOT_FASTBOOTD=YES; shift ;;
    --require-fastbootd) REQUIRE_FASTBOOTD=YES; shift ;;
    --wait-seconds) WAIT_SECONDS="$2"; shift 2 ;;
    --command-timeout-seconds) COMMAND_TIMEOUT_SECONDS="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "N1B_PHASE_10B_FASTBOOT_READONLY_PREFLIGHT=FAIL_UNKNOWN_ARG arg=$1" >&2; usage; exit 64 ;;
  esac
done

[[ "$WAIT_SECONDS" =~ ^[1-9][0-9]*$ ]] || { echo "N1B_PHASE_10B=FAIL_WAIT_SECONDS value=$WAIT_SECONDS"; exit 64; }
[[ "$COMMAND_TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]] || { echo "N1B_PHASE_10B=FAIL_COMMAND_TIMEOUT_SECONDS value=$COMMAND_TIMEOUT_SECONDS"; exit 64; }

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
echo "ADB_COMMANDS_RUN=NO_UNLESS_EXPLICIT_MODE_SWITCH"
echo "FASTBOOT_COMMANDS_AUTHORIZED=YES_READ_ONLY"
echo "MODE_SWITCH_AUTHORIZED_ADB_REBOOT_BOOTLOADER=$ALLOW_ADB_REBOOT_BOOTLOADER"
echo "MODE_SWITCH_AUTHORIZED_FASTBOOT_REBOOT_FASTBOOTD=$ALLOW_FASTBOOT_REBOOT_FASTBOOTD"
echo "REBOOT_COMMANDS_RUN=NO_UNLESS_EXPLICIT_MODE_SWITCH"
echo "FLASH_AUTHORIZED=NO"
echo "FLASH_COMMANDS_RUN=NO"
echo "ERASE_COMMANDS_RUN=NO"
echo "UNLOCK_COMMANDS_RUN=NO"
echo "PUBLIC_RELEASE=NO"
echo "PRODUCTION_SIGNING=NO"
echo "REQUIRE_FASTBOOTD=$REQUIRE_FASTBOOTD"
echo "WAIT_SECONDS=$WAIT_SECONDS"
echo "COMMAND_TIMEOUT_SECONDS=$COMMAND_TIMEOUT_SECONDS"

command -v fastboot >/dev/null || {
  echo "N1B_PHASE_10B_FASTBOOT=FAIL_FASTBOOT_NOT_FOUND"
  exit 1
}

have_fastboot_device() {
  timeout "$COMMAND_TIMEOUT_SECONDS" fastboot devices 2>/dev/null \
    | awk 'NF >= 2 {print $1}'
}

write_fastboot_devices() {
  timeout "$COMMAND_TIMEOUT_SECONDS" fastboot devices | tee "$EVIDENCE_DIR/fastboot-devices.txt" || true
}

resolve_one_serial() {
  local explicit="$1"
  local path="$2"
  python3 - "$explicit" "$path" <<'PY'
from __future__ import annotations
import sys
explicit = sys.argv[1].strip()
path = sys.argv[2]
if explicit:
    print(explicit)
    raise SystemExit(0)
serials = []
try:
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
except FileNotFoundError:
    lines = []
for line in lines:
    parts = line.split()
    if parts:
        serials.append(parts[0])
if len(serials) != 1:
    print("N1B_PHASE_10B_SERIAL=FAIL_EXPECTED_ONE_DEVICE", file=sys.stderr)
    print(f"DEVICE_COUNT={len(serials)}", file=sys.stderr)
    raise SystemExit(2)
print(serials[0])
PY
}

wait_for_fastboot() {
  local expected="$1"
  local deadline=$((SECONDS + WAIT_SECONDS))
  while (( SECONDS < deadline )); do
    write_fastboot_devices >/dev/null
    if [[ -n "$expected" ]] && grep -Fq "$expected" "$EVIDENCE_DIR/fastboot-devices.txt"; then
      return 0
    fi
    if [[ -z "$expected" ]] && [[ -s "$EVIDENCE_DIR/fastboot-devices.txt" ]]; then
      return 0
    fi
    sleep 2
  done
  return 1
}

write_fastboot_devices

if [[ ! -s "$EVIDENCE_DIR/fastboot-devices.txt" && "$ALLOW_ADB_REBOOT_BOOTLOADER" == YES ]]; then
  command -v adb >/dev/null || {
    echo "N1B_PHASE_10B_ADB_REBOOT_BOOTLOADER=FAIL_ADB_NOT_FOUND"
    exit 1
  }
  echo "N1B_PHASE_10B_ADB_REBOOT_BOOTLOADER=REQUESTED"
  adb devices -l | tee "$EVIDENCE_DIR/adb-devices-before-mode-switch.txt"
  ADB_SERIAL="$(python3 - "$TITAN_ADB_SERIAL" "$EVIDENCE_DIR/adb-devices-before-mode-switch.txt" <<'PY'
from __future__ import annotations
import sys
explicit = sys.argv[1].strip()
path = sys.argv[2]
if explicit:
    print(explicit)
    raise SystemExit(0)
serials = []
for line in open(path, encoding="utf-8", errors="replace"):
    parts = line.split()
    if len(parts) >= 2 and parts[1] == "device":
        serials.append(parts[0])
if len(serials) != 1:
    print("N1B_PHASE_10B_ADB_SERIAL=FAIL_EXPECTED_ONE_DEVICE", file=sys.stderr)
    print(f"ADB_DEVICE_COUNT={len(serials)}", file=sys.stderr)
    raise SystemExit(2)
print(serials[0])
PY
)"
  echo "EXPLICIT_TITAN_ADB_SERIAL=$ADB_SERIAL"
  echo "REBOOT_COMMANDS_RUN=YES_ADB_REBOOT_BOOTLOADER_EXPLICIT"
  adb -s "$ADB_SERIAL" reboot bootloader
  if ! wait_for_fastboot "$TITAN_FASTBOOT_SERIAL"; then
    echo "N1B_PHASE_10B_FASTBOOT=FAIL_WAIT_FOR_BOOTLOADER"
    exit 2
  fi
fi

write_fastboot_devices
SERIAL="$(resolve_one_serial "$TITAN_FASTBOOT_SERIAL" "$EVIDENCE_DIR/fastboot-devices.txt")"
echo "EXPLICIT_TITAN_FASTBOOT_SERIAL=$SERIAL"
FASTBOOT=(fastboot -s "$SERIAL")

collect_getvars() {
  local phase="$1"
  local out_dir="$EVIDENCE_DIR/$phase"
  mkdir -p "$out_dir"
  timeout "$COMMAND_TIMEOUT_SECONDS" "${FASTBOOT[@]}" getvar all > "$out_dir/getvar-all.txt" 2>&1 || true
  : > "$out_dir/getvar-selected.txt"
  local keys=(
    current-slot
    is-userspace
    unlocked
    secure
    product
    slot-count
    snapshot-update-status
    partition-size:system
    partition-size:system_a
    partition-size:system_b
    partition-size:super
    has-slot:system
    super-partition-name
  )
  local key
  for key in "${keys[@]}"; do
    {
      echo "===== getvar $key ====="
      timeout "$COMMAND_TIMEOUT_SECONDS" "${FASTBOOT[@]}" getvar "$key" 2>&1 || true
    } >> "$out_dir/getvar-selected.txt"
  done
}

collect_getvars initial

python3 - "$EVIDENCE_DIR/initial" > "$EVIDENCE_DIR/initial-mode.env" <<'PY'
from __future__ import annotations
import pathlib
import re
import sys
root = pathlib.Path(sys.argv[1])
text = ""
for name in ("getvar-all.txt", "getvar-selected.txt"):
    p = root / name
    if p.exists():
        text += "\n" + p.read_text(errors="replace")
def get(key: str) -> str:
    m = re.search(rf"(?:^|\n)\s*{re.escape(key)}:\s*([^\n\r]+)", text)
    return m.group(1).strip() if m else ""
print(f"IS_USERSPACE={get('is-userspace') or 'UNKNOWN'}")
PY
# shellcheck disable=SC1091
source "$EVIDENCE_DIR/initial-mode.env"

echo "INITIAL_IS_USERSPACE=$IS_USERSPACE"

if [[ "$IS_USERSPACE" == no && "$ALLOW_FASTBOOT_REBOOT_FASTBOOTD" == YES ]]; then
  echo "N1B_PHASE_10B_FASTBOOT_REBOOT_FASTBOOTD=REQUESTED"
  echo "REBOOT_COMMANDS_RUN=YES_FASTBOOT_REBOOT_FASTBOOTD_EXPLICIT"
  timeout "$COMMAND_TIMEOUT_SECONDS" "${FASTBOOT[@]}" reboot fastboot || true
  if ! wait_for_fastboot "$SERIAL"; then
    echo "N1B_PHASE_10B_FASTBOOT=FAIL_WAIT_FOR_FASTBOOTD"
    exit 2
  fi
  collect_getvars final
else
  cp -a "$EVIDENCE_DIR/initial" "$EVIDENCE_DIR/final"
fi

python3 - "$EVIDENCE_DIR" "$SERIAL" "$JSON_OUT" "$REQUIRE_FASTBOOTD" <<'PY'
from __future__ import annotations

import json
import pathlib
import re
import sys

evidence = pathlib.Path(sys.argv[1])
serial = sys.argv[2]
json_out = pathlib.Path(sys.argv[3])
require_fastbootd = sys.argv[4] == "YES"

text = ""
for name in ("final/getvar-all.txt", "final/getvar-selected.txt"):
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

if require_fastbootd and is_userspace != "yes":
    print("N1B_PHASE_10B_FASTBOOTD=FAIL_REQUIRED_BUT_NOT_USERSPACE")
    print(f"IS_USERSPACE={is_userspace}")
    raise SystemExit(2)

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
    "adb_commands_run": "YES_ONLY_IF_EXPLICIT_ADB_REBOOT_BOOTLOADER_FLAG_WAS_USED",
    "fastboot_commands_run": "YES_READ_ONLY_PLUS_EXPLICIT_MODE_SWITCH_IF_FLAG_WAS_USED",
    "reboot_commands_run": "YES_ONLY_IF_EXPLICIT_MODE_SWITCH_FLAG_WAS_USED",
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
