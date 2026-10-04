#!/usr/bin/env bash
# N1I-B read-only guard self-test (no device, no adb).
# Loads the guard functions out of capture-n1b2-cellular-runtime.sh and checks verdicts:
#   - every exact n1i-b1 extra passes under n1i-b1 and fails under default
#   - prohibited commands fail under both profiles
#   - legacy-allowed families that n1i-b1 narrows (dumpsys activity, lshal) fail under n1i-b1
#   - every literal device command the script itself issues passes the guard of each profile
#   - default-profile verdicts equal the base commit's is_read_only on the whole corpus,
#     and the is_read_only function text is byte-identical to the base commit
#   - n1i-b1 is never wider than (legacy OR exact extra)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$HERE/lib/common.sh"
ROOT="$(git -C "$HERE" rev-parse --show-toplevel)"
SCRIPT="$ROOT/build/titan2/capture-n1b2-cellular-runtime.sh"
BASE="${N1I_B_BASE_COMMIT:-8adfac494380d36dcf1951bcef4adb9dca106b5e}"
C=guard

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
{
  extract_fn "$SCRIPT" is_read_only
  extract_array "$SCRIPT" B1_EXTRA_CMDS
  extract_fn "$SCRIPT" is_b1_extra
  extract_fn "$SCRIPT" is_read_only_b1
  extract_fn "$SCRIPT" guard_ok
} > "$TMP/new.sh"
for f in is_read_only B1_EXTRA_CMDS is_b1_extra is_read_only_b1 guard_ok; do
  grep -q "^$f" "$TMP/new.sh" || { case_result $C "extract_$f" 0 "could not extract $f"; exit 1; }
done
# shellcheck source=/dev/null
source "$TMP/new.sh"

v_default() { PROFILE=default guard_ok "$1" && echo 1 || echo 0; }
v_b1()      { PROFILE=n1i-b1  guard_ok "$1" && echo 1 || echo 0; }

# ---- exact extras
EXTRAS=("${B1_EXTRA_CMDS[@]}")
case_result $C extras_count "$([[ ${#EXTRAS[@]} -eq 11 ]] && echo 1 || echo 0)" "n=${#EXTRAS[@]} expected 11"
for x in "${EXTRAS[@]}"; do
  case_result $C "b1_allows:$x" "$(v_b1 "$x")" "exact extra under n1i-b1"
  case_result $C "default_refuses:$x" "$([[ "$(v_default "$x")" == 0 ]] && echo 1 || echo 0)" "extra must stay refused under default"
done

# ---- prohibited under every profile
PROHIBITED=(
  "settings put global mobile_data 0" "settings delete global mobile_data" "settings reset global"
  "svc data disable" "svc wifi disable" "am force-stop com.android.phone" "am broadcast -a x"
  "setprop persist.vendor.radio.simswitch 2" "reboot" "reboot bootloader" "rm -rf /data/local/tmp/x"
  "pm install /data/local/tmp/x.apk" "pm clear com.android.phone" "pm disable com.mediatek.ims"
  "input keyevent 26" "monkey 1" "wm size 1x1" "kill 1" "stop ril-daemon-mtk" "start ril-daemon-mtk"
  "su" "su 0 id" "su -c id" "sh -c getprop" "toybox ls" "busybox ls" "echo hi" "log -t x y"
  "logcat -c" "logcat -G 16M" "logcat -P ''" "dumpsys battery set level 5" "dumpsys phone --wait"
  "getprop | grep imei" "getprop > /sdcard/x" 'getprop $(id)' 'getprop `id`' "getprop; reboot" "getprop && reboot"
  "lshal debug android.hardware.radio@1.0::IRadio/slot1" "lshal --types=b,c,l -i -x" "lshal --types=b,c,l"
  "bugreportz" "dumpstate" "bugreport"
  "cmd phone ims enable -s 0" "cmd phone ims disable -s 0" "cmd phone ims set-ims-service -s 0 -c com.x"
  "cmd phone ims get-ims-service -s 2 -d -f 1" "cmd phone ims get-ims-service -s 0 -d -f 1 "
  " cmd phone ims get-ims-service -s 0 -d -f 1" "cmd phone ims get-ims-service -s 0 -d -f 1; reboot"
  "cmd phone ims get-ims-service -s 0  -d -f 1" "cmd package list packages" "cmd settings put global x 1"
  "content insert --uri content://telephony/carriers --bind name:s:x"
  "content update --uri content://telephony/carriers/preferapn --bind apn_id:i:1"
  "content delete --uri content://telephony/carriers" "content call --uri content://telephony/siminfo --method x"
  "content query --uri content://telephony/carriers" "content query --uri content://sms"
  "content query --uri content://telephony/siminfo --projection icc_id"
  "content query --uri content://telephony/carriers --where \"numeric='310260'\""
  "content query --uri content://telephony/carriers/preferapn/subId/1"
  "pm path com.android.phone" "pm path com.mediatek.ims extra" " pm path com.mediatek.ims"
  "dumpsys activity services com.mediatek.ims extra" "dumpsys activity services"
  "dumpsys activity service com.android.phone/.Other" "dumpsys activity broadcasts"
  "dumpsys activity service com.android.phone/.TelephonyDebugService -a"
  "adb root" "root" "unroot" "remount" "disable-verity"
)
for x in "${PROHIBITED[@]}"; do
  case_result $C "b1_refuses:$x" "$([[ "$(v_b1 "$x")" == 0 ]] && echo 1 || echo 0)" "prohibited under n1i-b1"
  case_result $C "default_refuses:$x" "$([[ "$(v_default "$x")" == 0 ]] && echo 1 || echo 0)" "prohibited under default"
