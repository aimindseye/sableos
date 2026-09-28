#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVIDENCE_ROOT="${SABLE_N1B_PHASE_17_EVIDENCE_ROOT:-/srv/data/sable-build/evidence/titan2/n1b-phase-17-guarded-execution-script-draft}"
STAMP="$(date -u +%Y%m%d_%H%M%S)"
EVIDENCE_DIR="$EVIDENCE_ROOT/$STAMP/offline-guarded-draft"

PHASE16_JSON=""
PHASE15_JSON=""
PHASE14_JSON=""
ARTIFACT_MANIFEST=""
RESTORE_REPORT=""
SYSTEM_IMAGE=""

usage() {
  cat >&2 <<'EOF'
usage:
  bash build/titan2/assemble-n1b-phase-17-guarded-execution-script-draft.sh \
    --phase16-json <path> \
    --phase15-json <path> \
    --phase14-json <path> \
    --artifact-manifest <path> \
    --restore-report <dir> \
    --system-image <path>

This assembles an offline guarded script draft for review only.
It does not contact the device, run transport tools, reboot, flash, erase,
unlock, mutate LP metadata, mutate AVB, change slots, or emit runnable commands.
EOF
}

while (($#)); do
  case "$1" in
    --phase16-json) PHASE16_JSON="$2"; shift 2 ;;
    --phase15-json) PHASE15_JSON="$2"; shift 2 ;;
    --phase14-json) PHASE14_JSON="$2"; shift 2 ;;
    --artifact-manifest) ARTIFACT_MANIFEST="$2"; shift 2 ;;
    --restore-report) RESTORE_REPORT="$2"; shift 2 ;;
    --system-image) SYSTEM_IMAGE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "N1B_PHASE_17_GUARDED_EXECUTION_SCRIPT_DRAFT=FAIL_UNKNOWN_ARG arg=$1" >&2; usage; exit 64 ;;
  esac
done

mkdir -p "$EVIDENCE_DIR"
LOG="$EVIDENCE_DIR/phase17-guarded-execution-script-draft.log"
JSON_OUT="$EVIDENCE_DIR/phase17-guarded-execution-script-draft.json"
MD_OUT="$EVIDENCE_DIR/phase17-guarded-execution-script-draft.md"
DRAFT_OUT="$EVIDENCE_DIR/phase17-guarded-execution-script.sh.draft"

exec > >(tee "$LOG") 2>&1

echo "===== N1B PHASE 17 TITAN2 GUARDED EXECUTION SCRIPT DRAFT ====="
echo "ROOT=$ROOT"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "DEVICE=titan2"
echo "RELEASE=N1B"
echo "OWNER_AUTHORIZATION=APPROVE_PHASE_17_GUARDED_EXECUTION_SCRIPT_DRAFT_ONLY"
echo "AUTHORIZE_EXECUTION=NO"
echo "SOURCE_MAP_REVIEWED=YES"
echo "CURRENT_SABLEOS_REPO_REVIEWED=YES"
echo "CURRENT_DEVICE_EVIDENCE_REVIEWED=YES_PHASE_14_15_16_OUTPUTS"
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
  "$PHASE16_JSON" \
  "$PHASE15_JSON" \
  "$PHASE14_JSON" \
  "$ARTIFACT_MANIFEST" \
  "$RESTORE_REPORT" \
  "$SYSTEM_IMAGE" \
  "$JSON_OUT" \
  "$MD_OUT" \
  "$DRAFT_OUT" <<'PY'
from __future__ import annotations

import hashlib
import json
import pathlib
import sys
from typing import Any

phase16_path = pathlib.Path(sys.argv[1]) if sys.argv[1] else None
phase15_path = pathlib.Path(sys.argv[2]) if sys.argv[2] else None
phase14_path = pathlib.Path(sys.argv[3]) if sys.argv[3] else None
artifact_manifest_path = pathlib.Path(sys.argv[4]) if sys.argv[4] else None
restore_report_path = pathlib.Path(sys.argv[5]) if sys.argv[5] else None
system_image_path = pathlib.Path(sys.argv[6]) if sys.argv[6] else None
json_out = pathlib.Path(sys.argv[7])
md_out = pathlib.Path(sys.argv[8])
draft_out = pathlib.Path(sys.argv[9])

failures: list[str] = []
warnings: list[str] = []


def require_file(name: str, path: pathlib.Path | None) -> None:
    if path is None or not path.is_file():
        failures.append(f"MISSING_FILE:{name}:{path}")


def require_dir(name: str, path: pathlib.Path | None) -> None:
    if path is None or not path.is_dir():
        failures.append(f"MISSING_DIR:{name}:{path}")

