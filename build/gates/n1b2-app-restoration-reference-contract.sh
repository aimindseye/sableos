#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="$ROOT/docs/titan2/N1B2_APP_RESTORATION_REFERENCE.tsv"
DOC="$ROOT/docs/titan2/N1B2_APP_RESTORATION_REFERENCE.md"
PLATFORM_SABLE_ROOT="${PLATFORM_SABLE_ROOT:-/srv/data/sable-build/platform_sable}"

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

require_dir() {
  local key="$1"
  local path="$2"

  [[ -d "$path" ]] \
    && emit PASS "$key" "path=$path" \
    || emit FAIL "$key" "missing=$path"
}

key_for_surface() {
  local prefix="$1"
  local surface="$2"
  local key="${prefix}_${surface//-/_}"
  printf '%s' "${key^^}"
}

require_manifest_surface() {
  local surface="$1"
  local key
  key="$(key_for_surface N1B2_APP_RESTORATION_REFERENCE_ROW "$surface")"

  if awk -F '\t' -v s="$surface" 'NR > 1 && $1 == s { found=1 } END { exit found ? 0 : 1 }' "$MANIFEST"; then
    emit PASS "$key" "surface=$surface"
  else
    emit FAIL "$key" "missing_surface=$surface"
  fi
}

cat <<EOF
===== N1B2 APP RESTORATION REFERENCE CONTRACT =====
ROOT=$ROOT
MANIFEST=$MANIFEST
DOC=$DOC
PLATFORM_SABLE_ROOT=$PLATFORM_SABLE_ROOT
DEVICE_CONTACT_AUTHORIZED=NO
ADB_COMMANDS_RUN=NO
FASTBOOT_COMMANDS_RUN=NO
BUILD_AUTHORIZED=NO
IMAGE_BUILD_AUTHORIZED=NO
SOONG_BUILD_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
FACTORY_RESET_AUTHORIZED=NO
PUBLIC_RELEASE=NO
PRODUCTION_SIGNING=NO
EOF

require_file N1B2_APP_RESTORATION_REFERENCE_DOC_PRESENT "$DOC"
require_file N1B2_APP_RESTORATION_REFERENCE_MANIFEST_PRESENT "$MANIFEST"
require_file N1B2_EXISTING_APK_INVENTORY_DOC_PRESENT "$ROOT/docs/titan2/N1B2_EXISTING_APK_INVENTORY.md"
require_file N1B2_EXISTING_APK_INVENTORY_MANIFEST_PRESENT "$ROOT/docs/titan2/N1B2_EXISTING_APK_INVENTORY.tsv"
require_file N1B2_PANTHER_NO_REGRESSION_GATE_PRESENT "$ROOT/build/gates/n1b2-panther-no-regression-contract.sh"
require_dir N1B2_PLATFORM_SABLE_ROOT_PRESENT "$PLATFORM_SABLE_ROOT"
require_file N1B2_PLATFORM_SABLE_APP_REUSE_MODEL_PRESENT "$PLATFORM_SABLE_ROOT/docs/SABLE_APP_REUSE_AND_INTEGRATION_PLAN.md"
require_file N1B2_PLATFORM_SABLE_PORTABILITY_RULES_PRESENT "$PLATFORM_SABLE_ROOT/docs/PORTABILITY_RULES.md"
require_file N1B2_PLATFORM_SABLE_ARCHITECTURE_PRESENT "$PLATFORM_SABLE_ROOT/docs/ARCHITECTURE.md"

required_surfaces=(
  calculator
  games
  media
  hub
  weather
  calendar
  mail
  messages
  reader
  textreader
  people
  contacts
  browser
  settings
  command
  phone
  systemui
)

for surface in "${required_surfaces[@]}"; do
  require_manifest_surface "$surface"
done

while IFS=$'\t' read -r \
  surface \
  current_n1b2_status \
  panther_common_reference \
  existing_repo_path \
  platform_sable_source \
  restoration_rule \
  notes; do
  [[ "$surface" == surface ]] && continue

  key="$(key_for_surface N1B2_APP_RESTORATION_REFERENCE "$surface")"

  if [[ -z "$surface" || -z "$current_n1b2_status" || -z "$panther_common_reference" || -z "$existing_repo_path" || -z "$platform_sable_source" || -z "$restoration_rule" ]]; then
    emit FAIL "$key" "empty_required_field surface=$surface"
    continue
  fi

  case "$restoration_rule" in
    CREATE_NEW*|*CREATE_NEW_FROM_SCRATCH*|NEW_APP_ONLY)
      emit FAIL "$key" "forbidden_restoration_rule=$restoration_rule"
      ;;
    *)
      emit PASS "$key" "rule=$restoration_rule"
      ;;
  esac

  if [[ "$existing_repo_path" != NONE ]]; then
    require_dir "$(key_for_surface N1B2_APP_RESTORATION_REPO_REFERENCE "$surface")" \
      "$ROOT/$existing_repo_path"
  else
    emit NOT_PROVEN "$(key_for_surface N1B2_APP_RESTORATION_REPO_REFERENCE "$surface")" \
      "no_current_repo_path surface=$surface"
  fi

  if [[ "$platform_sable_source" != NONE ]]; then
    require_file "$(key_for_surface N1B2_APP_RESTORATION_PLATFORM_SOURCE "$surface")" \
      "$PLATFORM_SABLE_ROOT/$platform_sable_source"
  else
    emit FAIL "$(key_for_surface N1B2_APP_RESTORATION_PLATFORM_SOURCE "$surface")" \
      "missing_platform_source surface=$surface"
  fi

  case "$current_n1b2_status" in
    PROVEN_EXISTING_MODULE|NOT_PROVEN_ACCEPTED_COMMON_APP|NOT_PROVEN_HUB_MESSAGES_REFERENCE|NOT_PROVEN_DESIGN_REFERENCE|NOT_PROVEN_SYSTEM_SURFACE)
      emit PASS "$(key_for_surface N1B2_APP_RESTORATION_STATUS "$surface")" \
        "status=$current_n1b2_status"
      ;;
    *)
      emit FAIL "$(key_for_surface N1B2_APP_RESTORATION_STATUS "$surface")" \
        "unexpected_status=$current_n1b2_status"
      ;;
  esac

done < "$MANIFEST"

echo "N1B2_APP_RESTORATION_REFERENCE_PASSES=$passes"
echo "N1B2_APP_RESTORATION_REFERENCE_WARNINGS=$warnings"
echo "N1B2_APP_RESTORATION_REFERENCE_FAILURES=$failures"

if (( failures == 0 )); then
  echo "N1B2_APP_RESTORATION_REFERENCE=PASS"
  exit 0
fi

echo "N1B2_APP_RESTORATION_REFERENCE=FAIL failures=$failures"
exit 1
