#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "===== SABLE STANDARD PIPELINE CONTRACT ====="

for f in \
  "$ROOT/build/sable.sh" \
  "$ROOT/build/deploy/common.sh" \
  "$ROOT/build/deploy/flash.sh" \
  "$ROOT/build/panther/qualify-r9-physical-ux.sh" \
  "$ROOT/build/panther/qualify-r9-media-flow.sh" \
  "$ROOT/build/panther/qualify-r9-messages.sh" \
  "$ROOT/build/panther/qualify-r9-textreader.sh" \
  "$ROOT/build/panther/prepare-r8-final-ui.sh" \
  "$ROOT/build/panther/run-r8-release-candidate.sh" \
  "$ROOT/build/gates/r8-build-driver-contract.sh" \
  "$ROOT/build/host/verify-r8-host-tools.sh" \
  "$ROOT/tests/systemui/device/r9_identity_audit.sh" \
  "$ROOT/tests/systemui/device/r9_branding_surface_audit.sh" \
  "$ROOT/tests/systemui/device/r9_final_ui_runtime_audit.sh" \
  "$ROOT/build/check-repo-layout.sh" \
  "$ROOT/build/devices/panther.sh" \
  "$ROOT/build/devices/titan2.sh" \
  "$ROOT/build/devices/titan2-elite.sh" \
  "$ROOT/build/devices/q27.sh"
do
  bash -n "$f"
done
echo "SABLE_PIPELINE_SHELL_SYNTAX=PASS"

python3 -m py_compile \
  "$ROOT/build/deploy/target_files_plan.py" \
  "$ROOT/build/deploy/artifact_registry.py" \
  "$ROOT/apps/r8/reader/apply_sable_flavor.py" \
  "$ROOT/apps/r8/textreader/apply_sable_flavor.py" \
  "$ROOT/apps/r8/textreader/verify_sable_textreader.py" \
  "$ROOT/build/gates/r9-textreader-standalone-contract.py" \
  "$ROOT/apps/r8/mail/apply_sable_flavor.py" \
  "$ROOT/apps/r8/mail/verify_sable_mail.py" \
  "$ROOT/patches/android-17-grapheneos-2026081300/apply_ui5c_ui6_system_surfaces.py" \
  "$ROOT/patches/android-17-grapheneos-2026081300/apply_r9_systemui_coherence.py" \
  "$ROOT/patches/android-17-grapheneos-2026081300/apply_r9_settings_cohesion.py" \
  "$ROOT/patches/android-17-grapheneos-2026081300/apply_r9_launcher3_foundation.py" \
  "$ROOT/patches/android-17-grapheneos-2026081300/apply_r9_quickstep_recents_only.py" \
  "$ROOT/patches/android-17-grapheneos-2026081300/apply_r9_phone_contacts_presentation.py" \
  "$ROOT/build/gates/r9-launcher3-foundation-contract.py" \
  "$ROOT/build/gates/r9-media-flow-contract.py" \
  "$ROOT/build/gates/r9-messages-native-first-contract.py" \
  "$ROOT/build/gates/r9-messages-local-conversation-contract.py" \
  "$ROOT/build/gates/r9-messages-source-style.py" \
  "$ROOT/build/gates/r9-system-cohesion-contract.py"
echo "SABLE_PIPELINE_PYTHON_SYNTAX=PASS"

python3 "$ROOT/build/deploy/target_files_plan.py" --self-test
python3 "$ROOT/build/deploy/artifact_registry.py" self-test
python3 "$ROOT/patches/android-17-grapheneos-2026081300/apply_r9_settings_cohesion.py" --self-test
python3 "$ROOT/patches/android-17-grapheneos-2026081300/apply_r9_launcher3_foundation.py" --self-test
python3 "$ROOT/patches/android-17-grapheneos-2026081300/apply_r9_quickstep_recents_only.py" --self-test
python3 "$ROOT/patches/android-17-grapheneos-2026081300/apply_r9_phone_contacts_presentation.py" --self-test
python3 "$ROOT/build/gates/r9-launcher3-foundation-contract.py" --self-test
echo "SABLE_PIPELINE_FASTBOOT_PLAN_SELF_TEST=PASS"
echo "SABLE_PIPELINE_ARTIFACT_REGISTRY_SELF_TEST=PASS"
echo "SABLE_PIPELINE_SETTINGS_COHESION_SELF_TEST=PASS"
echo "SABLE_PIPELINE_LAUNCHER3_FOUNDATION_SELF_TEST=PASS"
grep -Fq 'R9_QUICKSTEP_RECENTS_ONLY_SOURCE_RESOLUTION_SELF_TEST=PASS' \
  "$ROOT/patches/android-17-grapheneos-2026081300/apply_r9_quickstep_recents_only.py"
