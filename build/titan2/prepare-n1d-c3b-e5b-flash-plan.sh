#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GSI_INFO="$ROOT/build/deploy/gsi_image_info.py"

RELEASE=""
BUILD_SOURCE=""
SYSTEM_IMG=""
EXPECTED_SHA256=""
E5B_JSON=""
EXPECTED_E5B_JSON_SHA256=""
AUTH_FREEZE_ENV=""
EXPECTED_AUTH_FREEZE_SHA256=""
BUILD_EVIDENCE_DIR=""
EVIDENCE_DIR=""

EXPECTED_BUILD_SOURCE="caf98dde723d07a071d95aaa1ef27d578d3208d8"
EXPECTED_SYSTEM_SHA256="998a8b99cd4d1a631006291a96c6f0160c5a4400c4bf6bba62c319c4ed3c82a5"
EXPECTED_DECISION_SHA256="74531923a9ea6c755a9f8ea52db511c4a4a19a5d9dba3cb51da342c04b768926"

usage() {
  cat >&2 <<'EOF'
usage:
  bash build/titan2/prepare-n1d-c3b-e5b-flash-plan.sh \
    --release N1D \
    --build-source <40-hex-sha> \
    --system-img <path> \
    --expected-sha256 <sha256> \
    --e5b-json <path> \
    --expected-e5b-json-sha256 <sha256> \
    --auth-freeze-env <path> \
    --build-evidence-dir <path> \
    --evidence-dir <path>

Offline-only standardized N1D C3B E5B flash-plan preparation.
No adb, fastboot, reboot, flash, LP mutation, AVB mutation, slot change,
userdata operation, factory reset, build, or network command is run.
EOF
}

fail() {
  echo "N1D_C3B_E5B_STANDARD_FLASH_PLAN=FAIL reason=$1" >&2
  exit "${2:-1}"
}

while (($#)); do
  case "$1" in
    --release) RELEASE="$2"; shift 2 ;;
    --build-source) BUILD_SOURCE="$2"; shift 2 ;;
    --system-img) SYSTEM_IMG="$2"; shift 2 ;;
    --expected-sha256) EXPECTED_SHA256="$2"; shift 2 ;;
    --e5b-json) E5B_JSON="$2"; shift 2 ;;
    --expected-e5b-json-sha256) EXPECTED_E5B_JSON_SHA256="$2"; shift 2 ;;
    --auth-freeze-env) AUTH_FREEZE_ENV="$2"; shift 2 ;;
    --expected-auth-freeze-sha256) EXPECTED_AUTH_FREEZE_SHA256="$2"; shift 2 ;;
    --build-evidence-dir) BUILD_EVIDENCE_DIR="$2"; shift 2 ;;
    --evidence-dir) EVIDENCE_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown_arg=$1" 64 ;;
  esac
done

echo "===== TITAN 2 N1D C3B E5B STANDARD FLASH PLAN / OFFLINE ONLY ====="
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "ADB_COMMANDS_RUN=NO"
echo "FASTBOOT_COMMANDS_RUN=NO"
echo "REBOOT_COMMANDS_RUN=NO"
echo "FLASH_AUTHORIZED=NO"
echo "LP_MUTATION_AUTHORIZED=NO"
echo "AVB_MUTATION_AUTHORIZED=NO"
echo "SLOT_MUTATION_AUTHORIZED=NO"
echo "FACTORY_RESET_AUTHORIZED=NO"
echo "WRITE_CAPABLE_SCRIPT_CREATED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"

[[ "${RELEASE^^}" == N1D ]] || fail "release=$RELEASE" 64
[[ "$BUILD_SOURCE" == "$EXPECTED_BUILD_SOURCE" ]] || fail "build_source=$BUILD_SOURCE" 64
[[ "$EXPECTED_SHA256" == "$EXPECTED_SYSTEM_SHA256" ]] || fail "system_sha_binding" 64
[[ "$EXPECTED_E5B_JSON_SHA256" == "$EXPECTED_DECISION_SHA256" ]] || fail "e5b_sha_binding" 64
[[ "$EXPECTED_AUTH_FREEZE_SHA256" =~ ^[0-9a-f]{64}$ ]] || fail "auth_freeze_sha_binding" 64

for path in "$SYSTEM_IMG" "$E5B_JSON" "$AUTH_FREEZE_ENV"; do
  [[ -f "$path" ]] || fail "missing_file=$path" 66
