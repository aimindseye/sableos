#!/usr/bin/env bash
set -euo pipefail
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/build/config/storage.env"
source "$ROOT/build/config/host-tools.env"

SERIAL="${TITAN_ADB_SERIAL:-TITAN20000006073}"
DURATION_SEC=600
INTERVAL_SEC=5

while (($#)); do
  case "$1" in
    --serial) SERIAL="$2"; shift 2 ;;
    --duration-sec) DURATION_SEC="$2"; shift 2 ;;
    --interval-sec) INTERVAL_SEC="$2"; shift 2 ;;
    -h|--help)
      cat <<'USAGE'
usage:
  bash build/titan2/run-n1h-cellular-live-isolation.sh     [--serial SERIAL] [--duration-sec 600] [--interval-sec 5]

Read-only live cellular isolation on the currently booted Titan 2 image.
No reboot, radio toggle, settings mutation, content update, setprop, install,
service restart, or flash is performed.
USAGE
      exit 0
      ;;
    *) echo "N1H=FAIL unknown_arg=$1" >&2; exit 64 ;;
  esac
done

fail() {
  echo "N1H=FAIL reason=$1" >&2
  exit "${2:-1}"
}

[[ "$DURATION_SEC" =~ ^[1-9][0-9]*$ ]] || fail duration 64
[[ "$INTERVAL_SEC" =~ ^[1-9][0-9]*$ ]] || fail interval 64
[[ -x "$SABLE_ADB" ]] || fail adb_missing
"$SABLE_ADB" -s "$SERIAL" get-state >/dev/null 2>&1 || fail adb_device_not_ready

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$SABLE_EVIDENCE_ROOT/titan2/n1h-cellular-live-isolation/$STAMP"
mkdir -p "$OUT"

echo "===== N1H CELLULAR LIVE ISOLATION ====="
echo "DEVICE_MUTATION=NO"
echo "REBOOT=NO"
echo "AIRPLANE_TOGGLE=NO"
echo "SETTINGS_MUTATION=NO"
echo "PROPERTY_MUTATION=NO"
echo "IMS_REBIND=NO"
echo "RIL_MODEM_RESTART=NO"
echo "FLASH=NO"
echo "DURATION_SEC=$DURATION_SEC"
echo "INTERVAL_SEC=$INTERVAL_SEC"
echo "EVIDENCE_DIR=$OUT"

adb_shell() {
  "$SABLE_ADB" -s "$SERIAL" shell "$@" 2>/dev/null | tr -d '\r'
}

one_line() {
  tr '\n\t' '  ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'
}

prop() {
  adb_shell getprop "$1" | head -n1
}

setting() {
  adb_shell settings get global "$1" | head -n1
}

capture_full() {
  local tag="$1"
  adb_shell getprop > "$OUT/$tag.getprop.txt" || true
  adb_shell dumpsys telephony.registry > "$OUT/$tag.telephony-registry.txt" || true
  adb_shell dumpsys carrier_config > "$OUT/$tag.carrier-config.txt" || true
  adb_shell dumpsys connectivity > "$OUT/$tag.connectivity.txt" || true
  adb_shell dumpsys ims > "$OUT/$tag.ims.txt" || true
  adb_shell content query --uri content://telephony/siminfo     --projection _id:sim_id:data_roaming:is_opportunistic     > "$OUT/$tag.siminfo.txt" || true
  adb_shell cmd phone ims get-ims-service -s 0 -d > "$OUT/$tag.ims-slot0.txt" || true
  adb_shell cmd phone ims get-ims-service -s 1 -d > "$OUT/$tag.ims-slot1.txt" || true
}

capture_full start

echo -e "epoch\tuptime\toperator_numeric\tnetwork_type\tsim_state\tdata_roaming_global\tmobile_data\tpreferred_network_mode\tvoice_sub\tdata_sub\tsms_sub\tvendor_simswitch\tvendor_capability_slot\tradio_simswitch\tvendor_sim_mode\tmtk_ims_support\tmtk_epdg_support\tphh_ims_mtk\tmims_support\tservice_state\tdisplay_info\tdata_state\tims_slot0\tims_slot1\tsiminfo"   > "$OUT/timeline.tsv"

"$SABLE_ADB" -s "$SERIAL" logcat -b radio -v threadtime > "$OUT/radio.log" 2>&1 &
RADIO_PID=$!

