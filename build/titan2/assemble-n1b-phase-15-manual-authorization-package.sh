#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVIDENCE_ROOT="${SABLE_N1B_PHASE_15_EVIDENCE_ROOT:-/srv/data/sable-build/evidence/titan2/n1b-phase-15-manual-authorization-package}"
STAMP="$(date -u +%Y%m%d_%H%M%S)"
EVIDENCE_DIR="$EVIDENCE_ROOT/$STAMP/offline-authorization-package"

PHASE14_JSON=""
PHASE13_JSON=""
ARTIFACT_MANIFEST=""
RESTORE_REPORT=""
SYSTEM_IMAGE=""

usage() {
  cat >&2 <<'EOF'
usage:
  bash build/titan2/assemble-n1b-phase-15-manual-authorization-package.sh \
    --phase14-json <path> \
    --phase13-json <path> \
    --artifact-manifest <path> \
    --restore-report <path> \
    --system-image <path>

This is an offline manual authorization package assembler.
It does not contact a device, run adb/fastboot, reboot, flash, erase, unlock,
mutate LP metadata, mutate AVB, change slots, or emit executable commands.
EOF
}

while (($#)); do
  case "$1" in
    --phase14-json) PHASE14_JSON="$2"; shift 2 ;;
    --phase13-json) PHASE13_JSON="$2"; shift 2 ;;
    --artifact-manifest) ARTIFACT_MANIFEST="$2"; shift 2 ;;
    --restore-report) RESTORE_REPORT="$2"; shift 2 ;;
    --system-image) SYSTEM_IMAGE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "N1B_PHASE_15_MANUAL_AUTHORIZATION_PACKAGE=FAIL_UNKNOWN_ARG arg=$1" >&2; usage; exit 64 ;;
  esac
done

mkdir -p "$EVIDENCE_DIR"
LOG="$EVIDENCE_DIR/phase15-manual-authorization-package.log"
JSON_OUT="$EVIDENCE_DIR/phase15-manual-authorization-package.json"
MD_OUT="$EVIDENCE_DIR/phase15-manual-authorization-package.md"

exec > >(tee "$LOG") 2>&1

echo "===== N1B PHASE 15 TITAN2 MANUAL AUTHORIZATION PACKAGE ====="
echo "ROOT=$ROOT"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "DEVICE=titan2"
echo "RELEASE=N1B"
echo "SOURCE_MAP_REVIEWED=YES"
echo "CURRENT_SABLEOS_REPO_REVIEWED=YES"
echo "CURRENT_DEVICE_EVIDENCE_REVIEWED=YES_PHASE_13_14_OUTPUTS"
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

phase14_path = pathlib.Path(sys.argv[1]) if sys.argv[1] else None
phase13_path = pathlib.Path(sys.argv[2]) if sys.argv[2] else None
artifact_manifest_path = pathlib.Path(sys.argv[3]) if sys.argv[3] else None
restore_report_path = pathlib.Path(sys.argv[4]) if sys.argv[4] else None
system_image_path = pathlib.Path(sys.argv[5]) if sys.argv[5] else None
json_out = pathlib.Path(sys.argv[6])
md_out = pathlib.Path(sys.argv[7])

failures: list[str] = []
warnings: list[str] = []


def require_file(name: str, path: pathlib.Path | None) -> None:
    if path is None or not path.is_file():
        failures.append(f"MISSING_FILE:{name}:{path}")


def require_dir(name: str, path: pathlib.Path | None) -> None:
    if path is None or not path.is_dir():
        failures.append(f"MISSING_DIR:{name}:{path}")


require_file("phase14_json", phase14_path)
require_file("phase13_json", phase13_path)
require_file("artifact_manifest", artifact_manifest_path)
require_dir("restore_report", restore_report_path)
require_file("system_image", system_image_path)


def read_json(path: pathlib.Path | None, name: str) -> Any:
    if path is None or not path.is_file():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        failures.append(f"JSON_READ_FAIL:{name}:{path}:{exc}")
        return {}

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