done
[[ -d "$BUILD_EVIDENCE_DIR" ]] || fail "build_evidence_dir=$BUILD_EVIDENCE_DIR" 66
[[ -n "$EVIDENCE_DIR" ]] || fail evidence_dir_missing 64
mkdir -p "$EVIDENCE_DIR"

actual_system_sha="$(sha256sum "$SYSTEM_IMG" | awk '{print $1}')"
actual_e5b_sha="$(sha256sum "$E5B_JSON" | awk '{print $1}')"
freeze_sha="$(sha256sum "$AUTH_FREEZE_ENV" | awk '{print $1}')"
[[ "$freeze_sha" == "$EXPECTED_AUTH_FREEZE_SHA256" ]] || fail auth_freeze_sha256_mismatch 66

[[ "$actual_system_sha" == "$EXPECTED_SYSTEM_SHA256" ]] || fail system_sha256_mismatch 66
[[ "$actual_e5b_sha" == "$EXPECTED_DECISION_SHA256" ]] || fail e5b_json_sha256_mismatch 66

BUILD_STATE="$BUILD_EVIDENCE_DIR/build-state.env"
[[ -f "$BUILD_STATE" ]] || fail "build_state_missing=$BUILD_STATE" 66
grep -Fxq 'N1D_C3B_E3_SYSTEMIMAGE=PASS' "$BUILD_STATE" || fail e3_build_not_pass 66
grep -Fxq "N1D_C3B_E3_SYSTEM_SHA256=$EXPECTED_SYSTEM_SHA256" "$BUILD_STATE" || fail e3_sha_marker 66
grep -Fxq "N1D_C3B_E3_SYSTEM_IMG=$SYSTEM_IMG" "$BUILD_STATE" || fail e3_path_marker 66

GSI_INFO_OUT="$EVIDENCE_DIR/gsi-image-info.txt"
python3 "$GSI_INFO" \
  --image "$SYSTEM_IMG" \
  --expected-sha256 "$EXPECTED_SYSTEM_SHA256" \
  | tee "$GSI_INFO_OUT"
grep -Fxq 'SABLE_GSI_IMAGE_INFO=PASS' "$GSI_INFO_OUT" || fail gsi_info 66

image_file_bytes="$(sed -n 's/^GSI_IMAGE_FILE_BYTES=//p' "$GSI_INFO_OUT" | tail -n1)"
image_format="$(sed -n 's/^GSI_IMAGE_FORMAT=//p' "$GSI_INFO_OUT" | tail -n1)"
image_logical_bytes="$(sed -n 's/^GSI_IMAGE_LOGICAL_BYTES=//p' "$GSI_INFO_OUT" | tail -n1)"

[[ "$image_file_bytes" =~ ^[0-9]+$ ]] || fail image_file_bytes 66
[[ "$image_logical_bytes" =~ ^[0-9]+$ ]] || fail image_logical_bytes 66
case "$image_format" in raw|android-sparse) ;; *) fail "image_format=$image_format" 66 ;; esac

PLAN_VALUES="$EVIDENCE_DIR/plan-values.env"
python3 - \
  "$E5B_JSON" \
  "$AUTH_FREEZE_ENV" \
  "$EXPECTED_SYSTEM_SHA256" \
  "$EXPECTED_DECISION_SHA256" \
  "$image_logical_bytes" \
  "$PLAN_VALUES" <<'PY'
from __future__ import annotations

import json
import pathlib
import sys

e5b_path = pathlib.Path(sys.argv[1])
freeze_path = pathlib.Path(sys.argv[2])
expected_system_sha = sys.argv[3]
expected_decision_sha = sys.argv[4]
logical_bytes = int(sys.argv[5])
out = pathlib.Path(sys.argv[6])

data = json.loads(e5b_path.read_text(encoding="utf-8"))

freeze: dict[str, str] = {}
for raw in freeze_path.read_text(encoding="utf-8", errors="replace").splitlines():
    if not raw or raw.lstrip().startswith("#") or "=" not in raw:
        continue
    key, value = raw.split("=", 1)
    freeze[key.strip()] = value.strip()

