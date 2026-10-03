#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROBE="$ROOT/build/titan2/probe-n1b-pinned-source-remotes.sh"

fail() {
  echo "N1B_PINNED_REMOTE_PROBE_CONTRACT=FAIL reason=$*" >&2
  exit 1
}

[[ -f "$PROBE" ]] || fail probe_missing
bash -n "$PROBE" || fail bash_n

for marker in   'EXPECTED_MANIFEST_SHA="2ce10689772b122b1cd8810a302735a67826753e819e17ca35a576aaff6c21cc"'   'EXPECTED_TREBLE_REV="70ecdf29d78928c84f556f7a4dc80a6d8f8c1e93"'   'EXPECTED_VNDK29_REV="16d658458c18835392bd4f2101eb28ba2e7b9e6f"'   'probe requires --authorize-network'   'REPO_SYNC_AUTHORIZED=NO'   'ANDROID_SOURCE_MUTATION_AUTHORIZED=NO'   'ANDROID_BUILD_AUTHORIZED=NO'   'DEVICE_CONTACT_AUTHORIZED=NO'   'FLASH_AUTHORIZED=NO'   'git init --bare "$bare"'   '--no-tags --depth=1 "$url" "$revision"'   'GIT_TERMINAL_PROMPT=0'   'PASS_ALL_EXACT_OBJECTS_REMOTE_AVAILABLE'   'REVIEW_REQUIRED_ONE_OR_MORE_EXACT_FETCHES_FAILED'   'PROVIDER_SPECIFIC_OBJECT_EXISTENCE_CHECK'   'N1B_EXACT_REBUILD_AUTHORIZED=NO'   'N1B_V010014_PHYSICAL_CONTROL_AUTHORIZED=NO'   'N1E_BUILD_AUTHORIZED=NO'
do
  grep -Fq -- "$marker" "$PROBE" || fail "marker_missing=$marker"
done

if grep -Eq '^[[:space:]]*(repo[[:space:]]+sync|adb([[:space:]]|$)|fastboot([[:space:]]|$)|make([[:space:]]|$)|m([[:space:]]|$)|ninja([[:space:]]|$))' "$PROBE"; then
  fail forbidden_sync_build_device_command
fi

if grep -Eq 'git[[:space:]]+-C[[:space:]][^ ]+[[:space:]]+(checkout|switch|reset|clean|pull|clone)' "$PROBE"; then
  fail forbidden_source_mutation_command
fi

echo "N1B_PINNED_REMOTE_PROBE_SCRIPT_SYNTAX=PASS"
echo "N1B_PINNED_REMOTE_PROBE_EXACT_TWO_OBJECT_SCOPE=PASS"
echo "N1B_PINNED_REMOTE_PROBE_EXPLICIT_NETWORK_AUTHORIZATION=PASS"
echo "N1B_PINNED_REMOTE_PROBE_NO_REPO_SYNC_BUILD_DEVICE=PASS"
echo "N1B_PINNED_REMOTE_PROBE_CONTRACT=PASS"
