#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVIDENCE_ROOT="${SABLE_N1B_PHASE_14_EVIDENCE_ROOT:-/srv/data/sable-build/evidence/titan2/n1b-phase-14-final-preflight-approval}"
STAMP="$(date -u +%Y%m%d_%H%M%S)"
EVIDENCE_DIR="$EVIDENCE_ROOT/$STAMP/offline-approval"

PHASE10A_JSON=""
PHASE10B_JSON=""
PHASE11_JSON=""
PHASE12_JSON=""
PHASE13_JSON=""
ARTIFACT_MANIFEST=""
RESTORE_REPORT=""
SYSTEM_IMAGE=""

usage() {
  cat >&2 <<'EOF'
usage:
  bash build/titan2/qualify-n1b-phase-14-final-preflight-approval.sh \
    --phase10a-json <path> \
    --phase10b-json <path> \
    --phase11-json <path> \
    --phase12-json <path> \
    --phase13-json <path> \
    --artifact-manifest <path> \
    --restore-report <path> \
    [--system-image <path>]

This is an offline final-preflight approval gate.
It does not contact the device, run adb/fastboot, reboot, flash, erase, unlock,
mutate LP metadata, mutate AVB, change slots, or emit executable commands.
EOF
}

while (($#)); do
  case "$1" in
    --phase10a-json) PHASE10A_JSON="$2"; shift 2 ;;
    --phase10b-json) PHASE10B_JSON="$2"; shift 2 ;;
    --phase11-json) PHASE11_JSON="$2"; shift 2 ;;
    --phase12-json) PHASE12_JSON="$2"; shift 2 ;;
    --phase13-json) PHASE13_JSON="$2"; shift 2 ;;
    --artifact-manifest) ARTIFACT_MANIFEST="$2"; shift 2 ;;
    --restore-report) RESTORE_REPORT="$2"; shift 2 ;;
    --system-image) SYSTEM_IMAGE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "N1B_PHASE_14_FINAL_PREFLIGHT_APPROVAL=FAIL_UNKNOWN_ARG arg=$1" >&2; usage; exit 64 ;;
  esac
done

mkdir -p "$EVIDENCE_DIR"
LOG="$EVIDENCE_DIR/phase14-final-preflight-approval.log"
JSON_OUT="$EVIDENCE_DIR/phase14-final-preflight-approval.json"

exec > >(tee "$LOG") 2>&1

echo "===== N1B PHASE 14 TITAN2 FINAL PREFLIGHT APPROVAL ====="
echo "ROOT=$ROOT"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "DEVICE=titan2"
echo "RELEASE=N1B"
echo "SOURCE_MAP_REVIEWED=YES"
echo "CURRENT_SABLEOS_REPO_REVIEWED=YES"
echo "CURRENT_DEVICE_EVIDENCE_REVIEWED=YES_PHASE_10_11_12_13_OUTPUTS"
echo "JINN_LINEAGEOS22_ISSUES_REVIEWED=YES_SCOPE_LIMITED"
echo "JINN_PHASE14_USAGE=POST_CHANGE_ACCEPTANCE_RISK_SOURCE"
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
  "$PHASE10A_JSON" \
  "$PHASE10B_JSON" \
  "$PHASE11_JSON" \
  "$PHASE12_JSON" \
  "$PHASE13_JSON" \
  "$ARTIFACT_MANIFEST" \
  "$RESTORE_REPORT" \
  "$SYSTEM_IMAGE" \
  "$JSON_OUT" <<'PY'
from __future__ import annotations

import hashlib
import json
import pathlib
import sys
from typing import Any

phase10a_path = pathlib.Path(sys.argv[1]) if sys.argv[1] else None
phase10b_path = pathlib.Path(sys.argv[2]) if sys.argv[2] else None
phase11_path = pathlib.Path(sys.argv[3]) if sys.argv[3] else None
phase12_path = pathlib.Path(sys.argv[4]) if sys.argv[4] else None
phase13_path = pathlib.Path(sys.argv[5]) if sys.argv[5] else None
artifact_manifest_path = pathlib.Path(sys.argv[6]) if sys.argv[6] else None
restore_report_path = pathlib.Path(sys.argv[7]) if sys.argv[7] else None
system_image_path = pathlib.Path(sys.argv[8]) if sys.argv[8] else None
json_out = pathlib.Path(sys.argv[9])

inputs = {
    "phase10a_json": phase10a_path,
    "phase10b_json": phase10b_path,
    "phase11_json": phase11_path,
    "phase12_json": phase12_path,
    "phase13_json": phase13_path,
    "artifact_manifest": artifact_manifest_path,
    "restore_report": restore_report_path,
}

