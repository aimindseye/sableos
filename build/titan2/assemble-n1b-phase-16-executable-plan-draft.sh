#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVIDENCE_ROOT="${SABLE_N1B_PHASE_16_EVIDENCE_ROOT:-/srv/data/sable-build/evidence/titan2/n1b-phase-16-executable-plan-draft}"
STAMP="$(date -u +%Y%m%d_%H%M%S)"
EVIDENCE_DIR="$EVIDENCE_ROOT/$STAMP/offline-draft"

PHASE15_JSON=""
PHASE14_JSON=""
PHASE13_JSON=""
ARTIFACT_MANIFEST=""
RESTORE_REPORT=""
SYSTEM_IMAGE=""

usage() {
  cat >&2 <<'EOF'
usage:
  bash build/titan2/assemble-n1b-phase-16-executable-plan-draft.sh \
    --phase15-json <path> \
    --phase14-json <path> \
    --phase13-json <path> \
    --artifact-manifest <path> \
    --restore-report <path> \
    --system-image <path>

This is an offline review-draft assembler.
It does not contact a device, run device tools, reboot, resize partitions,
flash, erase, unlock, mutate AVB, change slots, or emit runnable commands.
EOF
}

while (($#)); do
  case "$1" in
    --phase15-json) PHASE15_JSON="$2"; shift 2 ;;
    --phase14-json) PHASE14_JSON="$2"; shift 2 ;;
    --phase13-json) PHASE13_JSON="$2"; shift 2 ;;
    --artifact-manifest) ARTIFACT_MANIFEST="$2"; shift 2 ;;
    --restore-report) RESTORE_REPORT="$2"; shift 2 ;;
    --system-image) SYSTEM_IMAGE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "N1B_PHASE_16_EXECUTABLE_PLAN_DRAFT=FAIL_UNKNOWN_ARG arg=$1" >&2; usage; exit 64 ;;
  esac
done

mkdir -p "$EVIDENCE_DIR"
LOG="$EVIDENCE_DIR/phase16-executable-plan-draft.log"
JSON_OUT="$EVIDENCE_DIR/phase16-executable-plan-draft.json"
MD_OUT="$EVIDENCE_DIR/phase16-executable-plan-draft.md"

exec > >(tee "$LOG") 2>&1

echo "===== N1B PHASE 16 TITAN2 EXECUTABLE-PLAN DRAFT ====="
echo "ROOT=$ROOT"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "DEVICE=titan2"
echo "RELEASE=N1B"
echo "OWNER_AUTHORIZATION=APPROVE_PHASE_16_EXECUTABLE_PLAN_DRAFT_ONLY"
echo "AUTHORIZE_EXECUTION=NO"
echo "SOURCE_MAP_REVIEWED=YES"
echo "CURRENT_SABLEOS_REPO_REVIEWED=YES"
echo "CURRENT_DEVICE_EVIDENCE_REVIEWED=YES_PHASE_13_14_15_OUTPUTS"
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

python3 - \
  "$PHASE15_JSON" \
  "$PHASE14_JSON" \
  "$PHASE13_JSON" \
  "$ARTIFACT_MANIFEST" \
  "$RESTORE_REPORT" \
  "$SYSTEM_IMAGE" \
  "$JSON_OUT" \
  "$MD_OUT" <<'PY'
from __future__ import annotations

import hashlib
import json
import pathlib
import sys
from typing import Any

phase15_path = pathlib.Path(sys.argv[1]) if sys.argv[1] else None
phase14_path = pathlib.Path(sys.argv[2]) if sys.argv[2] else None
phase13_path = pathlib.Path(sys.argv[3]) if sys.argv[3] else None
artifact_manifest_path = pathlib.Path(sys.argv[4]) if sys.argv[4] else None
restore_report_path = pathlib.Path(sys.argv[5]) if sys.argv[5] else None
system_image_path = pathlib.Path(sys.argv[6]) if sys.argv[6] else None
json_out = pathlib.Path(sys.argv[7])
md_out = pathlib.Path(sys.argv[8])

failures: list[str] = []
warnings: list[str] = []


def require_file(name: str, path: pathlib.Path | None) -> None:
    if path is None or not path.is_file():
        failures.append(f"MISSING_FILE:{name}:{path}")


def require_dir(name: str, path: pathlib.Path | None) -> None:
    if path is None or not path.is_dir():
        failures.append(f"MISSING_DIR:{name}:{path}")

for name, path in (
    ("phase15_json", phase15_path),
    ("phase14_json", phase14_path),
    ("phase13_json", phase13_path),
    ("artifact_manifest", artifact_manifest_path),
    ("system_image", system_image_path),
):
    require_file(name, path)
