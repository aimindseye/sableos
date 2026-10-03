#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="/srv/sable-build/evidence/titan2/n1d-c3b-e5a-readonly-device-state/$STAMP"

SYSTEM_IMG="/srv/sable-build/workspaces/titan2-n1d-c3b/out-c3b-engineering/e3-systemimage/20261003T014638Z/target/product/tdgsi_arm64_ab/system.img"
EXPECTED_SYSTEM_SHA256="998a8b99cd4d1a631006291a96c6f0160c5a4400c4bf6bba62c319c4ed3c82a5"
EXPECTED_SYSTEM_BYTES="2994405376"
EXPECTED_STOCK_FINGERPRINT="Unihertz/Titan_2/Titan_2:16/BP2A.250605.031.A3/V01.00.14:user/release-keys"
EXPECTED_STOCK_INCREMENTAL="V01.00.14"
PLANNED_SYSTEM_TARGET_BYTES="3263168512"
MIN_REMAINING_HEADROOM_BYTES="536870912"
MIN_FUTURE_MUTATION_BATTERY_PERCENT="50"

ADB_SERIAL=""
FASTBOOT_SERIAL=""
AUTHORIZE_READONLY=NO
AUTHORIZE_REBOOT_TO_FASTBOOTD=NO
WAIT_SECONDS=90
COMMAND_TIMEOUT_SECONDS=30

usage() {
  cat >&2 <<'EOF'
usage:
  bash build/titan2/collect-n1d-c3b-e5a-readonly-device-state.sh \
    --authorize-e5a-readonly \
    --authorize-reboot-to-fastbootd \
    [--adb-serial SERIAL] \
    [--fastboot-serial SERIAL] \
    [--wait-seconds N] \
    [--command-timeout-seconds N] \
    [--evidence-dir DIR]

Required starting state:
  Titan 2 booted into stock Android V01.00.14 with USB debugging authorized.

Authorized:
  read-only ADB inspection
  adb reboot bootloader
  read-only fastboot/fastbootd getvar inspection
  fastboot reboot fastboot (bootloader -> userspace fastbootd)

Not authorized:
  flash / update / custom boot
  erase / format / factory reset
  logical-partition resize/delete/create
  AVB/vbmeta mutation
  slot mutation
  bootloader unlock/lock
  reboot back to Android

The device is intentionally left in userspace fastbootd after evidence capture.
EOF
}

while (($#)); do
  case "$1" in
    --authorize-e5a-readonly) AUTHORIZE_READONLY=YES; shift ;;
    --authorize-reboot-to-fastbootd) AUTHORIZE_REBOOT_TO_FASTBOOTD=YES; shift ;;
    --adb-serial) ADB_SERIAL="$2"; shift 2 ;;
    --fastboot-serial) FASTBOOT_SERIAL="$2"; shift 2 ;;
    --wait-seconds) WAIT_SECONDS="$2"; shift 2 ;;
    --command-timeout-seconds) COMMAND_TIMEOUT_SECONDS="$2"; shift 2 ;;
    --evidence-dir) EVIDENCE_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "N1D_C3B_E5A_READONLY_DEVICE_STATE=FAIL_UNKNOWN_ARG arg=$1" >&2; usage; exit 64 ;;
  esac
done

