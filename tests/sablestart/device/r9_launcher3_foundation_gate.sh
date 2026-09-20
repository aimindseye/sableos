#!/usr/bin/env bash
set -euo pipefail

PKG="${PKG:-com.android.launcher3}"
ACTIVITY="${ACTIVITY:-.sable.SableQuickstepLauncher}"
SERIAL="${SERIAL:-}"
ADB=(adb)
[[ -n "$SERIAL" ]] && ADB=(adb -s "$SERIAL")
COMPONENT="$PKG/$ACTIVITY"

TS="$(date +%Y%m%d_%H%M%S)"
E="${EVIDENCE_DIR:-/tmp/SABLE_R9_LAUNCHER3_FOUNDATION_${TS}}"
mkdir -p "$E/checkpoints"
R="$E/gate_report.txt"
: > "$R"

rec(){ printf '%s=%s\n' "$1" "$2" | tee -a "$R"; }
cap(){
    local n="$1"
    "${ADB[@]}" exec-out screencap -p > "$E/checkpoints/$n.png"
    "${ADB[@]}" shell dumpsys activity activities > "$E/checkpoints/$n.activity.txt" 2>&1 || true
}
ask(){
    local key="$1"; shift
    local x
    printf '%s [y/N]: ' "$*"
    read -r x
    case "$x" in y|Y|yes|YES|Yes) rec "$key" PASS;; *) rec "$key" FAIL;; esac
}

echo "===== R9 LAUNCHER3 / QUICKSTEP FOUNDATION PHYSICAL GATE ====="
"${ADB[@]}" get-state >/dev/null
rec R9_LAUNCHER3_DEVICE_REACHABLE PASS

"${ADB[@]}" shell pm path org.sableos.start > "$E/standalone-sablestart.txt" 2>&1 || true
if grep -Fq 'package:' "$E/standalone-sablestart.txt"; then
    rec R9_STANDALONE_SABLESTART_PACKAGE_ABSENT FAIL
else
    rec R9_STANDALONE_SABLESTART_PACKAGE_ABSENT PASS
fi

"${ADB[@]}" shell pm path "$PKG" > "$E/launcher3-package.txt" 2>&1 || true
grep -Fq 'package:' "$E/launcher3-package.txt" \
    && rec R9_LAUNCHER3_PACKAGE_PRESENT PASS \
    || rec R9_LAUNCHER3_PACKAGE_PRESENT FAIL

"${ADB[@]}" shell cmd package resolve-activity --brief \
    -a android.intent.action.MAIN \
    -c android.intent.category.HOME \
    > "$E/home-resolver.txt" 2>&1 || true

HOME_RESOLVER="$(tail -n1 "$E/home-resolver.txt" | tr -d '\r')"
rec R9_HOME_RESOLVER_VALUE "${HOME_RESOLVER:-NONE}"
if [[ "$HOME_RESOLVER" == "$PKG/"*SableQuickstepLauncher* ]]; then
    rec R9_HOME_RESOLVER_LAUNCHER3 PASS
else
    rec R9_HOME_RESOLVER_LAUNCHER3 FAIL
fi

"${ADB[@]}" shell am start -W -n "$COMPONENT" > "$E/am_start.txt" 2>&1
grep -q '^Status: ok' "$E/am_start.txt" \
    && rec R9_LAUNCHER3_HOME_COMPONENT_LAUNCH PASS \
    || rec R9_LAUNCHER3_HOME_COMPONENT_LAUNCH FAIL

"${ADB[@]}" shell input keyevent KEYCODE_HOME
sleep 2
cap 00_home
ask R9_SABLE_START_VISIBLE "Is the Sable Start root visible after HOME?"

printf 'Open All Apps and exercise the right and left edge Sable Rail, then press Enter: '; read -r _
cap 01_all_apps
ask R9_SABLE_RAIL_TOUCH "Does All Apps remain responsive and does edge alphabet navigation work?"

printf 'Open Search / Command, search for a known installed app, launch it, return HOME, then press Enter: '; read -r _
cap 02_search
ask R9_SABLE_SEARCH_LAUNCH "Did Launcher3-backed search launch the selected app and HOME return to Start?"

printf 'Open Sable Peek for an app, open Android app info, return HOME, then press Enter: '; read -r _
cap 03_peek
ask R9_SABLE_PEEK_APP_INFO "Did Sable Peek route to the correct Android app-info surface?"

printf 'Open Recents/Overview with the normal system gesture or key, then press Enter: '; read -r _
cap 04_recents
ask R9_QUICKSTEP_RECENTS_PRESERVED "Is Quickstep Recents/Overview visible and functional?"

printf 'Return HOME, enter a nested Sable screen, press Back once, then press Enter: '; read -r _
cap 05_back
ask R9_SABLE_BACK_DELEGATION "Did Back return one Sable semantic level without breaking HOME/Overview?"

"${ADB[@]}" shell pidof "$PKG" > "$E/pid.txt" 2>&1 || true
[[ -s "$E/pid.txt" ]] \
    && rec R9_LAUNCHER3_PROCESS_SURVIVES PASS \
    || rec R9_LAUNCHER3_PROCESS_SURVIVES FAIL

"${ADB[@]}" shell logcat -d -v epoch > "$E/logcat.txt" 2>&1 || true
grep -E "ANR in ${PKG}|Process: ${PKG}|FATAL EXCEPTION" "$E/logcat.txt" \
    > "$E/crash_candidates.txt" || true
if grep -Eq "ANR in ${PKG}|Process: ${PKG}" "$E/crash_candidates.txt"; then
    rec R9_LAUNCHER3_NO_OBVIOUS_CRASH_ANR FAIL
else
    rec R9_LAUNCHER3_NO_OBVIOUS_CRASH_ANR PASS
fi

FINAL=PASS
for k in \
    R9_LAUNCHER3_DEVICE_REACHABLE \
    R9_STANDALONE_SABLESTART_PACKAGE_ABSENT \
    R9_LAUNCHER3_PACKAGE_PRESENT \
    R9_HOME_RESOLVER_LAUNCHER3 \
    R9_LAUNCHER3_HOME_COMPONENT_LAUNCH \
    R9_SABLE_START_VISIBLE \
    R9_SABLE_RAIL_TOUCH \
    R9_SABLE_SEARCH_LAUNCH \
    R9_SABLE_PEEK_APP_INFO \
    R9_QUICKSTEP_RECENTS_PRESERVED \
    R9_SABLE_BACK_DELEGATION \
    R9_LAUNCHER3_PROCESS_SURVIVES \
    R9_LAUNCHER3_NO_OBVIOUS_CRASH_ANR
do
    grep -q "^$k=PASS$" "$R" || FINAL=FAIL
done
rec R9_LAUNCHER3_FOUNDATION_PHYSICAL_GATE "$FINAL"

(
 cd "$E"
 find . -type f ! -name SHA256SUMS.txt ! -name SHA256SUMS.txt.sha256 -print0 \
   | sort -z | xargs -0 sha256sum > SHA256SUMS.txt
)
H="$(sha256sum "$E/SHA256SUMS.txt" | awk '{print $1}')"
printf '%s  SHA256SUMS.txt\n' "$H" > "$E/SHA256SUMS.txt.sha256"

echo "$H  $E/SHA256SUMS.txt"
echo "Evidence: $E"
echo "Result: $FINAL"
