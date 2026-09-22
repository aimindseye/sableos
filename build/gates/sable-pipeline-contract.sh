#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "===== SABLE STANDARD PIPELINE CONTRACT ====="

for f in \
  "$ROOT/build/sable.sh" \
  "$ROOT/build/deploy/common.sh" \
  "$ROOT/build/deploy/flash.sh" \
  "$ROOT/build/panther/qualify-r9-physical-ux.sh" \
  "$ROOT/tests/systemui/device/r9_identity_audit.sh" \
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
  "$ROOT/build/deploy/artifact_registry.py"
echo "SABLE_PIPELINE_PYTHON_SYNTAX=PASS"

python3 "$ROOT/build/deploy/target_files_plan.py" --self-test
python3 "$ROOT/build/deploy/artifact_registry.py" self-test
echo "SABLE_PIPELINE_FASTBOOT_PLAN_SELF_TEST=PASS"
echo "SABLE_PIPELINE_ARTIFACT_REGISTRY_SELF_TEST=PASS"

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
grep -Fq 'r9-system-cohesion-contract.py' "$QUAL"
grep -Fq 'R9_SYSTEM_COHESION_STATIC_CONTRACT=PASS' "$QUAL"
grep -Fq 'SABLE_BUILD_STAGE' "$FINAL_BUILD"
grep -Fq 'R9_PHYSICAL_UX_MODULE_QUALIFICATION=PASS' "$FINAL_BUILD"
grep -Fq 'FULL_TARGET_FILES_BUILD_PERFORMED=NO' "$FINAL_BUILD"
grep -Fq 'SABLE_QUALIFICATION_ONLY' "$RC_DRIVER"
grep -Fq 'R8_RELEASE_CANDIDATE=NOT_RUN' "$RC_DRIVER"
echo "SABLE_PIPELINE_MODULE_QUALIFICATION_POLICY=PASS"
echo "SABLE_PIPELINE_SMS_MMS_BLOCKING_GATE=PASS"
echo "SABLE_PIPELINE_FIRST_PARTY_ICON_GATE=PASS"
echo "SABLE_PIPELINE_SYSTEM_COHESION_GATE=PASS"

grep -Fq 'R9:identity|r9:identity' "$ROOT/build/devices/panther.sh"
grep -Fq 'DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY' "$ROOT/tests/systemui/device/r9_identity_audit.sh"
grep -Fq 'R9_SYSTEM_IDENTITY_AUDIT=PASS_READ_ONLY' "$ROOT/tests/systemui/device/r9_identity_audit.sh"
echo "SABLE_PIPELINE_READ_ONLY_IDENTITY_AUDIT=PASS"

echo "SABLE_STANDARD_PIPELINE_CONTRACT=PASS"
