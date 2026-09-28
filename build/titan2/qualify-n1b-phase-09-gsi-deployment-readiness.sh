#!/usr/bin/env bash
set -euo pipefail

REGISTRY_ROOT="${SABLE_RELEASE_REGISTRY_ROOT:-/srv/data/sable-build/release-registry}"
BUILD_SOURCE=""
MANIFEST=""
REQUIRE_READY=NO

usage() {
  cat >&2 <<'USAGE'
usage:
  bash build/titan2/qualify-n1b-phase-09-gsi-deployment-readiness.sh \
    --build-source <source commit>

  bash build/titan2/qualify-n1b-phase-09-gsi-deployment-readiness.sh \
    --manifest <artifact manifest json>

Options:
  --require-ready   Exit non-zero if physical preflight metadata is missing.

This is a read-only GSI deployment readiness gate. It does not contact devices,
does not run adb, does not run fastboot, and does not flash.
USAGE
}

while (($#)); do
  case "$1" in
    --build-source) BUILD_SOURCE="$2"; shift 2 ;;
    --manifest) MANIFEST="$2"; shift 2 ;;
    --require-ready) REQUIRE_READY=YES; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "N1B_PHASE_09_GSI_DEPLOYMENT_READINESS=FAIL_UNKNOWN_ARG arg=$1"; usage; exit 64 ;;
  esac
done

if [[ -z "$MANIFEST" ]]; then
  [[ -n "$BUILD_SOURCE" ]] || {
    echo "N1B_PHASE_09_GSI_DEPLOYMENT_READINESS=FAIL_BUILD_SOURCE_OR_MANIFEST_REQUIRED"
    usage
    exit 64
  }
  MANIFEST="$REGISTRY_ROOT/titan2/N1B/$BUILD_SOURCE.json"
fi

python3 - "$MANIFEST" "$REQUIRE_READY" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

manifest = Path(sys.argv[1])
require_ready = sys.argv[2] == "YES"

required_top = {
    "schema", "device", "release", "build_source", "tool_source",
    "out_dir", "primary_artifact", "metadata",
}
required_build_metadata = {
    "active_product_mk", "artifact_logical_bytes",
    "n1b_full_local_ci_evidence_dir", "n1b_full_local_ci_profile",
    "n1b_phase_08_image_build_evidence_dir", "device_contact_authorized",
    "flash_authorized", "public_release", "production_signing",
}
required_physical_metadata = {
    "active_slot", "avb_action", "bootloader_preflight",
    "explicit_titan_serial", "fastbootd_preflight", "lp_action",
    "restore_path_verified", "restore_report", "snapshot_update_status",
    "stock_baseline", "system_current_bytes", "userdata_policy",
}

print("===== N1B PHASE 09 GSI DEPLOYMENT READINESS =====")
print(f"MANIFEST={manifest}")
print("DEVICE=titan2")
print("RELEASE=N1B")
print("ARTIFACT_KIND=gsi-system-image")
print("PRIMARY_ARTIFACT=system")
print("SOURCE_MUTATION_AUTHORIZED=NO")
print("DEVICE_CONTACT_AUTHORIZED=NO")
print("FLASH_AUTHORIZED=NO")
print("ADB_COMMANDS_RUN=NO")
print("FASTBOOT_COMMANDS_RUN=NO")
print("PUBLIC_RELEASE=NO")
print("PRODUCTION_SIGNING=NO")

failures = 0

if not manifest.exists():
    print("N1B_PHASE_09_MANIFEST=FAIL_MISSING")
    print("N1B_PHASE_09_GSI_DEPLOYMENT_READINESS=FAIL")
    raise SystemExit(1)

try:
    data = json.loads(manifest.read_text())
except json.JSONDecodeError as exc:
    print("N1B_PHASE_09_MANIFEST=FAIL_INVALID_JSON")
    print(f"N1B_PHASE_09_MANIFEST_JSON_ERROR={exc}")
    print("N1B_PHASE_09_GSI_DEPLOYMENT_READINESS=FAIL")
    raise SystemExit(1)

