#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PREP="$ROOT/build/titan2/prepare-c3a-v010014-runtime-control.sh"
C3A_ENV="$ROOT/build/titan2/n1d-c3a-control-evidence.env"

fail() {
  echo "C3A_V010014_CONTROL_CONTRACT=FAIL reason=$*" >&2
  exit 1
}

for f in "$PREP" "$C3A_ENV"; do
  [[ -f "$f" ]] || fail "missing_file=$f"
done
bash -n "$PREP" || fail bash_n

for marker in   'EXPECTED_PROVIDER_DECISION="BLOCKED_BOTH_EXACT_OBJECTS_NOT_ADDRESSABLE"'   'EXPECTED_PROVIDER_SEAL="fce7ed70c41ef99ccfa0ff4ec9e8c5a39a738cef6cdb266fc1ba3496c0203730"'   'EXPECTED_C3A_SHA256="4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16"'   'EXPECTED_C3A_BYTES=3146977280'   'EXPECTED_C3A_PATCH_COUNT=369'   'EXPECTED_C3A_MANAGED_PROJECT_COUNT=991'   'N1E_STATUS=RETIRED_EXACT_N1B_PREREQUISITE_UNAVAILABLE'   'C3A_V010014_PHYSICAL_CONTROL_AUTHORIZED=NO'   'C3A_DERIVED_ISOLATION_BUILD_AUTHORIZED=NO'   'LIVE_PREFLIGHT_REQUIRED=YES'   'MANUAL_PRE_RESIZE_ALLOWED=NO'   'COW_DELETION_ALLOWED=NO'   'AVB_MUTATION_ALLOWED=NO'   'BOOT_CHAIN_FLASH_ALLOWED=NO'   'WHOLE_SUPER_FLASH_ALLOWED=NO'   'RECOVERY_RESULT_REQUIRES_SEPARATE_FACTORY_RESET_AUTHORIZATION=YES'   'C2_FALLBACK_CONTROL=REVIEW_ONLY_IF_C3A_UNAVAILABLE_OR_INCONCLUSIVE'   'WRITE_CAPABLE_SCRIPT_CREATED=NO'
do
  grep -Fq -- "$marker" "$PREP" || fail "marker_missing=$marker"
done

for marker in   'N1D_C3A_CONTROL_EVIDENCE_STATUS=PASS_SYSTEMIMAGE'   'N1D_C3A_SYSTEM_SHA256=4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16'   'N1D_C3A_SYSTEM_BYTES=3146977280'   'N1D_C3A_CONTROL_FIDELITY=PUBLIC_FUNCTIONAL_REPRODUCTION'   'N1D_C3A_MANAGED_PROJECT_COUNT=991'   'N1D_C3A_CONTROL_PATCH_COUNT=369'
do
  grep -Fxq -- "$marker" "$C3A_ENV" || fail "c3a_evidence_marker_missing=$marker"
done

if grep -Eq '^[[:space:]]*(adb|fastboot|repo[[:space:]]+sync|make[[:space:]]|m[[:space:]]|ninja[[:space:]])' "$PREP"; then
  fail forbidden_device_sync_build_command
fi

if grep -Eq '^[[:space:]]*(git[[:space:]]+(checkout|switch|reset|clean|pull|fetch)|cp[[:space:]]|mv[[:space:]]|install[[:space:]])' "$PREP"; then
  fail forbidden_source_or_artifact_mutation_command
fi

echo "C3A_V010014_CONTROL_SCRIPT_SYNTAX=PASS"
echo "C3A_V010014_CONTROL_PROVIDER_RETIREMENT_BINDING=PASS_STATIC"
echo "C3A_V010014_CONTROL_SEALED_ARTIFACT_BINDING=PASS_STATIC"
echo "C3A_V010014_CONTROL_NO_DEVICE_BUILD_MUTATION=PASS"
echo "C3A_V010014_CONTROL_CONTRACT=PASS"
