#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AUDIT="$ROOT/build/titan2/audit-n1b-exact-reconstruction-feasibility.sh"

fail() {
  echo "N1B_EXACT_RECONSTRUCTION_FEASIBILITY_CONTRACT=FAIL reason=$*" >&2
  exit 1
}

[[ -f "$AUDIT" ]] || fail audit_missing
bash -n "$AUDIT" || fail bash_n

for marker in   'EXPECTED_SYSTEM_SHA="bc550bfaf8463324c122abb490cf4aba956b89e7e4d42168a55f0f0f0f5b638e"'   'EXPECTED_SYSTEM_BYTES=3180666880'   'EXPECTED_TARGET_FILES_SHA="29d21d08ceb9c286e85ec52996dcc53a17fd0290cc979b5853709ef7357f2481"'   'EXPECTED_TARGET_FILES_BYTES=2806615483'   'EXPECTED_REGISTERED_BUILD_SOURCE="462839cfcc362e4f4ed93d8a8dabf059885452b1"'   'EXPECTED_PRIOR_IDENTICAL_BUILD_SOURCE="851b4ba50c1d9141d26afaa1432cbe7a416073a6"'   'EXPECTED_LEDGER_SOURCE="8dd06e77410fea131e4716447f7f05067e427654"'   'KNOWN_C2_BLOCKED_TREBLE_REV="db688b38d729cf33e31baea47986c3fd210b671e"'   'KNOWN_C2_BLOCKED_VNDK29_REV="0062f4721125d68951fba37361c8204b929ae178"'   'N1B_PHASE08_ARTIFACT_IDENTITY=PASS_TWO_BUILDS_IDENTICAL'   'N1B_PHASE08_ANDROID_MANIFEST_PARITY=PASS_SEMANTIC_IDENTICAL'   'N1B_EXACT_REBUILD_AUTHORIZED=NO'   'N1B_V010014_PHYSICAL_CONTROL_AUTHORIZED=NO'   'N1E_BUILD_AUTHORIZED=NO'   'N1B_EXACT_RECONSTRUCTION_FEASIBILITY_AUDIT=PASS_READ_ONLY'
do
  grep -Fq -- "$marker" "$AUDIT" || fail "marker_missing=$marker"
done

if grep -Eq '^[[:space:]]*(adb|fastboot|curl|wget|repo[[:space:]]+sync|make[[:space:]]|m[[:space:]]|ninja[[:space:]])' "$AUDIT"; then
  fail forbidden_device_network_build_command
fi

if grep -Eq '^[[:space:]]*(cp|mv|install|rm[[:space:]]+-rf|git[[:space:]]+(checkout|switch|reset|clean|pull|fetch))' "$AUDIT"; then
  fail forbidden_mutation_command
fi

echo "N1B_EXACT_RECONSTRUCTION_FEASIBILITY_SCRIPT_SYNTAX=PASS"
echo "N1B_EXACT_RECONSTRUCTION_FEASIBILITY_NO_DEVICE_NETWORK_BUILD=PASS"
echo "N1B_EXACT_RECONSTRUCTION_FEASIBILITY_NO_MUTATION=PASS"
echo "N1B_EXACT_RECONSTRUCTION_FEASIBILITY_CONTRACT=PASS"
