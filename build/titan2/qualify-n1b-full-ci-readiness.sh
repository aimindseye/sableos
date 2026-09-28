#!/usr/bin/env bash

REPO="${REPO:-$(pwd)}"
DOC="$REPO/docs/titan2/N1B_FULL_CI_READINESS.md"
FAILURES=0
FIRST_FAILURE=""

say() {
  printf '%s\n' "$1"
}

record_failure() {
  NAME="$1"
  DETAIL="$2"
  FAILURES=$((FAILURES + 1))
  if [ -z "$FIRST_FAILURE" ]; then
    FIRST_FAILURE="$NAME"
  fi
  say "$NAME=FAIL"
  say "$DETAIL"
}

pass() {
  say "$1=PASS"
}

require_file() {
  NAME="$1"
  PATH_VALUE="$2"
  if [ -f "$REPO/$PATH_VALUE" ]; then
    pass "$NAME"
  else
    record_failure "$NAME" "MISSING_PATH=$PATH_VALUE"
  fi
}

require_marker() {
  NAME="$1"
  MARKER="$2"
  if grep -Fq "$MARKER" "$DOC" 2>/dev/null; then
    pass "$NAME"
  else
    record_failure "$NAME" "MISSING_MARKER=$MARKER"
  fi
}

say "===== N1B FULL CI READINESS QUALIFIER ====="
say "REPO=$REPO"
say "DOC=$DOC"
say "SOURCE_MUTATION_AUTHORIZED=NO"
say "BUILD_AUTHORIZED=NO"
say "IMAGE_BUILD_AUTHORIZED=NO"
say "DEVICE_CONTACT_AUTHORIZED=NO"
say "FLASH_AUTHORIZED=NO"
say "ADB_COMMANDS_RUN=NO"
say "FASTBOOT_COMMANDS_RUN=NO"
say "PUBLIC_RELEASE=NO"
say "PRODUCTION_SIGNING=NO"

require_file "N1B_FULL_CI_DOC" "docs/titan2/N1B_FULL_CI_READINESS.md"
require_file "N1B_FULL_CI_QUALIFIER" "build/titan2/qualify-n1b-full-ci-readiness.sh"
require_file "N1B_FULL_CI_CONTRACT" "build/gates/n1b-full-ci-readiness-contract.sh"

if [ -f "$DOC" ]; then
  require_marker "N1B_FULL_CI_READINESS_MARKER" "N1B_FULL_CI_READINESS=YES"
  require_marker "N1B_PHASE_07_MARKER" "N1B_PHASE=07"
  require_marker "N1B_PHASE_07_FULL_CI_NAME" "N1B_PHASE_NAME=FULL_CI_READINESS"
  require_marker "N1B_NO_IMAGE_MARKER" "IMAGE_BUILD_AUTHORIZED=NO"
  require_marker "N1B_NO_DEVICE_MARKER" "DEVICE_CONTACT_AUTHORIZED=NO"
  require_marker "N1B_NO_FLASH_MARKER" "FLASH_AUTHORIZED=NO"
  require_marker "N1B_NO_RELEASE_MARKER" "PUBLIC_RELEASE=NO"
  require_marker "N1B_NO_SIGNING_MARKER" "PRODUCTION_SIGNING=NO"
  require_marker "N1B_PHASE_01_REQUIRED" "N1B_PHASE_01_STAGE_A_FAST_LANE_REQUIRED=YES"
  require_marker "N1B_PHASE_02_REQUIRED" "N1B_PHASE_02_PHASE_EXECUTION_REQUIRED=YES"
  require_marker "N1B_PHASE_03_REQUIRED" "N1B_PHASE_03_IDENTITY_STATIC_REQUIRED=YES"
  require_marker "N1B_PHASE_04_REQUIRED" "N1B_PHASE_04_BRANDING_DEFAULTS_REQUIRED=YES"
  require_marker "N1B_PHASE_05_REQUIRED" "N1B_PHASE_05_SETUP_LAUNCHER_BINDING_REQUIRED=YES"
  require_marker "N1B_PHASE_06_REQUIRED" "N1B_PHASE_06_PHYSICAL_UX_READINESS_REQUIRED=YES"
  require_marker "N1B_N1A_SUBSTRATE_REQUIRED" "N1B_FULL_CI_REQUIRES_N1A_SUBSTRATE_EVIDENCE=YES"
  require_marker "N1B_R7E_SUBSTRATE_REQUIRED" "N1B_FULL_CI_REQUIRES_R7E_ANDROID16_RESTLESS_SUBSTRATE=YES"
  require_marker "N1B_N0B_DEVIATIONS_REQUIRED" "N1B_FULL_CI_REQUIRES_N0B_DEVIATIONS_RECORDED=YES"
  require_marker "N1B_FLASH_BOUNDARY_REQUIRED" "N1B_FULL_CI_REQUIRES_N0_N1_FLASH_PLAN_BOUNDARY=YES"
  require_marker "N1B_STAGE_A_SCOPE" "N1B_STAGE_A_FAST_LANE_BUILD_SCOPE=YES_APPS_AND_STATIC_GATES_ONLY"
  require_marker "N1B_PROMOTES_TO_PHASE_08" "N1B_PHASE_07_PROMOTES_TO_PHASE_08_ONLY=YES"
  require_marker "N1B_PASS_MARKER" "N1B_FULL_CI_READINESS=PASS"
