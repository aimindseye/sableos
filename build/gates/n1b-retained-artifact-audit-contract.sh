#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AUDIT="$ROOT/build/titan2/audit-n1b-retained-artifacts.sh"

fail() {
  echo "N1B_RETAINED_ARTIFACT_AUDIT_CONTRACT=FAIL reason=$*" >&2
  exit 1
}

[[ -f "$AUDIT" ]] || fail audit_missing
bash -n "$AUDIT" || fail bash_n

for marker in   'EXPECTED_SYSTEM_SHA="bc550bfaf8463324c122abb490cf4aba956b89e7e4d42168a55f0f0f0f5b638e"'   'EXPECTED_SYSTEM_BYTES=3180666880'   'DEVICE_CONTACT_AUTHORIZED=NO'   'BUILD_AUTHORIZED=NO'   'NETWORK_AUTHORIZED=NO'   'SOURCE_MUTATION_AUTHORIZED=NO'   'ARTIFACT_MUTATION_AUTHORIZED=NO'   'n1b-phase-08-image-build.env'   'TARGET_FILES_SHA256'   'TARGET_FILES_BYTES'   'old-n1b-reference-pack.zip'   'C0_01_N1B_CANDIDATES.txt'   'N1B_CONTROL_ARTIFACT_STATUS=NOT_FOUND_IN_RETAINED_STORAGE'   'N1B_RETAINED_ARTIFACT_FORENSIC_AUDIT=PASS_READ_ONLY'
do
  grep -Fq -- "$marker" "$AUDIT" || fail "marker_missing=$marker"
done

if grep -Eq '^[[:space:]]*(adb|fastboot|curl|wget|repo[[:space:]]+sync|make[[:space:]]|m[[:space:]]|ninja[[:space:]])' "$AUDIT"; then
  fail forbidden_command_present
fi

if grep -Eq '(unzip[[:space:]]+-p.*[[:space:]]>[[:space:]]*[^&]|^[[:space:]]*(cp|mv|install)[[:space:]])' "$AUDIT"; then
  fail artifact_write_command_present
fi

echo "N1B_RETAINED_ARTIFACT_AUDIT_SCRIPT_SYNTAX=PASS"
echo "N1B_RETAINED_ARTIFACT_AUDIT_NO_DEVICE_NETWORK_BUILD=PASS"
echo "N1B_RETAINED_ARTIFACT_AUDIT_NO_ARTIFACT_MUTATION=PASS"
echo "N1B_RETAINED_ARTIFACT_AUDIT_CONTRACT=PASS"
