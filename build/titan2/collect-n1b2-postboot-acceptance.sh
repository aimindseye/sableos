#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SERIAL="${TITAN_SERIAL:-TITAN20000006073}"
DURATION_SECONDS="600"
ADB="${ADB:-adb}"
TIMESTAMP="$(date -u +%Y%m%d_%H%M%S)"
EVIDENCE_DIR="/srv/data/sable-build/evidence/titan2/n1b2-postboot-acceptance/$TIMESTAMP"

fail() {
  echo "N1B2_POSTBOOT_ACCEPTANCE_FAILURE=$*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage:
  collect-n1b2-postboot-acceptance.sh [--serial <adb-serial>] [--duration-seconds <seconds>] [--evidence-dir <path>]

Read-only post-boot acceptance collector for Titan2 N1B2 after explicit factory
reset. It does not flash, reboot, wipe, or mutate device state.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --serial)
      SERIAL="${2:-}"
      shift 2
      ;;
    --duration-seconds)
      DURATION_SECONDS="${2:-}"
      shift 2
      ;;
    --evidence-dir)
      EVIDENCE_DIR="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

[[ -n "$SERIAL" ]] || fail "serial is required"
[[ "$DURATION_SECONDS" =~ ^[0-9]+$ ]] || fail "duration must be numeric"
(( DURATION_SECONDS >= 60 )) || fail "duration must be at least 60 seconds"

mkdir -p "$EVIDENCE_DIR"
SUMMARY="$EVIDENCE_DIR/n1b2-postboot-acceptance.txt"
RADIO_LOG="$EVIDENCE_DIR/n1b2-radio-timed-capture.txt"
INPUT_LOG="$EVIDENCE_DIR/dumpsys-input.txt"
DISPLAY_LOG="$EVIDENCE_DIR/dumpsys-display.txt"
PACKAGES_LOG="$EVIDENCE_DIR/packages.txt"

adb_shell() {
  "$ADB" -s "$SERIAL" shell "$@"
}

prop() {
  local key="$1"
  adb_shell getprop "$key" 2>/dev/null | tr -d '\r'
}

resolve_home() {
  adb_shell cmd package resolve-activity --brief \
    -a android.intent.action.MAIN \
    -c android.intent.category.HOME 2>/dev/null || true
}

package_audit() {
  adb_shell pm list packages 2>/dev/null | sort || true
}

radio_snapshot() {
  {
    echo "===== RADIO SNAPSHOT $(date -u +%Y-%m-%dT%H:%M:%SZ) ====="
    echo "gsm.operator.alpha=$(prop gsm.operator.alpha)"
    echo "gsm.network.type=$(prop gsm.network.type)"
    echo "gsm.sim.state=$(prop gsm.sim.state)"
    adb_shell dumpsys telephony.registry 2>/dev/null | grep -Ei \
      'mVoiceRegState|mDataRegState|mDataConnectionState|accessNetworkTechnology|availableServices|mSignalStrength|onDataConnectionStateChanged|mActiveDataSubId|mRadioPowerState|rejectCause|nrState' \
      || true
    echo
  } >> "$RADIO_LOG"
}

echo "===== N1B2 POSTBOOT ACCEPTANCE =====" | tee "$SUMMARY"
{
  echo "ROOT=$ROOT"
  echo "EVIDENCE_DIR=$EVIDENCE_DIR"
  echo "TITAN_SERIAL=$SERIAL"
  echo "DURATION_SECONDS=$DURATION_SECONDS"
  echo "DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY_ADB"
  echo "ADB_COMMANDS_AUTHORIZED=YES_READ_ONLY"
  echo "FASTBOOT_COMMANDS_RUN=NO"
  echo "REBOOT_COMMANDS_RUN=NO"
  echo "FLASH_COMMANDS_RUN=NO"
  echo "ERASE_COMMANDS_RUN=NO"
  echo "FACTORY_RESET_COMMANDS_RUN=NO"
  echo "AVB_MUTATION_COMMANDS_RUN=NO"
  echo "PUBLIC_RELEASE=NO"
  echo "PRODUCTION_SIGNING=NO"
  echo
} | tee -a "$SUMMARY"

"$ADB" -s "$SERIAL" wait-for-device

