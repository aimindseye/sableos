#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GUARD="$ROOT/build/titan2/n1i-c1-readonly-guard.sh"
SNAPSHOT="$ROOT/build/titan2/n1i-c1-physical-snapshot.sh"
COLLECTOR="$ROOT/build/titan2/collect-n1i-c1-physical-runtime.sh"
# shellcheck source=/dev/null
source "$GUARD"

fail() { echo "N1I_C1_PHYSICAL_GUARD_TEST=FAIL reason=$1" >&2; exit 1; }

allow() { n1i_c1_guard_ok "$1" || fail "expected_allow=$1"; }
deny() { if n1i_c1_guard_ok "$1"; then fail "expected_deny=$1"; fi; }

# Positive surface is intentionally narrow.
allow "getprop"
allow "getprop ro.product.device"
allow "getprop ro.product.vendor.device"
allow "getprop ro.build.fingerprint"
allow "getprop ro.boot.slot_suffix"
allow "dumpsys telephony.registry"
allow "dumpsys phone"
allow "dumpsys connectivity"
allow "dumpsys carrier_config"
allow "dumpsys package com.mediatek.ims"
allow "dumpsys activity services com.mediatek.ims"
allow "pm path com.mediatek.ims"
allow "cmd phone ims get-ims-service -s 0 -d -f 1"
allow "cmd phone ims get-ims-service -s 0 -c -f 1"
allow "cmd phone ims get-ims-service -s 1 -d -f 1"
allow "cmd phone ims get-ims-service -s 1 -c -f 1"
allow "content query --uri content://telephony/carriers/preferapn"
allow "content query --uri content://telephony/siminfo"
allow "settings get global airplane_mode_on"
allow "settings get global mobile_data"
allow "cat /proc/uptime"

# Regression deny list: no write/toggle/restart/heal/device-mode commands.
deny "setprop persist.vendor.radio.simswitch 2"
deny "setprop persist.vendor.radio.c_capability_slot 2"
deny "settings put global airplane_mode_on 1"
deny "settings delete global airplane_mode_on"
deny "svc data disable"
deny "svc wifi disable"
deny "reboot"
deny "stop ril-daemon"
deny "start ril-daemon"
deny "killall rild"
deny "pm install /data/local/tmp/a.apk"
deny "pm clear com.android.phone"
deny "content update --uri content://telephony/carriers/preferapn --bind apn:s:x"
deny "content insert --uri content://telephony/carriers"
deny "cmd phone ims set-ims-service -s 0 -d com.example.bad"
deny "cmd phone data enable"
deny "am broadcast -a android.intent.action.AIRPLANE_MODE"
deny "input keyevent 26"
deny "getprop; reboot"
deny 'getprop $(setprop x y)'

[[ "${1:-}" == "--guard-only" ]] && {
  echo "N1I_C1_PHYSICAL_GUARD_LIBRARY=PASS"
  exit 0
}

bash -n "$GUARD" "$SNAPSHOT" "$COLLECTOR" || fail shell_syntax

# Runtime identity must tolerate generic GSI system-side identity. Physical
# identity is stock-vendor-bound, while exact system bytes are host/receipt-bound.
# shellcheck source=/dev/null
source "$SNAPSHOT"
SERIAL="TITAN20000006073"
EXPECTED_VENDOR_FP="Unihertz/Titan_2/Titan_2:14/fixture:user/release-keys"
STOCK_SYSTEM_FP="Unihertz/Titan_2/Titan_2:16/stock:user/release-keys"
n1i_c1_adb_ro_value() {
  case "$1" in
    "getprop ro.serialno") echo "$SERIAL" ;;
    "getprop ro.product.device") echo "tdgsi_arm64_ab" ;;
    "getprop ro.product.model") echo "TrebleDroid" ;;
    "getprop ro.product.manufacturer") echo "unknown" ;;
    "getprop ro.product.vendor.device") echo "Titan_2" ;;
    "getprop ro.product.vendor.model") echo "Titan 2" ;;
    "getprop ro.product.vendor.manufacturer") echo "Unihertz" ;;
    "getprop ro.build.version.release") echo "16" ;;
    "getprop ro.build.version.sdk") echo "36" ;;
    "getprop sys.boot_completed") echo "1" ;;
    "getprop ro.vendor.build.fingerprint") echo "$EXPECTED_VENDOR_FP" ;;
    "getprop ro.build.fingerprint") echo "SableOS/tdgsi/tdgsi:16/fixture:userdebug/test-keys" ;;
    "getprop ro.boot.slot_suffix") echo "_a" ;;
    *) return 1 ;;
  esac
}
n1i_c1_verify_runtime_identity || fail generic_gsi_runtime_identity

