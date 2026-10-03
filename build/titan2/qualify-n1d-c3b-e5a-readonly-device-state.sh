#!/usr/bin/env bash
set -euo pipefail

PHASE10A_JSON=""
PHASE10B_JSON=""
PHASE11_JSON=""
ADB_EXTRA_DIR=""
DEVICE_BINDING_SHA256=""
SYSTEM_IMAGE=""
OUTPUT_JSON=""
EXPECTED_SYSTEM_SHA256="998a8b99cd4d1a631006291a96c6f0160c5a4400c4bf6bba62c319c4ed3c82a5"
EXPECTED_SYSTEM_BYTES=2994405376
EXPECTED_STOCK_FINGERPRINT="Unihertz/Titan_2/Titan_2:16/BP2A.250605.031.A3/V01.00.14:user/release-keys"
EXPECTED_STOCK_INCREMENTAL="V01.00.14"
PLANNED_SYSTEM_TARGET_BYTES=3263168512
MIN_REMAINING_HEADROOM_BYTES=536870912
MIN_FUTURE_MUTATION_BATTERY_PERCENT=50

usage() {
  cat >&2 <<'USAGE'
usage:
  bash build/titan2/qualify-n1d-c3b-e5a-readonly-device-state.sh \
    --phase10a-json PATH \
    --phase10b-json PATH \
    --phase11-json PATH \
    --adb-extra-dir DIR \
    --device-binding-sha256 SHA256 \
    --system-image PATH \
    --output-json PATH

Offline-only qualifier for E5A evidence. It never runs adb or fastboot.
USAGE
}

while (($#)); do
  case "$1" in
    --phase10a-json) PHASE10A_JSON="$2"; shift 2 ;;
    --phase10b-json) PHASE10B_JSON="$2"; shift 2 ;;
    --phase11-json) PHASE11_JSON="$2"; shift 2 ;;
    --adb-extra-dir) ADB_EXTRA_DIR="$2"; shift 2 ;;
    --device-binding-sha256) DEVICE_BINDING_SHA256="$2"; shift 2 ;;
    --system-image) SYSTEM_IMAGE="$2"; shift 2 ;;
    --output-json) OUTPUT_JSON="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "N1D_C3B_E5A_QUALIFIER=FAIL_UNKNOWN_ARG" >&2; usage; exit 64 ;;
  esac
done

for pair in \
  "phase10a:$PHASE10A_JSON" \
  "phase10b:$PHASE10B_JSON" \
  "phase11:$PHASE11_JSON" \
  "system:$SYSTEM_IMAGE"; do
  name="${pair%%:*}"
  path="${pair#*:}"
  [[ -f "$path" ]] || { echo "N1D_C3B_E5A_QUALIFIER=FAIL_MISSING_FILE name=$name" >&2; exit 64; }
done
[[ -d "$ADB_EXTRA_DIR" ]] || { echo "N1D_C3B_E5A_QUALIFIER=FAIL_ADB_EXTRA_DIR" >&2; exit 64; }
[[ "$DEVICE_BINDING_SHA256" =~ ^[0-9a-f]{64}$ ]] || { echo "N1D_C3B_E5A_QUALIFIER=FAIL_DEVICE_BINDING" >&2; exit 64; }
[[ -n "$OUTPUT_JSON" ]] || { echo "N1D_C3B_E5A_QUALIFIER=FAIL_OUTPUT_JSON" >&2; exit 64; }
mkdir -p "$(dirname "$OUTPUT_JSON")"

actual_sha="$(sha256sum "$SYSTEM_IMAGE" | awk '{print $1}')"
actual_bytes="$(stat -c '%s' "$SYSTEM_IMAGE")"
[[ "$actual_sha" == "$EXPECTED_SYSTEM_SHA256" ]] || { echo "N1D_C3B_E5A_QUALIFIER=FAIL_SYSTEM_SHA" >&2; exit 1; }
[[ "$actual_bytes" == "$EXPECTED_SYSTEM_BYTES" ]] || { echo "N1D_C3B_E5A_QUALIFIER=FAIL_SYSTEM_BYTES" >&2; exit 1; }

python3 - \
  "$PHASE10A_JSON" \
  "$PHASE10B_JSON" \
  "$PHASE11_JSON" \
  "$ADB_EXTRA_DIR" \
  "$DEVICE_BINDING_SHA256" \
  "$actual_sha" \
  "$actual_bytes" \
  "$EXPECTED_STOCK_FINGERPRINT" \
  "$EXPECTED_STOCK_INCREMENTAL" \
  "$PLANNED_SYSTEM_TARGET_BYTES" \
  "$MIN_REMAINING_HEADROOM_BYTES" \
  "$MIN_FUTURE_MUTATION_BATTERY_PERCENT" \
  "$OUTPUT_JSON" <<'PY'