required = {
    "authorization_state": "READY_FOR_MANUAL_AUTHORIZATION_ACTIVE_SYSTEM_PATH",
    "current_slot": "a",
    "target_system_partition": "system_a",
    "other_system_current_bytes": 0,
    "slot_policy": "KEEP_CURRENT_SLOT_NO_SLOT_SWITCH",
    "active_cow_total_bytes": 0,
    "cow_cleanup_policy": "NO_COW_CLEANUP_NEEDED",
    "avb_policy": "PRESERVE_NO_VBMETA_OR_BOOT_CHAIN_MUTATION",
    "boot_partition_policy": "PRESERVE_STOCK_BOOT_INIT_BOOT_VENDOR_BOOT_DTBO",
    "active_group_capacity_safe": True,
    "super_capacity_safe": True,
    "write_capable_commands_emitted": False,
}
for key, expected in required.items():
    actual = data.get(key)
    if actual != expected:
        raise SystemExit(
            "N1D_C3B_E5B_STANDARD_FLASH_PLAN=FAIL "
            f"reason=e5b_field key={key} expected={expected!r} actual={actual!r}"
        )

if data.get("snapshot_update_review") != "PASS_IDLE_OR_NONE":
    raise SystemExit(
        "N1D_C3B_E5B_STANDARD_FLASH_PLAN=FAIL reason=snapshot_not_idle"
    )

freeze_required = {
    "N1D_C3B_E5B_SYSTEM_SHA256": expected_system_sha,
    "N1D_C3B_E5B_DECISION_PACKAGE_SHA256": expected_decision_sha,
    "N1D_C3B_E5B_MANUAL_AUTH_FREEZE": "PASS_READY_FOR_OWNER_AUTHORIZATION",
    "N1D_C3B_E5B_MUTATION_AUTHORIZED": "NO",
}
for key, expected in freeze_required.items():
    actual = freeze.get(key)
    if actual != expected:
        raise SystemExit(
            "N1D_C3B_E5B_STANDARD_FLASH_PLAN=FAIL "
            f"reason=freeze_field key={key} expected={expected!r} actual={actual!r}"
        )

active_system = int(data["active_system_current_bytes"])
planned_target = int(data["planned_system_target_bytes"])
super_bytes = int(data["super_bytes"])
fresh_headroom = int(data["fresh_super_headroom_bytes"])
minimum_remaining = int(data["minimum_remaining_headroom_bytes"])
group_current = int(data["active_group_current_bytes"])
group_max = int(data["active_group_maximum_bytes"])

growth = max(0, logical_bytes - active_system)
remaining = fresh_headroom - growth
prospective_group = group_current - active_system + logical_bytes

if logical_bytes > planned_target:
    raise SystemExit(
        "N1D_C3B_E5B_STANDARD_FLASH_PLAN=FAIL "
        f"reason=logical_size_exceeds_reviewed_target "
        f"logical={logical_bytes} target={planned_target}"
    )
if prospective_group > group_max:
    raise SystemExit(
        "N1D_C3B_E5B_STANDARD_FLASH_PLAN=FAIL reason=active_group_capacity"
    )
if remaining < minimum_remaining:
    raise SystemExit(
        "N1D_C3B_E5B_STANDARD_FLASH_PLAN=FAIL reason=super_capacity"
    )

lines = {
    "ACTIVE_SYSTEM_CURRENT_BYTES": active_system,
    "REVIEWED_PLANNED_TARGET_BYTES": planned_target,
    "SUPER_BYTES": super_bytes,
    "IMAGE_LOGICAL_BYTES": logical_bytes,
    "FASTBOOT_IMPLICIT_GROWTH_BYTES": growth,
    "ACTIVE_GROUP_CURRENT_BYTES": group_current,
    "ACTIVE_GROUP_MAXIMUM_BYTES": group_max,
    "ACTIVE_GROUP_PROSPECTIVE_BYTES": prospective_group,
    "FRESH_SUPER_HEADROOM_BYTES": fresh_headroom,
    "REMAINING_SUPER_HEADROOM_BYTES": remaining,
    "MINIMUM_REMAINING_HEADROOM_BYTES": minimum_remaining,
}
out.write_text(
    "".join(f"{key}={value}\n" for key, value in lines.items()),
    encoding="utf-8",
)

for key, value in lines.items():
    print(f"N1D_C3B_E5B_{key}={value}")
print("N1D_C3B_E5B_IMAGE_WITHIN_REVIEWED_TARGET=YES")
print("N1D_C3B_E5B_ACTIVE_GROUP_CAPACITY_SAFE=YES")
print("N1D_C3B_E5B_SUPER_CAPACITY_SAFE=YES")
PY

# shellcheck source=/dev/null
source "$PLAN_VALUES"

