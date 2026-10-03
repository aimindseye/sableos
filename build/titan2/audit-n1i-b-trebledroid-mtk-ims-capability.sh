#!/usr/bin/env bash
# SableOS Titan 2 N1I-B: TrebleDroid MTK IMS and real radio-capability-switch
# source audit.
#
# Re-checks the claims in docs/titan2/N1I_B_TREBLEDROID_MTK_IMS_CAPABILITY_ANALYSIS.md
# against pinned source, and checks that the report and
# docs/titan2/N1I_B_DECISIONS.env agree.
#
# READ-ONLY CONTRACT
#   - Reads source trees and repo files only. Writes nothing except the optional
#     --out marker file.
#   - Never contacts a device, never builds, never flashes, never installs.
#   - Never fetches from the network.
#
# Every source path has a flag. Defaults point at the C3A workspace and the
# pinned Restless recipe on the build host. A missing required source makes the
# dependent marker FAIL; it is never skipped silently.
#
# Exit codes: 0 all markers PASS   1 any marker FAIL   2 usage error

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  audit-n1i-b-trebledroid-mtk-ims-capability.sh [options]

Source locations (each defaults under --c3a-workspace unless noted):
  --c3a-workspace DIR     default: $SABLE_BUILD_ROOT/workspaces/titan2-n1d
  --treble-app DIR        default: <ws>/treble_app
  --device-phh-treble DIR default: <ws>/device/phh/treble
  --hardware-overlay DIR  default: <ws>/vendor/hardware_overlay
  --vendor-interfaces DIR default: <ws>/vendor/interfaces
  --opt-telephony DIR     default: <ws>/frameworks/opt/telephony
  --telephony-app DIR     default: <ws>/packages/services/Telephony
  --hwi-radio DIR         default: <ws>/hardware/interfaces/radio
  --framework-config FILE default: <ws>/frameworks/base/core/res/res/values/config.xml
  --ril-constants FILE    default: <ws>/frameworks/base/telephony/java/com/android/internal/telephony/RILConstants.java
  --restless DIR          default: $SABLE_BUILD_ROOT/artifacts/titan2/n1d-c3a-restless-recipe/16.0.0-202606230923
  --atlasos DIR           AtlasOS reference checkout (required, no default)

Other:
  --out FILE              also write the marker list to FILE
  --check-scope           fail if the working tree differs from --base in any file
                          other than the three N1I-B deliverables
  --base SHA              default: 20d8df8ff97706c73b2bdbf522fbf3c75abfc6a1
  -h, --help
EOF
}

die() { echo "N1I_B=FAIL reason=$1" >&2; exit "${2:-2}"; }
((BASH_VERSINFO[0] >= 4)) || die bash4_required

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="$ROOT/docs/titan2/N1I_B_TREBLEDROID_MTK_IMS_CAPABILITY_ANALYSIS.md"
ENVF="$ROOT/docs/titan2/N1I_B_DECISIONS.env"
INV="$ROOT/build/titan2/n1d-c3a-control-patch-inventory-r2.tsv"
PROFILE="$ROOT/build/titan2/n1d-c3-trebledroid.env"
PRIOR_EVIDENCE="$ROOT/docs/titan2/N1B2_RADIO_COMPAT_R1.md"
SELF="${BASH_SOURCE[0]}"

BUILD_ROOT="${SABLE_BUILD_ROOT:-/srv/sable-build}"
WS="$BUILD_ROOT/workspaces/titan2-n1d"
TREBLE_APP="" DEVICE_PHH="" HW_OVERLAY="" VENDOR_IF="" OPT_TEL="" TEL_APP="" HWI_RADIO=""
FW_CONFIG="" RIL_CONST="" RESTLESS="" ATLAS="" OUT="" CHECK_SCOPE=0
BASE="20d8df8ff97706c73b2bdbf522fbf3c75abfc6a1"
RESTLESS_DEFAULT="$BUILD_ROOT/artifacts/titan2/n1d-c3a-restless-recipe/16.0.0-202606230923"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --c3a-workspace)     WS="${2:?}"; shift 2 ;;
    --treble-app)        TREBLE_APP="${2:?}"; shift 2 ;;
    --device-phh-treble) DEVICE_PHH="${2:?}"; shift 2 ;;
    --hardware-overlay)  HW_OVERLAY="${2:?}"; shift 2 ;;
    --vendor-interfaces) VENDOR_IF="${2:?}"; shift 2 ;;
    --opt-telephony)     OPT_TEL="${2:?}"; shift 2 ;;
    --telephony-app)     TEL_APP="${2:?}"; shift 2 ;;
    --hwi-radio)         HWI_RADIO="${2:?}"; shift 2 ;;
    --framework-config)  FW_CONFIG="${2:?}"; shift 2 ;;
    --ril-constants)     RIL_CONST="${2:?}"; shift 2 ;;
    --restless)          RESTLESS="${2:?}"; shift 2 ;;
    --atlasos)           ATLAS="${2:?}"; shift 2 ;;
    --out)               OUT="${2:?}"; shift 2 ;;
    --check-scope)       CHECK_SCOPE=1; shift ;;
    --base)              BASE="${2:?}"; shift 2 ;;
    -h|--help)           usage; exit 0 ;;
    *) usage >&2; die "unknown_arg=$1" 2 ;;
  esac
done

: "${TREBLE_APP:=$WS/treble_app}"
: "${DEVICE_PHH:=$WS/device/phh/treble}"
: "${HW_OVERLAY:=$WS/vendor/hardware_overlay}"
: "${VENDOR_IF:=$WS/vendor/interfaces}"
: "${OPT_TEL:=$WS/frameworks/opt/telephony}"
: "${TEL_APP:=$WS/packages/services/Telephony}"
: "${HWI_RADIO:=$WS/hardware/interfaces/radio}"
: "${FW_CONFIG:=$WS/frameworks/base/core/res/res/values/config.xml}"
: "${RIL_CONST:=$WS/frameworks/base/telephony/java/com/android/internal/telephony/RILConstants.java}"
: "${RESTLESS:=$RESTLESS_DEFAULT}"
ATLAS_GIVEN="$ATLAS"
: "${ATLAS:=/ATLAS_CHECKOUT_NOT_PROVIDED_USE_--atlasos}"

for f in "$DOC" "$ENVF" "$INV" "$PROFILE"; do
  [[ -f "$f" ]] || die "repo_file_missing=${f#"$ROOT"/}"
done

# --- check plumbing ---------------------------------------------------------

declare -A MFAIL=()
CHECKS_TOTAL=0

chk() {
  local marker="$1" desc="$2"
  shift 2
  CHECKS_TOTAL=$((CHECKS_TOTAL + 1))
  if "$@" >/dev/null 2>&1; then
    echo "CHECK $marker $desc=PASS"
  else
    echo "CHECK $marker $desc=FAIL"
    MFAIL[$marker]=$(( ${MFAIL[$marker]:-0} + 1 ))
  fi
}