metadata = data.get("metadata", {})

missing_top = sorted(required_top - set(data))
if missing_top:
    failures += len(missing_top)
    print("N1B_PHASE_09_MANIFEST_SCHEMA=FAIL")
    for key in missing_top:
        print(f"N1B_PHASE_09_MISSING_TOP_FIELD={key}")
else:
    print("N1B_PHASE_09_MANIFEST_SCHEMA=PASS")

for key, expected in {"device": "titan2", "release": "N1B", "primary_artifact": "system"}.items():
    value = data.get(key)
    if value != expected:
        failures += 1
        print(f"N1B_PHASE_09_TOP_FIELD_VALUE=FAIL key={key} expected={expected} actual={value}")

missing_build_metadata = sorted(required_build_metadata - set(metadata))
if missing_build_metadata:
    failures += len(missing_build_metadata)
    print("N1B_PHASE_09_BUILD_METADATA=FAIL")
    for key in missing_build_metadata:
        print(f"N1B_PHASE_09_MISSING_BUILD_METADATA={key}")
else:
    print("N1B_PHASE_09_BUILD_METADATA=PASS")

boundary_failures = []
for key in ("device_contact_authorized", "flash_authorized", "public_release", "production_signing"):
    value = metadata.get(key)
    if value != "NO":
        boundary_failures.append((key, value))

if boundary_failures:
    failures += len(boundary_failures)
    print("N1B_PHASE_09_BOUNDARY=FAIL")
    for key, value in boundary_failures:
        print(f"N1B_PHASE_09_BAD_BOUNDARY {key}={value}")
else:
    print("N1B_PHASE_09_BOUNDARY=PASS")

missing_physical = sorted(required_physical_metadata - set(metadata))
if missing_physical:
    print("N1B_PHASE_09_PHYSICAL_PREFLIGHT_METADATA=BLOCKED_MISSING_METADATA")
    for key in missing_physical:
        print(f"N1B_PHASE_09_MISSING_PHYSICAL_METADATA={key}")
else:
    print("N1B_PHASE_09_PHYSICAL_PREFLIGHT_METADATA=PASS")

physical_failures = []
if not missing_physical:
    try:
        logical_bytes = int(metadata.get("artifact_logical_bytes", ""))
        system_current_bytes = int(metadata.get("system_current_bytes", ""))
    except ValueError:
        physical_failures.append("system_current_bytes and artifact_logical_bytes must be integers")
    else:
        if system_current_bytes < logical_bytes:
            physical_failures.append("system_current_bytes is smaller than artifact_logical_bytes")

    for key in required_physical_metadata:
        if not str(metadata.get(key, "")).strip():
            physical_failures.append(f"{key} is empty")

if physical_failures:
    failures += len(physical_failures)
    print("N1B_PHASE_09_PHYSICAL_PREFLIGHT_METADATA_VALUES=FAIL")
    for item in physical_failures:
        print(f"N1B_PHASE_09_PHYSICAL_PREFLIGHT_VALUE_FAILURE={item}")

print("===== N1B PHASE 09 GSI DEPLOYMENT READINESS RESULT =====")
print(f"FAILURES={failures}")

if failures:
    print("N1B_PHASE_09_GSI_DEPLOYMENT_READINESS=FAIL")
    print("N1B_PHASE_09_FLASH_PLAN_ALLOWED=NO")
    raise SystemExit(1)

if missing_physical:
    print("N1B_PHASE_09_GSI_DEPLOYMENT_READINESS=BLOCKED")
    print("N1B_PHASE_09_FLASH_PLAN_ALLOWED=NO")
    if require_ready:
        raise SystemExit(1)
    raise SystemExit(0)

print("N1B_PHASE_09_GSI_DEPLOYMENT_READINESS=PASS")
print("N1B_PHASE_09_FLASH_PLAN_ALLOWED=YES_PLAN_ONLY")
print("FLASH_AUTHORIZED=NO")
PY