PLAN="$EVIDENCE_DIR/titan2-n1d-c3b-e5b-standard-flash-plan.txt"
cat > "$PLAN" <<EOF
N1D_C3B_E5B_STANDARD_FLASH_PLAN=PREPARED_NO_WRITE
RELEASE=N1D
BUILD_SOURCE=$BUILD_SOURCE
ARTIFACT_KIND=gsi-system-image
SYSTEM_IMG=$SYSTEM_IMG
SYSTEM_SHA256=$actual_system_sha
SYSTEM_FILE_BYTES=$image_file_bytes
SYSTEM_FORMAT=$image_format
SYSTEM_LOGICAL_BYTES=$IMAGE_LOGICAL_BYTES
TARGET_PARTITION=system_a
EXPECTED_ACTIVE_SLOT=a
EXPECTED_SYSTEM_CURRENT_BYTES=$ACTIVE_SYSTEM_CURRENT_BYTES
EXPECTED_SUPER_BYTES=$SUPER_BYTES
EXPECTED_ACTIVE_COW_COUNT=0
FLASH_ENTRY_MODE=userspace-fastbootd
FLASH_OPERATION=STANDARD_ADAPTER_FASTBOOT_FLASH_SYSTEM_A_ONLY
FASTBOOT_IMPLICIT_RESIZE=YES
FASTBOOT_IMPLICIT_RESIZE_TARGET_BYTES=$IMAGE_LOGICAL_BYTES
MANUAL_PRE_RESIZE_REQUIRED=NO
REVIEWED_PLANNED_TARGET_CEILING_BYTES=$REVIEWED_PLANNED_TARGET_BYTES
ACTIVE_GROUP_PROSPECTIVE_BYTES=$ACTIVE_GROUP_PROSPECTIVE_BYTES
ACTIVE_GROUP_MAXIMUM_BYTES=$ACTIVE_GROUP_MAXIMUM_BYTES
REMAINING_SUPER_HEADROOM_BYTES=$REMAINING_SUPER_HEADROOM_BYTES
MINIMUM_REMAINING_HEADROOM_BYTES=$MINIMUM_REMAINING_HEADROOM_BYTES
COW_DELETION_ALLOWED=NO
SLOT_CHANGE_ALLOWED=NO
AVB_MUTATION_ALLOWED=NO
BOOT_CHAIN_FLASH_ALLOWED=NO
WHOLE_SUPER_FLASH_ALLOWED=NO
USERDATA_ERASE_ALLOWED=NO
FACTORY_RESET_ALLOWED=NO
POST_WRITE_REBOOT_COUNT=1
WRITE_CAPABLE_SCRIPT_CREATED=NO
FLASH_AUTHORIZED=NO
EXECUTION_GATE=SEPARATE_STANDARD_ADAPTER_QUALIFICATION_AND_OWNER_SCOPE_CONFIRMATION_REQUIRED
E5B_DECISION_PACKAGE_SHA256=$actual_e5b_sha
E5B_MANUAL_AUTH_FREEZE_SHA256=$freeze_sha
EOF

(
  cd "$EVIDENCE_DIR"
  find . -type f ! -name SHA256SUMS.txt -print0 \
    | LC_ALL=C sort -z \
    | xargs -0 sha256sum > SHA256SUMS.txt
  sha256sum -c SHA256SUMS.txt >/dev/null
)

echo "N1D_C3B_E5B_SYSTEM_FORMAT=$image_format"
echo "N1D_C3B_E5B_SYSTEM_FILE_BYTES=$image_file_bytes"
echo "N1D_C3B_E5B_SYSTEM_LOGICAL_BYTES=$IMAGE_LOGICAL_BYTES"
echo "N1D_C3B_E5B_FASTBOOT_IMPLICIT_RESIZE=YES"
echo "N1D_C3B_E5B_MANUAL_PRE_RESIZE_REQUIRED=NO"
echo "N1D_C3B_E5B_FLASH_EXECUTION_SUPPORTED=NO"
echo "N1D_C3B_E5B_WRITE_CAPABLE_SCRIPT_CREATED=NO"
echo "FLASH_PLAN=$PLAN"
echo "EVIDENCE_SEAL_SHA256=$(sha256sum "$EVIDENCE_DIR/SHA256SUMS.txt" | awk '{print $1}')"
echo "N1D_C3B_E5B_STANDARD_FLASH_PLAN=PASS_PREPARED_NO_WRITE"
