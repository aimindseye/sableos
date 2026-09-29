#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  build/titan2/capture-n1b2-cellular-runtime.sh --label LABEL [options]

Required:
  --label LABEL             n1b1, n1b2, or stock.

Options:
  --mode MODE               snapshot or transition. Default: snapshot.
  --snapshot-only           Alias for --mode snapshot.
  --transition              Alias for --mode transition.
  --serial SERIAL           adb serial to target a specific device.
  --evidence-dir DIR        Output directory. Default: /tmp/SABLE_N1B2_CELLULAR_RUNTIME_<label>_<UTC>.
  --duration SECONDS        Transition logcat duration. Default: 180. Used only in transition mode.
  --command-timeout SECONDS Per-command timeout for adb shell/dumpsys reads. Default: 60.
  --transition-note TEXT    Optional operator note.

Capture modes:
  snapshot    Use this when the device is already in the failing/no-cellular state.
              It collects dumpsys/getprop/package/current-logcat evidence and exits.

  transition  Use this immediately after a manual reboot, as soon as adb is online,
              or while the cellular connect->disconnect transition is happening.
              It adds a timed logcat window controlled by --duration.

Android mode with adb is required. Do not use fastboot or fastbootd for PR 207
runtime capture. This script is read-only: it does not change settings, toggle
radios, reboot, root, remount, install packages, build images, or flash.
USAGE
}

LABEL=""
CAPTURE_MODE="${CAPTURE_MODE:-snapshot}"
SERIAL="${ADB_SERIAL:-}"
DURATION="${DURATION:-180}"
COMMAND_TIMEOUT="${COMMAND_TIMEOUT:-60}"
EVIDENCE_DIR=""
TRANSITION_NOTE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --label)
      if [[ $# -lt 2 ]]; then
        echo "ARG_VALUE_REQUIRED=--label" >&2
        exit 2
      fi
      LABEL="$2"
      shift 2
      ;;
    --label=*)
      LABEL="${1#*=}"
      shift
      ;;
    --mode)
      if [[ $# -lt 2 ]]; then
        echo "ARG_VALUE_REQUIRED=--mode" >&2
        exit 2
      fi
      CAPTURE_MODE="$2"
      shift 2
      ;;
    --mode=*)
      CAPTURE_MODE="${1#*=}"
      shift
      ;;
    --snapshot-only)
      CAPTURE_MODE="snapshot"
      shift
      ;;
    --transition)
      CAPTURE_MODE="transition"
      shift
      ;;
    --serial)
      if [[ $# -lt 2 ]]; then
        echo "ARG_VALUE_REQUIRED=--serial" >&2
        exit 2
      fi
      SERIAL="$2"
      shift 2
      ;;
    --serial=*)
      SERIAL="${1#*=}"
      shift
      ;;
    --evidence-dir)
      if [[ $# -lt 2 ]]; then
        echo "ARG_VALUE_REQUIRED=--evidence-dir" >&2
        exit 2
      fi
      EVIDENCE_DIR="$2"
      shift 2
      ;;
    --evidence-dir=*)
      EVIDENCE_DIR="${1#*=}"
      shift
      ;;
    --duration)
      if [[ $# -lt 2 ]]; then
        echo "ARG_VALUE_REQUIRED=--duration" >&2
        exit 2
      fi
      DURATION="$2"
      shift 2
      ;;
    --duration=*)
      DURATION="${1#*=}"
      shift
      ;;
    --command-timeout)
      if [[ $# -lt 2 ]]; then
        echo "ARG_VALUE_REQUIRED=--command-timeout" >&2
        exit 2
      fi
      COMMAND_TIMEOUT="$2"
      shift 2
      ;;
    --command-timeout=*)
      COMMAND_TIMEOUT="${1#*=}"
      shift
      ;;
    --transition-note)
      if [[ $# -lt 2 ]]; then
        echo "ARG_VALUE_REQUIRED=--transition-note" >&2
        exit 2
      fi
      TRANSITION_NOTE="$2"
      shift 2
      ;;
    --transition-note=*)
      TRANSITION_NOTE="${1#*=}"
      shift
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

case "$CAPTURE_MODE" in
  snapshot|transition) ;;
  *)
    echo "CAPTURE_MODE_INVALID=FAIL mode=$CAPTURE_MODE expected=snapshot,transition" >&2
    exit 2
    ;;
esac

if [[ ! "$DURATION" =~ ^[0-9]+$ || "$DURATION" -lt 1 ]]; then
  echo "DURATION_INVALID=FAIL duration=$DURATION" >&2
  exit 2
fi

if [[ ! "$COMMAND_TIMEOUT" =~ ^[0-9]+$ || "$COMMAND_TIMEOUT" -lt 1 ]]; then
  echo "COMMAND_TIMEOUT_INVALID=FAIL command_timeout=$COMMAND_TIMEOUT" >&2
  exit 2
fi

if [[ -z "$EVIDENCE_DIR" ]]; then
  EVIDENCE_DIR="/tmp/SABLE_N1B2_CELLULAR_RUNTIME_${LABEL}_${CAPTURE_MODE}_$(date -u +%Y%m%dT%H%M%SZ)"
fi

