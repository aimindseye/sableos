#!/usr/bin/env bash
# Refuse sourcing before changing shell options. Device-acceptance failures
# must terminate only this child Bash process, never an interactive SSH shell.
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

EXPECTED_PACKAGE="com.android.launcher3"
EXPECTED_ACTIVITY="com.android.launcher3.sable.SableQuickstepLauncher"
EXPECTED_COMPONENT="$EXPECTED_PACKAGE/$EXPECTED_ACTIVITY"
RETIRED_PACKAGE="org.sableos.start"

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
    rec R9_LAUNCHER3_HOME_DEVICE_ACCEPTANCE FAIL
    exit "${2:-1}"
}

echo "===== R9 LAUNCHER3 HOME DEVICE ACCEPTANCE ====="
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
    adb_cmd shell cmd package resolve-activity --brief         -a android.intent.action.MAIN         -c android.intent.category.HOME         2>/dev/null | tr -d '\r' | tail -n1
)"
printf '%s\n' "$resolver" > "$EVIDENCE_DIR/home-resolver.txt"

case "$resolver" in
    "$EXPECTED_COMPONENT"|"$EXPECTED_PACKAGE/.sable.SableQuickstepLauncher")
        rec HOME_RESOLVER "$EXPECTED_COMPONENT"
        ;;
    *)
        echo "actual_resolver=$resolver"
        fail HOME_RESOLVER
        ;;
esac

role_holders="$(
    adb_cmd shell cmd role get-role-holders --user 0 android.app.role.HOME         2>/dev/null | tr -d '\r'
)"
printf '%s\n' "$role_holders" > "$EVIDENCE_DIR/home-role-holders.txt"
grep -Fxq "$EXPECTED_PACKAGE" <<<"$role_holders" || fail HOME_ROLE_HOLDER
rec HOME_ROLE_HOLDER "$EXPECTED_PACKAGE"

if adb_cmd shell pm path "$RETIRED_PACKAGE" 2>/dev/null     | tr -d '\r' | grep -q '^package:'; then
    fail RETIRED_SABLESTART_PACKAGE_ABSENT
fi
rec RETIRED_SABLESTART_PACKAGE_ABSENT PASS

launcher_path="$(
    adb_cmd shell pm path "$EXPECTED_PACKAGE" 2>/dev/null         | tr -d '\r' | sed -n 's/^package://p' | head -n1
)"
[[ -n "$launcher_path" ]] || fail LAUNCHER3_PACKAGE_PRESENT
printf '%s\n' "$launcher_path" > "$EVIDENCE_DIR/launcher-package-path.txt"
rec LAUNCHER3_PACKAGE_PRESENT PASS

adb_cmd logcat -c

for _ in 1 2 3; do
    adb_cmd shell input keyevent KEYCODE_HOME
    sleep 2
done

adb_cmd shell dumpsys activity activities     > "$EVIDENCE_DIR/activities-after-home.txt" 2>&1 || true
adb_cmd shell dumpsys window     > "$EVIDENCE_DIR/window-after-home.txt" 2>&1 || true
adb_cmd shell pidof "$EXPECTED_PACKAGE"     > "$EVIDENCE_DIR/launcher-pid.txt" 2>&1 || true

[[ -s "$EVIDENCE_DIR/launcher-pid.txt" ]] || fail HOME_PROCESS_SURVIVES
rec HOME_PROCESS_SURVIVES PASS

adb_cmd logcat -d -v epoch > "$EVIDENCE_DIR/logcat-after-home.txt" 2>&1 || true
if grep -E     "ANR in $EXPECTED_PACKAGE|Process: $EXPECTED_PACKAGE|FATAL EXCEPTION.*launcher3"     "$EVIDENCE_DIR/logcat-after-home.txt"     > "$EVIDENCE_DIR/crash-candidates.txt"
then
    fail COLD_HOME_LAUNCH_CRASHES
fi
: > "$EVIDENCE_DIR/crash-candidates.txt"
rec COLD_HOME_LAUNCH_CRASHES 0

