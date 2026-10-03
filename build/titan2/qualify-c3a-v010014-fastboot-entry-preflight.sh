#!/usr/bin/env bash
set -euo pipefail

PHASE10B_JSON=""
PHASE11_JSON=""
PHASE11_GETVAR_ALL=""
PHASE11_GETVAR_SELECTED=""
OFFLINE_PLAN=""
BASELINE_E5B_JSON=""
FASTBOOT_BINDING_SHA256=""
OUTPUT_JSON=""

EXPECTED_C3A_SHA256="4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16"
EXPECTED_C3A_BYTES=3146977280
EXPECTED_SLOT="a"
EXPECTED_PRODUCT="Titan_2"
EXPECTED_SUPER_BYTES=9663676416
EXPECTED_BASELINE_E5B_SHA256="74531923a9ea6c755a9f8ea52db511c4a4a19a5d9dba3cb51da342c04b768926"
MINIMUM_REMAINING_HEADROOM_BYTES=536870912

usage() {
  cat >&2 <<'USAGE'
usage:
  bash build/titan2/qualify-c3a-v010014-fastboot-entry-preflight.sh \
    --phase10b-json PATH \
    --phase11-json PATH \
    --phase11-getvar-all PATH \
    --phase11-getvar-selected PATH \
    --offline-plan PATH \
    --baseline-e5b-json PATH \
    --fastboot-binding-sha256 SHA256 \
    --output-json PATH

Offline-only qualifier for the recovery/bootloop entry path.
It consumes fresh fastbootd evidence plus the already-sealed V01.00.14
baseline. It runs no adb or fastboot commands.
USAGE
}

while (($#)); do
  case "$1" in
    --phase10b-json) PHASE10B_JSON="$2"; shift 2 ;;
    --phase11-json) PHASE11_JSON="$2"; shift 2 ;;
    --phase11-getvar-all) PHASE11_GETVAR_ALL="$2"; shift 2 ;;
    --phase11-getvar-selected) PHASE11_GETVAR_SELECTED="$2"; shift 2 ;;
    --offline-plan) OFFLINE_PLAN="$2"; shift 2 ;;
    --baseline-e5b-json) BASELINE_E5B_JSON="$2"; shift 2 ;;
    --fastboot-binding-sha256) FASTBOOT_BINDING_SHA256="$2"; shift 2 ;;
    --output-json) OUTPUT_JSON="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "C3A_FASTBOOT_ENTRY_QUALIFIER=FAIL_UNKNOWN_ARG arg=$1" >&2; usage; exit 64 ;;
  esac
done

for pair in   "phase10b:$PHASE10B_JSON"   "phase11:$PHASE11_JSON"   "phase11_getvar_all:$PHASE11_GETVAR_ALL"   "offline_plan:$OFFLINE_PLAN"   "baseline_e5b:$BASELINE_E5B_JSON"
do
  name="${pair%%:*}"
  path="${pair#*:}"
  [[ -f "$path" ]] || {
    echo "C3A_FASTBOOT_ENTRY_QUALIFIER=FAIL_MISSING_FILE name=$name path=$path" >&2
    exit 64
  }
done

[[ "$FASTBOOT_BINDING_SHA256" =~ ^[0-9a-f]{64}$ ]] || {
  echo "C3A_FASTBOOT_ENTRY_QUALIFIER=FAIL_FASTBOOT_BINDING_SHA256" >&2
  exit 64
}
[[ -n "$OUTPUT_JSON" ]] || {
  echo "C3A_FASTBOOT_ENTRY_QUALIFIER=FAIL_OUTPUT_JSON" >&2
  exit 64
}
mkdir -p "$(dirname "$OUTPUT_JSON")"

baseline_e5b_sha="$(sha256sum "$BASELINE_E5B_JSON" | awk '{print $1}')"
[[ "$baseline_e5b_sha" == "$EXPECTED_BASELINE_E5B_SHA256" ]] || {
  echo "C3A_FASTBOOT_ENTRY_QUALIFIER=FAIL_BASELINE_E5B_SHA expected=$EXPECTED_BASELINE_E5B_SHA256 actual=$baseline_e5b_sha" >&2
  exit 64
}

