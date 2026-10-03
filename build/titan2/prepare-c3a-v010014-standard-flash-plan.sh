#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GSI_INFO="$ROOT/build/deploy/gsi_image_info.py"
C3A_ENV="$ROOT/build/titan2/n1d-c3a-control-evidence.env"

RELEASE=""
BUILD_SOURCE=""
SYSTEM_IMG=""
REQUESTED_SYSTEM_SHA256=""
PREFLIGHT_JSON=""
PREFLIGHT_JSON_SHA256=""
PREFLIGHT_SUMS=""
PREFLIGHT_SUMS_SHA256=""
OFFLINE_PLAN=""
OFFLINE_PLAN_SHA256=""
OFFLINE_SUMS=""
OFFLINE_SUMS_SHA256=""
BASELINE_E5A=""
BASELINE_E5A_SHA256=""
BASELINE_E5B=""
BASELINE_E5B_SHA256=""
REGISTRY_VERIFIED=""
BUILD_EVIDENCE_DIR=""
EVIDENCE_DIR=""

EXPECTED_BUILD_SOURCE="e6bcd76885c6048da7cbd9f200a9b1102e6d91a2"
CANONICAL_SYSTEM_SHA256="4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16"
CANONICAL_SYSTEM_BYTES=3146977280
EXPECTED_PREFLIGHT_SEAL_SHA256="47f28c371f13974d3a7303dc550014502401fae55a76bb365139f29e4c2da893"
EXPECTED_OFFLINE_SEAL_SHA256="e6ad9a20192ef7c1fcb8bf0bfc1f393afd8b9cdd7239cb19b0497512f4f8fd57"
EXPECTED_BASELINE_E5B_SHA256="74531923a9ea6c755a9f8ea52db511c4a4a19a5d9dba3cb51da342c04b768926"
EXPECTED_FASTBOOT_BINDING_SHA256="bcfdee61b23e3cb002919c27a055389ffe37e284bf5150dfc1d0bbbd7564090a"
CANONICAL_SYSTEM_CURRENT_BYTES=2994388992
CANONICAL_SUPER_BYTES=9663676416
CANONICAL_SLOT=a
CANONICAL_PRODUCT=Titan_2
CANONICAL_ACTIVE_GROUP=main_a
MINIMUM_REMAINING_HEADROOM_BYTES=536870912

usage() {
  cat >&2 <<'USAGE'
usage:
  bash build/titan2/prepare-c3a-v010014-standard-flash-plan.sh     --release N1D     --build-source <40-hex-sha>     --system-img PATH     --expected-system-sha256 SHA256     --preflight-json PATH     --preflight-json-sha256 SHA256     --preflight-sums PATH     --preflight-sums-sha256 SHA256     --offline-plan PATH     --offline-plan-sha256 SHA256     --offline-sums PATH     --offline-sums-sha256 SHA256     --baseline-e5a PATH     --baseline-e5a-sha256 SHA256     --baseline-e5b PATH     --baseline-e5b-sha256 SHA256     --registry-verified PASS     --build-evidence-dir DIR     --evidence-dir DIR

Offline-only. Generates a sealed C3A system_a flash plan.
It runs no adb, fastboot, reboot, flash, reset, LP mutation, AVB mutation,
source mutation, build, or network command.
USAGE
}

fail() {
  echo "C3A_V010014_STANDARD_FLASH_PLAN=FAIL reason=$1" >&2
  exit "${2:-1}"
}

while (($#)); do
  case "$1" in
    --release) RELEASE="$2"; shift 2 ;;
    --build-source) BUILD_SOURCE="$2"; shift 2 ;;
    --system-img) SYSTEM_IMG="$2"; shift 2 ;;
    --expected-system-sha256) REQUESTED_SYSTEM_SHA256="$2"; shift 2 ;;
    --preflight-json) PREFLIGHT_JSON="$2"; shift 2 ;;
    --preflight-json-sha256) PREFLIGHT_JSON_SHA256="$2"; shift 2 ;;
    --preflight-sums) PREFLIGHT_SUMS="$2"; shift 2 ;;
    --preflight-sums-sha256) PREFLIGHT_SUMS_SHA256="$2"; shift 2 ;;
    --offline-plan) OFFLINE_PLAN="$2"; shift 2 ;;
    --offline-plan-sha256) OFFLINE_PLAN_SHA256="$2"; shift 2 ;;
    --offline-sums) OFFLINE_SUMS="$2"; shift 2 ;;
    --offline-sums-sha256) OFFLINE_SUMS_SHA256="$2"; shift 2 ;;
    --baseline-e5a) BASELINE_E5A="$2"; shift 2 ;;
    --baseline-e5a-sha256) BASELINE_E5A_SHA256="$2"; shift 2 ;;
    --baseline-e5b) BASELINE_E5B="$2"; shift 2 ;;
    --baseline-e5b-sha256) BASELINE_E5B_SHA256="$2"; shift 2 ;;
    --registry-verified) REGISTRY_VERIFIED="$2"; shift 2 ;;
    --build-evidence-dir) BUILD_EVIDENCE_DIR="$2"; shift 2 ;;
    --evidence-dir) EVIDENCE_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown_arg=$1" 64 ;;
  esac
