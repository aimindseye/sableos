#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVIDENCE_ROOT="${SABLE_N1B_PHASE_13_EVIDENCE_ROOT:-/srv/data/sable-build/evidence/titan2/n1b-phase-13-flash-plan-proposal}"
STAMP="$(date -u +%Y%m%d_%H%M%S)"
EVIDENCE_DIR="$EVIDENCE_ROOT/$STAMP/offline-proposal"
PHASE12_JSON=""
SYSTEM_IMAGE=""
OUTPUT_JSON=""

usage() {
  cat >&2 <<'EOF'
usage:
  bash build/titan2/design-n1b-phase-13-flash-plan-proposal.sh \
    --phase12-json <phase12-lp-resize-plan.json> \
    --system-image <system.img> \
    [--output-json <path>]

Phase 13 is offline only. It emits a human-reviewable JSON proposal.
It does not contact a device, run adb, run fastboot, reboot, flash, erase,
unlock, mutate logical partitions, mutate AVB, or emit executable commands.
EOF
}

while (($#)); do
  case "$1" in
    --phase12-json) PHASE12_JSON="$2"; shift 2 ;;
    --system-image) SYSTEM_IMAGE="$2"; shift 2 ;;
    --output-json) OUTPUT_JSON="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "N1B_PHASE_13_FLASH_PLAN_PROPOSAL=FAIL_UNKNOWN_ARG arg=$1" >&2; usage; exit 64 ;;
  esac
done

[[ -n "$PHASE12_JSON" && -n "$SYSTEM_IMAGE" ]] || { usage; exit 64; }
[[ -f "$PHASE12_JSON" ]] || { echo "N1B_PHASE_13_PHASE12_JSON=FAIL_MISSING path=$PHASE12_JSON"; exit 66; }
[[ -f "$SYSTEM_IMAGE" ]] || { echo "N1B_PHASE_13_SYSTEM_IMAGE=FAIL_MISSING path=$SYSTEM_IMAGE"; exit 66; }

mkdir -p "$EVIDENCE_DIR"
if [[ -z "$OUTPUT_JSON" ]]; then
  OUTPUT_JSON="$EVIDENCE_DIR/phase13-flash-plan-proposal.json"
fi
LOG="$EVIDENCE_DIR/phase13-flash-plan-proposal.log"

exec > >(tee "$LOG") 2>&1

echo "===== N1B PHASE 13 TITAN2 FLASH-PLAN PROPOSAL ====="
echo "ROOT=$ROOT"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "PHASE12_JSON=$PHASE12_JSON"
echo "SYSTEM_IMAGE=$SYSTEM_IMAGE"
echo "DEVICE=titan2"
echo "RELEASE=N1B"
echo "SOURCE_MAP_REVIEWED=YES"
echo "HISTORICAL_CHAT_CONTEXT_REVIEWED=SCOPE_LIMITED_TO_CURRENT_PROJECT_CONTEXT_AND_PASTED_VALIDATION_LOGS"
echo "EXTERNAL_TITAN2_REPOS_REVIEWED=SCOPE_LIMITED_TO_CANONICAL_SOURCE_MAP_REFERENCE"
echo "CURRENT_SABLEOS_REPO_REVIEWED=YES"
echo "CURRENT_DEVICE_EVIDENCE_REVIEWED=YES_PHASE_12_OUTPUT"
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
echo "SLOT_MUTATION_AUTHORIZED=NO"
echo "COMMAND_OUTPUTS_EXECUTABLE_COMMANDS=NO"
echo "PUBLIC_RELEASE=NO"
echo "PRODUCTION_SIGNING=NO"

python3 - "$PHASE12_JSON" "$SYSTEM_IMAGE" "$OUTPUT_JSON" <<'PY'
from __future__ import annotations

import hashlib
import json
import math
import pathlib
import sys
from typing import Any

phase12_path = pathlib.Path(sys.argv[1])
system_image = pathlib.Path(sys.argv[2])
output_json = pathlib.Path(sys.argv[3])

phase12 = json.loads(phase12_path.read_text(errors="replace"))

def walk(value: Any):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from walk(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk(child)


def lookup(*names: str, default: Any = None) -> Any:
    lowered = {name.lower() for name in names}
    for node in walk(phase12):
        for key, value in node.items():
            if key.lower() in lowered:
                return value
    return default


def as_int(value: Any, default: int = 0) -> int:
    if value is None:
        return default
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, int):
        return value
    text = str(value).strip()
    if not text:
        return default
    try:
        return int(text, 0)
    except ValueError:
        return default


