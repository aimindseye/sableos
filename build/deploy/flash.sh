#!/usr/bin/env bash
# Common SableOS deployment policy/orchestration.
# Device mutation semantics live behind build/devices/<device>.sh callbacks.
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
    --serial <adb/transport-serial> \
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

[[ "${SABLE_DEVICE_FLASH_SUPPORTED:-NO}" == YES ]] ||
  sable_die "SABLE_DEVICE_FLASH_SUPPORTED" "device adapter blocks flashing" 78
[[ "${SABLE_DEVICE_PRESERVED_DATA_FLASH_SUPPORTED:-NO}" == YES ]] ||
  sable_die "SABLE_PRESERVED_DATA_FLASH_SUPPORTED" "device adapter blocks preserved-data flash" 78
[[ -n "${SABLE_DEVICE_EXPECTED_PRODUCT:-}" && "${SABLE_DEVICE_EXPECTED_PRODUCT}" != UNQUALIFIED ]] ||
  sable_die "SABLE_DEVICE_EXPECTED_PRODUCT" "qualified expected product is required" 78

for callback in   sable_device_flash_prepare_artifact   sable_device_flash_preflight   sable_device_flash_execute   sable_device_flash_postboot
do
  declare -F "$callback" >/dev/null 2>&1 ||
    sable_die "SABLE_DEVICE_FLASH_CALLBACK" "missing adapter callback: $callback" 78
done
echo "SABLE_DEVICE_FLASH_CALLBACK_CONTRACT=PASS"

REGISTRY="$ROOT/build/deploy/artifact_registry.py"
PLAN="$ROOT/build/deploy/target_files_plan.py"

field() {
  python3 "$REGISTRY" --registry-root "$REGISTRY_ROOT" field     --device "$DEVICE"     --release "$RELEASE"     --build-source "$BUILD_SOURCE"     --field "$1"
}

python3 "$REGISTRY" --registry-root "$REGISTRY_ROOT" verify   --device "$DEVICE" --release "$RELEASE" --build-source "$BUILD_SOURCE" ||
  sable_die "SABLE_ARTIFACT_MANIFEST_VERIFY" "registered artifact set failed verification" 30

ARTIFACT_KIND="$(field artifact_kind)" ||
  sable_die "SABLE_ARTIFACT_KIND" "artifact kind missing" 30
PRIMARY_ARTIFACT="$(field primary_artifact)" ||
  sable_die "SABLE_PRIMARY_ARTIFACT" "primary artifact missing" 30
PRIMARY_PATH="$(field "artifacts.$PRIMARY_ARTIFACT.path")" ||
  sable_die "SABLE_PRIMARY_ARTIFACT_PATH" "primary artifact path missing" 30
PRIMARY_SHA="$(field "artifacts.$PRIMARY_ARTIFACT.sha256")" ||
  sable_die "SABLE_PRIMARY_ARTIFACT_SHA256" "primary artifact hash missing" 30
OUT_DIR="$(field out_dir 2>/dev/null || true)"
BUILD_EVIDENCE_DIR="$(field build_evidence_dir 2>/dev/null || true)"

sable_artifact_kind_supported "$ARTIFACT_KIND" ||
  sable_die "SABLE_DEVICE_ARTIFACT_KIND"     "device=$DEVICE does not support artifact kind=$ARTIFACT_KIND" 30
echo "SABLE_DEVICE_ARTIFACT_KIND=PASS kind=$ARTIFACT_KIND"

if declare -F sable_device_artifact_gate >/dev/null 2>&1; then
  sable_device_artifact_gate     "$RELEASE" "$BUILD_SOURCE" "$ARTIFACT_KIND" "$PRIMARY_SHA" "$BUILD_EVIDENCE_DIR" ||
    sable_die "SABLE_DEVICE_ARTIFACT_GATE" "qualified build evidence missing or inconsistent" 30
fi

ADB_BIN=""
FASTBOOT_BIN=""

if [[ -n "${SABLE_ANDROID_SDK:-}" && -x "$SABLE_ANDROID_SDK/platform-tools/adb" ]]; then
  ADB_BIN="$SABLE_ANDROID_SDK/platform-tools/adb"
elif [[ -n "$OUT_DIR" && -x "$OUT_DIR/host/linux-x86/bin/adb" ]]; then
  ADB_BIN="$OUT_DIR/host/linux-x86/bin/adb"
