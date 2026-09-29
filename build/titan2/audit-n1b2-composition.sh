#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ANDROID_ROOT=""
ACTIVE_PRODUCT_MK=""
PLATFORM_SABLE_ROOT=""
PLATFORM_SABLE_ROOT_MISSING=""
EVIDENCE_DIR=""
FAIL_ON_PANTHER_TAINT="YES"

usage() {
  cat <<'USAGE'
usage:
  bash build/titan2/audit-n1b2-composition.sh \
    --android-root <android source root> \
    --active-product-mk <path relative to android root> \
    [--platform-sable-root <platform_sable checkout>] \
    [--evidence-dir <dir>] \
    [--fail-on-panther-taint YES|NO]

Offline Titan2/N1B2 composition audit.
This script does not build, does not contact a device, does not run adb or
fastboot, does not flash, does not erase userdata, and does not authorize public
release or production signing.
USAGE
}

while (($#)); do
  case "$1" in
    --android-root) ANDROID_ROOT="${2:-}"; shift 2 ;;
    --active-product-mk) ACTIVE_PRODUCT_MK="${2:-}"; shift 2 ;;
    --platform-sable-root) PLATFORM_SABLE_ROOT="${2:-}"; shift 2 ;;
    --evidence-dir) EVIDENCE_DIR="${2:-}"; shift 2 ;;
    --fail-on-panther-taint) FAIL_ON_PANTHER_TAINT="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "N1B2_COMPOSITION_AUDIT=FAIL_UNKNOWN_ARG arg=$1" >&2; usage; exit 64 ;;
  esac
done