from __future__ import annotations

import json
import pathlib
import re
import sys
from typing import Any

p10a = pathlib.Path(sys.argv[1])
p10b = pathlib.Path(sys.argv[2])
p11 = pathlib.Path(sys.argv[3])
adb_extra = pathlib.Path(sys.argv[4])
device_hash = sys.argv[5]
system_sha = sys.argv[6]
system_bytes = int(sys.argv[7])
expected_fp = sys.argv[8]
expected_inc = sys.argv[9]
target = int(sys.argv[10])
minimum_remaining = int(sys.argv[11])
minimum_battery = int(sys.argv[12])
out = pathlib.Path(sys.argv[13])

def load(path: pathlib.Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))

def read(path: pathlib.Path) -> str:
    return path.read_text(errors="replace") if path.exists() else ""

def prop(text: str, name: str) -> str:
    m = re.search(rf"^\[{re.escape(name)}\]: \[(.*)\]$", text, re.M)
    return m.group(1).strip() if m else ""

def parse_battery(text: str) -> int:
    m = re.search(r"^\s*level:\s*([0-9]+)\s*$", text, re.M | re.I)
    return int(m.group(1)) if m else -1

def normalize_getvar(text: str) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in text.splitlines():
        line = re.sub(r"^\s*\([^)]*\)\s*", "", raw.strip())
        if not line:
            continue
        m = re.match(r"^(.+):\s*([^:]+)$", line)
        if m:
            values.setdefault(m.group(1).strip(), m.group(2).strip())
    return values

def as_int(value: str) -> int:
    token = value.strip().split()[0] if value.strip() else ""
    try:
        return int(token, 0)
    except ValueError:
        return 0

def classify_snapshot(snapshot_text: str, update_text: str, fastboot_snapshot: str) -> tuple[str, str]:
    combined = "\n".join([snapshot_text, update_text, fastboot_snapshot]).lower()
    active_terms = ("merging", "merge in progress", "downloading", "verifying", "finalizing", "updated_but_not_active", "snapshotted")
    if any(term in combined for term in active_terms):
        return "BLOCK_ACTIVE", "BLOCKED_ACTIVE_SNAPSHOT_OR_UPDATE"
    idle_terms = ("no snapshots", "idle", "current_op: 0", "current_op=0", "none")
    if any(term in combined for term in idle_terms):
        return "PASS_IDLE_OR_NONE", "PASS"
    return "REVIEW_UNKNOWN", "REVIEW"

j10a = load(p10a)
j10b = load(p10b)
j11 = load(p11)
meta10a = j10a.get("metadata", {})
meta10b = j10b.get("metadata", {})
meta11 = j11.get("metadata", {})

p10a_dir = p10a.parent
p10b_dir = p10b.parent
p11_dir = p11.parent
getprop = read(p10a_dir / "getprop.txt")
battery_text = read(adb_extra / "battery.txt")
snapshot_text = read(p10a_dir / "snapshotctl-status.txt")
update_text = read(p10a_dir / "update-engine.txt")
lpdump_text = read(adb_extra / "lpdump.txt")

fingerprint = str(meta10a.get("stock_baseline", "")) or prop(getprop, "ro.build.fingerprint")
incremental = prop(getprop, "ro.build.version.incremental")
vendor_fingerprint = prop(getprop, "ro.vendor.build.fingerprint")
adb_slot = str(meta10a.get("active_slot", "")).lstrip("_")
verified_boot = prop(getprop, "ro.boot.verifiedbootstate") or "UNKNOWN"
vbmeta_state = prop(getprop, "ro.boot.vbmeta.device_state") or "UNKNOWN"
flash_locked = prop(getprop, "ro.boot.flash.locked") or "UNKNOWN"
dynamic = prop(getprop, "ro.boot.dynamic_partitions") or "UNKNOWN"
virtual_ab = prop(getprop, "ro.virtual_ab.enabled") or "UNKNOWN"
battery = parse_battery(battery_text)

raw_getvar = "\n".join([
    read(p10b_dir / "final/getvar-all.txt"),
    read(p10b_dir / "final/getvar-selected.txt"),
    read(p11_dir / "getvar-all.txt"),
    read(p11_dir / "getvar-selected.txt"),
])
getvars = normalize_getvar(raw_getvar)
slot = (getvars.get("current-slot") or str(meta11.get("active_slot", ""))).lstrip("_")
is_userspace = getvars.get("is-userspace") or str(meta11.get("is_userspace", ""))
unlocked = getvars.get("unlocked") or str(meta11.get("unlocked", ""))
secure = getvars.get("secure") or str(meta11.get("secure", ""))
snapshot_fastboot = getvars.get("snapshot-update-status", "UNKNOWN")
super_bytes = as_int(getvars.get("partition-size:super", "")) or int(str(meta11.get("super_bytes", "0")) or 0)