require_dir("restore_report", restore_report_path)


def read_json(path: pathlib.Path | None, name: str) -> Any:
    if path is None or not path.is_file():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        failures.append(f"JSON_READ_FAIL:{name}:{path}:{exc}")
        return {}

phase15 = read_json(phase15_path, "phase15")
phase14 = read_json(phase14_path, "phase14")
phase13 = read_json(phase13_path, "phase13")
artifact_manifest = read_json(artifact_manifest_path, "artifact_manifest")


def walk(obj: Any):
    if isinstance(obj, dict):
        for key, value in obj.items():
            yield str(key), value
            yield from walk(value)
    elif isinstance(obj, list):
        for item in obj:
            yield from walk(item)


def find_value(obj: Any, keys: list[str]) -> str:
    wanted = {key.lower() for key in keys}
    for key, value in walk(obj):
        if key.lower() in wanted:
            if isinstance(value, (dict, list)):
                return json.dumps(value, sort_keys=True)
            return str(value)
    return ""


def find_int(obj: Any, keys: list[str]) -> int:
    value = find_value(obj, keys).strip()
    if not value:
        return 0
    try:
        return int(value, 0)
    except ValueError:
        return 0

phase15_status = find_value(phase15, ["status", "n1b_phase_15_status"])
phase15_recommendation = find_value(
    phase15,
    ["recommended_owner_decision", "n1b_phase_15_recommended_owner_decision"],
)
phase14_state = find_value(phase14, ["final_state", "n1b_phase_14_final_preflight_approval"])
phase13_status = find_value(phase13, ["status", "phase_result", "result"])

required_system_bytes = find_int(phase15, ["required_system_bytes", "n1b_phase_15_required_system_bytes"])
system_current_bytes = find_int(phase15, ["system_current_bytes", "n1b_phase_15_system_current_bytes"])
system_target_bytes = find_int(phase15, ["system_target_bytes", "n1b_phase_15_system_target_bytes"])
system_growth_bytes = find_int(phase15, ["system_growth_bytes", "n1b_phase_15_system_growth_bytes"])
super_headroom = find_int(phase15, ["super_headroom_estimate_bytes", "n1b_phase_15_super_headroom_estimate_bytes"])
remaining_super_headroom = find_int(phase15, ["remaining_super_headroom_estimate_bytes", "n1b_phase_15_remaining_super_headroom_estimate_bytes"])

if "READY" not in phase15_status:
    failures.append("PHASE15_NOT_READY_FOR_OWNER_REVIEW")
if phase15_recommendation != "APPROVE_PHASE_16_EXECUTABLE_PLAN_DRAFT_ONLY":
    failures.append("PHASE15_RECOMMENDATION_NOT_PHASE16_DRAFT_ONLY")
if phase14_state != "APPROVAL_READY_FOR_MANUAL_AUTHORIZATION":
    failures.append("PHASE14_NOT_READY_FOR_MANUAL_AUTHORIZATION")
if "PASS" not in phase13_status:
    failures.append("PHASE13_PROPOSAL_NOT_PASS")
for label, value in (
    ("required_system_bytes", required_system_bytes),
    ("system_current_bytes", system_current_bytes),
    ("system_target_bytes", system_target_bytes),
    ("system_growth_bytes", system_growth_bytes),
    ("super_headroom_estimate_bytes", super_headroom),
    ("remaining_super_headroom_estimate_bytes", remaining_super_headroom),
):
    if value <= 0:
        failures.append(f"MISSING_OR_INVALID_SIZE:{label}")

system_sha = ""
system_bytes = 0
if system_image_path is not None and system_image_path.is_file():
    h = hashlib.sha256()
    with system_image_path.open("rb") as fp:
        for chunk in iter(lambda: fp.read(1024 * 1024), b""):
            h.update(chunk)
    system_sha = h.hexdigest()
    system_bytes = system_image_path.stat().st_size

if required_system_bytes and system_bytes and required_system_bytes != system_bytes:
    failures.append("SYSTEM_IMAGE_SIZE_MISMATCH_PHASE15_REQUIRED")

artifact_build_source = find_value(artifact_manifest, ["build_source"])
artifact_primary = find_value(artifact_manifest, ["primary_artifact"])

acceptance_areas = [
    "keyboard_input",
    "trackpad_policy",
    "shortcut_keys",
    "settings_app",
    "storage_and_documentsui",
    "telephony_sim_sms_mms_ims",
    "wifi_bluetooth_nfc",
    "webview_and_app_launch",
    "systemui_navigation",
    "sable_apps_smoke",
    "restore_path",
    "ota_update_surface_not_claimed",
]