else
  ADB_BIN="$(command -v adb || true)"
fi
[[ -x "$ADB_BIN" ]] || sable_die "SABLE_ADB" "adb executable unavailable" 33
echo "SABLE_ADB_BIN=$ADB_BIN"

if [[ "${SABLE_DEVICE_REQUIRES_FASTBOOT:-NO}" == YES ]]; then
  if [[ -n "${SABLE_ANDROID_SDK:-}" && -x "$SABLE_ANDROID_SDK/platform-tools/fastboot" ]]; then
    FASTBOOT_BIN="$SABLE_ANDROID_SDK/platform-tools/fastboot"
  elif [[ -n "$OUT_DIR" && -x "$OUT_DIR/host/linux-x86/bin/fastboot" ]]; then
    FASTBOOT_BIN="$OUT_DIR/host/linux-x86/bin/fastboot"
  else
    FASTBOOT_BIN="$(command -v fastboot || true)"
  fi
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
  echo "SABLE_FASTBOOT_BIN=$FASTBOOT_BIN"
  echo "SABLE_FASTBOOT_VERSION=$FASTBOOT_VERSION"
  echo "SABLE_FASTBOOT_VERSION_GATE=PASS"
fi

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="$EVIDENCE_ROOT/$DEVICE/${RELEASE,,}-physical/${STAMP}_flash"
STAGE_DIR="$EVIDENCE_DIR/flash-payload"
mkdir -p "$EVIDENCE_DIR"

exec 3>&1 4>&2
exec > >(tee "$EVIDENCE_DIR/flash.log" >&3) 2>&1

FINAL_RESULT=FAIL
REBOOTED_TO_FLASH_MODE=NO
REBOOTED_TO_BOOTLOADER=NO
FLASH_STARTED=NO
POSTFLASH_REBOOT_SENT=NO

