#!/usr/bin/env bash
# Operator safety: never allow this mutating deployment script to be sourced.
# Returning here occurs before set -euo pipefail, so the parent SSH shell is
# left untouched on both success and failure.
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  echo "SABLE_STANDARD_FLASH=REFUSED_SOURCED_SCRIPT" >&2
  echo "Run with: bash ${BASH_SOURCE[0]} ..." >&2
  return 64
fi

set -euo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/common.sh"
# Canonical platform-tools live in the pinned Sable host-tool profile.
# Prefer them over distro adb/fastboot packages.
if [[ -f "$ROOT/build/config/r8-host-tools.env" ]]; then
  # shellcheck source=/dev/null
  source "$ROOT/build/config/r8-host-tools.env"
fi

DEVICE=""
RELEASE=""
BUILD_SOURCE=""
SERIAL=""
AUTHORIZED=NO
PRESERVE_DATA=NO
REGISTRY_ROOT="${SABLE_RELEASE_REGISTRY_ROOT:-/srv/data/sable-build/release-registry}"
EVIDENCE_ROOT="${SABLE_DEVICE_EVIDENCE_ROOT:-/srv/data/sable-build/evidence}"

usage() {
  cat >&2 <<'EOF'
usage:
  bash build/deploy/flash.sh \
    --device <device> \
    --release <release> \
    --build-source <40-hex-sha> \
    --serial <adb/fastboot-serial> \
    --preserve-data \
    --authorize
EOF
}

while (($#)); do
  case "$1" in
    --device) DEVICE="$2"; shift 2 ;;
    --release) RELEASE="$2"; shift 2 ;;
    --build-source) BUILD_SOURCE="$2"; shift 2 ;;
    --serial) SERIAL="$2"; shift 2 ;;
    --registry-root) REGISTRY_ROOT="$2"; shift 2 ;;
    --evidence-root) EVIDENCE_ROOT="$2"; shift 2 ;;
    --preserve-data) PRESERVE_DATA=YES; shift ;;
    --authorize) AUTHORIZED=YES; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage; exit 64 ;;
  esac
done

[[ -n "$DEVICE" && -n "$RELEASE" && -n "$BUILD_SOURCE" && -n "$SERIAL" ]] || {
  usage
  exit 64
}
[[ "$BUILD_SOURCE" =~ ^[0-9a-f]{40}$ ]] || sable_die "SABLE_BUILD_SOURCE" "invalid build source" 64
[[ "$AUTHORIZED" == YES ]] || sable_die "SABLE_FLASH_AUTHORIZATION" "explicit --authorize required" 64
[[ "$PRESERVE_DATA" == YES ]] || sable_die "SABLE_FLASH_POLICY" "only --preserve-data deployment is implemented" 64

ADAPTER="$ROOT/build/devices/$DEVICE.sh"
[[ -f "$ADAPTER" ]] || sable_die "SABLE_DEVICE_ADAPTER" "missing adapter for $DEVICE" 64
# shellcheck source=/dev/null
source "$ADAPTER"

[[ "${SABLE_DEVICE_FLASH_SUPPORTED:-NO}" == YES ]] || sable_die "SABLE_DEVICE_FLASH_SUPPORTED" "device adapter blocks flashing" 78
[[ "${SABLE_DEVICE_PRESERVED_DATA_FLASH_SUPPORTED:-NO}" == YES ]] || sable_die "SABLE_PRESERVED_DATA_FLASH_SUPPORTED" "device adapter blocks preserved-data flash" 78

REGISTRY="$ROOT/build/deploy/artifact_registry.py"
PLAN="$ROOT/build/deploy/target_files_plan.py"

field() {
  python3 "$REGISTRY" --registry-root "$REGISTRY_ROOT" field \
    --device "$DEVICE" \
    --release "$RELEASE" \
    --build-source "$BUILD_SOURCE" \
    --field "$1"
}

TF="$(field target_files)" || sable_die "SABLE_ARTIFACT_MANIFEST" "artifact manifest not found" 30
EXPECTED_TF_SHA="$(field target_files_sha256)"
ANDROID_INFO="$(field android_info)"
EXPECTED_ANDROID_INFO_SHA="$(field android_info_sha256)"
OUT_DIR="$(field out_dir 2>/dev/null || true)"
BUILD_EVIDENCE_DIR="$(field build_evidence_dir 2>/dev/null || true)"

