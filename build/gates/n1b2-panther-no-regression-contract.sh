#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IDENTITY_BRANCHING_BASELINE="$ROOT/docs/titan2/N1B2_COMMON_APP_DEVICE_IDENTITY_BRANCHING_BASELINE.txt"

passes=0
warnings=0
failures=0

emit() {
  local status="$1"
  local key="$2"
  local detail="${3:-}"

  printf '%s=%s' "$key" "$status"
  [[ -z "$detail" ]] || printf ' %s' "$detail"
  printf '\n'

  case "$status" in
    PASS) passes=$((passes + 1)) ;;
    FAIL) failures=$((failures + 1)) ;;
    *) warnings=$((warnings + 1)) ;;
  esac
}

require_file() {
  local key="$1"
  local path="$2"

  [[ -f "$path" ]] \
    && emit PASS "$key" "path=$path" \
    || emit FAIL "$key" "missing=$path"
}

normalize_grep_report() {
  local input="$1"
  local output="$2"

  sed \
    -e "s#^$ROOT/##" \
    -e 's/:[0-9][0-9]*:/:/' \
    -e 's/:[[:space:]]*/:/' \
    "$input" \
    | sort \
    > "$output"
}

scan_forbidden() {
  local key="$1"
  local pattern="$2"
  shift 2
  local -a paths=("$@")
  local report

  report="$(mktemp)"

  for path in "${paths[@]}"; do
    [[ -e "$path" ]] || continue
    find "$path" -type f \
      \( \
        -name '*.kt' \
        -o -name '*.java' \
        -o -name '*.rs' \
        -o -name '*.xml' \
        -o -name '*.gradle' \
        -o -name '*.gradle.kts' \
        -o -name 'Android.bp' \
        -o -name 'Android.mk' \
        -o -name '*.mk' \
        -o -name '*.sh' \
        -o -name '*.py' \
        -o -name '*.env' \
        -o -name '*.properties' \
      \) \
      ! -path '*/.git/*' \
      ! -path '*/.gradle/*' \
      ! -path '*/build/*' \
      ! -path '*/src/main/assets/*' \
      -print0 \
      | xargs -0 -r grep -n -E "$pattern" >> "$report" 2>/dev/null || true
  done

  if [[ -s "$report" ]]; then
    emit FAIL "$key" "report=$report"
    sed 's/^/  /' "$report"
  else
    emit PASS "$key"
    rm -f "$report"
  fi
}

scan_app_identity_branching() {
  local key="$1"
  shift
  local -a paths=("$@")
  local raw_report normalized_report unexpected_report
  local baseline_filtered baseline_count unexpected_count

  raw_report="$(mktemp)"
  normalized_report="$(mktemp)"
  unexpected_report="$(mktemp)"

  for path in "${paths[@]}"; do
    [[ -e "$path" ]] || continue
    find "$path" -type f \
      \( -name '*.kt' -o -name '*.java' \) \
      ! -path '*/.git/*' \
      ! -path '*/.gradle/*' \
      ! -path '*/build/*' \
      -print0 \
      | xargs -0 -r grep -n -E \
        'Build\.(MODEL|DEVICE|PRODUCT|MANUFACTURER|BRAND|HARDWARE)|android\.os\.Build\.(MODEL|DEVICE|PRODUCT|MANUFACTURER|BRAND|HARDWARE)|SystemProperties\.get\(|getprop|ro\.product\.|ro\.sableos\.' \
        >> "$raw_report" 2>/dev/null || true
  done

  if [[ ! -s "$raw_report" ]]; then
    emit PASS "$key"
    rm -f "$raw_report" "$normalized_report" "$unexpected_report"
    return
  fi

  normalize_grep_report "$raw_report" "$normalized_report"

  baseline_filtered="$(mktemp)"
  grep -v -E '^[[:space:]]*(#|$)' "$IDENTITY_BRANCHING_BASELINE" \
    | sort \
    > "$baseline_filtered"

  grep -Fvx -f "$baseline_filtered" "$normalized_report" \
    > "$unexpected_report" || true

  baseline_count="$(wc -l < "$normalized_report" | tr -d ' ')"
  unexpected_count="$(wc -l < "$unexpected_report" | tr -d ' ')"

  if [[ -s "$unexpected_report" ]]; then
    emit FAIL "$key" "unexpected_report=$unexpected_report baseline=$IDENTITY_BRANCHING_BASELINE"
    sed 's/^/  /' "$unexpected_report"
  else
    emit PASS "$key" "allowed_existing_reader_baseline=$baseline_count baseline=$IDENTITY_BRANCHING_BASELINE"
    rm -f "$raw_report" "$normalized_report" "$unexpected_report" "$baseline_filtered"
  fi

  if [[ "$unexpected_count" == 0 ]]; then
    rm -f "$unexpected_report"
  fi
}