# Require a source path. A missing one is one FAIL, never a silent skip.
need() {
  local marker="$1" name="$2" path="$3" kind="$4"
  CHECKS_TOTAL=$((CHECKS_TOTAL + 1))
  if [[ "$kind" == dir && -d "$path" ]] || [[ "$kind" == file && -f "$path" ]]; then
    echo "CHECK $marker source_present:$name=PASS"
    return 0
  fi
  echo "CHECK $marker source_present:$name=FAIL path=$path"
  MFAIL[$marker]=$(( ${MFAIL[$marker]:-0} + 1 ))
  return 1
}

# grep helpers. Fixed strings use gf, extended regex uses ge.
gf() { grep -qF -- "$1" "$2"; }
ge() { grep -qE -- "$1" "$2"; }
# No match for REGEX anywhere under the given paths (missing paths ignored).
absent() {
  local re="$1"
  shift
  local p
  for p in "$@"; do
    [[ -e "$p" ]] || continue
    if grep -rIqE --exclude-dir=.git -- "$re" "$p"; then return 1; fi
  done
  return 0
}
absent_i() {
  local re="$1"
  shift
  local p
  for p in "$@"; do
    [[ -e "$p" ]] || continue
    if grep -rIqiE --exclude-dir=.git -- "$re" "$p"; then return 1; fi
  done
  return 0
}
# Print the body of the method whose signature line matches PATTERN (4-space
# indented Java method, closed by a line that is exactly "    }").
fn_body() {
  awk -v pat="$2" '$0 ~ pat { f = 1 } f { print } f && /^    }$/ { exit }' "$1"
}
body_has() { fn_body "$1" "$2" | grep -F -- "$3" >/dev/null; }
body_lacks() { ! fn_body "$1" "$2" | grep -F -- "$3" >/dev/null; }
body_nonempty() { [[ -n "$(fn_body "$1" "$2")" ]]; }
count_is() { [[ "$1" == "$2" ]]; }
env_val() { grep -E "^$1=" "$ENVF" | head -1 | cut -d= -f2-; }
doc_has_line() { grep -qxF -- "$1" "$DOC"; }
tsv_rows() { awk -F'\t' '!/^#/ && NF >= 5' "$INV"; }
tsv_has() { tsv_rows | awk -F'\t' -v t="$1" -v p="$2" -v n="$3" '$1 == t && $2 == p && index($3, n) == 1 { f = 1 } END { exit !f }'; }
tsv_count() { tsv_rows | awk -F'\t' -v p="$1" '$2 == p { c++ } END { print c + 0 }'; }

# --- 0. self scan: this script must not contact a device or build ----------

DEVICE_TOOL_RE="(^|[;&|(\`[:space:]])(a""db|fast""boot|heim""dall|mtk""client|ss""h|sc""p|ma""ke|ni""nja|re""po|lu""nch)[[:space:]]"
self_scan_clean() {
  ! grep -vE '^[[:space:]]*#' "$SELF" | grep -E "$DEVICE_TOOL_RE" | grep -vE 'usage|echo|cat <<|DEVICE_TOOL_RE'
}
chk SCAN script_runs_no_device_or_build_tool self_scan_clean

# --- 1. INV: C3A patch inventory -------------------------------------------

env_count() { grep -E "^$1=" "$PROFILE" | head -1 | cut -d= -f2; }
tier_count() { tsv_rows | awk -F'\t' -v t="$1" '$1 == t { c++ } END { print c + 0 }'; }

chk INV inventory_total_is_369 count_is "$(tsv_rows | wc -l | tr -d ' ')" 369
chk INV profile_total_is_369 count_is "$(env_count N1D_C3_CONTROL_PATCH_COUNT)" 369
chk INV tier_trebledroid_198 count_is "$(tier_count trebledroid)" "$(env_count N1D_C3_CONTROL_TREBLEDROID_PATCH_COUNT)"
chk INV tier_staging_121 count_is "$(tier_count trebledroid-staging)" "$(env_count N1D_C3_CONTROL_TREBLEDROID_STAGING_PATCH_COUNT)"
chk INV tier_rom_29 count_is "$(tier_count rom)" "$(env_count N1D_C3_CONTROL_ROM_PATCH_COUNT)"
chk INV tier_personal_17 count_is "$(tier_count personal)" "$(env_count N1D_C3_CONTROL_PERSONAL_PATCH_COUNT)"
chk INV tier_release_4 count_is "$(tier_count release-builds)" "$(env_count N1D_C3_CONTROL_RELEASE_PATCH_COUNT)"

chk INV has_net_ims_updateImsServiceConfig_shim tsv_has trebledroid platform_frameworks_opt_net_ims 0001-Pie-MTK-IMS
chk INV has_imscall_hold_inversion tsv_has trebledroid-staging platform_frameworks_opt_net_ims 0001-ImsCall-Auto-detect
chk INV has_telephony_metrics_stub tsv_has trebledroid-staging platform_frameworks_opt_telephony 0001-Reintroduce-TelephonyMetrics
chk INV has_binder_thread_conditional_revert tsv_has trebledroid platform_frameworks_opt_telephony 0006-Conditionally-revert
chk INV has_subscription_calling_account_patch tsv_has trebledroid platform_frameworks_opt_telephony 0001-SubscriptionController
chk INV has_getSimStateForSlotIndex_restore tsv_has trebledroid platform_frameworks_base 0033-Restore-getSimStateForSlotIndex
chk INV has_runWithCleanCallingIdentity tsv_has trebledroid platform_frameworks_base 0034-Add-runWithCleanCallingIdentity
chk INV has_phh_signature_trust tsv_has trebledroid platform_frameworks_base 0051-Allow-APKs-of-a-certain-signature
chk INV has_treble_app_ims_download_catch tsv_has trebledroid-staging treble_app 0009-Catch-IMS-download-failures
chk INV has_treble_app_system_menu tsv_has trebledroid-staging treble_app 0002-Move-treble-app-to-system-menu
chk INV has_sourcebuilt_trebleapp_redirect tsv_has personal platform_vendor_hardware_overlay 0001-Replace-prebuilt-TrebleApp

chk INV opt_telephony_patch_count_is_13 count_is "$(tsv_count platform_frameworks_opt_telephony)" 13
no_core_telephony_names() {
  ! tsv_rows | awk -F'\t' '$2 ~ /opt_telephony|opt_net_ims|packages_services_Telephony/ { print $3 }' |
    grep -E 'ImsResolver|PhoneSwitcher|RadioCapability|ProxyController|QNS|Iwlan|IWLAN|CarrierConfig'
}
chk INV no_patch_named_for_resolver_switcher_capability_qns_iwlan_carrierconfig no_core_telephony_names
chk INV no_services_telephony_patch_project count_is "$(tsv_count platform_packages_services_Telephony)" 0

