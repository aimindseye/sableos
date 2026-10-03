#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
E5A_EVIDENCE_DIR="/srv/sable-build/evidence/titan2/n1d-c3b-e5a-readonly-device-state/20261003T053441Z"
E5A_JSON=""
OUTPUT_JSON=""

usage() {
  cat <<'EOF'
usage:
  bash build/titan2/prepare-n1d-c3b-e5b-authorization-package.sh \
    [--e5a-evidence-dir DIR] \
    [--e5a-json PATH] \
    [--output-json PATH]

Offline-only Titan 2 E5B decision-package preparation.
It reads the sealed E5A evidence and historical Titan 2 deployment model.
It performs no device command and no mutation.
EOF
}

while (($#)); do
  case "$1" in
    --e5a-evidence-dir) E5A_EVIDENCE_DIR="$2"; shift 2 ;;
    --e5a-json) E5A_JSON="$2"; shift 2 ;;
    --output-json) OUTPUT_JSON="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "N1D_C3B_E5B_AUTH_PACKAGE=FAIL_UNKNOWN_ARG arg=$1" >&2; usage >&2; exit 64 ;;
  esac
done

[[ -n "$E5A_JSON" ]] || E5A_JSON="$E5A_EVIDENCE_DIR/e5a-readonly-device-state.json"
[[ -n "$OUTPUT_JSON" ]] || OUTPUT_JSON="$E5A_EVIDENCE_DIR/e5b-authorization-package.json"

fail() {
  echo "N1D_C3B_E5B_AUTH_PACKAGE=FAIL reason=$1" >&2
  exit 1
}

echo "===== TITAN 2 N1D C3B E5B AUTHORIZATION PACKAGE / OFFLINE ONLY ====="
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "ADB_COMMANDS_RUN=NO"
echo "FASTBOOT_COMMANDS_RUN=NO"
echo "REBOOT_COMMANDS_RUN=NO"
echo "FLASH_AUTHORIZED=NO"
echo "ERASE_AUTHORIZED=NO"
echo "FORMAT_AUTHORIZED=NO"
echo "LP_MUTATION_AUTHORIZED=NO"
echo "AVB_MUTATION_AUTHORIZED=NO"
echo "SLOT_MUTATION_AUTHORIZED=NO"
echo "UNLOCK_LOCK_AUTHORIZED=NO"
echo "FACTORY_RESET_AUTHORIZED=NO"
echo "CUSTOM_BOOT_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=NO"
echo "PRODUCTION_SIGNING_AUTHORIZED=NO"

bash "$ROOT/build/gates/n1d-c3b-e4-evidence-contract.sh" >/dev/null
[[ -f "$E5A_JSON" ]] || fail "e5a_json_missing path=$E5A_JSON"

LPDUMP="$E5A_EVIDENCE_DIR/adb-extra/lpdump.txt"
[[ -s "$LPDUMP" ]] || fail "e5a_lpdump_missing"

mapfile -t phase11_getvars < <(
  find "$E5A_EVIDENCE_DIR/private/phase11" -type f -name 'getvar-all.txt' -print 2>/dev/null | sort
)
[[ "${#phase11_getvars[@]}" -eq 1 ]] || fail "phase11_getvar_all_count count=${#phase11_getvars[@]}"
PHASE11_GETVAR_ALL="${phase11_getvars[0]}"

E5A_JSON_SHA256="$(sha256sum "$E5A_JSON" | awk '{print $1}')"
LPDUMP_SHA256="$(sha256sum "$LPDUMP" | awk '{print $1}')"
PHASE11_GETVAR_ALL_SHA256="$(sha256sum "$PHASE11_GETVAR_ALL" | awk '{print $1}')"

python3 - \
  "$E5A_JSON" \
  "$E5A_JSON_SHA256" \
  "$LPDUMP" \
  "$LPDUMP_SHA256" \
  "$PHASE11_GETVAR_ALL" \
  "$PHASE11_GETVAR_ALL_SHA256" \
  "$OUTPUT_JSON" <<'PY'
from __future__ import annotations

import json
import pathlib
import re
import sys
from typing import Any

