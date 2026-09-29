#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ANDROID_ROOT=""
ACTIVE_PRODUCT_MK=""
EVIDENCE_DIR=""
PLATFORM_SABLE_ROOT=""
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

Offline composition audit for Titan2/N1B2.

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

case "$FAIL_ON_PANTHER_TAINT" in YES|NO) ;; *) echo "N1B2_COMPOSITION_AUDIT=FAIL_BAD_FAIL_ON_PANTHER_TAINT value=$FAIL_ON_PANTHER_TAINT" >&2; exit 64 ;; esac
[[ -n "$ANDROID_ROOT" ]] || { echo "N1B2_COMPOSITION_AUDIT=FAIL_ANDROID_ROOT_REQUIRED" >&2; usage; exit 64; }
[[ -n "$ACTIVE_PRODUCT_MK" ]] || { echo "N1B2_COMPOSITION_AUDIT=FAIL_ACTIVE_PRODUCT_MK_REQUIRED" >&2; usage; exit 64; }
[[ "$ACTIVE_PRODUCT_MK" != /* ]] || { echo "N1B2_COMPOSITION_AUDIT=FAIL_ACTIVE_PRODUCT_MK_ABSOLUTE" >&2; exit 64; }
[[ -d "$ANDROID_ROOT" ]] || { echo "N1B2_COMPOSITION_AUDIT=FAIL_ANDROID_ROOT_NOT_FOUND path=$ANDROID_ROOT" >&2; exit 64; }
ANDROID_ROOT="$(cd "$ANDROID_ROOT" && pwd)"
ACTIVE_PRODUCT_PATH="$ANDROID_ROOT/$ACTIVE_PRODUCT_MK"
[[ -f "$ACTIVE_PRODUCT_PATH" ]] || { echo "N1B2_COMPOSITION_AUDIT=FAIL_ACTIVE_PRODUCT_MK_NOT_FOUND path=$ACTIVE_PRODUCT_PATH" >&2; exit 64; }

if [[ -n "$PLATFORM_SABLE_ROOT" ]]; then
  [[ -d "$PLATFORM_SABLE_ROOT" ]] || { echo "N1B2_COMPOSITION_AUDIT=FAIL_PLATFORM_SABLE_ROOT_NOT_FOUND path=$PLATFORM_SABLE_ROOT" >&2; exit 64; }
  PLATFORM_SABLE_ROOT="$(cd "$PLATFORM_SABLE_ROOT" && pwd)"
fi

if [[ -z "$EVIDENCE_DIR" ]]; then
  EVIDENCE_DIR="/tmp/SABLE_N1B2_COMPOSITION_AUDIT_$(date -u +%Y%m%dT%H%M%SZ)"
fi
mkdir -p "$EVIDENCE_DIR"
REPORT="$EVIDENCE_DIR/n1b2-composition-audit.env"
SUMMARY="$EVIDENCE_DIR/n1b2-composition-audit.md"
: > "$REPORT"
: > "$SUMMARY"

failures=0
warnings=0
passes=0
notes=0

emit() {
  local status="$1"
  local key="$2"
  local detail="${3:-}"
  printf '%s=%s' "$key" "$status" | tee -a "$REPORT"
  if [[ -n "$detail" ]]; then
    printf ' %s' "$detail" | tee -a "$REPORT"
  fi
  printf '\n' | tee -a "$REPORT"
  case "$status" in
    PASS) passes=$((passes + 1)) ;;
    WARN|BLOCKED|NOT_PROVEN|NOT_CHECKED) warnings=$((warnings + 1)) ;;
    FAIL) failures=$((failures + 1)) ;;
    *) notes=$((notes + 1)) ;;
  esac
}

require_file_status() {
  local key="$1"
  local path="$2"
  if [[ -f "$path" ]]; then
    emit PASS "$key" "path=$path"
  else
    emit FAIL "$key" "missing=$path"
  fi
}

require_text_status() {
  local key="$1"
  local pattern="$2"
  local path="$3"
  if [[ -f "$path" ]] && grep -Fq -- "$pattern" "$path"; then
    emit PASS "$key" "pattern=$(printf '%q' "$pattern") path=$path"
  else
    emit FAIL "$key" "missing_pattern=$(printf '%q' "$pattern") path=$path"
  fi
}

warn_text_status() {
  local key="$1"
  local pattern="$2"
  local path="$3"
  if [[ -f "$path" ]] && grep -Fq -- "$pattern" "$path"; then
    emit PASS "$key" "pattern=$(printf '%q' "$pattern") path=$path"
  else
    emit WARN "$key" "missing_pattern=$(printf '%q' "$pattern") path=$path"
  fi
}

module_in_gradle() {
  local module="$1"
  grep -Fq "include(\":$module\")" "$ROOT/apps/r8/android/settings.gradle.kts"
}

android_module_present() {
  local module="$1"
  local pattern_bp='name: "'"$module"'"'
  local pattern_mk='LOCAL_MODULE := '"$module"
  grep -R --include='Android.bp' --include='Android.mk' -Fq -- "$pattern_bp" "$ANDROID_ROOT" 2>/dev/null || \
    grep -R --include='Android.bp' --include='Android.mk' -Fq -- "$pattern_mk" "$ANDROID_ROOT" 2>/dev/null
}

product_selects() {
  local module="$1"
  [[ -f "$ANDROID_ROOT/vendor/sable/n1b2/sable_n1b2_product_profile.mk" ]] && \
    grep -Eq "(^|[[:space:]])${module}([[:space:]]|\\\\|$)" "$ANDROID_ROOT/vendor/sable/n1b2/sable_n1b2_product_profile.mk"
}

copy_file_selected() {
  local rel="$1"
  [[ -f "$ANDROID_ROOT/vendor/sable/n1b2/sable_n1b2_product_profile.mk" ]] && \
    grep -Fq -- "$rel" "$ANDROID_ROOT/vendor/sable/n1b2/sable_n1b2_product_profile.mk"
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

# Canonical build interface and artifact classes.
require_file_status "COMPOSITION_BUILD_README_PRESENT" "$ROOT/build/README.md"
for kind in target-files full-device-images gsi-system-image system-product-bundle boot-recovery-bundle; do
  require_text_status "COMPOSITION_ARTIFACT_KIND_${kind//-/_}" "$kind" "$ROOT/build/README.md"
done
require_file_status "COMPOSITION_SABLE_ENTRYPOINT_PRESENT" "$ROOT/build/sable.sh"
require_text_status "COMPOSITION_ENTRYPOINT_REGISTER_GENERIC_ARTIFACTS" "--artifact-kind" "$ROOT/build/sable.sh"
require_text_status "COMPOSITION_ENTRYPOINT_SHOW_ARTIFACT" "show-artifact" "$ROOT/build/sable.sh"
require_text_status "COMPOSITION_ENTRYPOINT_FLASH_PLAN" "flash-plan" "$ROOT/build/sable.sh"

# Device adapters.
require_file_status "COMPOSITION_PANTHER_ADAPTER_PRESENT" "$ROOT/build/devices/panther.sh"
require_text_status "COMPOSITION_PANTHER_TARGET_FILES_ONLY" 'SABLE_DEVICE_ARTIFACT_KINDS="target-files"' "$ROOT/build/devices/panther.sh"
require_text_status "COMPOSITION_PANTHER_BUILD_SUPPORTED" 'SABLE_DEVICE_BUILD_SUPPORTED=YES' "$ROOT/build/devices/panther.sh"
require_file_status "COMPOSITION_TITAN2_ADAPTER_PRESENT" "$ROOT/build/devices/titan2.sh"
warn_text_status "COMPOSITION_TITAN2_GSI_ARTIFACT_KIND" 'SABLE_DEVICE_ARTIFACT_KINDS="gsi-system-image"' "$ROOT/build/devices/titan2.sh"
if grep -Fq 'SABLE_DEVICE_BUILD_SUPPORTED=YES' "$ROOT/build/devices/titan2.sh"; then
  emit PASS "COMPOSITION_TITAN2_CANONICAL_BUILD_SUPPORTED" "build/devices/titan2.sh"
else
  emit BLOCKED "COMPOSITION_TITAN2_CANONICAL_BUILD_SUPPORTED" "Titan2 canonical build remains fail-closed"
fi
if grep -Eq 'N1B2|n1b2' "$ROOT/build/devices/titan2.sh"; then
  emit PASS "COMPOSITION_TITAN2_N1B2_RELEASE_GATE" "build/devices/titan2.sh mentions N1B2"
else
  emit FAIL "COMPOSITION_TITAN2_N1B2_RELEASE_GATE" "build/devices/titan2.sh does not allow/register N1B2 explicitly"
fi

# Private repo app composition.
require_file_status "COMPOSITION_GRADLE_SETTINGS_PRESENT" "$ROOT/apps/r8/android/settings.gradle.kts"
for module in design calculator games media hub weather calendar; do
  if module_in_gradle "$module"; then
    emit PASS "COMPOSITION_GRADLE_MODULE_${module^^}" "module=$module"
  else
    emit FAIL "COMPOSITION_GRADLE_MODULE_${module^^}" "missing_module=$module"
  fi
done
for module in mail messages people reader textreader browser settings systemui phone contacts; do
  if module_in_gradle "$module"; then
    emit PASS "COMPOSITION_GRADLE_EXPECTED_MODULE_${module^^}" "module=$module"
  else
    emit NOT_PROVEN "COMPOSITION_GRADLE_EXPECTED_MODULE_${module^^}" "not_listed_in_apps_gradle module=$module"
  fi
done

# Repository-owned Android package source.
require_file_status "COMPOSITION_REPO_SABLELAUNCHER_BP" "$ROOT/src/android/packages/apps/SableStart/Android.bp"
require_text_status "COMPOSITION_REPO_SABLELAUNCHER_MODULE" 'name: "SableLauncher"' "$ROOT/src/android/packages/apps/SableStart/Android.bp"
require_file_status "COMPOSITION_REPO_SABLELAUNCHER_MANIFEST" "$ROOT/src/android/packages/apps/SableStart/AndroidManifest.xml"
require_text_status "COMPOSITION_REPO_SABLELAUNCHER_PACKAGE" 'package="org.sableos.launcher"' "$ROOT/src/android/packages/apps/SableStart/AndroidManifest.xml"
require_text_status "COMPOSITION_REPO_SABLELAUNCHER_HOME" 'android.intent.category.HOME' "$ROOT/src/android/packages/apps/SableStart/AndroidManifest.xml"
require_file_status "COMPOSITION_REPO_SABLE_DESIGN_BP" "$ROOT/src/android/shared/sabledesign/Android.bp"

# Android workspace product composition.
PROFILE_MK="$ANDROID_ROOT/vendor/sable/n1b2/sable_n1b2_product_profile.mk"
PRODUCT_CLOSURE_ENV="$ANDROID_ROOT/vendor/sable/n1b2/product-closure.env"
UX_READINESS_ENV="$ANDROID_ROOT/vendor/sable/n1b2/ux-testbed-readiness.env"
PROFILE_DIR="$ANDROID_ROOT/vendor/sable/n1b2/profiles/titan2"
require_file_status "COMPOSITION_ACTIVE_PRODUCT_MK_PRESENT" "$ACTIVE_PRODUCT_PATH"
require_file_status "COMPOSITION_N1B2_PROFILE_MK_PRESENT" "$PROFILE_MK"
require_file_status "COMPOSITION_N1B2_PRODUCT_CLOSURE_ENV_PRESENT" "$PRODUCT_CLOSURE_ENV"
require_file_status "COMPOSITION_N1B2_UX_READINESS_ENV_PRESENT" "$UX_READINESS_ENV"
require_text_status "COMPOSITION_ACTIVE_PRODUCT_INHERITS_N1B2_PROFILE" 'vendor/sable/n1b2/sable_n1b2_product_profile.mk' "$ACTIVE_PRODUCT_PATH"
require_text_status "COMPOSITION_PRODUCT_SELECTS_SABLELAUNCHER" 'SableLauncher' "$PROFILE_MK"
require_text_status "COMPOSITION_PRODUCT_MARKS_HOME_PACKAGE" 'N1B2_HOME_PACKAGE=org.sableos.launcher' "$PRODUCT_CLOSURE_ENV"
require_text_status "COMPOSITION_PRODUCT_MARKS_QUICKSTEP_RECENTS_ONLY" 'N1B2_QUICKSTEP_ROLE=RECENTS_ONLY' "$PRODUCT_CLOSURE_ENV"
require_text_status "COMPOSITION_PRODUCT_PROPERTIES_HOME_PACKAGE" 'ro.sableos.home_package=org.sableos.launcher' "$PROFILE_MK"

for profile in hardware.env display.env panel-power.env attention.env keyboard.env pointer.env critical-text-entry.env app-layout.env; do
  require_file_status "COMPOSITION_TITAN2_PROFILE_${profile//[-.]/_}_SOURCE" "$PROFILE_DIR/$profile"
  if copy_file_selected "profiles/titan2/$profile"; then
    emit PASS "COMPOSITION_TITAN2_PROFILE_${profile//[-.]/_}_COPY" "profile=$profile"
  else
    emit FAIL "COMPOSITION_TITAN2_PROFILE_${profile//[-.]/_}_COPY" "not_selected_in_product_mk profile=$profile"
  fi
done

# SableLauncher source copied into Android workspace.
require_file_status "COMPOSITION_ANDROID_SABLELAUNCHER_BP" "$ANDROID_ROOT/packages/apps/SableStart/Android.bp"
require_file_status "COMPOSITION_ANDROID_SABLELAUNCHER_MANIFEST" "$ANDROID_ROOT/packages/apps/SableStart/AndroidManifest.xml"
require_file_status "COMPOSITION_ANDROID_SABLE_DESIGN_BP" "$ANDROID_ROOT/packages/apps/SableDesign/Android.bp"
if android_module_present SableLauncher; then
  emit PASS "COMPOSITION_ANDROID_MODULE_SABLELAUNCHER_PRESENT" "module=SableLauncher"
else
  emit FAIL "COMPOSITION_ANDROID_MODULE_SABLELAUNCHER_PRESENT" "module=SableLauncher"
fi
if product_selects SableLauncher; then
  emit PASS "COMPOSITION_ANDROID_PRODUCT_SELECTS_SABLELAUNCHER" "module=SableLauncher"
else
  emit FAIL "COMPOSITION_ANDROID_PRODUCT_SELECTS_SABLELAUNCHER" "module=SableLauncher"
fi

# Design-driven product surfaces that must not be claimed unless present.
# These names intentionally check for product/image composition, not Gradle-only source.
for module in SableHub SableMail SableCalendar SableWeather SableMedia SableMessages SablePeople SableReader SableTextReader SableCommand SableSettings SablePhone SableContacts; do
  if android_module_present "$module"; then
    emit PASS "COMPOSITION_ANDROID_MODULE_${module^^}_PRESENT" "module=$module"
  else
    emit NOT_PROVEN "COMPOSITION_ANDROID_MODULE_${module^^}_PRESENT" "module_not_found=$module"
  fi
  if product_selects "$module"; then
    emit PASS "COMPOSITION_ANDROID_PRODUCT_SELECTS_${module^^}" "module=$module"
  else
    emit NOT_PROVEN "COMPOSITION_ANDROID_PRODUCT_SELECTS_${module^^}" "not_selected_in_n1b2_product_profile module=$module"
  fi
done

# Platform_sable docs/artifacts if a local checkout is supplied.
if [[ -n "$PLATFORM_SABLE_ROOT" ]]; then
  require_file_status "COMPOSITION_PLATFORM_ARCHITECTURE_DOC" "$PLATFORM_SABLE_ROOT/docs/ARCHITECTURE.md"
  require_file_status "COMPOSITION_PLATFORM_SYSTEM_IMG_AUDIT_DOC" "$PLATFORM_SABLE_ROOT/docs/design/KEYBOARD_FIRST_SYSTEM_IMG_COVERAGE_AUDIT.md"
  require_file_status "COMPOSITION_PLATFORM_SETUP_WIZARD_DOC" "$PLATFORM_SABLE_ROOT/docs/design/SETUP_WIZARD_FIRST_BOOT_UX.md"
  require_file_status "COMPOSITION_PLATFORM_SABLE_START_DOC" "$PLATFORM_SABLE_ROOT/docs/design/SABLE_START_KEYBOARD_FIRST_UX.md"
  require_file_status "COMPOSITION_PLATFORM_HUB_DOC" "$PLATFORM_SABLE_ROOT/docs/design/SABLE_HUB_KEYBOARD_FIRST_UX.md"
  require_file_status "COMPOSITION_PLATFORM_QS_DOC" "$PLATFORM_SABLE_ROOT/docs/design/QUICK_SETTINGS_NOTIFICATION_SHADE_UX.md"
  require_file_status "COMPOSITION_PLATFORM_SETTINGS_DOC" "$PLATFORM_SABLE_ROOT/docs/design/KEYBOARD_FIRST_SETTINGS_UX.md"
  require_file_status "COMPOSITION_PLATFORM_BROWSER_DOC" "$PLATFORM_SABLE_ROOT/docs/design/BROWSER_WEBVIEW_UX.md"
else
  emit NOT_CHECKED "COMPOSITION_PLATFORM_SABLE_DOCS" "--platform-sable-root not supplied"
fi

# Panther taint check: Titan2/N1B device-specific tokens must not appear in common app source or Panther build path.
TAINT_REPORT="$EVIDENCE_DIR/panther-taint-grep.txt"
: > "$TAINT_REPORT"
for path in "$ROOT/apps" "$ROOT/src/android/shared" "$ROOT/build/panther" "$ROOT/tests"; do
  [[ -d "$path" ]] || continue
  grep -R -n -E 'titan2|Titan2|Titan 2|N1B|N1B2|tdgsi|Restless|g71v78c2k|MT6878|vendor/sable/n1b2' "$path" \
    --exclude-dir='.git' \
    --exclude='*.png' --exclude='*.jpg' --exclude='*.webp' --exclude='*.mp4' \
    >> "$TAINT_REPORT" 2>/dev/null || true
done
if [[ -s "$TAINT_REPORT" ]]; then
  if [[ "$FAIL_ON_PANTHER_TAINT" == YES ]]; then
    emit FAIL "COMPOSITION_PANTHER_TAINT_CHECK" "taint_report=$TAINT_REPORT"
  else
    emit WARN "COMPOSITION_PANTHER_TAINT_CHECK" "taint_report=$TAINT_REPORT"
  fi
else
  emit PASS "COMPOSITION_PANTHER_TAINT_CHECK" "no_titan2_tokens_in_common_apps_or_panther_paths"
fi

# Runtime proofs intentionally not inferred from package/source presence.
emit NOT_PROVEN "COMPOSITION_RUNTIME_SETUP_WIZARD_KEYBOARD" "requires post-flash/runtime evidence"
emit NOT_PROVEN "COMPOSITION_RUNTIME_LOCKSCREEN_TEXT_ENTRY" "requires post-flash/runtime evidence"
emit NOT_PROVEN "COMPOSITION_RUNTIME_GLOBAL_THEME_PROPAGATION" "requires post-flash/runtime evidence"
emit NOT_PROVEN "COMPOSITION_RUNTIME_VANADIUM_LABEL" "requires package/string/runtime evidence"
emit NOT_PROVEN "COMPOSITION_RUNTIME_QS_SHADE_BRANDING" "requires SystemUI/runtime evidence"

cat > "$SUMMARY" <<EOF
# N1B2 Titan2 composition audit

- passes: $passes
- warnings/not-proven/not-checked/blocked: $warnings
- failures: $failures

Primary report: \`$REPORT\`
Panther taint report: \`$TAINT_REPORT\`

This audit is offline only. It does not build, does not contact a device, does
not run adb/fastboot, does not flash, and does not authorize public release or
production signing.
EOF

cat <<EOF | tee -a "$REPORT"
N1B2_COMPOSITION_AUDIT_PASSES=$passes
N1B2_COMPOSITION_AUDIT_WARNINGS=$warnings
N1B2_COMPOSITION_AUDIT_FAILURES=$failures
N1B2_COMPOSITION_AUDIT_REPORT=$REPORT
N1B2_COMPOSITION_AUDIT_SUMMARY=$SUMMARY
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