if need INV restless_recipe "$RESTLESS/patches" dir; then
  restless_total() {
    local t n=0
    for t in trebledroid trebledroid-staging rom personal release-builds; do
      n=$((n + $(find "$RESTLESS/patches/$t" -name '*.patch' | wc -l)))
    done
    echo "$n"
  }
  chk INV restless_patch_files_total_369 count_is "$(restless_total)" 369
  restless_five_tiers() {
    local t
    for t in trebledroid trebledroid-staging rom personal release-builds; do echo "$RESTLESS/patches/$t"; done
  }
  # shellcheck disable=SC2046
  chk INV restless_patches_never_touch_capability_resolver_switcher_or_mtkradioex \
    absent 'ProxyController|PhoneSwitcher|ImsResolver|RadioCapability|persist\.vendor\.radio\.(simswitch|c_capability_slot)|mtkradioex|MtkRadioEx|mtkNetworkIndication|persist\.sys\.phh\.ims\.mtk' \
    $(restless_five_tiers)
  # shellcheck disable=SC2046
  chk INV restless_no_qns_iwlan_carrierconfigloader_patch \
    absent 'CarrierConfigLoader|com\.android\.qns|QualifiedNetworksService|IwlanDataService' $(restless_five_tiers)
  rp="$RESTLESS/patches"
  chk INV restless_phh_signature_patch_content ge 'PHH_SIGNATURE' "$(ls "$rp"/trebledroid/platform_frameworks_base/0051-*.patch)"
  chk INV restless_binder_thread_property_default_true ge 'ro\.telephony\.block_binder_thread_on_incoming_calls", true' "$(ls "$rp"/trebledroid/platform_frameworks_opt_telephony/0006-*.patch)"
  chk INV restless_telephony_metrics_stub_content gf 'MediaTek IMS' "$(ls "$rp"/trebledroid-staging/platform_frameworks_opt_telephony/0001-*.patch)"
fi

# --- 2. PATH: TrebleDroid MTK IMS option -----------------------------------

if need PATH treble_app "$TREBLE_APP/app/src/main" dir; then
  TA="$TREBLE_APP/app/src/main"
  IS="$TA/java/me/phh/treble/app/ImsSettings.kt"
  IM="$TA/java/me/phh/treble/app/Ims.kt"
  chk PATH settings_enabled_hardcoded_true ge 'override fun enabled\(\) = true' "$IS"
  chk PATH url_ims_mtk_u_with_sign_suffix gf 'https://treble.phh.me/ims-mtk-u$signSuffix.apk' "$IS"
  chk PATH variant_rule_r_s_aidl_sdk34 gf '(Ims.gotMtkR || Ims.gotMtkS || Ims.gotMtkAidl) && Build.VERSION.SDK_INT >= 34' "$IS"
  chk PATH resigned_suffix_from_phh_signature_field gf 'PHH_SIGNATURE' "$IS"
  chk PATH uses_download_manager gf 'DownloadManager' "$IS"
  chk PATH download_target_external_files_dir gf 'setDestinationInExternalFilesDir' "$IS"
  chk PATH installs_through_package_installer gf 'MODE_FULL_INSTALL' "$IS"
  chk PATH sets_vilte_support_zero_before_install gf 'safeSetprop("persist.vendor.vilte_support", "0")' "$IS"
  chk PATH menu_row_title_rewritten gf 'Install IMS APK for' "$IS"
  chk PATH pref_key_install gf 'key_ims_install_apn' "$TA/res/xml/pref_ims.xml"
  chk PATH pref_header_ims_features gf 'ImsSettingsFragment' "$TA/res/xml/pref_headers.xml"
  chk PATH top_level_title_trebledroid_settings gf '>TrebleDroid Settings<' "$TA/res/values/strings.xml"
  chk PATH selects_telephony_rro_for_mtk gf 'me.phh.treble.overlay.mtkims_telephony' "$IM"
  chk PATH detects_mtkradioex_aidl_ims gf 'vendor.mediatek.hardware.mtkradioex.ims.IMtkRadioExIms/' "$IM"
  chk PATH enables_selected_overlay gf 'OverlayPicker.setOverlayEnabled(selectOverlay, true)' "$IM"
  chk PATH installer_is_system_uid ge 'android:sharedUserId="android.uid.system"' "$TA/AndroidManifest.xml"
  chk PATH installer_declares_install_packages gf 'android.permission.INSTALL_PACKAGES' "$TA/AndroidManifest.xml"
  chk PATH treble_app_has_no_phh_ims_mtk_setter absent 'persist\.sys\.phh\.ims\.mtk' "$TREBLE_APP/app"
  chk PATH treble_app_ships_no_ims_apk count_is "$(find "$TREBLE_APP" \( -iname 'ims*.apk' -o -iname '*mtk*ims*.apk' \) -not -path '*/.git/*' | wc -l | tr -d ' ')" 0
  chk PATH treble_app_force_4g_toggle_sets_dbg_overrides gf 'persist.dbg.volte_avail_ovr' "$IM"
fi
if need PATH device_phh_treble "$DEVICE_PHH" dir; then
  chk PATH device_phh_treble_has_no_phh_ims_mtk_setter absent 'persist\.sys\.phh\.ims\.mtk' "$DEVICE_PHH"
  chk PATH privapp_xml_grants_install_packages gf 'android.permission.INSTALL_PACKAGES' "$DEVICE_PHH/privapp-permissions-me.phh.treble.app.xml"
  chk PATH phh_on_boot_zeroes_mtk_ims_support gf 'persist.mtk_ims_support' "$DEVICE_PHH/phh-on-boot.sh"
  chk PATH base_mk_installs_mtk_sms_fwk_ready gf 'mtk-sms-fwk-ready' "$DEVICE_PHH/base.mk"
fi
if need PATH hardware_overlay "$HW_OVERLAY" dir; then
  chk PATH overlay_mk_lists_trebleapp gf 'TrebleApp' "$HW_OVERLAY/overlay.mk"
  chk PATH overlay_mk_lists_static_mtk_ims gf 'treble-overlay-mtk-ims' "$HW_OVERLAY/overlay.mk"
  chk PATH overlay_mk_lists_telephony_mtk_ims gf 'treble-overlay-telephony-mtk-ims' "$HW_OVERLAY/overlay.mk"
  chk PATH trebleapp_is_platform_signed_privileged ge 'LOCAL_PRIVILEGED_MODULE := true' "$HW_OVERLAY/TrebleApp/Android.mk"
  chk PATH trebleapp_certificate_platform ge 'LOCAL_CERTIFICATE := platform' "$HW_OVERLAY/TrebleApp/Android.mk"
fi
no_license_file() {
  local d n=0
  for d in "$TREBLE_APP" "$HW_OVERLAY" "$DEVICE_PHH"; do
    n=$((n + $(find "$d" -maxdepth 1 \( -iname 'LICENSE*' -o -iname 'COPYING*' \) | wc -l)))
  done
  [[ "$n" == 0 ]]
}
chk PATH treble_app_hw_overlay_device_phh_have_no_license_file no_license_file
chk PATH doc_states_no_license_or_provenance gf 'No license or provenance for the APK in any pinned repo' "$DOC"

# --- 3. ROUTE: provider routing --------------------------------------------