if declare -F sable_device_artifact_gate >/dev/null 2>&1; then
  sable_device_artifact_gate "$RELEASE" "$BUILD_SOURCE" "$EXPECTED_TF_SHA" "$BUILD_EVIDENCE_DIR" \
    || sable_die "SABLE_DEVICE_ARTIFACT_GATE" "qualified build evidence missing or inconsistent" 30
fi

[[ -f "$TF" ]] || sable_die "SABLE_TARGET_FILES_PRESENT" "target-files missing: $TF" 31
[[ -f "$ANDROID_INFO" ]] || sable_die "SABLE_ANDROID_INFO_PRESENT" "android-info missing: $ANDROID_INFO" 31

ACTUAL_TF_SHA="$(sable_sha256 "$TF")"
[[ "$ACTUAL_TF_SHA" == "$EXPECTED_TF_SHA" ]] || sable_die "SABLE_TARGET_FILES_IDENTITY" "target-files hash mismatch" 32
ACTUAL_ANDROID_INFO_SHA="$(sable_sha256 "$ANDROID_INFO")"
[[ "$ACTUAL_ANDROID_INFO_SHA" == "$EXPECTED_ANDROID_INFO_SHA" ]] || sable_die "SABLE_ANDROID_INFO_IDENTITY" "android-info hash mismatch" 32

ADB_BIN=""
FASTBOOT_BIN=""

if [[ -n "${SABLE_ANDROID_SDK:-}" && -x "$SABLE_ANDROID_SDK/platform-tools/adb" ]]; then
  ADB_BIN="$SABLE_ANDROID_SDK/platform-tools/adb"
elif [[ -n "$OUT_DIR" && -x "$OUT_DIR/host/linux-x86/bin/adb" ]]; then
  ADB_BIN="$OUT_DIR/host/linux-x86/bin/adb"
else
  ADB_BIN="$(command -v adb || true)"
fi

if [[ -n "${SABLE_ANDROID_SDK:-}" && -x "$SABLE_ANDROID_SDK/platform-tools/fastboot" ]]; then
  FASTBOOT_BIN="$SABLE_ANDROID_SDK/platform-tools/fastboot"
elif [[ -n "$OUT_DIR" && -x "$OUT_DIR/host/linux-x86/bin/fastboot" ]]; then
  FASTBOOT_BIN="$OUT_DIR/host/linux-x86/bin/fastboot"
else
  FASTBOOT_BIN="$(command -v fastboot || true)"
fi

[[ -x "$ADB_BIN" ]] || sable_die "SABLE_ADB" "adb executable unavailable" 33
[[ -x "$FASTBOOT_BIN" ]] || sable_die "SABLE_FASTBOOT" "fastboot executable unavailable" 33

FASTBOOT_VERSION="$(
  "$FASTBOOT_BIN" --version 2>/dev/null |
    awk '/^fastboot version / {print $3; exit}' |
    cut -d- -f1
)"
MIN_FASTBOOT_VERSION=35.0.1
[[ -n "$FASTBOOT_VERSION" ]] ||
  sable_die "SABLE_FASTBOOT_VERSION" "unable to read fastboot version" 33
