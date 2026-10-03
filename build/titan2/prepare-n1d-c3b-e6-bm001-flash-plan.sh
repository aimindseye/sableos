#!/usr/bin/env bash
# Offline-only flash plan for Titan 2 N1D C3B E6 BM-001 candidate.
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
REGISTRY_VERIFIED=""
EVIDENCE_DIR=""

EXPECTED_BUILD_SOURCE="36d5ee13f5a05b2ac19aeedf0b653a244e1eee3e"
EXPECTED_SYSTEM_SHA256="a048bde792636338cba4cab18301422179a7aa3322e7bd747f3218e90750502e"
EXPECTED_DECISION_SHA256="74531923a9ea6c755a9f8ea52db511c4a4a19a5d9dba3cb51da342c04b768926"
EXPECTED_FREEZE_SHA256="a5df48f0e77c9372dadc1a7453f0bc265c1a01733132c0b50d4969ba2c041e3a"
EXPECTED_PREFLASH_SYSTEM_BYTES=2994405376
EXPECTED_IMAGE_LOGICAL_BYTES=2994388992
EXPECTED_ORIGINAL_SYSTEM_BYTES=757059584

fail() {
  echo "N1D_C3B_E6_STANDARD_FLASH_PLAN=FAIL reason=$1" >&2
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
    --registry-verified) REGISTRY_VERIFIED="$2"; shift 2 ;;
    --build-evidence-dir) BUILD_EVIDENCE_DIR="$2"; shift 2 ;;
    --evidence-dir) EVIDENCE_DIR="$2"; shift 2 ;;
    *) fail "unknown_arg=$1" 64 ;;
  esac
done

echo "===== TITAN 2 N1D C3B E6 BM-001 STANDARD FLASH PLAN / OFFLINE ONLY ====="
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FASTBOOT_COMMANDS_RUN=NO"
echo "FLASH_AUTHORIZED=NO"
echo "FACTORY_RESET_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"

[[ "${RELEASE^^}" == N1D ]] || fail "release=$RELEASE" 64
[[ "$BUILD_SOURCE" == "$EXPECTED_BUILD_SOURCE" ]] || fail "build_source=$BUILD_SOURCE" 64
[[ "$EXPECTED_SHA256" == "$EXPECTED_SYSTEM_SHA256" ]] || fail system_sha_binding 64
[[ "$EXPECTED_E5B_JSON_SHA256" == "$EXPECTED_DECISION_SHA256" ]] || fail e5b_sha_binding 64
[[ "$EXPECTED_AUTH_FREEZE_SHA256" == "$EXPECTED_FREEZE_SHA256" ]] || fail auth_freeze_sha_binding 64
[[ "$REGISTRY_VERIFIED" == PASS ]] || fail registry_verification_required 64

for path in "$SYSTEM_IMG" "$E5B_JSON" "$AUTH_FREEZE_ENV"; do
  [[ -f "$path" ]] || fail "missing_file=$path" 66
done
[[ -d "$BUILD_EVIDENCE_DIR" ]] || fail "build_evidence_dir=$BUILD_EVIDENCE_DIR" 66
[[ -n "$EVIDENCE_DIR" ]] || fail evidence_dir_missing 64
mkdir -p "$EVIDENCE_DIR"

E6_STATE="$BUILD_EVIDENCE_DIR/e6-state.env"
[[ -f "$E6_STATE" ]] || fail "e6_state_missing=$E6_STATE" 66
for marker in \
  'N1D_C3B_E6_SYSTEMIMAGE=PASS' \
  "N1D_C3B_E6_CANONICAL_HEAD=$EXPECTED_BUILD_SOURCE" \
  'N1D_C3B_E6_RUNTIME_PATCH_COUNT=1' \
  'N1D_C3B_E6_RUNTIME_PATCH=BM-001_REMOVE_INIT_VNDK_NODEF' \
  'N1D_C3B_E6_VNDK28_SEPOLICY_ADMISSION=NO' \
  "N1D_C3B_E6_SYSTEM_SHA256=$EXPECTED_SYSTEM_SHA256" \
  "N1D_C3B_E6_SYSTEM_BYTES=$EXPECTED_IMAGE_LOGICAL_BYTES" \
  'N1D_C3B_E6_SABLE_MODULE_COUNT=5' \
  'N1D_C3B_E6_DEVICE_CONTACT_AUTHORIZED=NO' \
  'N1D_C3B_E6_FLASH_AUTHORIZED=NO'
do
  grep -Fxq -- "$marker" "$E6_STATE" || fail "e6_state_marker=$marker" 66
