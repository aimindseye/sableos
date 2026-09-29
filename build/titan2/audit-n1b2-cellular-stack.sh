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

Performance controls:
  FIND_TIMEOUT_SECONDS  Max seconds per sample root scan. Default: 180.

This script is static/read-only. It does not build images, modify sources,
contact devices, use adb, use fastboot, or use fastbootd.
USAGE
}

EVIDENCE_DIR="${EVIDENCE_DIR:-/tmp/SABLE_N1B2_CELLULAR_STATIC_$(date -u +%Y%m%dT%H%M%SZ)}"
FIND_TIMEOUT_SECONDS="${FIND_TIMEOUT_SECONDS:-180}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --evidence-dir)
      if [[ $# -lt 2 ]]; then
        echo "ARG_VALUE_REQUIRED=--evidence-dir" >&2
        exit 2
      fi
      EVIDENCE_DIR="$2"
      shift 2
      ;;
    --evidence-dir=*)
      EVIDENCE_DIR="${1#*=}"
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

mkdir -p "$EVIDENCE_DIR" "$EVIDENCE_DIR/indexes"
SUMMARY="$EVIDENCE_DIR/summary.tsv"
CANDIDATES="$EVIDENCE_DIR/cellular-candidate-files.tsv"
DIFF_REPORT="$EVIDENCE_DIR/common-failure-vs-stock-candidates.tsv"
MARKERS="$EVIDENCE_DIR/static-markers.txt"

: > "$SUMMARY"
: > "$CANDIDATES"
: > "$DIFF_REPORT"
: > "$MARKERS"

printf 'sample\trole\troot\tstatus\n' > "$SUMMARY"
printf 'sample\tcategory\tpath\tcanonical_path\n' > "$CANDIDATES"
printf 'category\tstock_path\tstock_canonical_path\tn1b1_present\tn1b2_present\tpriority\n' > "$DIFF_REPORT"

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

build_index() {
  local sample="$1"
  local root="$2"
  local index="$EVIDENCE_DIR/indexes/${sample}.paths"
  local stderr="$EVIDENCE_DIR/indexes/${sample}.find.stderr"

  [[ -d "$root" ]] || return 0

  if command -v timeout >/dev/null 2>&1; then
    if ! timeout "$FIND_TIMEOUT_SECONDS" find "$root" \
      \( -path '*/.git' -o -path '*/.repo' -o -path '*/out' -o -path '*/.gradle' -o -path '*/node_modules' \) -prune -o \
      \( -type f -o -type l \) -printf '%P\n' \
      > "$index" 2> "$stderr"; then
      if [[ -s "$index" ]]; then
        sort -u "$index" -o "$index"
        log_marker "N1B2_CELLULAR_STATIC_${sample}_INDEX=WARN_PARTIAL timeout_or_find_error path=$index seconds=$FIND_TIMEOUT_SECONDS"
      else
        log_marker "N1B2_CELLULAR_STATIC_${sample}_INDEX=WARN timeout_or_find_error path=$index seconds=$FIND_TIMEOUT_SECONDS"
      fi
      return 0
    fi
  else
    if ! find "$root" \
      \( -path '*/.git' -o -path '*/.repo' -o -path '*/out' -o -path '*/.gradle' -o -path '*/node_modules' \) -prune -o \
      \( -type f -o -type l \) -printf '%P\n' \
      > "$index" 2> "$stderr"; then
      if [[ -s "$index" ]]; then
        sort -u "$index" -o "$index"
        log_marker "N1B2_CELLULAR_STATIC_${sample}_INDEX=WARN_PARTIAL find_error path=$index"
      else
        log_marker "N1B2_CELLULAR_STATIC_${sample}_INDEX=WARN find_error path=$index"
      fi
      return 0
    fi
  fi

  sort -u "$index" -o "$index"
  log_marker "N1B2_CELLULAR_STATIC_${sample}_INDEX=PASS path=$index"
}

emit_category_from_index() {
  local sample="$1"
  local category="$2"
  local pattern="$3"
  local index="$EVIDENCE_DIR/indexes/${sample}.paths"

  [[ -f "$index" ]] || return 0

  grep -Ei -- "$pattern" "$index" \
    | awk -v sample="$sample" -v category="$category" '
        BEGIN { OFS="\t" }
        function canonical(rel, out) {
          out = rel
          gsub(/^\.\//, "", out)

          if (out ~ /^SYSTEM\/product\//) {
            sub(/^SYSTEM\/product\//, "product/", out)
          } else if (out ~ /^SYSTEM\/system_ext\//) {
            sub(/^SYSTEM\/system_ext\//, "system_ext/", out)
          } else if (out ~ /^SYSTEM\/system_dlkm\//) {
            sub(/^SYSTEM\/system_dlkm\//, "system_dlkm/", out)
          } else if (out ~ /^SYSTEM\//) {
            sub(/^SYSTEM\//, "system/", out)
          } else if (out ~ /^PRODUCT\//) {
            sub(/^PRODUCT\//, "product/", out)
          } else if (out ~ /^SYSTEM_EXT\//) {
            sub(/^SYSTEM_EXT\//, "system_ext/", out)
          } else if (out ~ /^VENDOR\//) {
            sub(/^VENDOR\//, "vendor/", out)
          } else if (out ~ /^ODM\//) {
            sub(/^ODM\//, "odm/", out)
          }

          if (out ~ /^system\/system\//) {
            sub(/^system\/system\//, "system/", out)
          } else if (out ~ /^system\/product\//) {
            sub(/^system\/product\//, "product/", out)
          } else if (out ~ /^system\/system_ext\//) {
            sub(/^system\/system_ext\//, "system_ext/", out)
          } else if (out ~ /^system\/system_dlkm\//) {
            sub(/^system\/system_dlkm\//, "system_dlkm/", out)
          }

          return out
        }
        { print sample, category, $0, canonical($0) }
      ' \
    >> "$CANDIDATES" || true
}

sample_present() {
  local sample="$1"
  local canonical_rel="$2"
  awk -F '\t' -v sample="$sample" -v rel="$canonical_rel" '$1 == sample && $4 == rel { found=1 } END { exit found ? 0 : 1 }' "$CANDIDATES"
}

sample_index_available() {
  local sample="$1"
  local index="$EVIDENCE_DIR/indexes/${sample}.paths"
  [[ -s "$index" ]]
}

stock_missing_in_failures() {
  local category="$1"
  awk -F '\t' -v category="$category" '$1 == "stock" && $2 == category { print $3 "\t" $4 }' "$CANDIDATES" \
    | while IFS=$'\t' read -r rel canonical_rel; do
        n1b1="NO"
        n1b2="NO"
        sample_present "n1b1" "$canonical_rel" && n1b1="YES"
        sample_present "n1b2" "$canonical_rel" && n1b2="YES"
        priority="LOW"
        if [[ "$n1b1" == "NO" && "$n1b2" == "NO" ]]; then
          priority="HIGH_STOCK_PRESENT_MISSING_BOTH_FAILURES"
        elif [[ "$n1b1" == "NO" || "$n1b2" == "NO" ]]; then
          priority="MEDIUM_STOCK_PRESENT_MISSING_ONE_FAILURE"
        fi
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$category" "$rel" "$canonical_rel" "$n1b1" "$n1b2" "$priority"
      done >> "$DIFF_REPORT"
}

echo "===== N1B2 CELLULAR STATIC AUDIT ====="
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "STATIC_ONLY=YES"
echo "FIND_TIMEOUT_SECONDS=$FIND_TIMEOUT_SECONDS"
echo "SINGLE_PASS_ROOT_INDEX=YES"
echo "CANONICAL_PATH_COMPARE=YES"
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

  build_index "$sample" "$root"

  emit_category_from_index "$sample" "telephony_packages" \
    'TeleService|TelephonyProvider|Telecom|CarrierConfig|CellBroadcast|(^|/)Stk|Euicc|(^|/)Lpa|MmsService|Ims|Rcs|Mbms|ims\.apk'

  emit_category_from_index "$sample" "privapp_permissions" \
    '(^|/)etc/permissions/.*privapp|(^|/)etc/permissions/privapp-permissions|(^|/)etc/sysconfig/'

  emit_category_from_index "$sample" "telephony_overlays_configs" \
    '(^|/)overlay/|(^|/)product/overlay/|(^|/)vendor/overlay/|apns|carrier.*config|telephony.*xml|mms|mbn'

  emit_category_from_index "$sample" "radio_vendor_init_vintf" \
    '(^|/)etc/init/.*(radio|ril|ims)|(^|/)etc/vintf/|radio.*\.so|ims.*\.so|ril.*\.so|mtk.*radio|vendor.*radio'
done

if sample_index_available stock && sample_index_available n1b1 && sample_index_available n1b2; then
  log_marker "N1B2_CELLULAR_STATIC_FAILURE_DIFF_INPUTS=PASS stock_n1b1_n1b2_indexes_present"
  for category in telephony_packages privapp_permissions telephony_overlays_configs radio_vendor_init_vintf; do
    stock_missing_in_failures "$category"
  done
else
  log_marker "N1B2_CELLULAR_STATIC_FAILURE_DIFF_INPUTS=WARN stock_n1b1_n1b2_required_for_high_priority_diff"
fi

if [[ -s "$CANDIDATES" ]]; then
  log_marker "N1B2_CELLULAR_STATIC_CANDIDATE_SCAN=PASS path=$CANDIDATES"
else
  log_marker "N1B2_CELLULAR_STATIC_CANDIDATE_SCAN=WARN no_candidates_found"
fi

if grep -Fq 'HIGH_STOCK_PRESENT_MISSING_BOTH_FAILURES' "$DIFF_REPORT"; then
  log_marker "N1B2_CELLULAR_STATIC_STOCK_VS_COMMON_FAILURE_DIFF=PASS path=$DIFF_REPORT"
elif sample_index_available stock && sample_index_available n1b1 && sample_index_available n1b2; then
  log_marker "N1B2_CELLULAR_STATIC_STOCK_VS_COMMON_FAILURE_DIFF=WARN no_high_priority_static_diff_yet"
else
  log_marker "N1B2_CELLULAR_STATIC_STOCK_VS_COMMON_FAILURE_DIFF=WARN insufficient_failure_inputs"
fi

log_marker "N1B2_CELLULAR_STATIC_AUDIT=PASS evidence_dir=$EVIDENCE_DIR"

echo "SUMMARY=$SUMMARY"
echo "CANDIDATES=$CANDIDATES"
echo "DIFF_REPORT=$DIFF_REPORT"
echo "MARKERS=$MARKERS"