[[ "$(
  printf '%s\n' "$MIN_FASTBOOT_VERSION" "$FASTBOOT_VERSION" |
    sort -V |
    head -n1
)" == "$MIN_FASTBOOT_VERSION" ]] ||
  sable_die "SABLE_FASTBOOT_VERSION" "minimum=$MIN_FASTBOOT_VERSION actual=$FASTBOOT_VERSION" 33

echo "SABLE_ADB_BIN=$ADB_BIN"
echo "SABLE_FASTBOOT_BIN=$FASTBOOT_BIN"
echo "SABLE_FASTBOOT_VERSION=$FASTBOOT_VERSION"
echo "SABLE_FASTBOOT_VERSION_GATE=PASS"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="$EVIDENCE_ROOT/$DEVICE/${RELEASE,,}-physical/${STAMP}_flash"
STAGE_DIR="$EVIDENCE_DIR/flash-payload"
mkdir -p "$EVIDENCE_DIR"

exec 3>&1 4>&2
exec > >(tee "$EVIDENCE_DIR/flash.log" >&3) 2>&1

FINAL_RESULT=FAIL
finalize_run() {
  local rc=$?
  trap - EXIT
  if [[ "$FINAL_RESULT" != PASS ]]; then
    echo "SABLE_BLOCKER_ISSUE_REQUIRED=YES"
    echo "SABLE_STANDARD_FLASH=FAIL rc=$rc"

    if [[ "${REBOOTED_TO_BOOTLOADER:-NO}" == YES && "${FLASH_STARTED:-NO}" == NO ]]; then
      echo "PREWRITE_FAILURE_RECOVERY=ATTEMPT_FASTBOOT_REBOOT"
      if "$FASTBOOT_BIN" -s "$SERIAL" reboot </dev/null >/dev/null 2>&1; then
        echo "PREWRITE_FAILURE_RECOVERY_FASTBOOT_REBOOT=PASS"
        if sable_wait_adb_boot_completed "$ADB_BIN" "$SERIAL" 300; then
          echo "PREWRITE_FAILURE_RECOVERY=PASS_ANDROID"
        else
          echo "PREWRITE_FAILURE_RECOVERY=BOUNDED_FAIL_ANDROID_NOT_CONFIRMED"
        fi
      else
        echo "PREWRITE_FAILURE_RECOVERY=BOUNDED_FAIL_FASTBOOT_REBOOT"
      fi
    elif [[ "${FLASH_STARTED:-NO}" == YES && "${POSTFLASH_REBOOT_SENT:-NO}" == NO ]]; then
      echo "AUTOMATIC_REBOOT_AFTER_FLASH_FAILURE=SUPPRESSED"
    fi
  fi

  exec 1>&3 2>&4
  wait || true

  if [[ -d "$EVIDENCE_DIR" ]]; then
    sable_seal_evidence_dir "$EVIDENCE_DIR" || true
    echo "EVIDENCE_DIR=$EVIDENCE_DIR"
  fi

  if [[ "$FINAL_RESULT" == PASS ]]; then
    echo "SABLE_STANDARD_FLASH=PASS"
  fi
  exit "$rc"
}
trap finalize_run EXIT

TOOL_SOURCE="$(git -C "$ROOT" rev-parse HEAD)"
echo "===== SABLEOS STANDARD DEVICE FLASH ====="
echo "DEVICE=$DEVICE"
echo "RELEASE=$RELEASE"
echo "TOOL_SOURCE_COMMIT=$TOOL_SOURCE"
echo "BUILD_SOURCE_COMMIT=$BUILD_SOURCE"
echo "TARGET_FILES=$TF"
echo "TARGET_FILES_SHA256=$ACTUAL_TF_SHA"
echo "ANDROID_INFO=$ANDROID_INFO"
echo "ANDROID_INFO_SHA256=$ACTUAL_ANDROID_INFO_SHA"
echo "BUILD_EVIDENCE_DIR=${BUILD_EVIDENCE_DIR:-NOT_RECORDED}"
echo "SERIAL=$(sable_mask_serial "$SERIAL")"
echo "PRESERVE_DATA=$PRESERVE_DATA"
echo "DEVICE_CONTACT_AUTHORIZED=YES"
echo "DEVICE_REBOOT_AUTHORIZED=YES"
echo "FLASH_AUTHORIZED=YES"
echo "SLOT_REASSERTION_AUTHORIZED=YES"
echo "SLOT_CHANGE_AUTHORIZED=NO"
echo "BOOTLOADER_UNLOCK_AUTHORIZED=NO"
echo "USERDATA_OR_METADATA_WIPE_AUTHORIZED=NO"
echo "INACTIVE_SLOT_FLASH_AUTHORIZED=NO"
echo "FASTBOOT_WIPE_FLAG=ABSENT"

sable_git_clean_or_die "$ROOT"

echo
echo "===== TARGET-FILES PLAN + EXACT STAGING ====="
python3 "$PLAN" \
  --target-files "$TF" \
  --expected-sha256 "$EXPECTED_TF_SHA" \
  --evidence-dir "$EVIDENCE_DIR" \
  --stage-dir "$STAGE_DIR" \
  --android-info "$ANDROID_INFO"

echo
echo "===== PRE-MUTATION DEVICE BINDING ====="
mapfile -t ADB_READY < <("$ADB_BIN" devices </dev/null | awk 'NR>1 && $2=="device" {print $1}')
[[ "${#ADB_READY[@]}" -eq 1 ]] || sable_die "SABLE_ADB_SINGLE_DEVICE" "expected exactly one authorized adb device" 40
[[ "${ADB_READY[0]}" == "$SERIAL" ]] || sable_die "SABLE_ADB_SERIAL" "attached adb device does not match requested serial" 40

PRODUCT="$("$ADB_BIN" -s "$SERIAL" shell getprop ro.product.device </dev/null | tr -d '\r')"
SLOT_SUFFIX="$("$ADB_BIN" -s "$SERIAL" shell getprop ro.boot.slot_suffix </dev/null | tr -d '\r')"
LOCKED="$("$ADB_BIN" -s "$SERIAL" shell getprop ro.boot.flash.locked </dev/null | tr -d '\r')"
VBMETA="$("$ADB_BIN" -s "$SERIAL" shell getprop ro.boot.vbmeta.device_state </dev/null | tr -d '\r')"
CE="$("$ADB_BIN" -s "$SERIAL" shell getprop sys.user.0.ce_available </dev/null | tr -d '\r')"

echo "PRE_DEVICE_PRODUCT=$PRODUCT"
echo "PRE_SLOT_SUFFIX=$SLOT_SUFFIX"
echo "PRE_FLASH_LOCKED=$LOCKED"
echo "PRE_VBMETA_DEVICE_STATE=$VBMETA"
echo "PRE_CE_AVAILABLE=$CE"

[[ "$PRODUCT" == "$SABLE_DEVICE_EXPECTED_PRODUCT" ]] || sable_die "SABLE_DEVICE_PRODUCT" "expected $SABLE_DEVICE_EXPECTED_PRODUCT actual $PRODUCT" 40
[[ "$SLOT_SUFFIX" =~ ^_[ab]$ ]] || sable_die "SABLE_DEVICE_SLOT" "unexpected slot suffix: $SLOT_SUFFIX" 40
[[ "$LOCKED" == 0 && "$VBMETA" == unlocked ]] || sable_die "SABLE_DEVICE_UNLOCKED" "development flash requires pre-existing unlocked bootloader" 40
[[ "$CE" == 1 || "$CE" == true ]] || sable_die "SABLE_PRE_CE_AVAILABLE" "unlock device before preserved-data baseline" 40

SLOT="${SLOT_SUFFIX#_}"
echo "FLASH_TARGET_SLOT=$SLOT"
echo "SABLE_PRE_DEVICE_BINDING=PASS"

echo
echo "===== PRESERVED-DATA BASELINE ====="
BASELINE_LOG="$EVIDENCE_DIR/baseline-capture.log"
set +e
sable_run_sablectl "$ROOT" \
  --adb "$ADB_BIN" \
  --serial "$SERIAL" \
  --output-root "$EVIDENCE_DIR/sablectl" \
  baseline capture \
  --out-root "$EVIDENCE_DIR/baselines" \
  2>&1 | tee "$BASELINE_LOG"
BASELINE_RC=${PIPESTATUS[0]}
set -e
[[ "$BASELINE_RC" -eq 0 ]] || sable_die "SABLE_PRESERVED_DATA_BASELINE" "sablectl baseline capture failed rc=$BASELINE_RC" 41
BASELINE="$(sed -n 's/^BASELINE=//p' "$BASELINE_LOG" | tail -n1)"
[[ -f "$BASELINE" ]] || sable_die "SABLE_PRESERVED_DATA_BASELINE" "baseline path not produced" 41
echo "PRESERVED_DATA_BASELINE=$BASELINE"
echo "SABLE_PRESERVED_DATA_BASELINE=PASS"

echo
echo "===== PRE-REBOOT ANDROID-INFO ====="
cat "$ANDROID_INFO"
REQUIRED_BOARD="$(sed -n 's/^require board=//p' "$ANDROID_INFO" | tail -n1)"
[[ -z "$REQUIRED_BOARD" || "$REQUIRED_BOARD" == "$PRODUCT" ]] || sable_die "SABLE_ANDROID_INFO_BOARD" "android-info board mismatch" 42

REBOOTED_TO_BOOTLOADER=NO
FLASH_STARTED=NO
POSTFLASH_REBOOT_SENT=NO

echo
echo "===== ENTER BOOTLOADER ====="
"$ADB_BIN" -s "$SERIAL" reboot bootloader </dev/null
REBOOTED_TO_BOOTLOADER=YES

sable_wait_fastboot_ready "$FASTBOOT_BIN" "$SERIAL" "$SABLE_DEVICE_EXPECTED_PRODUCT" 120 \
  || sable_die "SABLE_FASTBOOT_READY" "fastboot getvar product did not become ready" 43

mapfile -t FB_READY < <("$FASTBOOT_BIN" devices </dev/null | awk 'NF>=1 {print $1}')
[[ "${#FB_READY[@]}" -eq 1 && "${FB_READY[0]}" == "$SERIAL" ]] \
  || sable_die "SABLE_FASTBOOT_SINGLE_DEVICE" "fastboot transport is ambiguous" 43

FB_SLOT="$(sable_fastboot_getvar "$FASTBOOT_BIN" "$SERIAL" current-slot)"
FB_UNLOCKED="$(sable_fastboot_getvar "$FASTBOOT_BIN" "$SERIAL" unlocked)"
FB_BOOTLOADER="$(sable_fastboot_getvar "$FASTBOOT_BIN" "$SERIAL" version-bootloader)"
FB_BASEBAND="$(sable_fastboot_getvar "$FASTBOOT_BIN" "$SERIAL" version-baseband)"

echo "FASTBOOT_CURRENT_SLOT=$FB_SLOT"
echo "FASTBOOT_UNLOCKED=$FB_UNLOCKED"
echo "FASTBOOT_VERSION_BOOTLOADER=$FB_BOOTLOADER"
echo "FASTBOOT_VERSION_BASEBAND=$FB_BASEBAND"

[[ "$FB_SLOT" == "$SLOT" ]] || sable_die "SABLE_FASTBOOT_SLOT" "slot changed before flash expected=$SLOT actual=$FB_SLOT" 44
case "$FB_UNLOCKED" in yes|true|1) ;; *) sable_die "SABLE_FASTBOOT_UNLOCKED" "bootloader no longer reports unlocked" 44 ;; esac