[[ "$AUTHORIZE_READONLY" == YES ]] || {
  echo "N1D_C3B_E5A_READONLY_DEVICE_STATE=FAIL_READONLY_AUTHORIZATION_REQUIRED" >&2
  exit 64
}
[[ "$AUTHORIZE_REBOOT_TO_FASTBOOTD" == YES ]] || {
  echo "N1D_C3B_E5A_READONLY_DEVICE_STATE=FAIL_REBOOT_AUTHORIZATION_REQUIRED" >&2
  exit 64
}
[[ "$WAIT_SECONDS" =~ ^[1-9][0-9]*$ ]] || { echo "N1D_C3B_E5A=FAIL_WAIT_SECONDS"; exit 64; }
[[ "$COMMAND_TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]] || { echo "N1D_C3B_E5A=FAIL_COMMAND_TIMEOUT_SECONDS"; exit 64; }

fail() {
  echo "N1D_C3B_E5A_READONLY_DEVICE_STATE=FAIL reason=$1" >&2
  exit 1
}

mkdir -p "$EVIDENCE_DIR"
LOG="$EVIDENCE_DIR/e5a-readonly-device-state.log"
JSON_OUT="$EVIDENCE_DIR/e5a-readonly-device-state.json"
exec > >(tee "$LOG") 2>&1

echo "===== TITAN 2 N1D C3B E5A READ-ONLY DEVICE-STATE REVALIDATION ====="
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY_E5A"
echo "ADB_READONLY_AUTHORIZED=YES"
echo "FASTBOOT_READONLY_AUTHORIZED=YES"
echo "REBOOT_BOOTLOADER_AUTHORIZED=YES"
echo "REBOOT_FASTBOOTD_AUTHORIZED=YES"
echo "FLASH_AUTHORIZED=NO"
echo "FLASH_COMMANDS_RUN=NO"
echo "ERASE_AUTHORIZED=NO"
echo "ERASE_COMMANDS_RUN=NO"
echo "FORMAT_AUTHORIZED=NO"
echo "LP_MUTATION_AUTHORIZED=NO"
echo "AVB_MUTATION_AUTHORIZED=NO"
echo "SLOT_MUTATION_AUTHORIZED=NO"
echo "UNLOCK_LOCK_AUTHORIZED=NO"
echo "FACTORY_RESET_AUTHORIZED=NO"
echo "CUSTOM_BOOT_AUTHORIZED=NO"
echo "PRODUCTION_SIGNING_AUTHORIZED=NO"
echo "RELEASE_ELIGIBLE=NO"
echo "FINAL_DEVICE_MODE=FASTBOOTD_EXPECTED"
echo "REBOOT_BACK_TO_ANDROID=NO_NOT_AUTHORIZED"

bash "$ROOT/build/gates/n1d-c3b-e4-evidence-contract.sh"

[[ -f "$SYSTEM_IMG" ]] || fail "sealed_system_image_missing"
actual_system_sha="$(sha256sum "$SYSTEM_IMG" | awk '{print $1}')"
actual_system_bytes="$(stat -c '%s' "$SYSTEM_IMG")"
[[ "$actual_system_sha" == "$EXPECTED_SYSTEM_SHA256" ]] || fail "sealed_system_sha_mismatch"
[[ "$actual_system_bytes" == "$EXPECTED_SYSTEM_BYTES" ]] || fail "sealed_system_size_mismatch"
echo "N1D_C3B_E5A_E4_SEAL=PASS"

command -v adb >/dev/null 2>&1 || fail "adb_not_found"
command -v fastboot >/dev/null 2>&1 || fail "fastboot_not_found"
command -v timeout >/dev/null 2>&1 || fail "timeout_not_found"

adb start-server >/dev/null 2>&1 || fail "adb_start_server"
adb devices -l > "$EVIDENCE_DIR/adb-devices-l.txt"

resolve_adb_serial() {
  python3 - "$ADB_SERIAL" "$EVIDENCE_DIR/adb-devices-l.txt" <<'PY'
from __future__ import annotations
import sys
explicit = sys.argv[1].strip()
path = sys.argv[2]
devices = []
for line in open(path, encoding="utf-8", errors="replace"):
    parts = line.split()
    if len(parts) >= 2 and parts[1] == "device":
        devices.append(parts[0])
if explicit:
    if explicit not in devices:
        raise SystemExit("explicit adb serial is not an authorized connected device")
    print(explicit)
    raise SystemExit(0)
if len(devices) != 1:
    raise SystemExit(f"expected exactly one authorized adb device, got {len(devices)}")
print(devices[0])
PY
}

ADB_SERIAL="$(resolve_adb_serial)" || fail "adb_device_resolution"
serial_binding_sha256="$(printf '%s' "$ADB_SERIAL" | sha256sum | awk '{print $1}')"
echo "N1D_C3B_E5A_DEVICE_BINDING_SHA256=$serial_binding_sha256"
echo "N1D_C3B_E5A_ADB_DEVICE=PASS_ONE_AUTHORIZED"

ADB=(adb -s "$ADB_SERIAL")

"${ADB[@]}" shell getprop > "$EVIDENCE_DIR/getprop.txt"
"${ADB[@]}" shell dumpsys battery > "$EVIDENCE_DIR/battery.txt"
"${ADB[@]}" shell 'snapshotctl status 2>/dev/null || true' > "$EVIDENCE_DIR/snapshotctl-status.txt"
"${ADB[@]}" shell 'dumpsys update_engine 2>/dev/null || true' > "$EVIDENCE_DIR/update-engine.txt"
"${ADB[@]}" shell 'lpdump 2>/dev/null || true' > "$EVIDENCE_DIR/lpdump.txt"
"${ADB[@]}" shell 'ls -l /dev/block/by-name 2>/dev/null || true' > "$EVIDENCE_DIR/by-name.txt"
"${ADB[@]}" shell '
  for p in \
    /dev/block/by-name/system \
    /dev/block/by-name/system_a \
    /dev/block/by-name/system_b \
    /dev/block/mapper/system \
    /dev/block/mapper/system_a \
    /dev/block/mapper/system_b \
    /dev/block/by-name/super
  do
    if [ -e "$p" ]; then
      echo "CANDIDATE=$p"
      blockdev --getsize64 "$p" 2>/dev/null || true
    fi
  done
' > "$EVIDENCE_DIR/adb-block-sizes.txt"

python3 - "$EVIDENCE_DIR" "$EXPECTED_STOCK_FINGERPRINT" "$EXPECTED_STOCK_INCREMENTAL" "$MIN_FUTURE_MUTATION_BATTERY_PERCENT" <<'PY' > "$EVIDENCE_DIR/adb-summary.env"
from __future__ import annotations
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
expected_fp = sys.argv[2]
expected_inc = sys.argv[3]
min_battery = int(sys.argv[4])

getprop = (root / "getprop.txt").read_text(errors="replace")
battery = (root / "battery.txt").read_text(errors="replace")

def prop(name: str) -> str:
    m = re.search(rf"^\[{re.escape(name)}\]: \[(.*)\]$", getprop, re.M)
    return m.group(1).strip() if m else ""

def battery_int(label: str) -> int:
    m = re.search(rf"^\s*{re.escape(label)}:\s*([0-9]+)\s*$", battery, re.M | re.I)
    return int(m.group(1)) if m else -1

fingerprint = prop("ro.build.fingerprint")
incremental = prop("ro.build.version.incremental")
vendor_fp = prop("ro.vendor.build.fingerprint")
slot = prop("ro.boot.slot_suffix").lstrip("_")
verified = prop("ro.boot.verifiedbootstate")
vbmeta_state = prop("ro.boot.vbmeta.device_state")
flash_locked = prop("ro.boot.flash.locked")
dynamic = prop("ro.boot.dynamic_partitions")
virtual_ab = prop("ro.virtual_ab.enabled")
virtual_ab_compression = prop("ro.virtual_ab.compression.enabled")
level = battery_int("level")

print(f"ADB_STOCK_FINGERPRINT={fingerprint}")
print(f"ADB_STOCK_INCREMENTAL={incremental}")
print(f"ADB_VENDOR_FINGERPRINT={vendor_fp}")
print(f"ADB_CURRENT_SLOT={slot or 'UNKNOWN'}")
print(f"ADB_VERIFIED_BOOT_STATE={verified or 'UNKNOWN'}")
print(f"ADB_VBMETA_DEVICE_STATE={vbmeta_state or 'UNKNOWN'}")
print(f"ADB_FLASH_LOCKED={flash_locked or 'UNKNOWN'}")
print(f"ADB_DYNAMIC_PARTITIONS={dynamic or 'UNKNOWN'}")
print(f"ADB_VIRTUAL_AB={virtual_ab or 'UNKNOWN'}")
print(f"ADB_VIRTUAL_AB_COMPRESSION={virtual_ab_compression or 'UNKNOWN'}")
print(f"ADB_BATTERY_LEVEL={level if level >= 0 else 'UNKNOWN'}")
print(f"ADB_STOCK_FINGERPRINT_MATCH={'PASS' if fingerprint == expected_fp else 'FAIL'}")
print(f"ADB_STOCK_INCREMENTAL_MATCH={'PASS' if incremental == expected_inc else 'FAIL'}")
if level < 0:
    print("ADB_BATTERY_SANITY=REVIEW_UNKNOWN")
elif level >= min_battery:
    print("ADB_BATTERY_SANITY=PASS")
else:
    print("ADB_BATTERY_SANITY=BLOCK_BELOW_FUTURE_MUTATION_THRESHOLD")
PY

# shellcheck disable=SC1090
source "$EVIDENCE_DIR/adb-summary.env"
cat "$EVIDENCE_DIR/adb-summary.env"

[[ "$ADB_STOCK_FINGERPRINT_MATCH" == PASS ]] || fail "stock_fingerprint_mismatch"
[[ "$ADB_STOCK_INCREMENTAL_MATCH" == PASS ]] || fail "stock_incremental_mismatch"
[[ "$ADB_CURRENT_SLOT" == a || "$ADB_CURRENT_SLOT" == b ]] || fail "adb_current_slot_unknown"

echo "N1D_C3B_E5A_ADB_BASELINE=PASS"

echo "N1D_C3B_E5A_ADB_REBOOT_BOOTLOADER=AUTHORIZED_AND_RUNNING"
"${ADB[@]}" reboot bootloader

resolve_fastboot_serial() {
  local explicit="$1"
  local deadline=$((SECONDS + WAIT_SECONDS))
  while (( SECONDS < deadline )); do
    timeout "$COMMAND_TIMEOUT_SECONDS" fastboot devices > "$EVIDENCE_DIR/fastboot-devices.txt" 2>/dev/null || true
    if resolved="$(
      python3 - "$explicit" "$EVIDENCE_DIR/fastboot-devices.txt" <<'PY'
from __future__ import annotations
import sys

explicit = sys.argv[1].strip()
path = sys.argv[2]
devices = []
for line in open(path, encoding="utf-8", errors="replace"):
    parts = line.split()
    if parts:
        devices.append(parts[0])

if explicit:
    if explicit not in devices:
        raise SystemExit(2)
    print(explicit)
    raise SystemExit(0)

if len(devices) != 1:
    raise SystemExit(3)
print(devices[0])
PY
    )"; then
      printf '%s\n' "$resolved"
      return 0
    fi
    sleep 2
  done
  return 1
}

FASTBOOT_SERIAL="$(resolve_fastboot_serial "$FASTBOOT_SERIAL")" ||
  fail "wait_for_single_bootloader_fastboot"
fastboot_binding_sha256="$(printf '%s' "$FASTBOOT_SERIAL" | sha256sum | awk '{print $1}')"
echo "N1D_C3B_E5A_FASTBOOT_BINDING_SHA256=$fastboot_binding_sha256"
echo "N1D_C3B_E5A_DEVICE_BINDING_METHOD=CONTROLLED_SINGLE_DEVICE_MODE_TRANSITION"
echo "N1D_C3B_E5A_FASTBOOT_DEVICE_BINDING=PASS"

FASTBOOT=(fastboot -s "$FASTBOOT_SERIAL")

collect_getvar() {
  local key="$1"
  timeout "$COMMAND_TIMEOUT_SECONDS" "${FASTBOOT[@]}" getvar "$key" 2>&1 || true
}

collect_getvar all > "$EVIDENCE_DIR/bootloader-getvar-all.txt"
{
  for key in current-slot is-userspace unlocked secure product slot-count snapshot-update-status super-partition-name; do
    echo "===== $key ====="
    collect_getvar "$key"
  done
} > "$EVIDENCE_DIR/bootloader-getvar-selected.txt"

python3 - "$EVIDENCE_DIR/bootloader-getvar-all.txt" "$EVIDENCE_DIR/bootloader-getvar-selected.txt" <<'PY' > "$EVIDENCE_DIR/bootloader-summary.env"
from __future__ import annotations
import pathlib
import re
import sys

text = "\n".join(pathlib.Path(p).read_text(errors="replace") for p in sys.argv[1:])

def get(key: str) -> str:
    for line in text.splitlines():
        line = re.sub(r"^\s*\([^)]*\)\s*", "", line.strip())
        if line.lower().startswith(key.lower() + ":"):
            return line.split(":", 1)[1].strip()
    return ""

print(f"BOOTLOADER_CURRENT_SLOT={get('current-slot') or 'UNKNOWN'}")
print(f"BOOTLOADER_IS_USERSPACE={get('is-userspace') or 'UNKNOWN'}")
print(f"BOOTLOADER_UNLOCKED={get('unlocked') or 'UNKNOWN'}")
print(f"BOOTLOADER_SECURE={get('secure') or 'UNKNOWN'}")
print(f"BOOTLOADER_PRODUCT={get('product') or 'UNKNOWN'}")
print(f"BOOTLOADER_SLOT_COUNT={get('slot-count') or 'UNKNOWN'}")
print(f"BOOTLOADER_SNAPSHOT_UPDATE_STATUS={get('snapshot-update-status') or 'UNKNOWN'}")
PY

# shellcheck disable=SC1090
source "$EVIDENCE_DIR/bootloader-summary.env"
cat "$EVIDENCE_DIR/bootloader-summary.env"

[[ "$BOOTLOADER_CURRENT_SLOT" == a || "$BOOTLOADER_CURRENT_SLOT" == b ]] || fail "bootloader_current_slot_unknown"
[[ "$BOOTLOADER_CURRENT_SLOT" == "$ADB_CURRENT_SLOT" ]] || fail "slot_changed_between_adb_and_bootloader"
[[ "$BOOTLOADER_UNLOCKED" == yes ]] || fail "bootloader_not_unlocked_do_not_unlock"
[[ "$BOOTLOADER_IS_USERSPACE" == no || "$BOOTLOADER_IS_USERSPACE" == yes ]] || fail "bootloader_mode_unknown"

if [[ "$BOOTLOADER_IS_USERSPACE" == no ]]; then
  echo "N1D_C3B_E5A_FASTBOOT_REBOOT_FASTBOOTD=AUTHORIZED_AND_RUNNING"
  timeout "$COMMAND_TIMEOUT_SECONDS" "${FASTBOOT[@]}" reboot fastboot
  resolved_after_fastbootd="$(resolve_fastboot_serial "$FASTBOOT_SERIAL")" ||
    fail "wait_for_fastbootd"
  [[ "$resolved_after_fastbootd" == "$FASTBOOT_SERIAL" ]] ||
    fail "fastboot_serial_changed_during_transition"
fi

collect_getvar all > "$EVIDENCE_DIR/fastbootd-getvar-all.txt"

GETVARS=(
  current-slot
  is-userspace
  unlocked
  secure
  product
  slot-count
  snapshot-update-status
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
  has-slot:system_ext
  has-slot:product
  has-slot:vendor
  has-slot:odm
  has-slot:system_dlkm
  has-slot:vendor_dlkm
  has-slot:odm_dlkm
)

: > "$EVIDENCE_DIR/fastbootd-getvar-selected.txt"
for key in "${GETVARS[@]}"; do
  {
    echo "===== $key ====="
    collect_getvar "$key"
  } >> "$EVIDENCE_DIR/fastbootd-getvar-selected.txt"
done

python3 - \
  "$EVIDENCE_DIR/fastbootd-getvar-all.txt" \
  "$EVIDENCE_DIR/fastbootd-getvar-selected.txt" \
  "$PLANNED_SYSTEM_TARGET_BYTES" \
  "$MIN_REMAINING_HEADROOM_BYTES" \
  "$EVIDENCE_DIR/fastbootd-sizing.json" <<'PY' > "$EVIDENCE_DIR/fastbootd-summary.env"
from __future__ import annotations
import json
import pathlib
import re
import sys

paths = [pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])]
target = int(sys.argv[3])
minimum_remaining = int(sys.argv[4])
json_out = pathlib.Path(sys.argv[5])
text = "\n".join(p.read_text(errors="replace") for p in paths)

