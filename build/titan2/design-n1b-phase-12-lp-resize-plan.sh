#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVIDENCE_ROOT="${SABLE_N1B_PHASE_12_EVIDENCE_ROOT:-/srv/data/sable-build/evidence/titan2/n1b-phase-12-lp-resize-plan}"
STAMP="$(date -u +%Y%m%d_%H%M%S)"
EVIDENCE_DIR="$EVIDENCE_ROOT/$STAMP/offline-plan"
PHASE11_JSON=""
SYSTEM_IMAGE=""
ALIGNMENT_BYTES=1048576
SYSTEM_MARGIN_BYTES=268435456
MIN_REMAINING_SUPER_HEADROOM_BYTES=536870912

usage() {
  cat >&2 <<'EOF'
usage:
  bash build/titan2/design-n1b-phase-12-lp-resize-plan.sh \
    --phase11-json <phase11-fastbootd-lp-sizing.json> \
    --system-image <system.img> \
    [--alignment-bytes <bytes>] \
    [--system-margin-bytes <bytes>] \
    [--min-remaining-super-headroom-bytes <bytes>] \
    [--evidence-dir <dir>]

This is an offline design gate. It emits a JSON review record only.
It does not contact the device, run adb, run fastboot, reboot, flash, erase,
unlock, change slots, mutate AVB, or mutate logical partitions.
EOF
}

while (($#)); do
  case "$1" in
    --phase11-json) PHASE11_JSON="$2"; shift 2 ;;
    --system-image) SYSTEM_IMAGE="$2"; shift 2 ;;
    --alignment-bytes) ALIGNMENT_BYTES="$2"; shift 2 ;;
    --system-margin-bytes) SYSTEM_MARGIN_BYTES="$2"; shift 2 ;;
    --min-remaining-super-headroom-bytes) MIN_REMAINING_SUPER_HEADROOM_BYTES="$2"; shift 2 ;;
    --evidence-dir) EVIDENCE_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "N1B_PHASE_12_LP_RESIZE_PLAN=FAIL_UNKNOWN_ARG arg=$1" >&2; usage; exit 64 ;;
  esac
done

[[ -n "$PHASE11_JSON" ]] || { echo "N1B_PHASE_12_LP_RESIZE_PLAN=FAIL_MISSING_PHASE11_JSON"; usage; exit 64; }
[[ -n "$SYSTEM_IMAGE" ]] || { echo "N1B_PHASE_12_LP_RESIZE_PLAN=FAIL_MISSING_SYSTEM_IMAGE"; usage; exit 64; }
[[ -f "$PHASE11_JSON" ]] || { echo "N1B_PHASE_12_LP_RESIZE_PLAN=FAIL_PHASE11_JSON_NOT_FOUND path=$PHASE11_JSON"; exit 66; }
[[ -f "$SYSTEM_IMAGE" ]] || { echo "N1B_PHASE_12_LP_RESIZE_PLAN=FAIL_SYSTEM_IMAGE_NOT_FOUND path=$SYSTEM_IMAGE"; exit 66; }

mkdir -p "$EVIDENCE_DIR"
LOG="$EVIDENCE_DIR/phase12-lp-resize-plan.log"
JSON_OUT="$EVIDENCE_DIR/phase12-lp-resize-plan.json"

exec > >(tee "$LOG") 2>&1

