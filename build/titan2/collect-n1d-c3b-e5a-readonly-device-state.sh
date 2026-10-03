#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="${SABLE_E5A_EVIDENCE_DIR:-/srv/sable-build/evidence/titan2/n1d-c3b-e5a-readonly-device-state/$STAMP}"
SYSTEM_IMG="/srv/sable-build/workspaces/titan2-n1d-c3b/out-c3b-engineering/e3-systemimage/20261003T014638Z/target/product/tdgsi_arm64_ab/system.img"
EXPECTED_SYSTEM_SHA256="998a8b99cd4d1a631006291a96c6f0160c5a4400c4bf6bba62c319c4ed3c82a5"
EXPECTED_SYSTEM_BYTES="2994405376"
E4_EVIDENCE_DIR="/srv/sable-build/evidence/titan2/n1d-c3b-e4-deployment-readiness/20261003T044503Z"

AUTHORIZE_READONLY=NO
AUTHORIZE_REBOOT_TO_FASTBOOTD=NO
ADB_SERIAL=""
FASTBOOT_SERIAL=""
WAIT_SECONDS=90
COMMAND_TIMEOUT_SECONDS=30

usage() {
  cat >&2 <<'USAGE'
usage:
  bash build/titan2/collect-n1d-c3b-e5a-readonly-device-state.sh \
    --authorize-e5a-readonly \
    --authorize-reboot-to-fastbootd \
    [--adb-serial SERIAL] \
    [--fastboot-serial SERIAL] \
    [--wait-seconds N] \
    [--command-timeout-seconds N] \
    [--evidence-dir DIR]

Start with Titan 2 booted into recovered stock V01.00.14 and USB debugging authorized.
The script leaves the device in userspace fastbootd.

Authorized: read-only ADB/fastboot inspection, adb reboot bootloader, and
fastboot reboot fastboot to enter userspace fastbootd.

Not authorized: flash/update/custom boot, erase/format/factory reset,
logical-partition mutation, AVB/vbmeta mutation, slot mutation, unlock/lock,
or reboot back to Android.
USAGE
}

while (($#)); do
  case "$1" in
    --authorize-e5a-readonly) AUTHORIZE_READONLY=YES; shift ;;
    --authorize-reboot-to-fastbootd) AUTHORIZE_REBOOT_TO_FASTBOOTD=YES; shift ;;
    --adb-serial) ADB_SERIAL="$2"; shift 2 ;;
    --fastboot-serial) FASTBOOT_SERIAL="$2"; shift 2 ;;
    --wait-seconds) WAIT_SECONDS="$2"; shift 2 ;;
    --command-timeout-seconds) COMMAND_TIMEOUT_SECONDS="$2"; shift 2 ;;
    --evidence-dir) EVIDENCE_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "N1D_C3B_E5A_READONLY_DEVICE_STATE=FAIL_UNKNOWN_ARG" >&2; usage; exit 64 ;;
  esac
done

