#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  build/titan2/audit-n1b2-stock-telephony-apks.sh \
    --stock-root DIR \
    --evidence-dir DIR \
    [--android-src DIR]

Audits Titan 2 stock telephony/IMS APK manifests before any image build or
flash. The audit classifies stock APKs by package name, sharedUserId, duplicate
AOSP package risk, and signing-certificate digest. It does not copy payload,
modify source, build images, use adb, use fastboot, or flash.

The audit is intentionally conservative:
- APKs that duplicate AOSP/system phone packages are BLOCKED.
- APKs declaring android.uid.phone/android.uid.system or any sharedUserId are BLOCKED.
- MTK ImsService may only be CONDITIONAL when its manifest has no shared UID and
  does not duplicate a core AOSP phone package; runtime testing still requires a
  separate controlled build.
USAGE
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STOCK_ROOT="${STOCK_ROOT:-}"
ANDROID_SRC="${ANDROID_SRC:-}"
EVIDENCE_DIR="${EVIDENCE_DIR:-/tmp/SABLE_N1B2_STOCK_APK_AUDIT_$(date -u +%Y%m%dT%H%M%SZ)}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stock-root) STOCK_ROOT="$2"; shift 2 ;;
    --stock-root=*) STOCK_ROOT="${1#*=}"; shift ;;
    --android-src) ANDROID_SRC="$2"; shift 2 ;;
    --android-src=*) ANDROID_SRC="${1#*=}"; shift ;;
    --evidence-dir) EVIDENCE_DIR="$2"; shift 2 ;;
    --evidence-dir=*) EVIDENCE_DIR="${1#*=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "UNKNOWN_ARG=$1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -n "$STOCK_ROOT" && -d "$STOCK_ROOT" ]] || {
  echo "N1B2_STOCK_APK_AUDIT=FAIL_STOCK_ROOT_REQUIRED path=$STOCK_ROOT"
  exit 2
}

STOCK_ROOT="$(cd "$STOCK_ROOT" && pwd)"
if [[ -n "$ANDROID_SRC" ]]; then
  [[ -d "$ANDROID_SRC" ]] || {
    echo "N1B2_STOCK_APK_AUDIT=FAIL_ANDROID_SRC path=$ANDROID_SRC"
    exit 2
  }
  ANDROID_SRC="$(cd "$ANDROID_SRC" && pwd)"
fi

mkdir -p "$EVIDENCE_DIR" "$EVIDENCE_DIR/manifest-dumps" "$EVIDENCE_DIR/certs"
EVIDENCE_DIR="$(cd "$EVIDENCE_DIR" && pwd)"

REPORT="$EVIDENCE_DIR/n1b2-stock-telephony-apk-audit.tsv"
MARKERS="$EVIDENCE_DIR/n1b2-stock-telephony-apk-audit-markers.txt"
BLOCKED="$EVIDENCE_DIR/n1b2-stock-telephony-apk-blocked.tsv"
CONDITIONAL="$EVIDENCE_DIR/n1b2-stock-telephony-apk-conditional.tsv"

: > "$MARKERS"

log_marker() {
  echo "$1" | tee -a "$MARKERS"
}

find_tool() {
  local name="$1"
  shift

  local p
  for p in "$@"; do
    [[ -n "$p" ]] || continue
    if [[ -x "$p" ]]; then
      printf '%s\n' "$p"
      return 0
    fi
  done

  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
    return 0
  fi

  return 1
}

AAPT2_PATH="$(find_tool aapt2 \
  "${AAPT2:-}" \
  "${ANDROID_SRC:+$ANDROID_SRC/out/host/linux-x86/bin/aapt2}" \
  "${ANDROID_SRC:+$ANDROID_SRC/prebuilts/sdk/tools/linux/bin/aapt2}" \
  "${ANDROID_SRC:+$ANDROID_SRC/prebuilts/sdk/current/androidx/aapt2/aapt2}" \
  || true)"

APKSIGNER_PATH="$(find_tool apksigner \
  "${APKSIGNER:-}" \
  "${ANDROID_SRC:+$ANDROID_SRC/prebuilts/sdk/tools/linux/bin/apksigner}" \
  "${ANDROID_SRC:+$ANDROID_SRC/out/host/linux-x86/bin/apksigner}" \
  || true)"

if [[ -z "$AAPT2_PATH" ]]; then
  log_marker "N1B2_STOCK_APK_AUDIT=FAIL_AAPT2_NOT_FOUND"
  log_marker "N1B2_STOCK_APK_AUDIT_STOCK_ROOT=$STOCK_ROOT"
  log_marker "N1B2_STOCK_APK_AUDIT_ANDROID_SRC=$ANDROID_SRC"
  echo "AAPT2_REQUIRED=YES" >&2
  exit 69