REQ_BOOTLOADER="$(sed -n 's/^require version-bootloader=//p' "$ANDROID_INFO" | tail -n1)"
REQ_BASEBAND="$(sed -n 's/^require version-baseband=//p' "$ANDROID_INFO" | tail -n1)"
if [[ -n "$REQ_BOOTLOADER" ]]; then
  [[ "$FB_BOOTLOADER" == "$REQ_BOOTLOADER" ]] || sable_die "SABLE_BOOTLOADER_REQUIREMENT" "expected=$REQ_BOOTLOADER actual=$FB_BOOTLOADER" 45
fi
if [[ -n "$REQ_BASEBAND" ]]; then
  [[ "$FB_BASEBAND" == "$REQ_BASEBAND" ]] || sable_die "SABLE_BASEBAND_REQUIREMENT" "expected=$REQ_BASEBAND actual=$FB_BASEBAND" 45
fi

while IFS= read -r part; do
  [[ -n "$part" ]] || continue
  has_slot="$(sable_fastboot_getvar "$FASTBOOT_BIN" "$SERIAL" "has-slot:$part")"
  echo "FASTBOOT_PARTITION_EXISTS partition=$part has_slot=${has_slot:-UNOBSERVABLE}"
  case "$has_slot" in
    yes|no) ;;
    *)
      sable_die "SABLE_REQUIRED_PARTITION" \
        "fastboot has-slot requirement failed for partition: $part" 45
      ;;
  esac
