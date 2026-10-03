#!/usr/bin/env bash
set -euo pipefail
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"

OFFLINE_EVIDENCE_DIR="/srv/sable-build/evidence/titan2/c3a-v010014-control/20261003T192925Z_offline-plan"
EXPECTED_OFFLINE_SEAL="e6ad9a20192ef7c1fcb8bf0bfc1f393afd8b9cdd7239cb19b0497512f4f8fd57"
BASELINE_E5A_DIR="/srv/sable-build/evidence/titan2/n1d-c3b-e5a-readonly-device-state/20261003T053441Z"
EXPECTED_BASELINE_E5B_SHA256="74531923a9ea6c755a9f8ea52db511c4a4a19a5d9dba3cb51da342c04b768926"
EVIDENCE_DIR="${SABLE_C3A_FASTBOOT_ENTRY_EVIDENCE_DIR:-/srv/sable-build/evidence/titan2/c3a-v010014-fastboot-entry-preflight/$STAMP}"

AUTHORIZE_READONLY=NO
AUTHORIZE_FASTBOOTD_SWITCH=NO
FASTBOOT_SERIAL=""
WAIT_SECONDS=90
COMMAND_TIMEOUT_SECONDS=30

usage() {
  cat >&2 <<'USAGE'
usage:
  bash build/titan2/collect-c3a-v010014-fastboot-entry-preflight.sh \
    --authorize-readonly-fastboot-contact \
    --authorize-fastbootd-mode-switch \
    [--fastboot-serial SERIAL] \
    [--offline-evidence-dir DIR] \
    [--baseline-e5a-dir DIR] \
    [--evidence-dir DIR]

Use when Titan 2 is already in bootloader fastboot or userspace fastbootd after
the N1D bootloop.

Authorized:
  - read-only fastboot getvar inspection
  - bootloader-fastboot -> userspace-fastbootd mode switch if required

Not authorized:
  adb, Android boot, flash, erase, format, factory reset, COW cleanup,
  logical-partition mutation, AVB/vbmeta mutation, slot change, unlock/lock,
  custom boot, or reboot back to Android.

The script leaves the device in userspace fastbootd.
USAGE
}

while (($#)); do
  case "$1" in
    --authorize-readonly-fastboot-contact) AUTHORIZE_READONLY=YES; shift ;;
    --authorize-fastbootd-mode-switch) AUTHORIZE_FASTBOOTD_SWITCH=YES; shift ;;
    --fastboot-serial) FASTBOOT_SERIAL="$2"; shift 2 ;;
    --offline-evidence-dir) OFFLINE_EVIDENCE_DIR="$2"; shift 2 ;;
    --baseline-e5a-dir) BASELINE_E5A_DIR="$2"; shift 2 ;;
    --evidence-dir) EVIDENCE_DIR="$2"; shift 2 ;;
    --wait-seconds) WAIT_SECONDS="$2"; shift 2 ;;
    --command-timeout-seconds) COMMAND_TIMEOUT_SECONDS="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "C3A_FASTBOOT_ENTRY_PREFLIGHT=FAIL_UNKNOWN_ARG arg=$1" >&2; usage; exit 64 ;;
  esac
done

