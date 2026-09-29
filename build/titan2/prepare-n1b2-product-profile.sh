#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ANDROID_ROOT=""
ACTIVE_PRODUCT_MK=""
PATCH_ACTIVE_PRODUCT="NO"
SABLE_HOME_MODULE="${SABLE_HOME_MODULE:-SableLauncher}"
ALLOW_MISSING_SABLE_HOME="${ALLOW_MISSING_SABLE_HOME:-NO}"
PROFILE_REL="vendor/sable/n1b2/sable_n1b2_product_profile.mk"
MARKERS_REL="vendor/sable/n1b2/product-closure.env"
UX_READINESS_REL="vendor/sable/n1b2/ux-testbed-readiness.env"
PROFILE_DIR_REL="vendor/sable/n1b2/profiles/titan2"
SABLE_START_SRC_REL="src/android/packages/apps/SableStart"
SABLE_DESIGN_SRC_REL="src/android/shared/sabledesign"
SABLE_START_DST_REL="packages/apps/SableStart"
SABLE_DESIGN_DST_REL="packages/apps/SableDesign"

fail() {
  echo "N1B2_PRODUCT_PROFILE_FAILURE=$*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage:
  prepare-n1b2-product-profile.sh \
    --android-root <android-source-root> \
    --active-product-mk <path relative to android root> \
    [--patch-active-product]

Environment:
  SABLE_HOME_MODULE=<module>         Default: SableLauncher
  ALLOW_MISSING_SABLE_HOME=YES      Escape hatch for investigation only.
                                    Default: NO. Do not use for N1B2 candidates.

This prepares an N1B2 Sable product-profile overlay in an Android workspace.
It syncs the repository-owned SableLauncher source into the Android workspace,
packages Titan2 profile artifacts, and optionally wires the active Treble product
makefile. It does not contact a device and does not authorize flashing.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --android-root)
      ANDROID_ROOT="${2:-}"
      shift 2
      ;;
    --active-product-mk)
      ACTIVE_PRODUCT_MK="${2:-}"
      shift 2
      ;;
    --patch-active-product)
      PATCH_ACTIVE_PRODUCT="YES"
      shift
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