done < <(sed -n 's/^require partition-exists=//p' "$ANDROID_INFO")

echo "SABLE_FASTBOOT_PREFLASH_REQUIREMENTS=PASS"

echo
echo "===== VERIFY STAGED PAYLOAD BEFORE WRITE ====="
(
  cd "$STAGE_DIR"
  sha256sum -c SHA256SUMS.txt
)
echo "SABLE_STAGED_PAYLOAD_VERIFY=PASS"

echo
echo "===== CONTROLLED CURRENT-SLOT PRESERVED-DATA FLASH ====="
echo "FLASH_METHOD=FASTBOOT_FLASHALL_STAGED_CURRENT_SLOT"
echo "FLASH_TARGET_SLOT=$SLOT"
echo "FLASH_SKIP_SECONDARY=YES"
echo "FLASH_SKIP_REBOOT=YES"
echo "FLASH_WIPE=NO"
echo "FLASH_ANDROID_PRODUCT_OUT=$STAGE_DIR"

FLASH_STARTED=YES
set +e
ANDROID_PRODUCT_OUT="$STAGE_DIR" \
  "$FASTBOOT_BIN" -s "$SERIAL" \
    --slot "$SLOT" \
    --set-active="$SLOT" \
    --skip-secondary \
    --skip-reboot \
    flashall \
    </dev/null 2>&1 | tee "$EVIDENCE_DIR/fastboot-flashall.log"
