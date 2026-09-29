#!/usr/bin/env bash
set -euo pipefail

ANDROID_ROOT=""
PROFILE_REL="vendor/sable/n1b2/sable_n1b2_product_profile.mk"
MARKERS_REL="vendor/sable/n1b2/product-closure.env"
PROFILE_DIR_REL="vendor/sable/n1b2/profiles/titan2"
STALE_MTK_PAYLOAD_DIR_REL="vendor/sable/n1b2/mtk-telephony-payload"
RADIO_PROFILE="n1b3_r1"
MTK_IMS_PROPERTY="persist.sys.phh.ims.mtk"
MTK_IMS_VALUE="false"

fail() {
  echo "N1B3_RADIO_COMPAT_PRODUCT_DELTA=FAIL reason=$*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage:
  apply-n1b3-radio-compat-product-delta.sh --android-root <android-source-root>

Applies a small Titan2/N1B2 radio compatibility product-profile delta.

Scope:
  - appends an idempotent N1B3 radio-compat block to
    vendor/sable/n1b2/sable_n1b2_product_profile.mk
  - writes vendor/sable/n1b2/profiles/titan2/radio-compat.env
  - records product-closure markers for the radio-compat hypothesis

Safety:
  - no adb
  - no fastboot
  - no flashing
  - no reboot
  - no setprop/runtime mutation
  - no stock APK/JAR/SO payload import
  - fail closed if stale PR208 MTK payload residue is present
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --android-root)
      ANDROID_ROOT="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown_arg=$1"
      ;;
  esac
done

[[ -n "$ANDROID_ROOT" ]] || fail "android_root_required"
[[ -d "$ANDROID_ROOT" ]] || fail "android_root_not_found path=$ANDROID_ROOT"

ANDROID_ROOT="$(cd "$ANDROID_ROOT" && pwd)"
PROFILE_MK="$ANDROID_ROOT/$PROFILE_REL"
MARKERS_PATH="$ANDROID_ROOT/$MARKERS_REL"
PROFILE_DIR="$ANDROID_ROOT/$PROFILE_DIR_REL"
RADIO_ENV="$PROFILE_DIR/radio-compat.env"
STALE_MTK_PAYLOAD_DIR="$ANDROID_ROOT/$STALE_MTK_PAYLOAD_DIR_REL"

[[ -f "$PROFILE_MK" ]] || fail "profile_mk_missing path=$PROFILE_MK"
[[ -f "$MARKERS_PATH" ]] || fail "product_closure_missing path=$MARKERS_PATH"

if [[ -e "$STALE_MTK_PAYLOAD_DIR" ]]; then
  echo "N1B3_STALE_MTK_PAYLOAD_PRESENT=FAIL path=$STALE_MTK_PAYLOAD_DIR" >&2
  echo "N1B3_STALE_MTK_PAYLOAD_ACTION=QUARANTINE_OR_REMOVE_FROM_ANDROID_WORKSPACE_BEFORE_APPLY" >&2
  fail "stale_mtk_payload_present path=$STALE_MTK_PAYLOAD_DIR_REL"
fi

echo "N1B3_STALE_MTK_PAYLOAD_ABSENT=PASS path=$STALE_MTK_PAYLOAD_DIR_REL"

mkdir -p "$PROFILE_DIR"

cat > "$RADIO_ENV" <<EOF
# SableOS Titan2 N1B3 radio compatibility profile.
TARGET_ID=titan2
RADIO_COMPAT_PROFILE=$RADIO_PROFILE
LTE_TELEPHONY_COMPATIBILITY=KEEP_ENABLED
MTK_IMS_PHHSYSTEM_PROPERTY=$MTK_IMS_PROPERTY
MTK_IMS_PHHSYSTEM_PROPERTY_DEFAULT=$MTK_IMS_VALUE
MTK_IMS_OVERLAY_POLICY=DISABLE_DEFAULT_UNTIL_IMS_SERVICE_PRESENT
IMS_BINDING_POLICY=AOSP_DEFAULT_UNTIL_COM_MEDIATEK_IMS_VALIDATED
COM_MEDIATEK_IMS_REQUIRED_FOR_ENABLEMENT=YES
STOCK_TELEPHONY_APK_IMPORT=NO
STOCK_IMS_APK_IMPORT=NO
MTK_JAR_SO_PAYLOAD_IMPORT=NO
WWAN_DATA_DROP_REGRESSION_GATE=REQUIRED
TITAN2_RADIO_COMPAT_PROFILE_PACKAGED=YES
EOF