[[ -n "$ANDROID_ROOT" ]] || fail "--android-root is required"
[[ -d "$ANDROID_ROOT" ]] || fail "android root not found: $ANDROID_ROOT"
[[ -n "$ACTIVE_PRODUCT_MK" ]] || fail "--active-product-mk is required"
[[ "$ACTIVE_PRODUCT_MK" != /* ]] || fail "--active-product-mk must be relative to android root"

bash "$ROOT/build/gates/n1b2-titan2-ux-testbed-readiness-contract.sh" "$ROOT"

ANDROID_ROOT="$(cd "$ANDROID_ROOT" && pwd)"
ACTIVE_PRODUCT_PATH="$ANDROID_ROOT/$ACTIVE_PRODUCT_MK"
[[ -f "$ACTIVE_PRODUCT_PATH" ]] || fail "active product makefile not found: $ACTIVE_PRODUCT_PATH"

OUT_DIR="$ANDROID_ROOT/vendor/sable/n1b2"
PROFILE_PATH="$ANDROID_ROOT/$PROFILE_REL"
MARKERS_PATH="$ANDROID_ROOT/$MARKERS_REL"
UX_READINESS_PATH="$ANDROID_ROOT/$UX_READINESS_REL"
PROFILE_DIR="$ANDROID_ROOT/$PROFILE_DIR_REL"

sync_tree() {
  local name="$1"
  local src="$2"
  local dst="$3"

  [[ -d "$src" ]] || fail "$name source not found: $src"
  mkdir -p "$(dirname "$dst")"

  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete \
      --exclude='/PORTABILITY_STATUS.md' \
      --exclude='/SHA256SUMS.txt' \
      "$src/" "$dst/"
  else
    rm -rf -- "$dst"
    mkdir -p "$dst"
    (cd "$src" && tar cf - .) | (cd "$dst" && tar xf -)
    rm -f -- "$dst/PORTABILITY_STATUS.md" "$dst/SHA256SUMS.txt"
  fi

  echo "N1B2_${name}_SYNC=PASS source=$src destination=$dst"
}

require_synced_file() {
  local marker="$1"
  local path="$2"
  [[ -f "$path" ]] || fail "$marker missing: $path"
  echo "$marker=PASS path=$path"
}

sync_tree "SABLELAUNCHER_SOURCE" \
  "$ROOT/$SABLE_START_SRC_REL" \
  "$ANDROID_ROOT/$SABLE_START_DST_REL"
sync_tree "SABLE_DESIGN_SOURCE" \
  "$ROOT/$SABLE_DESIGN_SRC_REL" \
  "$ANDROID_ROOT/$SABLE_DESIGN_DST_REL"

require_synced_file "N1B2_SABLELAUNCHER_ANDROID_BP" \
  "$ANDROID_ROOT/$SABLE_START_DST_REL/Android.bp"
require_synced_file "N1B2_SABLELAUNCHER_MANIFEST" \
  "$ANDROID_ROOT/$SABLE_START_DST_REL/AndroidManifest.xml"
require_synced_file "N1B2_SABLELAUNCHER_ACTIVITY" \
  "$ANDROID_ROOT/$SABLE_START_DST_REL/src/com/sable/start/SableStartActivity.kt"
require_synced_file "N1B2_SABLE_DESIGN_ANDROID_BP" \
  "$ANDROID_ROOT/$SABLE_DESIGN_DST_REL/Android.bp"

grep -Fq 'name: "SableLauncher"' \
  "$ANDROID_ROOT/$SABLE_START_DST_REL/Android.bp" \
  || fail "synced SableLauncher Android.bp does not define android_app SableLauncher"
grep -Fq 'package="org.sableos.launcher"' \
  "$ANDROID_ROOT/$SABLE_START_DST_REL/AndroidManifest.xml" \
  || fail "synced SableLauncher manifest does not declare org.sableos.launcher"
grep -Fq 'android.intent.category.HOME' \
  "$ANDROID_ROOT/$SABLE_START_DST_REL/AndroidManifest.xml" \
  || fail "synced SableLauncher manifest does not declare HOME"

module_present() {
  local module="$1"
  local pattern_bp='name: "'"$module"'"'
  local pattern_mk='LOCAL_MODULE := '"$module"

  if grep -R --include='Android.bp' --include='Android.mk' \
      -Fq "$pattern_bp" "$ANDROID_ROOT" 2>/dev/null; then
    return 0
  fi
  if grep -R --include='Android.bp' --include='Android.mk' \
      -Fq "$pattern_mk" "$ANDROID_ROOT" 2>/dev/null; then
    return 0
  fi
  return 1
}

select_setup_module() {
  local candidates=(SableSetupWizard SetupWizard Provision)
  local candidate
  for candidate in "${candidates[@]}"; do
    if module_present "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

SETUP_MODULE="$(select_setup_module || true)"
if [[ -z "$SETUP_MODULE" ]]; then
  echo "N1B2_SETUP_WIZARD_MODULE=BLOCKED_NOT_FOUND"
  echo "Searched Android.bp / Android.mk for: SableSetupWizard SetupWizard Provision"
  fail "no setup wizard/provisioning module found in Android workspace"
fi

HOME_PRESENT="NO"
if module_present "$SABLE_HOME_MODULE"; then
  HOME_PRESENT="YES"
fi

if [[ "$HOME_PRESENT" != "YES" ]]; then
  echo "N1B2_SABLE_HOME_MODULE=$SABLE_HOME_MODULE"
  echo "N1B2_SABLE_HOME_MODULE_PRESENT=BLOCKED_NOT_FOUND"
  echo "Searched Android.bp / Android.mk for SABLE_HOME_MODULE=$SABLE_HOME_MODULE"
  if [[ "$ALLOW_MISSING_SABLE_HOME" != "YES" ]]; then
    fail "required Sable HOME module is missing from Android workspace"
  fi
  echo "N1B2_SABLE_HOME_MODULE_MISSING_OVERRIDE=YES_INVESTIGATION_ONLY"
fi

mkdir -p "$OUT_DIR" "$PROFILE_DIR"

cat > "$PROFILE_DIR/hardware.env" <<'EOF'
# SableOS Titan2 N1B2 hardware profile.
TARGET_ID=titan2
DEVICE_FAMILY=Unihertz_Titan_2
BOARD_PRODUCT=g71v78c2k_dfl_tee
SOC_FAMILY=MediaTek_MT6878
USERSpace_ABI=arm64
VENDOR_API=34
VNDK=34
TREBLE_STATE=true
DYNAMIC_PARTITIONS=true
VIRTUAL_AB=true
SUPPORTED_ARTIFACT_KIND=gsi-system-image
TITAN2_HARDWARE_PROFILE_PACKAGED=YES
EOF

cat > "$PROFILE_DIR/display.env" <<'EOF'
# SableOS Titan2 N1B2 display profile.
TARGET_ID=titan2
DISPLAY_CLASS=SQUARE_KEYBOARD_WITH_REAR_SUBSCREEN
PRIMARY_DISPLAY_EXPECTED=1440x1440
SECONDARY_DISPLAY_EXPECTED=410x502
LOGICAL_DENSITY_EXPECTED=360
SECONDARY_DISPLAY_POLICY=restricted_attention_glance_candidate
APP_LAYOUT_PROFILE=SQUARE_KEYBOARD
TITAN2_DISPLAY_PROFILE_PACKAGED=YES
EOF

cat > "$PROFILE_DIR/panel-power.env" <<'EOF'
# SableOS Titan2 N1B2 panel power profile.
TARGET_ID=titan2
PANEL_POWER_CLASS=LCD_NO_AOD_BY_DEFAULT
AOD_DEFAULT=NO
PULSE_DEFAULT=NO_UNTIL_POWER_EVIDENCE
REAR_SUBSCREEN_GLANCE=CANDIDATE_REQUIRES_VALIDATION
TITAN2_PANEL_POWER_PROFILE_PACKAGED=YES
EOF

cat > "$PROFILE_DIR/attention.env" <<'EOF'
# SableOS Titan2 N1B2 attention surface profile.
TARGET_ID=titan2
PRIMARY_ATTENTION_SURFACE=status_bar_lockscreen_hub
SECONDARY_DISPLAY_ATTENTION=privacy_minimal_candidate
KEYBOARD_BACKLIGHT_POLICY=default_stock_until_validated
NOTIFICATION_PRIVACY_POLICY=locked_count_only_until_user_opt_in
TITAN2_ATTENTION_PROFILE_PACKAGED=YES
EOF

cat > "$PROFILE_DIR/keyboard.env" <<'EOF'
# SableOS Titan2 N1B2 keyboard profile.
TARGET_ID=titan2
PHYSICAL_KEYBOARD_PROFILE=titan2
INPUT_DEVICE_TITANKEY=required
KEYLAYOUT_POLICY=device_specific_required
KEYCHARACTERMAP_POLICY=device_specific_required
GENERIC_KL_KCM_AS_FINAL_POLICY=NO
SEMANTIC_ACTION_MAP_REQUIRED=YES
SETUP_KEYBOARD_DEFINED=YES_PENDING_RUNTIME_PROOF
LOCKSCREEN_KEYBOARD_DEFINED=YES_PENDING_RUNTIME_PROOF
TITAN2_KEYBOARD_PROFILE_PACKAGED=YES
EOF

cat > "$PROFILE_DIR/pointer.env" <<'EOF'
# SableOS Titan2 N1B2 pointer/touch surface profile.
TARGET_ID=titan2
POINTER_PROFILE=titan2_touchpad_mouse_candidate
INPUT_DEVICE_TOUCHPAD=required
SURFACE_LOCATION=separate_trackpad
RELATIVE_POINTER=to_be_validated
ABSOLUTE_TOUCH=to_be_validated
MOUSE_MODE_POLICY=bounded_stock_until_validated
TITAN2_POINTER_PROFILE_PACKAGED=YES
EOF

cat > "$PROFILE_DIR/critical-text-entry.env" <<'EOF'
# SableOS Titan2 N1B2 critical text-entry profile.
TARGET_ID=titan2
SETUP_WIZARD_KEYBOARD_SAFE=REQUIRED
WIFI_PASSWORD_ENTRY=REQUIRED
LOCKSCREEN_PIN_PASSWORD=REQUIRED
ACCOUNT_SIGN_IN=REQUIRED
EMERGENCY_TEXT_ENTRY=REQUIRED
INPUT_METHOD_SWITCHING=REQUIRED
HARDWARE_KEYBOARD_TEXT_ENTRY=REQUIRED
SOFTWARE_KEYBOARD_FALLBACK=REQUIRED
ALT_SYM_FN_TEXT_ENTRY=REQUIRED
NO_SETUP_DEAD_ENDS=REQUIRED
NO_FOCUS_TRAPS=REQUIRED
TITAN2_CRITICAL_TEXT_ENTRY_PROFILE_PACKAGED=YES
EOF

cat > "$PROFILE_DIR/app-layout.env" <<'EOF'
# SableOS Titan2 N1B2 app layout profile.
TARGET_ID=titan2
DEFAULT_HOME_LAYOUT=square_keyboard_list_card
HUB_LAYOUT=dense_square_keyboard_triage
COMMAND_OVERLAY_LAYOUT=compact_centered_keyboard_focus
SETTINGS_LAYOUT=list_first_keyboard_section_jumps
MEDIA_LAYOUT=portrait_density_review_required
THIRD_PARTY_APP_COMPATIBILITY_CLASS=square_keyboard_review_required
TITAN2_APP_LAYOUT_PROFILE_PACKAGED=YES
EOF

cat > "$MARKERS_PATH" <<EOF
# SableOS Titan2 N1B2 product-closure markers.
N1B2_PRODUCT_PROFILE=YES
N1B2_SETUP_WIZARD_REQUIRED=YES
N1B2_SETUP_WIZARD_REASON=factory_reset_required_for_first_boot
N1B2_SETUP_WIZARD_MODULE=$SETUP_MODULE
N1B2_SABLE_PRODUCT_IDENTITY_REQUIRED=YES
N1B2_DEVICE_NAME_TARGET=SableOS Titan2
N1B2_VISIBLE_SETTINGS_BRAND_TARGET=SableOS
N1B2_SABLE_HOME_REQUIRED=YES
N1B2_SABLE_HOME_MODULE=$SABLE_HOME_MODULE
N1B2_SABLE_HOME_MODULE_PRESENT=$HOME_PRESENT
N1B2_HOME_PACKAGE=org.sableos.launcher
N1B2_QUICKSTEP_ROLE=RECENTS_ONLY
N1B2_TITAN2_INPUT_PROFILE_REQUIRED=YES
N1B2_PLATFORM_PROFILE_PACKAGING_REQUIRED=YES
N1B2_MOBILE_NETWORK_TRIAGE_REQUIRED=YES
N1B2_UX_TESTBED_READINESS_MATRIX_REQUIRED=YES
N1B2_FLASH_ALLOWED=NO_SEPARATE_GATE_REQUIRED
USERDATA_WIPE_IMPLICIT_ALLOWED=NO
BOOTLOADER_RELOCK_ALLOWED=NO
AVB_MUTATION_ALLOWED=NO_UNLESS_SEPARATE_REVIEW
PUBLIC_RELEASE_WITH_STOCK_BLOBS=NO_UNLESS_SEPARATE_LICENSE_REVIEW
EOF

cat > "$UX_READINESS_PATH" <<EOF
# SableOS Titan2 N1B2 UX testbed readiness marker.
N1B2_TITAN2_UX_TESTBED_READINESS_MATRIX=PASS
N1B2_UX_TESTBED_ALLOWED_STATUS_SET=PASS_POLICY_PRESENT_EXPLICIT_BOUNDED_DEFERRAL
N1B2_UX_TESTBED_PACKAGING_GATE=PASS
N1B2_UX_TESTBED_TARGET_FILES_MARKER=REQUIRED
N1B2_UX_TESTBED_ROWS=32
N1B2_FLASH_ALLOWED=NO_SEPARATE_GATE_REQUIRED
PUBLIC_RELEASE=NO
PRODUCTION_SIGNING=NO
EOF

cat > "$PROFILE_PATH" <<EOF
# Auto-generated by build/titan2/prepare-n1b2-product-profile.sh.
# This file is intentionally source-workspace local until reviewed in evidence.

PRODUCT_PACKAGES += \\
    $SETUP_MODULE \\
    $SABLE_HOME_MODULE

PRODUCT_COPY_FILES += \\
    vendor/sable/n1b2/product-closure.env:system/etc/sableos/n1b2/product-closure.env \\
    vendor/sable/n1b2/ux-testbed-readiness.env:system/etc/sableos/n1b2/ux-testbed-readiness.env \\
    vendor/sable/n1b2/profiles/titan2/hardware.env:system/etc/sableos/profiles/titan2/hardware.env \\
    vendor/sable/n1b2/profiles/titan2/display.env:system/etc/sableos/profiles/titan2/display.env \\
    vendor/sable/n1b2/profiles/titan2/panel-power.env:system/etc/sableos/profiles/titan2/panel-power.env \\
    vendor/sable/n1b2/profiles/titan2/attention.env:system/etc/sableos/profiles/titan2/attention.env \\
    vendor/sable/n1b2/profiles/titan2/keyboard.env:system/etc/sableos/profiles/titan2/keyboard.env \\
    vendor/sable/n1b2/profiles/titan2/pointer.env:system/etc/sableos/profiles/titan2/pointer.env \\
    vendor/sable/n1b2/profiles/titan2/critical-text-entry.env:system/etc/sableos/profiles/titan2/critical-text-entry.env \\
    vendor/sable/n1b2/profiles/titan2/app-layout.env:system/etc/sableos/profiles/titan2/app-layout.env

PRODUCT_SYSTEM_PROPERTIES += \\
    ro.sableos.device=titan2 \\
    ro.sableos.release=N1B2 \\
    ro.sableos.factory_reset_first_boot_required=true \\
    ro.sableos.setup_wizard_required=true \\
    ro.sableos.home_package=org.sableos.launcher \\
    ro.sableos.quickstep_role=recents_only \\
    ro.sableos.titan2_profiles_required=true \\
    ro.sableos.critical_text_entry_required=true \\
    ro.sableos.mobile_network_triage_required=true \\
    ro.sableos.ux_testbed_readiness_required=true

PRODUCT_PRODUCT_PROPERTIES += \\
    ro.sableos.product.name=SableOS_Titan2 \\
    ro.sableos.product.brand=SableOS \\
    ro.sableos.product.model=SableOS_Titan2
EOF

INCLUDE_LINE='$(call inherit-product-if-exists, vendor/sable/n1b2/sable_n1b2_product_profile.mk)'

if [[ "$PATCH_ACTIVE_PRODUCT" == "YES" ]]; then
  if grep -Fq "$INCLUDE_LINE" "$ACTIVE_PRODUCT_PATH"; then
    echo "N1B2_ACTIVE_PRODUCT_ALREADY_PATCHED=YES"
  else
    {
      echo
      echo "# SableOS Titan2 N1B2 product-closure profile."
      echo "$INCLUDE_LINE"
    } >> "$ACTIVE_PRODUCT_PATH"
    echo "N1B2_ACTIVE_PRODUCT_PATCHED=YES path=$ACTIVE_PRODUCT_MK"
  fi
else
  echo "N1B2_ACTIVE_PRODUCT_PATCHED=NO"
  echo "N1B2_ACTIVE_PRODUCT_INCLUDE_LINE=$INCLUDE_LINE"
fi

cat <<EOF
===== N1B2 PRODUCT PROFILE PREPARED =====
ROOT=$ROOT
ANDROID_ROOT=$ANDROID_ROOT
ACTIVE_PRODUCT_MK=$ACTIVE_PRODUCT_MK
PATCH_ACTIVE_PRODUCT=$PATCH_ACTIVE_PRODUCT
N1B2_SETUP_WIZARD_MODULE=$SETUP_MODULE
N1B2_SABLE_HOME_MODULE=$SABLE_HOME_MODULE
N1B2_SABLE_HOME_MODULE_PRESENT=$HOME_PRESENT
N1B2_HOME_PACKAGE=org.sableos.launcher
N1B2_QUICKSTEP_ROLE=RECENTS_ONLY
N1B2_SABLELAUNCHER_SYNCED=YES
N1B2_SABLE_DESIGN_SYNCED=YES
N1B2_PROFILE_MK=$PROFILE_PATH
N1B2_MARKERS=$MARKERS_PATH
N1B2_UX_READINESS_MARKERS=$UX_READINESS_PATH
N1B2_PROFILE_DIR=$PROFILE_DIR
TITAN2_HARDWARE_PROFILE_PACKAGED=YES
TITAN2_DISPLAY_PROFILE_PACKAGED=YES
TITAN2_KEYBOARD_PROFILE_PACKAGED=YES
TITAN2_POINTER_PROFILE_PACKAGED=YES
TITAN2_CRITICAL_TEXT_ENTRY_PROFILE_PACKAGED=YES
TITAN2_APP_LAYOUT_PROFILE_PACKAGED=YES
DEVICE_CONTACT_AUTHORIZED=NO_OFFLINE_ONLY
ADB_COMMANDS_RUN=NO
FASTBOOT_COMMANDS_RUN=NO
FLASH_AUTHORIZED=NO
FACTORY_RESET_AUTHORIZED=NO
PUBLIC_RELEASE=NO
PRODUCTION_SIGNING=NO
N1B2_PRODUCT_PROFILE_PREPARED=PASS
EOF