FLASH_RC=${PIPESTATUS[0]}
set -e
echo "FASTBOOT_FLASHALL_RC=$FLASH_RC"
if [[ "$FLASH_RC" -ne 0 ]]; then
  echo "SABLE_BLOCKER_ISSUE_REQUIRED=YES"
  echo "FINAL_REBOOT_SUPPRESSED_DUE_TO_FLASH_FAILURE=YES"
  sable_die "SABLE_FLASH_EXECUTION" "fastboot flashall failed rc=$FLASH_RC" 50
fi

sable_wait_fastboot_ready "$FASTBOOT_BIN" "$SERIAL" "$SABLE_DEVICE_EXPECTED_PRODUCT" 120 \
  || sable_die "SABLE_POSTFLASH_FASTBOOT_READY" "fastboot unavailable after successful flashall" 51
POST_SLOT="$(sable_fastboot_getvar "$FASTBOOT_BIN" "$SERIAL" current-slot)"
echo "POST_FLASH_PRE_REBOOT_SLOT=$POST_SLOT"
if [[ "$POST_SLOT" != "$SLOT" ]]; then
  echo "SABLE_BLOCKER_ISSUE_REQUIRED=YES"
  echo "FINAL_REBOOT_SUPPRESSED_DUE_TO_SLOT_MISMATCH=YES"
  sable_die "SABLE_POSTFLASH_SLOT" "expected=$SLOT actual=$POST_SLOT" 51
fi
echo "SABLE_FLASH_EXECUTION=PASS"
echo "SABLE_POSTFLASH_SLOT_PRESERVED=PASS"

"$FASTBOOT_BIN" -s "$SERIAL" reboot </dev/null
POSTFLASH_REBOOT_SENT=YES
echo "FINAL_FASTBOOT_REBOOT=PASS"

echo
echo "===== POST-BOOT ====="
sable_wait_adb_boot_completed "$ADB_BIN" "$SERIAL" 420 \
  || sable_die "SABLE_POSTBOOT" "Android did not return completed within timeout" 52

echo "USER_ACTION=UNLOCK_DEVICE_IF_REQUIRED_FOR_CREDENTIAL_ENCRYPTED_DATA"
CE_START="$(date +%s)"
while :; do
  CE="$("$ADB_BIN" -s "$SERIAL" shell getprop sys.user.0.ce_available </dev/null 2>/dev/null | tr -d '\r')"
  if [[ "$CE" == 1 || "$CE" == true ]]; then
    break
  fi
  if (( $(date +%s) - CE_START >= 300 )); then
    sable_die "SABLE_POST_CE_AVAILABLE" "credential-encrypted user data not available" 53
  fi
  sleep 2
done
echo "SABLE_POST_CE_AVAILABLE=PASS"

set +e
sable_run_sablectl "$ROOT" \
  --adb "$ADB_BIN" \
  --serial "$SERIAL" \
  --output-root "$EVIDENCE_DIR/sablectl" \
  smoke \
  --target-files "$TF" \
  --baseline "$BASELINE" \
  --expected-device "$SABLE_DEVICE_EXPECTED_PRODUCT" \
  --expected-slot "$SLOT" \
  --hash-container \
  2>&1 | tee "$EVIDENCE_DIR/sablectl-smoke.log"
SMOKE_RC=${PIPESTATUS[0]}
set -e
if [[ "$SMOKE_RC" -ne 0 ]]; then
  echo "SABLE_BLOCKER_ISSUE_REQUIRED=YES"
  sable_die "SABLE_POSTFLASH_SMOKE" "sablectl smoke failed rc=$SMOKE_RC" 54
fi
echo "SABLE_POSTFLASH_SMOKE=PASS"

echo
echo "===== FINAL DEVICE IDENTITY ====="
echo "POST_DEVICE_PRODUCT=$("$ADB_BIN" -s "$SERIAL" shell getprop ro.product.device </dev/null | tr -d '\r')"
echo "POST_SLOT_SUFFIX=$("$ADB_BIN" -s "$SERIAL" shell getprop ro.boot.slot_suffix </dev/null | tr -d '\r')"
echo "POST_BUILD_FINGERPRINT=$("$ADB_BIN" -s "$SERIAL" shell getprop ro.build.fingerprint </dev/null | tr -d '\r')"
echo "POST_VERIFIED_BOOT_STATE=$("$ADB_BIN" -s "$SERIAL" shell getprop ro.boot.verifiedbootstate </dev/null | tr -d '\r')"

FINAL_RESULT=PASS
