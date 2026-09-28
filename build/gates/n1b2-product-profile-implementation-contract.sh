#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="$ROOT/docs/titan2/N1B2_PRODUCT_PROFILE_IMPLEMENTATION.md"
PREP="$ROOT/build/titan2/prepare-n1b2-product-profile.sh"
COLLECT="$ROOT/build/titan2/collect-n1b2-postboot-acceptance.sh"
UX_GATE="$ROOT/build/gates/n1b2-titan2-ux-testbed-readiness-contract.sh"
IMAGE_BUILD="$ROOT/build/titan2/build-n1b2-image-candidate.sh"

fail() {
  echo "N1B2_PRODUCT_PROFILE_IMPLEMENTATION_CONTRACT_FAILURE=$*" >&2
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

forbid_text() {
  local pattern="$1"
  local path="$2"
  if grep -Fq -- "$pattern" "$path"; then
    fail "forbidden marker '$pattern' present in $path"
  fi
}

echo "===== N1B2 PRODUCT PROFILE IMPLEMENTATION CONTRACT ====="
echo "ROOT=$ROOT"
echo "DOC=$DOC"
echo "PREP=$PREP"
echo "COLLECT=$COLLECT"
echo "UX_GATE=$UX_GATE"
echo "IMAGE_BUILD=$IMAGE_BUILD"

require_file "$DOC"
require_file "$PREP"
require_file "$COLLECT"
require_file "$UX_GATE"
require_file "$IMAGE_BUILD"

bash -n "$PREP"
bash -n "$COLLECT"
bash -n "$UX_GATE"
bash -n "$IMAGE_BUILD"

# Document must bind this implementation to the proven N1B evidence and the N1B2 contract.
require_text "N1B_FIRST_BOOT=PASS" "$DOC"
require_text "FACTORY_RESET_REQUIRED=YES_CONFIRMED" "$DOC"
require_text "N1B_PRODUCT_CLOSURE=FAIL" "$DOC"
require_text "N1B2_PRODUCT_PROFILE_IMPLEMENTATION=YES" "$DOC"
require_text "N1B2_FLASH_ALLOWED=NO_SEPARATE_GATE_REQUIRED" "$DOC"

# Stage ownership and safety boundaries.
require_text "N1_SABLE=SableOS_product_overlay_and_package_deltas" "$DOC"
require_text "STOCK_VENDOR_STRATEGY=PRESERVE" "$DOC"
require_text "STOCK_BOOT_VENDOR_BOOT_STRATEGY=PRESERVE" "$DOC"
require_text "FIRMWARE_MUTATION=NO" "$DOC"
require_text "BOOTLOADER_RELOCK_ALLOWED=NO" "$DOC"
require_text "PUBLIC_RELEASE_WITH_STOCK_BLOBS=NO_UNLESS_SEPARATE_LICENSE_REVIEW" "$DOC"

# Setup Wizard / factory reset path.
require_text "N1B2_SETUP_WIZARD_REQUIRED=YES" "$DOC"
require_text "SETUP_WIZARD_INCLUDED=YES" "$DOC"
require_text "SETUP_WIZARD_SURVIVES_FACTORY_RESET=YES" "$DOC"
require_text "SETUP_WIZARD_MOBILE_NETWORK_STEP_DOES_NOT_DEAD_END=YES" "$DOC"
require_text "SableSetupWizard" "$PREP"
require_text "SetupWizard" "$PREP"
require_text "Provision" "$PREP"
require_text "N1B2_SETUP_WIZARD_MODULE=BLOCKED_NOT_FOUND" "$PREP"

# Sable identity / HOME.
require_text "N1B2_SABLE_PRODUCT_IDENTITY_REQUIRED=YES" "$DOC"
require_text "DEVICE_NAME_TARGET=SableOS Titan2" "$DOC"
require_text "HOME_RESOLVES_TO_SABLE=YES" "$DOC"
require_text "QUICKSTEP_AS_PRIMARY_HOME=NO_UNLESS_EXPLICITLY_APPROVED" "$DOC"
require_text "N1B2_SABLE_HOME_MODULE_PRESENT=YES_REQUIRED" "$DOC"
require_text "N1B2_SABLE_HOME_MISSING_BEHAVIOR=FAIL_CLOSED" "$DOC"
require_text "ALLOW_MISSING_SABLE_HOME=YES_INVESTIGATION_ONLY_NOT_CANDIDATE" "$DOC"
require_text "SABLE_HOME_MODULE" "$PREP"
require_text "N1B2_SABLE_HOME_MODULE_PRESENT=BLOCKED_NOT_FOUND" "$PREP"
require_text "required Sable HOME module is missing from Android workspace" "$PREP"
require_text "ALLOW_MISSING_SABLE_HOME" "$PREP"
require_text "YES_INVESTIGATION_ONLY" "$PREP"
require_text "ro.sableos.release=N1B2" "$PREP"
require_text "ro.sableos.setup_wizard_required=true" "$PREP"

# N1B2 UX readiness and image packaging gates must be part of the build path.
require_text "n1b2-titan2-ux-testbed-readiness-contract.sh" "$PREP"
require_text "N1B2_TITAN2_UX_TESTBED_READINESS_MATRIX=PASS" "$PREP"
require_text "N1B2_UX_TESTBED_ALLOWED_STATUS_SET=PASS|POLICY_PRESENT|EXPLICIT_BOUNDED_DEFERRAL" "$UX_GATE"
require_text "reject_unlisted_matrix_rows" "$UX_GATE"
require_text "SYSTEM/etc/sableos/n1b2/ux-testbed-readiness.env" "$IMAGE_BUILD"
require_text "N1B2_TARGET_FILES_UX_TESTBED_MARKER=PASS" "$IMAGE_BUILD"
require_text "SABLEOS_RELEASE_VERSION=N1B2" "$IMAGE_BUILD"

# Titan2 input and mobile network triage.
require_text "N1B2_TITAN2_INPUT_PROFILE_REQUIRED=YES" "$DOC"
require_text "TITANKEY_ENUMERATED=YES" "$DOC"
require_text "TOUCHPAD_ENUMERATED=YES" "$DOC"
require_text "GENERIC_KL_KCM_AS_FINAL_POLICY=NO" "$DOC"
require_text "N1B2_MOBILE_NETWORK_TRIAGE_REQUIRED=YES" "$DOC"
require_text "MOBILE_NETWORK_STATUS=TRIAGE_REQUIRED" "$DOC"
require_text "LTE_STABILITY_PASS=NO_UNTIL_TIMED_CAPTURE" "$DOC"
require_text "MOBILE_NETWORK_RESULT" "$COLLECT"
require_text "MOBILE_NETWORK_PARTIAL_INTERMITTENT" "$COLLECT"
require_text "MOBILE_NETWORK_STABLE_PASS" "$COLLECT"
require_text "EMERGENCY_CALL_TESTING=NO" "$COLLECT"

# Acceptance collector must be read-only and must not contain device mutation commands.
require_text "DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY_ADB" "$COLLECT"
require_text "FASTBOOT_COMMANDS_RUN=NO" "$COLLECT"
require_text "REBOOT_COMMANDS_RUN=NO" "$COLLECT"
require_text "FLASH_COMMANDS_RUN=NO" "$COLLECT"
require_text "FACTORY_RESET_COMMANDS_RUN=NO" "$COLLECT"
require_text "AVB_MUTATION_COMMANDS_RUN=NO" "$COLLECT"

forbid_text "fastboot flash" "$PREP"
forbid_text "fastboot flash" "$COLLECT"
forbid_text " fastboot " "$COLLECT"
forbid_text "adb reboot" "$COLLECT"
forbid_text "wipe data" "$COLLECT"
forbid_text "factory reset" "$COLLECT"
forbid_text "setprop" "$COLLECT"
forbid_text "cmd role add-role-holder" "$COLLECT"
forbid_text "pm grant" "$COLLECT"
forbid_text "settings put" "$COLLECT"

# Profile prep may patch Android source only with explicit operator flag; it must not contact device.
require_text "--patch-active-product" "$PREP"
require_text "DEVICE_CONTACT_AUTHORIZED=NO_OFFLINE_ONLY" "$PREP"
require_text "ADB_COMMANDS_RUN=NO" "$PREP"
require_text "FASTBOOT_COMMANDS_RUN=NO" "$PREP"
require_text "FLASH_AUTHORIZED=NO" "$PREP"
require_text "FACTORY_RESET_AUTHORIZED=NO" "$PREP"

# Stock image policy.
require_text "STOCK_IMAGES_ON_AI_G732=AVAILABLE" "$DOC"
require_text "LOCAL_PACKAGING_USE=YES_IF_GATED" "$DOC"
require_text "COMMIT_STOCK_IMAGES_TO_GIT=NO" "$DOC"
require_text "COMMIT_EXTRACTED_PROPRIETARY_BINARIES=NO" "$DOC"

echo "N1B2_PRODUCT_PROFILE_DOC=PASS"
echo "N1B2_PRODUCT_PROFILE_PREP_SCRIPT=PASS"
echo "N1B2_POSTBOOT_ACCEPTANCE_SCRIPT=PASS"
echo "N1B2_UX_TESTBED_GATE_SCRIPT=PASS"
echo "N1B2_IMAGE_BUILD_SCRIPT=PASS"
echo "N1B2_SETUP_WIZARD_REQUIREMENT=PASS"
echo "N1B2_SABLE_IDENTITY_HOME_REQUIREMENT=PASS"
echo "N1B2_SABLE_HOME_MISSING_FAIL_CLOSED=PASS"
echo "N1B2_TITAN2_INPUT_REQUIREMENT=PASS"
echo "N1B2_MOBILE_NETWORK_TRIAGE_REQUIREMENT=PASS"
echo "N1B2_FLASH_ALLOWED=NO_SEPARATE_GATE_REQUIRED"
echo "N1B2_PRODUCT_PROFILE_IMPLEMENTATION_CONTRACT=PASS"
