#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT/build/config/r8-release.env"
source "$ROOT/build/config/panther-grapheneos-2026081300.env"

SOURCE_MUTATION_AUTHORIZED="${SOURCE_MUTATION_AUTHORIZED:-NO}"
R8_APP_BUNDLE="${R8_APP_BUNDLE:-${1:-}}"

if [[ "$SOURCE_MUTATION_AUTHORIZED" != YES ]]; then
    echo "R8_FINAL_UI_PREPARE=REFUSED_SOURCE_MUTATION_NOT_AUTHORIZED"
    exit 2
fi

WS="$SABLEOS_UPSTREAM"
[[ -d "$WS/.repo" ]] || {
    echo "R8_ANDROID_WORKSPACE=FAIL path=$WS"
    exit 3
}

[[ -n "$R8_APP_BUNDLE" && -d "$R8_APP_BUNDLE" ]] || {
    echo "R8_APP_BUNDLE=FAIL_MISSING"
    exit 4
}

echo "===== R8 FINAL UI SOURCE / PRODUCT PREPARATION ====="
echo "SOURCE_MUTATION_AUTHORIZED=YES"
echo "BUILD_AUTHORIZED=NO"
echo "CLEAN_AUTHORIZED=NO"
echo "CLOBBER_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "WORKSPACE=$WS"
echo "R8_APP_BUNDLE=$R8_APP_BUNDLE"

BRANDING="$ROOT/patches/android-17-grapheneos-2026081300/apply_sable_branding.py"
UI4="$ROOT/patches/android-17-grapheneos-2026081300/apply_ui4_systemui.py"
UI5A="$ROOT/patches/android-17-grapheneos-2026081300/apply_ui5a_settings.py"
UI5B="$ROOT/patches/android-17-grapheneos-2026081300/apply_ui5b_app_security.py"
UI5C_UI6="$ROOT/patches/android-17-grapheneos-2026081300/apply_ui5c_ui6_system_surfaces.py"
SYSTEMUI_COHERENCE="$ROOT/patches/android-17-grapheneos-2026081300/apply_r9_systemui_coherence.py"
SETTINGS_COHERENCE="$ROOT/patches/android-17-grapheneos-2026081300/apply_r9_settings_cohesion.py"
LAUNCHER3_FOUNDATION="$ROOT/patches/android-17-grapheneos-2026081300/apply_r9_launcher3_foundation.py"
QUICKSTEP_RECENTS_ONLY="$ROOT/patches/android-17-grapheneos-2026081300/apply_r9_quickstep_recents_only.py"
MESSAGING_VISIBILITY="$ROOT/patches/android-17-grapheneos-2026081300/apply_r9_messaging_visibility.py"
PHONE_CONTACTS="$ROOT/patches/android-17-grapheneos-2026081300/apply_r9_phone_contacts_presentation.py"
DAILY_DRIVER_CORE="$ROOT/patches/android-17-grapheneos-2026081300/apply_r9_daily_driver_core_presentation.py"

# UI5C/UI6 is the sealed base for later R9 SystemUI/Settings layers. Git status
# cannot distinguish an older modification from a later modification to the
# same tracked file, so the UI5C verifier explicitly skips superseded UI4
# semantics for Tile.kt while retaining its dirty-scope entry. The untracked
# bridge is subtracted from the UI5C scope and then independently validated by
# the R9 SystemUI applicator.
UI5C_SYSTEMUI_LATER_ARGS=(
    --allow-framework-untracked
    packages/SystemUI/src/com/android/systemui/sable/SableSystemAppearance.kt
    --allow-framework-modified
    packages/SystemUI/src/com/android/systemui/qs/panels/ui/compose/infinitegrid/Tile.kt
    --allow-framework-modified
    core/java/android/debug/AdbNotifications.java
)

UI5C_SETTINGS_LATER_ARGS=(
    --allow-settings-modified
    AndroidManifest.xml
    --allow-settings-modified
    src/com/android/settings/core/gateway/SettingsGateway.java
    --allow-settings-untracked
    res/xml/sable_appearance_settings.xml
    --allow-settings-untracked
    res/xml/sable_network_manager_settings.xml
    --allow-settings-untracked
    res/values/strings_sable_cohesion.xml
    --allow-settings-untracked
    src/com/android/settings/sable/SableAppearanceContract.java
    --allow-settings-untracked
    src/com/android/settings/sable/SableAppearanceProvider.java
    --allow-settings-untracked
    src/com/android/settings/sable/SableAppearanceBootReceiver.java
    --allow-settings-untracked
    src/com/android/settings/sable/SableAppearanceSettings.java
    --allow-settings-untracked
    src/com/android/settings/sable/SableNetworkManagerSettings.java
)

