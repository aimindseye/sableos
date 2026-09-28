#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PHASE11_JSON=""
SYSTEM_IMAGE=""
SYSTEM_BYTES=""
BUILD_SOURCE=""
REGISTRY_ROOT="${SABLE_RELEASE_REGISTRY_ROOT:-/srv/data/sable-build/release-registry}"

usage() {
  cat >&2 <<'EOF'
usage:
  bash build/titan2/qualify-n1b-phase-11-lp-super-sizing.sh \
    --phase11-json <phase11-fastbootd-lp-sizing.json> \
    [--system-image <system.img> | --system-bytes <bytes> | --build-source <sha>]

This qualifier is offline only. It compares the N1B GSI system image size with the
read-only fastbootd LP/super sizing evidence produced by Phase 11.

It does not contact the device and does not generate executable flash, resize, erase,
or AVB mutation commands.
EOF
}

while (($#)); do
  case "$1" in
    --phase11-json) PHASE11_JSON="$2"; shift 2 ;;
    --system-image) SYSTEM_IMAGE="$2"; shift 2 ;;
    --system-bytes) SYSTEM_BYTES="$2"; shift 2 ;;
    --build-source) BUILD_SOURCE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "N1B_PHASE_11_LP_SUPER_SIZING=FAIL_UNKNOWN_ARG arg=$1" >&2; usage; exit 64 ;;
  esac
done

[[ -n "$PHASE11_JSON" && -f "$PHASE11_JSON" ]] || {
  echo "N1B_PHASE_11_LP_SUPER_SIZING=FAIL_PHASE11_JSON path=$PHASE11_JSON"
  exit 64
}

if [[ -n "$SYSTEM_IMAGE" ]]; then
  [[ -f "$SYSTEM_IMAGE" ]] || {
    echo "N1B_PHASE_11_LP_SUPER_SIZING=FAIL_SYSTEM_IMAGE path=$SYSTEM_IMAGE"
    exit 64
  }
fi

if [[ -n "$SYSTEM_BYTES" ]]; then
  [[ "$SYSTEM_BYTES" =~ ^[0-9]+$ ]] || {
    echo "N1B_PHASE_11_LP_SUPER_SIZING=FAIL_SYSTEM_BYTES value=$SYSTEM_BYTES"
    exit 64
  }
fi

if [[ -n "$BUILD_SOURCE" ]]; then
  [[ "$BUILD_SOURCE" =~ ^[0-9a-f]{40}$ ]] || {
    echo "N1B_PHASE_11_LP_SUPER_SIZING=FAIL_BUILD_SOURCE value=$BUILD_SOURCE"
    exit 64
  }
fi

echo "===== N1B PHASE 11 LP/SUPER SIZING QUALIFIER ====="
echo "ROOT=$ROOT"
echo "PHASE11_JSON=$PHASE11_JSON"
echo "DEVICE=titan2"
echo "RELEASE=N1B"
echo "SOURCE_MUTATION_AUTHORIZED=NO"
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
echo "PUBLIC_RELEASE=NO"
echo "PRODUCTION_SIGNING=NO"

python3 - "$PHASE11_JSON" "$SYSTEM_IMAGE" "$SYSTEM_BYTES" "$BUILD_SOURCE" "$REGISTRY_ROOT" <<'PY'
from __future__ import annotations

import json
import os
import pathlib
import sys
from typing import Any

phase11_path = pathlib.Path(sys.argv[1])
system_image = sys.argv[2]
system_bytes_arg = sys.argv[3]
build_source = sys.argv[4]
registry_root = pathlib.Path(sys.argv[5])


def as_int(value: Any) -> int:
    if isinstance(value, int):
        return value
    if value is None:
        return 0
    text = str(value).strip()
    if not text:
        return 0
    try:
        return int(text, 0)
    except ValueError:
        return 0