done

echo "===== TITAN 2 C3A V01.00.14 STANDARD FLASH PLAN / OFFLINE ONLY ====="
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "ADB_COMMANDS_RUN=NO"
echo "FASTBOOT_COMMANDS_RUN=NO"
echo "REBOOT_COMMANDS_RUN=NO"
echo "FLASH_AUTHORIZED=NO"
echo "FACTORY_RESET_AUTHORIZED=NO"
echo "LP_MUTATION_AUTHORIZED=NO"
echo "COW_CLEANUP_AUTHORIZED=NO"
echo "AVB_MUTATION_AUTHORIZED=NO"
echo "SLOT_MUTATION_AUTHORIZED=NO"
echo "WRITE_CAPABLE_SCRIPT_CREATED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"

[[ "${RELEASE^^}" == N1D ]] || fail "release=$RELEASE" 64
[[ "$BUILD_SOURCE" == "$EXPECTED_BUILD_SOURCE" ]] || fail "build_source=$BUILD_SOURCE" 64
[[ "$REQUESTED_SYSTEM_SHA256" == "$CANONICAL_SYSTEM_SHA256" ]] || fail system_sha_binding 64
[[ "$PREFLIGHT_SUMS_SHA256" == "$EXPECTED_PREFLIGHT_SEAL_SHA256" ]] || fail preflight_seal_binding 64
[[ "$OFFLINE_SUMS_SHA256" == "$EXPECTED_OFFLINE_SEAL_SHA256" ]] || fail offline_seal_binding 64
[[ "$BASELINE_E5B_SHA256" == "$EXPECTED_BASELINE_E5B_SHA256" ]] || fail baseline_e5b_binding 64
[[ "$REGISTRY_VERIFIED" == PASS ]] || fail registry_verification_required 64

[[ "$(basename "$PREFLIGHT_SUMS")" == SHA256SUMS.txt ]] || fail preflight_sums_name
[[ "$(basename "$PREFLIGHT_JSON")" == c3a-v010014-fastboot-entry-preflight.json ]] || fail preflight_json_name
[[ "$(dirname "$PREFLIGHT_JSON")" == "$(dirname "$PREFLIGHT_SUMS")" ]] || fail preflight_json_not_in_sealed_dir
[[ "$(basename "$OFFLINE_SUMS")" == SHA256SUMS.txt ]] || fail offline_sums_name
[[ "$(basename "$OFFLINE_PLAN")" == c3a-v010014-control-plan.env ]] || fail offline_plan_name
[[ "$(dirname "$OFFLINE_PLAN")" == "$(dirname "$OFFLINE_SUMS")" ]] || fail offline_plan_not_in_sealed_dir
[[ "$(basename "$BASELINE_E5A")" == e5a-readonly-device-state.json ]] || fail baseline_e5a_name
[[ "$(basename "$BASELINE_E5B")" == e5b-authorization-package.json ]] || fail baseline_e5b_name
[[ "$(dirname "$BASELINE_E5A")" == "$(dirname "$BASELINE_E5B")" ]] || fail baseline_evidence_dir_mismatch

for p in   "$SYSTEM_IMG"   "$PREFLIGHT_JSON"   "$PREFLIGHT_SUMS"   "$OFFLINE_PLAN"   "$OFFLINE_SUMS"   "$BASELINE_E5A"   "$BASELINE_E5B"   "$C3A_ENV"
do
  [[ -f "$p" ]] || fail "missing_file=$p" 66
done
[[ -d "$BUILD_EVIDENCE_DIR" ]] || fail "build_evidence_dir=$BUILD_EVIDENCE_DIR" 66
[[ -n "$EVIDENCE_DIR" ]] || fail evidence_dir_missing 64
mkdir -p "$EVIDENCE_DIR"

