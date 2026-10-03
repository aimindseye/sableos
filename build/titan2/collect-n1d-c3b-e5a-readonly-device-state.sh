#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="/srv/sable-build/evidence/titan2/n1d-c3b-e5a-readonly-device-state/$STAMP"

SYSTEM_IMG="/srv/sable-build/workspaces/titan2-n1d-c3b/out-c3b-engineering/e3-systemimage/20261003T014638Z/target/product/tdgsi_arm64_ab/system.img"
EXPECTED_SYSTEM_SHA256="998a8b99cd4d1a631006291a96c6f0160c5a4400c4bf6bba62c319c4ed3c82a5"
EXPECTED_SYSTEM_BYTES="2994405376"
EXPECTED_STOCK_FINGERPRINT="Unihertz/Titan_2/Titan_2:16/BP2A.250605.031.A3/V01.00.14:user/release-keys"
EXPECTED_STOCK_INCREMENTAL="V01.00.14"
PLANNED_SYSTEM_TARGET_BYTES="3263168512"
MIN_REMAINING_HEADROOM_BYTES="536870912"
MIN_FUTURE_MUTATION_BATTERY_PERCENT="50"

ADB_SERIAL=""
FASTBOOT_SERIAL=""
AUTHORIZE_READONLY=NO
AUTHORIZE_REBOOT_TO_FASTBOOTD=NO
WAIT_SECONDS=90
COMMAND_TIMEOUT_SECONDS=30

usage() {
  cat >&2 <<'EOF'
usage:
  bash build/titan2/collect-n1d-c3b-e5a-readonly-device-state.sh \
    --authorize-e5a-readonly \
    --authorize-reboot-to-fastbootd \
    [--adb-serial SERIAL] \
    [--fastboot-serial SERIAL] \
    [--wait-seconds N] \
    [--command-timeout-seconds N] \
    [--evidence-dir DIR]

Required starting state:
  Titan 2 booted into stock Android V01.00.14 with USB debugging authorized.

Authorized:
  read-only ADB inspection
  adb reboot bootloader
  read-only fastboot/fastbootd getvar inspection
  fastboot reboot fastboot (bootloader -> userspace fastbootd)

Not authorized:
  flash / update / custom boot
  erase / format / factory reset
  logical-partition resize/delete/create
  AVB/vbmeta mutation
  slot mutation
  bootloader unlock/lock
  reboot back to Android

The device is intentionally left in userspace fastbootd after evidence capture.
EOF
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
    *) echo "N1D_C3B_E5A_READONLY_DEVICE_STATE=FAIL_UNKNOWN_ARG arg=$1" >&2; usage; exit 64 ;;
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

mkdir -p "$EVIDENCE_DIR"
LOG="$EVIDENCE_DIR/e5a-readonly-device-state.log"
JSON_OUT="$EVIDENCE_DIR/e5a-readonly-device-state.json"
exec > >(tee "$LOG") 2>&1

echo "===== TITAN 2 N1D C3B E5A READ-ONLY DEVICE-STATE REVALIDATION ====="
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY_E5A"
echo "ADB_READONLY_AUTHORIZED=YES"
echo "FASTBOOT_READONLY_AUTHORIZED=YES"
echo "REBOOT_BOOTLOADER_AUTHORIZED=YES"
echo "REBOOT_FASTBOOTD_AUTHORIZED=YES"
echo "FLASH_AUTHORIZED=NO"
echo "FLASH_COMMANDS_RUN=NO"
echo "ERASE_AUTHORIZED=NO"
echo "ERASE_COMMANDS_RUN=NO"
echo "FORMAT_AUTHORIZED=NO"
echo "LP_MUTATION_AUTHORIZED=NO"
echo "AVB_MUTATION_AUTHORIZED=NO"
echo "SLOT_MUTATION_AUTHORIZED=NO"
echo "UNLOCK_LOCK_AUTHORIZED=NO"
echo "FACTORY_RESET_AUTHORIZED=NO"
echo "CUSTOM_BOOT_AUTHORIZED=NO"
echo "PRODUCTION_SIGNING_AUTHORIZED=NO"
echo "RELEASE_ELIGIBLE=NO"
echo "FINAL_DEVICE_MODE=FASTBOOTD_EXPECTED"
echo "REBOOT_BACK_TO_ANDROID=NO_NOT_AUTHORIZED"

bash "$ROOT/build/gates/n1d-c3b-e4-evidence-contract.sh"

[[ -f "$SYSTEM_IMG" ]] || fail "sealed_system_image_missing"
actual_system_sha="$(sha256sum "$SYSTEM_IMG" | awk '{print $1}')"
actual_system_bytes="$(stat -c '%s' "$SYSTEM_IMG")"
[[ "$actual_system_sha" == "$EXPECTED_SYSTEM_SHA256" ]] || fail "sealed_system_sha_mismatch"
[[ "$actual_system_bytes" == "$EXPECTED_SYSTEM_BYTES" ]] || fail "sealed_system_size_mismatch"
echo "N1D_C3B_E5A_E4_SEAL=PASS"

command -v adb >/dev/null 2>&1 || fail "adb_not_found"
command -v fastboot >/dev/null 2>&1 || fail "fastboot_not_