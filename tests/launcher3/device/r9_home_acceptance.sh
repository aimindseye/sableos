#!/usr/bin/env bash
# Physical acceptance for the standalone R9 Sable HOME plus Quickstep fallback Recents.
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    echo "R9_HOME_ACCEPTANCE=REFUSED_SOURCED_SCRIPT" >&2
    echo "Run with: bash ${BASH_SOURCE[0]}" >&2
    return 64
fi

set -euo pipefail

SERIAL="${SERIAL:-${ANDROID_SERIAL:-}}"
ADB_BIN="${ADB:-adb}"
R9_HOME_INCLUDE_THEME_REVIEW="${R9_HOME_INCLUDE_THEME_REVIEW:-NO}"

adb_cmd() {
    if [[ -n "$SERIAL" ]]; then
        "$ADB_BIN" -s "$SERIAL" "$@" </dev/null
    else
        "$ADB_BIN" "$@" </dev/null
    fi
}

package_path() {
    local raw
    raw="$(adb_cmd shell pm path "$1" 2>/dev/null || true)"
    awk '
        /^package:/ {
            sub(/^package:/, "")
            print
            exit
        }
    ' <<<"$raw"
}

EXPECTED_PACKAGE="org.sableos.launcher"
EXPECTED_ACTIVITY="org.sableos.start.SableStartActivity"
EXPECTED_COMPONENT="$EXPECTED_PACKAGE/$EXPECTED_ACTIVITY"
QUICKSTEP_PACKAGE="com.android.launcher3"
LEGACY_PACKAGE="org.sableos.start"

STAMP="$(date +%Y%m%d_%H%M%S)"
EVIDENCE_DIR="${EVIDENCE_DIR:-/tmp/SABLE_R9_HOME_ACCEPTANCE_$STAMP}"
mkdir -p "$EVIDENCE_DIR"
REPORT="$EVIDENCE_DIR/gate_report.txt"
: > "$REPORT"

rec() {
    printf '%s=%s\n' "$1" "$2" | tee -a "$REPORT"
}

fail() {
    rec "$1" FAIL
    rec R9_SABLE_HOME_DEVICE_ACCEPTANCE FAIL
    exit "${2:-1}"
}

echo "===== R9 STANDALONE SABLE HOME DEVICE ACCEPTANCE ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "REBOOT_AUTHORIZED=NO"
echo "SLOT_CHANGE_AUTHORIZED=NO"
echo "WIPE_AUTHORIZED=NO"
echo "PACKAGE_INSTALL_REMOVE_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY_PLUS_NAVIGATION"
echo "ADB_STDIN=/dev/null"
echo "R9_HOME_INCLUDE_THEME_REVIEW=$R9_HOME_INCLUDE_THEME_REVIEW"
echo "EXPECTED_COMPONENT=$EXPECTED_COMPONENT"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"

adb_cmd get-state >/dev/null || fail R9_DEVICE_REACHABLE 2
rec R9_DEVICE_REACHABLE PASS

resolver="$(
    adb_cmd shell cmd package resolve-activity --brief \
        -a android.intent.action.MAIN \
        -c android.intent.category.HOME \
        2>/dev/null | tr -d '\r' | tail -n1
)"
printf '%s\n' "$resolver" > "$EVIDENCE_DIR/home-resolver.txt"

case "$resolver" in
    "$EXPECTED_COMPONENT"|"$EXPECTED_PACKAGE/.SableStartActivity")
        rec HOME_RESOLVER "$EXPECTED_COMPONENT"
        ;;
    *)
        echo "actual_resolver=$resolver"
        fail HOME_RESOLVER
        ;;
esac