def sha256(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fp:
        for chunk in iter(lambda: fp.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

system_image_bytes = system_image.stat().st_size
system_image_sha256 = sha256(system_image)

required_system_bytes = as_int(
    lookup(
        "required_system_bytes",
        "n1b_phase_12_required_system_bytes",
        "N1B_PHASE_12_REQUIRED_SYSTEM_BYTES",
    ),
    system_image_bytes,
)
system_current_bytes = as_int(
    lookup(
        "system_current_bytes",
        "n1b_phase_12_system_current_bytes",
        "N1B_PHASE_12_SYSTEM_CURRENT_BYTES",
    )
)
system_target_bytes = as_int(
    lookup(
        "system_target_bytes",
        "n1b_phase_12_system_target_bytes",
        "N1B_PHASE_12_SYSTEM_TARGET_BYTES",
    )
)
system_growth_bytes = as_int(
    lookup(
        "system_growth_bytes",
        "n1b_phase_12_system_growth_bytes",
        "N1B_PHASE_12_SYSTEM_GROWTH_BYTES",
    )
)
system_missing_direct_bytes = as_int(
    lookup(
        "system_missing_direct_bytes",
        "n1b_phase_12_system_missing_direct_bytes",
        "N1B_PHASE_12_SYSTEM_MISSING_DIRECT_BYTES",
    ),
    max(0, required_system_bytes - system_current_bytes),
)
super_headroom_estimate_bytes = as_int(
    lookup(
        "super_headroom_estimate_bytes",
        "n1b_phase_12_super_headroom_estimate_bytes",
        "N1B_PHASE_12_SUPER_HEADROOM_ESTIMATE_BYTES",
    )
)
remaining_super_headroom_estimate_bytes = as_int(
    lookup(
        "remaining_super_headroom_estimate_bytes",
        "n1b_phase_12_remaining_super_headroom_estimate_bytes",
        "N1B_PHASE_12_REMAINING_SUPER_HEADROOM_ESTIMATE_BYTES",
    ),
    super_headroom_estimate_bytes - system_growth_bytes,
)
alignment_bytes = as_int(
    lookup("alignment_bytes", "n1b_phase_12_alignment_bytes", "N1B_PHASE_12_ALIGNMENT_BYTES"),
    1048576,
)
min_remaining_super_headroom_bytes = as_int(
    lookup(
        "min_remaining_super_headroom_bytes",
        "n1b_phase_12_min_remaining_super_headroom_bytes",
        "N1B_PHASE_12_MIN_REMAINING_SUPER_HEADROOM_BYTES",
    ),
    536870912,
)

def align_up(value: int, alignment: int) -> int:
    if alignment <= 0:
        return value
    return int(math.ceil(value / alignment) * alignment)

if system_target_bytes <= 0:
    system_target_bytes = align_up(required_system_bytes + 268435456, alignment_bytes)
if system_growth_bytes <= 0:
    system_growth_bytes = max(0, system_target_bytes - system_current_bytes)
if remaining_super_headroom_estimate_bytes == 0 and super_headroom_estimate_bytes:
    remaining_super_headroom_estimate_bytes = super_headroom_estimate_bytes - system_growth_bytes

direct_compatible = system_current_bytes >= required_system_bytes and system_current_bytes > 0
capacity_appears_available = (
    super_headroom_estimate_bytes > 0
    and system_growth_bytes > 0
    and remaining_super_headroom_estimate_bytes >= min_remaining_super_headroom_bytes
)

if direct_compatible:
    direct_status = "PASS_CURRENT_SYSTEM_ALREADY_FITS"
else:
    direct_status = "BLOCKED_NEEDS_LP_RESIZE_PLAN"

if capacity_appears_available:
    headroom_status = "PASS_CAPACITY_APPEARS_AVAILABLE_REVIEW_REQUIRED"
else:
    headroom_status = "BLOCKED_INSUFFICIENT_OR_UNKNOWN_SUPER_HEADROOM"

if (not direct_compatible) and capacity_appears_available:
    proposal_status = "PASS_REVIEW_REQUIRED"
else:
    proposal_status = "BLOCKED_REVIEW_REQUIRED"

proposal = {
    "schema": 1,
    "phase": "N1B_PHASE_13_FLASH_PLAN_PROPOSAL",
    "device": "titan2",
    "release": "N1B",
    "status": proposal_status,
    "source_review": {
        "source_map_reviewed": "YES",
        "historical_chat_context_reviewed": "SCOPE_LIMITED_TO_CURRENT_PROJECT_CONTEXT_AND_PASTED_VALIDATION_LOGS",
        "external_titan2_repos_reviewed": "SCOPE_LIMITED_TO_CANONICAL_SOURCE_MAP_REFERENCE",
        "current_sableos_repo_reviewed": "YES",
        "current_device_evidence_reviewed": "YES_PHASE_12_OUTPUT",
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
        "slot_mutation_authorized": "NO",
        "command_outputs_executable_commands": "NO",
        "public_release": "NO",
        "production_signing": "NO",
    },
    "evidence": {
        "phase12_json": str(phase12_path),
        "system_image": str(system_image),
        "system_image_sha256": system_image_sha256,
        "system_image_bytes": system_image_bytes,
    },
    "sizing": {
        "required_system_bytes": required_system_bytes,
        "system_current_bytes": system_current_bytes,
        "system_missing_direct_bytes": system_missing_direct_bytes,
        "system_target_bytes": system_target_bytes,
        "system_growth_bytes": system_growth_bytes,
        "alignment_bytes": alignment_bytes,
        "super_headroom_estimate_bytes": super_headroom_estimate_bytes,
        "remaining_super_headroom_estimate_bytes": remaining_super_headroom_estimate_bytes,
        "min_remaining_super_headroom_bytes": min_remaining_super_headroom_bytes,
        "direct_system_size_compatibility": direct_status,
        "super_headroom_estimate": headroom_status,
    },
    "non_executable_ordered_proposal": [
        {
            "order": 1,
            "name": "restore_and_userdata_review",
            "description": "Review stock restore path, stock baseline, and userdata preservation policy before any mutation boundary is requested.",
            "executable_command": "NO",
        },
        {
            "order": 2,
            "name": "device_identity_and_slot_review",
            "description": "Review Titan2 serial, active slot, dynamic partition support, virtual A/B state, and fastbootd availability evidence.",
            "executable_command": "NO",
        },
        {
            "order": 3,
            "name": "lp_resize_review",
            "description": "Review whether the active system logical partition should be resized to the planned target size before image deployment.",
            "target_logical_partition": "system_active_slot",
            "target_size_bytes": system_target_bytes,
            "growth_bytes": system_growth_bytes,
            "executable_command": "NO",
        },
        {
            "order": 4,
            "name": "system_image_deployment_review",
            "description": "Review deployment of the canonical N1B system image only after LP sizing is reviewed and separately authorized.",
            "system_image_sha256": system_image_sha256,
            "system_image_bytes": system_image_bytes,
            "executable_command": "NO",
        },
        {
            "order": 5,
            "name": "avb_chain_review",
            "description": "Review chained AVB/vbmeta handling as a separate decision axis. Phase 13 does not patch or disable AVB.",
            "executable_command": "NO",
        },
        {
            "order": 6,
            "name": "post_change_acceptance_review",
            "description": "Define post-change validation criteria, rollback criteria, and stop conditions before any executable plan exists.",
            "executable_command": "NO",
        },
    ],
    "required_remaining_reviews": {
        "restore_path_final_review_required": "YES",
        "userdata_policy_final_review_required": "YES",
        "active_slot_final_review_required": "YES",
        "lp_resize_command_review_required": "YES",
        "gsi_flash_command_review_required": "YES",
        "avb_chain_decision_required": "YES",
        "post_flash_acceptance_required": "YES",
        "rollback_plan_required": "YES",
    },
    "allowed_next_phase": "PHASE_14_EXECUTABLE_PLAN_DRAFT_REVIEW_ONLY",
    "flash_plan_allowed": "NO",
    "flash_allowed": "NO",
    "lp_mutation_allowed": "NO",
    "avb_mutation_allowed": "NO",
}

output_json.parent.mkdir(parents=True, exist_ok=True)
output_json.write_text(json.dumps(proposal, indent=2, sort_keys=True) + "\n")

print(f"N1B_PHASE_13_REQUIRED_SYSTEM_BYTES={required_system_bytes}")
print(f"N1B_PHASE_13_SYSTEM_CURRENT_BYTES={system_current_bytes}")
print(f"N1B_PHASE_13_SYSTEM_TARGET_BYTES={system_target_bytes}")
print(f"N1B_PHASE_13_SYSTEM_GROWTH_BYTES={system_growth_bytes}")
print(f"N1B_PHASE_13_SUPER_HEADROOM_ESTIMATE_BYTES={super_headroom_estimate_bytes}")
print(f"N1B_PHASE_13_REMAINING_SUPER_HEADROOM_ESTIMATE_BYTES={remaining_super_headroom_estimate_bytes}")
print(f"N1B_PHASE_13_DIRECT_SYSTEM_SIZE_COMPATIBILITY={direct_status}")
print(f"N1B_PHASE_13_SUPER_HEADROOM_ESTIMATE={headroom_status}")
print("N1B_PHASE_13_FLASH_PLAN_ALLOWED=NO")
print("N1B_PHASE_13_FLASH_ALLOWED=NO")
print("N1B_PHASE_13_LP_MUTATION_ALLOWED=NO")
print("N1B_PHASE_13_AVB_MUTATION_ALLOWED=NO")
print("COMMAND_OUTPUTS_EXECUTABLE_COMMANDS=NO")
print(f"N1B_PHASE_13_PROPOSAL_JSON={output_json}")
print(f"N1B_PHASE_13_FLASH_PLAN_PROPOSAL={proposal_status}")
PY

echo "===== N1B PHASE 13 FLASH-PLAN PROPOSAL RESULT ====="
echo "N1B_PHASE_13_DEVICE_CONTACT=NO_OFFLINE_ONLY"
echo "N1B_PHASE_13_EVIDENCE_DIR=$EVIDENCE_DIR"