for name, path in (
    ("phase16_json", phase16_path),
    ("phase15_json", phase15_path),
    ("phase14_json", phase14_path),
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
        failures.append(f"JSON_READ_FAIL:{name}:{exc}")
        return {}

phase16 = read_json(phase16_path, "phase16")
phase15 = read_json(phase15_path, "phase15")
phase14 = read_json(phase14_path, "phase14")
artifact = read_json(artifact_manifest_path, "artifact_manifest")


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

phase16_status = find_value(phase16, ["status", "n1b_phase_16_status"])
phase15_status = find_value(phase15, ["status", "n1b_phase_15_status"])
phase14_state = find_value(phase14, ["final_state", "n1b_phase_14_final_preflight_approval"])
owner_auth = "APPROVE_PHASE_17_GUARDED_EXECUTION_SCRIPT_DRAFT_ONLY"
authorize_execution = "NO"

required_system_bytes = find_int(phase16, ["required_system_bytes", "n1b_phase_16_required_system_bytes"])
system_current_bytes = find_int(phase16, ["system_current_bytes", "n1b_phase_16_system_current_bytes"])
system_target_bytes = find_int(phase16, ["system_target_bytes", "n1b_phase_16_system_target_bytes"])
system_growth_bytes = find_int(phase16, ["system_growth_bytes", "n1b_phase_16_system_growth_bytes"])
super_headroom = find_int(phase16, ["super_headroom_estimate_bytes", "n1b_phase_16_super_headroom_estimate_bytes"])
remaining_headroom = find_int(phase16, ["remaining_super_headroom_estimate_bytes", "n1b_phase_16_remaining_super_headroom_estimate_bytes"])

if "PASS" not in phase16_status:
    failures.append("PHASE16_NOT_PASS_REVIEW_DRAFT_READY")
if phase15_status and "READY" not in phase15_status and "PASS" not in phase15_status:
    failures.append("PHASE15_NOT_REVIEW_READY")
if phase14_state and "READY" not in phase14_state:
    failures.append("PHASE14_NOT_READY_FOR_MANUAL_AUTHORIZATION")
if required_system_bytes <= 0:
    failures.append("REQUIRED_SYSTEM_BYTES_MISSING")
if system_target_bytes <= required_system_bytes:
    failures.append("SYSTEM_TARGET_BYTES_NOT_ABOVE_REQUIRED")
if system_growth_bytes <= 0:
    failures.append("SYSTEM_GROWTH_BYTES_MISSING")
if remaining_headroom <= 0:
    failures.append("REMAINING_SUPER_HEADROOM_MISSING")

system_sha = ""
system_bytes = 0
if system_image_path is not None and system_image_path.is_file():
    h = hashlib.sha256()
    with system_image_path.open("rb") as fp:
        for chunk in iter(lambda: fp.read(1024 * 1024), b""):
            h.update(chunk)
    system_sha = h.hexdigest()
    system_bytes = system_image_path.stat().st_size
    if required_system_bytes and system_bytes != required_system_bytes:
        failures.append("SYSTEM_IMAGE_SIZE_MISMATCH_PHASE16_REQUIRED")

artifact_sha = find_value(artifact, ["sha256", "artifact_sha256", "expected_sha256"])
if artifact_sha and system_sha and artifact_sha != system_sha:
    warnings.append("ARTIFACT_SHA_FIELD_DID_NOT_MATCH_SYSTEM_IMAGE_SHA_OR_SCHEMA_AMBIGUOUS")

action_intents = [
    "VERIFY_OPERATOR_INTENT_AND_STOP_CONDITIONS",
    "VERIFY_RESTORE_PATH_AND_USERDATA_POLICY",
    "VERIFY_DEVICE_IDENTITY_FASTBOOTD_AND_ACTIVE_SLOT",
    "INTENT_ACTIVE_SYSTEM_LOGICAL_PARTITION_GROWTH",
    "INTENT_SYSTEM_IMAGE_DEPLOYMENT",
    "INTENT_AVB_CHAIN_DECISION",
    "INTENT_POST_CHANGE_ACCEPTANCE",
    "INTENT_ROLLBACK_OR_STOP",
]

intent_records = [
    {
        "order": index + 1,
        "action_id": name,
        "executable_command": "NO",
        "runnable_shell": "NO",
        "manual_execution_authorization_required": "YES",
        "operator_review_required": "YES",
        "stop_if_unmet": "YES",
    }
    for index, name in enumerate(action_intents)
]

status = "PASS_REVIEW_DRAFT_READY" if not failures else "BLOCKED_REVIEW_REQUIRED"

result = {
    "phase": "N1B_PHASE_17_GUARDED_EXECUTION_SCRIPT_DRAFT",
    "device": "titan2",
    "release": "N1B",
    "status": status,
    "owner_authorization": owner_auth,
    "authorize_execution": authorize_execution,
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
    "inputs": {
        "phase16_json": str(phase16_path) if phase16_path else "",
        "phase15_json": str(phase15_path) if phase15_path else "",
        "phase14_json": str(phase14_path) if phase14_path else "",
        "artifact_manifest": str(artifact_manifest_path) if artifact_manifest_path else "",
        "restore_report": str(restore_report_path) if restore_report_path else "",
        "system_image": str(system_image_path) if system_image_path else "",
    },
    "sizing": {
        "required_system_bytes": required_system_bytes,
        "system_current_bytes": system_current_bytes,
        "system_target_bytes": system_target_bytes,
        "system_growth_bytes": system_growth_bytes,
        "super_headroom_estimate_bytes": super_headroom,
        "remaining_super_headroom_estimate_bytes": remaining_headroom,
        "system_image_bytes": system_bytes,
        "system_image_sha256": system_sha,
    },
    "guarded_script_draft": str(draft_out),
    "action_intents": intent_records,
    "failures": failures,
    "warnings": warnings,
}

json_out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")

md_lines = [
    "# N1B Phase 17 Guarded Execution Script Draft",
    "",
    "This is a review-only draft. Execution is not authorized.",
    "",
    "```text",
    f"OWNER_AUTHORIZATION={owner_auth}",
    f"AUTHORIZE_EXECUTION={authorize_execution}",
    "DEVICE_CONTACT_AUTHORIZED=NO_OFFLINE_ONLY",
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
    f"REMAINING_SUPER_HEADROOM_ESTIMATE_BYTES={remaining_headroom}",
    "```",
    "",
    "## Action intents",
    "",
]
for item in intent_records:
    md_lines.extend([
        f"### {item['order']}. {item['action_id']}",
        "",
        "```text",
        "executable_command=NO",
        "runnable_shell=NO",
        "manual_execution_authorization_required=YES",
        "operator_review_required=YES",
        "stop_if_unmet=YES",
        "```",
        "",
    ])
md_lines.extend([
    "## Final state",
    "",
    "```text",
    f"N1B_PHASE_17_GUARDED_EXECUTION_SCRIPT_DRAFT={status}",
    "N1B_PHASE_17_AUTHORIZE_EXECUTION=NO",
    "```",
])
md_out.write_text("\n".join(md_lines) + "\n", encoding="utf-8")

draft_lines = [
    "#!/usr/bin/env bash",
    "# NON-RUNNABLE REVIEW DRAFT. DO NOT EXECUTE.",
    "# DRAFT_ONLY=YES",
    "# AUTHORIZE_EXECUTION=NO",
    "# RUNNABLE_SHELL=NO",
    "# DEVICE_CONTACT=NO",
    "# COMMAND_OUTPUTS_EXECUTABLE_COMMANDS=NO",
    "exit 97  # intentional: this artifact is not executable",
    "",
]
for item in intent_records:
    draft_lines.extend([
        f"# ACTION_INTENT_{item['order']}={item['action_id']}",
        "# executable_command=NO",
        "# runnable_shell=NO",
        "# manual_execution_authorization_required=YES",
        "# operator_review_required=YES",
        "# stop_if_unmet=YES",
        "",
    ])
draft_out.write_text("\n".join(draft_lines), encoding="utf-8")

print(f"N1B_PHASE_17_STATUS={status}")
print(f"N1B_PHASE_17_OWNER_AUTHORIZATION={owner_auth}")
print(f"N1B_PHASE_17_AUTHORIZE_EXECUTION={authorize_execution}")
print(f"N1B_PHASE_17_REQUIRED_SYSTEM_BYTES={required_system_bytes}")
print(f"N1B_PHASE_17_SYSTEM_CURRENT_BYTES={system_current_bytes}")
print(f"N1B_PHASE_17_SYSTEM_TARGET_BYTES={system_target_bytes}")
print(f"N1B_PHASE_17_SYSTEM_GROWTH_BYTES={system_growth_bytes}")
print(f"N1B_PHASE_17_SUPER_HEADROOM_ESTIMATE_BYTES={super_headroom}")
print(f"N1B_PHASE_17_REMAINING_SUPER_HEADROOM_ESTIMATE_BYTES={remaining_headroom}")
print("N1B_PHASE_17_FLASH_AUTHORIZED=NO")
print("N1B_PHASE_17_FLASH_ALLOWED=NO")
print("N1B_PHASE_17_LP_MUTATION_ALLOWED=NO")
print("N1B_PHASE_17_AVB_MUTATION_ALLOWED=NO")
print("N1B_PHASE_17_SLOT_MUTATION_ALLOWED=NO")
print("COMMAND_OUTPUTS_EXECUTABLE_COMMANDS=NO")
for item in failures:
    print(f"N1B_PHASE_17_FAILURE={item}")
for item in warnings:
    print(f"N1B_PHASE_17_WARNING={item}")
print(f"N1B_PHASE_17_DRAFT_JSON={json_out}")
print(f"N1B_PHASE_17_DRAFT_MARKDOWN={md_out}")
print(f"N1B_PHASE_17_DRAFT_SCRIPT={draft_out}")
print(f"N1B_PHASE_17_GUARDED_EXECUTION_SCRIPT_DRAFT={status}")
PY

echo "===== N1B PHASE 17 GUARDED EXECUTION SCRIPT DRAFT RESULT ====="
echo "N1B_PHASE_17_DEVICE_CONTACT=NO_OFFLINE_ONLY"
echo "N1B_PHASE_17_EVIDENCE_DIR=$EVIDENCE_DIR"