python3 -   "$PHASE10B_JSON"   "$PHASE11_JSON"   "$PHASE11_GETVAR_ALL"   "$OFFLINE_PLAN"   "$BASELINE_E5B_JSON"   "$FASTBOOT_BINDING_SHA256"   "$OUTPUT_JSON"   "$EXPECTED_C3A_SHA256"   "$EXPECTED_C3A_BYTES"   "$EXPECTED_SLOT"   "$EXPECTED_PRODUCT"   "$EXPECTED_SUPER_BYTES"   "$MINIMUM_REMAINING_HEADROOM_BYTES" <<'PY'
from __future__ import annotations

import json
import pathlib
import re
import sys
from typing import Any

p10b = pathlib.Path(sys.argv[1])
p11 = pathlib.Path(sys.argv[2])
getvar_all_path = pathlib.Path(sys.argv[3])
getvar_selected_path = pathlib.Path(sys.argv[4])
plan_path = pathlib.Path(sys.argv[5])
baseline_path = pathlib.Path(sys.argv[6])
fastboot_binding_sha = sys.argv[7]
out = pathlib.Path(sys.argv[8])
expected_c3a_sha = sys.argv[9]
expected_c3a_bytes = int(sys.argv[10])
expected_slot = sys.argv[11]
expected_product = sys.argv[12]
expected_super = int(sys.argv[13])
minimum_remaining = int(sys.argv[14])

phase10b: dict[str, Any] = json.loads(p10b.read_text(encoding="utf-8"))
phase11: dict[str, Any] = json.loads(p11.read_text(encoding="utf-8"))
baseline: dict[str, Any] = json.loads(baseline_path.read_text(encoding="utf-8"))

