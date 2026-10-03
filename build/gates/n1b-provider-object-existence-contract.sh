#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROBE="$ROOT/build/titan2/probe-n1b-provider-specific-object-existence.sh"

fail() {
  echo "N1B_PROVIDER_OBJECT_EXISTENCE_CONTRACT=FAIL reason=$*" >&2
  exit 1
}

[[ -f "$PROBE" ]] || fail probe_missing
bash -n "$PROBE" || fail bash_n

for marker in \
  'EXPECTED_BOUND_DECISION="REVIEW_REQUIRED_ONE_OR_MORE_EXACT_FETCHES_FAILED"' \
  'EXPECTED_TREBLE_SHA="70ecdf29d78928c84f556f7a4dc80a6d8f8c1e93"' \
  'EXPECTED_TREBLE_RECORDED_REPO="TrebleDroid/device_phh_treble"' \
  'EXPECTED_TREBLE_UPSTREAM_REPO="phhusson/device_phh_treble"' \
  'EXPECTED_VNDK_SHA="16d658458c18835392bd4f2101eb28ba2e7b9e6f"' \
  'EXPECTED_VNDK_GITILES_BASE="https://android.googlesource.com/platform/prebuilts/vndk/v29"' \
  'probe requires --authorize-network' \
  'REPO_SYNC_AUTHORIZED=NO' \
  'GIT_CLONE_AUTHORIZED=NO' \
  'GIT_CHECKOUT_AUTHORIZED=NO' \
  'ANDROID_SOURCE_MUTATION_AUTHORIZED=NO' \
  'ANDROID_BUILD_AUTHORIZED=NO' \
  'DEVICE_CONTACT_AUTHORIZED=NO' \
  'FLASH_AUTHORIZED=NO' \
  'https://api.github.com/repos/' \
  '?format=JSON' \
  'ABSENT_FROM_CHECKED_AUTHENTIC_GITHUB_LINEAGE' \
  'PASS_ALL_EXACT_OBJECTS_PROVIDER_VERIFIED' \
  'BLOCKED_TREBLE_EXACT_OBJECT_NOT_ADDRESSABLE' \
  'REVIEW_REQUIRED_PROVIDER_CHECK_INCONCLUSIVE' \
  'N1B_EXACT_REBUILD_AUTHORIZED=NO' \
  'N1B_V010014_PHYSICAL_CONTROL_AUTHORIZED=NO' \
  'N1E_BUILD_AUTHORIZED=NO'
do
  grep -Fq -- "$marker" "$PROBE" || fail "marker_missing=$marker"
done

if grep -Eq '^[[:space:]]*(repo[[:space:]]+sync|git[[:space:]]+clone|adb([[:space:]]|$)|fastboot([[:space:]]|$)|make([[:space:]]|$)|m([[:space:]]|$)|ninja([[:space:]]|$))' "$PROBE"; then
  fail forbidden_sync_clone_build_device_command
fi

if grep -Eq 'git[[:space:]]+-C[[:space:]][^ ]+[[:space:]]+(checkout|switch|reset|clean|pull|fetch)' "$PROBE"; then
  fail forbidden_source_mutation_command
fi

echo "N1B_PROVIDER_OBJECT_EXISTENCE_SCRIPT_SYNTAX=PASS"
echo "N1B_PROVIDER_OBJECT_EXISTENCE_BOUND_EVIDENCE=PASS_STATIC"
echo "N1B_PROVIDER_OBJECT_EXISTENCE_GITHUB_GITILES_SCOPE=PASS"
echo "N1B_PROVIDER_OBJECT_EXISTENCE_NO_SYNC_CLONE_BUILD_DEVICE=PASS"
echo "N1B_PROVIDER_OBJECT_EXISTENCE_CONTRACT=PASS"