def normalize_lines(raw: str):
    for line in raw.splitlines():
        line = re.sub(r"^\s*\([^)]*\)\s*", "", line.strip())
        if line:
            yield line

values: dict[str, str] = {}
for line in normalize_lines(text):
    m = re.match(r"^(.+):\s*([^:]+)$", line)
    if not m:
        continue
    key = m.group(1).strip()
    value = m.group(2).strip()
    values.setdefault(key, value)

def get(key: str) -> str:
    return values.get(key, "")

def as_int(value: str) -> int:
    value = value.strip().split()[0] if value.strip() else ""
    try:
        return int(value, 0)
    except ValueError:
        return 0

slot = get("current-slot").lstrip("_")
is_userspace = get("is-userspace")
unlocked = get("unlocked")
secure = get("secure")
snapshot = get("snapshot-update-status") or "UNKNOWN"
super_bytes = as_int(get("partition-size:super"))

bases = ["system", "system_ext", "product", "vendor", "odm", "system_dlkm", "vendor_dlkm", "odm_dlkm"]
per_base: dict[str, dict[str, object]] = {}
active_total = 0
fallback_all_slots_total = 0
complete_all_slot_evidence = True

for base in bases:
    unsuffixed = as_int(get(f"partition-size:{base}"))
    a = as_int(get(f"partition-size:{base}_a"))
    b = as_int(get(f"partition-size:{base}_b"))
    has_slot = get(f"has-slot:{base}").lower()
    active = as_int(get(f"partition-size:{base}_{slot}")) if slot in {"a", "b"} else 0
    active = active or unsuffixed or max(a, b)

    if has_slot == "yes":
        complete = a > 0 and b > 0
        all_slots = a + b if complete else 0
    elif has_slot == "no":
        complete = unsuffixed > 0 or active > 0
        all_slots = unsuffixed or active
    elif a or b:
        complete = a > 0 and b > 0
        all_slots = a + b if complete else 0
    elif unsuffixed:
        complete = True
        all_slots = unsuffixed
    else:
        complete = True
        all_slots = 0

    if not complete:
        complete_all_slot_evidence = False

    per_base[base] = {
        "has_slot": has_slot or "UNKNOWN",
        "unsuffixed": unsuffixed,
        "a": a,
        "b": b,
        "active": active,
        "all_slots": all_slots,
        "complete": complete,
    }
    active_total += active
    fallback_all_slots_total += all_slots