src = pathlib.Path(sys.argv[1])
src_sha = sys.argv[2]
lpdump_path = pathlib.Path(sys.argv[3])
lpdump_sha = sys.argv[4]
getvar_path = pathlib.Path(sys.argv[5])
getvar_sha = sys.argv[6]
out = pathlib.Path(sys.argv[7])

data: dict[str, Any] = json.loads(src.read_text(encoding="utf-8"))
lpdump = lpdump_path.read_text(encoding="utf-8", errors="replace")
getvar_text = getvar_path.read_text(encoding="utf-8", errors="replace")

def fail(msg: str) -> None:
    raise SystemExit(f"N1D_C3B_E5B_AUTH_PACKAGE=FAIL_{msg}")

def as_int(value: Any) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0

def normalize_getvar(text: str) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in text.splitlines():
        line = re.sub(r"^\s*\([^)]*\)\s*", "", raw.strip())
        if not line:
            continue
        match = re.match(r"^(.+):\s*([^:]+)$", line)
        if match:
            values.setdefault(match.group(1).strip(), match.group(2).strip())
    return values

def parse_int_token(value: str) -> int:
    token = value.strip().split()[0] if value.strip() else ""
    try:
        return int(token, 0)
    except ValueError:
        return 0

def parse_lpdump_groups(text: str) -> tuple[dict[str, str], dict[str, int]]:
    partition_groups: dict[str, str] = {}
    group_max: dict[str, int] = {}
    current_name = ""
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith("Name:"):
            current_name = line.split(":", 1)[1].strip()
            continue
        if line.startswith("Group:") and current_name:
            partition_groups[current_name] = line.split(":", 1)[1].strip()
            continue
        if line.startswith("Maximum size:") and current_name:
            raw_value = line.split(":", 1)[1].strip().split()[0]
            try:
                group_max[current_name] = int(raw_value, 0)
            except ValueError:
                pass
    return partition_groups, group_max

if data.get("final_state") != "PASS_REVIEW_READY":
    fail("E5A_NOT_CLEAN_PASS")
if data.get("device_binding_verified") is not True:
    fail("DEVICE_BINDING_NOT_VERIFIED")
stock = data.get("stock", {})
if stock.get("fingerprint_match") is not True or stock.get("incremental_match") is not True:
    fail("STOCK_IDENTITY_MISMATCH")

fast = data.get("fastbootd", {})
current = str(fast.get("current_slot", ""))
if current not in {"a", "b"}:
    fail("CURRENT_SLOT_UNKNOWN")
if fast.get("is_userspace") != "yes":
    fail("NOT_FASTBOOTD")
if fast.get("unlocked") != "yes":
    fail("BOOTLOADER_NOT_UNLOCKED")
if fast.get("allocation_complete") is not True:
    fail("ALLOCATION_INCOMPLETE")
if fast.get("capacity_safe") is not True:
    fail("CAPACITY_NOT_SAFE")
if data.get("snapshot_update_review") != "PASS_IDLE_OR_NONE":
    fail("SNAPSHOT_UPDATE_NOT_CLEAN")

partition_sizes = fast.get("partition_sizes", {})
system = partition_sizes.get("system", {})
if not isinstance(system, dict):
    fail("SYSTEM_PARTITION_EVIDENCE_MISSING")

target_partition = f"system_{current}"
other_slot = "b" if current == "a" else "a"
other_partition = f"system_{other_slot}"
target = as_int(fast.get("planned_system_target_bytes"))
super_bytes = as_int(fast.get("super_bytes"))
allocated = as_int(fast.get("all_slots_reported_dynamic_total_bytes"))
fresh_headroom = as_int(fast.get("fresh_super_headroom_all_slots_estimate_bytes"))
minimum_remaining = as_int(fast.get("minimum_remaining_headroom_bytes"))
active_bytes = as_int(system.get(current)) or as_int(system.get("active"))
other_bytes = as_int(system.get(other_slot))

if target <= 0 or super_bytes <= 0 or allocated <= 0 or fresh_headroom <= 0:
    fail("FRESH_CAPACITY_FIELDS_MISSING")
if active_bytes <= 0:
    fail("ACTIVE_SYSTEM_SIZE_MISSING")