[[ "$(dirname "$PREFLIGHT_JSON")" == "$(dirname "$PREFLIGHT_SUMS")" ]] ||
  fail preflight_json_not_in_sealed_dir
[[ "$(basename "$PREFLIGHT_JSON")" == "c3a-v010014-fastboot-entry-preflight.json" ]] ||
  fail preflight_json_basename
[[ "$(basename "$PREFLIGHT_SUMS")" == "SHA256SUMS.txt" ]] ||
  fail preflight_sums_basename

[[ "$(dirname "$OFFLINE_PLAN")" == "$(dirname "$OFFLINE_SUMS")" ]] ||
  fail offline_plan_not_in_sealed_dir
[[ "$(basename "$OFFLINE_PLAN")" == "c3a-v010014-control-plan.env" ]] ||
  fail offline_plan_basename
[[ "$(basename "$OFFLINE_SUMS")" == "SHA256SUMS.txt" ]] ||
  fail offline_sums_basename

# shellcheck source=/dev/null
source "$C3A_ENV"
[[ "${N1D_C3A_CONTROL_EVIDENCE_STATUS:-}" == PASS_SYSTEMIMAGE ]] || fail c3a_evidence_status
[[ "${N1D_C3A_REGISTRY_BUILD_SOURCE:-}" == "$EXPECTED_BUILD_SOURCE" ]] || fail c3a_registry_build_source
[[ "${N1D_C3A_REGISTRY_BUILD_SOURCE_ROLE:-}" == POSTBUILD_EVIDENCE_SEAL_COMMIT_NOT_RECORDED_BUILD_START_HEAD ]] || fail c3a_registry_build_source_role
[[ "${N1D_C3A_SYSTEM_SHA256:-}" == "$CANONICAL_SYSTEM_SHA256" ]] || fail c3a_evidence_system_sha
[[ "${N1D_C3A_SYSTEM_BYTES:-}" == "$CANONICAL_SYSTEM_BYTES" ]] || fail c3a_evidence_system_bytes
[[ "${N1D_C3A_CONTROL_FIDELITY:-}" == PUBLIC_FUNCTIONAL_REPRODUCTION ]] || fail c3a_evidence_fidelity
[[ "${N1D_C3A_EVIDENCE_DIR:-}" == "$BUILD_EVIDENCE_DIR" ]] || fail c3a_build_evidence_dir

[[ "$(sha256sum "$SYSTEM_IMG" | awk '{print $1}')" == "$CANONICAL_SYSTEM_SHA256" ]] || fail system_sha
[[ "$(stat -c '%s' "$SYSTEM_IMG")" == "$CANONICAL_SYSTEM_BYTES" ]] || fail system_bytes
[[ "$(sha256sum "$PREFLIGHT_JSON" | awk '{print $1}')" == "$PREFLIGHT_JSON_SHA256" ]] || fail preflight_json_sha
[[ "$(sha256sum "$PREFLIGHT_SUMS" | awk '{print $1}')" == "$EXPECTED_PREFLIGHT_SEAL_SHA256" ]] || fail preflight_sums_sha
[[ "$(sha256sum "$OFFLINE_PLAN" | awk '{print $1}')" == "$OFFLINE_PLAN_SHA256" ]] || fail offline_plan_sha
[[ "$(sha256sum "$OFFLINE_SUMS" | awk '{print $1}')" == "$EXPECTED_OFFLINE_SEAL_SHA256" ]] || fail offline_sums_sha
[[ "$(sha256sum "$BASELINE_E5A" | awk '{print $1}')" == "$BASELINE_E5A_SHA256" ]] || fail baseline_e5a_sha
[[ "$(sha256sum "$BASELINE_E5B" | awk '{print $1}')" == "$EXPECTED_BASELINE_E5B_SHA256" ]] || fail baseline_e5b_sha

(
  cd "$(dirname "$PREFLIGHT_SUMS")"
  sha256sum -c "$(basename "$PREFLIGHT_SUMS")" >/dev/null
) || fail preflight_evidence_seal_invalid
(
  cd "$(dirname "$OFFLINE_SUMS")"
  sha256sum -c "$(basename "$OFFLINE_SUMS")" >/dev/null
) || fail offline_evidence_seal_invalid

grep -Eq "^[0-9a-f]{64}[[:space:]]+\*?\./c3a-v010014-fastboot-entry-preflight\.json$" "$PREFLIGHT_SUMS" ||
  fail preflight_json_not_listed_in_seal
