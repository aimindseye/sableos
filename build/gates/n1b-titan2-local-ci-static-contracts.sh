#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "===== N1B TITAN2 LOCAL CI STATIC CONTRACTS ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=NO"
echo "IMAGE_BUILD_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "ADB_COMMANDS_RUN=NO"
echo "FASTBOOT_COMMANDS_RUN=NO"
echo "PUBLIC_RELEASE=NO"
echo "PRODUCTION_SIGNING=NO"

if [[ "${SABLEOS_DEVICE:-}" != titan2 || "${SABLEOS_RELEASE_VERSION:-}" != N1B ]]; then
  echo "N1B_TITAN2_LOCAL_CI_STATIC_CONTRACTS=SKIP_NOT_TITAN2_N1B"
  exit 0
fi

grep -Fq 'run_static_contract sable-pipeline' "$ROOT/build/local-ci/run.sh"
echo "N1B_LOCAL_CI_RUNS_SABLE_PIPELINE_CONTRACT=PASS"

run_n1b_contract() {
  local name="$1"
  local path="$2"

  bash "$ROOT/$path" .
  echo "N1B_LOCAL_CI_STATIC_CONTRACT_${name}=PASS"
}

run_n1b_contract SABLE_HOST_TOOLCHAIN \
  build/gates/n1b-sable-host-toolchain-contract.sh
run_n1b_contract STAGE_A_FAST_LANE \
  build/gates/n1b-stage-a-fast-lane-contract.sh
run_n1b_contract PHASE_EXECUTION \
  build/gates/n1b-phase-execution-contract.sh
run_n1b_contract IDENTITY_STATIC \
  build/gates/n1b-sable-identity-static-contract.sh
run_n1b_contract BRANDING_DEFAULTS \
  build/gates/n1b-branding-defaults-contract.sh
run_n1b_contract SETUP_LAUNCHER_BINDING \
  build/gates/n1b-setup-launcher-binding-contract.sh
run_n1b_contract PHYSICAL_UX_READINESS \
  build/gates/n1b-physical-ux-readiness-contract.sh
run_n1b_contract FULL_CI_READINESS \
  build/gates/n1b-full-ci-readiness-contract.sh

echo "N1B_TITAN2_LOCAL_CI_STATIC_CONTRACTS=PASS"