echo "SABLE_PIPELINE_QUICKSTEP_SOURCE_RESOLUTION=PASS"
grep -Fq 'R9_QUICKSTEP_RESOLVEINFO_SECONDARY_HOME_SELF_TEST=PASS' \
  "$ROOT/patches/android-17-grapheneos-2026081300/apply_r9_quickstep_recents_only.py"
grep -Fq 'R9_QUICKSTEP_RECENTS_FINAL_SCOPE_SELF_TEST=PASS' \
  "$ROOT/patches/android-17-grapheneos-2026081300/apply_r9_quickstep_recents_only.py"
grep -Fq 'R9_QUICKSTEP_STALE_FINAL_IMPORT_REPAIR_SELF_TEST=PASS' \
  "$ROOT/patches/android-17-grapheneos-2026081300/apply_r9_quickstep_recents_only.py"
grep -Fq 'upgrade-final' "$ROOT/build/panther/prepare-r8-final-ui.sh"
grep -Fq 'upgrade-final' "$ROOT/build/panther/qualify-r9-launcher3-foundation.sh"
echo "SABLE_PIPELINE_QUICKSTEP_RESOLVEINFO_SECONDARY_HOME=PASS"
echo "SABLE_PIPELINE_QUICKSTEP_STALE_FINAL_UPGRADE=PASS"
echo "SABLE_PIPELINE_QUICKSTEP_RECENTS_ONLY_SELF_TEST=PASS"
grep -Fq 'R9_PHONE_CONTACTS_PARTIAL_CONVERGENCE_SELF_TEST=PASS' \
  "$ROOT/patches/android-17-grapheneos-2026081300/apply_r9_phone_contacts_presentation.py"
grep -Fq 'R9_PHONE_CONTACTS_CONTAINMENT_AWARE_VERIFY_SELF_TEST=PASS' \
  "$ROOT/patches/android-17-grapheneos-2026081300/apply_r9_phone_contacts_presentation.py"
echo "SABLE_PIPELINE_PHONE_CONTACTS_PARTIAL_CONVERGENCE_SELF_TEST=PASS"
echo "SABLE_PIPELINE_PHONE_CONTACTS_CONTAINMENT_VERIFY_SELF_TEST=PASS"
echo "SABLE_PIPELINE_LAUNCHER3_FOUNDATION_CONTRACT_SELF_TEST=PASS"

grep -Fq 'usage:' "$ROOT/build/sable.sh"
grep -Fq 'build/sable.sh <device> <release> <function>' "$ROOT/build/sable.sh"
for fn in ci qualify build register-artifact show-artifact flash-plan flash accept; do
  grep -Fq "$fn)" "$ROOT/build/sable.sh"
done
echo "SABLE_PIPELINE_CANONICAL_ENTRYPOINT=PASS"

grep -Fq 'SABLE_DEVICE_FLASH_SUPPORTED=YES' "$ROOT/build/devices/panther.sh"
grep -Fq 'SABLE_DEVICE_QUALIFY_SUPPORTED=YES' "$ROOT/build/devices/panther.sh"
grep -Fq 'sable_device_qualify' "$ROOT/build/devices/panther.sh"
grep -Fq 'qualify-r9-physical-ux.sh' "$ROOT/build/devices/panther.sh"
grep -Fq 'sable_device_artifact_gate' "$ROOT/build/devices/panther.sh"
for d in titan2 titan2-elite q27; do
  f="$ROOT/build/devices/$d.sh"
  grep -Fq 'SABLE_DEVICE_FLASH_SUPPORTED=NO' "$f"
  grep -Fq 'SABLE_DEVICE_QUALIFY_SUPPORTED=NO' "$f"
  grep -Fq 'SABLE_DEVICE_QUALIFY=BLOCKED_UNQUALIFIED' "$f"
  grep -Fq 'BLOCKED_UNQUALIFIED' "$f"
done
test ! -e "$ROOT/build/devices/q25.sh"
echo "SABLE_PIPELINE_DEVICE_ADAPTER_POLICY=PASS"