grep -Eq "^[0-9a-f]{64}[[:space:]]+\*?\./c3a-v010014-control-plan\.env$" "$OFFLINE_SUMS" ||
  fail offline_plan_not_listed_in_seal

GSI_INFO_OUT="$EVIDENCE_DIR/gsi-image-info.txt"
python3 "$GSI_INFO" --image "$SYSTEM_IMG" | tee "$GSI_INFO_OUT"
grep -Fxq 'SABLE_GSI_IMAGE_INFO=PASS' "$GSI_INFO_OUT" || fail gsi_info
grep -Fxq 'GSI_IMAGE_FORMAT=raw' "$GSI_INFO_OUT" || fail gsi_format
grep -Fxq "GSI_IMAGE_FILE_BYTES=$CANONICAL_SYSTEM_BYTES" "$GSI_INFO_OUT" || fail gsi_file_bytes
grep -Fxq "GSI_IMAGE_LOGICAL_BYTES=$CANONICAL_SYSTEM_BYTES" "$GSI_INFO_OUT" || fail gsi_logical_bytes

PLAN_VALUES="$EVIDENCE_DIR/plan-values.env"
python3 -   "$PREFLIGHT_JSON"   "$OFFLINE_PLAN"   "$BASELINE_E5A"   "$BASELINE_E5B"   "$BASELINE_E5A_SHA256"   "$PLAN_VALUES" <<'PY'
from __future__ import annotations
import hashlib
import json
import pathlib
import sys

preflight_path = pathlib.Path(sys.argv[1])
offline_plan_path = pathlib.Path(sys.argv[2])
baseline_e5a_path = pathlib.Path(sys.argv[3])
baseline_e5b_path = pathlib.Path(sys.argv[4])
registered_e5a_sha = sys.argv[5]
out = pathlib.Path(sys.argv[6])

preflight = json.loads(preflight_path.read_text(encoding="utf-8"))
e5a = json.loads(baseline_e5a_path.read_text(encoding="utf-8"))
e5b = json.loads(baseline_e5b_path.read_text(encoding="utf-8"))

plan = {}
for raw in offline_plan_path.read_text(encoding="utf-8").splitlines():
    line = raw.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    key, value = line.split("=", 1)
    plan[key] = value

def die(reason: str) -> None:
    raise SystemExit(f"C3A_V010014_STANDARD_FLASH_PLAN=FAIL reason={reason}")

expected = {
    "phase": "C3A_V010014_FASTBOOT_ENTRY_PREFLIGHT",
    "final_state": "PASS_READY_FOR_PHYSICAL_CONTROL_REVIEW",
    "entry_state": "FASTBOOT_OR_FASTBOOTD_FROM_N1D_BOOTLOOP",
    "current_slot": "a",
    "is_userspace": "yes",
    "unlocked": "yes",
    "product": "Titan_2",
    "snapshot_update_status": "none",
    "system_a_current_bytes": 2994388992,
    "c3a_target_bytes": 3146977280,
    "active_cow_count": 0,
    "active_group": "main_a",
    "active_group_capacity_safe": True,
    "super_capacity_safe": True,
    "flash_authorized": False,
    "factory_reset_authorized": False,
    "lp_mutation_authorized": False,
    "cow_cleanup_authorized": False,
    "avb_mutation_authorized": False,
    "slot_mutation_authorized": False,
    "write_capable_script_created": False,
}
for key, wanted in expected.items():
    actual = preflight.get(key)
    if actual != wanted:
        die(f"preflight_field key={key} expected={wanted!r} actual={actual!r}")

if preflight.get("fastboot_device_binding_sha256") != "bcfdee61b23e3cb002919c27a055389ffe37e284bf5150dfc1d0bbbd7564090a":
    die("fastboot_binding")

if plan.get("C3A_V010014_CONTROL_PLAN") != "PREPARED_NO_WRITE":
    die("offline_plan_state")
if plan.get("C3A_SYSTEM_SHA256") != "4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16":
    die("offline_system_sha")
if plan.get("C3A_SYSTEM_LOGICAL_BYTES") != "3146977280":
    die("offline_system_bytes")
if plan.get("CURRENT_STOCK_INCREMENTAL") != "V01.00.14":
    die("offline_incremental")
if plan.get("EXPECTED_ACTIVE_SLOT") != "a":
    die("offline_slot")
if plan.get("FLASH_AUTHORIZED") != "NO" or plan.get("FACTORY_RESET_AUTHORIZED") != "NO":
    die("offline_write_boundary")

