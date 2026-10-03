#!/usr/bin/env bash
set -euo pipefail
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PYTHON="${SABLE_PYTHON:-python3}"

PROVIDER_EVIDENCE=""
E5A_JSON=""
E5B_JSON=""
SYSTEM_IMG=""
EVIDENCE_DIR=""

EXPECTED_PROVIDER_DECISION="BLOCKED_BOTH_EXACT_OBJECTS_NOT_ADDRESSABLE"
EXPECTED_PROVIDER_SEAL="fce7ed70c41ef99ccfa0ff4ec9e8c5a39a738cef6cdb266fc1ba3496c0203730"

C3A_ENV="$ROOT/build/titan2/n1d-c3a-control-evidence.env"
C3A_GATE="$ROOT/build/gates/n1d-c3a-control-evidence-contract.sh"

EXPECTED_C3A_SHA256="4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16"
EXPECTED_C3A_BYTES=3146977280
EXPECTED_C3A_PATCH_COUNT=369
EXPECTED_C3A_MANAGED_PROJECT_COUNT=991

EXPECTED_E5B_SHA256="74531923a9ea6c755a9f8ea52db511c4a4a19a5d9dba3cb51da342c04b768926"
EXPECTED_CURRENT_INCREMENTAL="V01.00.14"
EXPECTED_SLOT="a"
EXPECTED_FASTBOOT_PRODUCT="Titan_2"
EXPECTED_SUPER_BYTES=9663676416
MINIMUM_REMAINING_HEADROOM_BYTES=536870912

usage() {
  cat >&2 <<'USAGE'
usage:
  bash build/titan2/prepare-c3a-v010014-runtime-control.sh \
    --provider-evidence-dir /absolute/path \
    --e5a-json /absolute/path/e5a-readonly-device-state.json \
    --e5b-json /absolute/path/e5b-authorization-package.json \
    [--system-img /absolute/path/to/c3a/system.img] \
    [--evidence-dir /absolute/path/output]

Offline only. This command retires the exact-N1B/N1E path as unavailable,
verifies the sealed C3A public-functional Restless/TrebleDroid system image,
binds the V01.00.14 evidence, and emits a no-write physical-control plan.

It never runs adb, fastboot, repo sync, an Android build, a factory reset,
or any partition mutation.
USAGE
}

fail() {
  echo "C3A_V010014_CONTROL_PREP=FAIL reason=$*" >&2
  exit 1
}

while (($#)); do
  case "$1" in
    --provider-evidence-dir) PROVIDER_EVIDENCE="${2:-}"; shift 2 ;;
    --e5a-json) E5A_JSON="${2:-}"; shift 2 ;;
    --e5b-json) E5B_JSON="${2:-}"; shift 2 ;;
    --system-img) SYSTEM_IMG="${2:-}"; shift 2 ;;
    --evidence-dir) EVIDENCE_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage; exit 64 ;;
  esac
done

