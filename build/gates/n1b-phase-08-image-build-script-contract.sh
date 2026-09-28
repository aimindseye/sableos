#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
ROOT="$(cd "$ROOT" && pwd)"
SCRIPT="$ROOT/build/titan2/build-n1b-phase-08-image-candidate.sh"
READINESS_CONTRACT="$ROOT/build/gates/n1b-phase-08-image-build-candidate-contract.sh"

fail() {
  echo "N1B_PHASE_08_IMAGE_BUILD_SCRIPT_CONTRACT=FAIL $*"
  exit 1
}

require_marker() {
  local marker="$1"
  local path="${2:-$SCRIPT}"
  grep -Fq -- "$marker" "$path" || fail "marker=$marker path=$path"
}

echo "===== N1B PHASE 08 IMAGE BUILD SCRIPT CONTRACT ====="
echo "ROOT=$ROOT"
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=NO_FOR_CONTRACT"
echo "IMAGE_BUILD_AUTHORIZED=NO_FOR_CONTRACT"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "ADB_COMMANDS_RUN=NO"
echo "FASTBOOT_COMMANDS_RUN=NO"
echo "PUBLIC_RELEASE=NO"
echo "PRODUCTION_SIGNING=NO"

[[ -f "$SCRIPT" ]] || fail "missing_script=$SCRIPT"
[[ -f "$READINESS_CONTRACT" ]] || fail "missing_readiness_contract=$READINESS_CONTRACT"

bash -n "$SCRIPT"
echo "N1B_PHASE_08_IMAGE_BUILD_SCRIPT_SYNTAX=PASS"

require_marker "BUILD_AUTHORIZED=YES_N1B_IMAGE_ONLY"
require_marker "IMAGE_BUILD_AUTHORIZED=YES_N1B_CANDIDATE_ONLY"
require_marker "DEVICE_CONTACT_AUTHORIZED=NO"
require_marker "FLASH_AUTHORIZED=NO"
require_marker "ADB_COMMANDS_RUN=NO"
require_marker "FASTBOOT_COMMANDS_RUN=NO"
require_marker "PUBLIC_RELEASE=NO"
require_marker "PRODUCTION_SIGNING=NO"
require_marker "DEVICE=titan2"
require_marker "RELEASE=N1B"
require_marker "ARTIFACT_KIND=gsi-system-image"
require_marker "PRIMARY_ARTIFACT=system"
require_marker "SABLEOS_DEVICE=titan2" "$ROOT/build/gates/sable-pipeline-contract.sh"
require_marker "SABLEOS_RELEASE_VERSION=N1B" "$ROOT/build/gates/sable-pipeline-contract.sh"
require_marker "SABLE_LOCAL_CI=PASS"
require_marker "PROFILE=full"
require_marker 'SOURCE_COMMIT=$SOURCE_COMMIT'
require_marker "device/phh/treble/treble_arm64_bvN.mk"
require_marker "treble_arm64_bvN-bp4a-userdebug"
require_marker "systemimage target-files-package otatools"
require_marker "SYSTEM/product/etc/sableos/n1-substrate.env"
require_marker "build/sable.sh\" titan2 N1B register-artifact"
require_marker "--artifact-kind gsi-system-image"
require_marker "--primary-artifact system"
require_marker "--metadata \"artifact_logical_bytes="
require_marker "N1B_PHASE_08_IMAGE_BUILD_CANDIDATE=PASS"

echo "N1B_PHASE_08_IMAGE_BUILD_SCRIPT_MARKERS=PASS"

if grep -Eq '(^|[^A-Za-z0-9_-])(adb|fastboot)([[:space:]]|$)' "$SCRIPT"; then
  fail "blocked_device_command_token"
fi
if grep -Eq '(^|[^A-Za-z0-9_-])(flashing|unlock|relock|wipe)([[:space:]]|$)' "$SCRIPT"; then
  fail "blocked_destructive_token"
fi
if grep -Fq "sable-release" "$SCRIPT"; then
  fail "blocked_production_signing_token"
fi

echo "N1B_PHASE_08_IMAGE_BUILD_SCRIPT_NO_DEVICE_COMMANDS=PASS"
echo "N1B_PHASE_08_IMAGE_BUILD_SCRIPT_NO_DESTRUCTIVE_TOKENS=PASS"
echo "N1B_PHASE_08_IMAGE_BUILD_SCRIPT_NO_PRODUCTION_SIGNING=PASS"

bash "$READINESS_CONTRACT" "$ROOT"
echo "N1B_PHASE_08_READINESS_CONTRACT_STILL_PASS=PASS"

echo "===== N1B PHASE 08 IMAGE BUILD SCRIPT CONTRACT RESULT ====="
echo "FAILURES=0"
echo "N1B_PHASE_08_IMAGE_BUILD_SCRIPT_CONTRACT=PASS"
