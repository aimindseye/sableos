#!/usr/bin/env bash
set -euo pipefail
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"

OFFLINE_EVIDENCE_DIR="/srv/sable-build/evidence/titan2/c3a-v010014-control/20261003T192925Z_offline-plan"
EXPECTED_OFFLINE_SEAL="e6ad9a20192ef7c1fcb8bf0bfc1f393afd8b9cdd7239cb19b0497512f4f8fd57"
EVIDENCE_DIR="${SABLE_C3A_LIVE_EVIDENCE_DIR:-/srv/sable-build/evidence/titan2/c3a-v010014-live-preflight/$STAMP}"

AUTHORIZE_READONLY=NO
AUTHORIZE_REBOOT=NO
ADB_SERIAL=""
FASTBOOT_SERIAL=""
WAIT_SECONDS=90
COMMAND_TIMEOUT_SECONDS=30

usage() {
  cat >&2 <<'USAGE'
usage:
  bash build/titan2/collect-c3a-v010014-live-preflight.sh \
    --authorize-readonly-device-contact \
    --authorize-reboot-to-fastbootd \
    [--adb-serial SERIAL] \
    [--fastboot-serial SERIAL] \
    [--offline-evidence-dir DIR] \
    [--evidence-dir DIR]

Start with Titan 2 in recovered stock V01.00.14 with USB debugging authorized.
This leaves the device in userspace fastbootd.

Authorized: read-only ADB/fastboot inspection and the two mode transitions.
Not authorized: flash, erase, format, factory reset, logical-partition mutation,
COW cleanup, AVB/vbmeta mutation, slot mutation, unlock/lock, custom boot, or
reboot back to Android.
USAGE
}

while (($#)); do
  case "$1" in
    --authorize-readonly-device-contact) AUTHORIZE_READONLY=YES; shift ;;
    --authorize-reboot-to-fastbootd) AUTHORIZE_REBOOT=YES; shift ;;
    --adb-serial) ADB_SERIAL="$2"; shift 2 ;;
    --fastboot-serial) FASTBOOT_SERIAL="$2"; shift 2 ;;
    --offline-evidence-dir) OFFLINE_EVIDENCE_DIR="$2"; shift 2 ;;
    --evidence-dir) EVIDENCE_DIR="$2"; shift 2 ;;
    --wait-seconds) WAIT_SECONDS="$2"; shift 2 ;;
    --command-timeout-seconds) COMMAND_TIMEOUT_SECONDS="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "C3A_V010014_LIVE_PREFLIGHT=FAIL_UNKNOWN_ARG" >&2; usage; exit 64 ;;
  esac
done