done
echo "N1D_C3B_E6_BUILD_EVIDENCE=PASS"

GSI_INFO_OUT="$EVIDENCE_DIR/gsi-image-info.txt"
python3 "$GSI_INFO" --image "$SYSTEM_IMG" | tee "$GSI_INFO_OUT"
grep -Fxq 'SABLE_GSI_IMAGE_INFO=PASS' "$GSI_INFO_OUT" || fail gsi_info 66
image_file_bytes="$(sed -n 's/^GSI_IMAGE_FILE_BYTES=//p' "$GSI_INFO_OUT" | tail -n1)"
image_format="$(sed -n 's/^GSI_IMAGE_FORMAT=//p' "$GSI_INFO_OUT" | tail -n1)"
image_logical_bytes="$(sed -n 's/^GSI_IMAGE_LOGICAL_BYTES=//p' "$GSI_INFO_OUT" | tail -n1)"
[[ "$image_format" == raw ]] || fail "image_format=$image_format" 66
[[ "$image_file_bytes" == "$EXPECTED_IMAGE_LOGICAL_BYTES" ]] || fail "image_file_bytes=$image_file_bytes" 66
[[ "$image_logical_bytes" == "$EXPECTED_IMAGE_LOGICAL_BYTES" ]] || fail "image_logical_bytes=$image_logical_bytes" 66

PLAN_VALUES="$EVIDENCE_DIR/plan-values.env"
python3 - \
  "$E5B_JSON" \
  "$EXPECTED_ORIGINAL_SYSTEM_BYTES" \
  "$EXPECTED_PREFLASH_SYSTEM_BYTES" \
  "$EXPECTED_IMAGE_LOGICAL_BYTES" \
  "$PLAN_VALUES" <<'PY'
from __future__ import annotations
import json
import pathlib
import sys

data = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
original_system = int(sys.argv[2])
current_system = int(sys.argv[3])
image_system = int(sys.argv[4])
out = pathlib.Path(sys.argv[5])

required = {
    "current_slot": "a",
    "target_system_partition": "system_a",
    "other_system_current_bytes": 0,
    "slot_policy": "KEEP_CURRENT_SLOT_NO_SLOT_SWITCH",
    "active_cow_total_bytes": 0,
    "cow_cleanup_policy": "NO_COW_CLEANUP_NEEDED",
    "avb_policy": "PRESERVE_NO_VBMETA_OR_BOOT_CHAIN_MUTATION",
    "boot_partition_policy": "PRESERVE_STOCK_BOOT_INIT_BOOT_VENDOR_BOOT_DTBO",
    "snapshot_update_review": "PASS_IDLE_OR_NONE",
}
for key, expected in required.items():
    actual = data.get(key)
    if actual != expected:
        raise SystemExit(
            f"N1D_C3B_E6_STANDARD_FLASH_PLAN=FAIL reason=e5b_field "
            f"key={key} expected={expected!r} actual={actual!r}"
        )

if int(data["active_system_current_bytes"]) != original_system:
    raise SystemExit("N1D_C3B_E6_STANDARD_FLASH_PLAN=FAIL reason=baseline_system_size")
planned_target = int(data["planned_system_target_bytes"])
super_bytes = int(data["super_bytes"])
fresh_headroom = int(data["fresh_super_headroom_bytes"])
minimum_remaining = int(data["minimum_remaining_headroom_bytes"])
baseline_group = int(data["active_group_current_bytes"])
group_max = int(data["active_group_maximum_bytes"])
baseline_allocated = int(data["all_materialized_logical_bytes"])

current_group = baseline_group - original_system + current_system
prospective_group = current_group - current_system + image_system
remaining = fresh_headroom - max(0, image_system - original_system)
current_allocated = baseline_allocated - original_system + current_system
size_delta = image_system - current_system

if image_system > planned_target:
    raise SystemExit("N1D_C3B_E6_STANDARD_FLASH_PLAN=FAIL reason=reviewed_target")
if prospective_group > group_max:
    raise SystemExit("N1D_C3B_E6_STANDARD_FLASH_PLAN=FAIL reason=active_group_capacity")
if remaining < minimum_remaining:
    raise SystemExit("N1D_C3B_E6_STANDARD_FLASH_PLAN=FAIL reason=super_capacity")