logical_names = {
    key.split(":", 1)[1]
    for key, value in values.items()
    if key.startswith("is-logical:") and value.lower() == "yes"
}
deduped_logical_names = set(logical_names)
for name in list(logical_names):
    if not (name.endswith("_a") or name.endswith("_b")):
        if f"{name}_a" in logical_names or f"{name}_b" in logical_names:
            deduped_logical_names.discard(name)

reported_logical_sizes = {
    name: as_int(get(f"partition-size:{name}"))
    for name in sorted(deduped_logical_names)
}
reported_logical_complete = bool(reported_logical_sizes) and all(
    size > 0 for size in reported_logical_sizes.values()
)

if reported_logical_complete:
    all_slots_total = sum(reported_logical_sizes.values())
    allocation_basis = "GETVAR_ALL_LOGICAL_PARTITIONS_COMPLETE"
    allocation_complete = True
elif complete_all_slot_evidence and fallback_all_slots_total > 0:
    all_slots_total = fallback_all_slots_total
    allocation_basis = "KNOWN_FAMILY_COMPLETE_FALLBACK"
    allocation_complete = True
else:
    all_slots_total = 0
    allocation_basis = "INCOMPLETE"
    allocation_complete = False

system_current = int(per_base["system"]["active"])
growth = max(0, target - system_current)
headroom_all_slots = super_bytes - all_slots_total if super_bytes and allocation_complete else 0
remaining_after_growth = headroom_all_slots - growth if headroom_all_slots else 0