families = ["system", "system_ext", "product", "vendor", "odm", "system_dlkm", "vendor_dlkm", "odm_dlkm"]
per_family: dict[str, dict[str, int]] = {}
fallback_all_slots_total = 0
active_total = 0
for base in families:
    unsuffixed = as_int(getvars.get(f"partition-size:{base}", ""))
    a = as_int(getvars.get(f"partition-size:{base}_a", ""))
    b = as_int(getvars.get(f"partition-size:{base}_b", ""))
    active = as_int(getvars.get(f"partition-size:{base}_{slot}", "")) if slot in {"a", "b"} else 0
    active = active or unsuffixed or max(a, b)
    all_slots = a + b if (a or b) else unsuffixed
    per_family[base] = {"unsuffixed": unsuffixed, "a": a, "b": b, "active": active, "all_slots": all_slots}
    active_total += active
    fallback_all_slots_total += all_slots

logical_names = {
    key.split(":", 1)[1]
    for key, value in getvars.items()
    if key.startswith("is-logical:") and value.lower() == "yes"
}
deduped = set(logical_names)
for name in list(logical_names):
    if not (name.endswith("_a") or name.endswith("_b")):
        if f"{name}_a" in logical_names or f"{name}_b" in logical_names:
            deduped.discard(name)
reported_logical_total = sum(as_int(getvars.get(f"partition-size:{name}", "")) for name in deduped)
if reported_logical_total > 0:
    allocated_total = reported_logical_total
    allocation_basis = "GETVAR_ALL_LOGICAL_PARTITIONS"
else:
    allocated_total = fallback_all_slots_total
    allocation_basis = "KNOWN_FAMILY_FALLBACK"

system_current = per_family["system"]["active"] or int(str(meta11.get("system_current_bytes", "0")) or 0)
growth = max(0, target - system_current)
fresh_headroom = super_bytes - allocated_total if super_bytes else 0
remaining = fresh_headroom - growth if super_bytes else 0
capacity_safe = super_bytes > 0 and system_current > 0 and allocated_total > 0 and fresh_headroom >= 0 and remaining >= minimum_remaining
snapshot_status, snapshot_class = classify_snapshot(snapshot_text, update_text, snapshot_fastboot)

failures: list[str] = []
reviews: list[str] = []
if fingerprint != expected_fp:
    failures.append("STOCK_FINGERPRINT_MISMATCH")
if incremental != expected_inc:
    failures.append("STOCK_INCREMENTAL_MISMATCH")
if adb_slot not in {"a", "b"} or slot not in {"a", "b"}:
    failures.append("CURRENT_SLOT_UNKNOWN")
elif adb_slot != slot:
    failures.append("SLOT_CHANGED_BETWEEN_ADB_AND_FASTBOOTD")
if is_userspace != "yes":
    failures.append("FINAL_MODE_NOT_FASTBOOTD")
if unlocked != "yes":
    failures.append("BOOTLOADER_NOT_UNLOCKED_DO_NOT_UNLOCK")
if not capacity_safe:
    failures.append("FRESH_CAPACITY_INSUFFICIENT_OR_UNKNOWN")
if snapshot_class.startswith("BLOCKED"):
    failures.append(snapshot_class)
elif snapshot_class == "REVIEW":
    reviews.append("SNAPSHOT_UPDATE_STATUS_REQUIRES_MANUAL_REVIEW")
if battery < 0:
    failures.append("BATTERY_LEVEL_UNKNOWN")
elif battery < minimum_battery:
    failures.append("BATTERY_BELOW_FUTURE_MUTATION_THRESHOLD")

if failures:
    final_state = "BLOCKED_" + failures[0]
elif reviews:
    final_state = "PASS_REVIEW_READY_SNAPSHOT_STATUS_REQUIRES_MANUAL_REVIEW"
else:
    final_state = "PASS_REVIEW_READY"

