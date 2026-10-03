#!/usr/bin/env bash
set -euo pipefail
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PYTHON="${SABLE_PYTHON:-python3}"
LEDGER="$ROOT/docs/titan2/N1B_FIRST_BOOT_LEDGER_AND_N1B2_HANDOFF.md"
SYSTEM_IMG=""
E5A_JSON=""
E5B_JSON=""
EVIDENCE_DIR=""

EXPECTED_N1B_SOURCE="8dd06e77410fea131e4716447f7f05067e427654"
EXPECTED_N1B_SHA256="bc550bfaf8463324c122abb490cf4aba956b89e7e4d42168a55f0f0f0f5b638e"
EXPECTED_N1B_BYTES=3180666880
EXPECTED_E5B_SHA256="74531923a9ea6c755a9f8ea52db511c4a4a19a5d9dba3cb51da342c04b768926"
EXPECTED_CURRENT_INCREMENTAL="V01.00.14"
EXPECTED_SLOT="a"
EXPECTED_FASTBOOT_PRODUCT="Titan_2"
EXPECTED_SUPER_BYTES=9663676416
MINIMUM_REMAINING_HEADROOM_BYTES=536870912

usage() {
  cat >&2 <<'USAGE'
usage:
  bash build/titan2/prepare-n1b-v010014-control.sh \
    --system-img /absolute/path/to/n1b/system.img \
    --e5a-json /absolute/path/e5a-readonly-device-state.json \
    --e5b-json /absolute/path/e5b-authorization-package.json \
    [--evidence-dir /absolute/path/output]

This command is offline-only. It never runs adb or fastboot and never authorizes
flash, erase, resize, AVB mutation, slot mutation, factory reset, or N1E build.
USAGE
}

fail() {
  echo "N1B_V010014_CONTROL_PREP=FAIL reason=$*" >&2
  exit 1
}

while (($#)); do
  case "$1" in
    --system-img) SYSTEM_IMG="${2:-}"; shift 2 ;;
    --e5a-json) E5A_JSON="${2:-}"; shift 2 ;;
    --e5b-json) E5B_JSON="${2:-}"; shift 2 ;;
    --evidence-dir) EVIDENCE_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage; exit 64 ;;
  esac
done

for pair in \
  "system-img:$SYSTEM_IMG" \
  "e5a-json:$E5A_JSON" \
  "e5b-json:$E5B_JSON"