finalize_run() {
  local rc=$?
  trap - EXIT
  if [[ "$FINAL_RESULT" != PASS ]]; then
    echo "SABLE_BLOCKER_ISSUE_REQUIRED=YES"
    echo "SABLE_STANDARD_FLASH=FAIL rc=$rc"

    if [[ "$REBOOTED_TO_FLASH_MODE" == YES && "$FLASH_STARTED" == NO ]]; then
      echo "PREWRITE_FAILURE_RECOVERY=ATTEMPT_ADAPTER_RECOVERY"
      if declare -F sable_device_flash_recover_prewrite >/dev/null 2>&1 &&
         sable_device_flash_recover_prewrite; then
        echo "PREWRITE_FAILURE_RECOVERY=PASS_ANDROID"
      else
        echo "PREWRITE_FAILURE_RECOVERY=BOUNDED_FAIL"
      fi
    elif [[ "$FLASH_STARTED" == YES && "$POSTFLASH_REBOOT_SENT" == NO ]]; then
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
echo "ARTIFACT_KIND=$ARTIFACT_KIND"
echo "PRIMARY_ARTIFACT=$PRIMARY_ARTIFACT"
echo "PRIMARY_ARTIFACT_PATH=$PRIMARY_PATH"
echo "PRIMARY_ARTIFACT_SHA256=$PRIMARY_SHA"
echo "BUILD_EVIDENCE_DIR=${BUILD_EVIDENCE_DIR:-NOT_RECORDED}"
echo "SERIAL=$(sable_mask_serial "$SERIAL")"
echo "PRESERVE_DATA=$PRESERVE_DATA"
echo "FLASH_TRANSPORT=${SABLE_DEVICE_FLASH_TRANSPORT:-adapter-defined}"
echo "DEVICE_CONTACT_AUTHORIZED=YES"
echo "DEVICE_REBOOT_AUTHORIZED=YES"
echo "FLASH_AUTHORIZED=YES"
echo "SLOT_CHANGE_AUTHORIZED=NO"
echo "BOOTLOADER_UNLOCK_AUTHORIZED=NO"
echo "USERDATA_OR_METADATA_WIPE_AUTHORIZED=NO"
echo "INACTIVE_SLOT_FLASH_AUTHORIZED=NO"
echo "FASTBOOT_WIPE_FLAG=ABSENT"

sable_git_clean_or_die "$ROOT"

echo
echo "===== DEVICE ARTIFACT PREPARATION ====="
sable_device_flash_prepare_artifact ||
  sable_die "SABLE_DEVICE_FLASH_ARTIFACT_PREPARE" "adapter artifact preparation failed" 35

echo
echo "===== PRE-MUTATION DEVICE BINDING ====="
sable_require_adb_serial_exact_once "$ADB_BIN" "$SERIAL" ||
  sable_die "SABLE_ADB_TARGET_SERIAL" "requested serial is not exactly once among ready adb devices" 40

PRE_DEVICE_PRODUCT="$("$ADB_BIN" -s "$SERIAL" shell getprop ro.product.device </dev/null | tr -d '\r')"
PRE_CE_AVAILABLE="$("$ADB_BIN" -s "$SERIAL" shell getprop sys.user.0.ce_available </dev/null | tr -d '\r')"
echo "PRE_DEVICE_PRODUCT=$PRE_DEVICE_PRODUCT"
echo "PRE_CE_AVAILABLE=$PRE_CE_AVAILABLE"

[[ "$PRE_DEVICE_PRODUCT" == "$SABLE_DEVICE_EXPECTED_PRODUCT" ]] ||
  sable_die "SABLE_DEVICE_PRODUCT"     "expected $SABLE_DEVICE_EXPECTED_PRODUCT actual $PRE_DEVICE_PRODUCT" 40
[[ "$PRE_CE_AVAILABLE" == 1 || "$PRE_CE_AVAILABLE" == true ]] ||
  sable_die "SABLE_PRE_CE_AVAILABLE" "unlock device before preserved-data baseline" 40
echo "SABLE_PRE_DEVICE_BINDING=PASS"

sable_device_flash_preflight ||
  sable_die "SABLE_DEVICE_FLASH_PREFLIGHT" "adapter preflight failed" 42

echo
echo "===== PRESERVED-DATA BASELINE ====="
BASELINE_LOG="$EVIDENCE_DIR/baseline-capture.log"
set +e
sable_run_sablectl "$ROOT"   --adb "$ADB_BIN"   --serial "$SERIAL"   --output-root "$EVIDENCE_DIR/sablectl"   baseline capture   --out-root "$EVIDENCE_DIR/baselines"   2>&1 | tee "$BASELINE_LOG"
BASELINE_RC=${PIPESTATUS[0]}
set -e
[[ "$BASELINE_RC" -eq 0 ]] ||
  sable_die "SABLE_PRESERVED_DATA_BASELINE" "sablectl baseline capture failed rc=$BASELINE_RC" 41
BASELINE="$(sed -n 's/^BASELINE=//p' "$BASELINE_LOG" | tail -n1)"
[[ -f "$BASELINE" ]] ||
  sable_die "SABLE_PRESERVED_DATA_BASELINE" "baseline path not produced" 41
echo "PRESERVED_DATA_BASELINE=$BASELINE"
echo "SABLE_PRESERVED_DATA_BASELINE=PASS"

echo
echo "===== ADAPTER DEPLOYMENT ====="
sable_device_flash_execute ||
  sable_die "SABLE_FLASH_EXECUTION" "device adapter deployment failed" 50

echo
echo "===== POST-BOOT ====="
sable_wait_adb_boot_completed "$ADB_BIN" "$SERIAL" "${SABLE_DEVICE_POSTBOOT_TIMEOUT:-420}" ||
  sable_die "SABLE_POSTBOOT" "Android did not return completed within timeout" 52

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

sable_device_flash_postboot ||
  sable_die "SABLE_POSTFLASH_SMOKE" "adapter post-boot acceptance failed" 54

echo
echo "===== FINAL DEVICE IDENTITY ====="
echo "POST_DEVICE_PRODUCT=$("$ADB_BIN" -s "$SERIAL" shell getprop ro.product.device </dev/null | tr -d '\r')"
echo "POST_SLOT_SUFFIX=$("$ADB_BIN" -s "$SERIAL" shell getprop ro.boot.slot_suffix </dev/null | tr -d '\r')"
echo "POST_BUILD_FINGERPRINT=$("$ADB_BIN" -s "$SERIAL" shell getprop ro.build.fingerprint </dev/null | tr -d '\r')"
echo "POST_VERIFIED_BOOT_STATE=$("$ADB_BIN" -s "$SERIAL" shell getprop ro.boot.verifiedbootstate </dev/null | tr -d '\r')"

FINAL_RESULT=PASS
