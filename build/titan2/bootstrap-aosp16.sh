#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/build/config/titan2-n0.env"

NETWORK_FETCH_AUTHORIZED="${NETWORK_FETCH_AUTHORIZED:-NO}"
[[ "$NETWORK_FETCH_AUTHORIZED" == YES ]] || {
  echo "TITAN2_AOSP_BOOTSTRAP=BLOCKED_NETWORK_FETCH_NOT_AUTHORIZED"
  echo "Set NETWORK_FETCH_AUTHORIZED=YES explicitly to initialize/sync the pinned AOSP tree."
  exit 78
}

command -v repo >/dev/null 2>&1 || {
  echo "TITAN2_AOSP_BOOTSTRAP=FAIL_REPO_TOOL_MISSING"
  exit 2
}

mkdir -p "$SABLE_TITAN2_UPSTREAM" "$SABLE_TITAN2_EVIDENCE"
cd "$SABLE_TITAN2_UPSTREAM"

if [[ ! -d .repo ]]; then
  repo init \
    -u "$SABLE_TITAN2_AOSP_MANIFEST_URL" \
    -b "$SABLE_TITAN2_AOSP_TAG"
else
  echo "TITAN2_AOSP_REPO_ALREADY_INITIALIZED=YES"
fi

repo sync -c -j"${JOBS:-8}" --fail-fast

repo manifest -r > "$SABLE_TITAN2_EVIDENCE/aosp-${SABLE_TITAN2_AOSP_TAG}-pinned-manifest.xml"

echo "TITAN2_AOSP_TAG=$SABLE_TITAN2_AOSP_TAG"
echo "TITAN2_AOSP_UPSTREAM=$SABLE_TITAN2_UPSTREAM"
echo "TITAN2_AOSP_PINNED_MANIFEST=$SABLE_TITAN2_EVIDENCE/aosp-${SABLE_TITAN2_AOSP_TAG}-pinned-manifest.xml"
echo "TITAN2_AOSP_PINNED_MANIFEST_SHA256=$(sha256sum "$SABLE_TITAN2_EVIDENCE/aosp-${SABLE_TITAN2_AOSP_TAG}-pinned-manifest.xml" | awk '{print $1}')"
echo "TITAN2_AOSP_BOOTSTRAP=PASS"