FLASH="$ROOT/build/deploy/flash.sh"
grep -Fq -- '--preserve-data' "$FLASH"
grep -Fq -- '--authorize' "$FLASH"
grep -Fq 'USERDATA_OR_METADATA_WIPE_AUTHORIZED=NO' "$FLASH"
grep -Fq 'BOOTLOADER_UNLOCK_AUTHORIZED=NO' "$FLASH"
grep -Fq 'INACTIVE_SLOT_FLASH_AUTHORIZED=NO' "$FLASH"
grep -Fq 'FASTBOOT_WIPE_FLAG=ABSENT' "$FLASH"
grep -Fq -- '--skip-secondary' "$FLASH"
grep -Fq -- '--skip-reboot' "$FLASH"
grep -Fq 'SABLE_BLOCKER_ISSUE_REQUIRED=YES' "$FLASH"
grep -Fq 'PREWRITE_FAILURE_RECOVERY=PASS_ANDROID' "$FLASH"
grep -Fq 'SABLE_DEVICE_ARTIFACT_GATE' "$FLASH"
grep -Fq '"has-slot:$part"' "$FLASH"
if grep -Fq '"partition-size:$part"' "$FLASH"; then
  echo "SABLE_PIPELINE_PARTITION_EXISTS_SEMANTICS=FAIL_PARTITION_SIZE"
  exit 1
fi
echo "SABLE_PIPELINE_PARTITION_EXISTS_SEMANTICS=PASS"

if grep -Eq '(^|[[:space:]])-w([[:space:]]|$)' "$FLASH"; then
  echo "SABLE_PIPELINE_NO_WIPE_FLAG=FAIL"
  exit 1
fi
if grep -Eq '(flashing unlock|flashing lock|erase userdata|erase metadata)' "$FLASH"; then
  echo "SABLE_PIPELINE_NO_UNLOCK_ERASE=FAIL"
  exit 1
fi
echo "SABLE_PIPELINE_MUTATION_POLICY=PASS"

grep -Fq 'sable_wait_fastboot_ready' "$FLASH"
grep -Fq 'FASTBOOT_GETVAR_READY=PASS' "$ROOT/build/deploy/common.sh"
grep -Fq '</dev/null' "$ROOT/build/deploy/common.sh"
grep -Fq '</dev/null' "$FLASH"
echo "SABLE_PIPELINE_FASTBOOT_READINESS_AND_STDIN_ISOLATION=PASS"

grep -Fq 'IMAGES/' "$ROOT/build/deploy/target_files_plan.py"
grep -Fq 'unconditional_erase_forbidden' "$ROOT/build/deploy/target_files_plan.py"
grep -Fq 'inactive_slot_directive_forbidden' "$ROOT/build/deploy/target_files_plan.py"
grep -Fq 'unsupported_flash_option' "$ROOT/build/deploy/target_files_plan.py"
echo "SABLE_PIPELINE_TARGET_FILES_ONLY_POLICY=PASS"

QUAL="$ROOT/build/panther/qualify-r9-physical-ux.sh"
FINAL_BUILD="$ROOT/build/panther/build-r8-final-ui.sh"
RC_DRIVER="$ROOT/build/panther/run-r8-release-candidate.sh"
grep -Fq 'FULL_TARGET_FILES_BUILD_AUTHORIZED=NO' "$QUAL"
grep -Fq 'SABLE_QUALIFICATION_ONLY=YES' "$QUAL"
grep -Fq 'r9-sms-mms-blocking-contract.py' "$QUAL"
grep -Fq 'r9-first-party-app-icon-contract.py' "$QUAL"
grep -Fq 'r9-media-flow-contract.py' "$QUAL"
grep -Fq 'r9-messages-native-first-contract.py' "$QUAL"
grep -Fq 'r9-messages-local-conversation-contract.py' "$QUAL"
grep -Fq 'r9-system-cohesion-contract.py' "$QUAL"
MEDIA_QUAL="$ROOT/build/panther/qualify-r9-media-flow.sh"
grep -Fq 'source "$ROOT/build/config/r8-host-tools.env"' "$MEDIA_QUAL"
grep -Fq 'export ANDROID_HOME="$SABLE_ANDROID_SDK"' "$MEDIA_QUAL"
grep -Fq 'set -euo pipefail' "$MEDIA_QUAL"
grep -Fq 'R9_MEDIA_FLOW_FOCUSED_QUALIFICATION=PASS' "$MEDIA_QUAL"
TEXTREADER_QUAL="$ROOT/build/panther/qualify-r9-textreader.sh"
grep -Fq 'set -euo pipefail' "$TEXTREADER_QUAL"
grep -Fq 'NETWORK_FETCH_AUTHORIZED=NO' "$TEXTREADER_QUAL"
grep -Fq 'R8_NO_STALE_WORKSPACE_INVENTORY_REQUIRED=NO' "$TEXTREADER_QUAL"
grep -Fq 'WORKSPACE_PRODUCT_INVENTORY_REQUIRED=NO_PRESTAGING' "$TEXTREADER_QUAL"
grep -Fq 'r9-textreader-standalone-contract.py' "$TEXTREADER_QUAL"
grep -Fq 'testDebugUnitTest' "$TEXTREADER_QUAL"
grep -Fq 'lintDebug' "$TEXTREADER_QUAL"
grep -Fq 'assembleDebug' "$TEXTREADER_QUAL"
grep -Fq 'R9_TEXT_READER_FOCUSED_QUALIFICATION=PASS' "$TEXTREADER_QUAL"
grep -Fq 'R9:textreader|r9:textreader' "$ROOT/build/devices/panther.sh"
echo "SABLE_PIPELINE_TEXT_READER_FOCUSED_QUALIFIER=PASS"

