#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
ROOT="$(cd "$ROOT" && pwd)"
DOC="$ROOT/docs/titan2/N1B_PHASE_08_IMAGE_BUILD_CANDIDATE_READINESS.md"

require_file() {
  local path="$1"
  [[ -f "$ROOT/$path" ]] || {
    echo "N1B_PHASE_08_READINESS=FAIL_MISSING_FILE path=$path"
    return 1
  }
}

require_marker() {
  local marker="$1"
  local path="${2:-$DOC}"
  grep -Fq "$marker" "$path" || {
    echo "N1B_PHASE_08_READINESS=FAIL_MARKER marker=$marker path=$path"
    return 1
  }
}

echo "===== N1B PHASE 08 IMAGE BUILD CANDIDATE READINESS QUALIFIER ====="
echo "ROOT=$ROOT"
echo "DOC=$DOC"
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
require_file docs/titan2/N1B_PHASE_EXECUTION_LEDGER.md
require_file docs/titan2/N1B_FULL_CI_READINESS.md
require_file docs/titan2/N1B_BETA_IMAGE_SCOPE.md
require_file docs/titan2/N1A_ACTIVE_PRODUCT_GRAPH_LESSON.md
require_file docs/titan2/GSI_BUILD_STAGE_LEDGER.md
require_file docs/titan2/N0_N1_FLASH_PLAN_LEDGER.md
require_file build/sable.sh
require_file build/devices/titan2.sh
require_file build/local-ci/run.sh

echo "N1B_PHASE_08_DOC=PASS"
echo "N1B_PHASE_08_SOURCE_FILES=PASS"

require_marker "N1B_PHASE_08_IMAGE_BUILD_CANDIDATE_READINESS=YES"
require_marker "N1B_PHASE=08"
require_marker "PREVIOUS_SABLEOS_CHAT_HISTORY_REVIEWED=YES"
require_marker "UNIHERTZ_TITAN2_RESEARCH_REVIEWED=YES"
require_marker "SABLEOS_PROJECT_REPOS_REVIEWED=YES"
require_marker "AIMINDSEYE_SABLEOS_REVIEWED=YES"
require_marker "N1B_FULL_LOCAL_CI=PASS"
require_marker "N1B_FULL_LOCAL_CI_SOURCE_COMMIT=1bedaaf49cb82b215b95c5bf9e3b47a41710b659"
require_marker "N1B_FULL_LOCAL_CI_EVIDENCE_DIR=/srv/data/sable-build/sableos/local-ci-evidence/20260928T143234Z-1bedaaf49cb8-full"
require_marker "N1B_PHASE_08_BUILD_SCRIPT_REQUIRES_CURRENT_HEAD_FULL_CI=YES"
require_marker "N1B_PHASE_08_STAGE=N1_SABLE"
require_marker "N1B_PHASE_08_OUT_DIR_DEDICATED=YES"
require_marker "ACTIVE_PRODUCT_MK=device/phh/treble/treble_arm64_bvN.mk"
require_marker "ANDROID_PRODUCTS_MK_IS_NOT_PAYLOAD_OWNER=YES"
require_marker "BASELINE=N0B_R7E_RESTLESS_INTERNAL_CANDIDATE"
require_marker "ANDROID17_BASELINE_PIVOT=NO"
require_marker "GOODIX_PATCH_SKIPPED=YES"
require_marker "PLATFORM_TESTING_GATE=Android.bp_placeholder_from_R7D"
require_marker "TREBLEAPP_DEXPREOPT_DISABLED=YES"
require_marker "ARTIFACT_KIND=gsi-system-image"
require_marker "PRIMARY_ARTIFACT=system"
require_marker "PRESERVE_BOOT=YES"
require_marker "PRESERVE_VENDOR=YES"
require_marker "BOOT_IMAGE_PATCHING_ALLOWED=NO"
require_marker "KERNEL_PATCHING_ALLOWED=NO"
require_marker "PERMISSIVE_SELINUX_ALLOWED=NO"
require_marker "TITAN_TOUCHPAD_DAEMON_ENABLED=NO"
require_marker "SETUP_WIZARD_FIRST_BOOT_REQUIRED=YES"
require_marker "KEYBOARD_FIRST_ONBOARDING_REQUIRED=YES"
require_marker "SYSTEM_IMG_SHA256=REQUIRED"
require_marker "SYSTEM_IMG_LOGICAL_BYTES=REQUIRED"
require_marker "TARGET_FILES_ZIP=REQUIRED"
require_marker "TARGET_FILES_SABLE_MARKER=REQUIRED"
require_marker "REGISTER_ENTRYPOINT=build/sable.sh titan2 N1B register-artifact"
require_marker "TITAN2_FLASH_EXECUTION_SUPPORTED=NO"
require_marker "TITAN2_WRITE_CAPABLE_SCRIPT_ALLOWED=NO"
require_marker "DEVICE_CONTACT_AUTHORIZED=NO"
require_marker "FLASH_AUTHORIZED=NO"
require_marker "RESTORE_REPORT=REQUIRED_BEFORE_FLASH"
require_marker "EXPLICIT_TITAN_SERIAL=REQUIRED_BEFORE_FLASH"
require_marker "USERDATA_WIPE_IMPLICIT_ALLOWED=NO"
require_marker "N1B_PHASE_08_PROMOTES_TO_IMAGE_CANDIDATE_ONLY=YES"
require_marker "N1B_PHASE_08_DOES_NOT_AUTHORIZE_FLASH=YES"
require_marker "N1B_PHASE_08_IMAGE_BUILD_CANDIDATE_READINESS=PASS"

