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

Offline-only E5B decision-package preparation.
It does not run adb, fastboot, reboot, flash, erase, resize, set-active,
AVB/vbmeta mutation, build, signing, or network commands.
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

E5A_JSON_SHA256="$(sha256sum "$E5A_JSON" | awk '{print $1}')"
LPDUMP="$E5A_EVIDENCE_DIR/adb-extra/lpdump.txt"
LPDUMP_SHA256=UNKNOWN
if [[ -s "$LPDUMP" ]]; then
  LPDUMP_SHA256="$(sha256sum "$LPDUMP" | awk '{print $1}')"
fi

python3 - \
  "$E5A_JSON" \
  "$E5A_JSON_SHA256" \
  "$LPDUMP" \
  "$LPDUMP_SHA256" \
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
out = pathlib.Path(sys.argv[5])

data: dict[str, Any] = json.loads(src.read_text(encoding="utf-8"))

def fail(msg: str) -> None:
    raise SystemExit(f"N1D_C3B_E5B_AUTH_PACKAGE=FAIL_{msg}")

if data.get("final_state") != "PASS_REVIEW_READY":
    fail("E5A_NOT_CLEAN_PASS")
if data.get("device_binding_verified") is not True:
    fail("DEVICE_BINDING_NOT_VERIFIED")
stock = data.get("stock", {})
if stock.get("fingerprint_match") is not True or stock.get("incremental_match") is not True:
    fail("STOCK_IDENTITY_MISMATCH")

fast = data.get("fastbootd", {})
if fast.get("current_slot") not in {"a", "b"}:
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

current = fast["current_slot"]
inactive = "b" if current == "a" else "a"
partition_sizes = fast.get("partition_sizes", {})
system = partition_sizes.get("system", {})
if not isinstance(system, dict):
    fail("SYSTEM_PARTITION_EVIDENCE_MISSING")

def as_int(value: Any) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0

target = as_int(fast.get("planned_system_target_bytes"))
super_bytes = as_int(fast.get("super_bytes"))
allocated = as_int(fast.get("all_slots_reported_dynamic_total_bytes"))
fresh_headroom = as_int(fast.get("fresh_super_headroom_all_slots_estimate_bytes"))
minimum_remaining = as_int(fast.get("minimum_remaining_headroom_bytes"))
active_bytes = as_int(system.get(current)) or as_int(system.get("active"))
inactive_bytes = as_int(system.get(inactive))

if target <= 0 or super_bytes <= 0 or allocated <= 0 or fresh_headroom <= 0:
    fail("FRESH_CAPACITY_FIELDS_MISSING")
if active_bytes <= 0:
    fail("ACTIVE_SYSTEM_SIZE_MISSING")

active_growth = max(0, target - active_bytes)
inactive_growth = max(0, target - inactive_bytes) if inactive_bytes > 0 else 0
active_remaining = fresh_headroom - active_growth
inactive_remaining = fresh_headroom - inactive_growth if inactive_bytes > 0 else 0
active_fit = active_remaining >= minimum_remaining
inactive_fit = inactive_bytes > 0 and inactive_remaining >= minimum_remaining

# Best-effort lpdump sanitization: preserve only group/partition structural lines.
# This is intentionally not used as a capacity proof because OEM lpdump formats vary.
lpdump_present = lpdump_path.exists() and lpdump_path.stat().st_size > 0
lpdump_structural_lines: list[str] = []
if lpdump_present:
    for raw in lpdump_path.read_text(errors="replace").splitlines():
        line = raw.strip()
        if re.match(r"^(Name|Group|Maximum size|Flags|Partition name|Group name):", line, re.I):
            lpdump_structural_lines.append(line)
        if len(lpdump_structural_lines) >= 200:
            break