BOOT_COMPLETED="$(prop sys.boot_completed)"
VERIFIED_BOOT="$(prop ro.boot.verifiedbootstate)"
SLOT_SUFFIX="$(prop ro.boot.slot_suffix)"
SYSTEM_FINGERPRINT="$(prop ro.system.build.fingerprint)"
VENDOR_FINGERPRINT="$(prop ro.vendor.build.fingerprint)"
DEVICE_NAME="$(adb_shell settings get global device_name 2>/dev/null | tr -d '\r' || true)"
SYSTEM_NAME="$(prop ro.product.system.name)"
SYSTEM_BRAND="$(prop ro.product.system.brand)"
SYSTEM_MODEL="$(prop ro.product.system.model)"

HOME_RESOLUTION="$(resolve_home | tr '\n' '|' | sed 's/|$//')"
package_audit > "$PACKAGES_LOG"
adb_shell dumpsys input > "$INPUT_LOG" 2>/dev/null || true
adb_shell dumpsys display > "$DISPLAY_LOG" 2>/dev/null || true

SETUP_PACKAGE_STATUS="MISSING"
if grep -Eiq 'setupwizard|provision' "$PACKAGES_LOG"; then
  SETUP_PACKAGE_STATUS="PRESENT"
fi

SABLE_PACKAGE_STATUS="MISSING"
if grep -Eiq 'sable' "$PACKAGES_LOG"; then
  SABLE_PACKAGE_STATUS="PRESENT"
fi

TITANKEY_STATUS="MISSING"
if grep -Eiq 'TitanKey' "$INPUT_LOG"; then
  TITANKEY_STATUS="PRESENT"
fi

TOUCHPAD_STATUS="MISSING"
if grep -Eiq 'touchPad|synaptics_dsx_i2c' "$INPUT_LOG"; then
  TOUCHPAD_STATUS="PRESENT"
fi

PRIMARY_DISPLAY_STATUS="UNKNOWN"
if grep -q '1440' "$DISPLAY_LOG"; then
  PRIMARY_DISPLAY_STATUS="PRESENT_1440"
fi

REAR_DISPLAY_STATUS="UNKNOWN"
if grep -q '410' "$DISPLAY_LOG" && grep -q '502' "$DISPLAY_LOG"; then
  REAR_DISPLAY_STATUS="PRESENT_410x502"
fi

SABLE_HOME_STATUS="UNKNOWN"
if echo "$HOME_RESOLUTION" | grep -Eiq 'sable'; then
  SABLE_HOME_STATUS="PASS_SABLE"
elif echo "$HOME_RESOLUTION" | grep -Eiq 'launcher3|quickstep'; then
  SABLE_HOME_STATUS="FAIL_QUICKSTEP_PRIMARY_HOME"
else
  SABLE_HOME_STATUS="UNKNOWN_HOME"
fi

IDENTITY_STATUS="UNKNOWN"
if [[ "$DEVICE_NAME" == SableOS* ]] || [[ "$SYSTEM_BRAND" == "SableOS" ]]; then
  IDENTITY_STATUS="PASS_SABLE_VISIBLE_IDENTITY"
elif [[ "$DEVICE_NAME" == *TrebleDroid* ]] || [[ "$SYSTEM_FINGERPRINT" == google/treble_* ]]; then
  IDENTITY_STATUS="FAIL_GENERIC_TREBLE_VISIBLE_IDENTITY"
else
  IDENTITY_STATUS="UNKNOWN_IDENTITY"
fi

{
  echo "===== BOOT IDENTITY ====="
  echo "BOOT_COMPLETED=$BOOT_COMPLETED"
  echo "VERIFIED_BOOT_STATE=$VERIFIED_BOOT"
  echo "ACTIVE_SLOT=$SLOT_SUFFIX"
  echo "SYSTEM_FINGERPRINT=$SYSTEM_FINGERPRINT"
  echo "VENDOR_FINGERPRINT=$VENDOR_FINGERPRINT"
  echo "DEVICE_NAME=$DEVICE_NAME"
  echo "SYSTEM_NAME=$SYSTEM_NAME"
  echo "SYSTEM_BRAND=$SYSTEM_BRAND"
  echo "SYSTEM_MODEL=$SYSTEM_MODEL"
  echo
  echo "===== SETUP / HOME / SABLE ====="
  echo "SETUP_PACKAGE_STATUS=$SETUP_PACKAGE_STATUS"
  echo "SABLE_PACKAGE_STATUS=$SABLE_PACKAGE_STATUS"
  echo "HOME_RESOLUTION=$HOME_RESOLUTION"
  echo "SABLE_HOME_STATUS=$SABLE_HOME_STATUS"
  echo "IDENTITY_STATUS=$IDENTITY_STATUS"
  echo
  echo "===== TITAN2 HARDWARE ENUMERATION ====="
  echo "TITANKEY_STATUS=$TITANKEY_STATUS"
  echo "TOUCHPAD_STATUS=$TOUCHPAD_STATUS"
  echo "PRIMARY_DISPLAY_STATUS=$PRIMARY_DISPLAY_STATUS"
  echo "REAR_DISPLAY_STATUS=$REAR_DISPLAY_STATUS"
} | tee -a "$SUMMARY"

