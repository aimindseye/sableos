#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

EXPECTED_SOURCE_COMMIT="${EXPECTED_SOURCE_COMMIT:-$(git -C "$ROOT" rev-parse HEAD)}"

[[ "$EXPECTED_SOURCE_COMMIT" =~ ^[0-9a-f]{40}$ ]] || {
  echo "R9_PHYSICAL_UX_QUALIFICATION=FAIL_SOURCE_FORMAT"
  exit 64
}

ACTUAL_SOURCE="$(git -C "$ROOT" rev-parse HEAD)"
[[ "$ACTUAL_SOURCE" == "$EXPECTED_SOURCE_COMMIT" ]] || {
  echo "R9_PHYSICAL_UX_QUALIFICATION=FAIL_SOURCE_BINDING expected=$EXPECTED_SOURCE_COMMIT actual=$ACTUAL_SOURCE"
  exit 65
}

if ! git -C "$ROOT" diff --quiet || ! git -C "$ROOT" diff --cached --quiet; then
  echo "R9_PHYSICAL_UX_QUALIFICATION=FAIL_TRACKED_SOURCE_DIRTY"
  git -C "$ROOT" status --short
  exit 66
fi

echo "===== R9 PANTHER PHYSICAL UX PRE-FULL QUALIFICATION ====="
echo "SOURCE_MUTATION_AUTHORIZED=YES_ANDROID_WORKSPACE_ONLY"
echo "BUILD_AUTHORIZED=YES_MODULES_ONLY"
echo "FULL_TARGET_FILES_BUILD_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "EXPECTED_SOURCE_COMMIT=$EXPECTED_SOURCE_COMMIT"

python3 "$ROOT/build/gates/r9-physical-remediation-contract.py"
python3 "$ROOT/build/gates/r9-sms-mms-blocking-contract.py"
python3 "$ROOT/build/gates/r9-messages-native-first-contract.py"
python3 "$ROOT/build/gates/r9-messages-local-conversation-contract.py"
python3 "$ROOT/build/gates/r9-first-party-app-icon-contract.py"
python3 "$ROOT/build/gates/r9-media-flow-contract.py"
python3 "$ROOT/build/gates/r9-system-cohesion-contract.py"
python3 "$ROOT/build/gates/r9-physical-ux-closure-contract.py"
python3 "$ROOT/build/gates/r9-textreader-standalone-contract.py"
bash "$ROOT/build/gates/sable-pipeline-contract.sh"

echo "R9_MEDIA_FLOW_STATIC_CONTRACT=PASS"
echo "R9_MESSAGES_NATIVE_FIRST_STATIC_CONTRACT=PASS"
echo "R9_MESSAGES_LOCAL_CONVERSATION_STATIC_CONTRACT=PASS"
echo "R9_SYSTEM_COHESION_STATIC_CONTRACT=PASS"
echo "R9_TEXT_READER_STANDALONE_STATIC_CONTRACT=PASS"
echo "R9_PHYSICAL_UX_STATIC_CONTRACTS=PASS"

SOURCE_MUTATION_AUTHORIZED=YES \
BUILD_AUTHORIZED=YES \
EXPECTED_SOURCE_COMMIT="$EXPECTED_SOURCE_COMMIT" \
SABLE_QUALIFICATION_ONLY=YES \
SABLE_AUTO_REGISTER_ARTIFACT=NO \
  bash "$ROOT/build/panther/run-r8-release-candidate.sh"

echo "R9_PHYSICAL_UX_MODULE_QUALIFICATION=PASS"
echo "R9_MAC_VISUAL_ACCEPTANCE=WAIVED_BY_USER_FOR_R9"
echo "R9_PHYSICAL_PANTHER_VISUAL_ACCEPTANCE=REQUIRED"
echo "NEXT_FULL_PANTHER_BUILD_AUTHORIZED=YES_AFTER_MODULE_QUALIFICATION"