action_intents = [
    {
        "order": 1,
        "intent_id": "VERIFY_OPERATOR_INTENT_AND_STOP_CONDITIONS",
        "review_goal": "Confirm the owner approved only this Phase 16 draft and did not authorize execution.",
        "required_decision": "continue_review_or_stop",
    },
    {
        "order": 2,
        "intent_id": "VERIFY_RESTORE_PATH_AND_USERDATA_POLICY",
        "review_goal": "Confirm stock restore path, rollback plan, and userdata policy before any future execution authorization.",
        "restore_report": str(restore_report_path) if restore_report_path else "",
        "required_decision": "restore_ready_or_stop",
    },
    {
        "order": 3,
        "intent_id": "VERIFY_DEVICE_IDENTITY_FASTBOOTD_AND_ACTIVE_SLOT",
        "review_goal": "Confirm Titan2 serial, current active slot, userspace fastbootd availability, and no device mismatch.",
        "required_decision": "identity_slot_fastbootd_ready_or_stop",
    },
    {
        "order": 4,
        "intent_id": "PLAN_ACTIVE_SYSTEM_LOGICAL_PARTITION_GROWTH",
        "review_goal": "Review growth of the active system logical partition to the planned target size.",
        "target_logical_partition": "system_active_slot",
        "target_size_bytes": system_target_bytes,
        "growth_bytes": system_growth_bytes,
        "required_decision": "lp_growth_approved_or_stop",
    },
    {
        "order": 5,
        "intent_id": "PLAN_SYSTEM_IMAGE_DEPLOYMENT",
        "review_goal": "Review deployment of the canonical N1B system image only after LP sizing is approved.",
        "system_image": str(system_image_path) if system_image_path else "",
        "system_image_sha256": system_sha,
        "system_image_bytes": system_bytes,
        "required_decision": "system_image_deployment_approved_or_stop",
    },
    {
        "order": 6,
        "intent_id": "PLAN_AVB_CHAIN_DECISION",
        "review_goal": "Review chained AVB/vbmeta handling as a separate decision axis before execution.",
        "required_decision": "avb_decision_approved_or_stop",
    },
    {
        "order": 7,
        "intent_id": "PLAN_POST_CHANGE_ACCEPTANCE",
        "review_goal": "Review post-change acceptance criteria before execution.",
        "acceptance_areas": acceptance_areas,
        "required_decision": "acceptance_plan_approved_or_stop",
    },
    {
        "order": 8,
        "intent_id": "PLAN_ROLLBACK_OR_STOP",
        "review_goal": "Confirm rollback criteria and stop conditions before any future executable plan can be run.",
        "required_decision": "rollback_ready_or_stop",
    },
]

for item in action_intents:
    item.update(
        {
            "executable_command": "NO",
            "runnable_shell": "NO",
            "manual_execution_authorization_required": "YES",
            "operator_review_required": "YES",
            "stop_if_unmet": "YES",
        }
    )

status = "BLOCKED" if failures else "PASS_REVIEW_DRAFT_READY"

package = {
    "schema": 1,
    "phase": "N1B_PHASE_16_EXECUTABLE_PLAN_DRAFT",
    "device": "titan2",
    "release": "N1B",
    "status": status,
    "owner_authorization": {
        "approve_phase_16_executable_plan_draft_only": "YES",
        "authorize_execution": "NO",
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
        "phase15_json": str(phase15_path) if phase15_path else "",
        "phase14_json": str(phase14_path) if phase14_path else "",
        "phase13_json": str(phase13_path) if phase13_path else "",
        "artifact_manifest": str(artifact_manifest_path) if artifact_manifest_path else "",
        "restore_report": str(restore_report_path) if restore_report_path else "",
        "system_image": str(system_image_path) if system_image_path else "",
        "artifact_build_source": artifact_build_source,
        "artifact_primary": artifact_primary,
    },
    "sizing": {
        "required_system_bytes": required_system_bytes,
        "system_current_bytes": system_current_bytes,
        "system_target_bytes": system_target_bytes,
        "system_growth_bytes": system_growth_bytes,
        "super_headroom_estimate_bytes": super_headroom,
        "remaining_super_headroom_estimate_bytes": remaining_super_headroom,
    },
    "action_intents": action_intents,
    "post_change_acceptance_required": acceptance_areas,
    "next_owner_options": [
        "APPROVE_PHASE_17_CONTROLLED_EXECUTION_SCRIPT_DRAFT_ONLY",
        "REQUEST_MORE_EVIDENCE",
        "BLOCK_DEPLOYMENT",
    ],
    "failures": failures,
    "warnings": warnings,
}