echo "===== N1B PHASE 12 TITAN2 LP RESIZE PLAN DESIGN ====="
echo "ROOT=$ROOT"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "PHASE11_JSON=$PHASE11_JSON"
echo "SYSTEM_IMAGE=$SYSTEM_IMAGE"
echo "DEVICE=titan2"
echo "RELEASE=N1B"
echo "SOURCE_MAP_REVIEWED=YES"
echo "CURRENT_SABLEOS_REPO_REVIEWED=YES"
echo "CURRENT_DEVICE_EVIDENCE_REVIEWED=YES_PHASE_11_OUTPUT"
echo "DEVICE_CONTACT_AUTHORIZED=NO_OFFLINE_ONLY"
echo "ADB_COMMANDS_RUN=NO"
echo "FASTBOOT_COMMANDS_RUN=NO"
echo "REBOOT_COMMANDS_RUN=NO"
echo "FLASH_AUTHORIZED=NO"
echo "FLASH_COMMANDS_RUN=NO"
echo "ERASE_COMMANDS_RUN=NO"
echo "UNLOCK_COMMANDS_RUN=NO"
echo "LP_MUTATION_AUTHORIZED=NO"
echo "AVB_MUTATION_AUTHORIZED=NO"
echo "COMMAND_OUTPUTS_EXECUTABLE_COMMANDS=NO"
echo "PUBLIC_RELEASE=NO"
echo "PRODUCTION_SIGNING=NO"
echo "ALIGNMENT_BYTES=$ALIGNMENT_BYTES"
echo "SYSTEM_MARGIN_BYTES=$SYSTEM_MARGIN_BYTES"
echo "MIN_REMAINING_SUPER_HEADROOM_BYTES=$MIN_REMAINING_SUPER_HEADROOM_BYTES"

python3 - "$PHASE11_JSON" "$SYSTEM_IMAGE" "$JSON_OUT" \
  "$ALIGNMENT_BYTES" "$SYSTEM_MARGIN_BYTES" "$MIN_REMAINING_SUPER_HEADROOM_BYTES" <<'PY'
from __future__ import annotations

import hashlib
import json
import math
import os
import pathlib
import sys

phase11_path = pathlib.Path(sys.argv[1])
system_image = pathlib.Path(sys.argv[2])
json_out = pathlib.Path(sys.argv[3])
alignment_bytes = int(sys.argv[4], 0)
system_margin_bytes = int(sys.argv[5], 0)
min_remaining_super_headroom_bytes = int(sys.argv[6], 0)

if alignment_bytes <= 0:
    raise SystemExit("N1B_PHASE_12_LP_RESIZE_PLAN=FAIL_ALIGNMENT_BYTES")
if system_margin_bytes < 0:
    raise SystemExit("N1B_PHASE_12_LP_RESIZE_PLAN=FAIL_SYSTEM_MARGIN_BYTES")
if min_remaining_super_headroom_bytes < 0:
    raise SystemExit("N1B_PHASE_12_LP_RESIZE_PLAN=FAIL_MIN_REMAINING_SUPER_HEADROOM_BYTES")

phase11 = json.loads(phase11_path.read_text(encoding="utf-8"))


def lookup(key: str, default: object = None) -> object:
    for node_name in ("metadata", "sizing", "fastbootd", "result", "observed"):
        node = phase11.get(node_name)
        if isinstance(node, dict) and key in node:
            return node[key]
    return phase11.get(key, default)


def as_int(key: str) -> int:
    value = lookup(key, 0)
    if value in (None, "", "UNKNOWN"):
        return 0
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, int):
        return value
    return int(str(value).split()[0], 0)


def as_str(key: str, default: str = "UNKNOWN") -> str:
    value = lookup(key, default)
    if value is None or value == "":
        return default
    return str(value)


def align_up(value: int, alignment: int) -> int:
    return int(math.ceil(value / alignment) * alignment)

current_slot = as_str("current_slot", as_str("active_slot", "UNKNOWN"))
slot_letter = current_slot[1:] if current_slot.startswith("_") else current_slot
if slot_letter in ("a", "b"):
    target_logical_partition = f"system_{slot_letter}"
else:
    target_logical_partition = "system_ACTIVE_SLOT_UNKNOWN"

is_userspace = as_str("is_userspace", as_str("is-userspace", "UNKNOWN"))
system_current_bytes = as_int("system_current_bytes")
super_bytes = as_int("super_bytes")
total_selected_dynamic_current_bytes = as_int("total_selected_dynamic_current_bytes")
super_headroom_estimate_bytes = as_int("super_headroom_estimate_bytes")
required_system_bytes = os.path.getsize(system_image)