values = normalize_getvar(getvar_text)
logical_names = {
    key.split(":", 1)[1]
    for key, value in values.items()
    if key.startswith("is-logical:") and value.lower() == "yes"
}
logical_sizes = {
    name: parse_int_token(values.get(f"partition-size:{name}", ""))
    for name in logical_names
}
if not logical_names or any(size <= 0 for size in logical_sizes.values()):
    fail("LOGICAL_PARTITION_INVENTORY_INCOMPLETE")

active_cow_suffix = f"_{current}-cow"
lpdump_partition_names = set(parse_lpdump_groups(lpdump)[0])
active_cows = sorted(
    {
        name for name in logical_names if name.endswith(active_cow_suffix)
    }
    | {
        name for name in lpdump_partition_names if name.endswith(active_cow_suffix)
    }
)
active_cow_sizes = {
    name: logical_sizes.get(name, parse_int_token(values.get(f"partition-size:{name}", "")))
    for name in active_cows
}
if any(size <= 0 for size in active_cow_sizes.values()):
    fail("ACTIVE_COW_SIZE_INCOMPLETE")
active_cow_total = sum(active_cow_sizes.values())

partition_groups, group_max = parse_lpdump_groups(lpdump)
active_group = f"main_{current}"
active_group_max = group_max.get(active_group, 0)
active_group_members = sorted(name for name, group in partition_groups.items() if group == active_group)
active_group_sizes = {
    name: logical_sizes.get(name, 0)
    for name in active_group_members
}
group_members_complete = bool(active_group_members) and all(size > 0 for size in active_group_sizes.values())
active_group_current_bytes = sum(active_group_sizes.values()) if group_members_complete else 0

if active_group_max <= 0:
    fail("ACTIVE_GROUP_MAXIMUM_MISSING")
if target_partition not in active_group_members:
    fail("ACTIVE_SYSTEM_NOT_IN_ACTIVE_GROUP")
if not group_members_complete:
    fail("ACTIVE_GROUP_MEMBER_SIZE_INCOMPLETE")

active_growth = max(0, target - active_bytes)
post_cow_cleanup_headroom = fresh_headroom + active_cow_total
remaining_after_cleanup_and_growth = post_cow_cleanup_headroom - active_growth
prospective_active_group_bytes = active_group_current_bytes - active_bytes + target
group_capacity_safe = prospective_active_group_bytes <= active_group_max
super_capacity_safe = remaining_after_cleanup_and_growth >= minimum_remaining

cow_cleanup_policy = (
    "REVIEWED_ACTIVE_SLOT_COW_CLEANUP_REQUIRED"
    if active_cows
    else "NO_COW_CLEANUP_NEEDED"
)
lp_action = (
    "REVIEWED_COW_CLEANUP_PLUS_ACTIVE_SYSTEM_RESIZE"
    if active_cows
    else "REVIEWED_ACTIVE_SYSTEM_RESIZE"
)

ready = group_capacity_safe and super_capacity_safe
authorization_state = (
    "READY_FOR_MANUAL_AUTHORIZATION_ACTIVE_SYSTEM_PATH"
    if ready
    else "BLOCKED_CAPACITY_OR_GROUP_PROOF"
)

