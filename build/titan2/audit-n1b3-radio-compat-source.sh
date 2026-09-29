#!/usr/bin/env bash
set -euo pipefail

REPO="${REPO:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
ANDROID_SRC="${ANDROID_SRC:-$REPO}"
EVIDENCE_DIR="${EVIDENCE_DIR:-/tmp/SABLE_N1B3_RADIO_COMPAT_SOURCE_AUDIT_$(date -u +%Y%m%dT%H%M%SZ)}"
COMMAND_TIMEOUT_SECONDS="${COMMAND_TIMEOUT_SECONDS:-90}"

usage() {
  cat <<'USAGE'
Usage: build/titan2/audit-n1b3-radio-compat-source.sh [options]

Options:
  --android-src PATH          Android source/workspace root to inspect.
  --evidence-dir PATH         Directory for audit output.
  --command-timeout SECONDS   Timeout per grep group; default 90.
  -h, --help                  Show help.

Safety:
  - No source mutation.
  - No build.
  - No adb.
  - No fastboot.
  - No flash.
  - Grep is limited to explicit source roots only.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --android-src)
      ANDROID_SRC="$2"
      shift 2
      ;;
    --android-src=*)
      ANDROID_SRC="${1#*=}"
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
    --command-timeout)
      COMMAND_TIMEOUT_SECONDS="$2"
      shift 2
      ;;
    --command-timeout=*)
      COMMAND_TIMEOUT_SECONDS="${1#*=}"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "UNKNOWN_ARG=$1" >&2
      exit 2
      ;;
  esac
done

case "$COMMAND_TIMEOUT_SECONDS" in
  ''|*[!0-9]*)
    echo "COMMAND_TIMEOUT_SECONDS_INVALID=$COMMAND_TIMEOUT_SECONDS" >&2
    exit 2
    ;;
esac

if ! command -v timeout >/dev/null 2>&1; then
  echo "N1B3_RADIO_COMPAT_SOURCE_AUDIT=FAIL reason=missing_timeout_binary" >&2
  exit 1
fi

mkdir -p "$EVIDENCE_DIR" "$EVIDENCE_DIR/summary"
MARKERS_FILE="$EVIDENCE_DIR/markers.txt"
ROOTS_FILE="$EVIDENCE_DIR/source-roots.txt"
WARNINGS_FILE="$EVIDENCE_DIR/warnings.txt"
SUMMARY_DIR="$EVIDENCE_DIR/summary"
: > "$WARNINGS_FILE"

{
  echo "===== N1B3 RADIO COMPAT SOURCE AUDIT ====="
  echo "SOURCE_MUTATION_AUTHORIZED=NO"
  echo "BUILD_AUTHORIZED=NO"
  echo "DEVICE_CONTACT_AUTHORIZED=NO"
  echo "ADB_AUTHORIZED=NO"
  echo "FASTBOOT_AUTHORIZED=NO"
  echo "FLASH_AUTHORIZED=NO"
  echo "REPO=$REPO"
  echo "ANDROID_SRC=$ANDROID_SRC"
  echo "EVIDENCE_DIR=$EVIDENCE_DIR"
  echo "COMMAND_TIMEOUT_SECONDS=$COMMAND_TIMEOUT_SECONDS"
  echo "N1B3_RADIO_COMPAT_SOURCE_AUDIT_GREP_SCOPE=EXPLICIT_SOURCE_ROOTS_ONLY"
} | tee "$MARKERS_FILE"

candidate_roots=(
  "$ANDROID_SRC/frameworks/opt/telephony"
  "$ANDROID_SRC/frameworks/base/telephony"
  "$ANDROID_SRC/packages/services/Telephony"
  "$ANDROID_SRC/packages/modules/Connectivity"
  "$ANDROID_SRC/packages/modules/Telephony"
  "$ANDROID_SRC/device"
  "$ANDROID_SRC/vendor"
  "$REPO/docs/titan2"
  "$REPO/build/titan2"
  "$REPO/build/gates"
  "$REPO/patches"
  "$REPO/device"
  "$REPO/vendor"
)

: > "$ROOTS_FILE"
for root in "${candidate_roots[@]}"; do
  if [[ -d "$root" ]]; then
    realpath "$root" >> "$ROOTS_FILE"
  fi
done
sort -u "$ROOTS_FILE" -o "$ROOTS_FILE"

