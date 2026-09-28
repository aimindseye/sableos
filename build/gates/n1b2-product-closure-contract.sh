#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="$ROOT/docs/titan2/N1B2_PRODUCT_CLOSURE_REQUIREMENTS.md"

fail() {
  echo "N1B2_PRODUCT_CLOSURE_CONTRACT_FAILURE=$*" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "missing file: $path"
}

require_text() {
  local pattern="$1"
  local path="$2"
  grep -Fq "$pattern" "$path" || fail "missing required marker '$pattern' in $path"
}

forbid_text() {
  local pattern="$1"
  local path="$2"
  if grep -Fq "$pattern" "$path"; then
    fail "forbidden marker '$pattern' present in $path"
  fi
}

echo "===== N1B2 PRODUCT CLOSURE CONTRACT ====="
echo "ROOT=$ROOT"
echo "DOC=$DOC"

require_file "$DOC"

# Proven N1B state carried into N1B2.
require_text "FIRST_N1B_BOOT=PASS" "$DOC"
require_text "FACTORY_RESET_REQUIRED=YES_CONFIRMED" "$DOC"
require_text "N1B2_FLASH_ALLOWED=NO_SEPARATE_GATE_REQUIRED" "$DOC"

# Setup Wizard is mandatory because userdata wipe is now part of the proven path.
require_text "N1B2_SETUP_WIZARD_REQUIRED=YES" "$DOC"
require_text "SETUP_WIZARD_INCLUDED=YES" "$DOC"
require_text "SETUP_WIZARD_SURVIVES_FACTORY_RESET=YES" "$DOC"
require_text "SETUP_WIZARD_PRIMARY_DISPLAY_USABLE=YES" "$DOC"
require_text "SETUP_WIZARD_PHYSICAL_KEYBOARD_USABLE=YES" "$DOC"
require_text "SETUP_WIZARD_MOBILE_NETWORK_STEP_DOES_NOT_DEAD_END=YES" "$DOC"

# Sable product closure must be explicit.
require_text "N1B2_SABLE_PRODUCT_IDENTITY_REQUIRED=YES" "$DOC"
require_text "DEVICE_NAME=SableOS Titan2 OR approved SableOS Titan 2 label" "$DOC"
require_text "RESTLESSOS_USER_VISIBLE_BRANDING_REMOVED_OR_BOUNDED=YES" "$DOC"
require_text "TREBLEDROID_USER_VISIBLE_BRANDING_REMOVED_OR_BOUNDED=YES" "$DOC"
require_text "PHH_USER_VISIBLE_CONTROL_SURFACES_HIDDEN_OR_BOUNDARY_REVIEWED=YES" "$DOC"
require_text "GRAPHENE_PLACEHOLDER_UI_REMOVED_OR_BOUNDARY_REVIEWED=YES" "$DOC"

# HOME must no longer silently remain generic Quickstep.
require_text "N1B2_SABLE_HOME_REQUIRED=YES" "$DOC"
require_text "HOME_RESOLVES_TO_SABLE=YES" "$DOC"
require_text "QUICKSTEP_ALLOWED_FOR_RECENTS=YES" "$DOC"
require_text "QUICKSTEP_AS_PRIMARY_HOME=NO_UNLESS_EXPLICITLY_APPROVED" "$DOC"

# Titan2 input profile work must not be skipped.
require_text "N1B2_TITAN2_INPUT_PROFILE_REQUIRED=YES" "$DOC"
require_text "TITANKEY_ENUMERATED=YES" "$DOC"
require_text "TOUCHPAD_ENUMERATED=YES" "$DOC"
require_text "GENERIC_KL_KCM_AS_FINAL_POLICY=NO" "$DOC"
require_text "PHYSICAL_KEYBOARD_TEXT_ENTRY_SMOKE=PASS_REQUIRED" "$DOC"

# Mobile network must be triaged as intermittent until timed evidence proves stability.
require_text "N1B2_MOBILE_NETWORK_TRIAGE_REQUIRED=YES" "$DOC"
require_text "MOBILE_NETWORK_STATUS=TRIAGE_REQUIRED" "$DOC"
require_text "OPERATOR_BLOCKING_UNKNOWN=YES" "$DOC"
require_text "IMAGE_OR_VENDOR_QUIRK_UNKNOWN=YES" "$DOC"
require_text "LTE_HOME_SEEN=YES" "$DOC"
require_text "LTE_DATA_CONNECTED_SEEN=YES" "$DOC"
require_text "LTE_STABILITY_PASS=NO_UNTIL_TIMED_CAPTURE" "$DOC"
require_text "EMERGENCY_CALL_TESTING=NO" "$DOC"

# Stock images may support private restore/local packaging only.
require_text "STOCK_IMAGES_ON_AI_G732=AVAILABLE" "$DOC"
require_text "LOCAL_PACKAGING_USE=YES_IF_GATED" "$DOC"
require_text "COMMIT_STOCK_IMAGES_TO_GIT=NO" "$DOC"
require_text "COMMIT_EXTRACTED_PROPRIETARY_BINARIES=NO" "$DOC"
require_text "PUBLIC_RELEASE_WITH_STOCK_BLOBS=NO_UNLESS_SEPARATE_LICENSE_REVIEW" "$DOC"

# Safety boundaries.
require_text "USERDATA_WIPE_IMPLICIT_ALLOWED=NO" "$DOC"
require_text "BOOTLOADER_RELOCK_ALLOWED=NO" "$DOC"
require_text "AVB_MUTATION_ALLOWED=NO_UNLESS_SEPARATE_REVIEW" "$DOC"

# Do not let this contract accidentally authorize flash.
forbid_text "N1B2_FLASH_ALLOWED=YES" "$DOC"
forbid_text "USERDATA_WIPE_IMPLICIT_ALLOWED=YES" "$DOC"
forbid_text "BOOTLOADER_RELOCK_ALLOWED=YES" "$DOC"

echo "N1B2_SETUP_WIZARD_REQUIRED=PASS"
echo "N1B2_PRODUCT_IDENTITY_REQUIRED=PASS"
echo "N1B2_HOME_REQUIRED=PASS"
echo "N1B2_TITAN2_INPUT_PROFILE_REQUIRED=PASS"
echo "N1B2_MOBILE_NETWORK_TRIAGE_REQUIRED=PASS"
echo "N1B2_STOCK_IMAGE_POLICY=PASS"
echo "N1B2_FLASH_ALLOWED=NO_SEPARATE_GATE_REQUIRED"
echo "N1B2_PRODUCT_CLOSURE_CONTRACT=PASS"