[[ "$AUTHORIZE_READONLY" == YES ]] || { echo "C3A_V010014_LIVE_PREFLIGHT=FAIL_READONLY_AUTHORIZATION_REQUIRED" >&2; exit 64; }
[[ "$AUTHORIZE_REBOOT" == YES ]] || { echo "C3A_V010014_LIVE_PREFLIGHT=FAIL_REBOOT_AUTHORIZATION_REQUIRED" >&2; exit 64; }
[[ "$OFFLINE_EVIDENCE_DIR" = /* ]] || { echo "C3A_V010014_LIVE_PREFLIGHT=FAIL_OFFLINE_EVIDENCE_PATH" >&2; exit 64; }
[[ "$EVIDENCE_DIR" = /* ]] || { echo "C3A_V010014_LIVE_PREFLIGHT=FAIL_EVIDENCE_PATH" >&2; exit 64; }
[[ ! -e "$EVIDENCE_DIR" ]] || { echo "C3A_V010014_LIVE_PREFLIGHT=FAIL_EVIDENCE_EXISTS path=$EVIDENCE_DIR" >&2; exit 64; }

fail() {
  echo "C3A_V010014_LIVE_PREFLIGHT=FAIL reason=$1" >&2
  exit 1
}

bash "$ROOT/build/gates/c3a-v010014-control-contract.sh" >/dev/null
bash "$ROOT/build/gates/n1d-c3b-e5a-readonly-device-state-contract.sh" >/dev/null
bash "$ROOT/build/gates/n1d-c3b-e5b-authorization-package-contract.sh" >/dev/null

[[ -d "$OFFLINE_EVIDENCE_DIR" ]] || fail offline_evidence_missing
[[ -f "$OFFLINE_EVIDENCE_DIR/SHA256SUMS.txt" ]] || fail offline_evidence_seal_missing
(
  cd "$OFFLINE_EVIDENCE_DIR"
  sha256sum -c SHA256SUMS.txt >/dev/null
) || fail offline_evidence_seal_invalid
offline_seal="$(sha256sum "$OFFLINE_EVIDENCE_DIR/SHA256SUMS.txt" | awk '{print $1}')"
[[ "$offline_seal" == "$EXPECTED_OFFLINE_SEAL" ]] ||
  fail "offline_evidence_seal_mismatch expected=$EXPECTED_OFFLINE_SEAL actual=$offline_seal"

OFFLINE_PLAN="$OFFLINE_EVIDENCE_DIR/c3a-v010014-control-plan.env"
[[ -f "$OFFLINE_PLAN" ]] || fail offline_plan_missing
# shellcheck source=/dev/null
source "$OFFLINE_PLAN"

[[ "${C3A_V010014_CONTROL_PLAN:-}" == "PREPARED_NO_WRITE" ]] || fail offline_plan_state
[[ "${C3A_SYSTEM_SHA256:-}" == "4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16" ]] || fail c3a_sha_plan
[[ "${C3A_SYSTEM_LOGICAL_BYTES:-}" == "3146977280" ]] || fail c3a_bytes_plan
[[ "${CURRENT_STOCK_INCREMENTAL:-}" == "V01.00.14" ]] || fail stock_incremental_plan
[[ "${FLASH_AUTHORIZED:-}" == "NO" ]] || fail flash_boundary_plan
[[ "${FACTORY_RESET_AUTHORIZED:-}" == "NO" ]] || fail reset_boundary_plan
[[ -f "${C3A_SYSTEM_IMG:-}" ]] || fail c3a_system_missing
[[ "$(sha256sum "$C3A_SYSTEM_IMG" | awk '{print $1}')" == "$C3A_SYSTEM_SHA256" ]] || fail c3a_system_sha_changed
[[ "$(stat -c '%s' "$C3A_SYSTEM_IMG")" == "$C3A_SYSTEM_LOGICAL_BYTES" ]] || fail c3a_system_bytes_changed

mkdir -p "$EVIDENCE_DIR"
LOG="$EVIDENCE_DIR/c3a-v010014-live-preflight.log"
exec > >(tee "$LOG") 2>&1

echo "===== TITAN 2 C3A V01.00.14 FRESH LIVE PREFLIGHT ====="
echo "OFFLINE_EVIDENCE_DIR=$OFFLINE_EVIDENCE_DIR"
echo "OFFLINE_EVIDENCE_SEAL_SHA256=$offline_seal"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY_C3A_CONTROL"
echo "ADB_READONLY_AUTHORIZED=YES"
echo "FASTBOOT_READONLY_AUTHORIZED=YES"
echo "REBOOT_BOOTLOADER_AUTHORIZED=YES"
echo "REBOOT_FASTBOOTD_AUTHORIZED=YES"
echo "FLASH_AUTHORIZED=NO"
echo "ERASE_AUTHORIZED=NO"
echo "FORMAT_AUTHORIZED=NO"
echo "FACTORY_RESET_AUTHORIZED=NO"
echo "LP_MUTATION_AUTHORIZED=NO"
echo "COW_CLEANUP_AUTHORIZED=NO"
echo "AVB_MUTATION_AUTHORIZED=NO"
echo "SLOT_MUTATION_AUTHORIZED=NO"
echo "UNLOCK_LOCK_AUTHORIZED=NO"
echo "CUSTOM_BOOT_AUTHORIZED=NO"
echo "REBOOT_BACK_TO_ANDROID_AUTHORIZED=NO"

E5A_DIR="$EVIDENCE_DIR/e5a"
mkdir -p "$E5A_DIR"

e5a_args=(
  --authorize-e5a-readonly
  --authorize-reboot-to-fastbootd
  --wait-seconds "$WAIT_SECONDS"
  --command-timeout-seconds "$COMMAND_TIMEOUT_SECONDS"
)
[[ -z "$ADB_SERIAL" ]] || e5a_args+=(--adb-serial "$ADB_SERIAL")
[[ -z "$FASTBOOT_SERIAL" ]] || e5a_args+=(--fastboot-serial "$FASTBOOT_SERIAL")

SABLE_E5A_EVIDENCE_DIR="$E5A_DIR" \
SABLE_E5A_SYSTEM_IMG="$C3A_SYSTEM_IMG" \
SABLE_E5A_EXPECTED_SYSTEM_SHA256="$C3A_SYSTEM_SHA256" \
SABLE_E5A_EXPECTED_SYSTEM_BYTES="$C3A_SYSTEM_LOGICAL_BYTES" \
SABLE_E5A_PLANNED_SYSTEM_TARGET_BYTES="$C3A_SYSTEM_LOGICAL_BYTES" \
bash "$ROOT/build/titan2/collect-n1d-c3b-e5a-readonly-device-state.sh" "${e5a_args[@]}"

E5A_JSON="$E5A_DIR/e5a-readonly-device-state.json"
[[ -f "$E5A_JSON" ]] || fail e5a_json_missing

CAPACITY_JSON="$EVIDENCE_DIR/c3a-capacity-package.json"
bash "$ROOT/build/titan2/prepare-n1d-c3b-e5b-authorization-package.sh" \
  --e5a-evidence-dir "$E5A_DIR" \
  --e5a-json "$E5A_JSON" \
  --output-json "$CAPACITY_JSON"

FINAL_JSON="$EVIDENCE_DIR/c3a-v010014-live-preflight.json"
bash "$ROOT/build/titan2/qualify-c3a-v010014-live-preflight.sh" \
  --e5a-json "$E5A_JSON" \
  --capacity-json "$CAPACITY_JSON" \
  --offline-plan "$OFFLINE_PLAN" \
  --output-json "$FINAL_JSON"

cp "$E5A_JSON" "$EVIDENCE_DIR/e5a-readonly-device-state.json"
cp "$OFFLINE_PLAN" "$EVIDENCE_DIR/offline-control-plan.env"
printf '%s\n' "$offline_seal" > "$EVIDENCE_DIR/offline-evidence-seal-sha256.txt"

(
  cd "$EVIDENCE_DIR"
  find . -maxdepth 1 -type f \
    ! -name SHA256SUMS.txt \
    ! -name c3a-v010014-live-preflight.log \
    -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > SHA256SUMS.txt
  sha256sum -c SHA256SUMS.txt >/dev/null
)

echo "C3A_V010014_LIVE_PREFLIGHT_EVIDENCE_DIR=$EVIDENCE_DIR"
echo "C3A_V010014_LIVE_PREFLIGHT_EVIDENCE_SEAL_SHA256=$(sha256sum "$EVIDENCE_DIR/SHA256SUMS.txt" | awk '{print $1}')"
echo "C3A_V010014_LIVE_PREFLIGHT_FLASH_AUTHORIZED=NO"
echo "C3A_V010014_LIVE_PREFLIGHT_FACTORY_RESET_AUTHORIZED=NO"
echo "C3A_V010014_LIVE_PREFLIGHT_FINAL_DEVICE_MODE=FASTBOOTD"