MESSAGES_QUAL="$ROOT/build/panther/qualify-r9-messages.sh"
grep -Fq 'source "$ROOT/build/config/r8-host-tools.env"' "$MESSAGES_QUAL"
grep -Fq 'export ANDROID_HOME="$SABLE_ANDROID_SDK"' "$MESSAGES_QUAL"
grep -Fq 'set -euo pipefail' "$MESSAGES_QUAL"
grep -Fq 'r9-messages-local-conversation-contract.py' "$MESSAGES_QUAL"
grep -Fq ':hub:detekt' "$MESSAGES_QUAL"
grep -Fq ':hub:ktlintCheck' "$MESSAGES_QUAL"
grep -Fq 'R9_MESSAGES_WARNINGS_AS_ERRORS=PASS' "$MESSAGES_QUAL"
grep -Fq 'R9_MESSAGES_LOCAL_CONVERSATION_QUALIFICATION=PASS' "$MESSAGES_QUAL"
grep -Fq 'R9_MESSAGES_FOCUSED_QUALIFICATION=PASS' "$MESSAGES_QUAL"

LOCAL_CI="$ROOT/build/local-ci/run.sh"
for gate in \
  'r9-media-flow-contract.py' \
  'r9-messages-native-first-contract.py' \
  'r9-messages-local-conversation-contract.py' \
  'r9-messages-source-style.py' \
  'r9-textreader-standalone-contract.py'
do
  grep -Fq "$gate" "$LOCAL_CI"
done
echo "SABLE_PIPELINE_LOCAL_CI_MEDIA_MESSAGES_SOURCE_GATES=PASS"
grep -Fq 'R8_NO_STALE_WORKSPACE_INVENTORY_REQUIRED=NO' "$LOCAL_CI"
echo "SABLE_PIPELINE_LOCAL_CI_TEXT_READER_SOURCE_GATE=PASS"
echo "SABLE_PIPELINE_PRESTAGING_WORKSPACE_INVENTORY_POLICY=PASS"

grep -Fq 'SABLE_LOCAL_CI_PYTHON_SYNTAX=PASS' "$LOCAL_CI"
grep -Fq 'PYTHON_SYNTAX_FAILURE=' "$LOCAL_CI"
if grep -Fq 'python3 -m py_compile "$ROOT/$py"' "$LOCAL_CI"; then
  echo "SABLE_PIPELINE_LOCAL_CI_PYTHON_SYNTAX_AGGREGATION=FAIL_PER_FILE_FAIL_FAST"
  exit 1
fi
echo "SABLE_PIPELINE_LOCAL_CI_PYTHON_SYNTAX_AGGREGATION=PASS"

grep -Fq 'SABLE_LOCAL_CI_APPLICATOR_SELF_TEST_FAILURE=' "$LOCAL_CI"
grep -Fq 'SABLE_LOCAL_CI_APPLICATOR_SELF_TESTS=PASS' "$LOCAL_CI"
grep -Fq 'SABLE_LOCAL_CI_APPLICATOR_SELF_TESTS=FAIL' "$LOCAL_CI"
echo "SABLE_PIPELINE_LOCAL_CI_APPLICATOR_SELF_TEST_AGGREGATION=PASS"

grep -Fq 'SABLE_LOCAL_CI_STATIC_CONTRACT_FAILURE=' "$LOCAL_CI"
grep -Fq 'SABLE_LOCAL_CI_STATIC_CONTRACT_FAILURE_NAMES=' "$LOCAL_CI"
grep -Fq 'SABLE_LOCAL_CI_STATIC_CONTRACTS=FAIL' "$LOCAL_CI"
grep -Fq 'SABLE_LOCAL_CI_STATIC_CONTRACTS=PASS' "$LOCAL_CI"
echo "SABLE_PIPELINE_LOCAL_CI_STATIC_CONTRACT_AGGREGATION=PASS"