[[ "$AUTHORIZE_READONLY" == YES ]] || {
  echo "C3A_FASTBOOT_ENTRY_PREFLIGHT=FAIL_READONLY_FASTBOOT_AUTHORIZATION_REQUIRED" >&2
  exit 64
}
[[ "$AUTHORIZE_FASTBOOTD_SWITCH" == YES ]] || {
  echo "C3A_FASTBOOT_ENTRY_PREFLIGHT=FAIL_FASTBOOTD_SWITCH_AUTHORIZATION_REQUIRED" >&2
  exit 64
}
[[ "$OFFLINE_EVIDENCE_DIR" = /* && -d "$OFFLINE_EVIDENCE_DIR" ]] || {
  echo "C3A_FASTBOOT_ENTRY_PREFLIGHT=FAIL_OFFLINE_EVIDENCE_DIR" >&2
  exit 64
}
[[ "$BASELINE_E5A_DIR" = /* && -d "$BASELINE_E5A_DIR" ]] || {
  echo "C3A_FASTBOOT_ENTRY_PREFLIGHT=FAIL_BASELINE_E5A_DIR" >&2
  exit 64
}
[[ "$EVIDENCE_DIR" = /* && ! -e "$EVIDENCE_DIR" ]] || {
  echo "C3A_FASTBOOT_ENTRY_PREFLIGHT=FAIL_EVIDENCE_DIR path=$EVIDENCE_DIR" >&2
  exit 64
}

fail() {
  echo "C3A_FASTBOOT_ENTRY_PREFLIGHT=FAIL reason=$1" >&2
  exit 1
}

bash "$ROOT/build/gates/c3a-v010014-control-contract.sh" >/dev/null
bash "$ROOT/build/gates/n1b-phase-10-readonly-preflight-contract.sh" >/dev/null
bash "$ROOT/build/gates/n1b-phase-11-lp-super-sizing-contract.sh" >/dev/null

[[ -f "$OFFLINE_EVIDENCE_DIR/SHA256SUMS.txt" ]] || fail offline_seal_missing
(
  cd "$OFFLINE_EVIDENCE_DIR"
  sha256sum -c SHA256SUMS.txt >/dev/null
) || fail offline_seal_invalid
offline_seal="$(sha256sum "$OFFLINE_EVIDENCE_DIR/SHA256SUMS.txt" | awk '{print $1}')"
[[ "$offline_seal" == "$EXPECTED_OFFLINE_SEAL" ]] ||
  fail "offline_seal_mismatch expected=$EXPECTED_OFFLINE_SEAL actual=$offline_seal"

OFFLINE_PLAN="$OFFLINE_EVIDENCE_DIR/c3a-v010014-control-plan.env"
OFFLINE_BINDING="$OFFLINE_EVIDENCE_DIR/e5a-binding.env"
[[ -f "$OFFLINE_PLAN" && -f "$OFFLINE_BINDING" ]] || fail offline_plan_or_binding_missing

# shellcheck source=/dev/null
source "$OFFLINE_PLAN"
# shellcheck source=/dev/null
source "$OFFLINE_BINDING"

[[ "${C3A_V010014_CONTROL_PLAN:-}" == "PREPARED_NO_WRITE" ]] || fail offline_plan_state
[[ "${C3A_SYSTEM_SHA256:-}" == "4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16" ]] || fail offline_c3a_sha
[[ "${C3A_SYSTEM_LOGICAL_BYTES:-}" == "3146977280" ]] || fail offline_c3a_bytes
[[ "${CURRENT_STOCK_INCREMENTAL:-}" == "V01.00.14" ]] || fail offline_incremental
[[ "${EXPECTED_ACTIVE_SLOT:-}" == "a" ]] || fail offline_slot
[[ "${EXPECTED_FASTBOOT_PRODUCT:-}" == "Titan_2" ]] || fail offline_product
[[ "${EXPECTED_SUPER_BYTES:-}" == "9663676416" ]] || fail offline_super
[[ "${FLASH_AUTHORIZED:-}" == "NO" ]] || fail offline_flash_boundary
[[ "${FACTORY_RESET_AUTHORIZED:-}" == "NO" ]] || fail offline_reset_boundary
[[ "${EXPECTED_FASTBOOT_BINDING_SHA256:-}" =~ ^[0-9a-f]{64}$ ]] || fail offline_fastboot_binding_invalid

[[ -f "${C3A_SYSTEM_IMG:-}" ]] || fail c3a_system_img_missing
[[ "$(sha256sum "$C3A_SYSTEM_IMG" | awk '{print $1}')" == "$C3A_SYSTEM_SHA256" ]] || fail c3a_system_img_sha_changed
[[ "$(stat -c '%s' "$C3A_SYSTEM_IMG")" == "$C3A_SYSTEM_LOGICAL_BYTES" ]] || fail c3a_system_img_size_changed

BASELINE_E5B_JSON="$BASELINE_E5A_DIR/e5b-authorization-package.json"
[[ -f "$BASELINE_E5B_JSON" ]] || fail baseline_e5b_missing
baseline_e5b_sha="$(sha256sum "$BASELINE_E5B_JSON" | awk '{print $1}')"
[[ "$baseline_e5b_sha" == "$EXPECTED_BASELINE_E5B_SHA256" ]] ||
  fail "baseline_e5b_sha_mismatch expected=$EXPECTED_BASELINE_E5B_SHA256 actual=$baseline_e5b_sha"

python3 - "$BASELINE_E5B_JSON" "${E5A_JSON_SHA256:-}" <<'PY'
import json
import pathlib
import sys
data=json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
expected=sys.argv[2]
actual=str(data.get("e5a_source_json_sha256",""))
if not expected or actual != expected:
    raise SystemExit(
        f"C3A_FASTBOOT_ENTRY_PREFLIGHT=FAIL_BASELINE_E5A_BINDING expected={expected!r} actual={actual!r}"
    )
PY

mkdir -p "$EVIDENCE_DIR/private/phase10" "$EVIDENCE_DIR/private/phase11"
LOG="$EVIDENCE_DIR/c3a-fastboot-entry-preflight.log"
exec > >(tee "$LOG") 2>&1

echo "===== TITAN 2 C3A V01.00.14 FASTBOOT-ENTRY PREFLIGHT ====="
echo "ENTRY_STATE=FASTBOOT_OR_FASTBOOTD_FROM_N1D_BOOTLOOP"
echo "OFFLINE_EVIDENCE_DIR=$OFFLINE_EVIDENCE_DIR"
echo "OFFLINE_EVIDENCE_SEAL_SHA256=$offline_seal"
echo "BASELINE_E5B_JSON=$BASELINE_E5B_JSON"
echo "BASELINE_E5B_SHA256=$baseline_e5b_sha"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY_FASTBOOT"
echo "ADB_AUTHORIZED=NO"
echo "FASTBOOT_READONLY_AUTHORIZED=YES"
echo "FASTBOOTD_MODE_SWITCH_AUTHORIZED=YES_IF_BOOTLOADER"
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
echo "REBOOT_ANDROID_AUTHORIZED=NO"

PHASE10_ROOT="$EVIDENCE_DIR/private/phase10"
phase10_args=(
  --fastboot-reboot-fastbootd-if-bootloader
  --require-fastbootd
  --wait-seconds "$WAIT_SECONDS"
  --command-timeout-seconds "$COMMAND_TIMEOUT_SECONDS"
)
[[ -z "$FASTBOOT_SERIAL" ]] || phase10_args+=(--serial "$FASTBOOT_SERIAL")

SABLE_N1B_PHASE_10_EVIDENCE_ROOT="$PHASE10_ROOT" \
bash "$ROOT/build/titan2/collect-n1b-phase-10b-fastboot-readonly-preflight.sh" \
  "${phase10_args[@]}" ||
  fail phase10b_collection_failed

mapfile -t p10b_jsons < <(
  find "$PHASE10_ROOT" -type f -path '*/10b-fastboot/phase10b-fastboot-readonly-preflight.json' -print |
    LC_ALL=C sort
)
[[ "${#p10b_jsons[@]}" -eq 1 ]] || fail "phase10b_json_count=${#p10b_jsons[@]}"
PHASE10B_JSON="${p10b_jsons[0]}"

LIVE_FASTBOOT_SERIAL="$(
  python3 - "$PHASE10B_JSON" <<'PY'
import json
import pathlib
import sys
data=json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
serial=str((data.get("metadata") or {}).get("explicit_titan_serial","")).strip()
if not serial:
    raise SystemExit(2)
print(serial)
PY
)" || fail phase10b_serial_missing