snapshot_safe = snapshot.lower() in {"none", "no", "idle", "cancelled", "canceled"}
snapshot_review = snapshot == "UNKNOWN"
capacity_safe = (
    super_bytes > 0
    and system_current > 0
    and all_slots_total > 0
    and allocation_complete
    and headroom_all_slots >= 0
    and remaining_after_growth >= minimum_remaining
)

if is_userspace != "yes":
    classification = "BLOCKED_NOT_FASTBOOTD"
elif unlocked != "yes":
    classification = "BLOCKED_BOOTLOADER_NOT_UNLOCKED"
elif not capacity_safe:
    classification = "BLOCKED_FRESH_CAPACITY_INSUFFICIENT_OR_UNKNOWN"
elif snapshot_safe:
    classification = "PASS_REVIEW_READY"
elif snapshot_review:
    classification = "PASS_REVIEW_READY_SNAPSHOT_STATUS_REQUIRES_ADB_EVIDENCE_REVIEW"
else:
    classification = "BLOCKED_SNAPSHOT_OR_UPDATE_STATE_ACTIVE"

result = {
    "schema": 1,
    "phase": "N1D_C3B_E5A_READONLY_DEVICE_STATE",
    "current_slot": slot,
    "is_userspace": is_userspace,
    "unlocked": unlocked,
    "secure": secure,
    "snapshot_update_status": snapshot,
    "super_bytes": super_bytes,
    "partition_sizes": per_base,
    "active_selected_dynamic_total_bytes": active_total,
    "reported_logical_partition_names": sorted(deduped_logical_names),
    "reported_logical_partition_count": len(deduped_logical_names),
    "all_slots_reported_dynamic_total_bytes": all_slots_total,
    "allocation_basis": allocation_basis,
    "allocation_complete": allocation_complete,
    "complete_all_slot_evidence": complete_all_slot_evidence,
    "fresh_super_headroom_all_slots_estimate_bytes": headroom_all_slots,
    "system_current_bytes": system_current,
    "planned_system_target_bytes": target,
    "planned_system_growth_bytes": growth,
    "remaining_headroom_after_planned_growth_bytes": remaining_after_growth,
    "minimum_remaining_headroom_bytes": minimum_remaining,
    "capacity_safe": capacity_safe,
    "classification": classification,
    "flash_authorized": False,
    "lp_mutation_authorized": False,
    "avb_mutation_authorized": False,
    "slot_mutation_authorized": False,
}
json_out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")

