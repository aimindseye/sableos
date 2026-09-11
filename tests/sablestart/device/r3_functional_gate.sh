#!/usr/bin/env bash
set -euo pipefail

PKG="${PKG:-org.sableos.start}"
ACTIVITY="${ACTIVITY:-.ui.SableMetroPreviewActivity}"
SERIAL="${SERIAL:-}"
ADB=(adb)
[[ -n "$SERIAL" ]] && ADB=(adb -s "$SERIAL")
COMPONENT="$PKG/$ACTIVITY"

TS="$(date +%Y%m%d_%H%M%S)"
E="${EVIDENCE_DIR:-/tmp/SABLE_METRO_R3_DELTA_FUNCTIONAL_${TS}}"
mkdir -p "$E/checkpoints"
R="$E/gate_report.txt"
: > "$R"

rec(){ printf '%s=%s\n' "$1" "$2" | tee -a "$R"; }
cap(){
    local n="$1"
    "${ADB[@]}" exec-out screencap -p > "$E/checkpoints/$n.png"
    "${ADB[@]}" shell dumpsys activity activities > "$E/checkpoints/$n.activity.txt" 2>&1 || true
    grep -m1 -E 'topResumedActivity|mResumedActivity|ResumedActivity' "$E/checkpoints/$n.activity.txt" \
      | grep -oE '[A-Za-z0-9._]+/[A-Za-z0-9._$]+' | head -n1 \
      > "$E/checkpoints/$n.component.txt" || true
}
ask(){
    local key="$1"; shift
    local x
    printf '%s [y/N]: ' "$*"
    read -r x
    case "$x" in y|Y|yes|YES|Yes) rec "$key" PASS;; *) rec "$key" FAIL;; esac
}

echo "===== SABLE METRO R3 SOURCE-DELTA FUNCTIONAL GATE ====="
"${ADB[@]}" get-state >/dev/null
rec SABLE_METRO_R3_DEVICE_REACHABLE PASS

"${ADB[@]}" shell am start -W -n "$COMPONENT" > "$E/am_start.txt" 2>&1
grep -q '^Status: ok' "$E/am_start.txt" && rec SABLE_METRO_R3_COMPONENT_LAUNCH PASS || rec SABLE_METRO_R3_COMPONENT_LAUNCH FAIL
cap 00_launch

printf 'Navigate Start -> Settings tile, then press Enter: '; read -r _
cap 01_start_settings
ask SABLE_METRO_R3_START_SETTINGS "Is 6/8 Settings visible?"

printf 'Navigate Search -> Settings result, then press Enter: '; read -r _
cap 02_search_settings
ask SABLE_METRO_R3_SEARCH_SETTINGS "Is 6/8 Settings visible?"

printf 'Navigate Files detail -> Open, wait for external Files, then press Enter: '; read -r _
cap 03_files_open
OC="$(cat "$E/checkpoints/03_files_open.component.txt")"
rec SABLE_METRO_R3_FILES_OPEN_COMPONENT "${OC:-NONE}"
[[ -n "$OC" && "${OC%%/*}" != "$PKG" ]] && rec SABLE_METRO_R3_FILES_OPEN_EXTERNAL PASS || rec SABLE_METRO_R3_FILES_OPEN_EXTERNAL FAIL
ask SABLE_METRO_R3_FILES_OPEN_VISIBLE "Is the actual Files app/file browser visible?"

printf 'Return to preview Files detail -> App info, then press Enter: '; read -r _
cap 04_app_info
AC="$(cat "$E/checkpoints/04_app_info.component.txt")"
rec SABLE_METRO_R3_APP_INFO_COMPONENT "${AC:-NONE}"
[[ "${AC%%/*}" == "com.android.settings" ]] && rec SABLE_METRO_R3_APP_INFO_SETTINGS PASS || rec SABLE_METRO_R3_APP_INFO_SETTINGS FAIL
ask SABLE_METRO_R3_APP_INFO_VISIBLE "Is Android App info visible for the Files package?"