role_holders="$(
    adb_cmd shell cmd role get-role-holders --user 0 android.app.role.HOME \
        2>/dev/null | tr -d '\r'
)"
printf '%s\n' "$role_holders" > "$EVIDENCE_DIR/home-role-holders.txt"
grep -Fxq "$EXPECTED_PACKAGE" <<<"$role_holders" || fail HOME_ROLE_HOLDER
grep -Fxq "$QUICKSTEP_PACKAGE" <<<"$role_holders" && fail LAUNCHER3_HOME_ROLE_ABSENT
rec HOME_ROLE_HOLDER "$EXPECTED_PACKAGE"
rec LAUNCHER3_HOME_ROLE_ABSENT PASS

launcher_path="$(package_path "$EXPECTED_PACKAGE")"
[[ -n "$launcher_path" ]] || fail SABLELAUNCHER_PACKAGE_PRESENT
printf '%s\n' "$launcher_path" > "$EVIDENCE_DIR/sablelauncher-package-path.txt"
rec SABLELAUNCHER_PACKAGE_PRESENT PASS

quickstep_path="$(package_path "$QUICKSTEP_PACKAGE")"
[[ -n "$quickstep_path" ]] || fail QUICKSTEP_PACKAGE_PRESENT
printf '%s\n' "$quickstep_path" > "$EVIDENCE_DIR/quickstep-package-path.txt"
rec QUICKSTEP_PACKAGE_PRESENT PASS

legacy_path="$(package_path "$LEGACY_PACKAGE")"
[[ -z "$legacy_path" ]] || fail LEGACY_SABLESTART_PACKAGE_ABSENT
rec LEGACY_SABLESTART_PACKAGE_ABSENT PASS

home_candidates="$(
    adb_cmd shell cmd package query-activities --brief --components \
        -a android.intent.action.MAIN \
        -c android.intent.category.HOME \
        2>/dev/null | tr -d '\r' || true
)"
printf '%s\n' "$home_candidates" > "$EVIDENCE_DIR/home-candidates.txt"
grep -Fq "$EXPECTED_PACKAGE/" <<<"$home_candidates" || fail SABLELAUNCHER_HOME_CANDIDATE
if grep -Fq "$QUICKSTEP_PACKAGE/" <<<"$home_candidates"; then
    fail LAUNCHER3_HOME_ELIGIBILITY_ABSENT
fi
rec SABLELAUNCHER_HOME_CANDIDATE PASS
rec LAUNCHER3_HOME_ELIGIBILITY_ABSENT PASS

quickstep_services="$(
    adb_cmd shell cmd package query-services --brief --components \
        -a android.intent.action.QUICKSTEP_SERVICE \
        2>/dev/null | tr -d '\r' || true
)"
printf '%s\n' "$quickstep_services" > "$EVIDENCE_DIR/quickstep-services.txt"
grep -Fq "$QUICKSTEP_PACKAGE/com.android.quickstep.TouchInteractionService" \
    <<<"$quickstep_services" || fail QUICKSTEP_SERVICE_PRESENT
rec QUICKSTEP_SERVICE_PRESENT PASS

adb_cmd logcat -c
for _ in 1 2 3; do
    adb_cmd shell input keyevent KEYCODE_HOME
    sleep 2
done

adb_cmd shell dumpsys activity activities \
    > "$EVIDENCE_DIR/activities-after-home.txt" 2>&1 || true
adb_cmd shell dumpsys window \
    > "$EVIDENCE_DIR/window-after-home.txt" 2>&1 || true
adb_cmd shell pidof "$EXPECTED_PACKAGE" \
    > "$EVIDENCE_DIR/sablelauncher-pid.txt" 2>&1 || true

[[ -s "$EVIDENCE_DIR/sablelauncher-pid.txt" ]] || fail HOME_PROCESS_SURVIVES
rec HOME_PROCESS_SURVIVES PASS

adb_cmd logcat -d -v epoch > "$EVIDENCE_DIR/logcat-after-home.txt" 2>&1 || true
if grep -E \
    "ANR in $EXPECTED_PACKAGE|Process: $EXPECTED_PACKAGE|FATAL EXCEPTION.*sable" \
    "$EVIDENCE_DIR/logcat-after-home.txt" \
    > "$EVIDENCE_DIR/crash-candidates.txt"
