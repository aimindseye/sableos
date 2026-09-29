#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  build/titan2/stage-n1b2-mtk-telephony-payload.sh \
    --stock-root DIR \
    --evidence-dir DIR \
    [--stage-dir DIR] \
    [--copy-payload YES|NO]

This script stages/verifies the current PR208 boot-safe Titan 2 stock-derived
payload manifest. It classifies the larger stock MTK telephony/IMS candidate set
into:

  CLASS_A_BOOT_SAFE_CONFIG     copied into the image candidate
  CLASS_B_SIGNATURE_BLOCKED    never copied; shared UID / duplicate package risk
  CLASS_C_CONDITIONAL          never copied in the control image; layer later

Default:
  COPY_PAYLOAD=NO
USAGE
}

STOCK_ROOT="${STOCK_ROOT:-}"
EVIDENCE_DIR="${EVIDENCE_DIR:-/tmp/SABLE_N1B2_MTK_PAYLOAD_$(date -u +%Y%m%dT%H%M%SZ)}"
STAGE_DIR="${STAGE_DIR:-}"
COPY_PAYLOAD="${COPY_PAYLOAD:-NO}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stock-root)
      STOCK_ROOT="$2"
      shift 2
      ;;
    --stock-root=*)
      STOCK_ROOT="${1#*=}"
      shift
      ;;
    --evidence-dir)
      EVIDENCE_DIR="$2"
      shift 2
      ;;
    --evidence-dir=*)
      EVIDENCE_DIR="${1#*=}"
      shift
      ;;
    --stage-dir)
      STAGE_DIR="$2"
      shift 2
      ;;
    --stage-dir=*)
      STAGE_DIR="${1#*=}"
      shift
      ;;
    --copy-payload)
      COPY_PAYLOAD="$2"
      shift 2
      ;;
    --copy-payload=*)
      COPY_PAYLOAD="${1#*=}"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "UNKNOWN_ARG=$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$STOCK_ROOT" || ! -d "$STOCK_ROOT" ]]; then
  echo "STOCK_ROOT_REQUIRED=$STOCK_ROOT" >&2
  exit 2
fi

case "$COPY_PAYLOAD" in
  YES|NO) ;;
  *)
    echo "COPY_PAYLOAD_INVALID=$COPY_PAYLOAD" >&2
    exit 2
    ;;
esac

if [[ -z "$STAGE_DIR" ]]; then
  STAGE_DIR="$EVIDENCE_DIR/staged-payload"
fi

mkdir -p "$EVIDENCE_DIR" "$STAGE_DIR"

MANIFEST="$EVIDENCE_DIR/pr208-stock-mtk-telephony-payload-manifest.tsv"
MISSING="$EVIDENCE_DIR/pr208-stock-mtk-telephony-payload-missing.tsv"
EXCLUDED="$EVIDENCE_DIR/pr208-stock-mtk-telephony-payload-excluded.tsv"
NATIVE_DEPS="$EVIDENCE_DIR/pr208-stock-mtk-native-deps.tsv"
MARKERS="$EVIDENCE_DIR/pr208-stock-mtk-payload-markers.txt"

: > "$MARKERS"
: > "$MISSING"

log_marker() {
  echo "$1" | tee -a "$MARKERS"
}

resolve_stock_path() {
  local rel="$1"

  for p in \
    "$STOCK_ROOT/$rel" \
    "$STOCK_ROOT/system/$rel" \
    "$STOCK_ROOT/system/${rel#system/}" \
    "$STOCK_ROOT/system_ext/$rel" \
    "$STOCK_ROOT/system_ext/${rel#system_ext/}" \
    "$STOCK_ROOT/product/$rel" \
    "$STOCK_ROOT/product/${rel#product/}"
  do
    if [[ -f "$p" ]]; then
      printf '%s\n' "$p"
      return 0
    fi
  done

  return 1
}

boot_safe_payload_list() {
  cat <<'PAYLOAD'
system/etc/apns-conf.xml
system/etc/permissions/privapp-permissions-mediatek.xml
system_ext/etc/sysconfig/com.mediatek.ims.config.xml
PAYLOAD
}