result = {
    "schema": 2,
    "phase": "N1D_C3B_E5B_AUTHORIZATION_PACKAGE",
    "supersedes_schema_1_inactive_slot_assumption": True,
    "e5a_source_json_sha256": src_sha,
    "lpdump_sha256": lpdump_sha,
    "phase11_getvar_all_sha256": getvar_sha,
    "e5a_final_state": data.get("final_state"),
    "device_binding_verified": True,
    "stock_identity_verified": True,
    "snapshot_update_review": data.get("snapshot_update_review"),
    "titan2_partition_model": "VIRTUAL_AB_METADATA_SLOTTED_ACTIVE_LOGICAL_MATERIALIZATION",
    "current_slot": current,
    "target_system_partition": target_partition,
    "non_materialized_other_system_partition": other_partition if other_bytes == 0 else "",
    "other_system_current_bytes": other_bytes,
    "other_system_zero_interpretation": (
        "EXPECTED_VIRTUAL_AB_NON_MATERIALIZED_LOGICAL_NOT_DEPLOYMENT_TARGET"
        if other_bytes == 0
        else "MATERIALIZED_REVIEW_REQUIRED"
    ),
    "slot_policy": "KEEP_CURRENT_SLOT_NO_SLOT_SWITCH",
    "slot_mutation_required": False,
    "historical_proven_path": "N1B_ACTIVE_SYSTEM_COW_CLEANUP_RESIZE_SYSTEM_FLASH_FACTORY_RESET",
    "historical_n1b_first_boot": "PASS",
    "historical_n1c_whole_super_write": "FLASHED_BUT_BOOT_FAILED_DO_NOT_USE_AS_PRIMARY_C3B_PATH",
    "active_system_current_bytes": active_bytes,
    "planned_system_target_bytes": target,
    "active_system_growth_bytes": active_growth,
    "super_bytes": super_bytes,
    "all_materialized_logical_bytes": allocated,
    "fresh_super_headroom_bytes": fresh_headroom,
    "active_cow_partitions": active_cow_sizes,
    "active_cow_total_bytes": active_cow_total,
    "cow_cleanup_policy": cow_cleanup_policy,
    "lp_action": lp_action,
    "post_cow_cleanup_headroom_bytes": post_cow_cleanup_headroom,
    "remaining_headroom_after_cleanup_and_growth_bytes": remaining_after_cleanup_and_growth,
    "minimum_remaining_headroom_bytes": minimum_remaining,
    "active_group": active_group,
    "active_group_maximum_bytes": active_group_max,
    "active_group_members": active_group_sizes,
    "active_group_current_bytes": active_group_current_bytes,
    "active_group_prospective_bytes_after_system_target": prospective_active_group_bytes,
    "active_group_capacity_safe": group_capacity_safe,
    "super_capacity_safe": super_capacity_safe,
    "avb_policy": "PRESERVE_NO_VBMETA_OR_BOOT_CHAIN_MUTATION",
    "boot_partition_policy": "PRESERVE_STOCK_BOOT_INIT_BOOT_VENDOR_BOOT_DTBO",
    "dynamic_partition_policy": "PRESERVE_STOCK_PRODUCT_SYSTEM_EXT_VENDOR_AND_DLKMS",
    "whole_super_policy": "DO_NOT_USE_N1C_WHOLE_SUPER_AS_PRIMARY_C3B_DEPLOYMENT_PATH",
    "userdata_policy": "EXPLICIT_FACTORY_RESET_EXPECTED_FOR_FIRST_C3B_BOOT_SEPARATE_AUTHORIZATION_REQUIRED",
    "flash_authorized": False,
    "erase_authorized": False,
    "lp_mutation_authorized": False,
    "avb_mutation_authorized": False,
    "slot_mutation_authorized": False,
    "factory_reset_authorized": False,
    "write_capable_commands_emitted": False,
    "authorization_state": authorization_state,
}
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")

print(f"N1D_C3B_E5B_E5A_JSON_SHA256={src_sha}")
print("N1D_C3B_E5B_E5A_STATE=PASS_REVIEW_READY")
print("N1D_C3B_E5B_PREVIOUS_INACTIVE_SLOT_PACKAGE=SUPERSEDED")
print("N1D_C3B_E5B_TITAN2_PARTITION_MODEL=VIRTUAL_AB_METADATA_SLOTTED_ACTIVE_LOGICAL_MATERIALIZATION")
print(f"N1D_C3B_E5B_CURRENT_SLOT={current}")
print(f"N1D_C3B_E5B_TARGET_SYSTEM_PARTITION={target_partition}")
print(f"N1D_C3B_E5B_OTHER_SYSTEM_PARTITION={other_partition}")
print(f"N1D_C3B_E5B_OTHER_SYSTEM_CURRENT_BYTES={other_bytes}")
print(
    "N1D_C3B_E5B_OTHER_SYSTEM_ZERO_INTERPRETATION="
    + (
        "EXPECTED_VIRTUAL_AB_NON_MATERIALIZED_LOGICAL_NOT_DEPLOYMENT_TARGET"
        if other_bytes == 0
        else "MATERIALIZED_REVIEW_REQUIRED"
    )
)
print("N1D_C3B_E5B_SLOT_POLICY=KEEP_CURRENT_SLOT_NO_SLOT_SWITCH")
print("N1D_C3B_E5B_HISTORICAL_PROVEN_PATH=N1B_ACTIVE_SYSTEM_COW_CLEANUP_RESIZE_SYSTEM_FLASH_FACTORY_RESET")
print("N1D_C3B_E5B_N1C_WHOLE_SUPER_PATH=FLASHED_BUT_BOOT_FAILED_DO_NOT_USE_AS_PRIMARY_C3B_PATH")
print(f"N1D_C3B_E5B_ACTIVE_SYSTEM_CURRENT_BYTES={active_bytes}")
print(f"N1D_C3B_E5B_PLANNED_SYSTEM_TARGET_BYTES={target}")
print(f"N1D_C3B_E5B_ACTIVE_SYSTEM_GROWTH_BYTES={active_growth}")
print(f"N1D_C3B_E5B_SUPER_BYTES={super_bytes}")
print(f"N1D_C3B_E5B_FRESH_SUPER_HEADROOM_BYTES={fresh_headroom}")
print(f"N1D_C3B_E5B_ACTIVE_COW_COUNT={len(active_cows)}")
print(f"N1D_C3B_E5B_ACTIVE_COW_TOTAL_BYTES={active_cow_total}")
for name in active_cows:
    print(f"N1D_C3B_E5B_ACTIVE_COW={name}:{active_cow_sizes[name]}")