print(f"FASTBOOTD_CURRENT_SLOT={slot or 'UNKNOWN'}")
print(f"FASTBOOTD_IS_USERSPACE={is_userspace or 'UNKNOWN'}")
print(f"FASTBOOTD_UNLOCKED={unlocked or 'UNKNOWN'}")
print(f"FASTBOOTD_SECURE={secure or 'UNKNOWN'}")
print(f"FASTBOOTD_SNAPSHOT_UPDATE_STATUS={snapshot}")
print(f"FASTBOOTD_SYSTEM_CURRENT_BYTES={system_current}")
print(f"FASTBOOTD_SUPER_BYTES={super_bytes}")
print(f"FASTBOOTD_ACTIVE_SELECTED_DYNAMIC_TOTAL_BYTES={active_total}")
print(f"FASTBOOTD_LOGICAL_NAME_COUNT={len(deduped_logical_names)}")
print(f"FASTBOOTD_ALLOCATION_BASIS={allocation_basis}")
print(f"FASTBOOTD_ALLOCATION_COMPLETE={'YES' if allocation_complete else 'NO'}")
print(f"FASTBOOTD_COMPLETE_ALL_SLOT_EVIDENCE={'YES' if complete_all_slot_evidence else 'NO'}")
print(f"FASTBOOTD_ALL_SLOTS_REPORTED_DYNAMIC_TOTAL_BYTES={all_slots_total}")
print(f"FASTBOOTD_FRESH_SUPER_HEADROOM_ALL_SLOTS_ESTIMATE_BYTES={headroom_all_slots}")
print(f"FASTBOOTD_PLANNED_SYSTEM_TARGET_BYTES={target}")
print(f"FASTBOOTD_PLANNED_SYSTEM_GROWTH_BYTES={growth}")
print(f"FASTBOOTD_REMAINING_HEADROOM_AFTER_PLANNED_GROWTH_BYTES={remaining_after_growth}")
print(f"FASTBOOTD_CAPACITY_SAFE={'YES' if capacity_safe else 'NO'}")
print(f"E5A_FASTBOOTD_CLASSIFICATION={classification}")
PY