fi

require_file "N1B_DOC_PHASE_EXECUTION" "docs/titan2/N1B_PHASE_EXECUTION_LEDGER.md"
require_file "N1B_DOC_IDENTITY_STATIC" "docs/titan2/N1B_SABLE_IDENTITY_STATIC_GATE.md"
require_file "N1B_DOC_BRANDING_DEFAULTS" "docs/titan2/N1B_BRANDING_DEFAULTS_READINESS.md"
require_file "N1B_DOC_SETUP_LAUNCHER" "docs/titan2/N1B_SETUP_LAUNCHER_BINDING_READINESS.md"
require_file "N1B_DOC_PHYSICAL_UX" "docs/titan2/N1B_PHYSICAL_UX_ACCEPTANCE_READINESS.md"

require_file "N1B_GATE_STAGE_A_FAST_LANE" "build/gates/n1b-stage-a-fast-lane-contract.sh"
require_file "N1B_GATE_SABLE_HOST_TOOLCHAIN" "build/gates/n1b-sable-host-toolchain-contract.sh"
require_file "N1B_GATE_PHASE_EXECUTION" "build/gates/n1b-phase-execution-contract.sh"
require_file "N1B_GATE_IDENTITY_STATIC" "build/gates/n1b-sable-identity-static-contract.sh"
require_file "N1B_GATE_BRANDING_DEFAULTS" "build/gates/n1b-branding-defaults-contract.sh"
require_file "N1B_GATE_SETUP_LAUNCHER" "build/gates/n1b-setup-launcher-binding-contract.sh"
require_file "N1B_GATE_PHYSICAL_UX" "build/gates/n1b-physical-ux-readiness-contract.sh"
require_file "N1B_GATE_FULL_CI" "build/gates/n1b-full-ci-readiness-contract.sh"

require_file "N1B_QUALIFIER_STAGE_A_FAST_LANE_SABLE_HOST" "build/titan2/qualify-n1b-stage-a-fast-lane-sable-host.sh"
require_file "N1B_QUALIFIER_PHASE_EXECUTION" "build/titan2/qualify-n1b-phase-execution.sh"
require_file "N1B_QUALIFIER_IDENTITY_STATIC" "build/titan2/qualify-n1b-sable-identity-static.sh"
require_file "N1B_QUALIFIER_BRANDING_DEFAULTS" "build/titan2/qualify-n1b-branding-defaults.sh"
require_file "N1B_QUALIFIER_SETUP_LAUNCHER" "build/titan2/qualify-n1b-setup-launcher-binding.sh"
require_file "N1B_QUALIFIER_PHYSICAL_UX" "build/titan2/qualify-n1b-physical-ux-readiness.sh"
require_file "N1B_QUALIFIER_FULL_CI" "build/titan2/qualify-n1b-full-ci-readiness.sh"

say "===== N1B FULL CI READINESS RESULT ====="
say "FAILURES=$FAILURES"
if [ -n "$FIRST_FAILURE" ]; then
  say "FIRST_FAILURE=$FIRST_FAILURE"
fi

if [ "$FAILURES" -eq 0 ]; then
  say "N1B_FULL_CI_READINESS=PASS"
  exit 0
fi

say "N1B_FULL_CI_READINESS=FAIL"
exit 1
