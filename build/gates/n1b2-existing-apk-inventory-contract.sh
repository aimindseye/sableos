#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_ROOT="$ROOT/apps/r8/android"
MANIFEST="$ROOT/docs/titan2/N1B2_EXISTING_APK_INVENTORY.tsv"
DOC="$ROOT/docs/titan2/N1B2_EXISTING_APK_INVENTORY.md"
BUILD_MODE="NO"

usage() {
  cat <<'USAGE'
usage:
  bash build/gates/n1b2-existing-apk-inventory-contract.sh [--build YES|NO]

Inventory and optional Gradle APK build gate for existing R8 Android modules.
This gate does not run image builds, Soong builds, adb, fastboot, flash, device
contact, public release, or production signing.
USAGE
}

while (($#)); do
  case "$1" in
    --build) BUILD_MODE="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "N1B2_EXISTING_APK_INVENTORY=FAIL_UNKNOWN_ARG arg=$1"; usage; exit 64 ;;
  esac
done

case "$BUILD_MODE" in
  YES|NO) ;;
  *) echo "N1B2_EXISTING_APK_INVENTORY=FAIL_BAD_BUILD_MODE value=$BUILD_MODE"; exit 64 ;;
esac

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

require_settings_include() {
  local module="$1"
  local key
  key="N1B2_GRADLE_SETTINGS_INCLUDES_${module//-/_}"
  key="${key^^}"

  if grep -Fq "include(\":$module\")" "$APP_ROOT/settings.gradle.kts"; then
    emit PASS "$key" "module=$module"
  else
    emit FAIL "$key" "missing_include=$module"
  fi
}

require_manifest_row() {
  local module="$1"
  local key
  key="N1B2_APK_INVENTORY_ROW_${module//-/_}"
  key="${key^^}"

  if awk -F '\t' -v m="$module" 'NR > 1 && $1 == m { found=1 } END { exit found ? 0 : 1 }' "$MANIFEST"; then
    emit PASS "$key" "module=$module"
  else
    emit FAIL "$key" "missing_manifest_row=$module"
  fi
}

require_module_layout() {
  local module="$1"
  local module_dir="$APP_ROOT/$module"
  local key_module key_build key_manifest

  key_module="N1B2_MODULE_DIR_${module//-/_}"
  key_build="N1B2_MODULE_BUILD_GRADLE_${module//-/_}"
  key_manifest="N1B2_MODULE_ANDROID_MANIFEST_${module//-/_}"
  key_module="${key_module^^}"
  key_build="${key_build^^}"
  key_manifest="${key_manifest^^}"

  require_dir "$key_module" "$module_dir"
  require_file "$key_build" "$module_dir/build.gradle.kts"

  if [[ -f "$module_dir/src/main/AndroidManifest.xml" ]]; then
    emit PASS "$key_manifest" "path=$module_dir/src/main/AndroidManifest.xml"
  else
    emit NOT_APPLICABLE "$key_manifest" "module_may_be_library_or_validation module=$module"
  fi
}

