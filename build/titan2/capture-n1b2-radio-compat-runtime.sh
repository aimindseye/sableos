#!/usr/bin/env bash
set -euo pipefail

LABEL="${LABEL:-n1b2-radio-compat-r1}"
EVIDENCE_DIR="${EVIDENCE_DIR:-/tmp/SABLE_N1B2_RADIO_COMPAT_R1_$(date -u +%Y%m%dT%H%M%SZ)}"
ADB_BIN="${ADB:-adb}"
COMMAND_TIMEOUT_SECONDS="${COMMAND_TIMEOUT_SECONDS:-45}"
LOGCAT_TIMEOUT_SECONDS="${LOGCAT_TIMEOUT_SECONDS:-60}"
BOOT_WAIT_TIMEOUT_SECONDS="${BOOT_WAIT_TIMEOUT_SECONDS:-120}"

usage() {
  cat <<'EOF'
Usage: build/titan2/capture-n1b2-radio-compat-runtime.sh [options]

Options:
  --evidence-dir PATH          Directory for captured evidence.
  --label LABEL                Capture label; default n1b2-radio-compat-r1.
  --command-timeout SECONDS    Timeout for each adb shell capture; default 45.
  --logcat-timeout SECONDS     Timeout for adb logcat -d; default 60.
  --boot-wait-timeout SECONDS  Timeout for adb wait-for-device; default 120.
  -h, --help                   Show this help.

Safety boundaries:
  - Captures only runtime state from an already-booted device.
  - Does not flash, reboot, remount, root, clear logcat, toggle radio, or mutate settings.
  - Summary grep is limited to explicit files written under this evidence directory.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --evidence-dir)
      EVIDENCE_DIR="$2"
      shift 2
      ;;
    --evidence-dir=*)
      EVIDENCE_DIR="${1#*=}"
      shift
      ;;
    --label)
      LABEL="$2"
      shift 2
      ;;
    --label=*)
      LABEL="${1#*=}"
      shift
      ;;
    --command-timeout)
      COMMAND_TIMEOUT_SECONDS="$2"
      shift 2
      ;;
    --command-timeout=*)
      COMMAND_TIMEOUT_SECONDS="${1#*=}"
      shift
      ;;
    --logcat-timeout)
      LOGCAT_TIMEOUT_SECONDS="$2"
      shift 2
      ;;
    --logcat-timeout=*)
      LOGCAT_TIMEOUT_SECONDS="${1#*=}"
      shift
      ;;
    --boot-wait-timeout)
      BOOT_WAIT_TIMEOUT_SECONDS="$2"
      shift 2
      ;;
    --boot-wait-timeout=*)
      BOOT_WAIT_TIMEOUT_SECONDS="${1#*=}"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "UNKNOWN_ARG=$1" >&2
      exit 2
      ;;
  esac
done

case "$COMMAND_TIMEOUT_SECONDS" in
  ''|*[!0-9]*) echo "COMMAND_TIMEOUT_SECONDS_INVALID=$COMMAND_TIMEOUT_SECONDS" >&2; exit 2 ;;
esac
case "$LOGCAT_TIMEOUT_SECONDS" in
  ''|*[!0-9]*) echo "LOGCAT_TIMEOUT_SECONDS_INVALID=$LOGCAT_TIMEOUT_SECONDS" >&2; exit 2 ;;
esac
case "$BOOT_WAIT_TIMEOUT_SECONDS" in
  ''|*[!0-9]*) echo "BOOT_WAIT_TIMEOUT_SECONDS_INVALID=$BOOT_WAIT_TIMEOUT_SECONDS" >&2; exit 2 ;;
esac

if ! command -v timeout >/dev/null 2>&1; then
  echo "N1B2_RADIO_COMPAT_CAPTURE=FAIL reason=missing_timeout_binary" >&2
  exit 1
fi

if ! command -v "$ADB_BIN" >/dev/null 2>&1; then
  echo "N1B2_RADIO_COMPAT_CAPTURE=FAIL reason=missing_adb adb=$ADB_BIN" >&2
  exit 1
fi

mkdir -p "$EVIDENCE_DIR" "$EVIDENCE_DIR/raw" "$EVIDENCE_DIR/summary"
RAW_DIR="$EVIDENCE_DIR/raw"
SUMMARY_DIR="$EVIDENCE_DIR/summary"
WARNINGS_FILE="$SUMMARY_DIR/capture-warnings.txt"
MARKERS_FILE="$SUMMARY_DIR/markers.txt"
: >"$WARNINGS_FILE"