cleanup() {
  set +e
  kill "$RADIO_PID" 2>/dev/null || true
  wait "$RADIO_PID" 2>/dev/null || true
  set -e
}
trap cleanup EXIT INT TERM

START_EPOCH="$(date +%s)"
END_EPOCH=$((START_EPOCH + DURATION_SEC))

while (( $(date +%s) < END_EPOCH )); do
  epoch="$(date +%s)"
  uptime="$(adb_shell cat /proc/uptime | awk '{print $1}' || true)"
  operator_numeric="$(prop gsm.operator.numeric)"
  network_type="$(prop gsm.network.type)"
  sim_state="$(prop gsm.sim.state)"
  data_roaming="$(setting data_roaming)"
  mobile_data="$(setting mobile_data)"
  preferred_network_mode="$(setting preferred_network_mode)"
  voice_sub="$(setting multi_sim_voice_call)"
  data_sub="$(setting multi_sim_data_call)"
  sms_sub="$(setting multi_sim_sms)"
  vendor_simswitch="$(prop persist.vendor.radio.simswitch)"
  vendor_capability_slot="$(prop persist.vendor.radio.c_capability_slot)"
  radio_simswitch="$(prop persist.radio.simswitch)"
  vendor_sim_mode="$(prop persist.vendor.radio.sim.mode)"
  mtk_ims_support="$(prop persist.mtk_ims_support)"
  mtk_epdg_support="$(prop persist.mtk_epdg_support)"
  phh_ims_mtk="$(prop persist.sys.phh.ims.mtk)"
  mims_support="$(prop persist.vendor.mims_support)"

  registry="$(adb_shell dumpsys telephony.registry || true)"
  service_state="$(printf '%s\n' "$registry" | grep -m1 'mServiceState=' | one_line || true)"
  display_info="$(printf '%s\n' "$registry" | grep -m1 'mTelephonyDisplayInfo=' | one_line || true)"
  data_state="$(printf '%s\n' "$registry" | grep -m1 'mDataConnectionState=' | one_line || true)"

  ims0="$(adb_shell cmd phone ims get-ims-service -s 0 -d | one_line || true)"
  ims1="$(adb_shell cmd phone ims get-ims-service -s 1 -d | one_line || true)"
  siminfo="$(adb_shell content query --uri content://telephony/siminfo     --projection _id:sim_id:data_roaming:is_opportunistic | one_line || true)"

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n'     "$epoch" "$uptime" "$operator_numeric" "$network_type" "$sim_state"     "$data_roaming" "$mobile_data" "$preferred_network_mode"     "$voice_sub" "$data_sub" "$sms_sub"     "$vendor_simswitch" "$vendor_capability_slot" "$radio_simswitch"     "$vendor_sim_mode" "$mtk_ims_support" "$mtk_epdg_support"     "$phh_ims_mtk" "$mims_support"     "$service_state" "$display_info" "$data_state" "$ims0" "$ims1" "$siminfo"     >> "$OUT/timeline.tsv"

  sleep "$INTERVAL_SEC"
done

capture_full end
cleanup
trap - EXIT INT TERM

grep -Ei   'ROAMING_NOT_ALLOWED|rejectCause|reasonForDenial|DATA_DEACT|ERROR_UNSPECIFIED|registeredPlmn|REGISTRATION_STATE|NR_NSA|isNrAvailable|isEnDcAvailable|MCCMNC|NETWORK_STATE_CHANGED|IMS|simswitch'   "$OUT/radio.log" > "$OUT/radio-high-signal.txt" || true

{
  echo "N1H_CAPTURE=PASS"
  echo "N1H_DEVICE_MUTATION=NO"
  echo "N1H_TIMELINE=$OUT/timeline.tsv"
  echo "N1H_RADIO_LOG=$OUT/radio.log"
  echo "N1H_HIGH_SIGNAL=$OUT/radio-high-signal.txt"
  echo "N1H_START_SIMINFO=$OUT/start.siminfo.txt"
  echo "N1H_END_SIMINFO=$OUT/end.siminfo.txt"
  echo "N1H_START_TELEPHONY=$OUT/start.telephony-registry.txt"
  echo "N1H_END_TELEPHONY=$OUT/end.telephony-registry.txt"
} | tee "$OUT/SUMMARY.env"

echo
echo "===== N1H HIGH-SIGNAL RADIO EVENTS ====="
tail -n 250 "$OUT/radio-high-signal.txt" || true

echo
cat "$OUT/SUMMARY.env"