root_count="$(wc -l < "$ROOTS_FILE" | tr -d ' ')"
echo "N1B3_RADIO_COMPAT_SOURCE_AUDIT_ROOT_COUNT=$root_count" | tee -a "$MARKERS_FILE"

if [[ "$root_count" -eq 0 ]]; then
  echo "N1B3_RADIO_COMPAT_SOURCE_AUDIT=FAIL reason=no_source_roots" | tee -a "$MARKERS_FILE"
  exit 1
fi

sed 's#^#SOURCE_AUDIT_ROOT=#' "$ROOTS_FILE" | tee -a "$MARKERS_FILE"

grep_source_pattern() {
  local name="$1"
  local pattern="$2"
  local output="$SUMMARY_DIR/$name.txt"
  local count

  : > "$output"
  echo "SOURCE_AUDIT_PATTERN_START=$name" | tee -a "$MARKERS_FILE"

  if timeout "$COMMAND_TIMEOUT_SECONDS" bash -c '
    set -euo pipefail
    roots_file="$1"
    pattern="$2"
    output="$3"

    while IFS= read -r root; do
      find "$root" -type f \( \
        -name "*.java" -o \
        -name "*.kt" -o \
        -name "*.xml" -o \
        -name "*.mk" -o \
        -name "*.bp" -o \
        -name "*.sh" -o \
        -name "*.rc" -o \
        -name "*.te" -o \
        -name "*.cil" -o \
        -name "*.contexts" -o \
        -name "*.md" \
      \) -print0 \
        | xargs -0r grep -HInIE "$pattern" >> "$output" 2>/dev/null || true
    done < "$roots_file"
  ' bash "$ROOTS_FILE" "$pattern" "$output"; then
    :
  else
    echo "SOURCE_AUDIT_WARN pattern=$name timed_out_or_failed" | tee -a "$WARNINGS_FILE"
  fi

  count="$(wc -l < "$output" | tr -d ' ')"
  echo "N1B3_SOURCE_AUDIT_${name}_COUNT=$count" | tee -a "$MARKERS_FILE"
}

grep_source_pattern \
  "mtk_indication" \
  'mtkNetworkIndication|smartRatSwitchInd|responseCsNetworkStateChangeInd|vendor\.mediatek\.hardware\.(radio|mtkradioex)|mtk(Ims|Mwi|Em|Radio|Network)|MtkRadio|MtkIms'

grep_source_pattern \
  "ims_binding" \
  'com\.mediatek\.ims|config_ims_(mmtel|rcs)_package_override_string|ImsResolver|ImsService|MMTEL|EMERGENCY_MMTEL|NO_IMS_SERVICE_CONFIGURED|IMS_SERVICE_DISCONNECTED|IMS_UNSUPPORTED'

grep_source_pattern \
  "phh_mtk_ims" \
  'persist\.sys\.phh\.ims\.mtk|mtkims_telephony|treble.*mtk.*ims|me\.phh\.treble\.overlay\.mtkims_telephony'

grep_source_pattern \
  "wwan_drop" \
  'ERROR_UNSPECIFIED|UNSOL_DATA_CALL_LIST_CHANGED|DataCallResponse|SERVICE_OPTION_NOT_SUPPORTED|NO_SUITABLE_DATA_PROFILE|DATA_CONFIG_NOT_READY|NOT_IN_SERVICE'

grep_source_pattern \
  "qns_iwlan" \
  'com\.android\.telephony\.qns|QualifiedNetworks|QNS|IWLAN|WLAN'

grep_source_pattern \
  "selinux_radio" \
  'vendor\.mediatek\.hardware\.radio|vendor\.mediatek\.hardware\.mtkradioex|hwservice_contexts|service_contexts|hal_telephony|system_app|radio_service'

{
  echo "===== N1B3 RADIO COMPAT SOURCE AUDIT SUMMARY ====="
  echo "EVIDENCE_DIR=$EVIDENCE_DIR"
  for f in "$SUMMARY_DIR"/*.txt; do
    echo
    echo "===== $(basename "$f") ====="
    head -80 "$f" || true
  done
  echo
  echo "N1B3_RADIO_COMPAT_SOURCE_AUDIT=PASS"
} | tee "$EVIDENCE_DIR/source-audit-summary.txt"

echo "N1B3_RADIO_COMPAT_SOURCE_AUDIT=PASS" | tee -a "$MARKERS_FILE"