FASTBOOT_BINDING_SHA256="$(printf '%s' "$LIVE_FASTBOOT_SERIAL" | sha256sum | awk '{print $1}')"
echo "C3A_FASTBOOT_ENTRY_FASTBOOT_BINDING_SHA256=$FASTBOOT_BINDING_SHA256"
[[ "$FASTBOOT_BINDING_SHA256" == "$EXPECTED_FASTBOOT_BINDING_SHA256" ]] ||
  fail "fastboot_device_binding_changed expected=$EXPECTED_FASTBOOT_BINDING_SHA256 actual=$FASTBOOT_BINDING_SHA256"

PHASE11_ROOT="$EVIDENCE_DIR/private/phase11"
SABLE_N1B_PHASE_11_EVIDENCE_ROOT="$PHASE11_ROOT" \
TITAN_FASTBOOT_SERIAL="$LIVE_FASTBOOT_SERIAL" \
COMMAND_TIMEOUT_SECONDS="$COMMAND_TIMEOUT_SECONDS" \
bash "$ROOT/build/titan2/collect-n1b-phase-11-fastbootd-lp-sizing.sh" \
  --require-fastbootd ||
  fail phase11_collection_failed

mapfile -t p11_jsons < <(
  find "$PHASE11_ROOT" -type f -path '*/fastbootd-lp-sizing/phase11-fastbootd-lp-sizing.json' -print |
    LC_ALL=C sort
)
mapfile -t p11_getvars < <(
  find "$PHASE11_ROOT" -type f -path '*/fastbootd-lp-sizing/getvar-all.txt' -print |
    LC_ALL=C sort
)
[[ "${#p11_jsons[@]}" -eq 1 ]] || fail "phase11_json_count=${#p11_jsons[@]}"
[[ "${#p11_getvars[@]}" -eq 1 ]] || fail "phase11_getvar_count=${#p11_getvars[@]}"
PHASE11_JSON="${p11_jsons[0]}"
PHASE11_GETVAR_ALL="${p11_getvars[0]}"