result = {
    "schema": 1,
    "phase": "N1D_C3B_E5B_AUTHORIZATION_PACKAGE",
    "e5a_source_json_sha256": src_sha,
    "e5a_final_state": data.get("final_state"),
    "device_binding_verified": True,
    "stock_identity_verified": True,
    "snapshot_update_review": data.get("snapshot_update_review"),
    "current_slot": current,
    "inactive_slot": inactive,
    "active_system_partition": f"system_{current}",
    "inactive_system_partition": f"system_{inactive}",
    "active_system_current_bytes": active_bytes,
    "inactive_system_current_bytes": inactive_bytes,
    "planned_system_target_bytes": target,
    "active_system_growth_bytes": active_growth,
    "inactive_system_growth_bytes": inactive_growth,
    "super_bytes": super_bytes,
    "all_slots_allocated_dynamic_bytes": allocated,
    "fresh_super_headroom_bytes": fresh_headroom,
    "minimum_remaining_headroom_bytes": minimum_remaining,
    "active_candidate_remaining_super_headroom_bytes": active_remaining,
    "inactive_candidate_remaining_super_headroom_bytes": inactive_remaining,
    "active_candidate_total_super_fit": active_fit,
    "inactive_candidate_total_super_fit": inactive_fit,
    "allocation_basis": fast.get("allocation_basis", "UNKNOWN"),
    "allocation_complete": fast.get("allocation_complete"),
    "lpdump_captured": lpdump_present,
    "lpdump_sha256": lpdump_sha,
    "lpdump_structural_lines": lpdump_structural_lines,
    "fresh_dynamic_group_capacity_proof": "REQUIRED_BEFORE_E5B_AUTHORIZATION",
    "recommended_slot_policy": "PREFER_INACTIVE_SLOT_TO_PRESERVE_PROVEN_STOCK_ACTIVE_SLOT_IF_INACTIVE_BOOT_CHAIN_AND_GROUP_CAPACITY_ARE_CONFIRMED",
    "active_slot_mutation_required_for_recommended_policy": True,
    "userdata_policy": "PRESERVE_NO_ERASE",
    "flash_authorized": False,
    "erase_authorized": False,
    "lp_mutation_authorized": False,
    "avb_mutation_authorized": False,
    "slot_mutation_authorized": False,
    "unlock_lock_authorized": False,
    "factory_reset_authorized": False,
    "write_capable_commands_emitted": False,
    "authorization_state": "READY_FOR_MANUAL_DECISION_AFTER_GROUP_AND_INACTIVE_BOOT_CHAIN_REVIEW",
}
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")

print(f"N1D_C3B_E5B_E5A_JSON_SHA256={src_sha}")
print("N1D_C3B_E5B_E5A_STATE=PASS_REVIEW_READY")
print(f"N1D_C3B_E5B_CURRENT_SLOT={current}")
print(f"N1D_C3B_E5B_INACTIVE_SLOT={inactive}")
print(f"N1D_C3B_E5B_ACTIVE_SYSTEM_PARTITION=system_{current}")
print(f"N1D_C3B_E5B_INACTIVE_SYSTEM_PARTITION=system_{inactive}")
print(f"N1D_C3B_E5B_ACTIVE_SYSTEM_CURRENT_BYTES={active_bytes}")
print(f"N1D_C3B_E5B_INACTIVE_SYSTEM_CURRENT_BYTES={inactive_bytes}")
print(f"N1D_C3B_E5B_PLANNED_SYSTEM_TARGET_BYTES={target}")
print(f"N1D_C3B_E5B_ACTIVE_SYSTEM_GROWTH_BYTES={active_growth}")
print(f"N1D_C3B_E5B_INACTIVE_SYSTEM_GROWTH_BYTES={inactive_growth}")
print(f"N1D_C3B_E5B_SUPER_BYTES={super_bytes}")
print(f"N1D_C3B_E5B_FRESH_SUPER_HEADROOM_BYTES={fresh_headroom}")
print(f"N1D_C3B_E5B_ACTIVE_CANDIDATE_REMAINING_HEADROOM_BYTES={active_remaining}")
print(f"N1D_C3B_E5B_INACTIVE_CANDIDATE_REMAINING_HEADROOM_BYTES={inactive_remaining}")
print(f"N1D_C3B_E5B_ACTIVE_CANDIDATE_TOTAL_SUPER_FIT={'YES' if active_fit else 'NO'}")
print(f"N1D_C3B_E5B_INACTIVE_CANDIDATE_TOTAL_SUPER_FIT={'YES' if inactive_fit else 'NO'}")
print(f"N1D_C3B_E5B_LPDUMP_CAPTURED={'YES' if lpdump_present else 'NO'}")
print(f"N1D_C3B_E5B_LPDUMP_SHA256={lpdump_sha}")
print("N1D_C3B_E5B_GROUP_CAPACITY_PROOF=REQUIRED_BEFORE_AUTHORIZATION")
print("N1D_C3B_E5B_RECOMMENDED_SLOT_POLICY=PREFER_INACTIVE_SLOT_IF_BOOT_CHAIN_AND_GROUP_CAPACITY_CONFIRMED")
print("N1D_C3B_E5B_USERDATA_POLICY=PRESERVE_NO_ERASE")
print("N1D_C3B_E5B_FLASH_AUTHORIZED=NO")
print("N1D_C3B_E5B_ERASE_AUTHORIZED=NO")
print("N1D_C3B_E5B_LP_MUTATION_AUTHORIZED=NO")
print("N1D_C3B_E5B_AVB_MUTATION_AUTHORIZED=NO")
print("N1D_C3B_E5B_SLOT_MUTATION_AUTHORIZED=NO")
print("N1D_C3B_E5B_WRITE_CAPABLE_COMMANDS_EMITTED=NO")
print(f"N1D_C3B_E5B_AUTHORIZATION_PACKAGE_JSON={out}")
print("N1D_C3B_E5B_AUTHORIZATION_PACKAGE=READY_FOR_MANUAL_DECISION_AFTER_GROUP_AND_INACTIVE_BOOT_CHAIN_REVIEW")
PY