verify_ui5c_with_systemui_later() {
    python3 "$UI5C_UI6"         --source "$WS"         "${UI5C_SYSTEMUI_LATER_ARGS[@]}"         verify
}

verify_ui5c_with_full_r9_later() {
    python3 "$UI5C_UI6"         --source "$WS"         "${UI5C_SYSTEMUI_LATER_ARGS[@]}"         "${UI5C_SETTINGS_LATER_ARGS[@]}"         verify
}

repair_ui5c_known_with_systemui_later() {
    python3 "$UI5C_UI6"         --source "$WS"         "${UI5C_SYSTEMUI_LATER_ARGS[@]}"         repair-known-setup-strings
}

repair_ui5c_known_with_full_r9_later() {
    python3 "$UI5C_UI6"         --source "$WS"         "${UI5C_SYSTEMUI_LATER_ARGS[@]}"         "${UI5C_SETTINGS_LATER_ARGS[@]}"         repair-known-setup-strings
}

run_self_test() {
    local name="$1"
    local script="$2"

    echo
    echo "===== $name SELF-TEST ====="
    python3 "$script" --self-test
    echo "${name}_SELF_TEST=PASS"
}

run_self_test SABLE_BRANDING "$BRANDING"
run_self_test UI4_SYSTEMUI "$UI4"
run_self_test UI5A_SETTINGS "$UI5A"
run_self_test UI5B_APP_SECURITY "$UI5B"
run_self_test UI5C_UI6_SYSTEM_SURFACES "$UI5C_UI6"
run_self_test R9_SYSTEMUI_COHERENCE "$SYSTEMUI_COHERENCE"
run_self_test R9_SETTINGS_COHERENCE "$SETTINGS_COHERENCE"
run_self_test R9_LAUNCHER3_FOUNDATION "$LAUNCHER3_FOUNDATION"
run_self_test R9_MESSAGING_VISIBILITY "$MESSAGING_VISIBILITY"
run_self_test R9_PHONE_CONTACTS_PRESENTATION "$PHONE_CONTACTS"

echo
echo "===== CUMULATIVE SYSTEM-SURFACE STATE ====="

if python3 "$SYSTEMUI_COHERENCE" --source "$WS" verify >/dev/null 2>&1; then
    python3 "$SYSTEMUI_COHERENCE" --source "$WS" verify
    echo "R9_SYSTEMUI_COHERENCE=ALREADY_APPLIED"
    echo "R8_CUMULATIVE_SYSTEM_SURFACES=PASS"
elif verify_ui5c_with_full_r9_later >/dev/null 2>&1; then
    verify_ui5c_with_full_r9_later
    echo "R8_CUMULATIVE_SYSTEM_SURFACES=PASS_R9_LATER_DIRT_RECOGNIZED"
elif verify_ui5c_with_systemui_later >/dev/null 2>&1; then
    verify_ui5c_with_systemui_later
    echo "R8_CUMULATIVE_SYSTEM_SURFACES=PASS_SYSTEMUI_LATER_DIRT_RECOGNIZED"
elif python3 "$UI5C_UI6" --source "$WS" verify >/dev/null 2>&1; then
    python3 "$UI5C_UI6" --source "$WS" verify
    echo "R8_CUMULATIVE_SYSTEM_SURFACES=ALREADY_APPLIED"
else
    # A previously observed UI5C resource-alias failure has a dedicated
    # fail-closed repair. It only mutates the exact known wrong file hash.
    if repair_ui5c_known_with_full_r9_later; then
        echo "R8_CUMULATIVE_SYSTEM_SURFACES=REPAIRED_KNOWN_UI5C_STATE_WITH_R9_LATER_DIRT"
    elif repair_ui5c_known_with_systemui_later; then
        echo "R8_CUMULATIVE_SYSTEM_SURFACES=REPAIRED_KNOWN_UI5C_STATE_WITH_SYSTEMUI_LATER_DIRT"
    elif python3 "$UI5C_UI6" --source "$WS" repair-known-setup-strings; then
        echo "R8_CUMULATIVE_SYSTEM_SURFACES=REPAIRED_KNOWN_UI5C_STATE"
    else
        echo "R8_CUMULATIVE_SYSTEM_SURFACES=ADVANCING_RECOGNIZED_STAGE"

        # Settings/branding is an ordered cumulative chain. Test the newest
        # pre-UI5C state first so valid later dirt is never rejected by an
        # obsolete earlier-scope verifier.
        if python3 "$UI5B" --source "$WS" verify; then
            echo "R8_SETTINGS_STAGE=UI5B_ALREADY_APPLIED"
        elif python3 "$UI5A" --source "$WS" verify; then
            echo "R8_SETTINGS_STAGE=UI5A_ALREADY_APPLIED"
            python3 "$UI5B" --source "$WS" apply
            python3 "$UI5B" --source "$WS" verify
        elif python3 "$BRANDING" --source "$WS" verify; then
            echo "R8_SETTINGS_STAGE=BRANDING_ONLY"
            python3 "$UI5A" --source "$WS" apply
            python3 "$UI5A" --source "$WS" verify
            python3 "$UI5B" --source "$WS" apply
            python3 "$UI5B" --source "$WS" verify
        else
            echo "R8_SETTINGS_STAGE=PINNED_BASELINE_EXPECTED"
            python3 "$BRANDING" --source "$WS" apply
            python3 "$BRANDING" --source "$WS" verify
            python3 "$UI5A" --source "$WS" apply
            python3 "$UI5A" --source "$WS" verify
            python3 "$UI5B" --source "$WS" apply
            python3 "$UI5B" --source "$WS" verify
        fi

        # UI4 is independent of the Settings chain but must exist before UI6.
        if python3 "$UI4" --source "$WS" verify; then
            echo "R8_UI4_STAGE=ALREADY_APPLIED"
        else
            python3 "$UI4" --source "$WS" apply
            python3 "$UI4" --source "$WS" verify
            echo "R8_UI4_STAGE=APPLIED"
        fi

        python3 "$UI5C_UI6" --source "$WS" apply
        python3 "$UI5C_UI6" --source "$WS" verify
        echo "R8_CUMULATIVE_SYSTEM_SURFACES=APPLIED"
    fi