if ! grep -Fq "N1B3_RADIO_COMPAT_PRODUCT_DELTA=YES" "$MARKERS_PATH"; then
  cat >> "$MARKERS_PATH" <<EOF
N1B3_RADIO_COMPAT_PRODUCT_DELTA=YES
N1B3_RADIO_COMPAT_PROFILE=$RADIO_PROFILE
N1B3_MTK_IMS_DEFAULT_PROPERTY=$MTK_IMS_PROPERTY=$MTK_IMS_VALUE
N1B3_MTK_IMS_DEFAULT_DISABLED=YES
N1B3_RADIO_COMPAT_NO_STOCK_APK_IMPORT=YES
N1B3_RADIO_COMPAT_NO_MTK_JAR_SO_PAYLOAD=YES
N1B3_RADIO_COMPAT_WWAN_DROP_REGRESSION_GATE=REQUIRED
EOF
fi

if grep -Fq "# SABLE_N1B3_RADIO_COMPAT_START" "$PROFILE_MK"; then
  echo "N1B3_RADIO_COMPAT_PRODUCT_PROFILE_ALREADY_PATCHED=YES"
else
  cat >> "$PROFILE_MK" <<EOF

# SABLE_N1B3_RADIO_COMPAT_START
# Small targeted cellular compatibility delta.
# Keep LTE telephony in the base Treble stack, but do not default-enable the PHH
# MTK IMS path unless a usable com.mediatek.ims service is validated.
PRODUCT_COPY_FILES += \\
    vendor/sable/n1b2/profiles/titan2/radio-compat.env:system/etc/sableos/profiles/titan2/radio-compat.env

PRODUCT_SYSTEM_PROPERTIES += \\
    $MTK_IMS_PROPERTY=$MTK_IMS_VALUE \\
    ro.sableos.radio_compat.profile=$RADIO_PROFILE \\
    ro.sableos.radio_compat.mtk_ims_default=disabled_until_service_present \\
    ro.sableos.radio_compat.no_stock_telephony_payload=true \\
    ro.sableos.radio_compat.wwan_drop_regression_gate=required
# SABLE_N1B3_RADIO_COMPAT_END
EOF
  echo "N1B3_RADIO_COMPAT_PRODUCT_PROFILE_PATCHED=YES path=$PROFILE_REL"
fi

grep -Fq "$MTK_IMS_PROPERTY=$MTK_IMS_VALUE" "$PROFILE_MK" \
  || fail "mtk_ims_property_missing path=$PROFILE_REL"
grep -Fq "radio-compat.env:system/etc/sableos/profiles/titan2/radio-compat.env" "$PROFILE_MK" \
  || fail "radio_compat_copy_missing path=$PROFILE_REL"
grep -Fq "TITAN2_RADIO_COMPAT_PROFILE_PACKAGED=YES" "$RADIO_ENV" \
  || fail "radio_env_marker_missing path=$RADIO_ENV"

cat <<EOF
===== N1B3 RADIO COMPAT PRODUCT DELTA =====
ANDROID_ROOT=$ANDROID_ROOT
PROFILE_MK=$PROFILE_MK
PRODUCT_CLOSURE_MARKERS=$MARKERS_PATH
RADIO_COMPAT_ENV=$RADIO_ENV
N1B3_RADIO_COMPAT_PROFILE=$RADIO_PROFILE
N1B3_MTK_IMS_PROPERTY_DEFAULT=$MTK_IMS_PROPERTY=$MTK_IMS_VALUE
N1B3_MTK_IMS_DEFAULT_DISABLED=PASS
N1B3_STALE_MTK_PAYLOAD_ABSENT=PASS
TITAN2_RADIO_COMPAT_PROFILE_PACKAGED=YES
STOCK_TELEPHONY_APK_IMPORT=NO
STOCK_IMS_APK_IMPORT=NO
MTK_JAR_SO_PAYLOAD_IMPORT=NO
DEVICE_CONTACT_AUTHORIZED=NO_OFFLINE_ONLY
ADB_COMMANDS_RUN=NO
FASTBOOT_COMMANDS_RUN=NO
FLASH_AUTHORIZED=NO
REBOOT_AUTHORIZED=NO
RUNTIME_PROPERTY_MUTATION=NO
N1B3_RADIO_COMPAT_PRODUCT_DELTA=PASS
EOF