do
  name="${pair%%:*}"
  path="${pair#*:}"
  [[ "$path" = /* ]] || fail "$name must be an absolute path"
  [[ -f "$path" ]] || fail "$name missing path=$path"
done
[[ -f "$LEDGER" ]] || fail "historical ledger missing path=$LEDGER"
command -v "$PYTHON" >/dev/null 2>&1 || fail "python unavailable command=$PYTHON"

if [[ -z "$EVIDENCE_DIR" ]]; then
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  EVIDENCE_DIR="${SABLE_DEVICE_EVIDENCE_ROOT:-/srv/sable-build/evidence}/titan2/n1b-v010014-control/${stamp}_offline-plan"
fi
[[ "$EVIDENCE_DIR" = /* ]] || fail "evidence-dir must be an absolute path"
[[ ! -e "$EVIDENCE_DIR" ]] || fail "evidence-dir already exists path=$EVIDENCE_DIR"
mkdir -p "$EVIDENCE_DIR"

exec > >(tee "$EVIDENCE_DIR/prepare.log") 2>&1

echo "===== TITAN 2 N1B V01.00.14 CONTROL PREPARATION ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "IMAGE_BUILD_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "ERASE_AUTHORIZED=NO"
echo "LP_MUTATION_AUTHORIZED=NO"
echo "AVB_MUTATION_AUTHORIZED=NO"
echo "SLOT_MUTATION_AUTHORIZED=NO"
echo "FACTORY_RESET_AUTHORIZED=NO"
echo "ADB_COMMANDS_RUN=NO"
echo "FASTBOOT_COMMANDS_RUN=NO"
echo "N1E_BUILD_AUTHORIZED=NO"

echo
echo "===== HISTORICAL N1B AUTHORITY ====="
for marker in \
  "SOURCE_COMMIT=$EXPECTED_N1B_SOURCE" \
  "SYSTEM_SHA256=$EXPECTED_N1B_SHA256" \
  "SYSTEM_BYTES=$EXPECTED_N1B_BYTES" \
  'TARGET_PARTITION=system_a' \
  'ACTIVE_SLOT_BEFORE_FLASH=a' \
  'FLASH_RESULT=PASS_SYSTEM_A_WRITTEN' \
  'AVB_MUTATION=NO' \
  'BOOT_VENDOR_VBMETA_FLASH=NO' \
  'SLOT_CHANGE=NO' \
  'BOOT_COMPLETED=PASS' \
  'FIRST_N1B_BOOT=PASS'
do
  grep -Fq -- "$marker" "$LEDGER" || fail "ledger marker missing: $marker"
done
ledger_sha="$(sha256sum "$LEDGER" | awk '{print $1}')"
echo "N1B_LEDGER_SHA256=$ledger_sha"
echo "N1B_LEDGER_BINDING=PASS"

echo
echo "===== N1B ARTIFACT ====="
actual_sha="$(sha256sum "$SYSTEM_IMG" | awk '{print $1}')"
actual_bytes="$(stat -c '%s' "$SYSTEM_IMG")"
[[ "$actual_sha" == "$EXPECTED_N1B_SHA256" ]] || fail "N1B sha256 expected=$EXPECTED_N1B_SHA256 actual=$actual_sha"
[[ "$actual_bytes" == "$EXPECTED_N1B_BYTES" ]] || fail "N1B bytes expected=$EXPECTED_N1B_BYTES actual=$actual_bytes"

"$PYTHON" "$ROOT/build/deploy/gsi_image_info.py" --image "$SYSTEM_IMG" > "$EVIDENCE_DIR/system-image-geometry.txt" ||
  fail "gsi image geometry inspection failed"
grep -Fxq 'GSI_IMAGE_FORMAT=raw' "$EVIDENCE_DIR/system-image-geometry.txt" || fail "N1B image format is not raw"
grep -Fxq "GSI_IMAGE_FILE_BYTES=$EXPECTED_N1B_BYTES" "$EVIDENCE_DIR/system-image-geometry.txt" || fail "N1B file byte geometry mismatch"
grep -Fxq "GSI_IMAGE_LOGICAL_BYTES=$EXPECTED_N1B_BYTES" "$EVIDENCE_DIR/system-image-geometry.txt" || fail "N1B logical byte geometry mismatch"
echo "N1B_SYSTEM_SHA256=PASS value=$actual_sha"
echo "N1B_SYSTEM_BYTES=PASS value=$actual_bytes"
echo "N1B_SYSTEM_GEOMETRY=PASS_RAW_LOGICAL_EXACT"

echo
echo "===== SEALED CURRENT-FIRMWARE EVIDENCE ====="
e5a_sha="$(sha256sum "$E5A_JSON" | awk '{print $1}')"
e5b_sha="$(sha256sum "$E5B_JSON" | awk '{print $1}')"
[[ "$e5b_sha" == "$EXPECTED_E5B_SHA256" ]] || fail "E5B decision sha expected=$EXPECTED_E5B_SHA256 actual=$e5b_sha"

"$PYTHON" - "$E5A_JSON" "$E5B_JSON" "$e5a_sha" "$EXPECTED_CURRENT_INCREMENTAL" "$EXPECTED_SLOT" "$EXPECTED_SUPER_BYTES" "$EVIDENCE_DIR/e5a-binding.env" <<'PY'
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
    raise SystemExit(f"N1B_V010014_CONTROL_PREP=FAIL reason={msg}")

if e5a.get("final_state") != "PASS_REVIEW_READY":
    die(f"e5a final_state={e5a.get('final_state')!r}")
if e5a.get("device_binding_verified") is not True:
    die("e5a device binding not verified")
stock = e5a.get("stock") or {}
if stock.get("incremental") != expected_incremental:
    die(f"stock incremental expected={expected_incremental!r} actual={stock.get('incremental')!r}")
if stock.get("incremental_match") is not True or stock.get("fingerprint_match") is not True:
    die("e5a stock identity was not sealed as matching")
fb = e5a.get("fastbootd") or {}
if fb.get("current_slot") != expected_slot:
    die(f"e5a slot expected={expected_slot!r} actual={fb.get('current_slot')!r}")
if str(fb.get("is_userspace", "")).lower() != "yes":
    die("e5a final mode was not userspace fastbootd")
if str(fb.get("unlocked", "")).lower() != "yes":
    die("e5a bootloader was not unlocked")
if str(fb.get("snapshot_update_status", "")).lower() != "none":
    die(f"e5a snapshot status={fb.get('snapshot_update_status')!r}")
if int(fb.get("super_bytes", 0) or 0) != expected_super:
    die(f"super bytes expected={expected_super} actual={fb.get('super_bytes')!r}")
if fb.get("allocation_complete") is not True:
    die("e5a logical allocation was not complete")
if fb.get("capacity_safe") is not True:
    die("e5a capacity was not safe")
expected_e5a_sha = str(e5b.get("e5a_source_json_sha256", ""))
if expected_e5a_sha != e5a_sha:
    die(f"E5B does not bind supplied E5A json expected={expected_e5a_sha!r} actual={e5a_sha!r}")
fastboot_hash = str(e5a.get("fastboot_device_binding_sha256", ""))
adb_hash = str(e5a.get("adb_device_binding_sha256", ""))
if len(fastboot_hash) != 64 or len(adb_hash) != 64:
    die("sealed device binding hash missing")

fingerprint = str(stock.get("fingerprint", ""))
vendor_fingerprint = str(stock.get("vendor_fingerprint", ""))
out.write_text(
    "\n".join([
        f"E5A_JSON_SHA256={e5a_sha}",
        f"EXPECTED_FASTBOOT_BINDING_SHA256={fastboot_hash}",
        f"EXPECTED_ADB_BINDING_SHA256={adb_hash}",
        f"SEALED_STOCK_FINGERPRINT={fingerprint}",
        f"SEALED_VENDOR_FINGERPRINT={vendor_fingerprint}",
        f"SEALED_STOCK_INCREMENTAL={stock.get('incremental', '')}",
        f"SEALED_SLOT={fb.get('current_slot', '')}",
        f"SEALED_SUPER_BYTES={fb.get('super_bytes', 0)}",
        "",
    ]),
    encoding="utf-8",
)
print("N1B_V010014_E5A_E5B_BINDING=PASS")
PY

# shellcheck source=/dev/null
source "$EVIDENCE_DIR/e5a-binding.env"
echo "E5A_JSON_SHA256=$E5A_JSON_SHA256"
echo "E5B_JSON_SHA256=$e5b_sha"
echo "CURRENT_FIRMWARE_INCREMENTAL=$SEALED_STOCK_INCREMENTAL"
echo "CURRENT_FIRMWARE_EVIDENCE=PASS_SEALED_V010014"

echo
echo "===== CONTROL PLAN ====="
plan="$EVIDENCE_DIR/n1b-v010014-control-plan.env"
cat > "$plan" <<EOF_PLAN
N1B_V010014_CONTROL_PLAN=PREPARED_NO_WRITE
N1B_SOURCE_COMMIT=$EXPECTED_N1B_SOURCE
N1B_SYSTEM_IMG=$SYSTEM_IMG
N1B_SYSTEM_SHA256=$EXPECTED_N1B_SHA256
N1B_SYSTEM_LOGICAL_BYTES=$EXPECTED_N1B_BYTES
N1B_FIRST_BOOT_LEDGER=$LEDGER
N1B_FIRST_BOOT_LEDGER_SHA256=$ledger_sha
E5A_JSON=$E5A_JSON
E5A_JSON_SHA256=$E5A_JSON_SHA256
E5B_JSON=$E5B_JSON
E5B_JSON_SHA256=$e5b_sha
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
LIVE_REQUIRE_PRODUCT=Titan_2
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
FASTBOOT_IMPLICIT_RESIZE_TARGET_BYTES=$EXPECTED_N1B_BYTES
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
FACTORY_RESET_EXPECTED_FROM_HISTORICAL_N1B_PATH=YES
TELEMETRY_AFTER_RESET_REQUIRED=YES
N1E_BUILD_AUTHORIZED=NO_PENDING_N1B_V010014_CONTROL_RESULT
FLASH_AUTHORIZED=NO
FACTORY_RESET_AUTHORIZED=NO
WRITE_CAPABLE_SCRIPT_CREATED=NO
EOF_PLAN

(
  cd "$EVIDENCE_DIR"
  find . -type f ! -name SHA256SUMS.txt -print0 |
    LC_ALL=C sort -z |
    xargs -0 sha256sum > SHA256SUMS.txt
  sha256sum -c SHA256SUMS.txt >/dev/null
)

echo "CONTROL_PLAN=$plan"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "EVIDENCE_SEAL_SHA256=$(sha256sum "$EVIDENCE_DIR/SHA256SUMS.txt" | awk '{print $1}')"
echo "N1B_V010014_CONTROL_ARTIFACT=PASS_EXACT_HISTORICAL_N1B"
echo "N1B_V010014_CONTROL_CURRENT_FIRMWARE_EVIDENCE=PASS_SEALED_V010014"
echo "N1B_V010014_CONTROL_PLAN=PASS_PREPARED_NO_WRITE"
echo "N1B_V010014_CONTROL_FLASH_AUTHORIZED=NO"
echo "N1B_V010014_CONTROL_FACTORY_RESET_AUTHORIZED=NO"
echo "N1B_V010014_CONTROL_PREP=PASS"