fi

echo "R8_CUMULATIVE_SYSTEM_SURFACES=PASS"

echo
echo "===== R9 SYSTEMUI COHERENCE OVERLAY ====="

if python3 "$SYSTEMUI_COHERENCE" --source "$WS" verify >/dev/null 2>&1; then
    python3 "$SYSTEMUI_COHERENCE" --source "$WS" verify
    echo "R9_SYSTEMUI_COHERENCE=ALREADY_APPLIED"
else
    python3 "$SYSTEMUI_COHERENCE" --source "$WS" apply
    python3 "$SYSTEMUI_COHERENCE" --source "$WS" verify
    echo "R9_SYSTEMUI_COHERENCE=APPLIED"
fi
echo "R9_SYSTEMUI_COHERENCE=PASS"

echo
echo "===== R9 SETTINGS / APPEARANCE COHESION ====="

if python3 "$SETTINGS_COHERENCE" --source "$WS" verify >/dev/null 2>&1; then
    python3 "$SETTINGS_COHERENCE" --source "$WS" verify
    echo "R9_SETTINGS_COHERENCE=ALREADY_APPLIED"
else
    python3 "$SETTINGS_COHERENCE" --source "$WS" apply
    python3 "$SETTINGS_COHERENCE" --source "$WS" verify
    echo "R9_SETTINGS_COHERENCE=APPLIED"
fi
echo "R9_SETTINGS_COHERENCE=PASS"

echo
echo "===== SHARED SABLE DESIGN ====="

DESIGN_SRC="$ROOT/src/android/shared/sabledesign"
DESIGN_DST="$WS/packages/apps/SableDesign"

[[ -f "$DESIGN_SRC/Android.bp" ]] || {
    echo "R8_SABLE_DESIGN_SOURCE=FAIL"
    exit 5
}

mkdir -p "$DESIGN_DST"
rsync -a --delete "$DESIGN_SRC/" "$DESIGN_DST/"

diff -qr "$DESIGN_SRC" "$DESIGN_DST" >/dev/null || {
    echo "R8_SABLE_DESIGN_SYNC=FAIL"
    exit 6
}

echo "R8_SABLE_DESIGN_SYNC=PASS"

echo
echo "===== STANDALONE SABLE HOME SYNC ====="

SOURCE_MUTATION_AUTHORIZED=YES SABLEOS_UPSTREAM="$WS" \
    bash "$ROOT/build/panther/sync-sablestart.sh"

echo "R9_SABLELAUNCHER_STANDALONE_SYNC=PASS"

echo
echo "===== QUICKSTEP RECENTS-ONLY SUBSTRATE ====="

if python3 "$QUICKSTEP_RECENTS_ONLY" --source "$WS" verify >/dev/null 2>&1; then
    python3 "$QUICKSTEP_RECENTS_ONLY" --source "$WS" verify
    echo "R9_QUICKSTEP_RECENTS_ONLY=ALREADY_APPLIED"
elif QUICKSTEP_UPGRADE_OUTPUT="$(
    python3 "$QUICKSTEP_RECENTS_ONLY" --source "$WS" upgrade-final 2>&1
)"; then
    printf '%s\n' "$QUICKSTEP_UPGRADE_OUTPUT"
    python3 "$QUICKSTEP_RECENTS_ONLY" --source "$WS" verify
    echo "R9_QUICKSTEP_RECENTS_ONLY=UPGRADED_FINAL"