excluded_payload_list() {
  cat <<'PAYLOAD'
system/priv-app/MtkMmsService/MtkMmsService.apk	CLASS_B_SIGNATURE_BLOCKED	android.uid.phone shared UID / duplicate GSI package risk
system/priv-app/MtkTelecom/MtkTelecom.apk	CLASS_B_SIGNATURE_BLOCKED	android.uid.system or platform shared UID / duplicate GSI package risk
system/priv-app/MtkTelephonyProvider/MtkTelephonyProvider.apk	CLASS_B_SIGNATURE_BLOCKED	android.uid.phone shared UID / duplicate GSI package risk
system/priv-app/MtkTeleService/MtkTeleService.apk	CLASS_B_SIGNATURE_BLOCKED	boot-fatal com.android.phone android.uid.phone signature mismatch
system_ext/priv-app/ImsService/ImsService.apk	CLASS_C_CONDITIONAL_APK	manifest/shared UID must be audited before inclusion
system_ext/framework/mediatek-carrier-config-manager.jar	CLASS_C_CONDITIONAL_JAR	no proven boot-safe consumer without MTK TeleService
system_ext/framework/mediatek-ims-base.jar	CLASS_C_CONDITIONAL_JAR	no proven boot-safe consumer without MTK TeleService
system_ext/framework/mediatek-ims-common.jar	CLASS_C_CONDITIONAL_JAR	no proven boot-safe consumer without MTK TeleService
system_ext/framework/mediatek-ims-extension-plugin.jar	CLASS_C_CONDITIONAL_JAR	no proven boot-safe consumer without MTK TeleService
system_ext/framework/mediatek-telecom-common.jar	CLASS_C_CONDITIONAL_JAR	no proven boot-safe consumer without MTK TeleService
system_ext/lib64/libimsma.so	CLASS_C_CONDITIONAL_NATIVE	stage only after duplicate-lib and consumer audit
system_ext/lib64/libimsma_adapt.so	CLASS_C_CONDITIONAL_NATIVE	stage only after duplicate-lib and consumer audit
system_ext/lib64/libimsma_rtp.so	CLASS_C_CONDITIONAL_NATIVE	stage only after duplicate-lib and consumer audit
system_ext/lib64/libimsma_socketwrapper.so	CLASS_C_CONDITIONAL_NATIVE	stage only after duplicate-lib and consumer audit
system_ext/lib64/libsink.so	CLASS_C_CONDITIONAL_NATIVE	dependency closure held until IMS/native consumer audit
system_ext/lib64/libsource.so	CLASS_C_CONDITIONAL_NATIVE	dependency closure held until IMS/native consumer audit
system_ext/lib64/libvcodec_cap.so	CLASS_C_CONDITIONAL_NATIVE	dependency closure held until IMS/native consumer audit
system_ext/lib64/libcomutils.so	CLASS_C_CONDITIONAL_NATIVE	dependency closure held until IMS/native consumer audit
system_ext/lib64/libsignal.so	CLASS_C_CONDITIONAL_NATIVE	dependency closure held until IMS/native consumer audit
PAYLOAD
}

printf 'target_path\tsource_path\tkind\tsha256\tsize\tcopied\n' > "$MANIFEST"
printf 'target_path\n' > "$MISSING"
printf 'target_path\tclass\treason\tsource_path\tsha256\tsize\tpresent\n' > "$EXCLUDED"
printf 'object\tneeded_library\n' > "$NATIVE_DEPS"

missing_count=0
copied_count=0
present_count=0

while IFS= read -r rel; do
  [[ -n "$rel" ]] || continue

  if src="$(resolve_stock_path "$rel")"; then
    sha="$(sha256sum "$src" | awk '{print $1}')"
    size="$(stat -c '%s' "$src")"
    kind="$(file -b "$src" | tr '\t' ' ')"
    copied="NO"

    if [[ "$COPY_PAYLOAD" == "YES" ]]; then
      install -D -m 0644 "$src" "$STAGE_DIR/$rel"
      copied="YES"
      copied_count=$((copied_count + 1))
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$rel" "$src" "$kind" "$sha" "$size" "$copied" >> "$MANIFEST"

    present_count=$((present_count + 1))
  else
    printf '%s\n' "$rel" >> "$MISSING"
    missing_count=$((missing_count + 1))
  fi
done < <(boot_safe_payload_list)

excluded_total_count=0
excluded_present_count=0
excluded_missing_count=0
excluded_signature_blocked_count=0
excluded_conditional_count=0