END_TIME=$((SECONDS + DURATION_SECONDS))
SAMPLE=0
while (( SECONDS < END_TIME )); do
  SAMPLE=$((SAMPLE + 1))
  echo "RADIO_SAMPLE=$SAMPLE" | tee -a "$SUMMARY"
  radio_snapshot
  sleep 30
done

RADIO_HOME_SEEN="NO"
RADIO_DATA_CONNECTED_SEEN="NO"
RADIO_OUT_OF_SERVICE_SEEN="NO"
RADIO_EMERGENCY_SEEN="NO"

if grep -Eq 'registrationState=HOME|mVoiceRegState=0\(IN_SERVICE\)|mDataRegState=0\(IN_SERVICE\)' "$RADIO_LOG"; then
  RADIO_HOME_SEEN="YES"
fi
if grep -Eq 'onDataConnectionStateChanged\(CONNECTED|mDataConnectionState=2' "$RADIO_LOG"; then
  RADIO_DATA_CONNECTED_SEEN="YES"
fi
if grep -Eq 'OUT_OF_SERVICE|NOT_REG|mVoiceRegState=1|mDataRegState=1' "$RADIO_LOG"; then
  RADIO_OUT_OF_SERVICE_SEEN="YES"
fi
if grep -Eq 'EMERGENCY|emergencyEnabled=true' "$RADIO_LOG"; then
  RADIO_EMERGENCY_SEEN="YES"
fi

MOBILE_NETWORK_RESULT="MOBILE_NETWORK_FAIL_NO_REGISTRATION"
if [[ "$RADIO_HOME_SEEN" == "YES" && "$RADIO_DATA_CONNECTED_SEEN" == "YES" && "$RADIO_OUT_OF_SERVICE_SEEN" == "NO" ]]; then
  MOBILE_NETWORK_RESULT="MOBILE_NETWORK_STABLE_PASS"
elif [[ "$RADIO_HOME_SEEN" == "YES" || "$RADIO_DATA_CONNECTED_SEEN" == "YES" ]]; then
  MOBILE_NETWORK_RESULT="MOBILE_NETWORK_PARTIAL_INTERMITTENT"
fi

{
  echo
  echo "===== MOBILE NETWORK TRIAGE ====="
  echo "MOBILE_NETWORK_STATUS=TRIAGE_CAPTURED"
  echo "RADIO_CAPTURE_DURATION_SECONDS=$DURATION_SECONDS"
  echo "RADIO_HOME_SEEN=$RADIO_HOME_SEEN"
  echo "RADIO_DATA_CONNECTED_SEEN=$RADIO_DATA_CONNECTED_SEEN"
  echo "RADIO_OUT_OF_SERVICE_SEEN=$RADIO_OUT_OF_SERVICE_SEEN"
  echo "RADIO_EMERGENCY_SEEN=$RADIO_EMERGENCY_SEEN"
  echo "MOBILE_NETWORK_RESULT=$MOBILE_NETWORK_RESULT"
  echo "EMERGENCY_CALL_TESTING=NO"
  echo
  echo "N1B2_PACKAGES_LOG=$PACKAGES_LOG"
  echo "N1B2_INPUT_LOG=$INPUT_LOG"
  echo "N1B2_DISPLAY_LOG=$DISPLAY_LOG"
  echo "N1B2_RADIO_LOG=$RADIO_LOG"
  echo "N1B2_POSTBOOT_ACCEPTANCE_SUMMARY=$SUMMARY"
  echo "N1B2_POSTBOOT_ACCEPTANCE=PASS_CAPTURED"
} | tee -a "$SUMMARY"