def walk_values(value: Any):
    if isinstance(value, dict):
        for key, child in value.items():
            yield key, child
            yield from walk_values(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk_values(child)


def artifact_size_from_registry(source: str) -> int:
    if not source:
        return 0
    manifest = registry_root / "titan2" / "N1B" / f"{source}.json"
    if not manifest.exists():
        return 0
    data = json.loads(manifest.read_text(errors="replace"))

    preferred_keys = {
        "artifact_logical_bytes",
        "system_logical_bytes",
        "logical_bytes",
        "system_bytes",
        "bytes",
    }
    for key, value in walk_values(data):
        if key in preferred_keys:
            size = as_int(value)
            if size > 0:
                return size

    for key, value in walk_values(data):
        if key in {"artifact_path", "path"}:
            path = pathlib.Path(str(value))
            if path.exists() and path.name == "system.img":
                return path.stat().st_size
    return 0

phase11 = json.loads(phase11_path.read_text(errors="replace"))
metadata = phase11.get("metadata", {})

required_system_bytes = 0
if system_bytes_arg:
    required_system_bytes = as_int(system_bytes_arg)
elif system_image:
    required_system_bytes = pathlib.Path(system_image).stat().st_size
else:
    required_system_bytes = artifact_size_from_registry(build_source)

system_current_bytes = as_int(metadata.get("system_current_bytes"))
super_bytes = as_int(metadata.get("super_bytes"))
total_dynamic = as_int(metadata.get("total_selected_dynamic_current_bytes"))
super_headroom = as_int(metadata.get("super_headroom_estimate_bytes"))
missing_required = max(required_system_bytes - system_current_bytes, 0)

failures = 0

print(f"N1B_PHASE_11_REQUIRED_SYSTEM_BYTES={required_system_bytes}")
print(f"N1B_PHASE_11_SYSTEM_CURRENT_BYTES={system_current_bytes}")
print(f"N1B_PHASE_11_SYSTEM_MISSING_BYTES={missing_required}")
print(f"N1B_PHASE_11_SUPER_BYTES={super_bytes}")
print(f"N1B_PHASE_11_TOTAL_SELECTED_DYNAMIC_CURRENT_BYTES={total_dynamic}")
print(f"N1B_PHASE_11_SUPER_HEADROOM_ESTIMATE_BYTES={super_headroom}")

if required_system_bytes <= 0:
    print("N1B_PHASE_11_REQUIRED_SYSTEM_SIZE=FAIL_UNKNOWN")
    failures += 1
else:
    print("N1B_PHASE_11_REQUIRED_SYSTEM_SIZE=PASS")

if system_current_bytes <= 0:
    print("N1B_PHASE_11_CURRENT_SYSTEM_SIZE=FAIL_UNKNOWN")
    failures += 1
else:
    print("N1B_PHASE_11_CURRENT_SYSTEM_SIZE=PASS")

if required_system_bytes > 0 and system_current_bytes > 0 and system_current_bytes >= required_system_bytes:
    print("N1B_PHASE_11_DIRECT_SYSTEM_SIZE_COMPATIBILITY=PASS")
else:
    print("N1B_PHASE_11_DIRECT_SYSTEM_SIZE_COMPATIBILITY=BLOCKED_NEEDS_LP_RESIZE_PLAN")

if super_bytes <= 0 or total_dynamic <= 0:
    print("N1B_PHASE_11_SUPER_HEADROOM_ESTIMATE=UNKNOWN")
elif super_headroom >= missing_required:
    print("N1B_PHASE_11_SUPER_HEADROOM_ESTIMATE=PASS_CAPACITY_APPEARS_AVAILABLE_PLAN_REQUIRED")
else:
    print("N1B_PHASE_11_SUPER_HEADROOM_ESTIMATE=BLOCKED_INSUFFICIENT_ESTIMATED_HEADROOM")

print("N1B_PHASE_11_FLASH_PLAN_ALLOWED=NO")
print("N1B_PHASE_11_FLASH_ALLOWED=NO")
print("FLASH_AUTHORIZED=NO")
print("LP_MUTATION_AUTHORIZED=NO")
print("AVB_MUTATION_AUTHORIZED=NO")

print("===== N1B PHASE 11 LP/SUPER SIZING RESULT =====")
print(f"FAILURES={failures}")
if failures:
    print("N1B_PHASE_11_LP_SUPER_SIZING=FAIL")
    raise SystemExit(1)

if required_system_bytes > system_current_bytes:
    print("N1B_PHASE_11_LP_SUPER_SIZING=PASS_PLAN_REQUIRED")
else:
    print("N1B_PHASE_11_LP_SUPER_SIZING=PASS_DIRECT_SIZE_COMPATIBLE")
PY