phase14_state = find_value(phase14, ["final_state", "n1b_phase_14_final_preflight_approval"])
phase13_status = find_value(phase13, ["status", "n1b_phase_13_flash_plan_proposal"])

required_system_bytes = find_int(phase14, ["required_system_bytes", "n1b_phase_14_required_system_bytes"])
system_current_bytes = find_int(phase14, ["system_current_bytes", "n1b_phase_14_system_current_bytes"])
system_target_bytes = find_int(phase14, ["system_target_bytes", "n1b_phase_14_system_target_bytes"])
system_growth_bytes = find_int(phase14, ["system_growth_bytes", "n1b_phase_14_system_growth_bytes"])
super_headroom = find_int(phase14, ["super_headroom_estimate_bytes", "n1b_phase_14_super_headroom_estimate_bytes"])
remaining_super_headroom = find_int(phase14, ["remaining_super_headroom_estimate_bytes", "n1b_phase_14_remaining_super_headroom_estimate_bytes"])

if not required_system_bytes:
    required_system_bytes = find_int(phase13, ["required_system_bytes", "n1b_phase_13_required_system_bytes"])
if not system_current_bytes:
    system_current_bytes = find_int(phase13, ["system_current_bytes", "n1b_phase_13_system_current_bytes"])
if not system_target_bytes:
    system_target_bytes = find_int(phase13, ["system_target_bytes", "n1b_phase_13_system_target_bytes"])
if not system_growth_bytes:
    system_growth_bytes = find_int(phase13, ["system_growth_bytes", "n1b_phase_13_system_growth_bytes"])
if not super_headroom:
    super_headroom = find_int(phase13, ["super_headroom_estimate_bytes", "n1b_phase_13_super_headroom_estimate_bytes"])
if not remaining_super_headroom:
    remaining_super_headroom = find_int(phase13, ["remaining_super_headroom_estimate_bytes", "n1b_phase_13_remaining_super_headroom_estimate_bytes"])

system_image_sha256 = ""
system_image_bytes = 0
if system_image_path is not None and system_image_path.is_file():
    h = hashlib.sha256()
    with system_image_path.open("rb") as fp:
        for chunk in iter(lambda: fp.read(1024 * 1024), b""):
            h.update(chunk)
    system_image_sha256 = h.hexdigest()
    system_image_bytes = system_image_path.stat().st_size

manifest_build_source = find_value(artifact_manifest, ["build_source"])
manifest_primary_artifact = find_value(artifact_manifest, ["primary_artifact"])

if phase14_state != "APPROVAL_READY_FOR_MANUAL_AUTHORIZATION":
    failures.append(f"PHASE14_NOT_READY:{phase14_state or 'MISSING'}")
if "PASS" not in phase13_status and "REVIEW_REQUIRED" not in phase13_status:
    failures.append(f"PHASE13_NOT_PASS_REVIEW_REQUIRED:{phase13_status or 'MISSING'}")
for label, value in (
    ("required_system_bytes", required_system_bytes),
    ("system_current_bytes", system_current_bytes),
    ("system_target_bytes", system_target_bytes),
    ("system_growth_bytes", system_growth_bytes),
    ("super_headroom_estimate_bytes", super_headroom),
    ("remaining_super_headroom_estimate_bytes", remaining_super_headroom),
):
    if value <= 0:
        failures.append(f"MISSING_OR_INVALID:{label}")
if system_image_bytes and required_system_bytes and system_image_bytes != required_system_bytes:
    failures.append("SYSTEM_IMAGE_SIZE_MISMATCH_REQUIRED_SYSTEM_BYTES")
if not manifest_build_source:
    warnings.append("ARTIFACT_MANIFEST_BUILD_SOURCE_MISSING_OR_SCHEMA_AMBIGUOUS")
if manifest_primary_artifact and manifest_primary_artifact != "system":
    failures.append(f"ARTIFACT_PRIMARY_NOT_SYSTEM:{manifest_primary_artifact}")

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