case "$FAIL_ON_PANTHER_TAINT" in YES|NO) ;; *) echo "N1B2_COMPOSITION_AUDIT=FAIL_BAD_FAIL_ON_PANTHER_TAINT value=$FAIL_ON_PANTHER_TAINT"; exit 64 ;; esac
[[ -n "$ANDROID_ROOT" ]] || { echo "N1B2_COMPOSITION_AUDIT=FAIL_ANDROID_ROOT_REQUIRED"; usage; exit 64; }
[[ -n "$ACTIVE_PRODUCT_MK" ]] || { echo "N1B2_COMPOSITION_AUDIT=FAIL_ACTIVE_PRODUCT_MK_REQUIRED"; usage; exit 64; }
[[ "$ACTIVE_PRODUCT_MK" != /* ]] || { echo "N1B2_COMPOSITION_AUDIT=FAIL_ACTIVE_PRODUCT_MK_ABSOLUTE"; exit 64; }
[[ -d "$ANDROID_ROOT" ]] || { echo "N1B2_COMPOSITION_AUDIT=FAIL_ANDROID_ROOT_NOT_FOUND path=$ANDROID_ROOT"; exit 64; }
ANDROID_ROOT="$(cd "$ANDROID_ROOT" && pwd)"
ACTIVE_PRODUCT_PATH="$ANDROID_ROOT/$ACTIVE_PRODUCT_MK"
[[ -f "$ACTIVE_PRODUCT_PATH" ]] || { echo "N1B2_COMPOSITION_AUDIT=FAIL_ACTIVE_PRODUCT_MK_NOT_FOUND path=$ACTIVE_PRODUCT_PATH"; exit 64; }
if [[ -n "$PLATFORM_SABLE_ROOT" ]]; then
  if [[ -d "$PLATFORM_SABLE_ROOT" ]]; then
    PLATFORM_SABLE_ROOT="$(cd "$PLATFORM_SABLE_ROOT" && pwd)"
  else
    PLATFORM_SABLE_ROOT_MISSING="$PLATFORM_SABLE_ROOT"
    PLATFORM_SABLE_ROOT=""
  fi
fi
[[ -n "$EVIDENCE_DIR" ]] || EVIDENCE_DIR="/tmp/SABLE_N1B2_COMPOSITION_AUDIT_$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$EVIDENCE_DIR"
REPORT="$EVIDENCE_DIR/n1b2-composition-audit.env"
TAINT_REPORT="$EVIDENCE_DIR/panther-taint-grep.txt"
: > "$REPORT"
: > "$TAINT_REPORT"

passes=0
warnings=0
failures=0

emit() {
  local status="$1"
  local key="$2"
  local detail="${3:-}"
  printf '%s=%s' "$key" "$status" | tee -a "$REPORT"
  [[ -z "$detail" ]] || printf ' %s' "$detail" | tee -a "$REPORT"
  printf '\n' | tee -a "$REPORT"
  case "$status" in
    PASS) passes=$((passes + 1)) ;;
    FAIL) failures=$((failures + 1)) ;;
    *) warnings=$((warnings + 1)) ;;
  esac
}

require_file() {
  local key="$1"
  local path="$2"
  [[ -f "$path" ]] && emit PASS "$key" "path=$path" || emit FAIL "$key" "missing=$path"
}

require_text() {
  local key="$1"
  local pattern="$2"
  local path="$3"
  if [[ -f "$path" ]] && grep -Fq -- "$pattern" "$path"; then
    emit PASS "$key" "pattern=$(printf '%q' "$pattern") path=$path"
  else
    emit FAIL "$key" "missing_pattern=$(printf '%q' "$pattern") path=$path"
  fi
}

note_text() {
  local key="$1"
  local pattern="$2"
  local path="$3"
  if [[ -f "$path" ]] && grep -Fq -- "$pattern" "$path"; then
    emit PASS "$key" "pattern=$(printf '%q' "$pattern") path=$path"
  else
    emit NOT_PROVEN "$key" "missing_pattern=$(printf '%q' "$pattern") path=$path"
  fi
}

module_in_gradle() {
  grep -Fq "include(\":$1\")" "$ROOT/apps/r8/android/settings.gradle.kts"
}

check_gradle_expected_module() {
  local key="$1"
  local module="$2"

  if module_in_gradle "$module"; then
    emit PASS "$key" "module=$module"
  else
    emit NOT_PROVEN "$key" "not_listed_in_apps_gradle module=$module"
  fi
}

android_module_present() {
  grep -R --include='Android.bp' --include='Android.mk' -Fq -- "$1" "$ANDROID_ROOT" 2>/dev/null
}

product_selects() {
  [[ -f "$ANDROID_ROOT/vendor/sable/n1b2/sable_n1b2_product_profile.mk" ]] && grep -Fq -- "$1" "$ANDROID_ROOT/vendor/sable/n1b2/sable_n1b2_product_profile.mk"
}

cat <<EOF | tee -a "$REPORT"
===== N1B2 TITAN2 COMPOSITION AUDIT =====
ROOT=$ROOT
ANDROID_ROOT=$ANDROID_ROOT
ACTIVE_PRODUCT_MK=$ACTIVE_PRODUCT_MK
ACTIVE_PRODUCT_PATH=$ACTIVE_PRODUCT_PATH
PLATFORM_SABLE_ROOT=${PLATFORM_SABLE_ROOT:-ABSENT}
EVIDENCE_DIR=$EVIDENCE_DIR
DEVICE_CONTACT_AUTHORIZED=NO
ADB_COMMANDS_RUN=NO
FASTBOOT_COMMANDS_RUN=NO
BUILD_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
FACTORY_RESET_AUTHORIZED=NO
PUBLIC_RELEASE=NO
PRODUCTION_SIGNING=NO
EOF

if [[ -n "$PLATFORM_SABLE_ROOT_MISSING" ]]; then
  emit NOT_CHECKED COMPOSITION_PLATFORM_SABLE_ROOT "missing=$PLATFORM_SABLE_ROOT_MISSING"
fi

require_file COMPOSITION_BUILD_README_PRESENT "$ROOT/build/README.md"
for kind in target-files full-device-images gsi-system-image system-product-bundle boot-recovery-bundle; do
  require_text "COMPOSITION_ARTIFACT_KIND_${kind//-/_}" "$kind" "$ROOT/build/README.md"
done
require_file COMPOSITION_SABLE_ENTRYPOINT_PRESENT "$ROOT/build/sable.sh"
require_text COMPOSITION_ENTRYPOINT_REGISTER_GENERIC_ARTIFACTS "--artifact-kind" "$ROOT/build/sable.sh"
require_text COMPOSITION_ENTRYPOINT_SHOW_ARTIFACT "show-artifact" "$ROOT/build/sable.sh"
require_text COMPOSITION_ENTRYPOINT_FLASH_PLAN "flash-plan" "$ROOT/build/sable.sh"

require_file COMPOSITION_PANTHER_ADAPTER_PRESENT "$ROOT/build/devices/panther.sh"
require_text COMPOSITION_PANTHER_TARGET_FILES_ONLY "target-files" "$ROOT/build/devices/panther.sh"
require_text COMPOSITION_PANTHER_BUILD_SUPPORTED "SABLE_DEVICE_BUILD_SUPPORTED=YES" "$ROOT/build/devices/panther.sh"
require_file COMPOSITION_TITAN2_ADAPTER_PRESENT "$ROOT/build/devices/titan2.sh"
note_text COMPOSITION_TITAN2_GSI_ARTIFACT_KIND "gsi-system-image" "$ROOT/build/devices/titan2.sh"
if grep -Fq "SABLE_DEVICE_BUILD_SUPPORTED=YES" "$ROOT/build/devices/titan2.sh"; then
  emit PASS COMPOSITION_TITAN2_CANONICAL_BUILD_SUPPORTED "titan2 adapter enables canonical build"
else
  emit BLOCKED COMPOSITION_TITAN2_CANONICAL_BUILD_SUPPORTED "Titan2 canonical build remains fail-closed"
fi
if grep -Eq "N1B2|n1b2" "$ROOT/build/devices/titan2.sh"; then
  emit PASS COMPOSITION_TITAN2_N1B2_RELEASE_GATE "Titan2 adapter mentions N1B2"
else
  emit FAIL COMPOSITION_TITAN2_N1B2_RELEASE_GATE "Titan2 adapter does not explicitly gate/register N1B2"
fi

require_file COMPOSITION_GRADLE_SETTINGS_PRESENT "$ROOT/apps/r8/android/settings.gradle.kts"
for module in design calculator games media hub weather calendar; do
  module_in_gradle "$module" && emit PASS "COMPOSITION_GRADLE_MODULE_${module^^}" "module=$module" || emit FAIL "COMPOSITION_GRADLE_MODULE_${module^^}" "missing_module=$module"
done
check_gradle_expected_module COMPOSITION_GRADLE_EXPECTED_MODULE_MAIL mail
check_gradle_expected_module COMPOSITION_GRADLE_EXPECTED_MODULE_MESSAGES messages
check_gradle_expected_module COMPOSITION_GRADLE_EXPECTED_MODULE_PEOPLE people
check_gradle_expected_module COMPOSITION_GRADLE_EXPECTED_MODULE_READER reader
check_gradle_expected_module COMPOSITION_GRADLE_EXPECTED_MODULE_TEXTREADER textreader
check_gradle_expected_module COMPOSITION_GRADLE_EXPECTED_MODULE_BROWSER browser
check_gradle_expected_module COMPOSITION_GRADLE_EXPECTED_MODULE_SETTINGS settings
check_gradle_expected_module COMPOSITION_GRADLE_EXPECTED_MODULE_SYSTEMUI systemui
check_gradle_expected_module COMPOSITION_GRADLE_EXPECTED_MODULE_PHONE phone
check_gradle_expected_module COMPOSITION_GRADLE_EXPECTED_MODULE_CONTACTS contacts

require_file COMPOSITION_REPO_SABLELAUNCHER_BP "$ROOT/src/android/packages/apps/SableStart/Android.bp"
require_text COMPOSITION_REPO_SABLELAUNCHER_MODULE "SableLauncher" "$ROOT/src/android/packages/apps/SableStart/Android.bp"
require_file COMPOSITION_REPO_SABLELAUNCHER_MANIFEST "$ROOT/src/android/packages/apps/SableStart/AndroidManifest.xml"
require_text COMPOSITION_REPO_SABLELAUNCHER_PACKAGE "org.sableos.launcher" "$ROOT/src/android/packages/apps/SableStart/AndroidManifest.xml"
require_text COMPOSITION_REPO_SABLELAUNCHER_HOME "android.intent.category.HOME" "$ROOT/src/android/packages/apps/SableStart/AndroidManifest.xml"
require_file COMPOSITION_REPO_SABLE_DESIGN_BP "$ROOT/src/android/shared/sabledesign/Android.bp"

PROFILE_MK="$ANDROID_ROOT/vendor/sable/n1b2/sable_n1b2_product_profile.mk"
PRODUCT_CLOSURE_ENV="$ANDROID_ROOT/vendor/sable/n1b2/product-closure.env"
UX_READINESS_ENV="$ANDROID_ROOT/vendor/sable/n1b2/ux-testbed-readiness.env"
PROFILE_DIR="$ANDROID_ROOT/vendor/sable/n1b2/profiles/titan2"
require_file COMPOSITION_ACTIVE_PRODUCT_MK_PRESENT "$ACTIVE_PRODUCT_PATH"
require_file COMPOSITION_N1B2_PROFILE_MK_PRESENT "$PROFILE_MK"
require_file COMPOSITION_N1B2_PRODUCT_CLOSURE_ENV_PRESENT "$PRODUCT_CLOSURE_ENV"
require_file COMPOSITION_N1B2_UX_READINESS_ENV_PRESENT "$UX_READINESS_ENV"
require_text COMPOSITION_ACTIVE_PRODUCT_INHERITS_N1B2_PROFILE "vendor/sable/n1b2/sable_n1b2_product_profile.mk" "$ACTIVE_PRODUCT_PATH"
require_text COMPOSITION_PRODUCT_SELECTS_SABLELAUNCHER "SableLauncher" "$PROFILE_MK"
require_text COMPOSITION_PRODUCT_MARKS_HOME_PACKAGE "N1B2_HOME_PACKAGE=org.sableos.launcher" "$PRODUCT_CLOSURE_ENV"
require_text COMPOSITION_PRODUCT_MARKS_QUICKSTEP_RECENTS_ONLY "N1B2_QUICKSTEP_ROLE=RECENTS_ONLY" "$PRODUCT_CLOSURE_ENV"
require_text COMPOSITION_PRODUCT_PROPERTIES_HOME_PACKAGE "ro.sableos.home_package=org.sableos.launcher" "$PROFILE_MK"
for profile in hardware.env display.env panel-power.env attention.env keyboard.env pointer.env critical-text-entry.env app-layout.env; do
  require_file "COMPOSITION_TITAN2_PROFILE_${profile//[-.]/_}_SOURCE" "$PROFILE_DIR/$profile"
  require_text "COMPOSITION_TITAN2_PROFILE_${profile//[-.]/_}_COPY" "profiles/titan2/$profile" "$PROFILE_MK"
done

require_file COMPOSITION_ANDROID_SABLELAUNCHER_BP "$ANDROID_ROOT/packages/apps/SableStart/Android.bp"
require_file COMPOSITION_ANDROID_SABLELAUNCHER_MANIFEST "$ANDROID_ROOT/packages/apps/SableStart/AndroidManifest.xml"
require_file COMPOSITION_ANDROID_SABLE_DESIGN_BP "$ANDROID_ROOT/packages/apps/SableDesign/Android.bp"
android_module_present SableLauncher && emit PASS COMPOSITION_ANDROID_MODULE_SABLELAUNCHER_PRESENT "module=SableLauncher" || emit FAIL COMPOSITION_ANDROID_MODULE_SABLELAUNCHER_PRESENT "module=SableLauncher"
product_selects SableLauncher && emit PASS COMPOSITION_ANDROID_PRODUCT_SELECTS_SABLELAUNCHER "module=SableLauncher" || emit FAIL COMPOSITION_ANDROID_PRODUCT_SELECTS_SABLELAUNCHER "module=SableLauncher"

for module in SableHub SableMail SableCalendar SableWeather SableMedia SableMessages SablePeople SableReader SableTextReader SableCommand SableSettings SablePhone SableContacts; do
  android_module_present "$module" && emit PASS "COMPOSITION_ANDROID_MODULE_${module^^}_PRESENT" "module=$module" || emit NOT_PROVEN "COMPOSITION_ANDROID_MODULE_${module^^}_PRESENT" "module_not_found=$module"
  product_selects "$module" && emit PASS "COMPOSITION_ANDROID_PRODUCT_SELECTS_${module^^}" "module=$module" || emit NOT_PROVEN "COMPOSITION_ANDROID_PRODUCT_SELECTS_${module^^}" "not_selected_in_n1b2_product_profile module=$module"
done

if [[ -n "$PLATFORM_SABLE_ROOT" ]]; then
  for doc in docs/ARCHITECTURE.md docs/design/KEYBOARD_FIRST_SYSTEM_IMG_COVERAGE_AUDIT.md docs/design/SETUP_WIZARD_FIRST_BOOT_UX.md docs/design/SABLE_START_KEYBOARD_FIRST_UX.md docs/design/SABLE_HUB_KEYBOARD_FIRST_UX.md docs/design/QUICK_SETTINGS_NOTIFICATION_SHADE_UX.md docs/design/KEYBOARD_FIRST_SETTINGS_UX.md docs/design/BROWSER_WEBVIEW_UX.md; do
    require_file "COMPOSITION_PLATFORM_${doc//[^A-Za-z0-9]/_}" "$PLATFORM_SABLE_ROOT/$doc"
  done
else
  emit NOT_CHECKED COMPOSITION_PLATFORM_SABLE_DOCS "--platform-sable-root not supplied"
fi

for path in "$ROOT/apps" "$ROOT/src/android/shared" "$ROOT/build/panther" "$ROOT/tests"; do
  [[ -d "$path" ]] || continue

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
    | xargs -0 -r grep -n -E \
      "titan2|Titan2|Titan 2|N1B|N1B2|tdgsi|Restless|g71v78c2k|MT6878|vendor/sable/n1b2" \
      >> "$TAINT_REPORT" 2>/dev/null || true
done
if [[ -s "$TAINT_REPORT" ]]; then
  [[ "$FAIL_ON_PANTHER_TAINT" == YES ]] && emit FAIL COMPOSITION_PANTHER_TAINT_CHECK "taint_report=$TAINT_REPORT" || emit WARN COMPOSITION_PANTHER_TAINT_CHECK "taint_report=$TAINT_REPORT"
else
  emit PASS COMPOSITION_PANTHER_TAINT_CHECK "no_titan2_tokens_in_common_apps_or_panther_paths"
fi

emit NOT_PROVEN COMPOSITION_RUNTIME_SETUP_WIZARD_KEYBOARD "requires post-flash/runtime evidence"
emit NOT_PROVEN COMPOSITION_RUNTIME_LOCKSCREEN_TEXT_ENTRY "requires post-flash/runtime evidence"
emit NOT_PROVEN COMPOSITION_RUNTIME_GLOBAL_THEME_PROPAGATION "requires post-flash/runtime evidence"
emit NOT_PROVEN COMPOSITION_RUNTIME_VANADIUM_LABEL "requires package/string/runtime evidence"
emit NOT_PROVEN COMPOSITION_RUNTIME_QS_SHADE_BRANDING "requires SystemUI/runtime evidence"

cat <<EOF | tee -a "$REPORT"
N1B2_COMPOSITION_AUDIT_PASSES=$passes
N1B2_COMPOSITION_AUDIT_WARNINGS=$warnings
N1B2_COMPOSITION_AUDIT_FAILURES=$failures
N1B2_COMPOSITION_AUDIT_REPORT=$REPORT
PANTHER_TAINT_REPORT=$TAINT_REPORT
EOF

if ((failures > 0)); then
  echo "N1B2_COMPOSITION_AUDIT=FAIL failures=$failures warnings=$warnings report=$REPORT"
  exit 1
fi
if ((warnings > 0)); then
  echo "N1B2_COMPOSITION_AUDIT=PASS_WITH_WARNINGS warnings=$warnings report=$REPORT"
else
  echo "N1B2_COMPOSITION_AUDIT=PASS report=$REPORT"
fi