system_target_bytes = align_up(required_system_bytes + system_margin_bytes, alignment_bytes)
system_growth_bytes = max(0, system_target_bytes - system_current_bytes)
remaining_super_headroom_estimate_bytes = super_headroom_estimate_bytes - system_growth_bytes

missing_direct_bytes = max(0, required_system_bytes - system_current_bytes)
if system_current_bytes >= required_system_bytes:
    direct_compatibility = "PASS_CURRENT_SYSTEM_FITS_IMAGE"
else:
    direct_compatibility = "BLOCKED_NEEDS_LP_RESIZE_PLAN"

if is_userspace != "yes":
    plan_record = "PASS_BLOCKED_NOT_FASTBOOTD_EVIDENCE"
    headroom_status = "BLOCKED_NOT_FASTBOOTD_EVIDENCE"
elif system_current_bytes <= 0 or required_system_bytes <= 0:
    plan_record = "PASS_BLOCKED_INCOMPLETE_SIZE_EVIDENCE"
    headroom_status = "BLOCKED_INCOMPLETE_SIZE_EVIDENCE"
elif system_current_bytes >= required_system_bytes:
    plan_record = "PASS_NO_RESIZE_REQUIRED_REVIEW_REQUIRED"
    headroom_status = "PASS_NO_RESIZE_REQUIRED"
elif super_headroom_estimate_bytes <= 0:
    plan_record = "PASS_BLOCKED_MISSING_SUPER_HEADROOM_ESTIMATE"
    headroom_status = "BLOCKED_MISSING_SUPER_HEADROOM_ESTIMATE"
elif remaining_super_headroom_estimate_bytes < min_remaining_super_headroom_bytes:
    plan_record = "PASS_BLOCKED_INSUFFICIENT_SUPER_HEADROOM_ESTIMATE"
    headroom_status = "BLOCKED_INSUFFICIENT_SUPER_HEADROOM_ESTIMATE"
else:
    plan_record = "PASS_REVIEW_REQUIRED"
    headroom_status = "PASS_CAPACITY_APPEARS_AVAILABLE_REVIEW_REQUIRED"

sha256 = hashlib.sha256()
with system_image.open("rb") as fp:
    for chunk in iter(lambda: fp.read(1024 * 1024), b""):
        sha256.update(chunk)