actual_e5a_sha = hashlib.sha256(baseline_e5a_path.read_bytes()).hexdigest()
if actual_e5a_sha != registered_e5a_sha:
    die("baseline_e5a_registered_sha")
if str(e5b.get("e5a_source_json_sha256", "")) != actual_e5a_sha:
    die("baseline_e5a_e5b_binding")
if e5a.get("final_state") != "PASS_REVIEW_READY":
    die("baseline_e5a_state")
if e5a.get("device_binding_verified") is not True:
    die("baseline_device_binding")

adb_hash = str(e5a.get("adb_device_binding_sha256", ""))
fastboot_hash = str(e5a.get("fastboot_device_binding_sha256", ""))
if len(adb_hash) != 64 or len(fastboot_hash) != 64:
    die("baseline_serial_hash")
if fastboot_hash != preflight.get("fastboot_device_binding_sha256"):
    die("baseline_fastboot_binding_changed")

remaining = int(preflight.get("remaining_headroom_after_growth_bytes", 0))
minimum = int(preflight.get("minimum_remaining_headroom_bytes", 0))
group_max = int(preflight.get("active_group_maximum_bytes", 0))
group_prospective = int(preflight.get("active_group_prospective_bytes", 0))
if minimum != 536870912 or remaining < minimum:
    die("super_headroom")
if group_max <= 0 or group_prospective > group_max:
    die("active_group_capacity")

lines = {
    "EXPECTED_FASTBOOT_BINDING_SHA256": fastboot_hash,
    "EXPECTED_ADB_BINDING_SHA256": adb_hash,
    "EXPECTED_SYSTEM_CURRENT_BYTES": int(preflight["system_a_current_bytes"]),
    "EXPECTED_SYSTEM_TARGET_BYTES": int(preflight["c3a_target_bytes"]),
    "EXPECTED_SUPER_BYTES": int(preflight["super_bytes"]),
    "EXPECTED_ACTIVE_COW_COUNT": int(preflight["active_cow_count"]),
    "MATERIALIZED_LOGICAL_BYTES": int(preflight["materialized_logical_bytes_estimate_from_sealed_baseline_plus_fresh_group_delta"]),
    "SYSTEM_GROWTH_BYTES": int(preflight["system_growth_bytes"]),
    "REMAINING_SUPER_HEADROOM_BYTES": remaining,
    "MINIMUM_REMAINING_HEADROOM_BYTES": minimum,
    "ACTIVE_GROUP_MAXIMUM_BYTES": group_max,
    "ACTIVE_GROUP_PROSPECTIVE_BYTES": group_prospective,
}
out.write_text(
    "".join(f"{key}={value}\n" for key, value in lines.items()),
    encoding="utf-8",
)
for key, value in lines.items():
    print(f"C3A_V010014_{key}={value}")
print("C3A_V010014_PREFLIGHT_PACKAGE=PASS_CONSUMED")
print("C3A_V010014_BASELINE_BINDING=PASS")
PY

# shellcheck source=/dev/null
source "$PLAN_VALUES"

[[ "$EXPECTED_SYSTEM_CURRENT_BYTES" == "$CANONICAL_SYSTEM_CURRENT_BYTES" ]] || fail preflash_size
[[ "$EXPECTED_SYSTEM_TARGET_BYTES" == "$CANONICAL_SYSTEM_BYTES" ]] || fail target_size
[[ "$EXPECTED_SUPER_BYTES" == "$CANONICAL_SUPER_BYTES" ]] || fail super_size
[[ "$EXPECTED_ACTIVE_COW_COUNT" == 0 ]] || fail active_cow_count
[[ "$REMAINING_SUPER_HEADROOM_BYTES" -ge "$MINIMUM_REMAINING_HEADROOM_BYTES" ]] || fail super_headroom
[[ "$ACTIVE_GROUP_PROSPECTIVE_BYTES" -le "$ACTIVE_GROUP_MAXIMUM_BYTES" ]] || fail group_capacity