# shellcheck disable=SC1090
source "$EVIDENCE_DIR/fastbootd-summary.env"
cat "$EVIDENCE_DIR/fastbootd-summary.env"

[[ "$FASTBOOTD_CURRENT_SLOT" == "$ADB_CURRENT_SLOT" ]] || fail "slot_changed_between_adb_and_fastbootd"
[[ "$FASTBOOTD_IS_USERSPACE" == yes ]] || fail "final_mode_not_fastbootd"
[[ "$FASTBOOTD_UNLOCKED" == yes ]] || fail "fastbootd_not_unlocked"
[[ "$FASTBOOTD_SYSTEM_CURRENT_BYTES" =~ ^[1-9][0-9]*$ ]] || fail "fresh_system_size_missing"
[[ "$FASTBOOTD_SUPER_BYTES" =~ ^[1-9][0-9]*$ ]] || fail "fresh_super_size_missing"

lpdump_status=REVIEW_NOT_AVAILABLE
if [[ -s "$EVIDENCE_DIR/lpdump.txt" ]]; then
  lpdump_status=PASS_CAPTURED
fi
echo "N1D_C3B_E5A_LPDUMP=$lpdump_status"

snapshot_adb_status=REVIEW
if grep -Eqi 'no snapshots|none|idle|state[^[:alnum:]]*(none|idle)|snapshots[^[:alnum:]]*0' "$EVIDENCE_DIR/snapshotctl-status.txt"; then
  snapshot_adb_status=PASS_IDLE_OR_NONE
elif grep -Eqi 'merge|merging|snapshotted|initiated|ready' "$EVIDENCE_DIR/snapshotctl-status.txt"; then
  snapshot_adb_status=BLOCK_ACTIVE
fi
echo "N1D_C3B_E5A_ADB_SNAPSHOT_STATE=$snapshot_adb_status"

update_engine_status=REVIEW
if grep -Eqi 'IDLE|UPDATED_NEED_REBOOT|CURRENT_OP[^[:alnum:]]*0' "$EVIDENCE_DIR/update-engine.txt"; then
  update_engine_status=PASS_IDLE_OR_COMPLETE
elif grep -Eqi 'DOWNLOADING|VERIFYING|FINALIZING|MERGING|UPDATED_BUT_NOT_ACTIVE' "$EVIDENCE_DIR/update-engine.txt"; then
  update_engine_status=BLOCK_ACTIVE
