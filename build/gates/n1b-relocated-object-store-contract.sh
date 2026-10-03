#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AUDIT="$ROOT/build/titan2/audit-n1b-relocated-object-stores.sh"

fail() {
  echo "N1B_RELOCATED_OBJECT_STORE_CONTRACT=FAIL reason=$*" >&2
  exit 1
}

[[ -f "$AUDIT" ]] || fail audit_missing
bash -n "$AUDIT" || fail bash_n

for marker in \
  'source "$ROOT/build/config/storage.env"' \
  'source "$ROOT/build/config/host-tools.env"' \
  'EXPECTED_MANIFEST_SHA="2ce10689772b122b1cd8810a302735a67826753e819e17ca35a576aaff6c21cc"' \
  'EXPECTED_TREBLE_REV="70ecdf29d78928c84f556f7a4dc80a6d8f8c1e93"' \
  'EXPECTED_VNDK29_REV="16d658458c18835392bd4f2101eb28ba2e7b9e6f"' \
  '.repo/project-objects/$project_name.git' \
  '.repo/project-objects/$project_path.git' \
  '.repo/projects/$project_path.git' \
  'N1D_PRECLEANUP_SOURCE_STATE_PRESENT=' \
  'N1B_EXACT_REBUILD_AUTHORIZED=NO' \
  'N1B_V010014_PHYSICAL_CONTROL_AUTHORIZED=NO' \
  'N1E_BUILD_AUTHORIZED=NO' \
  'N1B_RELOCATED_OBJECT_STORE_AUDIT=PASS_READ_ONLY'
do
  grep -Fq -- "$marker" "$AUDIT" || fail "marker_missing=$marker"
done

if grep -Eq '^[[:space:]]*(adb|fastboot|curl|wget|repo[[:space:]]+sync|make[[:space:]]|m[[:space:]]|ninja[[:space:]])' "$AUDIT"; then
  fail forbidden_device_network_build_command
fi

if grep -Eq '^[[:space:]]*(cp|mv|install|rm[[:space:]]+-rf|git[[:space:]]+(checkout|switch|reset|clean|pull|fetch|clone))' "$AUDIT"; then
  fail forbidden_mutation_command
fi

echo "N1B_RELOCATED_OBJECT_STORE_SCRIPT_SYNTAX=PASS"
echo "N1B_RELOCATED_OBJECT_STORE_STANDARDIZED_STORAGE_BINDING=PASS"
echo "N1B_RELOCATED_OBJECT_STORE_NO_DEVICE_NETWORK_BUILD=PASS"
echo "N1B_RELOCATED_OBJECT_STORE_NO_MUTATION=PASS"
echo "N1B_RELOCATED_OBJECT_STORE_CONTRACT=PASS"