values = {
    "ORIGINAL_SYSTEM_BYTES": original_system,
    "PREFLASH_SYSTEM_BYTES": current_system,
    "IMAGE_LOGICAL_BYTES": image_system,
    "SYSTEM_SIZE_DELTA_BYTES": size_delta,
    "SUPER_BYTES": super_bytes,
    "CURRENT_ACTIVE_GROUP_BYTES": current_group,
    "PROSPECTIVE_ACTIVE_GROUP_BYTES": prospective_group,
    "ACTIVE_GROUP_MAXIMUM_BYTES": group_max,
    "REMAINING_SUPER_HEADROOM_BYTES": remaining,
    "MINIMUM_REMAINING_HEADROOM_BYTES": minimum_remaining,
    "EXPECTED_MATERIALIZED_LOGICAL_BYTES": current_allocated,
    "REVIEWED_PLANNED_TARGET_BYTES": planned_target,
}
out.write_text(
    "".join(f"{key}={value}\n" for key, value in values.items()),
    encoding="utf-8",
)
for key, value in values.items():
    print(f"N1D_C3B_E6_{key}={value}")
print("N1D_C3B_E6_IMAGE_WITHIN_REVIEWED_TARGET=YES")
print("N1D_C3B_E6_ACTIVE_GROUP_CAPACITY_SAFE=YES")
print("N1D_C3B_E6_SUPER_CAPACITY_SAFE=YES")
PY

# shellcheck source=/dev/null
source "$PLAN_VALUES"

PLAN="$EVIDENCE_DIR/titan2-n1d-c3b-e6-bm001-standard-flash-plan.txt"
cat > "$PLAN" <<EOF
N1D_C3B_E6_STANDARD_FLASH_PLAN=PREPARED_NO_WRITE
RELEASE=N1D
BUILD_SOURCE=$BUILD_SOURCE
ARTIFACT_KIND=gsi-system-image
CANDIDATE=BM-001_REMOVE_INIT_VNDK_NODEF
SYSTEM_IMG=$SYSTEM_IMG
SYSTEM_SHA256=$EXPECTED_SYSTEM_SHA256
SYSTEM_FORMAT=$image_format
SYSTEM_FILE_BYTES=$image_file_bytes
SYSTEM_LOGICAL_BYTES=$IMAGE_LOGICAL_BYTES
EXPECTED_PREFLASH_SYSTEM_BYTES=$PREFLASH_SYSTEM_BYTES
SYSTEM_SIZE_DELTA_BYTES=$SYSTEM_SIZE_DELTA_BYTES
TARGET_PARTITION=system_a
EXPECTED_ACTIVE_SLOT=a
EXPECTED_SUPER_BYTES=$SUPER_BYTES
EXPECTED_ACTIVE_COW_COUNT=0
EXPECTED_MATERIALIZED_LOGICAL_BYTES=$EXPECTED_MATERIALIZED_LOGICAL_BYTES
FLASH_ENTRY_MODE=userspace-fastbootd
FLASH_OPERATION=STANDARD_ADAPTER_FASTBOOT_FLASH_SYSTEM_A_ONLY
FASTBOOT_IMPLICIT_RESIZE=YES
FASTBOOT_IMPLICIT_RESIZE_TARGET_BYTES=$IMAGE_LOGICAL_BYTES
MANUAL_PRE_RESIZE_REQUIRED=NO
ACTIVE_GROUP_PROSPECTIVE_BYTES=$PROSPECTIVE_ACTIVE_GROUP_BYTES
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
AUTOMATIC_RETRY_ALLOWED=NO
E5B_DECISION_PACKAGE_SHA256=$EXPECTED_E5B_JSON_SHA256
E5B_MANUAL_AUTH_FREEZE_SHA256=$EXPECTED_AUTH_FREEZE_SHA256
EOF

echo "N1D_C3B_E6_SYSTEM_FORMAT=$image_format"
echo "N1D_C3B_E6_SYSTEM_FILE_BYTES=$image_file_bytes"
echo "N1D_C3B_E6_SYSTEM_LOGICAL_BYTES=$IMAGE_LOGICAL_BYTES"
echo "N1D_C3B_E6_SYSTEM_SIZE_DELTA_BYTES=$SYSTEM_SIZE_DELTA_BYTES"
echo "N1D_C3B_E6_FASTBOOT_IMPLICIT_RESIZE=YES"
echo "N1D_C3B_E6_MANUAL_PRE_RESIZE_REQUIRED=NO"
echo "N1D_C3B_E6_FACTORY_RESET_AUTHORIZED=NO"
echo "FLASH_PLAN=$PLAN"
echo "N1D_C3B_E6_STANDARD_FLASH_PLAN=PASS_PREPARED_NO_WRITE"