fi
echo "N1D_C3B_E5A_UPDATE_ENGINE_STATE=$update_engine_status"

final_state="$E5A_FASTBOOTD_CLASSIFICATION"
if [[ "$final_state" == PASS_REVIEW_READY_SNAPSHOT_STATUS_REQUIRES_ADB_EVIDENCE_REVIEW &&
      "$snapshot_adb_status" == PASS_IDLE_OR_NONE &&
      "$update_engine_status" == PASS_IDLE_OR_COMPLETE ]]; then
  final_state=PASS_REVIEW_READY
fi
if [[ "$ADB_BATTERY_SANITY" != PASS ]]; then
  final_state="BLOCKED_BATTERY_NOT_READY_FOR_FUTURE_MUTATION"
fi
if [[ "$snapshot_adb_status" == BLOCK_ACTIVE || "$update_engine_status" == BLOCK_ACTIVE ]]; then
  final_state="BLOCKED_ACTIVE_SNAPSHOT_OR_UPDATE"
fi

python3 - \
  "$EVIDENCE_DIR" \
  "$serial_binding_sha256" \
  "$final_state" \
  "$actual_system_sha" \
  "$actual_system_bytes" \
  "$JSON_OUT" <<'PY'
from __future__ import annotations
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
serial_hash = sys.argv[2]
final_state = sys.argv[3]
system_sha = sys.argv[4]
system_bytes = int(sys.argv[5])
out = pathlib.Path(sys.argv[6])

def env_file(name: str) -> dict[str, str]:
    result = {}
    path = root / name
    if not path.exists():
        return result
    for line in path.read_text(errors="replace").splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            result[k] = v
    return result

result = {
    "schema": 1,
    "phase": "N1D_C3B_E5A_READONLY_DEVICE_STATE",
    "device": "titan2",
    "adb_device_binding_sha256": serial_hash,
    "device_binding_method": "CONTROLLED_SINGLE_DEVICE_MODE_TRANSITION",
    "sealed_system_sha256": system_sha,
    "sealed_system_bytes": system_bytes,
    "adb": env_file("adb-summary.env"),
    "bootloader": env_file("bootloader-summary.env"),
    "fastbootd": env_file("fastbootd-summary.env"),
    "lpdump_captured": (root / "lpdump.txt").exists() and (root / "lpdump.txt").stat().st_size > 0,
    "device_contact_authorized": "YES_READ_ONLY_E5A",
    "reboot_bootloader_authorized": "YES",
    "reboot_fastbootd_authorized": "YES",
    "flash_authorized": "NO",
    "erase_authorized": "NO",
    "lp_mutation_authorized": "NO",
    "avb_mutation_authorized": "NO",
    "slot_mutation_authorized": "NO",
    "unlock_lock_authorized": "NO",
    "factory_reset_authorized": "NO",
    "custom_boot_authorized": "NO",
    "final_device_mode": "FASTBOOTD",
    "reboot_back_to_android": "NO_NOT_AUTHORIZED",
    "final_state": final_state,
}
out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

echo "N1D_C3B_E5A_FLASH_AUTHORIZED=NO"
echo "N1D_C3B_E5A_ERASE_AUTHORIZED=NO"
echo "N1D_C3B_E5A_LP_MUTATION_AUTHORIZED=NO"
echo "N1D_C3B_E5A_AVB_MUTATION_AUTHORIZED=NO"
echo "N1D_C3B_E5A_SLOT_MUTATION_AUTHORIZED=NO"
echo "N1D_C3B_E5A_UNLOCK_LOCK_AUTHORIZED=NO"
echo "N1D_C3B_E5A_FACTORY_RESET_AUTHORIZED=NO"
echo "N1D_C3B_E5A_CUSTOM_BOOT_AUTHORIZED=NO"
echo "N1D_C3B_E5A_FINAL_DEVICE_MODE=FASTBOOTD"
echo "N1D_C3B_E5A_REBOOT_BACK_TO_ANDROID=NO_NOT_AUTHORIZED"
echo "N1D_C3B_E5A_EVIDENCE_JSON=$JSON_OUT"
echo "N1D_C3B_E5A_EVIDENCE_DIR=$EVIDENCE_DIR"
echo "N1D_C3B_E5A_READONLY_DEVICE_STATE=$final_state"

case "$final_state" in
  PASS_REVIEW_READY|PASS_REVIEW_READY_SNAPSHOT_STATUS_REQUIRES_ADB_EVIDENCE_REVIEW)
    exit 0
    ;;
  *)
    exit 4
    ;;
esac