BUILD_DRIVER_CONTRACT="$ROOT/build/gates/r8-build-driver-contract.sh"
for marker in \
  'R9_BUILD_DRIVER_ELEVEN_APK_INVENTORY=PASS' \
  'R9_BUILD_DRIVER_STANDALONE_HOME_CONTRACT=PASS' \
  'R9_SABLE_TEXT_READER_TARGET_POLICY_CONTRACT=PASS' \
  'R9_SABLE_HOME_TARGET_POLICY_CONTRACT=PASS' \
  'R9_SABLE_HOME_QUICKSTEP_PREFLIGHT_CONTRACT=PASS' \
  'R9_BUILD_DRIVER_HOME_DOC_CONTRACT=PASS' \
  'R9_SABLESTART_PRESENTATION_GRADLE_SCOPE=PASS_EXACT_PRESENTATION_FILEGROUP' \
  'R9_SABLESTART_PRESENTATION_LINT_SOURCE_MIRROR=PASS' \
  'R9_SABLELAUNCHER_SDK_BOUNDARY=PASS_SYSTEM_CURRENT' \
  'R8_BUILD_DRIVER_CONTRACT=FAIL_UNEXPECTED'
do
  grep -Fq "$marker" "$BUILD_DRIVER_CONTRACT"
done
echo "SABLE_PIPELINE_STANDALONE_HOME_BUILD_DRIVER_CONTRACT=PASS"

grep -Fq 'R9_SYSTEM_COHESION_STATIC_CONTRACT=PASS' "$QUAL"
grep -Fq 'SABLE_BUILD_STAGE' "$FINAL_BUILD"
grep -Fq 'R9_PHYSICAL_UX_MODULE_QUALIFICATION=PASS' "$FINAL_BUILD"
grep -Fq 'FULL_TARGET_FILES_BUILD_PERFORMED=NO' "$FINAL_BUILD"
grep -Fq 'SABLE_QUALIFICATION_ONLY' "$RC_DRIVER"
grep -Fq 'R8_NO_STALE_WORKSPACE_INVENTORY_REQUIRED=YES' \
  "$ROOT/build/gates/r8-final-product-composition.sh"
grep -Fq 'R8_RELEASE_CANDIDATE=NOT_RUN' "$RC_DRIVER"
echo "SABLE_PIPELINE_POSTSTAGING_WORKSPACE_INVENTORY_POLICY=PASS"
echo "SABLE_PIPELINE_MODULE_QUALIFICATION_POLICY=PASS"
echo "SABLE_PIPELINE_SMS_MMS_BLOCKING_GATE=PASS"
echo "SABLE_PIPELINE_FIRST_PARTY_ICON_GATE=PASS"
echo "SABLE_PIPELINE_MEDIA_FLOW_GATE=PASS"
echo "SABLE_PIPELINE_MEDIA_FLOW_FOCUSED_QUALIFIER=PASS"
echo "SABLE_PIPELINE_TEXT_READER_GATE=PASS"
echo "SABLE_PIPELINE_MESSAGES_NATIVE_FIRST_GATE=PASS"
echo "SABLE_PIPELINE_MESSAGES_LOCAL_CONVERSATION_GATE=PASS"
echo "SABLE_PIPELINE_MESSAGES_STRICT_QUALITY_GATE=PASS"
echo "SABLE_PIPELINE_MESSAGES_FOCUSED_QUALIFIER=PASS"
echo "SABLE_PIPELINE_SYSTEM_COHESION_GATE=PASS"

grep -Fq 'R9:identity|r9:identity' "$ROOT/build/devices/panther.sh"
grep -Fq 'DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY' "$ROOT/tests/systemui/device/r9_identity_audit.sh"
grep -Fq 'R9_SYSTEM_IDENTITY_AUDIT=PASS_READ_ONLY' "$ROOT/tests/systemui/device/r9_identity_audit.sh"
grep -Fq 'DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY' "$ROOT/tests/systemui/device/r9_branding_surface_audit.sh"
grep -Fq 'R9_BRANDING_SURFACE_AUDIT=PASS_CAPTURED' "$ROOT/tests/systemui/device/r9_branding_surface_audit.sh"
echo "SABLE_PIPELINE_READ_ONLY_IDENTITY_AUDIT=PASS"
echo "SABLE_PIPELINE_READ_ONLY_BRANDING_AUDIT=PASS"

echo "SABLE_STANDARD_PIPELINE_CONTRACT=PASS"