FINAL_JSON="$EVIDENCE_DIR/c3a-v010014-fastboot-entry-preflight.json"
bash "$ROOT/build/titan2/qualify-c3a-v010014-fastboot-entry-preflight.sh" \
  --phase10b-json "$PHASE10B_JSON" \
  --phase11-json "$PHASE11_JSON" \
  --phase11-getvar-all "$PHASE11_GETVAR_ALL" \
  --offline-plan "$OFFLINE_PLAN" \
  --baseline-e5b-json "$BASELINE_E5B_JSON" \
  --fastboot-binding-sha256 "$FASTBOOT_BINDING_SHA256" \
  --output-json "$FINAL_JSON"

cp "$OFFLINE_PLAN" "$EVIDENCE_DIR/offline-control-plan.env"
cp "$OFFLINE_BINDING" "$EVIDENCE_DIR/offline-e5a-binding.env"
printf '%s\n' "$offline_seal" > "$EVIDENCE_DIR/offline-evidence-seal-sha256.txt"
printf '%s\n' "$baseline_e5b_sha" > "$EVIDENCE_DIR/baseline-e5b-sha256.txt"

(
  cd "$EVIDENCE_DIR"
  find . -type f \
    ! -name SHA256SUMS.txt \
    ! -name c3a-fastboot-entry-preflight.log \
    -print0 |
    LC_ALL=C sort -z |
    xargs -0 sha256sum > SHA256SUMS.txt
  sha256sum -c SHA256SUMS.txt >/dev/null
)

echo "C3A_FASTBOOT_ENTRY_EVIDENCE_DIR=$EVIDENCE_DIR"
echo "C3A_FASTBOOT_ENTRY_EVIDENCE_SEAL_SHA256=$(sha256sum "$EVIDENCE_DIR/SHA256SUMS.txt" | awk '{print $1}')"
echo "C3A_FASTBOOT_ENTRY_FLASH_AUTHORIZED=NO"
echo "C3A_FASTBOOT_ENTRY_FACTORY_RESET_AUTHORIZED=NO"
echo "C3A_FASTBOOT_ENTRY_FINAL_DEVICE_MODE=FASTBOOTD"
echo "C3A_FASTBOOT_ENTRY_PREFLIGHT_RUN=PASS_COLLECTION_AND_QUALIFICATION"