done

# ---- legacy-allowed forms that n1i-b1 deliberately narrows
NARROWED=("dumpsys activity" "dumpsys activity com.mediatek.ims" "dumpsys activity processes"
          "dumpsys activity -a" "lshal" "lshal -i" "lshal list -i" "lshal -d")
for x in "${NARROWED[@]}"; do
  case_result $C "b1_narrows:$x" "$([[ "$(v_b1 "$x")" == 0 ]] && echo 1 || echo 0)" "refused under n1i-b1"
done

# ---- every literal device command the script issues must pass its profile's guard
mapfile -t ISSUED < <(
  grep -oE '(adb_ro|adb_try [0-9]+) "[^"$]+"' "$SCRIPT" | sed -E 's/^(adb_ro|adb_try [0-9]+) "//; s/"$//'
  grep -oE 'b1_run "\$dir" [a-z_0-9]+ "[^"$]+"' "$SCRIPT" | sed -E 's/^b1_run "\$dir" [a-z_0-9]+ "//; s/"$//'
  grep -oE 'start_supervisor [a-z_]+ "[^"$]+"' "$SCRIPT" | sed -E 's/^start_supervisor [a-z_]+ "//; s/"$//'
  echo "cat /proc/sys/kernel/random/boot_id"
  for p in ro.build.fingerprint ro.vendor.build.fingerprint ro.build.type ro.debuggable \
           ro.boot.vbmeta.digest ro.boot.slot_suffix sys.boot_completed; do echo "getprop $p"; done
  for d in /system/etc/init/config /system/system_ext/etc/init/config /system_ext/etc/init/config; do echo "ls -la $d"; done
  for s in telephony.registry phone isub carrier_config telecom ims connectivity; do echo "dumpsys $s"; done
  echo "dumpsys package com.mediatek.ims"
)
case_result $C issued_scan_nonempty "$([[ ${#ISSUED[@]} -ge 20 ]] && echo 1 || echo 0)" "n=${#ISSUED[@]}"
for x in "${ISSUED[@]}"; do
  case_result $C "b1_allows_issued:$x" "$(v_b1 "$x")" "script-issued command under n1i-b1"
  case_result $C "default_allows_issued:$x" "$(v_default "$x")" "script-issued command under default"
done

# ---- legacy equivalence against the base commit
if git -C "$ROOT" cat-file -e "$BASE:build/titan2/capture-n1b2-cellular-runtime.sh" 2>/dev/null; then
  git -C "$ROOT" show "$BASE:build/titan2/capture-n1b2-cellular-runtime.sh" > "$TMP/base.sh"
  extract_fn "$TMP/base.sh" is_read_only > "$TMP/base_fn.sh"
  extract_fn "$SCRIPT" is_read_only > "$TMP/new_fn.sh"
  case_result $C legacy_is_read_only_text_identical "$(cmp -s "$TMP/base_fn.sh" "$TMP/new_fn.sh" && echo 1 || echo 0)" "base=$BASE"
  sed 's/^is_read_only()/base_is_read_only()/' "$TMP/base_fn.sh" > "$TMP/base_fn_renamed.sh"
  # shellcheck source=/dev/null
  source "$TMP/base_fn_renamed.sh"
  diffs=0 total=0
  for x in "${EXTRAS[@]}" "${PROHIBITED[@]}" "${NARROWED[@]}" "${ISSUED[@]}"; do
    total=$((total + 1))
    b=$(base_is_read_only "$x" && echo 1 || echo 0)
    [[ "$b" == "$(v_default "$x")" ]] || { diffs=$((diffs + 1)); echo "  verdict differs: $x" >&2; }
  done
  case_result $C legacy_default_verdicts_identical "$([[ $diffs -eq 0 ]] && echo 1 || echo 0)" "corpus=$total differing=$diffs"
  # n1i-b1 is a subset of legacy-or-extra
  wider=0
  for x in "${EXTRAS[@]}" "${PROHIBITED[@]}" "${NARROWED[@]}" "${ISSUED[@]}"; do
    if [[ "$(v_b1 "$x")" == 1 ]] && ! base_is_read_only "$x" && ! is_b1_extra "$x"; then
      wider=$((wider + 1)); echo "  b1 wider than legacy: $x" >&2
    fi
  done
  case_result $C b1_subset_of_legacy_or_extra "$([[ $wider -eq 0 ]] && echo 1 || echo 0)" "wider=$wider"
else
  case_result $C legacy_base_available 0 "base commit $BASE not in this clone; legacy equivalence cannot be shown"
fi

exit $(( N1IB_FAILS > 0 ? 1 : 0 ))