json_out.write_text(json.dumps(package, indent=2, sort_keys=True) + "\n")

lines = [
    "# N1B Phase 16 Executable-Plan Draft",
    "",
    f"Status: `{status}`",
    "",
    "## Authorization boundary",
    "",
    "Execution is **not** authorized. This package contains review action intents only.",
    "",
    "```text",
    "AUTHORIZE_EXECUTION=NO",
    "FLASH_AUTHORIZED=NO",
    "LP_MUTATION_AUTHORIZED=NO",
    "AVB_MUTATION_AUTHORIZED=NO",
    "COMMAND_OUTPUTS_EXECUTABLE_COMMANDS=NO",
    "```",
    "",
    "## Sizing basis",
    "",
    "```text",
    f"REQUIRED_SYSTEM_BYTES={required_system_bytes}",
    f"SYSTEM_CURRENT_BYTES={system_current_bytes}",
    f"SYSTEM_TARGET_BYTES={system_target_bytes}",
    f"SYSTEM_GROWTH_BYTES={system_growth_bytes}",
    f"SUPER_HEADROOM_ESTIMATE_BYTES={super_headroom}",
    f"REMAINING_SUPER_HEADROOM_ESTIMATE_BYTES={remaining_super_headroom}",
    "```",
    "",
    "## Review action intents",
    "",
]
for item in action_intents:
    lines.extend(
        [
            f"### {item['order']}. {item['intent_id']}",
            "",
            item["review_goal"],
            "",
            "```text",
            "executable_command=NO",
            "runnable_shell=NO",
            "manual_execution_authorization_required=YES",
            "stop_if_unmet=YES",
            "```",
            "",
        ]
    )
lines.extend(
    [
        "## Owner options after review",
        "",
        "```text",
        "APPROVE_PHASE_17_CONTROLLED_EXECUTION_SCRIPT_DRAFT_ONLY",
        "REQUEST_MORE_EVIDENCE",
        "BLOCK_DEPLOYMENT",
        "```",
        "",
        "No execution is authorized by approving or reviewing this file.",
        "",
    ]
)
md_out.write_text("\n".join(lines), encoding="utf-8")

print(f"N1B_PHASE_16_STATUS={status}")
print("N1B_PHASE_16_OWNER_AUTHORIZATION=APPROVE_PHASE_16_EXECUTABLE_PLAN_DRAFT_ONLY")
print("N1B_PHASE_16_AUTHORIZE_EXECUTION=NO")
print(f"N1B_PHASE_16_REQUIRED_SYSTEM_BYTES={required_system_bytes}")
print(f"N1B_PHASE_16_SYSTEM_CURRENT_BYTES={system_current_bytes}")
print(f"N1B_PHASE_16_SYSTEM_TARGET_BYTES={system_target_bytes}")
print(f"N1B_PHASE_16_SYSTEM_GROWTH_BYTES={system_growth_bytes}")
print(f"N1B_PHASE_16_SUPER_HEADROOM_ESTIMATE_BYTES={super_headroom}")
print(f"N1B_PHASE_16_REMAINING_SUPER_HEADROOM_ESTIMATE_BYTES={remaining_super_headroom}")
print("N1B_PHASE_16_FLASH_AUTHORIZED=NO")
print("N1B_PHASE_16_FLASH_ALLOWED=NO")
print("N1B_PHASE_16_LP_MUTATION_ALLOWED=NO")
print("N1B_PHASE_16_AVB_MUTATION_ALLOWED=NO")
print("N1B_PHASE_16_SLOT_MUTATION_ALLOWED=NO")
print("COMMAND_OUTPUTS_EXECUTABLE_COMMANDS=NO")
for item in failures:
    print(f"N1B_PHASE_16_FAILURE={item}")
for item in warnings:
    print(f"N1B_PHASE_16_WARNING={item}")
print(f"N1B_PHASE_16_DRAFT_JSON={json_out}")
print(f"N1B_PHASE_16_DRAFT_MARKDOWN={md_out}")
print(f"N1B_PHASE_16_EXECUTABLE_PLAN_DRAFT={status}")
PY

echo "===== N1B PHASE 16 EXECUTABLE-PLAN DRAFT RESULT ====="
echo "N1B_PHASE_16_DEVICE_CONTACT=NO_OFFLINE_ONLY"
echo "N1B_PHASE_16_EVIDENCE_DIR=$EVIDENCE_DIR"