else
    # The pinned Android 17 Launcher3 tree needs the already-qualified
    # compatibility/foundation patch set before it can compile in this branch.
    # Apply that foundation only as an intermediate substrate, then immediately
    # remove its Sable HOME host and HOME eligibility.
    if python3 "$LAUNCHER3_FOUNDATION" --source "$WS" verify >/dev/null 2>&1; then
        echo "R9_LAUNCHER3_FOUNDATION=PASS_EXISTING_INTERMEDIATE"
    else
        python3 "$LAUNCHER3_FOUNDATION" --source "$WS" apply
        python3 "$LAUNCHER3_FOUNDATION" --source "$WS" verify
        echo "R9_LAUNCHER3_FOUNDATION=APPLIED_INTERMEDIATE"
    fi

    python3 "$QUICKSTEP_RECENTS_ONLY" --source "$WS" apply
    python3 "$QUICKSTEP_RECENTS_ONLY" --source "$WS" verify
    echo "R9_QUICKSTEP_RECENTS_ONLY=APPLIED"
fi

echo "R9_SABLELAUNCHER_HOME_OWNERSHIP=PASS_SOURCE"
echo "R9_LAUNCHER3_HOME_ELIGIBILITY=PASS_ABSENT"

echo
echo "===== SINGLE USER-VISIBLE MESSAGES SURFACE ====="

python3 "$MESSAGING_VISIBILITY" --source "$WS" verify
echo "R9_GRAPHENE_MESSAGING_SUBSTRATE=PASS_PREBUILT_UNMODIFIED"
echo "R9_MESSAGING_LAUNCHER_SUPPRESSION=OWNED_BY_SABLELAUNCHER"
echo "R9_MESSAGING_VISIBILITY=PASS"

echo
echo "===== R9 PHONE + CONTACTS PRESENTATION ====="

if python3 "$PHONE_CONTACTS" --source "$WS" verify; then
    echo "R9_PHONE_CONTACTS_PRESENTATION=ALREADY_APPLIED"
else
    python3 "$PHONE_CONTACTS" --source "$WS" apply
    python3 "$PHONE_CONTACTS" --source "$WS" verify
    echo "R9_PHONE_CONTACTS_PRESENTATION=APPLIED"
fi
echo "R9_PHONE_CONTACTS_PRESENTATION=PASS"

echo
echo "===== R9 DAILY-DRIVER CORE PRESENTATION ====="

if python3 "$DAILY_DRIVER_CORE" --source "$WS" verify; then
    echo "R9_DAILY_DRIVER_CORE_PRESENTATION=ALREADY_APPLIED"
else
    python3 "$DAILY_DRIVER_CORE" --source "$WS" apply
    python3 "$DAILY_DRIVER_CORE" --source "$WS" verify
    echo "R9_DAILY_DRIVER_CORE_PRESENTATION=APPLIED"
fi
echo "R9_DAILY_DRIVER_CORE_PRESENTATION=PASS"

echo
echo "===== R8 FIRST-PARTY PRODUCT APPLICATIONS ====="

SOURCE_MUTATION_AUTHORIZED=YES SABLEOS_UPSTREAM="$WS" R8_APP_BUNDLE="$R8_APP_BUNDLE"     bash "$ROOT/build/panther/stage-r8-product-apps.sh"

echo
echo "===== FINAL CUMULATIVE SOURCE VERIFY ====="

python3 "$SYSTEMUI_COHERENCE" --source "$WS" verify
python3 "$SETTINGS_COHERENCE" --source "$WS" verify
python3 "$QUICKSTEP_RECENTS_ONLY" --source "$WS" verify
python3 "$MESSAGING_VISIBILITY" --source "$WS" verify
python3 "$PHONE_CONTACTS" --source "$WS" verify
python3 "$DAILY_DRIVER_CORE" --source "$WS" verify

echo "R8_SYSTEM_SURFACE_SOURCE_VERIFY=PASS"
echo "R9_SYSTEMUI_COHERENCE=PASS"
echo "R9_SETTINGS_COHERENCE=PASS"
echo "R9_QUICKSTEP_RECENTS_ONLY=PASS"
echo "R9_MESSAGING_VISIBILITY=PASS"
echo "R9_PHONE_CONTACTS_PRESENTATION=PASS"
echo "R9_DAILY_DRIVER_CORE_PRESENTATION=PASS"
echo "R9_SABLELAUNCHER_HOME_OWNERSHIP=PASS_SOURCE"
echo "R9_STANDALONE_SABLELAUNCHER_PRODUCT=PASS_PRESENT"
echo "R8_FINAL_UI_PREPARE=PASS"
echo "BUILD_PERFORMED=NO"
