#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
AUDIT="$ROOT/build/titan2/audit-n1b2-composition.sh"
DOC="$ROOT/docs/titan2/N1B2_COMPOSITION_AUDIT.md"
README="$ROOT/build/README.md"
SABLE="$ROOT/build/sable.sh"
PANTHER="$ROOT/build/devices/panther.sh"
TITAN2="$ROOT/build/devices/titan2.sh"

fail() {
  echo "N1B2_COMPOSITION_AUDIT_CONTRACT_FAILURE=$*" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "missing file: $path"
}

require_text() {
  local pattern="$1"
  local path="$2"
  grep -Fq -- "$pattern" "$path" || fail "missing required marker '$pattern' in $path"
}

echo "===== N1B2 COMPOSITION AUDIT CONTRACT ====="
echo "ROOT=$ROOT"

require_file "$AUDIT"
require_file "$DOC"
require_file "$README"
require_file "$SABLE"
require_file "$PANTHER"
require_file "$TITAN2"

bash -n "$AUDIT"

# Scope and safety markers.
require_text "DEVICE_CONTACT_AUTHORIZED=NO" "$AUDIT"
require_text "ADB_COMMANDS_RUN=NO" "$AUDIT"
require_text "FASTBOOT_COMMANDS_RUN=NO" "$AUDIT"
require_text "BUILD_AUTHORIZED=NO" "$AUDIT"
require_text "FLASH_AUTHORIZED=NO" "$AUDIT"
require_text "FACTORY_RESET_AUTHORIZED=NO" "$AUDIT"
require_text "PUBLIC_RELEASE=NO" "$AUDIT"
require_text "PRODUCTION_SIGNING=NO" "$AUDIT"
require_text "This script does not build" "$AUDIT"
require_text "does not contact a device" "$AUDIT"
require_text "does not flash" "$AUDIT"

# Required operator inputs and artifact classes.
require_text "--android-root" "$AUDIT"
require_text "--active-product-mk" "$AUDIT"
require_text "--platform-sable-root" "$AUDIT"
require_text "target-files" "$AUDIT"
require_text "full-device-images" "$AUDIT"
require_text "gsi-system-image" "$AUDIT"
require_text "system-product-bundle" "$AUDIT"
require_text "boot-recovery-bundle" "$AUDIT"

# Canonical build/deploy surface audit.
require_text "build/README.md" "$AUDIT"
require_text "build/sable.sh" "$AUDIT"
require_text "COMPOSITION_ENTRYPOINT_REGISTER_GENERIC_ARTIFACTS" "$AUDIT"
require_text "COMPOSITION_ENTRYPOINT_SHOW_ARTIFACT" "$AUDIT"
require_text "COMPOSITION_ENTRYPOINT_FLASH_PLAN" "$AUDIT"
require_text "COMPOSITION_PANTHER_TARGET_FILES_ONLY" "$AUDIT"
require_text "COMPOSITION_TITAN2_GSI_ARTIFACT_KIND" "$AUDIT"
require_text "COMPOSITION_TITAN2_N1B2_RELEASE_GATE" "$AUDIT"

# App/product composition audit.
require_text "apps/r8/android/settings.gradle.kts" "$AUDIT"
require_text "COMPOSITION_GRADLE_EXPECTED_MODULE_MAIL" "$AUDIT"
require_text "COMPOSITION_GRADLE_EXPECTED_MODULE_MESSAGES" "$AUDIT"
require_text "COMPOSITION_GRADLE_EXPECTED_MODULE_SETTINGS" "$AUDIT"
require_text "COMPOSITION_REPO_SABLELAUNCHER_MODULE" "$AUDIT"
require_text "COMPOSITION_ACTIVE_PRODUCT_INHERITS_N1B2_PROFILE" "$AUDIT"
require_text "COMPOSITION_PRODUCT_SELECTS_SABLELAUNCHER" "$AUDIT"
require_text "COMPOSITION_ANDROID_PRODUCT_SELECTS_SABLELAUNCHER" "$AUDIT"
require_text "SableHub" "$AUDIT"
require_text "SableMail" "$AUDIT"
require_text "SableMessages" "$AUDIT"
require_text "SableSettings" "$AUDIT"
require_text "SablePhone" "$AUDIT"
require_text "SableContacts" "$AUDIT"

# Titan2 profile/image-marker composition audit.
require_text "product-closure.env" "$AUDIT"
require_text "ux-testbed-readiness.env" "$AUDIT"
require_text "hardware.env" "$AUDIT"
require_text "display.env" "$AUDIT"
require_text "panel-power.env" "$AUDIT"
require_text "attention.env" "$AUDIT"
require_text "keyboard.env" "$AUDIT"
require_text "pointer.env" "$AUDIT"
require_text "critical-text-entry.env" "$AUDIT"
require_text "app-layout.env" "$AUDIT"

# Panther isolation and runtime-proof posture.
require_text "COMPOSITION_PANTHER_TAINT_CHECK" "$AUDIT"
require_text "FAIL_ON_PANTHER_TAINT" "$AUDIT"
require_text "COMPOSITION_RUNTIME_SETUP_WIZARD_KEYBOARD" "$AUDIT"
require_text "COMPOSITION_RUNTIME_LOCKSCREEN_TEXT_ENTRY" "$AUDIT"
require_text "COMPOSITION_RUNTIME_GLOBAL_THEME_PROPAGATION" "$AUDIT"
require_text "COMPOSITION_RUNTIME_VANADIUM_LABEL" "$AUDIT"
require_text "COMPOSITION_RUNTIME_QS_SHADE_BRANDING" "$AUDIT"

# Documentation must bind the intended use and decision rules.
require_text "N1B2_COMPOSITION_AUDIT=YES" "$DOC"
require_text "NO BUILD" "$DOC"
require_text "NO DEVICE CONTACT" "$DOC"
require_text "Panther taint" "$DOC"
require_text "target-files" "$DOC"
require_text "full-device-images" "$DOC"
require_text "gsi-system-image" "$DOC"
require_text "system-product-bundle" "$DOC"
require_text "boot-recovery-bundle" "$DOC"
require_text "fork" "$DOC"
require_text "platform_sable" "$DOC"

# Current README/operator model must remain the source of truth.
require_text "build/sable.sh <device> <release> <function>" "$README"
require_text "target-files" "$README"
require_text "full-device-images" "$README"
require_text "gsi-system-image" "$README"
require_text "system-product-bundle" "$README"
require_text "boot-recovery-bundle" "$README"

cat <<EOF
N1B2_COMPOSITION_AUDIT_SCRIPT_SYNTAX=PASS
N1B2_COMPOSITION_AUDIT_DOC_BINDING=PASS
N1B2_COMPOSITION_AUDIT_NO_DEVICE_CONTACT=PASS
N1B2_COMPOSITION_AUDIT_CONTRACT=PASS
EOF