# Recents must remain Quickstep-owned after the Sable presentation is hosted.
adb_cmd shell input keyevent KEYCODE_APP_SWITCH
sleep 2
adb_cmd shell dumpsys activity activities     > "$EVIDENCE_DIR/activities-after-recents.txt" 2>&1 || true
adb_cmd shell input keyevent KEYCODE_HOME
sleep 1
rec QUICKSTEP_RECENTS_NAVIGATION_EXECUTED PASS

echo
echo "Manual visual/interaction confirmations are intentionally separated"
echo "from the objective resolver/package/crash proof above."
printf 'Does HOME show the Sable Start presentation and return to Start after HOME? [y/N]: '
read -r home_ok
case "$home_ok" in
    y|Y|yes|YES|Yes) rec HOME_KEY_RETURNS_TO_START PASS ;;
    *) rec HOME_KEY_RETURNS_TO_START FAIL ;;
esac

printf 'Does app switching show native Quickstep Recents and return without corruption? [y/N]: '
read -r recents_ok
case "$recents_ok" in
    y|Y|yes|YES|Yes) rec QUICKSTEP_RECENTS_PRESERVED PASS ;;
    *) rec QUICKSTEP_RECENTS_PRESERVED FAIL ;;
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

printf 'In All Apps, is the privacy/security-impacting enabled-permission summary shown beneath each applicable app name? [y/N]: '
read -r permission_summary_ok
case "$permission_summary_ok" in
    y|Y|yes|YES|Yes) rec ALL_APPS_PERMISSION_SUMMARIES PASS ;;
    *) rec ALL_APPS_PERMISSION_SUMMARIES FAIL ;;
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
    RETIRED_SABLESTART_PACKAGE_ABSENT \
    LAUNCHER3_PACKAGE_PRESENT \
    HOME_PROCESS_SURVIVES \
    HOME_KEY_RETURNS_TO_START \
    QUICKSTEP_RECENTS_PRESERVED \
    ALL_APPS_TOUCH_NAVIGATION \
    SEARCH_LOCAL_RESULTS \
    SABLE_PEEK \
    ALL_APPS_PERMISSION_SUMMARIES
do
    grep -q "^$key=PASS$" "$REPORT" || FINAL=FAIL
done

if [[ "$R9_HOME_INCLUDE_THEME_REVIEW" == YES ]]; then
    grep -q '^THEME_PROPAGATION=PASS
grep -q '^HOME_RESOLVER=com.android.launcher3/com.android.launcher3.sable.SableQuickstepLauncher$' "$REPORT"     || FINAL=FAIL
grep -q '^HOME_ROLE_HOLDER=com.android.launcher3$' "$REPORT" || FINAL=FAIL
grep -q '^COLD_HOME_LAUNCH_CRASHES=0$' "$REPORT" || FINAL=FAIL

rec R9_LAUNCHER3_HOME_DEVICE_ACCEPTANCE "$FINAL"

(
    cd "$EVIDENCE_DIR"
    find . -type f ! -name SHA256SUMS.txt -print0         | sort -z | xargs -0 sha256sum > SHA256SUMS.txt
)

echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "RESULT=$FINAL"
[[ "$FINAL" == PASS ]]
 "$REPORT" || FINAL=FAIL
fi
grep -q '^HOME_RESOLVER=com.android.launcher3/com.android.launcher3.sable.SableQuickstepLauncher$' "$REPORT"     || FINAL=FAIL
grep -q '^HOME_ROLE_HOLDER=com.android.launcher3$' "$REPORT" || FINAL=FAIL
grep -q '^COLD_HOME_LAUNCH_CRASHES=0$' "$REPORT" || FINAL=FAIL

rec R9_LAUNCHER3_HOME_DEVICE_ACCEPTANCE "$FINAL"

(
    cd "$EVIDENCE_DIR"
    find . -type f ! -name SHA256SUMS.txt -print0         | sort -z | xargs -0 sha256sum > SHA256SUMS.txt
)

echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "RESULT=$FINAL"
[[ "$FINAL" == PASS ]]
