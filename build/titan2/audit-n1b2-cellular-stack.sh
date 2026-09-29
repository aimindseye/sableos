#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  build/titan2/audit-n1b2-cellular-stack.sh [--evidence-dir DIR]

Optional environment inputs:
  STOCK_ROOT       Extracted stock firmware/root tree, known-good reference.
  N1B1_ROOT        Extracted N1B1 image/root tree, failing sample 1.
  N1B2_ROOT        Extracted N1B2 candidate/root tree, failing sample 2.
  RESTLESS_ROOT    RestlessOS source or extracted image tree, candidate source.
  AOSP_ROOT        AOSP/Treble GSI source or extracted image tree, candidate source.

This script is static/read-only. It does not build images, modify sources,
contact devices, use adb, use fastboot, or use fastbootd.
USAGE
}

EVIDENCE_DIR="${EVIDENCE_DIR:-/tmp/SABLE_N1B2_CELLULAR_STATIC_$(date -u +%Y%m%dT%H%M%SZ)}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --evidence-dir)
      EVIDENCE_DIR="$2"
      shift 2
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

mkdir -p "$EVIDENCE_DIR"
SUMMARY="$EVIDENCE_DIR/summary.tsv"
CANDIDATES="$EVIDENCE_DIR/cellular-candidate-files.tsv"
DIFF_REPORT="$EVIDENCE_DIR/common-failure-vs-stock-candidates.tsv"
MARKERS="$EVIDENCE_DIR/static-markers.txt"

: > "$SUMMARY"
: > "$CANDIDATES"
: > "$DIFF_REPORT"
: > "$MARKERS"

printf 'sample\trole\troot\tstatus\n' > "$SUMMARY"
printf 'sample\tcategory\tpath\n' > "$CANDIDATES"
printf 'category\tstock_path\tn1b1_present\tn1b2_present\tpriority\n' > "$DIFF_REPORT"

log_marker() {
  echo "$1" | tee -a "$MARKERS"
}

record_sample() {
  local name="$1"
  local role="$2"
  local root="$3"
  if [[ -n "$root" && -d "$root" ]]; then
    printf '%s\t%s\t%s\tPRESENT\n' "$name" "$role" "$root" >> "$SUMMARY"
    log_marker "N1B2_CELLULAR_STATIC_${name}_ROOT=PASS path=$root"
    return 0
  fi
  printf '%s\t%s\t%s\tMISSING\n' "$name" "$role" "${root:-UNSET}" >> "$SUMMARY"
  log_marker "N1B2_CELLULAR_STATIC_${name}_ROOT=WARN path=${root:-UNSET}"
  return 1
}

emit_matches() {
  local name="$1"
  local root="$2"
  local category="$3"
  shift 3
  [[ -d "$root" ]] || return 0
  find "$root" \
    \( -type f -o -type l \) \
    \( "$@" \) \
    -printf '%P\n' 2>/dev/null \
    | sort -u \
    | awk -v sample="$name" -v category="$category" 'BEGIN { OFS="\t" } { print sample, category, $0 }' \
    >> "$CANDIDATES"
}

sample_present() {
  local sample="$1"
  local rel="$2"
  awk -F '\t' -v sample="$sample" -v rel="$rel" '$1 == sample && $3 == rel { found=1 } END { exit found ? 0 : 1 }' "$CANDIDATES"
}

stock_missing_in_failures() {
  local category="$1"
  awk -F '\t' -v category="$category" '$1 == "stock" && $2 == category { print $3 }' "$CANDIDATES" \
    | while IFS= read -r rel; do
        n1b1="NO"
        n1b2="NO"
        sample_present "n1b1" "$rel" && n1b1="YES"
        sample_present "n1b2" "$rel" && n1b2="YES"
        priority="LOW"
        if [[ "$n1b1" == "NO" && "$n1b2" == "NO" ]]; then
          priority="HIGH_STOCK_PRESENT_MISSING_BOTH_FAILURES"
        elif [[ "$n1b1" == "NO" || "$n1b2" == "NO" ]]; then
          priority="MEDIUM_STOCK_PRESENT_MISSING_ONE_FAILURE"
        fi
        printf '%s\t%s\t%s\t%s\t%s\n' "$category" "$rel" "$n1b1" "$n1b2" "$priority"
      done >> "$DIFF_REPORT"
}