adb_cmd=("$ADB_BIN")
if [[ -n "${ANDROID_SERIAL:-}" ]]; then
  adb_cmd+=("-s" "$ANDROID_SERIAL")
fi

run_capture() {
  local name="$1"
  local seconds="$2"
  shift 2
  local output="$RAW_DIR/$name.txt"
  if timeout "$seconds" "${adb_cmd[@]}" "$@" >"$output" 2>&1; then
    echo "CAPTURE_PASS name=$name output=$output" >>"$WARNINGS_FILE"
  else
    local rc=$?
    echo "CAPTURE_WARN name=$name rc=$rc output=$output" >>"$WARNINGS_FILE"
  fi
}

run_shell_capture() {
  local name="$1"
  shift
  run_capture "$name" "$COMMAND_TIMEOUT_SECONDS" shell "$@"
}

{
  echo "===== N1B2 RADIO COMPAT R1 RUNTIME CAPTURE ====="
  echo "LABEL=$LABEL"
  echo "EVIDENCE_DIR=$EVIDENCE_DIR"
  echo "DEVICE_CONTACT_AUTHORIZED=YES"
  echo "FLASH_AUTHORIZED=NO"
  echo "FASTBOOT_AUTHORIZED=NO"
  echo "ADB_ROOT_AUTHORIZED=NO"
  echo "RADIO_TOGGLE_AUTHORIZED=NO"
  echo "SETTINGS_MUTATION_AUTHORIZED=NO"
  echo "LOGCAT_CLEAR_AUTHORIZED=NO"
  echo "COMMAND_TIMEOUT_SECONDS=$COMMAND_TIMEOUT_SECONDS"
  echo "LOGCAT_TIMEOUT_SECONDS=$LOGCAT_TIMEOUT_SECONDS"
  echo "BOOT_WAIT_TIMEOUT_SECONDS=$BOOT_WAIT_TIMEOUT_SECONDS"
} | tee "$MARKERS_FILE"

if timeout "$BOOT_WAIT_TIMEOUT_SECONDS" "${adb_cmd[@]}" wait-for-device >>"$WARNINGS_FILE" 2>&1; then
  echo "N1B2_RADIO_COMPAT_ADB_WAIT=PASS" | tee -a "$MARKERS_FILE"
else
  echo "N1B2_RADIO_COMPAT_ADB_WAIT=FAIL" | tee -a "$MARKERS_FILE"
  exit 1
fi

boot_completed="$(timeout "$COMMAND_TIMEOUT_SECONDS" "${adb_cmd[@]}" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
dev_bootcomplete="$(timeout "$COMMAND_TIMEOUT_SECONDS" "${adb_cmd[@]}" shell getprop dev.bootcomplete 2>/dev/null | tr -d '\r' || true)"
echo "SYS_BOOT_COMPLETED=$boot_completed" | tee -a "$MARKERS_FILE"
echo "DEV_BOOTCOMPLETE=$dev_bootcomplete" | tee -a "$MARKERS_FILE"

run_shell_capture getprop getprop
run_shell_capture service-list service list
run_shell_capture packages-all cmd package list packages -f
run_shell_capture packages-ims cmd package list packages -f -i com.mediatek.ims
run_shell_capture overlays cmd overlay list
run_shell_capture ps ps -A
run_shell_capture lshal lshal
run_shell_capture dumpsys-isub dumpsys isub
run_shell_capture dumpsys-carrier-config dumpsys carrier_config
run_shell_capture dumpsys-phone dumpsys phone
run_shell_capture dumpsys-telephony-registry dumpsys telephony.registry
run_shell_capture dumpsys-connectivity dumpsys connectivity
run_shell_capture dumpsys-ims dumpsys ims
run_shell_capture package-com-android-phone dumpsys package com.android.phone
run_shell_capture package-com-mediatek-ims dumpsys package com.mediatek.ims
run_capture logcat "$LOGCAT_TIMEOUT_SECONDS" logcat -b main -b system -b radio -b events -b crash -d -v threadtime

