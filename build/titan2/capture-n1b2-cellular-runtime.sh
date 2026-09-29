#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  build/titan2/capture-n1b2-cellular-runtime.sh --label LABEL [options]

Required:
  --label LABEL             n1b1, n1b2, or stock.

Options:
  --serial SERIAL           adb serial to target a specific device.
  --evidence-dir DIR        Output directory. Default: /tmp/SABLE_N1B2_CELLULAR_RUNTIME_<label>_<UTC>.
  --duration SECONDS        Logcat capture duration. Default: 180.
  --transition-note TEXT    Optional operator note.

Android mode with adb is required. Do not use fastboot or fastbootd for PR 207
runtime capture. This script is read-only: it does not change settings, toggle
radios, reboot, root, remount, install packages, build images, or flash.
USAGE
}

LABEL=""
SERIAL="${ADB_SERIAL:-}"
DURATION="${DURATION:-180}"
EVIDENCE_DIR=""
TRANSITION_NOTE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --label)
      LABEL="$2"
      shift 2
      ;;
    --serial)
      SERIAL="$2"
      shift 2
      ;;
    --evidence-dir)
      EVIDENCE_DIR="$2"
      shift 2
      ;;
    --duration)
      DURATION="$2"
      shift 2
      ;;
    --transition-note)
      TRANSITION_NOTE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "UNKNOWN_ARG=$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$LABEL" ]]; then
  echo "LABEL_REQUIRED=FAIL" >&2
  usage >&2
  exit 2
fi

case "$LABEL" in
  n1b1|n1b2|stock) ;;
  *)
    echo "LABEL_INVALID=FAIL label=$LABEL expected=n1b1,n1b2,stock" >&2
    exit 2
    ;;
esac

if [[ ! "$DURATION" =~ ^[0-9]+$ || "$DURATION" -lt 1 ]]; then
  echo "DURATION_INVALID=FAIL duration=$DURATION" >&2
  exit 2
fi

if [[ -z "$EVIDENCE_DIR" ]]; then
  EVIDENCE_DIR="/tmp/SABLE_N1B2_CELLULAR_RUNTIME_${LABEL}_$(date -u +%Y%m%dT%H%M%SZ)"
fi

mkdir -p "$EVIDENCE_DIR" "$EVIDENCE_DIR/adb-shell" "$EVIDENCE_DIR/logcat"
MARKERS="$EVIDENCE_DIR/runtime-markers.txt"
COMMANDS="$EVIDENCE_DIR/commands.tsv"
: > "$MARKERS"
printf 'label\tcommand\toutput\tstatus\n' > "$COMMANDS"

ADB=(adb)
if [[ -n "$SERIAL" ]]; then
  ADB=(adb -s "$SERIAL")
fi

run_host() {
  local label="$1"
  local output="$2"
  shift 2
  echo "RUN_HOST=$label output=$output"
  if "$@" > "$output" 2>&1; then
    printf '%s\t%s\t%s\tPASS\n' "$LABEL" "$label" "$output" >> "$COMMANDS"
    echo "N1B2_CELLULAR_RUNTIME_${label}=PASS output=$output" >> "$MARKERS"
  else
    printf '%s\t%s\t%s\tWARN\n' "$LABEL" "$label" "$output" >> "$COMMANDS"
    echo "N1B2_CELLULAR_RUNTIME_${label}=WARN output=$output" >> "$MARKERS"
  fi
}

run_shell() {
  local label="$1"
  local output="$2"
  shift 2
  echo "RUN_ADB_SHELL=$label output=$output"
  if "${ADB[@]}" shell "$@" > "$output" 2>&1; then
    printf '%s\tadb shell %s\t%s\tPASS\n' "$LABEL" "$*" "$output" >> "$COMMANDS"
    echo "N1B2_CELLULAR_RUNTIME_${label}=PASS output=$output" >> "$MARKERS"
  else
    printf '%s\tadb shell %s\t%s\tWARN\n' "$LABEL" "$*" "$output" >> "$COMMANDS"
    echo "N1B2_CELLULAR_RUNTIME_${label}=WARN output=$output" >> "$MARKERS"
  fi
}

echo "===== N1B2 CELLULAR RUNTIME CAPTURE ====="
echo "LABEL=$LABEL"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "ANDROID_MODE_REQUIRED=YES"
echo "ADB_USED=YES"
echo "FASTBOOT_USED=NO"
echo "FASTBOOTD_USED=NO"
echo "SETTINGS_MUTATION=NO"
echo "RADIO_TOGGLE=NO"
echo "REBOOT=NO"
echo "ROOT_REQUIRED=NO"
echo "IMAGE_BUILD=NO"
echo "FLASH_ENABLEMENT=NO"