print(f"N1D_C3B_E5B_COW_CLEANUP_POLICY={cow_cleanup_policy}")
print(f"N1D_C3B_E5B_LP_ACTION={lp_action}")
print(f"N1D_C3B_E5B_POST_COW_CLEANUP_HEADROOM_BYTES={post_cow_cleanup_headroom}")
print(f"N1D_C3B_E5B_REMAINING_HEADROOM_AFTER_CLEANUP_AND_GROWTH_BYTES={remaining_after_cleanup_and_growth}")
print(f"N1D_C3B_E5B_ACTIVE_GROUP={active_group}")
print(f"N1D_C3B_E5B_ACTIVE_GROUP_MAXIMUM_BYTES={active_group_max}")
print(f"N1D_C3B_E5B_ACTIVE_GROUP_CURRENT_BYTES={active_group_current_bytes}")
print(f"N1D_C3B_E5B_ACTIVE_GROUP_PROSPECTIVE_BYTES={prospective_active_group_bytes}")
print(f"N1D_C3B_E5B_ACTIVE_GROUP_CAPACITY_SAFE={'YES' if group_capacity_safe else 'NO'}")
print(f"N1D_C3B_E5B_SUPER_CAPACITY_SAFE={'YES' if super_capacity_safe else 'NO'}")
print("N1D_C3B_E5B_AVB_POLICY=PRESERVE_NO_VBMETA_OR_BOOT_CHAIN_MUTATION")
print("N1D_C3B_E5B_BOOT_PARTITION_POLICY=PRESERVE_STOCK_BOOT_INIT_BOOT_VENDOR_BOOT_DTBO")
print("N1D_C3B_E5B_DYNAMIC_PARTITION_POLICY=PRESERVE_STOCK_PRODUCT_SYSTEM_EXT_VENDOR_AND_DLKMS")
print("N1D_C3B_E5B_USERDATA_POLICY=EXPLICIT_FACTORY_RESET_EXPECTED_SEPARATE_AUTHORIZATION_REQUIRED")
print("N1D_C3B_E5B_FLASH_AUTHORIZED=NO")
print("N1D_C3B_E5B_ERASE_AUTHORIZED=NO")
print("N1D_C3B_E5B_LP_MUTATION_AUTHORIZED=NO")
print("N1D_C3B_E5B_AVB_MUTATION_AUTHORIZED=NO")
print("N1D_C3B_E5B_SLOT_MUTATION_AUTHORIZED=NO")
print("N1D_C3B_E5B_FACTORY_RESET_AUTHORIZED=NO")
print("N1D_C3B_E5B_WRITE_CAPABLE_COMMANDS_EMITTED=NO")
print(f"N1D_C3B_E5B_AUTHORIZATION_PACKAGE_JSON={out}")
print(f"N1D_C3B_E5B_AUTHORIZATION_PACKAGE={authorization_state}")
if not ready:
    raise SystemExit(4)
PY