for pair in   "provider-evidence-dir:$PROVIDER_EVIDENCE"   "e5a-json:$E5A_JSON"   "e5b-json:$E5B_JSON"
do
  name="${pair%%:*}"
  path="${pair#*:}"
  [[ "$path" = /* ]] || fail "$name must be an absolute path"
done

[[ -d "$PROVIDER_EVIDENCE" ]] || fail "provider evidence missing path=$PROVIDER_EVIDENCE"
[[ -f "$PROVIDER_EVIDENCE/SHA256SUMS.txt" ]] || fail "provider evidence seal missing"
[[ -f "$PROVIDER_EVIDENCE/decision.env" ]] || fail "provider decision missing"
[[ -f "$E5A_JSON" ]] || fail "E5A json missing path=$E5A_JSON"
[[ -f "$E5B_JSON" ]] || fail "E5B json missing path=$E5B_JSON"
[[ -f "$C3A_ENV" ]] || fail "C3A evidence env missing"
[[ -x "$C3A_GATE" || -f "$C3A_GATE" ]] || fail "C3A evidence gate missing"
command -v "$PYTHON" >/dev/null 2>&1 || fail python_missing
command -v sha256sum >/dev/null 2>&1 || fail sha256sum_missing

(
  cd "$PROVIDER_EVIDENCE"
  sha256sum -c SHA256SUMS.txt >/dev/null
) || fail "provider evidence seal invalid"

provider_seal="$(sha256sum "$PROVIDER_EVIDENCE/SHA256SUMS.txt" | awk '{print $1}')"
[[ "$provider_seal" == "$EXPECTED_PROVIDER_SEAL" ]] ||
  fail "provider evidence seal expected=$EXPECTED_PROVIDER_SEAL actual=$provider_seal"

# shellcheck source=/dev/null
source "$PROVIDER_EVIDENCE/decision.env"
[[ "${N1B_PROVIDER_OBJECT_EXISTENCE:-}" == "$EXPECTED_PROVIDER_DECISION" ]] ||
  fail "provider decision expected=$EXPECTED_PROVIDER_DECISION actual=${N1B_PROVIDER_OBJECT_EXISTENCE:-MISSING}"
[[ "${N1B_TREBLE_EXACT_OBJECT_EXISTENCE:-}" == "ABSENT_FROM_CHECKED_AUTHENTIC_GITHUB_LINEAGE" ]] ||
  fail "Treble exact-object decision mismatch"
[[ "${N1B_VNDK29_EXACT_OBJECT_EXISTENCE:-}" == "ABSENT_CONFIRMED" ]] ||
  fail "VNDK29 exact-object decision mismatch"

bash "$C3A_GATE" >/dev/null || fail "C3A control evidence contract failed"

# shellcheck source=/dev/null
source "$C3A_ENV"
[[ "${N1D_C3A_CONTROL_EVIDENCE_STATUS:-}" == "PASS_SYSTEMIMAGE" ]] ||
  fail "C3A status mismatch"
[[ "${N1D_C3A_SYSTEM_SHA256:-}" == "$EXPECTED_C3A_SHA256" ]] ||
  fail "C3A evidence sha mismatch"
[[ "${N1D_C3A_SYSTEM_BYTES:-}" == "$EXPECTED_C3A_BYTES" ]] ||
  fail "C3A evidence bytes mismatch"
[[ "${N1D_C3A_CONTROL_PATCH_COUNT:-}" == "$EXPECTED_C3A_PATCH_COUNT" ]] ||
  fail "C3A patch count mismatch"
[[ "${N1D_C3A_MANAGED_PROJECT_COUNT:-}" == "$EXPECTED_C3A_MANAGED_PROJECT_COUNT" ]] ||
  fail "C3A project count mismatch"
[[ "${N1D_C3A_CONTROL_FIDELITY:-}" == "PUBLIC_FUNCTIONAL_REPRODUCTION" ]] ||
  fail "C3A fidelity mismatch"

if [[ -n "$SYSTEM_IMG" && "$SYSTEM_IMG" != /* ]]; then
  fail "system-img must be absolute when supplied"
fi

if [[ -z "$SYSTEM_IMG" ]]; then
  SYSTEM_IMG="${N1D_C3A_SYSTEM_IMG:-}"
fi

validate_c3a() {
  local p="$1"
  [[ -f "$p" ]] || return 1
  [[ "$(stat -c '%s' "$p")" == "$EXPECTED_C3A_BYTES" ]] || return 1
  [[ "$(sha256sum "$p" | awk '{print $1}')" == "$EXPECTED_C3A_SHA256" ]] || return 1
}

if ! validate_c3a "$SYSTEM_IMG"; then
  SYSTEM_IMG=""
  while IFS= read -r candidate; do
    if validate_c3a "$candidate"; then
      SYSTEM_IMG="$candidate"
      break
    fi
  done < <(
    find /srv/sable-build/workspaces /srv/sable-build/artifacts/titan2       -type f -size "${EXPECTED_C3A_BYTES}c" -name 'system.img' -print 2>/dev/null |
      LC_ALL=C sort -u
  )
fi

[[ -n "$SYSTEM_IMG" ]] || fail "exact sealed C3A system.img not found"
[[ -f "$SYSTEM_IMG" ]] || fail "resolved C3A image missing"

if [[ -z "$EVIDENCE_DIR" ]]; then
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  EVIDENCE_DIR="${SABLE_EVIDENCE_ROOT:-/srv/sable-build/evidence}/titan2/c3a-v010014-control/${stamp}_offline-plan"
fi
[[ "$EVIDENCE_DIR" = /* ]] || fail "evidence-dir must be absolute"
[[ ! -e "$EVIDENCE_DIR" ]] || fail "evidence-dir exists path=$EVIDENCE_DIR"
mkdir -p "$EVIDENCE_DIR"

exec > >(tee "$EVIDENCE_DIR/prepare.log") 2>&1

echo "===== TITAN 2 C3A V01.00.14 CONTROL PREPARATION ====="
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "FACTORY_RESET_AUTHORIZED=NO"
echo "ANDROID_BUILD_AUTHORIZED=NO"
echo "N1B_EXACT_REBUILD_AUTHORIZED=NO"
echo "N1B_V010014_PHYSICAL_CONTROL_AUTHORIZED=NO"
echo "N1E_BUILD_AUTHORIZED=NO"
echo "N1E_STATUS=RETIRED_EXACT_N1B_PREREQUISITE_UNAVAILABLE"
echo "C3A_V010014_PHYSICAL_CONTROL_AUTHORIZED=NO"
echo "C3A_DERIVED_ISOLATION_BUILD_AUTHORIZED=NO"

echo
echo "===== RETIRE EXACT N1B / N1E PATH ====="
echo "N1B_PROVIDER_EVIDENCE_DIR=$PROVIDER_EVIDENCE"
echo "N1B_PROVIDER_EVIDENCE_SEAL_SHA256=$provider_seal"
echo "N1B_EXACT_RECONSTRUCTION=RETIRED_BOTH_CRITICAL_SOURCE_OBJECTS_NOT_ADDRESSABLE"
echo "N1E_STATUS=RETIRED_EXACT_N1B_PREREQUISITE_UNAVAILABLE"

echo
echo "===== C3A ARTIFACT ====="
actual_sha="$(sha256sum "$SYSTEM_IMG" | awk '{print $1}')"
actual_bytes="$(stat -c '%s' "$SYSTEM_IMG")"
[[ "$actual_sha" == "$EXPECTED_C3A_SHA256" ]] || fail "C3A sha mismatch"
[[ "$actual_bytes" == "$EXPECTED_C3A_BYTES" ]] || fail "C3A bytes mismatch"

"$PYTHON" "$ROOT/build/deploy/gsi_image_info.py" --image "$SYSTEM_IMG" > "$EVIDENCE_DIR/system-image-geometry.txt" ||
  fail "C3A image geometry inspection failed"
grep -Fxq 'GSI_IMAGE_FORMAT=raw' "$EVIDENCE_DIR/system-image-geometry.txt" ||
  fail "C3A image format not raw"
grep -Fxq "GSI_IMAGE_FILE_BYTES=$EXPECTED_C3A_BYTES" "$EVIDENCE_DIR/system-image-geometry.txt" ||
  fail "C3A file bytes geometry mismatch"
grep -Fxq "GSI_IMAGE_LOGICAL_BYTES=$EXPECTED_C3A_BYTES" "$EVIDENCE_DIR/system-image-geometry.txt" ||
  fail "C3A logical bytes geometry mismatch"

echo "C3A_SYSTEM_IMG=$SYSTEM_IMG"
echo "C3A_SYSTEM_SHA256=PASS value=$actual_sha"
echo "C3A_SYSTEM_BYTES=PASS value=$actual_bytes"
echo "C3A_CONTROL_PATCH_COUNT=$EXPECTED_C3A_PATCH_COUNT"
echo "C3A_CONTROL_FIDELITY=PUBLIC_FUNCTIONAL_REPRODUCTION"

echo
echo "===== SEALED CURRENT-FIRMWARE EVIDENCE ====="
e5a_sha="$(sha256sum "$E5A_JSON" | awk '{print $1}')"
e5b_sha="$(sha256sum "$E5B_JSON" | awk '{print $1}')"
[[ "$e5b_sha" == "$EXPECTED_E5B_SHA256" ]] ||
  fail "E5B sha expected=$EXPECTED_E5B_SHA256 actual=$e5b_sha"

"$PYTHON" - "$E5A_JSON" "$E5B_JSON" "$e5a_sha"   "$EXPECTED_CURRENT_INCREMENTAL" "$EXPECTED_SLOT" "$EXPECTED_SUPER_BYTES"   "$EVIDENCE_DIR/e5a-binding.env" <<'PY'
from __future__ import annotations
import json
import pathlib
import sys

e5a_path = pathlib.Path(sys.argv[1])
e5b_path = pathlib.Path(sys.argv[2])
e5a_sha = sys.argv[3]
expected_incremental = sys.argv[4]
expected_slot = sys.argv[5]
expected_super = int(sys.argv[6])
out = pathlib.Path(sys.argv[7])

e5a = json.loads(e5a_path.read_text(encoding="utf-8"))
e5b = json.loads(e5b_path.read_text(encoding="utf-8"))

def die(msg: str) -> None:
    raise SystemExit(f"C3A_V010014_CONTROL_PREP=FAIL reason={msg}")

if e5a.get("final_state") != "PASS_REVIEW_READY":
    die("E5A final state mismatch")
if e5a.get("device_binding_verified") is not True:
    die("E5A device binding not verified")
stock = e5a.get("stock") or {}
if stock.get("incremental") != expected_incremental:
    die(f"stock incremental mismatch actual={stock.get('incremental')!r}")
if stock.get("incremental_match") is not True or stock.get("fingerprint_match") is not True:
    die("stock identity not sealed matching")
fb = e5a.get("fastbootd") or {}
if fb.get("current_slot") != expected_slot:
    die("slot mismatch")
if str(fb.get("is_userspace", "")).lower() != "yes":
    die("not userspace fastbootd")
if str(fb.get("unlocked", "")).lower() != "yes":
    die("bootloader not unlocked")
if str(fb.get("snapshot_update_status", "")).lower() != "none":
    die("snapshot update not none")
if int(fb.get("super_bytes", 0) or 0) != expected_super:
    die("super size mismatch")
if fb.get("allocation_complete") is not True or fb.get("capacity_safe") is not True:
    die("logical allocation/capacity not sealed safe")
if str(e5b.get("e5a_source_json_sha256", "")) != e5a_sha:
    die("E5B does not bind supplied E5A json")

out.write_text(
    "\n".join([
        f"E5A_JSON_SHA256={e5a_sha}",
        f"SEALED_STOCK_INCREMENTAL={stock.get('incremental', '')}",
        f"SEALED_STOCK_FINGERPRINT={stock.get('fingerprint', '')}",
        f"SEALED_VENDOR_FINGERPRINT={stock.get('vendor_fingerprint', '')}",
        f"EXPECTED_FASTBOOT_BINDING_SHA256={e5a.get('fastboot_device_binding_sha256', '')}",
        f"SEALED_SLOT={fb.get('current_slot', '')}",
        f"SEALED_SUPER_BYTES={fb.get('super_bytes', 0)}",
        "",
    ]),
    encoding="utf-8",
)
print("C3A_V010014_E5A_E5B_BINDING=PASS")
PY

# shellcheck source=/dev/null
source "$EVIDENCE_DIR/e5a-binding.env"
echo "CURRENT_FIRMWARE_INCREMENTAL=$SEALED_STOCK_INCREMENTAL"
echo "CURRENT_FIRMWARE_EVIDENCE=PASS_SEALED_V010014"

echo
echo "===== NO-WRITE CONTROL PLAN ====="
plan="$EVIDENCE_DIR/c3a-v010014-control-plan.env"
cat > "$plan" <<EOF_PLAN
C3A_V010014_CONTROL_PLAN=PREPARED_NO_WRITE
C3A_SYSTEM_IMG=$SYSTEM_IMG
C3A_SYSTEM_SHA256=$EXPECTED_C3A_SHA256
C3A_SYSTEM_LOGICAL_BYTES=$EXPECTED_C3A_BYTES
C3A_CONTROL_PATCH_COUNT=$EXPECTED_C3A_PATCH_COUNT
C3A_CONTROL_FIDELITY=PUBLIC_FUNCTIONAL_REPRODUCTION
CURRENT_STOCK_INCREMENTAL=$SEALED_STOCK_INCREMENTAL
SEALED_STOCK_FINGERPRINT=$SEALED_STOCK_FINGERPRINT
SEALED_VENDOR_FINGERPRINT=$SEALED_VENDOR_FINGERPRINT
EXPECTED_FASTBOOT_BINDING_SHA256=$EXPECTED_FASTBOOT_BINDING_SHA256
EXPECTED_FASTBOOT_PRODUCT=$EXPECTED_FASTBOOT_PRODUCT
EXPECTED_ACTIVE_SLOT=$EXPECTED_SLOT
EXPECTED_SUPER_BYTES=$EXPECTED_SUPER_BYTES
TARGET_PARTITION=system_a
FLASH_ENTRY_MODE=userspace-fastbootd
LIVE_PREFLIGHT_REQUIRED=YES
LIVE_REQUIRE_DEVICE_BINDING_MATCH=YES
LIVE_REQUIRE_ACTIVE_SLOT=a
LIVE_REQUIRE_IS_USERSPACE=yes
LIVE_REQUIRE_UNLOCKED=yes
LIVE_REQUIRE_SNAPSHOT_UPDATE_STATUS=none
LIVE_REQUIRE_SYSTEM_A_LOGICAL=yes
LIVE_REQUIRE_ACTIVE_COW_COUNT=0
LIVE_REQUIRE_COMPLETE_LOGICAL_ALLOCATION=YES
LIVE_REQUIRE_CAPACITY_CHECK=YES
MINIMUM_REMAINING_HEADROOM_BYTES=$MINIMUM_REMAINING_HEADROOM_BYTES
FASTBOOT_IMPLICIT_RESIZE_EXPECTED=YES
FASTBOOT_IMPLICIT_RESIZE_TARGET_BYTES=$EXPECTED_C3A_BYTES
MANUAL_PRE_RESIZE_ALLOWED=NO
COW_DELETION_ALLOWED=NO
SLOT_CHANGE_ALLOWED=NO
AVB_MUTATION_ALLOWED=NO
BOOT_CHAIN_FLASH_ALLOWED=NO
WHOLE_SUPER_FLASH_ALLOWED=NO
USERDATA_ERASE_DURING_FLASH_ALLOWED=NO
FACTORY_RESET_DURING_FLASH_ALLOWED=NO
POST_FLASH_AUTOMATIC_RETRY_ALLOWED=NO
POST_FLASH_OBSERVE_TERMINAL_STATE=ANDROID_BOOT_COMPLETED_OR_RECOVERY_OR_FASTBOOT_RETURN
RECOVERY_RESULT_REQUIRES_SEPARATE_FACTORY_RESET_AUTHORIZATION=YES
TELEMETRY_AFTER_RESET_REQUIRED=YES
C2_FALLBACK_CONTROL=REVIEW_ONLY_IF_C3A_UNAVAILABLE_OR_INCONCLUSIVE
N1E_STATUS=RETIRED_EXACT_N1B_PREREQUISITE_UNAVAILABLE
C3A_DERIVED_ISOLATION_BUILD=RESERVED_PENDING_C3A_V010014_BOOT
FLASH_AUTHORIZED=NO
FACTORY_RESET_AUTHORIZED=NO
WRITE_CAPABLE_SCRIPT_CREATED=NO
EOF_PLAN

(
  cd "$EVIDENCE_DIR"
  find . -type f ! -name SHA256SUMS.txt ! -name prepare.log -print0 |
    LC_ALL=C sort -z |
    xargs -0 sha256sum > SHA256SUMS.txt
  sha256sum -c SHA256SUMS.txt >/dev/null
)

echo "CONTROL_PLAN=$plan"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "EVIDENCE_SEAL_SHA256=$(sha256sum "$EVIDENCE_DIR/SHA256SUMS.txt" | awk '{print $1}')"
echo "C3A_V010014_CONTROL_ARTIFACT=PASS_EXACT_SEALED_C3A"
echo "C3A_V010014_CONTROL_CURRENT_FIRMWARE_EVIDENCE=PASS_SEALED_V010014"
echo "C3A_V010014_CONTROL_PLAN=PASS_PREPARED_NO_WRITE"
echo "C3A_V010014_CONTROL_FLASH_AUTHORIZED=NO"
echo "C3A_V010014_CONTROL_FACTORY_RESET_AUTHORIZED=NO"
echo "C3A_V010014_CONTROL_PREP=PASS"