TD="$(mktemp -d)"
trap 'rm -rf "$TD"' EXIT
SERIAL="TITAN20000006073"
SHA="$(printf 'fixture-system' | sha256sum | awk '{print $1}')"
mkdir -p "$TD/artifact" "$TD/receipt" "$TD/bin"
printf 'fixture-system' > "$TD/artifact/system.img"
cat > "$TD/artifact/artifact.env" <<EOF_A
ROLE=N1I_C1_ANDROID16_CELLULAR_ISOLATION
QUALIFICATION_MODE=POSTBUILD_READONLY
SOURCE_COMMIT=a745c7daa08267d851f45785a5bb7ff762ed4604
ANDROID_PLATFORM=16
SYSTEM_SHA256=$SHA
EOF_A
(
  cd "$TD/artifact"
  sha256sum artifact.env system.img > SHA256SUMS.txt
)
write_receipt() {
  local serial="$1"
  cat > "$TD/receipt/TITAN2_FLASH_RECEIPT.env" <<EOF_R
TITAN2_FLASH_RECEIPT_VERSION=1
DEVICE_SERIAL=$serial
ARTIFACT_ROLE=N1I_C1_ANDROID16_CELLULAR_ISOLATION
IMAGE_SOURCE_COMMIT=a745c7daa08267d851f45785a5bb7ff762ed4604
SYSTEM_SHA256=$SHA
TARGET_PARTITION=system_a
FLASH_RESULT=PASS
POST_FLASH_DEVICE_SERIAL=$serial
POST_FLASH_MODE=ANDROID_ADB
EOF_R
  (cd "$TD/receipt" && sha256sum TITAN2_FLASH_RECEIPT.env > SHA256SUMS.txt)
}
write_receipt "$SERIAL"

ADB_LOG="$TD/adb.log"
cat > "$TD/bin/adb" <<'EOF_ADB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$ADB_LOG"
if [[ "$*" == *" get-state" ]]; then
  printf '%s\n' "${ADB_STATE:-offline}"
  exit 0
fi
exit 1
EOF_ADB
chmod +x "$TD/bin/adb"
export ADB_LOG

: > "$ADB_LOG"
SABLE_ADB="$TD/bin/adb" bash "$COLLECTOR" \
  --authorize-device-contact NO \
  --serial "$SERIAL" --artifact-dir "$TD/artifact" --system-image-sha256 "$SHA" \
  --flash-receipt "$TD/receipt" --scenario tray1 >/dev/null 2>&1 && fail auth_should_fail
[[ ! -s "$ADB_LOG" ]] || fail auth_failure_contacted_adb

: > "$ADB_LOG"
SABLE_ADB="$TD/bin/adb" bash "$COLLECTOR" \
  --authorize-device-contact YES_READ_ONLY \
  --serial "$SERIAL" --artifact-dir "$TD/artifact" --system-image-sha256 abc \
  --flash-receipt "$TD/receipt" --scenario tray1 >/dev/null 2>&1 && fail sha_should_fail
[[ ! -s "$ADB_LOG" ]] || fail sha_failure_contacted_adb

write_receipt WRONGSERIAL
: > "$ADB_LOG"
SABLE_ADB="$TD/bin/adb" bash "$COLLECTOR" \
  --authorize-device-contact YES_READ_ONLY \
  --serial "$SERIAL" --artifact-dir "$TD/artifact" --system-image-sha256 "$SHA" \
  --flash-receipt "$TD/receipt" --scenario tray1 >/dev/null 2>&1 && fail receipt_serial_should_fail
[[ ! -s "$ADB_LOG" ]] || fail receipt_serial_failure_contacted_adb
write_receipt "$SERIAL"

# Mode failure is allowed one adb get-state contact, but no shell/reboot/healing.
for state in offline unauthorized recovery sideload ''; do
  : > "$ADB_LOG"
  ADB_STATE="$state" SABLE_ADB="$TD/bin/adb" bash "$COLLECTOR" \
    --authorize-device-contact YES_READ_ONLY \
    --serial "$SERIAL" --artifact-dir "$TD/artifact" --system-image-sha256 "$SHA" \
    --flash-receipt "$TD/receipt" --scenario tray1 >/dev/null 2>&1 && fail "mode_should_fail=$state"
  [[ "$(wc -l < "$ADB_LOG" | tr -d ' ')" == 1 ]] || fail "mode_extra_adb_calls=$state"
  grep -Fqx -- "-s $SERIAL get-state" "$ADB_LOG" || fail "mode_non_get_state_call=$state"
done

echo "N1I_C1_PHYSICAL_GUARD_TEST=PASS"