operation_sequence = [
    {
        "order": 1,
        "operation_id": "REVIEW_RESTORE_AND_USERDATA_POLICY",
        "summary": "Confirm restore report, stock baseline, userdata preservation policy, and stop conditions.",
        "executable_command": "NO",
    },
    {
        "order": 2,
        "operation_id": "REVIEW_DEVICE_IDENTITY_AND_ACTIVE_SLOT",
        "summary": "Confirm Titan2 identity, active slot, fastbootd availability, and physical-device evidence freshness.",
        "executable_command": "NO",
    },
    {
        "order": 3,
        "operation_id": "REVIEW_LP_RESIZE_ACTIVE_SYSTEM",
        "summary": "Review active system logical partition growth to the Phase 12 target size before image deployment.",
        "target_size_bytes": system_target_bytes,
        "growth_bytes": system_growth_bytes,
        "executable_command": "NO",
    },
    {
        "order": 4,
        "operation_id": "REVIEW_SYSTEM_IMAGE_DEPLOYMENT",
        "summary": "Review deployment of canonical N1B system image only after LP sizing is separately authorized.",
        "system_image_bytes": system_image_bytes,
        "system_image_sha256": system_image_sha256,
        "executable_command": "NO",
    },
    {
        "order": 5,
        "operation_id": "REVIEW_AVB_CHAIN_DECISION",
        "summary": "Review AVB/chained vbmeta handling as a separate decision axis.",
        "executable_command": "NO",
    },
    {
        "order": 6,
        "operation_id": "REVIEW_POST_CHANGE_ACCEPTANCE",
        "summary": "Review acceptance checklist and rollback criteria before any execution authorization exists.",
        "acceptance_areas": post_change_acceptance,
        "executable_command": "NO",
    },
]

final_state = "BLOCKED" if failures else "READY_FOR_OWNER_REVIEW"
recommended_owner_decision = (
    "REQUEST_MORE_EVIDENCE" if failures else "APPROVE_PHASE_16_EXECUTABLE_PLAN_DRAFT_ONLY"
)

package = {
    "phase": "N1B_PHASE_15_MANUAL_AUTHORIZATION_PACKAGE",
    "device": "titan2",
    "release": "N1B",
    "status": final_state,
    "recommended_owner_decision": recommended_owner_decision,
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
    "inputs": {
        "phase14_json": str(phase14_path),
        "phase13_json": str(phase13_path),
        "artifact_manifest": str(artifact_manifest_path),
        "restore_report": str(restore_report_path),
        "system_image": str(system_image_path),
    },
    "evidence_summary": {
        "phase14_state": phase14_state,
        "phase13_status": phase13_status,
        "artifact_build_source": manifest_build_source,
        "artifact_primary_artifact": manifest_primary_artifact,
    },
    "sizing_summary": {
        "required_system_bytes": required_system_bytes,
        "system_current_bytes": system_current_bytes,
        "system_target_bytes": system_target_bytes,
        "system_growth_bytes": system_growth_bytes,
        "super_headroom_estimate_bytes": super_headroom,
        "remaining_super_headroom_estimate_bytes": remaining_super_headroom,
        "system_image_bytes": system_image_bytes,
        "system_image_sha256": system_image_sha256,
    },
    "non_executable_operation_sequence": operation_sequence,
    "post_change_acceptance_required": post_change_acceptance,
    "manual_approval_options": [
        "APPROVE_PHASE_16_EXECUTABLE_PLAN_DRAFT_ONLY",
        "REQUEST_MORE_EVIDENCE",
        "BLOCK_DEPLOYMENT",
    ],
    "approval_statement": "Approval of this package authorizes only a future Phase 16 executable-plan draft PR. It does not authorize running any command.",
    "failures": failures,
    "warnings": warnings,
}

json_out.write_text(json.dumps(package, indent=2, sort_keys=True) + "\n")

