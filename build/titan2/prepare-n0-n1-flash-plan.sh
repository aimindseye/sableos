#!/usr/bin/env bash

RELEASE=""
BUILD_SOURCE=""
ARTIFACT_KIND=""
SYSTEM_IMG=""
EXPECTED_SHA256=""
ARTIFACT_LOGICAL_BYTES=""
SYSTEM_CURRENT_BYTES=""
RESTORE_REPORT=""
BOOTLOADER_PREFLIGHT=""
FASTBOOTD_PREFLIGHT=""
SNAPSHOT_UPDATE_STATUS=""
LP_ACTION=""
AVB_ACTION=""
USERDATA_POLICY=""
EXPLICIT_TITAN_SERIAL=""
ACTIVE_SLOT=""
STOCK_BASELINE=""
RESTORE_PATH_VERIFIED=""
EVIDENCE_DIR=""

usage() {
  cat >&2 <<'EOF'
usage:
  bash build/titan2/prepare-n0-n1-flash-plan.sh \
    --release N0|N1 \
    --build-source <40-hex-sha> \
    --artifact-kind gsi-system-image \
    --system-img /absolute/path/system.img \
    --expected-sha256 <64-hex-sha> \
    --artifact-logical-bytes <bytes> \
    --system-current-bytes <bytes> \
    --restore-report /path/report.txt \
    --bootloader-preflight /path/report.txt \
    --fastbootd-preflight /path/report.txt \
    --snapshot-update-status none \
    --lp-action direct-flash|reviewed-resize \
    --avb-action <reviewed action> \
    --userdata-policy preserve|explicit-wipe-approved \
    --explicit-titan-serial REQUIRED \
    --active-slot a|b \
    --stock-baseline <id> \
    --restore-path-verified YES \
    --evidence-dir /path/evidence
EOF
}

fail() {
  printf '%s\n' "$1"
  exit "${2:-1}"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --release) RELEASE="$2"; shift 2 ;;
    --build-source) BUILD_SOURCE="$2"; shift 2 ;;
    --artifact-kind) ARTIFACT_KIND="$2"; shift 2 ;;
    --system-img) SYSTEM_IMG="$2"; shift 2 ;;
    --expected-sha256) EXPECTED_SHA256="$2"; shift 2 ;;
    --artifact-logical-bytes) ARTIFACT_LOGICAL_BYTES="$2"; shift 2 ;;
    --system-current-bytes) SYSTEM_CURRENT_BYTES="$2"; shift 2 ;;
    --restore-report) RESTORE_REPORT="$2"; shift 2 ;;
    --bootloader-preflight) BOOTLOADER_PREFLIGHT="$2"; shift 2 ;;
    --fastbootd-preflight) FASTBOOTD_PREFLIGHT="$2"; shift 2 ;;
    --snapshot-update-status) SNAPSHOT_UPDATE_STATUS="$2"; shift 2 ;;
    --lp-action) LP_ACTION="$2"; shift 2 ;;
    --avb-action) AVB_ACTION="$2"; shift 2 ;;
    --userdata-policy) USERDATA_POLICY="$2"; shift 2 ;;
    --explicit-titan-serial) EXPLICIT_TITAN_SERIAL="$2"; shift 2 ;;
    --active-slot) ACTIVE_SLOT="$2"; shift 2 ;;
    --stock-baseline) STOCK_BASELINE="$2"; shift 2 ;;
    --restore-path-verified) RESTORE_PATH_VERIFIED="$2"; shift 2 ;;
    --evidence-dir) EVIDENCE_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage; exit 64 ;;
  esac
done

echo "===== TITAN2 N0/N1 FLASH PLAN PREPARATION ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "IMAGE_BUILD_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "ADB_COMMANDS_RUN=NO"
echo "FASTBOOT_COMMANDS_RUN=NO"
echo "WRITE_CAPABLE_SCRIPT_CREATED=NO"

case "$RELEASE" in
  N0|N0_A16|N1|N1B|n0|n0_a16|n1|n1b) ;;
  *) fail "TITAN2_FLASH_PLAN=FAIL_RELEASE release=$RELEASE" 64 ;;
esac

[ "$ARTIFACT_KIND" = "gsi-system-image" ] ||
  fail "TITAN2_FLASH_PLAN=FAIL_ARTIFACT_KIND kind=$ARTIFACT_KIND" 64

case "$BUILD_SOURCE" in
  [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
  *) fail "TITAN2_FLASH_PLAN=FAIL_BUILD_SOURCE" 64 ;;
esac

case "$EXPECTED_SHA256" in
  [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
  *) fail "TITAN2_FLASH_PLAN=FAIL_EXPECTED_SHA256" 64 ;;
esac

[ -f "$SYSTEM_IMG" ] || fail "TITAN2_FLASH_PLAN=FAIL_SYSTEM_IMG_MISSING path=$SYSTEM_IMG" 66
ACTUAL_SHA256="$(sha256sum "$SYSTEM_IMG" | awk '{print $1}')"
echo "ARTIFACT_SHA256=$ACTUAL_SHA256"
[ "$ACTUAL_SHA256" = "$EXPECTED_SHA256" ] ||
  fail "TITAN2_FLASH_PLAN=FAIL_SYSTEM_IMG_SHA256" 66

case "$ARTIFACT_LOGICAL_BYTES" in ''|*[!0-9]*) fail "TITAN2_FLASH_PLAN=FAIL_ARTIFACT_LOGICAL_BYTES" 64 ;; esac
case "$SYSTEM_CURRENT_BYTES" in ''|*[!0-9]*) fail "TITAN2_FLASH_PLAN=FAIL_SYSTEM_CURRENT_BYTES" 64 ;; esac