echo "N1B2_CELLULAR_RUNTIME_CAPTURE_LABEL=$LABEL" >> "$MARKERS"
echo "N1B2_CELLULAR_RUNTIME_ANDROID_MODE_REQUIRED=YES" >> "$MARKERS"
echo "N1B2_CELLULAR_RUNTIME_READ_ONLY=YES" >> "$MARKERS"
echo "N1B2_CELLULAR_RUNTIME_FASTBOOT_USED=NO" >> "$MARKERS"
echo "N1B2_CELLULAR_RUNTIME_FASTBOOTD_USED=NO" >> "$MARKERS"
echo "TRANSITION_NOTE=$TRANSITION_NOTE" > "$EVIDENCE_DIR/transition-note.txt"

run_host "ADB_DEVICES" "$EVIDENCE_DIR/adb-devices.txt" "${ADB[@]}" devices -l
run_host "ADB_GET_STATE" "$EVIDENCE_DIR/adb-state.txt" "${ADB[@]}" get-state
run_host "ADB_WAIT_FOR_DEVICE" "$EVIDENCE_DIR/adb-wait-for-device.txt" "${ADB[@]}" wait-for-device

run_shell "GETPROP_FULL" "$EVIDENCE_DIR/adb-shell/getprop.txt" getprop
run_shell "SERVICE_LIST" "$EVIDENCE_DIR/adb-shell/service-list.txt" service list
run_shell "LSHAL" "$EVIDENCE_DIR/adb-shell/lshal.txt" lshal
run_shell "PM_TELEPHONY_PACKAGES" "$EVIDENCE_DIR/adb-shell/pm-telephony-packages.txt" sh -c "pm list packages -f | grep -Ei 'tele|phone|carrier|cell|stk|euicc|lpa|ims|rcs|mms|mbms|telecom' || true"
run_shell "DUMPSYS_TELEPHONY_REGISTRY" "$EVIDENCE_DIR/adb-shell/dumpsys-telephony-registry.txt" dumpsys telephony.registry
run_shell "DUMPSYS_PHONE" "$EVIDENCE_DIR/adb-shell/dumpsys-phone.txt" dumpsys phone
run_shell "DUMPSYS_ISUB" "$EVIDENCE_DIR/adb-shell/dumpsys-isub.txt" dumpsys isub
run_shell "DUMPSYS_CARRIER_CONFIG" "$EVIDENCE_DIR/adb-shell/dumpsys-carrier-config.txt" dumpsys carrier_config
run_shell "DUMPSYS_CONNECTIVITY" "$EVIDENCE_DIR/adb-shell/dumpsys-connectivity.txt" dumpsys connectivity
run_shell "DUMPSYS_TELECOM" "$EVIDENCE_DIR/adb-shell/dumpsys-telecom.txt" dumpsys telecom
run_shell "DUMPSYS_ACTIVITY_PROCESSES" "$EVIDENCE_DIR/adb-shell/dumpsys-activity-processes.txt" dumpsys activity processes
run_shell "GLOBAL_MOBILE_DATA" "$EVIDENCE_DIR/adb-shell/settings-global-mobile-data.txt" settings get global mobile_data
run_shell "GLOBAL_AIRPLANE_MODE" "$EVIDENCE_DIR/adb-shell/settings-global-airplane-mode.txt" settings get global airplane_mode_on
run_shell "GLOBAL_DEVICE_PROVISIONED" "$EVIDENCE_DIR/adb-shell/settings-global-device-provisioned.txt" settings get global device_provisioned
run_shell "DMESG_RADIO_DENIALS" "$EVIDENCE_DIR/adb-shell/dmesg-radio-denials.txt" sh -c "dmesg 2>/dev/null | grep -Ei 'avc|denied|radio|ril|ims|phone' || true"

run_host "LOGCAT_DUMP_RADIO_MAIN_SYSTEM_CRASH_EVENTS" \
  "$EVIDENCE_DIR/logcat/logcat-current.txt" \
  "${ADB[@]}" logcat -b radio -b main -b system -b crash -b events -d -v threadtime

run_host "LOGCAT_TIMED_WINDOW" \
  "$EVIDENCE_DIR/logcat/logcat-window-${DURATION}s.txt" \
  timeout "$DURATION" "${ADB[@]}" logcat -b radio -b main -b system -b crash -b events -v threadtime

cat > "$EVIDENCE_DIR/README.txt" <<EOF
N1B2 cellular runtime capture evidence

Label: $LABEL
Duration: ${DURATION}s
Transition note: $TRANSITION_NOTE

Android mode is required for PR 207. Do not use fastboot or fastbootd unless a
later approved task explicitly asks for image/partition extraction.

This script is read-only. It does not change settings, toggle radios, reboot,
root, remount, install packages, build images, or flash.
EOF

echo "N1B2_CELLULAR_RUNTIME_CAPTURE=PASS evidence_dir=$EVIDENCE_DIR" | tee -a "$MARKERS"
echo "COMMANDS=$COMMANDS"
echo "MARKERS=$MARKERS"