PLAN="$EVIDENCE_DIR/titan2-n1d-c3a-control-standard-flash-plan.txt"
cat > "$PLAN" <<EOF
N1D_C3A_CONTROL_STANDARD_FLASH_PLAN=PREPARED_NO_WRITE
RELEASE=N1D
BUILD_SOURCE=$BUILD_SOURCE
CONTROL_FIDELITY=PUBLIC_FUNCTIONAL_REPRODUCTION
SYSTEM_IMG=$SYSTEM_IMG
SYSTEM_SHA256=$CANONICAL_SYSTEM_SHA256
SYSTEM_FORMAT=raw
SYSTEM_LOGICAL_BYTES=$CANONICAL_SYSTEM_BYTES
TARGET_PARTITION=system_a
EXPECTED_FASTBOOT_PRODUCT=$CANONICAL_PRODUCT
EXPECTED_ACTIVE_SLOT=$CANONICAL_SLOT
EXPECTED_FASTBOOT_BINDING_SHA256=$EXPECTED_FASTBOOT_BINDING_SHA256
EXPECTED_SYSTEM_CURRENT_BYTES=$EXPECTED_SYSTEM_CURRENT_BYTES
EXPECTED_SUPER_BYTES=$CANONICAL_SUPER_BYTES
EXPECTED_ACTIVE_COW_COUNT=0
FLASH_ENTRY_MODE=userspace-fastbootd
FLASH_OPERATION=STANDARD_ADAPTER_FASTBOOT_FLASH_SYSTEM_A_ONLY
FASTBOOT_IMPLICIT_RESIZE=YES
FASTBOOT_IMPLICIT_RESIZE_TARGET_BYTES=$CANONICAL_SYSTEM_BYTES
SYSTEM_GROWTH_BYTES=$SYSTEM_GROWTH_BYTES
ACTIVE_GROUP=$CANONICAL_ACTIVE_GROUP
ACTIVE_GROUP_PROSPECTIVE_BYTES=$ACTIVE_GROUP_PROSPECTIVE_BYTES
ACTIVE_GROUP_MAXIMUM_BYTES=$ACTIVE_GROUP_MAXIMUM_BYTES
REMAINING_SUPER_HEADROOM_BYTES=$REMAINING_SUPER_HEADROOM_BYTES
MINIMUM_REMAINING_HEADROOM_BYTES=$MINIMUM_REMAINING_HEADROOM_BYTES
MANUAL_PRE_RESIZE_REQUIRED=NO
COW_DELETION_ALLOWED=NO
SLOT_CHANGE_ALLOWED=NO
AVB_MUTATION_ALLOWED=NO
BOOT_CHAIN_FLASH_ALLOWED=NO
WHOLE_SUPER_FLASH_ALLOWED=NO
USERDATA_ERASE_ALLOWED=NO
FACTORY_RESET_ALLOWED=NO
POST_WRITE_REBOOT_COUNT=1
POSTBOOT_OBSERVATION_ONLY=YES
AUTOMATIC_FLASH_RETRY_ALLOWED=NO
PREFLIGHT_JSON_SHA256=$PREFLIGHT_JSON_SHA256
PREFLIGHT_EVIDENCE_SEAL_SHA256=$EXPECTED_PREFLIGHT_SEAL_SHA256
OFFLINE_CONTROL_PLAN_SHA256=$OFFLINE_PLAN_SHA256
OFFLINE_CONTROL_EVIDENCE_SEAL_SHA256=$EXPECTED_OFFLINE_SEAL_SHA256
BASELINE_E5A_SHA256=$BASELINE_E5A_SHA256
BASELINE_E5B_SHA256=$EXPECTED_BASELINE_E5B_SHA256
WRITE_CAPABLE_SCRIPT_CREATED=NO
FLASH_AUTHORIZED=NO
FACTORY_RESET_AUTHORIZED=NO
EXECUTION_GATE=SEPARATE_STANDARD_ADAPTER_SCOPE_TOKEN_BOUND_TO_THIS_PLAN_SEAL_REQUIRED
EOF

(
  cd "$EVIDENCE_DIR"
  find . -type f ! -name SHA256SUMS.txt -print0 |
    LC_ALL=C sort -z |
    xargs -0 sha256sum > SHA256SUMS.txt
  sha256sum -c SHA256SUMS.txt >/dev/null
)

echo "FLASH_PLAN=$PLAN"
echo "C3A_V010014_STANDARD_FLASH_PLAN_EVIDENCE_SEAL_SHA256=$(sha256sum "$EVIDENCE_DIR/SHA256SUMS.txt" | awk '{print $1}')"
echo "C3A_V010014_STANDARD_FLASH_PLAN_EXECUTION_SUPPORTED=NO_PENDING_SCOPE_BINDING"
echo "C3A_V010014_STANDARD_FLASH_PLAN_FLASH_AUTHORIZED=NO"
echo "C3A_V010014_STANDARD_FLASH_PLAN_FACTORY_RESET_AUTHORIZED=NO"
echo "C3A_V010014_STANDARD_FLASH_PLAN=PASS_PREPARED_NO_WRITE"