def parse_env(path: pathlib.Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        result[key.strip()] = value.strip()
    return result

def normalize_getvar(text: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for raw in text.splitlines():
        line = re.sub(r"^\s*\([^)]*\)\s*", "", raw.strip())
        if not line:
            continue
        match = re.match(r"^(.+):\s*([^:]+)$", line)
        if match:
            result.setdefault(match.group(1).strip(), match.group(2).strip())
    return result

def parse_int(value: Any) -> int:
    if value is None:
        return 0
    token = str(value).strip().split()[0] if str(value).strip() else ""
    try:
        return int(token, 0)
    except ValueError:
        return 0

plan = parse_env(plan_path)
getvar_text = (
    getvar_all_path.read_text(encoding="utf-8", errors="replace")
    + "\n"
    + getvar_selected_path.read_text(encoding="utf-8", errors="replace")
)
values = normalize_getvar(getvar_text)

failures: list[str] = []

def require(condition: bool, marker: str) -> None:
    if not condition:
        failures.append(marker)

# Sealed offline authority.
require(plan.get("C3A_V010014_CONTROL_PLAN") == "PREPARED_NO_WRITE", "OFFLINE_PLAN_STATE_INVALID")
require(plan.get("C3A_SYSTEM_SHA256") == expected_c3a_sha, "OFFLINE_C3A_SHA_MISMATCH")
require(parse_int(plan.get("C3A_SYSTEM_LOGICAL_BYTES")) == expected_c3a_bytes, "OFFLINE_C3A_BYTES_MISMATCH")
require(plan.get("CURRENT_STOCK_INCREMENTAL") == "V01.00.14", "OFFLINE_STOCK_INCREMENTAL_MISMATCH")
require(plan.get("EXPECTED_ACTIVE_SLOT") == expected_slot, "OFFLINE_SLOT_MISMATCH")
require(plan.get("EXPECTED_FASTBOOT_PRODUCT") == expected_product, "OFFLINE_PRODUCT_MISMATCH")
require(parse_int(plan.get("EXPECTED_SUPER_BYTES")) == expected_super, "OFFLINE_SUPER_MISMATCH")
require(plan.get("EXPECTED_FASTBOOT_BINDING_SHA256") == fastboot_binding_sha, "FASTBOOT_DEVICE_BINDING_CHANGED")
require(plan.get("FLASH_AUTHORIZED") == "NO", "OFFLINE_FLASH_BOUNDARY_VIOLATED")
require(plan.get("FACTORY_RESET_AUTHORIZED") == "NO", "OFFLINE_RESET_BOUNDARY_VIOLATED")

# Fresh Phase-10B / Phase-11 identity.
m10 = phase10b.get("metadata") or {}
m11 = phase11.get("metadata") or {}
require(str(m10.get("explicit_titan_serial", "")).strip() != "", "PHASE10B_SERIAL_MISSING")
require(str(m11.get("explicit_titan_serial", "")).strip() != "", "PHASE11_SERIAL_MISSING")
require(m10.get("explicit_titan_serial") == m11.get("explicit_titan_serial"), "FASTBOOT_SERIAL_CHANGED_BETWEEN_PHASES")

current_slot = (values.get("current-slot") or str(m11.get("active_slot", ""))).lstrip("_")
is_userspace = values.get("is-userspace") or str(m11.get("is_userspace", ""))
unlocked = values.get("unlocked") or str(m11.get("unlocked", ""))
product = values.get("product") or str(m11.get("product", ""))
snapshot_status = (values.get("snapshot-update-status") or "").lower()
super_bytes = parse_int(values.get("partition-size:super")) or parse_int(m11.get("super_bytes"))

require(current_slot == expected_slot, "CURRENT_SLOT_NOT_A")
require(is_userspace == "yes", "NOT_USERSPACE_FASTBOOTD")
require(unlocked == "yes", "BOOTLOADER_NOT_UNLOCKED")
require(product == expected_product, "FASTBOOT_PRODUCT_MISMATCH")
require(snapshot_status == "none", "FASTBOOT_SNAPSHOT_UPDATE_STATUS_NOT_NONE")
require(super_bytes == expected_super, "SUPER_BYTES_MISMATCH")

# Fresh logical-partition inventory from fastbootd getvar all.
logical_names = {
    key.split(":", 1)[1]
    for key, value in values.items()
    if key.startswith("is-logical:") and value.lower() == "yes"
}
logical_sizes = {
    name: parse_int(values.get(f"partition-size:{name}", ""))
    for name in logical_names
}
require(bool(logical_names), "LOGICAL_PARTITION_INVENTORY_EMPTY")
require(all(size > 0 for size in logical_sizes.values()), "LOGICAL_PARTITION_INVENTORY_INCOMPLETE")
require("system_a" in logical_names, "SYSTEM_A_NOT_REPORTED_LOGICAL")

system_current = logical_sizes.get("system_a", 0)
require(system_current > 0, "SYSTEM_A_SIZE_MISSING")

# Active-slot COWs must be absent; unlike the historical N1B path this control
# does not authorize cleanup as part of preflight.
cow_suffix = f"_{expected_slot}-cow"
cow_names = {
    name for name in logical_names if name.endswith(cow_suffix)
}
for key, value in values.items():
    if not key.startswith("partition-size:"):
        continue
    name = key.split(":", 1)[1]
    if name.endswith(cow_suffix) and parse_int(value) > 0:
        cow_names.add(name)
active_cows = {
    name: parse_int(values.get(f"partition-size:{name}", ""))
    for name in sorted(cow_names)
}
require(all(size > 0 for size in active_cows.values()), "ACTIVE_COW_SIZE_INCOMPLETE")
require(len(active_cows) == 0, "ACTIVE_COW_COUNT_NOT_ZERO")

# Group topology/max and whole-super baseline come from the sealed pre-N1D
# V01.00.14 E5B package. Fresh sizes are read from fastbootd. This avoids
# treating a device that omits some is-logical:* keys as if those partitions
# consume zero bytes.
baseline_group = str(baseline.get("active_group", ""))
baseline_cows = baseline.get("active_cow_partitions") or {}
baseline_group_max = parse_int(baseline.get("active_group_maximum_bytes"))
baseline_group_current = parse_int(baseline.get("active_group_current_bytes"))
baseline_allocated_total = parse_int(baseline.get("all_materialized_logical_bytes"))
baseline_members_raw = baseline.get("active_group_members") or {}
baseline_members = list(baseline_members_raw.keys()) if isinstance(baseline_members_raw, dict) else []

require(isinstance(baseline_cows, dict) and len(baseline_cows) == 0, "BASELINE_ACTIVE_COW_NOT_ZERO")
require(str(baseline.get("current_slot", "")).lstrip("_") == expected_slot, "BASELINE_GROUP_SLOT_MISMATCH")
require(baseline.get("target_system_partition") == "system_a", "BASELINE_TARGET_NOT_SYSTEM_A")
require(baseline_group == "main_a", "BASELINE_ACTIVE_GROUP_MISMATCH")
require(baseline_group_max > 0, "BASELINE_ACTIVE_GROUP_MAXIMUM_MISSING")
require(baseline_group_current > 0, "BASELINE_ACTIVE_GROUP_CURRENT_MISSING")
require(baseline_allocated_total > 0, "BASELINE_ALLOCATED_TOTAL_MISSING")
require("system_a" in baseline_members, "BASELINE_SYSTEM_A_NOT_IN_ACTIVE_GROUP")
require(bool(baseline_members), "BASELINE_ACTIVE_GROUP_MEMBERS_EMPTY")

fresh_group_sizes = {
    name: parse_int(values.get(f"partition-size:{name}", ""))
    for name in baseline_members
}
require(all(size > 0 for size in fresh_group_sizes.values()), "FRESH_ACTIVE_GROUP_MEMBER_SIZE_INCOMPLETE")
fresh_group_current = sum(fresh_group_sizes.values()) if fresh_group_sizes else 0
fresh_group_prospective = fresh_group_current - system_current + expected_c3a_bytes
group_capacity_safe = baseline_group_max > 0 and fresh_group_prospective <= baseline_group_max
require(group_capacity_safe, "ACTIVE_GROUP_CAPACITY_NOT_SAFE")

# Only system_a was written in the failed N1D experiment. Rebase the sealed
# whole-super allocation by the fresh active-group delta, then calculate the
# C3A target. Any active COW is already a hard failure above.
allocated_total = baseline_allocated_total + (fresh_group_current - baseline_group_current)
growth = max(0, expected_c3a_bytes - system_current)
fresh_headroom = expected_super - allocated_total
remaining = fresh_headroom - growth
super_capacity_safe = remaining >= minimum_remaining
require(super_capacity_safe, "TOTAL_SUPER_CAPACITY_NOT_SAFE")

state = "PASS_READY_FOR_PHYSICAL_CONTROL_REVIEW" if not failures else "BLOCKED_" + failures[0]
result = {
    "schema": 1,
    "phase": "C3A_V010014_FASTBOOT_ENTRY_PREFLIGHT",
    "entry_state": "FASTBOOT_OR_FASTBOOTD_FROM_N1D_BOOTLOOP",
    "sealed_stock_incremental": plan.get("CURRENT_STOCK_INCREMENTAL", ""),
    "sealed_stock_fingerprint": plan.get("SEALED_STOCK_FINGERPRINT", ""),
    "sealed_vendor_fingerprint": plan.get("SEALED_VENDOR_FINGERPRINT", ""),
    "fastboot_device_binding_sha256": fastboot_binding_sha,
    "current_slot": current_slot,
    "is_userspace": is_userspace,
    "unlocked": unlocked,
    "product": product,
    "snapshot_update_status": snapshot_status,
    "super_bytes": super_bytes,
    "logical_partition_names": sorted(logical_names),
    "baseline_materialized_logical_bytes": baseline_allocated_total,
    "materialized_logical_bytes_estimate_from_sealed_baseline_plus_fresh_group_delta": allocated_total,
    "system_a_current_bytes": system_current,
    "c3a_target_bytes": expected_c3a_bytes,
    "system_growth_bytes": growth,
    "fresh_super_headroom_bytes": fresh_headroom,
    "remaining_headroom_after_growth_bytes": remaining,
    "minimum_remaining_headroom_bytes": minimum_remaining,
    "super_capacity_safe": super_capacity_safe,
    "active_cow_partitions": active_cows,
    "active_cow_count": len(active_cows),
    "active_group": baseline_group,
    "active_group_maximum_bytes": baseline_group_max,
    "active_group_members": fresh_group_sizes,
    "active_group_current_bytes": fresh_group_current,
    "active_group_prospective_bytes": fresh_group_prospective,
    "active_group_capacity_safe": group_capacity_safe,
    "failures": failures,
    "flash_authorized": False,
    "factory_reset_authorized": False,
    "lp_mutation_authorized": False,
    "cow_cleanup_authorized": False,
    "avb_mutation_authorized": False,
    "slot_mutation_authorized": False,
    "write_capable_script_created": False,
    "final_state": state,
}
out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")

print(f"C3A_FASTBOOT_ENTRY_CURRENT_SLOT={current_slot}")
print(f"C3A_FASTBOOT_ENTRY_IS_USERSPACE={is_userspace}")
print(f"C3A_FASTBOOT_ENTRY_UNLOCKED={unlocked}")
print(f"C3A_FASTBOOT_ENTRY_PRODUCT={product}")
print(f"C3A_FASTBOOT_ENTRY_SNAPSHOT_UPDATE_STATUS={snapshot_status or 'UNKNOWN'}")
print(f"C3A_FASTBOOT_ENTRY_SYSTEM_A_CURRENT_BYTES={system_current}")
print(f"C3A_FASTBOOT_ENTRY_C3A_TARGET_BYTES={expected_c3a_bytes}")
print(f"C3A_FASTBOOT_ENTRY_SYSTEM_GROWTH_BYTES={growth}")
print(f"C3A_FASTBOOT_ENTRY_ACTIVE_COW_COUNT={len(active_cows)}")
print(f"C3A_FASTBOOT_ENTRY_MATERIALIZED_LOGICAL_BYTES={allocated_total}")
print(f"C3A_FASTBOOT_ENTRY_FRESH_SUPER_HEADROOM_BYTES={fresh_headroom}")
print(f"C3A_FASTBOOT_ENTRY_REMAINING_HEADROOM_BYTES={remaining}")
print(f"C3A_FASTBOOT_ENTRY_SUPER_CAPACITY_SAFE={'YES' if super_capacity_safe else 'NO'}")
print(f"C3A_FASTBOOT_ENTRY_ACTIVE_GROUP={baseline_group}")
print(f"C3A_FASTBOOT_ENTRY_ACTIVE_GROUP_MAXIMUM_BYTES={baseline_group_max}")
print(f"C3A_FASTBOOT_ENTRY_ACTIVE_GROUP_PROSPECTIVE_BYTES={fresh_group_prospective}")
print(f"C3A_FASTBOOT_ENTRY_ACTIVE_GROUP_CAPACITY_SAFE={'YES' if group_capacity_safe else 'NO'}")
for item in failures:
    print(f"C3A_FASTBOOT_ENTRY_PREFLIGHT_FAILURE={item}")
print("C3A_FASTBOOT_ENTRY_FLASH_AUTHORIZED=NO")
print("C3A_FASTBOOT_ENTRY_FACTORY_RESET_AUTHORIZED=NO")
print("C3A_FASTBOOT_ENTRY_LP_MUTATION_AUTHORIZED=NO")
print("C3A_FASTBOOT_ENTRY_COW_CLEANUP_AUTHORIZED=NO")
print("C3A_FASTBOOT_ENTRY_AVB_MUTATION_AUTHORIZED=NO")
print("C3A_FASTBOOT_ENTRY_SLOT_MUTATION_AUTHORIZED=NO")
print("C3A_FASTBOOT_ENTRY_WRITE_CAPABLE_SCRIPT_CREATED=NO")
print(f"C3A_FASTBOOT_ENTRY_PREFLIGHT_JSON={out}")
print(f"C3A_FASTBOOT_ENTRY_PREFLIGHT={state}")
raise SystemExit(0 if not failures else 4)
PY