printf 'Return to preview and navigate to 7/8 Live, then press Enter: '; read -r _
cap 05_live
ask SABLE_METRO_R3_LIVE_DATE_TIME "Does Live show the current local date/time rather than Sep 15/72° demo text?"
ask SABLE_METRO_R3_LIVE_STATUS "Do Photos/Music/Calendar each show live, empty, or permission-required status?"
ask SABLE_METRO_R3_NO_FAKE_WEATHER_TASKS "Do Weather and Tasks explicitly say provider not configured/unavailable?"

printf 'If "Enable local live data" is visible, tap it and grant only permissions you want to test. Return to Live, then press Enter: '; read -r _
echo "Waiting 65 seconds for the bounded provider/clock refresh..."
sleep 65
cap 06_live_after_refresh
ask SABLE_METRO_R3_PERMISSION_REFRESH "If permission was granted, did the corresponding card move away from permission-required? Answer y if no permission was intentionally granted."
ask SABLE_METRO_R3_CLOCK_REFRESH "Did the displayed time advance appropriately since the prior Live checkpoint?"

"${ADB[@]}" shell pidof "$PKG" > "$E/pid.txt" 2>&1 || true
[[ -s "$E/pid.txt" ]] && rec SABLE_METRO_R3_PROCESS_SURVIVES PASS || rec SABLE_METRO_R3_PROCESS_SURVIVES FAIL

"${ADB[@]}" shell logcat -d -v epoch > "$E/logcat.txt" 2>&1 || true
grep -E "ANR in ${PKG}|Process: ${PKG}|FATAL EXCEPTION" "$E/logcat.txt" > "$E/crash_candidates.txt" || true
if grep -Eq "ANR in ${PKG}|Process: ${PKG}" "$E/crash_candidates.txt"; then
    rec SABLE_METRO_R3_NO_OBVIOUS_CRASH_ANR FAIL
else
    rec SABLE_METRO_R3_NO_OBVIOUS_CRASH_ANR PASS
fi

COUNT="$(find "$E/checkpoints" -name '*.png' | wc -l | tr -d ' ')"
rec SABLE_METRO_R3_SCREENSHOT_COUNT "$COUNT"
[[ "$COUNT" == 7 ]] && rec SABLE_METRO_R3_EXPECTED_SCREENSHOTS PASS || rec SABLE_METRO_R3_EXPECTED_SCREENSHOTS FAIL

FINAL=PASS
for k in SABLE_METRO_R3_DEVICE_REACHABLE SABLE_METRO_R3_COMPONENT_LAUNCH SABLE_METRO_R3_START_SETTINGS SABLE_METRO_R3_SEARCH_SETTINGS SABLE_METRO_R3_FILES_OPEN_EXTERNAL SABLE_METRO_R3_FILES_OPEN_VISIBLE SABLE_METRO_R3_APP_INFO_SETTINGS SABLE_METRO_R3_APP_INFO_VISIBLE SABLE_METRO_R3_LIVE_DATE_TIME SABLE_METRO_R3_LIVE_STATUS SABLE_METRO_R3_NO_FAKE_WEATHER_TASKS SABLE_METRO_R3_PERMISSION_REFRESH SABLE_METRO_R3_CLOCK_REFRESH SABLE_METRO_R3_PROCESS_SURVIVES SABLE_METRO_R3_NO_OBVIOUS_CRASH_ANR SABLE_METRO_R3_EXPECTED_SCREENSHOTS; do
    grep -q "^$k=PASS$" "$R" || FINAL=FAIL
done
rec SABLE_METRO_R3_SOURCE_DELTA_FUNCTIONAL_GATE "$FINAL"

(
 cd "$E"
 find . -type f ! -name SHA256SUMS.txt ! -name SHA256SUMS.txt.sha256 -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS.txt
)
H="$(sha256sum "$E/SHA256SUMS.txt" | awk '{print $1}')"
printf '%s  SHA256SUMS.txt\n' "$H" > "$E/SHA256SUMS.txt.sha256"
echo "$H  $E/SHA256SUMS.txt"
echo "Evidence: $E"
echo "Result: $FINAL"