[ "$RESTORE_REPORT" != "" ] && [ -f "$RESTORE_REPORT" ] ||
  fail "TITAN2_FLASH_PLAN=FAIL_RESTORE_REPORT" 66
[ "$BOOTLOADER_PREFLIGHT" != "" ] && [ -f "$BOOTLOADER_PREFLIGHT" ] ||
  fail "TITAN2_FLASH_PLAN=FAIL_BOOTLOADER_PREFLIGHT" 66
[ "$FASTBOOTD_PREFLIGHT" != "" ] && [ -f "$FASTBOOTD_PREFLIGHT" ] ||
  fail "TITAN2_FLASH_PLAN=FAIL_FASTBOOTD_PREFLIGHT" 66

[ "$SNAPSHOT_UPDATE_STATUS" = "none" ] ||
  fail "TITAN2_FLASH_PLAN=FAIL_SNAPSHOT_UPDATE_STATUS value=$SNAPSHOT_UPDATE_STATUS" 66

case "$LP_ACTION" in
  direct-flash|reviewed-resize) ;;
  *) fail "TITAN2_FLASH_PLAN=FAIL_LP_ACTION value=$LP_ACTION" 64 ;;
esac

[ "$AVB_ACTION" != "" ] ||
  fail "TITAN2_FLASH_PLAN=FAIL_AVB_ACTION" 64

case "$USERDATA_POLICY" in
  preserve|explicit-wipe-approved) ;;
  *) fail "TITAN2_FLASH_PLAN=FAIL_USERDATA_POLICY value=$USERDATA_POLICY" 64 ;;
esac

[ "$EXPLICIT_TITAN_SERIAL" = "REQUIRED" ] ||
  fail "TITAN2_FLASH_PLAN=FAIL_EXPLICIT_TITAN_SERIAL value=$EXPLICIT_TITAN_SERIAL" 64

case "$ACTIVE_SLOT" in
  a|b) ;;
  *) fail "TITAN2_FLASH_PLAN=FAIL_ACTIVE_SLOT value=$ACTIVE_SLOT" 64 ;;
esac

[ "$STOCK_BASELINE" != "" ] ||
  fail "TITAN2_FLASH_PLAN=FAIL_STOCK_BASELINE" 64
[ "$RESTORE_PATH_VERIFIED" = "YES" ] ||
  fail "TITAN2_FLASH_PLAN=FAIL_RESTORE_PATH_VERIFIED value=$RESTORE_PATH_VERIFIED" 64

if [ "$ARTIFACT_LOGICAL_BYTES" -gt "$SYSTEM_CURRENT_BYTES" ] && [ "$LP_ACTION" != "reviewed-resize" ]; then
  fail "TITAN2_FLASH_PLAN=FAIL_LP_FIT_REQUIRES_REVIEWED_RESIZE" 66
fi

[ "$EVIDENCE_DIR" != "" ] || fail "TITAN2_FLASH_PLAN=FAIL_EVIDENCE_DIR" 64
mkdir -p "$EVIDENCE_DIR" || fail "TITAN2_FLASH_PLAN=FAIL_EVIDENCE_DIR_CREATE" 66

PLAN="$EVIDENCE_DIR/titan2-n0-n1-flash-plan.txt"
{
  echo "TITAN2_N0_N1_FLASH_PLAN=PREPARED_NO_WRITE"
  echo "RELEASE=$RELEASE"
  echo "BUILD_SOURCE=$BUILD_SOURCE"
  echo "ARTIFACT_KIND=$ARTIFACT_KIND"
  echo "SYSTEM_IMG=$SYSTEM_IMG"
  echo "ARTIFACT_SHA256=$ACTUAL_SHA256"
  echo "ARTIFACT_LOGICAL_BYTES=$ARTIFACT_LOGICAL_BYTES"
  echo "SYSTEM_CURRENT_BYTES=$SYSTEM_CURRENT_BYTES"
  echo "RESTORE_REPORT=$RESTORE_REPORT"
  echo "BOOTLOADER_PREFLIGHT=$BOOTLOADER_PREFLIGHT"
  echo "FASTBOOTD_PREFLIGHT=$FASTBOOTD_PREFLIGHT"
  echo "SNAPSHOT_UPDATE_STATUS=$SNAPSHOT_UPDATE_STATUS"
  echo "LP_ACTION=$LP_ACTION"
  echo "AVB_ACTION=$AVB_ACTION"
  echo "USERDATA_POLICY=$USERDATA_POLICY"
  echo "EXPLICIT_TITAN_SERIAL=$EXPLICIT_TITAN_SERIAL"
  echo "ACTIVE_SLOT=$ACTIVE_SLOT"
  echo "STOCK_BASELINE=$STOCK_BASELINE"
  echo "RESTORE_PATH_VERIFIED=$RESTORE_PATH_VERIFIED"
  echo "FASTBOOT_BOOT=UNSUPPORTED"
  echo "DSU=UNAVAILABLE_ON_TESTED_STOCK_BUILD"
  echo "WRITE_CAPABLE_SCRIPT_CREATED=NO"
  echo "FLASH_AUTHORIZED=NO"
} > "$PLAN" || fail "TITAN2_FLASH_PLAN=FAIL_WRITE_PLAN" 66

(
  cd "$EVIDENCE_DIR" || exit 1
  find . -type f ! -name SHA256SUMS.txt -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > SHA256SUMS.txt
) || fail "TITAN2_FLASH_PLAN=FAIL_SEAL" 66

echo "FLASH_PLAN=$PLAN"
echo "EVIDENCE_SEAL_SHA256=$(sha256sum "$EVIDENCE_DIR/SHA256SUMS.txt" | awk '{print $1}')"
echo "TITAN2_FLASH_PLAN=PASS_PREPARED_NO_WRITE"