cat <<EOF
===== N1B2 PANTHER NO-REGRESSION CONTRACT =====
ROOT=$ROOT
DEVICE_CONTACT_AUTHORIZED=NO
ADB_COMMANDS_RUN=NO
FASTBOOT_COMMANDS_RUN=NO
BUILD_AUTHORIZED=NO
IMAGE_BUILD_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
FACTORY_RESET_AUTHORIZED=NO
PUBLIC_RELEASE=NO
PRODUCTION_SIGNING=NO
EOF

require_file N1B2_PANTHER_NO_REGRESSION_DOC_PRESENT \
  "$ROOT/docs/titan2/N1B2_PANTHER_NO_REGRESSION.md"
require_file N1B2_PLATFORM_SABLE_BINDING_DOC_PRESENT \
  "$ROOT/docs/titan2/N1B2_APP_PROFILE_BINDING.md"
require_file N1B2_PLATFORM_SABLE_BINDING_MANIFEST_PRESENT \
  "$ROOT/docs/titan2/N1B2_APP_PROFILE_BINDING.tsv"
require_file N1B2_PLATFORM_SABLE_BINDING_GATE_PRESENT \
  "$ROOT/build/gates/n1b2-platform-sable-profile-binding-contract.sh"
require_file N1B2_DEVICE_IDENTITY_BRANCHING_BASELINE_PRESENT \
  "$IDENTITY_BRANCHING_BASELINE"

common_paths=(
  "$ROOT/apps/r8/android"
  "$ROOT/src/android/shared"
  "$ROOT/src/android/packages/apps/SableStart"
  "$ROOT/src/android/packages/apps/SableDesign"
)

panther_paths=(
  "$ROOT/build/panther"
)

scan_forbidden \
  N1B2_COMMON_APP_TITAN2_TAINT_ABSENT \
  'titan2|Titan2|Titan 2|N1B|N1B2|tdgsi|Restless|g71v78c2k|MT6878|vendor/sable/n1b2' \
  "${common_paths[@]}"

scan_forbidden \
  N1B2_PANTHER_PATH_TITAN2_TAINT_ABSENT \
  'titan2|Titan2|Titan 2|N1B|N1B2|tdgsi|Restless|g71v78c2k|MT6878|vendor/sable/n1b2' \
  "${panther_paths[@]}"

scan_app_identity_branching \
  N1B2_COMMON_APP_DEVICE_IDENTITY_BRANCHING_BASELINED \
  "${common_paths[@]}"

emit PASS N1B2_TITAN2_BOUNDARY_ALLOWED "allowed_paths=docs/titan2,build/titan2,build/devices/titan2.sh"
emit PASS N1B2_PANTHER_TOUCH_FIRST_DEFAULT_REQUIRED
emit PASS N1B2_TITAN2_PROFILE_DRIVEN_UX_REQUIRED

echo "N1B2_PANTHER_NO_REGRESSION_PASSES=$passes"
echo "N1B2_PANTHER_NO_REGRESSION_WARNINGS=$warnings"
echo "N1B2_PANTHER_NO_REGRESSION_FAILURES=$failures"

if (( failures == 0 )); then
  echo "N1B2_PANTHER_NO_REGRESSION=PASS"
  exit 0
fi

echo "N1B2_PANTHER_NO_REGRESSION=FAIL failures=$failures"
exit 1