mkdir -p "$EVIDENCE_DIR" "$EVIDENCE_DIR/adb-shell" "$EVIDENCE_DIR/logcat"
MARKERS="$EVIDENCE_DIR/runtime-markers.txt"
COMMANDS="$EVIDENCE_DIR/commands.tsv"
: > "$MARKERS"
printf 'label\tmode\tcommand\toutput\tstatus\n' > "$COMMANDS"

ADB=(adb)
if [[ -n "$SERIAL" ]]; then
  ADB=(adb -s "$SERIAL")
fi

record_command() {
  local command="$1"
  local output="$2"
  local status="$3"
  printf '%s\t%s\t%s\t%s\t%s\n' "$LABEL" "$CAPTURE_MODE" "$command" "$output" "$status" >> "$COMMANDS"
  echo "N1B2_CELLULAR_RUNTIME_${command}=\$status output=$output" >> "$MARKERS"
}

run_host() {
  local label="$1"
  local output="$2"
  shift 2
  echo "RUN_HOST=$label output=$output"
  if [[ "$label" == "LOGCAT_TIMED_WINDOW" ]]; then
    if "$@" > "$output" 2>&1; then
      record_command "$label" "$output" "PASS"
    else
      record_command "$label" "$output" "WARN"
    fi
    return 0
  fi

  if timeout "$COMMAND_TIMEOUT" "$@" > "$output" 2>&1; then
    record_command "$label" "$output" "PASS"
  else
    record_command "$label" "$output" "WARN"
  fi
}

run_shell() {
  local label="$1"
  local output="$2"
  shift 2
  echo "RUN_ADB_SHELL=$label output=$output"
  if timeout "$COMMAND_TIMEOUT" "${ADB[@]}" shell "$@" > "$output" 2>&1; then
    record_command "adb shell $*" "$output" "PASS"
  else
    record_command "adb shell $*" "$output" "WARN"
  fi
}

echo "===== N1B2 CELLULAR RUNTIME CAPTURE ====="
echo "LABEL=$LABEL"
echo "CAPTURE_MODE=$CAPTURE_MODE"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "ANDROID_MODE_REQUIRED=YES"
echo "ADB_USED=YES"
echo "FASTBOOT_USED=NO"
echo "FASTBOOTD_USED=NO"
echo "COMMAND_TIMEOUT=$COMMAND_TIMEOUT"
echo "SETTINGS_MUTATION=NO"
echo "RADIO_TOGGLE=NO"
echo "REBOOT=NO"
echo "ROOT_REQUIRED=NO"
echo "IMAGE_BUILD=NO"
echo "FLASH_ENABLEMENT=NO"

echo "N1B2_CELLULAR_RUNTIME_CAPTURE_LABEL=$LABEL" >> "$MARKERS"
echo "N1B2_CELLULAR_RUNTIME_CAPTURE_MODE=$CAPTURE_MODE" >> "$MARKERS"
echo "N1B2_CELLULAR_RUNTIME_ANDROID_MODE_REQUIRED=YES" >> "$MARKERS"
echo "N1B2_CELLULAR_RUNTIME_READ_ONLY=YES" >> "$MARKERS"
echo "N1B2_CELLULAR_RUNTIME_FASTBOOT_USED=NO" >> "$MARKERS"
echo "N1B2_CELLULAR_RUNTIME_FASTBOOTD_USED=NO" >> "$MARKERS"
echo "N1B2_CELLULAR_RUNTIME_COMMAND_TIMEOUT=$COMMAND_TIMEOUT" >> "$MARKERS"
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

if [[ "$CAPTURE_MODE" == "transition" ]]; then
  run_host "LOGCAT_TIMED_WINDOW" \
    "$EVIDENCE_DIR/logcat/logcat-window-${DURATION}s.txt" \
    timeout "$DURATION" "${ADB[@]}" logcat -b radio -b main -b system -b crash -b events -v threadtime
else
  skipped="$EVIDENCE_DIR/logcat/logcat-window-skipped-snapshot-mode.txt"
  cat > "$skipped" <<EOF
Timed logcat window skipped because CAPTURE_MODE=snapshot.
Use --mode transition immediately after a manual reboot or during the
cellular connect->disconnect transition when a long observation window is needed.
EOF
  record_command "LOGCAT_TIMED_WINDOW_SKIPPED" "$skipped" "PASS"
fi

cat > "$EVIDENCE_DIR/README.txt" <<EOF
N1B2 cellular runtime capture evidence

Label: $LABEL
Capture mode: $CAPTURE_MODE
Duration: ${DURATION}s, used only in transition mode
Command timeout: ${COMMAND_TIMEOUT}s
Transition note: $TRANSITION_NOTE

Use snapshot mode when the device is already in the failing/no-cellular state.
Use transition mode immediately after a manual reboot, as soon as adb is online,
or while the cellular connect->disconnect transition is happening.

Android mode is required for PR 207. Do not use fastboot or fastbootd unless a
later approved task explicitly asks for image/partition extraction.

This script is read-only. It does not change settings, toggle radios, reboot,
root, remount, install packages, build images, or flash.
EOF

echo "N1B2_CELLULAR_RUNTIME_CAPTURE=PASS evidence_dir=$EVIDENCE_DIR" | tee -a "$MARKERS"
echo "COMMANDS=$COMMANDS"
echo "MARKERS=$MARKERS"