fi

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

apk_list() {
  cat <<'APKS'
system/priv-app/MtkMmsService/MtkMmsService.apk
system/priv-app/MtkTelecom/MtkTelecom.apk
system/priv-app/MtkTelephonyProvider/MtkTelephonyProvider.apk
system/priv-app/MtkTeleService/MtkTeleService.apk
system_ext/priv-app/ImsService/ImsService.apk
APKS
}

extract_raw_attr() {
  local pattern="$1"
  local file="$2"

  grep -m1 -E "$pattern" "$file" \
    | sed -E 's/.*\(Raw: "([^"]+)"\).*/\1/; t; s/.*="([^"]+)".*/\1/; t; s/.*: ([^ ]+) .*/\1/' \
    || true
}

classify_apk() {
  local rel="$1"
  local pkg="$2"
  local shared_uid="$3"

  case "$rel" in
    system/priv-app/MtkTeleService/MtkTeleService.apk)
      echo "BLOCKED\tBOOT_FATAL_DUPLICATES_COM_ANDROID_PHONE_SHARED_UID_ANDROID_UID_PHONE"
      return 0
      ;;
    system/priv-app/MtkTelephonyProvider/MtkTelephonyProvider.apk)
      echo "BLOCKED\tDUPLICATES_COM_ANDROID_PROVIDERS_TELEPHONY_EXPECTED_SHARED_UID_PHONE"
      return 0
      ;;
    system/priv-app/MtkMmsService/MtkMmsService.apk)
      echo "BLOCKED\tDUPLICATES_COM_ANDROID_MMS_SERVICE_EXPECTED_SHARED_UID_PHONE"
      return 0
      ;;
    system/priv-app/MtkTelecom/MtkTelecom.apk)
      echo "BLOCKED\tDUPLICATES_COM_ANDROID_SERVER_TELECOM_EXPECTED_SYSTEM_SIGNATURE_SPACE"
      return 0
      ;;
  esac

  if [[ -n "$shared_uid" ]]; then
    echo "BLOCKED\tDECLARES_SHARED_USER_ID_$shared_uid"
    return 0
  fi

  case "$pkg" in
    com.android.phone|com.android.providers.telephony|com.android.mms.service|com.android.server.telecom)
      echo "BLOCKED\tDUPLICATES_CORE_AOSP_TELEPHONY_PACKAGE_$pkg"
      return 0
      ;;
    com.mediatek.ims|*)
      echo "CONDITIONAL\tNO_SHARED_UID_NO_CORE_AOSP_DUPLICATE_REQUIRES_RUNTIME_CONSUMER_TEST"
      return 0
      ;;
  esac
}

printf 'apk_rel\tsource_path\tpackage\tshared_user_id\tclass\treason\tsha256\tsize\tcert_sha256\tmanifest_dump\n' > "$REPORT"
printf 'apk_rel\tpackage\tshared_user_id\treason\n' > "$BLOCKED"
printf 'apk_rel\tpackage\tshared_user_id\treason\n' > "$CONDITIONAL"

checked_count=0
missing_count=0
blocked_count=0
conditional_count=0
parse_failures=0
ims_class="MISSING"