result = {
    "schema": 1,
    "phase": "N1D_C3B_E5A_READONLY_DEVICE_STATE",
    "device": "titan2",
    "device_binding_sha256": device_hash,
    "sealed_system_sha256": system_sha,
    "sealed_system_bytes": system_bytes,
    "stock": {
        "fingerprint": fingerprint,
        "incremental": incremental,
        "vendor_fingerprint": vendor_fingerprint,
        "fingerprint_match": fingerprint == expected_fp,
        "incremental_match": incremental == expected_inc,
    },
    "adb": {
        "current_slot": adb_slot,
        "verified_boot_state": verified_boot,
        "vbmeta_device_state": vbmeta_state,
        "flash_locked": flash_locked,
        "dynamic_partitions": dynamic,
        "virtual_ab": virtual_ab,
        "battery_percent": battery,
        "lpdump_captured": bool(lpdump_text.strip()),
    },
    "fastbootd": {
        "current_slot": slot,
        "is_userspace": is_userspace,
        "unlocked": unlocked,
        "secure": secure,
        "snapshot_update_status": snapshot_fastboot,
        "super_bytes": super_bytes,
        "partition_sizes": per_family,
        "active_selected_dynamic_total_bytes": active_total,
        "allocation_basis": allocation_basis,
        "all_slots_reported_dynamic_total_bytes": allocated_total,
        "fresh_super_headroom_all_slots_estimate_bytes": fresh_headroom,
        "system_current_bytes": system_current,
        "planned_system_target_bytes": target,
        "planned_system_growth_bytes": growth,
        "remaining_headroom_after_planned_growth_bytes": remaining,
        "minimum_remaining_headroom_bytes": minimum_remaining,
        "capacity_safe": capacity_safe,
    },
    "snapshot_update_review": snapshot_status,
    "failures": failures,
    "reviews": reviews,
    "device_contact_authorized": "YES_READ_ONLY_E5A",
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

print(f"N1D_C3B_E5A_DEVICE_BINDING_SHA256={device_hash}")
print(f"N1D_C3B_E5A_STOCK_FINGERPRINT_MATCH={'PASS' if fingerprint == expected_fp else 'FAIL'}")
print(f"N1D_C3B_E5A_STOCK_INCREMENTAL_MATCH={'PASS' if incremental == expected_inc else 'FAIL'}")
print(f"N1D_C3B_E5A_ADB_CURRENT_SLOT={adb_slot or 'UNKNOWN'}")
print(f"N1D_C3B_E5A_VERIFIED_BOOT_STATE={verified_boot}")
print(f"N1D_C3B_E5A_VBMETA_DEVICE_STATE={vbmeta_state}")
print(f"N1D_C3B_E5A_BATTERY_PERCENT={battery if battery >= 0 else 'UNKNOWN'}")
print(f"N1D_C3B_E5A_FASTBOOTD_CURRENT_SLOT={slot or 'UNKNOWN'}")
print(f"N1D_C3B_E5A_FASTBOOTD_IS_USERSPACE={is_userspace or 'UNKNOWN'}")
print(f"N1D_C3B_E5A_FASTBOOTD_UNLOCKED={unlocked or 'UNKNOWN'}")
print(f"N1D_C3B_E5A_SYSTEM_CURRENT_BYTES={system_current}")
print(f"N1D_C3B_E5A_SUPER_BYTES={super_bytes}")
print(f"N1D_C3B_E5A_ALLOCATION_BASIS={allocation_basis}")
print(f"N1D_C3B_E5A_ALL_SLOTS_REPORTED_DYNAMIC_TOTAL_BYTES={allocated_total}")
print(f"N1D_C3B_E5A_FRESH_SUPER_HEADROOM_BYTES={fresh_headroom}")
print(f"N1D_C3B_E5A_PLANNED_SYSTEM_TARGET_BYTES={target}")
print(f"N1D_C3B_E5A_PLANNED_SYSTEM_GROWTH_BYTES={growth}")
print(f"N1D_C3B_E5A_REMAINING_HEADROOM_AFTER_PLANNED_GROWTH_BYTES={remaining}")
print(f"N1D_C3B_E5A_CAPACITY_SAFE={'YES' if capacity_safe else 'NO'}")
print(f"N1D_C3B_E5A_SNAPSHOT_UPDATE_REVIEW={snapshot_status}")
for item in failures:
    print(f"N1D_C3B_E5A_FAILURE={item}")
for item in reviews:
    print(f"N1D_C3B_E5A_REVIEW={item}")
print("N1D_C3B_E5A_FLASH_AUTHORIZED=NO")
print("N1D_C3B_E5A_ERASE_AUTHORIZED=NO")
print("N1D_C3B_E5A_LP_MUTATION_AUTHORIZED=NO")
print("N1D_C3B_E5A_AVB_MUTATION_AUTHORIZED=NO")
print("N1D_C3B_E5A_SLOT_MUTATION_AUTHORIZED=NO")
print("N1D_C3B_E5A_UNLOCK_LOCK_AUTHORIZED=NO")
print("N1D_C3B_E5A_FACTORY_RESET_AUTHORIZED=NO")
print("N1D_C3B_E5A_CUSTOM_BOOT_AUTHORIZED=NO")
print("N1D_C3B_E5A_FINAL_DEVICE_MODE=FASTBOOTD")
print("N1D_C3B_E5A_REBOOT_BACK_TO_ANDROID=NO_NOT_AUTHORIZED")
print(f"N1D_C3B_E5A_EVIDENCE_JSON={out}")
print(f"N1D_C3B_E5A_READONLY_DEVICE_STATE={final_state}")

raise SystemExit(0 if final_state.startswith("PASS_REVIEW_READY") else 4)
PY
