#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVIDENCE_ROOT="${SABLE_N1B_PHASE_18_EVIDENCE_ROOT:-/srv/data/sable-build/evidence/titan2/n1b-phase-18-cross-repo-flash-readiness}"
STAMP="$(date -u +%Y%m%d_%H%M%S)"
EVIDENCE_DIR="$EVIDENCE_ROOT/$STAMP/offline-cross-repo-review"

PHASE17_JSON=""
PHASE17_DRAFT_SCRIPT=""

usage() {
  cat >&2 <<'EOF'
usage:
  bash build/titan2/qualify-n1b-phase-18-cross-repo-flash-readiness.sh \
    --phase17-json <path> \
    --phase17-draft-script <path>

This is an offline cross-repo flash-readiness review gate.
It does not contact the device, run adb/fastboot, reboot, flash, erase, unlock,
resize LP metadata, mutate AVB, change slots, or emit runnable commands.
EOF
}

while (($#)); do
  case "$1" in
    --phase17-json) PHASE17_JSON="$2"; shift 2 ;;
    --phase17-draft-script) PHASE17_DRAFT_SCRIPT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "N1B_PHASE_18_CROSS_REPO_FLASH_READINESS=FAIL_UNKNOWN_ARG arg=$1" >&2; usage; exit 64 ;;
  esac
done

mkdir -p "$EVIDENCE_DIR"
LOG="$EVIDENCE_DIR/phase18-cross-repo-flash-readiness.log"
JSON_OUT="$EVIDENCE_DIR/phase18-cross-repo-flash-readiness.json"
exec > >(tee "$LOG") 2>&1

echo "===== N1B PHASE 18 TITAN2 CROSS-REPO FLASH READINESS ====="
echo "ROOT=$ROOT"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "DEVICE=titan2"
echo "RELEASE=N1B"
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

python3 - "$PHASE17_JSON" "$PHASE17_DRAFT_SCRIPT" "$JSON_OUT" <<'PY'
from __future__ import annotations

import json
import pathlib
import sys
from typing import Any

phase17_json = pathlib.Path(sys.argv[1]) if sys.argv[1] else None
phase17_script = pathlib.Path(sys.argv[2]) if sys.argv[2] else None
json_out = pathlib.Path(sys.argv[3])

failures: list[str] = []
warnings: list[str] = []

if phase17_json is None or not phase17_json.is_file():
    failures.append(f"MISSING_PHASE17_JSON:{phase17_json}")
if phase17_script is None or not phase17_script.is_file():
    failures.append(f"MISSING_PHASE17_DRAFT_SCRIPT:{phase17_script}")

phase17: Any = {}
if phase17_json is not None and phase17_json.is_file():
    try:
        phase17 = json.loads(phase17_json.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        failures.append(f"PHASE17_JSON_READ_FAIL:{exc}")


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

phase17_status = find_value(phase17, ["status", "n1b_phase_17_status"])
authorize_execution = find_value(phase17, ["authorize_execution"])
flash_authorized = find_value(phase17, ["flash_authorized"])
lp_mutation_authorized = find_value(phase17, ["lp_mutation_authorized", "lp_mutation_allowed"])
command_outputs = find_value(phase17, ["command_outputs_executable_commands"])

if "PASS_REVIEW_DRAFT_READY" not in phase17_status:
    failures.append("PHASE17_NOT_PASS_REVIEW_DRAFT_READY")
if authorize_execution and authorize_execution != "NO":
    failures.append("PHASE17_AUTHORIZE_EXECUTION_NOT_NO")
if flash_authorized and flash_authorized != "NO":
    failures.append("PHASE17_FLASH_AUTHORIZED_NOT_NO")
if lp_mutation_authorized and lp_mutation_authorized not in {"NO", "False", "false", "0"}:
    failures.append("PHASE17_LP_MUTATION_NOT_NO")
if command_outputs and command_outputs != "NO":
    failures.append("PHASE17_COMMAND_OUTPUTS_EXECUTABLE_NOT_NO")

if phase17_script is not None and phase17_script.is_file():
    text = phase17_script.read_text(encoding="utf-8", errors="replace")
    if "exit 97" not in text:
        failures.append("PHASE17_DRAFT_SCRIPT_DOES_NOT_EXIT_IMMEDIATELY")
    if "AUTHORIZE_EXECUTION=NO" not in text:
        failures.append("PHASE17_DRAFT_SCRIPT_MISSING_NO_EXECUTION_MARKER")
    forbidden = [
        "fastboot flash",
        "fastboot erase",
        "fastboot reboot",
        "fastboot resize-logical-partition",
        "fastboot delete-logical-partition",
        "fastboot create-logical-partition",
        "adb reboot",
        "adb shell",
    ]
    for token in forbidden:
        if token in text and not text.strip().startswith("#"):
            failures.append(f"PHASE17_DRAFT_SCRIPT_FORBIDDEN_TOKEN:{token}")

result = {
    "phase": "N1B_PHASE_18_CROSS_REPO_FLASH_READINESS",
    "device": "titan2",
    "release": "N1B",
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
    "phase17_review_draft_valid": "YES" if not failures else "NO",
    "cross_repo_flash_execution_ready": "NO",
    "write_capable_flash_plan_exists": "NO",
    "exact_command_sequence_reviewed": "NO",
    "final_state": "BLOCKED_WRITE_CAPABLE_PLAN_REQUIRED",
    "allowed_next_phase": "PHASE_19_WRITE_CAPABLE_FLASH_PLAN_PR_ONLY",
    "recommended_owner_decision": "APPROVE_PHASE_19_WRITE_CAPABLE_FLASH_PLAN_PR_ONLY",
    "authorize_execution": "NO",
    "failures": failures,
    "warnings": warnings,
}
json_out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")

print(f"N1B_PHASE_18_PHASE17_STATUS_DETECTED={phase17_status}")
print(f"N1B_PHASE_18_PHASE17_REVIEW_DRAFT_VALID={result['phase17_review_draft_valid']}")
print("N1B_PHASE_18_CROSS_REPO_FLASH_EXECUTION_READY=NO")
print("N1B_PHASE_18_WRITE_CAPABLE_FLASH_PLAN_EXISTS=NO")
print("N1B_PHASE_18_EXACT_COMMAND_SEQUENCE_REVIEWED=NO")
print("N1B_PHASE_18_FLASH_AUTHORIZED=NO")
print("N1B_PHASE_18_LP_MUTATION_ALLOWED=NO")
print("N1B_PHASE_18_AVB_MUTATION_ALLOWED=NO")
print("COMMAND_OUTPUTS_EXECUTABLE_COMMANDS=NO")
for item in failures:
    print(f"N1B_PHASE_18_FAILURE={item}")
for item in warnings:
    print(f"N1B_PHASE_18_WARNING={item}")
print(f"N1B_PHASE_18_REVIEW_JSON={json_out}")
print("N1B_PHASE_18_CROSS_REPO_FLASH_READINESS=BLOCKED_WRITE_CAPABLE_PLAN_REQUIRED")
PY

echo "===== N1B PHASE 18 CROSS-REPO FLASH READINESS RESULT ====="
echo "N1B_PHASE_18_DEVICE_CONTACT=NO_OFFLINE_ONLY"
echo "N1B_PHASE_18_EVIDENCE_DIR=$EVIDENCE_DIR"