echo "===== N1B2 CELLULAR STATIC AUDIT ====="
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "STATIC_ONLY=YES"
echo "DEVICE_CONTACT=NO"
echo "ADB_USED=NO"
echo "FASTBOOT_USED=NO"
echo "FASTBOOTD_USED=NO"
echo "IMAGE_BUILD=NO"
echo "FLASH_ENABLEMENT=NO"
echo "SOURCE_MUTATION=NO"

record_sample "stock" "known_good_reference" "${STOCK_ROOT:-}" || true
record_sample "n1b1" "failing_sample_1" "${N1B1_ROOT:-}" || true
record_sample "n1b2" "failing_sample_2" "${N1B2_ROOT:-}" || true
record_sample "restless" "candidate_source" "${RESTLESS_ROOT:-}" || true
record_sample "aosp" "candidate_source" "${AOSP_ROOT:-}" || true

for sample in stock n1b1 n1b2 restless aosp; do
  var="$(printf '%s_ROOT' "$sample" | tr '[:lower:]' '[:upper:]')"
  root="${!var:-}"
  [[ -d "$root" ]] || continue

  emit_matches "$sample" "$root" "telephony_packages" \
    -iname '*TeleService*' -o -iname '*TelephonyProvider*' -o -iname '*Telecom*' \
    -o -iname '*CarrierConfig*' -o -iname '*CellBroadcast*' -o -iname '*Stk*' \
    -o -iname '*Euicc*' -o -iname '*Lpa*' -o -iname '*MmsService*' \
    -o -iname '*Ims*' -o -iname '*Rcs*' -o -iname '*Mbms*' -o -iname 'ims.apk'

  emit_matches "$sample" "$root" "privapp_permissions" \
    -path '*/etc/permissions/*privapp*' -o -path '*/etc/permissions/privapp-permissions*' \
    -o -path '*/etc/sysconfig/*'

  emit_matches "$sample" "$root" "telephony_overlays_configs" \
    -path '*/overlay/*' -o -path '*/product/overlay/*' -o -path '*/vendor/overlay/*' \
    -o -iname '*apns*' -o -iname '*carrier*config*' -o -iname '*telephony*xml' \
    -o -iname '*mms*' -o -iname '*mbn*'

  emit_matches "$sample" "$root" "radio_vendor_init_vintf" \
    -path '*/etc/init/*radio*' -o -path '*/etc/init/*ril*' -o -path '*/etc/init/*ims*' \
    -o -path '*/etc/vintf/*' -o -iname '*radio*.so' -o -iname '*ims*.so' \
    -o -iname '*ril*.so' -o -iname '*mtk*radio*' -o -iname '*vendor*radio*'
done

for category in telephony_packages privapp_permissions telephony_overlays_configs radio_vendor_init_vintf; do
  stock_missing_in_failures "$category"
done

if [[ -s "$CANDIDATES" ]]; then
  log_marker "N1B2_CELLULAR_STATIC_CANDIDATE_SCAN=PASS path=$CANDIDATES"
else
  log_marker "N1B2_CELLULAR_STATIC_CANDIDATE_SCAN=WARN no_candidates_found"
fi

if grep -Fq 'HIGH_STOCK_PRESENT_MISSING_BOTH_FAILURES' "$DIFF_REPORT"; then
  log_marker "N1B2_CELLULAR_STATIC_STOCK_VS_COMMON_FAILURE_DIFF=PASS path=$DIFF_REPORT"
else
  log_marker "N1B2_CELLULAR_STATIC_STOCK_VS_COMMON_FAILURE_DIFF=WARN no_high_priority_static_diff_yet"
fi

log_marker "N1B2_CELLULAR_STATIC_AUDIT=PASS evidence_dir=$EVIDENCE_DIR"

echo "SUMMARY=$SUMMARY"
echo "CANDIDATES=$CANDIDATES"
echo "DIFF_REPORT=$DIFF_REPORT"
echo "MARKERS=$MARKERS"
