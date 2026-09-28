#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
ROOT="$(cd "$ROOT" && pwd)"
DOC="$ROOT/docs/titan2/N1B_PHASE_08_IMAGE_BUILD_CANDIDATE_READINESS.md"
QUALIFIER="$ROOT/build/titan2/qualify-n1b-phase-08-image-build-candidate-readiness.sh"

require_file() {
  local path="$1"
  [[ -f "$ROOT/$path" ]] || {
    echo "N1B_PHASE_08_CONTRACT=FAIL_MISSING_FILE path=$path"
    return 1
  }
}

require_marker() {
  local marker="$1"
  local path="${2:-$DOC}"
  grep -Fq "$marker" "$path" || {
    echo "N1B_PHASE_08_CONTRACT=FAIL_MARKER marker=$marker path=$path"
    return 1
  }
}

echo "===== N1B PHASE 08 IMAGE BUILD CANDIDATE CONTRACT ====="
echo "ROOT=$ROOT"
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=NO"
echo "IMAGE_BUILD_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "ADB_COMMANDS_RUN=NO"
echo "FASTBOOT_COMMANDS_RUN=NO"
echo "PUBLIC_RELEASE=NO"
echo "PRODUCTION_SIGNING=NO"

require_file docs/titan2/N1B_PHASE_08_IMAGE_BUILD_CANDIDATE_READINESS.md
require_file build/titan2/qualify-n1b-phase-08-image-build-candidate-readiness.sh

echo "N1B_PHASE_08_DOC=PASS"
echo "N1B_PHASE_08_QUALIFIER=PASS"

bash -n "$QUALIFIER"
echo "N1B_PHASE_08_QUALIFIER_SYNTAX=PASS"

require_marker "N1B_PHASE_08_IMAGE_BUILD_CANDIDATE_READINESS=YES"
require_marker "IMAGE_BUILD_SCRIPT_AUTHORIZED_BY_THIS_DOC=NO"
require_marker "N1B_FULL_LOCAL_CI_SOURCE_COMMIT=1bedaaf49cb82b215b95c5bf9e3b47a41710b659"
require_marker "N1B_PHASE_08_BUILD_SCRIPT_REQUIRES_CURRENT_HEAD_FULL_CI=YES"
require_marker "ACTIVE_PRODUCT_MK=device/phh/treble/treble_arm64_bvN.mk"
require_marker "BASELINE=N0B_R7E_RESTLESS_INTERNAL_CANDIDATE"
require_marker "ARTIFACT_KIND=gsi-system-image"
require_marker "PRESERVE_BOOT=YES"
require_marker "TITAN_TOUCHPAD_DAEMON_ENABLED=NO"
require_marker "TARGET_FILES_SABLE_MARKER=REQUIRED"
require_marker "REGISTER_ENTRYPOINT=build/sable.sh titan2 N1B register-artifact"
require_marker "RESTORE_REPORT=REQUIRED_BEFORE_FLASH"
require_marker "USERDATA_WIPE_IMPLICIT_ALLOWED=NO"
require_marker "N1B_PHASE_08_DOES_NOT_AUTHORIZE_FLASH=YES"

echo "N1B_PHASE_08_CONTRACT_DOC_MARKERS=PASS"

require_marker "SOURCE_MUTATION_AUTHORIZED=NO" "$QUALIFIER"
require_marker "BUILD_AUTHORIZED=NO" "$QUALIFIER"
require_marker "IMAGE_BUILD_AUTHORIZED=NO" "$QUALIFIER"
require_marker "DEVICE_CONTACT_AUTHORIZED=NO" "$QUALIFIER"
require_marker "FLASH_AUTHORIZED=NO" "$QUALIFIER"
require_marker "ADB_COMMANDS_RUN=NO" "$QUALIFIER"
require_marker "FASTBOOT_COMMANDS_RUN=NO" "$QUALIFIER"
require_marker "PUBLIC_RELEASE=NO" "$QUALIFIER"
require_marker "PRODUCTION_SIGNING=NO" "$QUALIFIER"
require_marker "N1B_PHASE_08_IMAGE_BUILD_CANDIDATE_READINESS=PASS" "$QUALIFIER"

echo "N1B_PHASE_08_CONTRACT_QUALIFIER_MARKERS=PASS"

bash "$QUALIFIER" "$ROOT"

echo "===== N1B PHASE 08 IMAGE BUILD CANDIDATE CONTRACT RESULT ====="
echo "FAILURES=0"
echo "N1B_PHASE_08_IMAGE_BUILD_CANDIDATE_CONTRACT=PASS"