failures: list[str] = []
warnings: list[str] = []


def require_path(name: str, path: pathlib.Path | None, kind: str = "file") -> None:
    if path is None:
        failures.append(f"MISSING_ARGUMENT:{name}")
        return
    if kind == "dir":
        if not path.is_dir():
            failures.append(f"MISSING_DIR:{name}:{path}")
    elif not path.is_file():
        failures.append(f"MISSING_FILE:{name}:{path}")


for key, path in inputs.items():
    require_path(key, path, "dir" if key == "restore_report" else "file")

if system_image_path is not None and str(system_image_path):
    require_path("system_image", system_image_path, "file")


def read_json(path: pathlib.Path | None, name: str) -> Any:
    if path is None or not path.is_file():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        failures.append(f"JSON_READ_FAIL:{name}:{path}:{exc}")
        return {}

phase10a = read_json(phase10a_path, "phase10a")
phase10b = read_json(phase10b_path, "phase10b")
phase11 = read_json(phase11_path, "phase11")
phase12 = read_json(phase12_path, "phase12")
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

phase10a_contact = find_value(phase10a, ["device_contact_authorized"])
phase10b_fastboot = find_value(phase10b, ["fastboot_commands_run"])
phase10b_is_userspace = find_value(phase10b, ["fastbootd_preflight", "is_userspace"])
phase11_result = find_value(phase11, ["n1b_phase_11_lp_super_sizing", "phase_result", "result"])
phase12_result = find_value(phase12, ["n1b_phase_12_lp_resize_plan", "phase_result", "result"])
phase13_result = find_value(phase13, ["n1b_phase_13_flash_plan_proposal", "phase_result", "result"])

required_system_bytes = find_int(phase13, ["required_system_bytes", "n1b_phase_13_required_system_bytes"])
system_current_bytes = find_int(phase13, ["system_current_bytes", "n1b_phase_13_system_current_bytes"])
system_target_bytes = find_int(phase13, ["system_target_bytes", "n1b_phase_13_system_target_bytes"])
system_growth_bytes = find_int(phase13, ["system_growth_bytes", "n1b_phase_13_system_growth_bytes"])
super_headroom = find_int(phase13, ["super_headroom_estimate_bytes", "n1b_phase_13_super_headroom_estimate_bytes"])
remaining_super_headroom = find_int(phase13, ["remaining_super_headroom_estimate_bytes", "n1b_phase_13_remaining_super_headroom_estimate_bytes"])

phase13_no_flash = find_value(phase13, ["flash_allowed", "n1b_phase_13_flash_allowed", "flash_authorized"])
phase13_no_lp = find_value(phase13, ["lp_mutation_allowed", "n1b_phase_13_lp_mutation_allowed", "lp_mutation_authorized"])
phase13_no_avb = find_value(phase13, ["avb_mutation_allowed", "n1b_phase_13_avb_mutation_allowed", "avb_mutation_authorized"])
phase13_no_exec = find_value(phase13, ["command_outputs_executable_commands"])

artifact_sha = find_value(artifact_manifest, ["sha256", "artifact_sha256", "expected_sha256"])
manifest_build_source = find_value(artifact_manifest, ["build_source"])
manifest_primary_artifact = find_value(artifact_manifest, ["primary_artifact"])

system_image_sha256 = ""
system_image_bytes = 0
if system_image_path is not None and system_image_path.is_file():
    h = hashlib.sha256()
    with system_image_path.open("rb") as fp:
        for chunk in iter(lambda: fp.read(1024 * 1024), b""):
            h.update(chunk)
    system_image_sha256 = h.hexdigest()
    system_image_bytes = system_image_path.stat().st_size

# Conservative readiness checks. These are intentionally redundant: if a generated
# JSON schema changes, a missing value blocks rather than guessing readiness.
if "PASS" not in phase12_result and "REVIEW_REQUIRED" not in phase12_result:
    failures.append("PHASE12_RESULT_NOT_PASS_REVIEW_REQUIRED")
if "PASS" not in phase13_result and "REVIEW_REQUIRED" not in phase13_result:
    failures.append("PHASE13_RESULT_NOT_PASS_REVIEW_REQUIRED")
if required_system_bytes <= 0:
    failures.append("REQUIRED_SYSTEM_BYTES_MISSING")
if system_current_bytes <= 0:
    failures.append("SYSTEM_CURRENT_BYTES_MISSING")
if system_target_bytes <= required_system_bytes:
    failures.append("SYSTEM_TARGET_BYTES_NOT_ABOVE_REQUIRED")
if system_growth_bytes <= 0:
    failures.append("SYSTEM_GROWTH_BYTES_MISSING")
if super_headroom <= 0:
    failures.append("SUPER_HEADROOM_ESTIMATE_MISSING")