if need ROUTE hardware_overlay "$HW_OVERLAY" dir; then
  SM="$HW_OVERLAY/MTK-IMS"
  TM="$HW_OVERLAY/Telephony/MTK-IMS"
  chk ROUTE static_overlay_gated_on_phh_ims_mtk gf 'persist.sys.phh.ims.mtk' "$SM/AndroidManifest.xml"
  chk ROUTE static_overlay_targets_android gf 'android:targetPackage="android"' "$SM/AndroidManifest.xml"
  chk ROUTE static_overlay_is_static gf 'android:isStatic="true"' "$SM/AndroidManifest.xml"
  chk ROUTE static_overlay_sets_config_ims_package gf 'config_ims_package">com.mediatek.ims' "$SM/res/values/config.xml"
  chk ROUTE static_overlay_sets_dynamic_bind gf 'config_dynamic_bind_ims' "$SM/res/values/config.xml"
  chk ROUTE static_overlay_sets_carrier_volte gf 'config_carrier_volte_available' "$SM/res/values/config.xml"
  chk ROUTE telephony_rro_targets_phone gf 'android:targetPackage="com.android.phone"' "$TM/AndroidManifest.xml"
  chk ROUTE telephony_rro_has_no_property_gate absent 'requiredSystemPropertyName' "$TM/AndroidManifest.xml"
  chk ROUTE telephony_rro_sets_mmtel_package gf 'config_ims_mmtel_package">com.mediatek.ims' "$TM/res/values/config.xml"
  only_one_mmtel_producer() {
    [[ "$(grep -rIl --exclude-dir=.git 'config_ims_mmtel_package">com.mediatek.ims' "$HW_OVERLAY" | wc -l | tr -d ' ')" == 1 ]]
  }
  chk ROUTE exactly_one_overlay_sets_mmtel_to_mediatek only_one_mmtel_producer
fi
if need ROUTE telephony_app "$TEL_APP/src/com/android/phone/PhoneGlobals.java" file; then
  chk ROUTE default_mmtel_package_empty_in_aosp ge 'config_ims_mmtel_package" translatable="false"/>' "$TEL_APP/res/values/config.xml"
  chk ROUTE phone_reads_mmtel_package_resource gf 'R.string.config_ims_mmtel_package' "$TEL_APP/src/com/android/phone/PhoneGlobals.java"
  chk ROUTE phone_builds_imsresolver gf 'ImsResolver.make(this, defaultImsMmtelPackage' "$TEL_APP/src/com/android/phone/PhoneGlobals.java"
fi
if need ROUTE opt_telephony "$OPT_TEL/src/java/com/android/internal/telephony/ims/ImsResolver.java" file; then
  IR="$OPT_TEL/src/java/com/android/internal/telephony/ims/ImsResolver.java"
  chk ROUTE bind_requires_installed_provider body_has "$IR" 'private String getConfiguredImsServicePackageNameInternal' 'doesCachedImsServiceExist(devicePackage'
  chk ROUTE configured_check_does_not_verify_package body_has "$IR" 'public boolean isImsServiceConfiguredForFeature' 'Shortcut a little bit'
  chk ROUTE javadoc_unbound_when_no_application gf 'there is no application on the device that' "$IR"
  chk ROUTE resolver_reset_ims_exists ge 'public void resetIms\(int slotId\)' "$IR"
fi
if need ROUTE framework_config "$FW_CONFIG" file; then
  chk ROUTE android16_core_config_lacks_config_ims_package absent 'name="config_ims_package"' "$FW_CONFIG"
  chk ROUTE android16_core_config_lacks_config_dynamic_bind_ims absent 'name="config_dynamic_bind_ims"' "$FW_CONFIG"
  chk ROUTE android16_core_config_has_config_carrier_volte_available gf 'name="config_carrier_volte_available"' "$FW_CONFIG"
fi
chk ROUTE doc_states_missing_provider doc_has_line 'CONFIGURATION_POINTS_TO_MISSING_PROVIDER=YES'
chk ROUTE env_states_missing_provider count_is "$(env_val CONFIGURATION_POINTS_TO_MISSING_PROVIDER)" YES
for opt in 'A. Install GSI-native MTK IMS' 'B. Disable or change the overlay' 'C. Provide OEM MtkIms'; do
  chk ROUTE "doc_lists_option:${opt%% *}" gf "| $opt |" "$DOC"
done

# --- 4. RCS: real radio capability switch path -----------------------------

if need RCS opt_telephony "$OPT_TEL/src/java/com/android/internal/telephony/ProxyController.java" file; then
  T="$OPT_TEL/src/java/com/android/internal/telephony"
  SMS="$T/subscription/SubscriptionManagerService.java"
  PC="$T/ProxyController.java"
  chk RCS default_data_change_calls_remap body_has "$SMS" 'public void setDefaultDataSubId' 'remapRafIfApplicable();'
  chk RCS remap_only_when_value_changes body_has "$SMS" 'public void setDefaultDataSubId' 'if (mDefaultDataSubId.set(subId))'
  chk RCS default_voice_never_remaps body_nonempty "$SMS" 'public void setDefaultVoiceSubId'
  chk RCS default_voice_has_no_remap body_lacks "$SMS" 'public void setDefaultVoiceSubId' 'remapRafIfApplicable'
  chk RCS default_voice_has_no_proxycontroller body_lacks "$SMS" 'public void setDefaultVoiceSubId' 'ProxyController'
  chk RCS remap_calls_proxycontroller body_has "$SMS" 'private void remapRafIfApplicable' 'proxyController.setRadioCapability(rafs)'
  chk RCS remap_primary_gets_max_raf body_has "$SMS" 'private void remapRafIfApplicable' 'proxyController.getMaxRafSupported()'
  chk RCS remap_others_get_min_raf body_has "$SMS" 'private void remapRafIfApplicable' 'proxyController.getMinRafSupported()'
  sole_caller() {
    [[ "$(grep -rIlE --exclude-dir=.git 'proxyController\.setRadioCapability\(|ProxyController\.getInstance\(\)\.setRadioCapability\(' "$OPT_TEL/src" "$TEL_APP/src" | wc -l | tr -d ' ')" == 1 ]]
  }
  chk RCS subscription_manager_service_is_sole_caller sole_caller
  chk RCS phone_interface_manager_never_sets_raf absent 'ProxyController\.getInstance\(\)\.setRadioCapability' "$TEL_APP/src"
  chk RCS no_shell_command_for_capability absent 'setRadioCapability|set-radio-capability' "$TEL_APP/src/com/android/phone/TelephonyShellCommand.java"
  chk RCS timeout_45_seconds ge 'SET_RC_TIMEOUT_WAITING_MSEC +[=] [(]45 [*] 1000[)]' "$PC"
  chk RCS noop_when_already_configured gf 'Already in requested configuration, nothing to do.' "$PC"
  chk RCS start_phase_sent gf 'RadioCapability.RC_PHASE_START' "$PC"
  chk RCS permanent_failure_on_not_supported gf 'CommandException.Error.REQUEST_NOT_SUPPORTED' "$PC"
  chk RCS failed_transaction_reverts body_has "$PC" 'private void completeRadioCapabilityTransaction' 'doSetRadioCapabilities(rafs)'
  chk RCS completion_broadcasts_done_in_same_method body_has "$PC" 'private void completeRadioCapabilityTransaction' 'ACTION_SET_RADIO_CAPABILITY_DONE'
  chk RCS broadcasts_done gf 'ACTION_SET_RADIO_CAPABILITY_DONE' "$PC"
  chk RCS broadcasts_failed gf 'ACTION_SET_RADIO_CAPABILITY_FAILED' "$PC"
  chk RCS phone_forwards_to_ril gf 'mCi.setRadioCapability(rc, response)' "$T/Phone.java"
  chk RCS ril_forwards_to_modem_proxy gf 'modemProxy.setRadioCapability(rr.mSerial, rc)' "$T/RIL.java"
  chk RCS ril_requires_hal_1_4 ge 'canMakeRequest\("setRadioCapability", modemProxy, result, RADIO_HAL_VERSION_1_4\)' "$T/RIL.java"
  chk RCS modem_proxy_has_aidl_path ge 'mModemProxy\.setRadioCapability\(serial, halRc\)' "$T/RadioModemProxy.java"
  chk RCS modem_proxy_has_hidl_path ge 'mRadioProxy\.setRadioCapability\(serial, halRc\)' "$T/RadioModemProxy.java"
  chk RCS capability_updated_rereads_imei gf 'mCi.getImei(obtainMessage(EVENT_GET_DEVICE_IMEI_DONE))' "$T/Phone.java"
  chk RCS phoneswitcher_uses_preferred_data_modem gf 'mRadioConfig.setPreferredDataModem(mPreferredDataPhoneId, message)' "$T/data/PhoneSwitcher.java"
  chk RCS phoneswitcher_never_calls_proxycontroller absent 'setRadioCapability|ProxyController\.getInstance' "$T/data/PhoneSwitcher.java"
  chk RCS tray_move_is_no_change_when_subids_equal gf 'if (mPrimarySubList.equals(prevPrimarySubList)) return PRIMARY_SUB_NO_CHANGE;' "$T/MultiSimSettingController.java"
  chk RCS single_primary_sub_sets_default_data gf 'if (hasData()) mSubscriptionManagerService.setDefaultDataSubId(subId);' "$T/MultiSimSettingController.java"
fi
if need RCS hwi_radio "$HWI_RADIO/aidl/android/hardware/radio/modem/IRadioModem.aidl" file; then
  AM="$HWI_RADIO/aidl/android/hardware/radio/modem"
  chk RCS aidl_warns_modem_may_reset gf 'it may cause' "$AM/IRadioModem.aidl"
  chk RCS aidl_modem_reset_wording gf 'some vendor modems to reset' "$AM/IRadioModem.aidl"
  chk RCS aidl_requires_radio_access_feature gf 'android.hardware.telephony.radio.access' "$AM/IRadioModem.aidl"
  chk RCS aidl_unsol_within_30s gf 'unsol radioCapability() will be sent within 30 seconds' "$AM/IRadioModemResponse.aidl"
  chk RCS aidl_indication_exists gf 'radioCapabilityIndication' "$AM/IRadioModemIndication.aidl"
  chk RCS aidl_phases_defined gf 'const int PHASE_APPLY = 2;' "$AM/RadioCapability.aidl"
fi
chk RCS doc_names_sole_trigger gf 'That is the only caller of `ProxyController.setRadioCapability`.' "$DOC"

# --- 5. PROPS: property-only versus real modem operation -------------------

chk PROPS vendor_capability_props_absent_from_all_framework_and_treble_source \
  absent 'persist\.vendor\.radio\.simswitch|persist\.vendor\.radio\.c_capability_slot|c_capability_slot' \
  "$OPT_TEL" "$TEL_APP" "$TREBLE_APP" "$DEVICE_PHH" "$HW_OVERLAY" "$VENDOR_IF" "$HWI_RADIO" "$RESTLESS/patches"
chk PROPS vendor_capability_props_absent_from_repo_gates \
  absent 'persist\.vendor\.radio\.simswitch|persist\.vendor\.radio\.c_capability_slot' "$ROOT/build/titan2/n1d-c3a-trebledroid-add.xml" "$INV"
if need PROPS atlasos "$ATLAS/patches/gsi_source" dir; then
  A96="$ATLAS/patches/gsi_source/0096-telephony-ims-follows-settings-calls-sim.patch"
  AE="$ATLAS/packages/titan_ims/bin/titan2-ims-simswitch-early.sh"
  AS="$ATLAS/packages/titan_ims/bin/titan2-ims-setup.sh"
  chk PROPS atlas_0096_writes_vendor_simswitch_from_phone_process gf 'SystemProperties.set("persist.vendor.radio.simswitch", want)' "$A96"
  chk PROPS atlas_0096_writes_c_capability_slot gf 'SystemProperties.set("persist.vendor.radio.c_capability_slot", want)' "$A96"
  chk PROPS atlas_0096_follows_voice_not_data gf 'Settings -> SIMs -> Calls' <(sed 's/→/->/g' "$A96")
  chk PROPS atlas_0096_calls_resetIms gf 'resolver.resetIms(slot)' "$A96"
  chk PROPS atlas_claims_nvram_rewrites_simswitch gf 'Vendor NVRAM resets persist.vendor.radio.simswitch to tray 1' "$AE"
  chk PROPS atlas_uses_resetprop_for_vendor_prop gf 'resetprop_phh' "$AE"
  chk PROPS atlas_claims_vendor_ignores_setprop gf 'vendor persist ignores plain setprop' "$AS"
  chk PROPS atlas_never_calls_proxycontroller absent 'ProxyController|setRadioCapability' "$ATLAS/patches/gsi_source" "$ATLAS/packages/titan_ims"
fi
chk PROPS doc_property_forcing_not_recommended doc_has_line 'PROPERTY_FORCING_RECOMMENDED=NO'
chk PROPS doc_states_property_only_versus_real doc_has_line 'REAL_MODEM_OPERATION  IRadioModem / RIL setRadioCapability via ProxyController'

# --- 6. ATLAS: classification ----------------------------------------------

ALLOWED_CLASSES='ALREADY_IN_C3A ARCHITECTURE_REQUIRED REQUIRED_ONLY_WITH_OEM_MTKIMS CAPABILITY_SWITCH_WORKAROUND BOOT_RACE_WORKAROUND CARRIER_SPECIFIC_OVERRIDE RECOVERY/HEALING_WORKAROUND UNSAFE_OR_NOT_ACCEPTABLE_FOR_SABLEOS NOT_JUSTIFIED_BY_CURRENT_EVIDENCE'
REQUIRED_ATLAS_KEYS='PHH_IMS_MTK_PROP MTK_IMS_OVERLAYS SET_IMS_SERVICE IMS_ENABLE FORCE_CARRIER_CONFIG DATA_ROAMING_UPDATE IMS_APN_INSERT PREFERRED_NETWORK_MODE VENDOR_SIMSWITCH_FORCE C_CAPABILITY_SLOT_FORCE SIMSWITCH_HOLD_5S VOLTE_UA_MANUAL_START IMSSERVICE_KILL_REARM INCOMING_BINDER_THREAD SELINUX_PERMISSIVE_FALLBACK QNS_WFC_ACTIVATION'

in_set() { local v="$1"; shift; local x; for x in $1; do [[ "$x" == "$v" ]] && return 0; done; return 1; }
atlas_row_ok() {
  local key="$1" cls="$2" row
  [[ "$(grep -cE "^\| \`$key\` \|" "$DOC")" == 1 ]] || return 1
  row="$(grep -E "^\| \`$key\` \|" "$DOC")"
  [[ "$row" == *"| $cls |"* ]]
}
for k in $REQUIRED_ATLAS_KEYS; do
  v="$(env_val "ATLAS_CLASS_$k")"
  chk ATLAS "required_key_has_allowed_class:$k" in_set "$v" "$ALLOWED_CLASSES"
  chk ATLAS "doc_row_matches_env:$k" atlas_row_ok "$k" "$v"
done
env_atlas_keys="$(grep -E '^ATLAS_CLASS_' "$ENVF" | cut -d= -f1 | sed 's/^ATLAS_CLASS_//')"
for k in $env_atlas_keys; do
  in_set "$k" "$REQUIRED_ATLAS_KEYS" && continue
  v="$(env_val "ATLAS_CLASS_$k")"
  chk ATLAS "extra_key_has_allowed_class:$k" in_set "$v" "$ALLOWED_CLASSES"
  chk ATLAS "doc_row_matches_env:$k" atlas_row_ok "$k" "$v"
done
chk ATLAS selinux_permissive_is_unacceptable count_is "$(env_val ATLAS_CLASS_SELINUX_PERMISSIVE_FALLBACK)" UNSAFE_OR_NOT_ACCEPTABLE_FOR_SABLEOS
if need ATLAS atlasos "$ATLAS/packages/titan_ims/bin" dir; then
  AB="$ATLAS/packages/titan_ims/bin"
  chk ATLAS anchor_phh_ims_mtk_prop gf 'setprop persist.sys.phh.ims.mtk true' "$AB/titan2-ims-setup.sh"
  chk ATLAS anchor_overlay_enable gf 'cmd overlay enable me.phh.treble.overlay.mtkims_telephony' "$AB/titan2-ims-setup.sh"
  chk ATLAS anchor_set_ims_service gf 'cmd phone ims set-ims-service' "$AB/titan2-ims-setup.sh"
  chk ATLAS anchor_ims_enable gf 'cmd phone ims enable -s' "$AB/titan2-ims-setup.sh"
  chk ATLAS anchor_cc_set_value gf 'cmd phone cc set-value' "$AB/titan2-ims-setup.sh"
  chk ATLAS anchor_siminfo_data_roaming gf 'content update --uri content://telephony/siminfo' "$AB/titan2-ims-setup.sh"
  chk ATLAS anchor_apn_insert gf 'content insert --uri content://telephony/carriers' "$AB/titan2-ims-setup.sh"
  chk ATLAS anchor_preferred_network_mode_11 gf 'preferred_network_mode 11' "$AB/titan2-ims-setup.sh"
  chk ATLAS anchor_vendor_simswitch_forcing gf 'persist.vendor.radio.simswitch "$_want"' "$AB/titan2-ims-setup.sh"
  chk ATLAS anchor_c_capability_forcing gf 'persist.vendor.radio.c_capability_slot "$_want"' "$AB/titan2-ims-setup.sh"
  chk ATLAS anchor_hold_interval_5s gf 'INTERVAL_S=${INTERVAL_S:-5}' "$AB/titan2-ims-simswitch-hold.sh"
  chk ATLAS anchor_volte_ua_start gf 'setprop ctl.start titan2_volte_clientapi_ua' "$AB/titan2-ims-setup.sh"
  chk ATLAS anchor_rearm_kill gf 'kill -9' "$AB/titan2-ims-rearm.sh"
  chk ATLAS anchor_selinux_permissive gf 'setenforce 0' "$AB/titan2-ims-setup.sh"
  chk ATLAS anchor_qns_broadcast gf 'com.android.qns.wfcactivation.TRY_WFC_CONNECTION' "$AB/titan2-ims-setup.sh"
  chk ATLAS anchor_binder_default_false gf 'ro.telephony.block_binder_thread_on_incoming_calls", false' "$ATLAS/patches/gsi_source/0210-telephony-incoming-binder-thread-both-phones.patch"
  chk ATLAS anchor_vilte_zero gf 'persist.vendor.vilte_support 0' "$AB/titan2-ims-setup.sh"
  chk ATLAS anchor_pm_install_mtkims gf 'pm install -r -g /system/priv-app/MtkIms/MtkIms.apk' "$AB/titan2-ims-setup.sh"
  chk ATLAS anchor_multi_sim_write gf 'settings put global multi_sim_data_call' "$AB/titan2-ims-setup.sh"
  chk ATLAS anchor_rc_boot_hook gf 'on property:sys.boot_completed=1' "$ATLAS/packages/titan_ims/init/titan2-ims.rc"
fi
if need ATLAS ril_constants "$RIL_CONST" file; then
  chk ATLAS android16_mode_11_is_lte_only ge 'NETWORK_MODE_LTE_ONLY = 11;' "$RIL_CONST"
  chk ATLAS android16_mode_26_is_nr_lte_gsm_wcdma ge 'NETWORK_MODE_NR_LTE_GSM_WCDMA = 26;' "$RIL_CONST"
fi

# --- 7. MTKIND: mtkNetworkIndication analysis ------------------------------

chk MTKIND mtkNetworkIndication_and_smartRatSwitch_absent_from_all_source \
  absent 'mtkNetworkIndication|smartRatSwitch' "$OPT_TEL" "$TEL_APP" "$TREBLE_APP" "$DEVICE_PHH" "$HW_OVERLAY" "$VENDOR_IF" "$HWI_RADIO" "$RESTLESS/patches"
chk MTKIND csNetworkStateChange_absent_from_aosp_radio_and_framework \
  absent 'CsNetworkStateChange' "$OPT_TEL" "$TEL_APP" "$TREBLE_APP" "$DEVICE_PHH" "$HW_OVERLAY" "$HWI_RADIO" "$RESTLESS/patches"
chk MTKIND aosp_ril_never_registers_mtk_indication_channel \
  absent 'setResponseFunctionsMtk|setResponseFunctionsIms' "$OPT_TEL" "$TEL_APP" "$TREBLE_APP" "$DEVICE_PHH" "$RESTLESS/patches"
if need MTKIND opt_telephony_ril "$OPT_TEL/src/java/com/android/internal/telephony/RIL.java" file; then
  chk MTKIND aosp_ril_registers_its_own_network_indication gf 'mNetworkResponse, mNetworkIndication' "$OPT_TEL/src/java/com/android/internal/telephony/RIL.java"
  only_stub_mentions_mediatek() {
    # In the patched C3A tree the only mention is the TelephonyMetrics stub.
    local others
    others="$(grep -rIliE --exclude-dir=.git 'mediatek' "$OPT_TEL/src" | grep -v 'telephony/metrics/TelephonyMetrics\.java$' || true)"
    [[ -z "$others" ]]
  }
  chk MTKIND opt_telephony_mentions_mediatek_only_in_metrics_stub only_stub_mentions_mediatek
fi
if need MTKIND hwi_radio "$HWI_RADIO/aidl/android/hardware/radio/network/IRadioNetworkIndication.aidl" file; then
  chk MTKIND aosp_network_indication_has_network_state_changed gf 'void networkStateChanged' "$HWI_RADIO/aidl/android/hardware/radio/network/IRadioNetworkIndication.aidl"
  chk MTKIND aosp_network_indication_has_registration_failed gf 'void registrationFailed' "$HWI_RADIO/aidl/android/hardware/radio/network/IRadioNetworkIndication.aidl"
fi
if need MTKIND vendor_interfaces "$VENDOR_IF" dir; then
  MR="$VENDOR_IF/vendor/mediatek/hardware/radio"
  chk MTKIND vendor_interfaces_has_no_mtkradioex_definition count_is "$(find "$VENDOR_IF" -ipath '*mtkradioex*' -not -path '*/.git/*' | wc -l | tr -d ' ')" 0
  chk MTKIND vendor_interfaces_has_older_hidl_mtk_radio_2_0 ge '^package vendor\.mediatek\.hardware\.radio@2\.0;' "$MR/2.0/IRadioIndication.hal"
  chk MTKIND hidl_mtk_indication_extends_aosp_1_1_indication gf 'extends android.hardware.radio@1.1::IRadioIndication' "$MR/2.0/IRadioIndication.hal"
  chk MTKIND hidl_mtk_indication_is_registered_by_separate_call gf 'setResponseFunctionsMtk(IRadioResponse responseCb, IRadioIndication indicationCb)' "$MR/2.0/IRadio.hal"
  chk MTKIND hidl_mtk_defines_cs_network_state_change gf 'responseCsNetworkStateChangeInd' "$MR/2.0/IRadioIndication.hal"
  chk MTKIND hidl_mtk_defines_data_call_list_changed_ex gf 'dataCallListChangedEx' "$MR/2.0/IRadioIndication.hal"
  chk MTKIND hidl_mtk_defines_data_allowed_notification gf 'dataAllowedNotification' "$MR/2.0/IRadioIndication.hal"
  chk MTKIND hidl_mtk_defines_sim_tray_events gf 'onSimTrayPlugIn' "$MR/2.0/IRadioIndication.hal"
  chk MTKIND hidl_mtk_defines_wfc_pdn_events gf 'onWfcPdnStateChanged' "$MR/2.0/IRadioIndication.hal"
  chk MTKIND hidl_radio_2_6_has_build_module gf 'name: "vendor.mediatek.hardware.radio@2.6"' "$MR/2.6/Android.bp"
  chk MTKIND hidl_radio_2_7_to_2_11_are_hal_only count_is "$(find "$MR/2.7" "$MR/2.8" "$MR/2.9" "$MR/2.10" "$MR/2.11" -name Android.bp | wc -l | tr -d ' ')" 0
fi
if need MTKIND device_phh_treble "$DEVICE_PHH/cmds/mtk-sms-fwk-ready.cpp" file; then
  chk MTKIND only_mtk_radio_client_calls_setSmsFwkReady gf 'svc->setSmsFwkReady(1)' "$DEVICE_PHH/cmds/mtk-sms-fwk-ready.cpp"
  chk MTKIND mtk_sms_fwk_ready_does_not_register_indications absent 'setResponseFunctions' "$DEVICE_PHH/cmds/mtk-sms-fwk-ready.cpp"
fi
if need MTKIND treble_app "$TREBLE_APP/app/src/main" dir; then
  only_probe_in_ims_kt() {
    [[ "$(grep -rIl --exclude-dir=.git -i 'mtkradioex' "$TREBLE_APP/app/src" | sed 's#.*/##' | sort -u | tr '\n' ' ')" == "Ims.kt " ]]
  }
  chk MTKIND treble_app_only_probes_mtkradioex_service_names only_probe_in_ims_kt
fi
chk MTKIND prior_evidence_null_seen_in_good_window gf 'AOSP registration responses still complete successfully' "$PRIOR_EVIDENCE"
chk MTKIND prior_evidence_names_both_callbacks ge 'smartRatSwitchInd: radioNetworkServiceImpl\[1\]->mtkNetworkIndication == NULL' "$PRIOR_EVIDENCE"
chk MTKIND doc_root_cause_unproven doc_has_line 'MTK_NETWORK_INDICATION_NULL_ROOT_CAUSE=UNPROVEN'
chk MTKIND env_root_cause_unproven count_is "$(env_val MTK_NETWORK_INDICATION_NULL_ROOT_CAUSE)" UNPROVEN
chk MTKIND doc_has_three_categories_critical gf 'INDICATIONS_KNOWN_CRITICAL_FOR_BASIC_REGISTRATION' "$DOC"
chk MTKIND doc_has_three_categories_extension gf 'INDICATIONS_IMS_OR_MTK_EXTENSION_ONLY' "$DOC"
chk MTKIND doc_has_three_categories_unknown ge '^\| UNKNOWN \|' "$DOC"
chk MTKIND doc_no_radioex_shim_on_null_alone doc_has_line 'MTK_RADIOEX_SHIM_PROPOSED_ON_NULL_ALONE=NO'

# --- 8. HYP: engineer hypotheses -------------------------------------------

HYP_VERDICTS='SUPPORTED PARTIALLY_SUPPORTED UNPROVEN CONTRADICTED'
hyp_row_ok() {
  local id="$1" want="$2" row
  [[ "$(grep -cE "^\| $id \|" "$DOC")" == 1 ]] || return 1
  row="$(grep -E "^\| $id \|" "$DOC")"
  [[ "$row" == *"| $want |"* ]]
}
hyp_env_keys='P1_CAPABILITY_SLOT_MISMATCH_EXPLAINS_TRAY2_FAILURE P2_PROPERTY_FORCING_EQUALS_REAL_CAPABILITY_SWITCH P3_MISSING_IMS_CAN_CAUSE_INCOMING_CALL_FAILURE P4_MISSING_IMS_CAUSES_CAUSE_13 P5_MTK_NETWORK_INDICATION_NULL_CAUSES_LTE_DATA_TEARDOWN P6_OEM_MTKIMS_REQUIRED_BEFORE_GSI_NATIVE_MTK_IMS P7_SYSTEM_ONLY_TITAN_GSI_REMAINS_VIABLE P8_STOCK_SUPER_SYSTEM_EXT_HYBRID_REQUIRED'
for key in $hyp_env_keys; do
  id="${key%%_*}"
  v="$(env_val "$key")"
  chk HYP "env_verdict_allowed:$id" in_set "$v" "$HYP_VERDICTS"
  chk HYP "doc_row_matches_env:$id" hyp_row_ok "$id" "$v"
done
chk HYP eight_hypotheses_in_env count_is "$(grep -cE '^P[1-8]_' "$ENVF")" 8
chk HYP p4_cites_emm_cause_13_is_network_reject gf '3GPP TS 24.301' "$DOC"

# --- 9. EXP: cheapest experiment, design only ------------------------------

chk EXP doc_device_execution_not_authorized doc_has_line 'DEVICE_EXECUTION_AUTHORIZED=NO'
chk EXP doc_experiment_not_executed doc_has_line 'N1I_B_EXPERIMENT_EXECUTED=NO'
chk EXP env_device_execution_not_authorized count_is "$(env_val N1I_B_DEVICE_EXECUTION_AUTHORIZED)" NO
chk EXP doc_has_step_0_readonly gf '### Step 0: read-only baseline' "$DOC"
chk EXP doc_has_step_1_existing_option gf '### Step 1: existing TrebleDroid option' "$DOC"
chk EXP doc_names_ui_path gf 'Settings, "TrebleDroid Settings", "IMS features", "Install IMS APK for' "$DOC"
chk EXP doc_names_artifact_url gf 'https://treble.phh.me/ims-mtk-u-resigned.apk' "$DOC"
chk EXP doc_has_rollback gf 'adb shell pm uninstall com.mediatek.ims' "$DOC"
chk EXP doc_forbids_property_forcing_in_step_1 gf 'Do **not** in step 1: set `persist.sys.phh.ims.mtk`' "$DOC"

# B2 answers and final decisions: report lines must equal the env.
for k in TREBLEDROID_MTK_IMS_AVAILABLE TREBLEDROID_MTK_IMS_PACKAGE TREBLEDROID_MTK_IMS_ALREADY_LOCAL NETWORK_FETCH_REQUIRED TREBLEDROID_MTK_IMS_EXPECTED_SERVICE_PACKAGE; do
  chk EXP "b2_answer_matches_env:$k" doc_has_line "$k=$(env_val "$k")"
done
YNU='YES NO UNPROVEN'
for k in TRAY2_CAPABILITY_MISMATCH_RELEVANCE REAL_CAPABILITY_SWITCH_IMPLEMENTATION PROPERTY_HOLD_REQUIRED TREBLEDROID_MTK_IMS_FIRST_TRIAL OEM_MTKIMS_NEXT_IF_GSI_IMS_FAILS FRAMEWORK_PATCH_REQUIRED_NOW MTK_RADIOEX_SHIM_REQUIRED_NOW SYSTEM_ONLY_ARCHITECTURE_VIABLE STOCK_SUPER_HYBRID_REQUIRED_NOW; do
  v="$(env_val "$k")"
  chk EXP "decision_value_allowed:$k" in_set "$v" "$YNU"
  chk EXP "decision_in_report:$k" doc_has_line "$k=$v"
  chk EXP "decision_has_justification:$k" ge "^\| \`$k=$v\` \|" "$DOC"
done
last_decision_block_is_final() {
  # The nine decision lines appear contiguously in one fenced block.
  awk '/^```text$/ { blk = ""; inb = 1; next } /^```$/ { if (inb && blk ~ /TRAY2_CAPABILITY_MISMATCH_RELEVANCE=/ && blk ~ /STOCK_SUPER_HYBRID_REQUIRED_NOW=/) ok = 1; inb = 0; next } inb { blk = blk $0 "\n" } END { exit !ok }' "$DOC"
}
chk EXP decisions_in_single_fenced_block last_decision_block_is_final
chk EXP b3_missing_provider_answer_matches_env count_is "$(env_val CONFIGURATION_POINTS_TO_MISSING_PROVIDER)" YES

# --- optional scope check --------------------------------------------------

if [[ "$CHECK_SCOPE" == 1 ]]; then
  scope_ok() {
    local changed unexpected
    git -C "$ROOT" cat-file -e "$BASE^{commit}" || return 1
    changed="$({ git -C "$ROOT" diff --name-only "$BASE" --; git -C "$ROOT" ls-files --others --exclude-standard; } | sort -u)"
    unexpected="$(printf '%s\n' "$changed" | grep -vE '^(docs/titan2/N1I_B_TREBLEDROID_MTK_IMS_CAPABILITY_ANALYSIS\.md|docs/titan2/N1I_B_DECISIONS\.env|build/titan2/audit-n1i-b-trebledroid-mtk-ims-capability\.sh)$' | grep -v '^$' || true)"
    [[ -z "$unexpected" ]]
  }
  chk SCOPE changed_files_limited_to_three_deliverables scope_ok
fi

# --- source identity (informational) ---------------------------------------

rev_of() {
  local d="$1"
  if git -C "$d" rev-parse HEAD 2>/dev/null; then return 0; fi
  echo NOT_GIT
}
echo "SRC_TREBLE_APP=$(rev_of "$TREBLE_APP")"
echo "SRC_DEVICE_PHH_TREBLE=$(rev_of "$DEVICE_PHH")"
echo "SRC_HARDWARE_OVERLAY=$(rev_of "$HW_OVERLAY")"
echo "SRC_VENDOR_INTERFACES=$(rev_of "$VENDOR_IF")"
echo "SRC_OPT_TELEPHONY=$(rev_of "$OPT_TEL")"
echo "SRC_TELEPHONY_APP=$(rev_of "$TEL_APP")"
echo "SRC_RESTLESS=$(rev_of "$RESTLESS")"
echo "SRC_ATLASOS=$([[ -n "$ATLAS_GIVEN" ]] && rev_of "$ATLAS" || echo NOT_PROVIDED)"
echo "CHECKS_TOTAL=$CHECKS_TOTAL"

# --- markers ----------------------------------------------------------------

marker() {
  local name="$1" key="$2"
  if [[ -z "${MFAIL[$key]:-}" ]]; then echo "$name=PASS"; else echo "$name=FAIL failed_checks=${MFAIL[$key]}"; fi
}

emit_markers() {
  marker N1I_B_C3A_IMS_PATCH_INVENTORY INV
  marker N1I_B_TREBLEDROID_MTK_IMS_PATH PATH
  marker N1I_B_IMS_PROVIDER_ROUTING ROUTE
  marker N1I_B_RADIO_CAPABILITY_SWITCH_PATH RCS
  marker N1I_B_PROPERTY_VS_MODEM_SWITCH PROPS
  marker N1I_B_ATLASOS_CLASSIFICATION ATLAS
  marker N1I_B_MTK_NETWORK_INDICATION_ANALYSIS MTKIND
  marker N1I_B_ENGINEER_HYPOTHESIS_MATRIX HYP
  marker N1I_B_CHEAPEST_IMS_EXPERIMENT_DEFINED EXP
  if [[ -z "${MFAIL[SCAN]:-}" ]]; then
    echo "N1I_B_DEVICE_CONTACT=NO"
    echo "N1I_B_BUILD=NO"
    echo "N1I_B_FLASH=NO"
  else
    echo "N1I_B_DEVICE_CONTACT=UNVERIFIED_SELF_SCAN_FAILED"
    echo "N1I_B_BUILD=UNVERIFIED_SELF_SCAN_FAILED"
    echo "N1I_B_FLASH=UNVERIFIED_SELF_SCAN_FAILED"
  fi
  if [[ "$CHECK_SCOPE" == 1 ]]; then marker N1I_B_SCOPE SCOPE; fi
  if ((${#MFAIL[@]} == 0)); then echo "N1I_B=PASS"; else echo "N1I_B=FAIL"; fi
}

if [[ -n "$OUT" ]]; then
  emit_markers | tee "$OUT"
else
  emit_markers
fi

((${#MFAIL[@]} == 0))