echo "N1B_PHASE_08_DOC_MARKERS=PASS"

require_marker "N1B_PHASE_08=N1B_IMAGE_BUILD_CANDIDATE" \
  "$ROOT/docs/titan2/N1B_PHASE_EXECUTION_LEDGER.md"
require_marker "N1B_IMAGE_BUILD_ALLOWED_ONLY_AFTER_PHASES_01_TO_07_PASS=YES" \
  "$ROOT/docs/titan2/N1B_PHASE_EXECUTION_LEDGER.md"
require_marker "N1B_FLASH_STILL_REQUIRES_N0_N1_PHYSICAL_METADATA=YES" \
  "$ROOT/docs/titan2/N1B_PHASE_EXECUTION_LEDGER.md"
echo "N1B_PHASE_08_PHASE_LEDGER_BINDING=PASS"

require_marker "N1B_TITAN2_BETA_IMAGE_SCOPE=YES" \
  "$ROOT/docs/titan2/N1B_BETA_IMAGE_SCOPE.md"
require_marker "N1B = Android 16 Restless R7E substrate" \
  "$ROOT/docs/titan2/N1B_BETA_IMAGE_SCOPE.md"
require_marker "TITAN_TOUCHPAD_DAEMON_ENABLED=NO" \
  "$ROOT/docs/titan2/N1B_BETA_IMAGE_SCOPE.md"
echo "N1B_PHASE_08_BETA_SCOPE_BINDING=PASS"

require_marker "N1-SABLE" \
  "$ROOT/docs/titan2/GSI_BUILD_STAGE_LEDGER.md"
require_marker "N0-B-TREBLE passes and N1-SABLE fails -> Sable product overlay issue" \
  "$ROOT/docs/titan2/GSI_BUILD_STAGE_LEDGER.md"
echo "N1B_PHASE_08_GSI_STAGE_BINDING=PASS"

require_marker "ACTIVE_PRODUCT_MK=device/phh/treble/treble_arm64_bvN.mk" \
  "$ROOT/docs/titan2/N1A_ACTIVE_PRODUCT_GRAPH_LESSON.md"
require_marker "AndroidProducts.mk is product discovery" \
  "$ROOT/docs/titan2/N1A_ACTIVE_PRODUCT_GRAPH_LESSON.md"
echo "N1B_PHASE_08_ACTIVE_PRODUCT_GRAPH_BINDING=PASS"

require_marker "RESTORE_REPORT=REQUIRED" \
  "$ROOT/docs/titan2/N0_N1_FLASH_PLAN_LEDGER.md"
require_marker "USERDATA_WIPE_IMPLICIT_ALLOWED=NO" \
  "$ROOT/docs/titan2/N0_N1_FLASH_PLAN_LEDGER.md"
require_marker "PRESERVE_VENDOR=YES" \
  "$ROOT/docs/titan2/N0_N1_FLASH_PLAN_LEDGER.md"
echo "N1B_PHASE_08_FLASH_LEDGER_BINDING=PASS"

require_marker "SABLE_DEVICE_ARTIFACT_REGISTRATION_SUPPORTED=YES" \
  "$ROOT/build/devices/titan2.sh"
require_marker "SABLE_DEVICE_FLASH_PLAN_SUPPORTED=YES" \
  "$ROOT/build/devices/titan2.sh"
require_marker "TITAN2_FLASH_EXECUTION_SUPPORTED=NO" \
  "$ROOT/build/devices/titan2.sh"
require_marker "TITAN2_WRITE_CAPABLE_SCRIPT_ALLOWED=NO" \
  "$ROOT/build/devices/titan2.sh"
require_marker "SABLE_DEVICE_ARTIFACT_KINDS=\"gsi-system-image\"" \
  "$ROOT/build/devices/titan2.sh"
echo "N1B_PHASE_08_TITAN2_ADAPTER_BOUNDARY=PASS"

require_marker "SABLEOS_DEVICE=\"\${SABLEOS_DEVICE:-panther}\"" \
  "$ROOT/build/local-ci/run.sh"
require_marker "SABLEOS_RELEASE_VERSION=\"\${SABLEOS_RELEASE_VERSION:-R9}\"" \
  "$ROOT/build/local-ci/run.sh"
require_marker "bash build/local-ci/run.sh full" \
  "$ROOT/docs/titan2/N1B_FULL_CI_READINESS.md"
echo "N1B_PHASE_08_FULL_CI_CONTEXT_BINDING=PASS"

echo "===== N1B PHASE 08 IMAGE BUILD CANDIDATE READINESS RESULT ====="
echo "FAILURES=0"
echo "N1B_PHASE_08_IMAGE_BUILD_CANDIDATE_READINESS=PASS"