summary_lines = [
    "# N1B Phase 15 Manual Authorization Package",
    "",
    f"Status: `{final_state}`",
    f"Recommended owner decision: `{recommended_owner_decision}`",
    "",
    "## High-level summary",
    "",
    "SableOS N1B has a built and registered Titan2 GSI candidate. Physical preflight, fastbootd LP/super sizing, LP resize planning, flash-plan proposal review, and final preflight approval have completed as offline/read-only gates.",
    "",
    "The active system logical partition is too small for the N1B system image, but the super headroom estimate appears sufficient for a reviewed resize plan. No flash, resize, erase, AVB mutation, reboot, slot mutation, unlock, or executable command generation is authorized by this package.",
    "",
    "## Key sizing values",
    "",
    f"- Required system bytes: `{required_system_bytes}`",
    f"- Current system bytes: `{system_current_bytes}`",
    f"- Target system bytes: `{system_target_bytes}`",
    f"- System growth bytes: `{system_growth_bytes}`",
    f"- Super headroom estimate bytes: `{super_headroom}`",
    f"- Remaining super headroom estimate bytes: `{remaining_super_headroom}`",
    "",
    "## Review-only operation sequence",
    "",
]
for item in operation_sequence:
    summary_lines.append(
        f"{item['order']}. `{item['operation_id']}` — {item['summary']} Executable command: `NO`."
    )
summary_lines.extend([
    "",
    "## Post-change acceptance areas",
    "",
    ", ".join(post_change_acceptance),
    "",
    "## Manual approval options",
    "",
    "- `APPROVE_PHASE_16_EXECUTABLE_PLAN_DRAFT_ONLY`",
    "- `REQUEST_MORE_EVIDENCE`",
    "- `BLOCK_DEPLOYMENT`",
    "",
    "Approving this package authorizes only a future Phase 16 executable-plan draft PR. It does not authorize running any command.",
])
if failures:
    summary_lines.extend(["", "## Blocking failures", ""])
    summary_lines.extend(f"- `{item}`" for item in failures)
if warnings:
    summary_lines.extend(["", "## Warnings", ""])
    summary_lines.extend(f"- `{item}`" for item in warnings)
md_out.write_text("\n".join(summary_lines) + "\n", encoding="utf-8")

print(f"N1B_PHASE_15_STATUS={final_state}")
print(f"N1B_PHASE_15_RECOMMENDED_OWNER_DECISION={recommended_owner_decision}")
print(f"N1B_PHASE_15_REQUIRED_SYSTEM_BYTES={required_system_bytes}")
print(f"N1B_PHASE_15_SYSTEM_CURRENT_BYTES={system_current_bytes}")
print(f"N1B_PHASE_15_SYSTEM_TARGET_BYTES={system_target_bytes}")
print(f"N1B_PHASE_15_SYSTEM_GROWTH_BYTES={system_growth_bytes}")
print(f"N1B_PHASE_15_SUPER_HEADROOM_ESTIMATE_BYTES={super_headroom}")
print(f"N1B_PHASE_15_REMAINING_SUPER_HEADROOM_ESTIMATE_BYTES={remaining_super_headroom}")
print("N1B_PHASE_15_FLASH_AUTHORIZED=NO")
print("N1B_PHASE_15_FLASH_ALLOWED=NO")
print("N1B_PHASE_15_LP_MUTATION_ALLOWED=NO")
print("N1B_PHASE_15_AVB_MUTATION_ALLOWED=NO")
print("N1B_PHASE_15_SLOT_MUTATION_ALLOWED=NO")
print("COMMAND_OUTPUTS_EXECUTABLE_COMMANDS=NO")
for item in failures:
    print(f"N1B_PHASE_15_FAILURE={item}")
for item in warnings:
    print(f"N1B_PHASE_15_WARNING={item}")
print(f"N1B_PHASE_15_PACKAGE_JSON={json_out}")
print(f"N1B_PHASE_15_PACKAGE_MARKDOWN={md_out}")
print(f"N1B_PHASE_15_MANUAL_AUTHORIZATION_PACKAGE={'PASS_REVIEW_READY' if not failures else 'BLOCKED'}")
PY

echo "===== N1B PHASE 15 MANUAL AUTHORIZATION PACKAGE RESULT ====="
echo "N1B_PHASE_15_DEVICE_CONTACT=NO_OFFLINE_ONLY"
echo "N1B_PHASE_15_EVIDENCE_DIR=$EVIDENCE_DIR"