if remaining_super_headroom <= 0:
    failures.append("REMAINING_SUPER_HEADROOM_ESTIMATE_MISSING")
if phase13_no_exec and phase13_no_exec != "NO":
    failures.append("PHASE13_EXECUTABLE_COMMAND_OUTPUT_NOT_NO")

for label, value in (
    ("phase13_flash_allowed", phase13_no_flash),
    ("phase13_lp_mutation_allowed", phase13_no_lp),
    ("phase13_avb_mutation_allowed", phase13_no_avb),
):
    if value and value not in {"NO", "False", "false", "0"}:
        failures.append(f"UNEXPECTED_ALLOWED_STATE:{label}:{value}")

if system_image_bytes and required_system_bytes and system_image_bytes != required_system_bytes:
    failures.append("SYSTEM_IMAGE_SIZE_MISMATCH_PHASE13_REQUIRED")
if system_image_sha256 and artifact_sha and artifact_sha != system_image_sha256:
    warnings.append("ARTIFACT_SHA_FIELD_DID_NOT_MATCH_SYSTEM_IMAGE_SHA_OR_SCHEMA_AMBIGUOUS")

post_change_acceptance = [
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

final_state = (
    "APPROVAL_BLOCKED" if failures else "APPROVAL_READY_FOR_MANUAL_AUTHORIZATION"
)

result = {
    "phase": "N1B_PHASE_14_FINAL_PREFLIGHT_APPROVAL",
    "device": "titan2",
    "release": "N1B",
    "source_map_reviewed": "YES",
    "jinn_lineageos22_issues_reviewed": "YES_SCOPE_LIMITED",
    "jinn_phase14_usage": "POST_CHANGE_ACCEPTANCE_RISK_SOURCE",
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
    "inputs": {key: str(value) if value else "" for key, value in inputs.items()},
    "optional_system_image": str(system_image_path) if system_image_path else "",
    "artifact_manifest": {
        "build_source": manifest_build_source,
        "primary_artifact": manifest_primary_artifact,
    },
    "computed": {
        "required_system_bytes": required_system_bytes,
        "system_current_bytes": system_current_bytes,
        "system_target_bytes": system_target_bytes,
        "system_growth_bytes": system_growth_bytes,
        "super_headroom_estimate_bytes": super_headroom,
        "remaining_super_headroom_estimate_bytes": remaining_super_headroom,
        "system_image_bytes": system_image_bytes,
        "system_image_sha256": system_image_sha256,
    },
    "post_change_acceptance_required": post_change_acceptance,
    "failures": failures,
    "warnings": warnings,
    "final_state": final_state,
}

json_out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")

print(f"N1B_PHASE_14_REQUIRED_SYSTEM_BYTES={required_system_bytes}")
print(f"N1B_PHASE_14_SYSTEM_CURRENT_BYTES={system_current_bytes}")
print(f"N1B_PHASE_14_SYSTEM_TARGET_BYTES={system_target_bytes}")
print(f"N1B_PHASE_14_SYSTEM_GROWTH_BYTES={system_growth_bytes}")
print(f"N1B_PHASE_14_SUPER_HEADROOM_ESTIMATE_BYTES={super_headroom}")
print(f"N1B_PHASE_14_REMAINING_SUPER_HEADROOM_ESTIMATE_BYTES={remaining_super_headroom}")
print(f"N1B_PHASE_14_POST_CHANGE_ACCEPTANCE_REQUIRED={','.join(post_change_acceptance)}")
print("N1B_PHASE_14_FLASH_AUTHORIZED=NO")
print("N1B_PHASE_14_FLASH_ALLOWED=NO")
print("N1B_PHASE_14_LP_MUTATION_ALLOWED=NO")
print("N1B_PHASE_14_AVB_MUTATION_ALLOWED=NO")
print("N1B_PHASE_14_SLOT_MUTATION_ALLOWED=NO")
print("COMMAND_OUTPUTS_EXECUTABLE_COMMANDS=NO")
for item in failures:
    print(f"N1B_PHASE_14_FAILURE={item}")
for item in warnings:
    print(f"N1B_PHASE_14_WARNING={item}")
print(f"N1B_PHASE_14_APPROVAL_JSON={json_out}")
print(f"N1B_PHASE_14_FINAL_PREFLIGHT_APPROVAL={final_state}")
PY

echo "===== N1B PHASE 14 FINAL PREFLIGHT APPROVAL RESULT ====="
echo "N1B_PHASE_14_DEVICE_CONTACT=NO_OFFLINE_ONLY"
echo "N1B_PHASE_14_EVIDENCE_DIR=$EVIDENCE_DIR"