result = {
    "phase": "N1B_PHASE_12_LP_RESIZE_PLAN_DESIGN",
    "device": "titan2",
    "release": "N1B",
    "source_review": {
        "source_map_reviewed": "YES",
        "historical_chat_context_reviewed": "SCOPE_LIMITED_TO_CURRENT_PROJECT_CONTEXT_AND_PASTED_VALIDATION_LOGS",
        "unihertz_titan2_repo_reviewed": "SCOPE_LIMITED_TO_CANONICAL_SOURCE_MAP_REFERENCE",
        "device_sable_titan2_repo_reviewed": "SCOPE_LIMITED_TO_CANONICAL_SOURCE_MAP_REFERENCE",
        "platform_sable_repo_reviewed": "SCOPE_LIMITED_TO_CANONICAL_SOURCE_MAP_REFERENCE",
        "treble_restlessos_repo_reviewed": "SCOPE_LIMITED_TO_CANONICAL_SOURCE_MAP_REFERENCE",
        "platform_manifest_repo_reviewed": "SCOPE_LIMITED_TO_CANONICAL_SOURCE_MAP_REFERENCE",
        "build_repo_reviewed": "SCOPE_LIMITED_TO_CANONICAL_SOURCE_MAP_REFERENCE",
        "current_sableos_repo_reviewed": "YES",
        "current_device_evidence_reviewed": "YES_PHASE_11_OUTPUT",
    },
    "authorization_boundary": {
        "device_contact_authorized": "NO_OFFLINE_ONLY",
        "adb_commands_run": "NO",
        "fastboot_commands_run": "NO",
        "reboot_commands_run": "NO",
        "flash_authorized": "NO",
        "flash_commands_run": "NO",
        "erase_commands_run": "NO",
        "unlock_commands_run": "NO",
        "lp_mutation_authorized": "NO",
        "avb_mutation_authorized": "NO",
        "command_outputs_executable_commands": "NO",
        "public_release": "NO",
        "production_signing": "NO",
    },
    "inputs": {
        "phase11_json": str(phase11_path),
        "system_image": str(system_image),
        "system_image_sha256": sha256.hexdigest(),
        "alignment_bytes": alignment_bytes,
        "system_margin_bytes": system_margin_bytes,
        "min_remaining_super_headroom_bytes": min_remaining_super_headroom_bytes,
    },
    "observed_phase11_state": {
        "current_slot": current_slot,
        "is_userspace": is_userspace,
        "system_current_bytes": system_current_bytes,
        "super_bytes": super_bytes,
        "total_selected_dynamic_current_bytes": total_selected_dynamic_current_bytes,
        "super_headroom_estimate_bytes": super_headroom_estimate_bytes,
    },
    "sizing_decision": {
        "target_logical_partition": target_logical_partition,
        "required_system_bytes": required_system_bytes,
        "system_current_bytes": system_current_bytes,
        "system_missing_direct_bytes": missing_direct_bytes,
        "system_target_bytes": system_target_bytes,
        "system_growth_bytes": system_growth_bytes,
        "super_headroom_estimate_bytes": super_headroom_estimate_bytes,
        "remaining_super_headroom_estimate_bytes": remaining_super_headroom_estimate_bytes,
        "direct_system_size_compatibility": direct_compatibility,
        "super_headroom_estimate": headroom_status,
        "plan_record": plan_record,
        "flash_plan_allowed": "NO",
        "flash_allowed": "NO",
        "lp_mutation_allowed": "NO",
    },
    "non_authorized_actions": [
        "device_contact",
        "adb",
        "fastboot",
        "reboot",
        "flash",
        "erase",
        "unlock",
        "slot_change",
        "lp_mutation",
        "avb_mutation",
        "public_release",
        "production_signing",
        "executable_command_generation",
    ],
    "next_gate": "Phase 13 reviewed flash-plan design may consume this JSON, but only under a separate PR and authorization boundary.",
}

json_out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")

print(f"N1B_PHASE_12_REQUIRED_SYSTEM_BYTES={required_system_bytes}")
print(f"N1B_PHASE_12_SYSTEM_CURRENT_BYTES={system_current_bytes}")
print(f"N1B_PHASE_12_SYSTEM_MISSING_DIRECT_BYTES={missing_direct_bytes}")
print(f"N1B_PHASE_12_SYSTEM_MARGIN_BYTES={system_margin_bytes}")
print(f"N1B_PHASE_12_SYSTEM_TARGET_BYTES={system_target_bytes}")
print(f"N1B_PHASE_12_SYSTEM_GROWTH_BYTES={system_growth_bytes}")
print(f"N1B_PHASE_12_SUPER_HEADROOM_ESTIMATE_BYTES={super_headroom_estimate_bytes}")
print(f"N1B_PHASE_12_REMAINING_SUPER_HEADROOM_ESTIMATE_BYTES={remaining_super_headroom_estimate_bytes}")
print(f"N1B_PHASE_12_DIRECT_SYSTEM_SIZE_COMPATIBILITY={direct_compatibility}")
print(f"N1B_PHASE_12_SUPER_HEADROOM_ESTIMATE={headroom_status}")
print("N1B_PHASE_12_FLASH_PLAN_ALLOWED=NO")
print("N1B_PHASE_12_FLASH_ALLOWED=NO")
print("N1B_PHASE_12_LP_MUTATION_ALLOWED=NO")
print(f"N1B_PHASE_12_PLAN_JSON={json_out}")
print(f"N1B_PHASE_12_LP_RESIZE_PLAN={plan_record}")
PY

echo "===== N1B PHASE 12 LP RESIZE PLAN RESULT ====="
echo "N1B_PHASE_12_DEVICE_CONTACT=NO_OFFLINE_ONLY"
echo "N1B_PHASE_12_EVIDENCE_DIR=$EVIDENCE_DIR"