then
    fail COLD_HOME_LAUNCH_CRASHES
fi
: > "$EVIDENCE_DIR/crash-candidates.txt"
rec COLD_HOME_LAUNCH_CRASHES 0

# Exercise the system app-switch path. With SableLauncher as default HOME,
# Launcher3 Quickstep must use its fallback Recents path rather than workspace.
adb_cmd shell input keyevent KEYCODE_APP_SWITCH
sleep 2
adb_cmd shell dumpsys activity activities \
    > "$EVIDENCE_DIR/activities-after-recents.txt" 2>&1 || true
adb_cmd shell input keyevent KEYCODE_HOME
sleep 1
rec QUICKSTEP_FALLBACK_RECENTS_NAVIGATION_EXECUTED PASS

echo
echo "Manual visual/interaction confirmations are intentionally separated"
echo "from the objective HOME-role/package/service proof above."

printf 'Does HOME show Sable Start and return to Start after repeated HOME presses? [y/N]: '
read -r home_ok
case "$home_ok" in
    y|Y|yes|YES|Yes) rec HOME_KEY_RETURNS_TO_START PASS ;;
    *) rec HOME_KEY_RETURNS_TO_START FAIL ;;
esac

printf 'Does app switching show Quickstep Recents and return to Sable HOME without native workspace? [y/N]: '
read -r recents_ok
case "$recents_ok" in
    y|Y|yes|YES|Yes) rec QUICKSTEP_FALLBACK_RECENTS_PRESERVED PASS ;;
    *) rec QUICKSTEP_FALLBACK_RECENTS_PRESERVED FAIL ;;
esac

printf 'Do All Apps, local Search, Sable Peek, and app launch/details work? [y/N]: '
read -r launcher_ok
case "$launcher_ok" in
    y|Y|yes|YES|Yes)
        rec ALL_APPS_TOUCH_NAVIGATION PASS
        rec SEARCH_LOCAL_RESULTS PASS
        rec SABLE_PEEK PASS
        ;;
    *)
        rec ALL_APPS_TOUCH_NAVIGATION FAIL
        rec SEARCH_LOCAL_RESULTS FAIL
        rec SABLE_PEEK FAIL
        ;;
esac

printf 'In All Apps, are enabled privacy/security permission summaries shown under applicable apps? [y/N]: '
read -r permission_summary_ok
case "$permission_summary_ok" in
    y|Y|yes|YES|Yes) rec ALL_APPS_PERMISSION_SUMMARIES PASS ;;
    *) rec ALL_APPS_PERMISSION_SUMMARIES FAIL ;;
esac

echo
echo "Open Live, All Apps, Search, Peek and Appearance."
printf 'Does left-edge Back return from every Sable sub-surface? [y/N]: '
read -r sable_back_ok
case "$sable_back_ok" in
    y|Y|yes|YES|Yes) rec SABLE_SUBSURFACE_BACK_GESTURES PASS ;;
    *) rec SABLE_SUBSURFACE_BACK_GESTURES FAIL ;;
esac

echo
echo "Repeat at least five SHORT/ABORTED bottom-edge swipe-ups from Sable HOME."
echo "Native Launcher3 workspace/icons must never appear."
printf 'Did every aborted swipe remain contained by Sable HOME/system gesture animation? [y/N]: '
read -r aborted_swipe_ok
case "$aborted_swipe_ok" in
    y|Y|yes|YES|Yes) rec SABLE_ABORTED_SWIPE_NO_NATIVE_ESCAPE PASS ;;
    *) rec SABLE_ABORTED_SWIPE_NO_NATIVE_ESCAPE FAIL ;;
esac