check_apk_output() {
  local module="$1"
  local glob="$APP_ROOT/$module/build/outputs/apk/debug"/*.apk
  local key
  key="N1B2_EXISTING_APK_OUTPUT_${module//-/_}"
  key="${key^^}"

  shopt -s nullglob
  local -a apks=( $glob )
  shopt -u nullglob

  if ((${#apks[@]} > 0)); then
    emit PASS "$key" "count=${#apks[@]} first=${apks[0]}"
  else
    emit FAIL "$key" "missing_glob=$APP_ROOT/$module/build/outputs/apk/debug/*.apk"
  fi
}

core_modules=(
  design
  calculator
  convert
  games
  media
  hub
  sablestart-presentation-check
  sablestart-visual-review
  weather
  calendar
)

product_apk_modules=(
  calculator
  convert
  games
  media
  hub
  weather
  calendar
)

validation_apk_modules=(
  sablestart-visual-review
)

build_tasks=(
  :design:assemble
  :calculator:assembleDebug
  :convert:assembleDebug
  :games:assembleDebug
  :media:assembleDebug
  :hub:assembleDebug
  :weather:assembleDebug
  :calendar:assembleDebug
  :sablestart-visual-review:assembleDebug
)

cat <<EOF
===== N1B2 EXISTING APK INVENTORY CONTRACT =====
ROOT=$ROOT
APP_ROOT=$APP_ROOT
MANIFEST=$MANIFEST
DOC=$DOC
BUILD_MODE=$BUILD_MODE
DEVICE_CONTACT_AUTHORIZED=NO
ADB_COMMANDS_RUN=NO
FASTBOOT_COMMANDS_RUN=NO
BUILD_AUTHORIZED=$([[ "$BUILD_MODE" == YES ]] && echo YES_GRADLE_APK_ONLY || echo NO)
IMAGE_BUILD_AUTHORIZED=NO
SOONG_BUILD_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
FACTORY_RESET_AUTHORIZED=NO
PUBLIC_RELEASE=NO
PRODUCTION_SIGNING=NO
EOF

require_file N1B2_EXISTING_APK_INVENTORY_DOC_PRESENT "$DOC"
require_file N1B2_EXISTING_APK_INVENTORY_MANIFEST_PRESENT "$MANIFEST"
require_file N1B2_PLATFORM_SABLE_BINDING_GATE_PRESENT "$ROOT/build/gates/n1b2-platform-sable-profile-binding-contract.sh"
require_file N1B2_PANTHER_NO_REGRESSION_GATE_PRESENT "$ROOT/build/gates/n1b2-panther-no-regression-contract.sh"
require_file N1B2_ANDROID_GRADLE_SETTINGS_PRESENT "$APP_ROOT/settings.gradle.kts"
require_file N1B2_ANDROID_GRADLE_WRAPPER_PRESENT "$APP_ROOT/gradlew"

for module in "${core_modules[@]}"; do
  require_settings_include "$module"
  require_manifest_row "$module"
  require_module_layout "$module"
done

for missing in mail messages people reader textreader command browser settings systemui phone contacts; do
  if grep -Fq "include(\":$missing\")" "$APP_ROOT/settings.gradle.kts"; then
    emit WARN "N1B2_UNPLANNED_EXISTING_MODULE_${missing^^}" "unexpected_existing_module=$missing"
  else
    emit NOT_PROVEN "N1B2_MISSING_MODULE_${missing^^}" "not_part_of_existing_apk_inventory module=$missing"
  fi
done

if (( failures == 0 )); then
  echo "N1B2_EXISTING_APK_INVENTORY_PASSES=$passes"
  echo "N1B2_EXISTING_APK_INVENTORY_WARNINGS=$warnings"
  echo "N1B2_EXISTING_APK_INVENTORY_FAILURES=$failures"
  echo "N1B2_EXISTING_APK_INVENTORY=PASS"
else
  echo "N1B2_EXISTING_APK_INVENTORY_PASSES=$passes"
  echo "N1B2_EXISTING_APK_INVENTORY_WARNINGS=$warnings"
  echo "N1B2_EXISTING_APK_INVENTORY_FAILURES=$failures"
  echo "N1B2_EXISTING_APK_INVENTORY=FAIL failures=$failures"
  exit 1
fi

if [[ "$BUILD_MODE" == NO ]]; then
  echo "N1B2_EXISTING_APK_BUILD=NOT_RUN use=--build YES"
  exit 0
fi

(
  cd "$APP_ROOT"
  ./gradlew --no-daemon "${build_tasks[@]}"
)

for module in "${product_apk_modules[@]}"; do
  check_apk_output "$module"
done
for module in "${validation_apk_modules[@]}"; do
  check_apk_output "$module"
done

if (( failures == 0 )); then
  echo "N1B2_EXISTING_APK_BUILD=PASS"
  exit 0
fi

echo "N1B2_EXISTING_APK_BUILD=FAIL failures=$failures"
exit 1