while IFS=$'\t' read -r rel class reason; do
  [[ -n "$rel" ]] || continue
  excluded_total_count=$((excluded_total_count + 1))

  case "$class" in
    CLASS_B_SIGNATURE_BLOCKED*) excluded_signature_blocked_count=$((excluded_signature_blocked_count + 1)) ;;
    CLASS_C_CONDITIONAL*) excluded_conditional_count=$((excluded_conditional_count + 1)) ;;
  esac

  if src="$(resolve_stock_path "$rel")"; then
    sha="$(sha256sum "$src" | awk '{print $1}')"
    size="$(stat -c '%s' "$src")"
    present="YES"
    excluded_present_count=$((excluded_present_count + 1))
  else
    src=""
    sha=""
    size=""
    present="NO"
    excluded_missing_count=$((excluded_missing_count + 1))
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$rel" "$class" "$reason" "$src" "$sha" "$size" "$present" >> "$EXCLUDED"
done < <(excluded_payload_list)

log_marker "N1B2_MTK_PAYLOAD_STATIC_ONLY=YES"
log_marker "N1B2_MTK_PAYLOAD_PROFILE=BOOT_SAFE_CONFIG_ONLY"
log_marker "N1B2_MTK_PAYLOAD_STOCK_ROOT=$STOCK_ROOT"
log_marker "N1B2_MTK_PAYLOAD_EVIDENCE_DIR=$EVIDENCE_DIR"
log_marker "N1B2_MTK_PAYLOAD_STAGE_DIR=$STAGE_DIR"
log_marker "N1B2_MTK_PAYLOAD_COPY_PAYLOAD=$COPY_PAYLOAD"
log_marker "N1B2_MTK_PAYLOAD_PRESENT_COUNT=$present_count"
log_marker "N1B2_MTK_PAYLOAD_MISSING_COUNT=$missing_count"
log_marker "N1B2_MTK_PAYLOAD_COPIED_COUNT=$copied_count"
log_marker "N1B2_MTK_PAYLOAD_MANIFEST=$MANIFEST"
log_marker "N1B2_MTK_PAYLOAD_EXCLUDED_MANIFEST=$EXCLUDED"
log_marker "N1B2_MTK_PAYLOAD_EXCLUDED_TOTAL_COUNT=$excluded_total_count"
log_marker "N1B2_MTK_PAYLOAD_EXCLUDED_PRESENT_COUNT=$excluded_present_count"
log_marker "N1B2_MTK_PAYLOAD_EXCLUDED_MISSING_COUNT=$excluded_missing_count"
log_marker "N1B2_MTK_PAYLOAD_EXCLUDED_SIGNATURE_BLOCKED_COUNT=$excluded_signature_blocked_count"
log_marker "N1B2_MTK_PAYLOAD_EXCLUDED_CONDITIONAL_COUNT=$excluded_conditional_count"
log_marker "N1B2_MTK_PAYLOAD_NATIVE_DEPS=$NATIVE_DEPS"
log_marker "N1B2_MTK_PAYLOAD_STOCK_APKS_IN_BOOT_SAFE=NO"
log_marker "N1B2_MTK_PAYLOAD_STOCK_JARS_IN_BOOT_SAFE=NO"
log_marker "N1B2_MTK_PAYLOAD_STOCK_NATIVE_LIBS_IN_BOOT_SAFE=NO"
log_marker "N1B2_MTK_PAYLOAD_VENDOR_PARTITION_COPY=NO"
log_marker "N1B2_MTK_PAYLOAD_FASTBOOT_USED=NO"
log_marker "N1B2_MTK_PAYLOAD_ADB_USED=NO"
log_marker "N1B2_MTK_PAYLOAD_IMAGE_BUILD=NO"
log_marker "N1B2_MTK_PAYLOAD_SOURCE_MUTATION=NO"

if [[ "$missing_count" -eq 0 ]]; then
  log_marker "N1B2_MTK_PAYLOAD_STAGE=PASS"
else
  log_marker "N1B2_MTK_PAYLOAD_STAGE=FAIL"
  exit 1
fi

echo "MANIFEST=$MANIFEST"
echo "MISSING=$MISSING"
echo "EXCLUDED=$EXCLUDED"
echo "NATIVE_DEPS=$NATIVE_DEPS"
echo "MARKERS=$MARKERS"