# Keep summary grep bounded. Do not recurse and do not scan the workspace.
grep_targets=(
  "$RAW_DIR/getprop.txt"
  "$RAW_DIR/service-list.txt"
  "$RAW_DIR/packages-all.txt"
  "$RAW_DIR/packages-ims.txt"
  "$RAW_DIR/overlays.txt"
  "$RAW_DIR/ps.txt"
  "$RAW_DIR/lshal.txt"
  "$RAW_DIR/dumpsys-isub.txt"
  "$RAW_DIR/dumpsys-carrier-config.txt"
  "$RAW_DIR/dumpsys-phone.txt"
  "$RAW_DIR/dumpsys-telephony-registry.txt"
  "$RAW_DIR/dumpsys-connectivity.txt"
  "$RAW_DIR/dumpsys-ims.txt"
  "$RAW_DIR/package-com-android-phone.txt"
  "$RAW_DIR/package-com-mediatek-ims.txt"
  "$RAW_DIR/logcat.txt"
)

summary_grep() {
  local name="$1"
  local pattern="$2"
  local output="$SUMMARY_DIR/$name.txt"
  grep -Eai "$pattern" "${grep_targets[@]}" >"$output" 2>/dev/null || true
}

summary_grep radio-good 'REG_HOME|IN_SERVICE|DataCallResponse: \{ cause=NONE|SETUP_DATA_CALL|CONNECTED, transport: WWAN|ccmni[0-9]|TelephonyDisplayInfo \{network=LTE|overrideNetwork=NR_NSA|registeredPlmn: 310260|rRplmn=310260|mMcc=310 mMnc=260'
summary_grep radio-drop 'ERROR_UNSPECIFIED|UNSOL_DATA_CALL_LIST_CHANGED|DISCONNECTED, transport: WWAN|OUT_OF_SERVICE|NOT_IN_SERVICE|NO_SUITABLE_DATA_PROFILE|SERVICE_OPTION_NOT_SUPPORTED|DATA_CONFIG_NOT_READY|SIM_NOT_READY|reg state=EMERGENCY'
summary_grep mtk-indication 'mtkNetworkIndication == NULL|smartRatSwitchInd|responseCsNetworkStateChangeInd|vendor\.mediatek\.hardware\.radio|IRadio|RILC|RILJ'
summary_grep ims-suspect 'com\.mediatek\.ims|ImsResolver|IMS_SERVICE_DISCONNECTED|NO_IMS_SERVICE_CONFIGURED|IMS_UNSUPPORTED|no ImsService available|registerMmTelCapabilityCallback|registerImsRegistrationCallback|MMTEL|EMERGENCY_MMTEL|RCS'
summary_grep selinux 'avc: denied|SELinux|denied.*vendor\.mediatek\.hardware\.radio|hwservice_manager|service_manager'

count_matches() {
  local pattern="$1"
  grep -Eai "$pattern" "${grep_targets[@]}" 2>/dev/null | wc -l | tr -d ' '
}

good_count="$(count_matches 'REG_HOME|DataCallResponse: \{ cause=NONE|CONNECTED, transport: WWAN|ccmni[0-9]')"
drop_count="$(count_matches 'ERROR_UNSPECIFIED|UNSOL_DATA_CALL_LIST_CHANGED|DISCONNECTED, transport: WWAN')"
mtk_indication_count="$(count_matches 'mtkNetworkIndication == NULL')"
ims_failure_count="$(count_matches 'IMS_SERVICE_DISCONNECTED|NO_IMS_SERVICE_CONFIGURED|IMS_UNSUPPORTED|no ImsService available')"
selinux_count="$(count_matches 'avc: denied|SELinux')"

{
  echo "N1B2_RADIO_COMPAT_CAPTURE_GREP_SCOPE=EXPLICIT_CAPTURE_FILES_ONLY"
  echo "N1B2_RADIO_COMPAT_CAPTURE_RAW_DIR=$RAW_DIR"
  echo "N1B2_RADIO_COMPAT_CAPTURE_SUMMARY_DIR=$SUMMARY_DIR"
  echo "N1B2_RADIO_COMPAT_GOOD_SIGNAL_COUNT=$good_count"
  echo "N1B2_RADIO_COMPAT_DROP_SIGNAL_COUNT=$drop_count"
  echo "N1B2_RADIO_COMPAT_MTK_INDICATION_NULL_COUNT=$mtk_indication_count"
  echo "N1B2_RADIO_COMPAT_IMS_FAILURE_COUNT=$ims_failure_count"
  echo "N1B2_RADIO_COMPAT_SELINUX_SIGNAL_COUNT=$selinux_count"
  echo "N1B2_RADIO_COMPAT_CAPTURE=PASS"
} | tee -a "$MARKERS_FILE"