echo
echo "Perform at least three deliberate swipe-up-and-hold Recents gestures."
printf 'Did fallback Recents work without native Launcher3 workspace exposure? [y/N]: '
read -r committed_recents_ok
case "$committed_recents_ok" in
    y|Y|yes|YES|Yes) rec SABLE_FALLBACK_RECENTS_GESTURE PASS ;;
    *) rec SABLE_FALLBACK_RECENTS_GESTURE FAIL ;;
esac

echo
echo "From Sable HOME repeat at least five notification-shade swipe-down gestures."
printf 'Did the shade open/close consistently and return to intact Sable HOME? [y/N]: '
read -r shade_gesture_ok
case "$shade_gesture_ok" in
    y|Y|yes|YES|Yes) rec SABLE_STATUS_SHADE_GESTURE_STABILITY PASS ;;
    *) rec SABLE_STATUS_SHADE_GESTURE_STABILITY FAIL ;;
esac

if [[ "$R9_HOME_INCLUDE_THEME_REVIEW" == YES ]]; then
    printf 'Does Sable appearance/theme propagation still work across first-party apps? [y/N]: '
    read -r theme_ok
    case "$theme_ok" in
        y|Y|yes|YES|Yes) rec THEME_PROPAGATION PASS ;;
        *) rec THEME_PROPAGATION FAIL ;;
    esac
else
    rec THEME_PROPAGATION DEFERRED_SEPARATE_PHYSICAL_APPEARANCE_GATE
fi

FINAL=PASS
for key in \
    R9_DEVICE_REACHABLE \
    SABLELAUNCHER_PACKAGE_PRESENT \
    QUICKSTEP_PACKAGE_PRESENT \
    LEGACY_SABLESTART_PACKAGE_ABSENT \
    SABLELAUNCHER_HOME_CANDIDATE \
    LAUNCHER3_HOME_ELIGIBILITY_ABSENT \
    LAUNCHER3_HOME_ROLE_ABSENT \
    QUICKSTEP_SERVICE_PRESENT \
    HOME_PROCESS_SURVIVES \
    HOME_KEY_RETURNS_TO_START \
    QUICKSTEP_FALLBACK_RECENTS_PRESERVED \
    ALL_APPS_TOUCH_NAVIGATION \
    SEARCH_LOCAL_RESULTS \
    SABLE_PEEK \
    ALL_APPS_PERMISSION_SUMMARIES \
    SABLE_SUBSURFACE_BACK_GESTURES \
    SABLE_ABORTED_SWIPE_NO_NATIVE_ESCAPE \
    SABLE_FALLBACK_RECENTS_GESTURE \
    SABLE_STATUS_SHADE_GESTURE_STABILITY
do
    grep -Fxq "$key=PASS" "$REPORT" || FINAL=FAIL
done

grep -Fxq "HOME_RESOLVER=$EXPECTED_COMPONENT" "$REPORT" || FINAL=FAIL
grep -Fxq "HOME_ROLE_HOLDER=$EXPECTED_PACKAGE" "$REPORT" || FINAL=FAIL
grep -Fxq 'COLD_HOME_LAUNCH_CRASHES=0' "$REPORT" || FINAL=FAIL

if [[ "$R9_HOME_INCLUDE_THEME_REVIEW" == YES ]]; then
    grep -Fxq 'THEME_PROPAGATION=PASS' "$REPORT" || FINAL=FAIL
else
    grep -Fxq \
        'THEME_PROPAGATION=DEFERRED_SEPARATE_PHYSICAL_APPEARANCE_GATE' \
        "$REPORT" || FINAL=FAIL
fi

rec R9_SABLE_HOME_DEVICE_ACCEPTANCE "$FINAL"

(
    cd "$EVIDENCE_DIR"
    find . -type f ! -name SHA256SUMS.txt -print0 |
        sort -z |
        xargs -0 sha256sum > SHA256SUMS.txt
)

echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "RESULT=$FINAL"

[[ "$FINAL" == PASS ]] || exit 1
exit 0