[[ "$AUTHORIZE_READONLY" == YES ]] || {
  echo "N1D_C3B_E5A_READONLY_DEVICE_STATE=FAIL_READONLY_AUTHORIZATION_REQUIRED" >&2
  exit 64
}
[[ "$AUTHORIZE_REBOOT_TO_FASTBOOTD" == YES ]] || {
  echo "N1D_C3B_E5A_READONLY_DEVICE_STATE=FAIL_REBOOT_AUTHORIZATION_REQUIRED" >&2
  exit 64
}
[[ "$WAIT_SECONDS" =~ ^[1-9][0-9]*$ ]] || { echo "N1D_C3B_E5A=FAIL_WAIT_SECONDS"; exit 64; }
[[ "$COMMAND_TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]] || { echo "N1D_C3B_E5A=FAIL_COMMAND_TIMEOUT_SECONDS"; exit 64; }

fail() {
  echo "N1D_C3B_E5A_READONLY_DEVICE_STATE=FAIL reason=$1" >&2
  exit 1
}

mkdir -p "$EVIDENCE_DIR/private" "$EVIDENCE_DIR/adb-extra"
LOG="$EVIDENCE_DIR/e5a-readonly-device-state.log"
exec > >(tee "$LOG") 2>&1

printf '%s\n' \
  '===== TITAN 2 N1D C3B E5A READ-ONLY DEVICE-STATE REVALIDATION =====' \
  "EVIDENCE_DIR=$EVIDENCE_DIR" \
  'DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY_E5A' \
  'ADB_READONLY_AUTHORIZED=YES' \
  'FASTBOOT_READONLY_AUTHORIZED=YES' \
  'REBOOT_BOOTLOADER_AUTHORIZED=YES' \
  'REBOOT_FASTBOOTD_AUTHORIZED=YES' \
  'FLASH_AUTHORIZED=NO' \
  'ERASE_AUTHORIZED=NO' \
  'FORMAT_AUTHORIZED=NO' \
  'LP_MUTATION_AUTHORIZED=NO' \
  'AVB_MUTATION_AUTHORIZED=NO' \
  'SLOT_MUTATION_AUTHORIZED=NO' \
  'UNLOCK_LOCK_AUTHORIZED=NO' \
  'FACTORY_RESET_AUTHORIZED=NO' \
  'CUSTOM_BOOT_AUTHORIZED=NO' \
  'REBOOT_BACK_TO_ANDROID=NO_NOT_AUTHORIZED' \
  'FINAL_DEVICE_MODE=FASTBOOTD_EXPECTED' \
  'E5B_FLASH_AUTHORIZED=NO'

bash "$ROOT/build/gates/n1d-c3b-e4-evidence-contract.sh"
bash "$ROOT/build/gates/n1b-phase-10-readonly-preflight-contract.sh" >/dev/null
bash "$ROOT/build/gates/n1b-phase-11-lp-super-sizing-contract.sh" >/dev/null

[[ -f "$SYSTEM_IMG" ]] || fail sealed_system_image_missing
actual_sha="$(sha256sum "$SYSTEM_IMG" | awk '{print $1}')"
actual_bytes="$(stat -c '%s' "$SYSTEM_IMG")"
[[ "$actual_sha" == "$EXPECTED_SYSTEM_SHA256" ]] || fail sealed_system_sha_mismatch
[[ "$actual_bytes" == "$EXPECTED_SYSTEM_BYTES" ]] || fail sealed_system_size_mismatch

[[ -f "$E4_EVIDENCE_DIR/stock-super.sha256" ]] || fail e4_stock_super_hash_list_missing
[[ -f "$E4_EVIDENCE_DIR/stock-boot-avb.sha256" ]] || fail e4_boot_avb_hash_list_missing
sha256sum -c "$E4_EVIDENCE_DIR/stock-super.sha256" > "$EVIDENCE_DIR/private/restore-super-check.txt" 2>&1 || fail stock_super_restore_artifact_changed
sha256sum -c "$E4_EVIDENCE_DIR/stock-boot-avb.sha256" > "$EVIDENCE_DIR/private/restore-boot-avb-check.txt" 2>&1 || fail stock_boot_avb_restore_artifact_changed
echo "N1D_C3B_E5A_OFFLINE_RESTORE_ARTIFACTS=PASS"

command -v adb >/dev/null 2>&1 || fail adb_not_found
command -v fastboot >/dev/null 2>&1 || fail fastboot_not_found

PHASE10_ROOT="$EVIDENCE_DIR/phase10"
PHASE11_ROOT="$EVIDENCE_DIR/phase11"
mkdir -p "$PHASE10_ROOT" "$PHASE11_ROOT"

if ! SABLE_N1B_PHASE_10_EVIDENCE_ROOT="$PHASE10_ROOT" \
     TITAN_SERIAL="$ADB_SERIAL" \
     bash "$ROOT/build/titan2/collect-n1b-phase-10a-adb-readonly-preflight.sh" \
       > "$EVIDENCE_DIR/private/phase10a-console.log" 2>&1; then
  fail phase10a_readonly_collection_failed
fi

mapfile -t phase10a_jsons < <(find "$PHASE10_ROOT" -type f -path '*/10a-adb/phase10a-adb-readonly-preflight.json' -print | sort)
[[ "${#phase10a_jsons[@]}" -eq 1 ]] || fail phase10a_json_count
PHASE10A_JSON="${phase10a_jsons[0]}"

DEVICE_SERIAL="$(python3 - "$PHASE10A_JSON" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1])
data = json.loads(p.read_text())
serial = str(data.get('metadata', {}).get('explicit_titan_serial', '')).strip()
if not serial:
    raise SystemExit(2)
print(serial)
PY
)" || fail phase10a_serial_missing
DEVICE_BINDING_SHA256="$(printf '%s' "$DEVICE_SERIAL" | sha256sum | awk '{print $1}')"
echo "N1D_C3B_E5A_DEVICE_BINDING_SHA256=$DEVICE_BINDING_SHA256"
echo "N1D_C3B_E5A_PHASE10A=PASS_READ_ONLY"

adb -s "$DEVICE_SERIAL" shell dumpsys battery > "$EVIDENCE_DIR/adb-extra/battery.txt" 2>&1 || true
adb -s "$DEVICE_SERIAL" shell 'lpdump 2>/dev/null || true' > "$EVIDENCE_DIR/adb-extra/lpdump.txt" 2>&1 || true

if ! SABLE_N1B_PHASE_10_EVIDENCE_ROOT="$PHASE10_ROOT" \
     TITAN_ADB_SERIAL="$DEVICE_SERIAL" \
     TITAN_FASTBOOT_SERIAL="${FASTBOOT_SERIAL:-$DEVICE_SERIAL}" \
     TITAN_FASTBOOT_WAIT_SECONDS="$WAIT_SECONDS" \
     TITAN_FASTBOOT_COMMAND_TIMEOUT_SECONDS="$COMMAND_TIMEOUT_SECONDS" \
     bash "$ROOT/build/titan2/collect-n1b-phase-10b-fastboot-readonly-preflight.sh" \
       --adb-reboot-bootloader-if-android \
       --fastboot-reboot-fastbootd-if-bootloader \
       --require-fastbootd \
       > "$EVIDENCE_DIR/private/phase10b-console.log" 2>&1; then
  fail phase10b_readonly_collection_failed
fi

mapfile -t phase10b_jsons < <(find "$PHASE10_ROOT" -type f -path '*/10b-fastboot/phase10b-fastboot-readonly-preflight.json' -print | sort)
[[ "${#phase10b_jsons[@]}" -eq 1 ]] || fail phase10b_json_count
PHASE10B_JSON="${phase10b_jsons[0]}"
echo "N1D_C3B_E5A_PHASE10B=PASS_READ_ONLY_FASTBOOTD"

if ! SABLE_N1B_PHASE_11_EVIDENCE_ROOT="$PHASE11_ROOT" \
     TITAN_FASTBOOT_SERIAL="${FASTBOOT_SERIAL:-$DEVICE_SERIAL}" \
     COMMAND_TIMEOUT_SECONDS="$COMMAND_TIMEOUT_SECONDS" \
     bash "$ROOT/build/titan2/collect-n1b-phase-11-fastbootd-lp-sizing.sh" \
       --require-fastbootd \
       > "$EVIDENCE_DIR/private/phase11-console.log" 2>&1; then
  fail phase11_readonly_collection_failed
fi

mapfile -t phase11_jsons < <(find "$PHASE11_ROOT" -type f -path '*/fastbootd-lp-sizing/phase11-fastbootd-lp-sizing.json' -print | sort)
[[ "${#phase11_jsons[@]}" -eq 1 ]] || fail phase11_json_count
PHASE11_JSON="${phase11_jsons[0]}"
echo "N1D_C3B_E5A_PHASE11=PASS_READ_ONLY_FASTBOOTD"

bash "$ROOT/build/titan2/qualify-n1d-c3b-e5a-readonly-device-state.sh" \
  --phase10a-json "$PHASE10A_JSON" \
  --phase10b-json "$PHASE10B_JSON" \
  --phase11-json "$PHASE11_JSON" \
  --adb-extra-dir "$EVIDENCE_DIR/adb-extra" \
  --device-binding-sha256 "$DEVICE_BINDING_SHA256" \
  --system-image "$SYSTEM_IMG" \
  --output-json "$EVIDENCE_DIR/e5a-readonly-device-state.json"

printf '%s\n' \
  'N1D_C3B_E5A_FLASH_AUTHORIZED=NO' \
  'N1D_C3B_E5A_ERASE_AUTHORIZED=NO' \
  'N1D_C3B_E5A_LP_MUTATION_AUTHORIZED=NO' \
  'N1D_C3B_E5A_AVB_MUTATION_AUTHORIZED=NO' \
  'N1D_C3B_E5A_SLOT_MUTATION_AUTHORIZED=NO' \
  'N1D_C3B_E5A_UNLOCK_LOCK_AUTHORIZED=NO' \
  'N1D_C3B_E5A_FACTORY_RESET_AUTHORIZED=NO' \
  'N1D_C3B_E5A_CUSTOM_BOOT_AUTHORIZED=NO' \
  'N1D_C3B_E5A_FINAL_DEVICE_MODE=FASTBOOTD' \
  'N1D_C3B_E5A_REBOOT_BACK_TO_ANDROID=NO_NOT_AUTHORIZED' \
  "N1D_C3B_E5A_EVIDENCE_DIR=$EVIDENCE_DIR"