while IFS= read -r rel; do
  [[ -n "$rel" ]] || continue

  if ! src="$(resolve_stock_path "$rel")"; then
    printf '%s\n' "$rel" >> "$EVIDENCE_DIR/missing-apks.txt"
    missing_count=$((missing_count + 1))
    continue
  fi

  checked_count=$((checked_count + 1))
  safe_name="$(echo "$rel" | tr '/.' '__')"
  dump="$EVIDENCE_DIR/manifest-dumps/$safe_name.xmltree.txt"
  cert_dump="$EVIDENCE_DIR/certs/$safe_name.apksigner.txt"

  if ! "$AAPT2_PATH" dump xmltree --file AndroidManifest.xml "$src" > "$dump" 2>&1; then
    parse_failures=$((parse_failures + 1))
    pkg=""
    shared_uid=""
    class="BLOCKED"
    reason="AAPT2_MANIFEST_PARSE_FAILED"
  else
    pkg="$(extract_raw_attr 'A: .*package' "$dump")"
    shared_uid="$(extract_raw_attr 'sharedUserId' "$dump")"
    if [[ -z "$pkg" ]]; then
      parse_failures=$((parse_failures + 1))
      class="BLOCKED"
      reason="PACKAGE_NAME_PARSE_FAILED"
    else
      class_reason="$(classify_apk "$rel" "$pkg" "$shared_uid")"
      class="$(printf '%s' "$class_reason" | cut -f1)"
      reason="$(printf '%s' "$class_reason" | cut -f2-)"
    fi
  fi

  cert_sha="UNAVAILABLE"
  if [[ -n "$APKSIGNER_PATH" ]]; then
    "$APKSIGNER_PATH" verify --print-certs "$src" > "$cert_dump" 2>&1 || true
    cert_sha="$(grep -m1 -E 'SHA-256 digest:' "$cert_dump" | sed -E 's/.*SHA-256 digest:[[:space:]]*//' || true)"
    [[ -n "$cert_sha" ]] || cert_sha="UNAVAILABLE"
  else
    echo "APKSIGNER_NOT_FOUND" > "$cert_dump"
  fi

  sha="$(sha256sum "$src" | awk '{print $1}')"
  size="$(stat -c '%s' "$src")"

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$rel" "$src" "$pkg" "$shared_uid" "$class" "$reason" "$sha" "$size" "$cert_sha" "$dump" \
    >> "$REPORT"

  case "$class" in
    BLOCKED)
      blocked_count=$((blocked_count + 1))
      printf '%s\t%s\t%s\t%s\n' "$rel" "$pkg" "$shared_uid" "$reason" >> "$BLOCKED"
      ;;
    CONDITIONAL)
      conditional_count=$((conditional_count + 1))
      printf '%s\t%s\t%s\t%s\n' "$rel" "$pkg" "$shared_uid" "$reason" >> "$CONDITIONAL"
      ;;
    *)
      parse_failures=$((parse_failures + 1))
      ;;
  esac

  if [[ "$rel" == "system_ext/priv-app/ImsService/ImsService.apk" ]]; then
    ims_class="$class"
  fi
done < <(apk_list)

log_marker "N1B2_STOCK_APK_AUDIT=PASS"
log_marker "N1B2_STOCK_APK_AUDIT_STATIC_ONLY=YES"
log_marker "N1B2_STOCK_APK_AUDIT_STOCK_ROOT=$STOCK_ROOT"
log_marker "N1B2_STOCK_APK_AUDIT_ANDROID_SRC=$ANDROID_SRC"
log_marker "N1B2_STOCK_APK_AUDIT_AAPT2=$AAPT2_PATH"
log_marker "N1B2_STOCK_APK_AUDIT_APKSIGNER=${APKSIGNER_PATH:-UNAVAILABLE}"
log_marker "N1B2_STOCK_APK_AUDIT_CHECKED_COUNT=$checked_count"
log_marker "N1B2_STOCK_APK_AUDIT_MISSING_COUNT=$missing_count"
log_marker "N1B2_STOCK_APK_AUDIT_BLOCKED_COUNT=$blocked_count"
log_marker "N1B2_STOCK_APK_AUDIT_CONDITIONAL_COUNT=$conditional_count"
log_marker "N1B2_STOCK_APK_AUDIT_PARSE_FAILURES=$parse_failures"
log_marker "N1B2_STOCK_APK_AUDIT_IMSSERVICE_CLASS=$ims_class"
log_marker "N1B2_STOCK_APK_AUDIT_REPORT=$REPORT"
log_marker "N1B2_STOCK_APK_AUDIT_BLOCKED=$BLOCKED"
log_marker "N1B2_STOCK_APK_AUDIT_CONDITIONAL=$CONDITIONAL"
log_marker "N1B2_STOCK_APK_AUDIT_ADB_USED=NO"
log_marker "N1B2_STOCK_APK_AUDIT_FASTBOOT_USED=NO"
log_marker "N1B2_STOCK_APK_AUDIT_FLASH_USED=NO"
log_marker "N1B2_STOCK_APK_AUDIT_IMAGE_BUILD=NO"
log_marker "N1B2_STOCK_APK_AUDIT_SOURCE_MUTATION=NO"

if [[ "$missing_count" -ne 0 || "$parse_failures" -ne 0 ]]; then
  log_marker "N1B2_STOCK_APK_AUDIT_RESULT=FAIL"
  exit 1
fi

log_marker "N1B2_STOCK_APK_AUDIT_RESULT=PASS"

echo "REPORT=$REPORT"
echo "BLOCKED=$BLOCKED"
echo "CONDITIONAL=$CONDITIONAL"
echo "MARKERS=$MARKERS"
