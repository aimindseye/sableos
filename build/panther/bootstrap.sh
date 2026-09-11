#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$REPO_ROOT/build/config/panther-grapheneos-2026081300.env"

NETWORK_FETCH_AUTHORIZED="${NETWORK_FETCH_AUTHORIZED:-NO}"
if [[ "$NETWORK_FETCH_AUTHORIZED" != YES ]]; then
    echo "Refusing network bootstrap. Set NETWORK_FETCH_AUTHORIZED=YES explicitly."
    exit 2
fi

mkdir -p "$SABLEOS_ROOT" "$SABLEOS_ROOT/upstream/panther" "$SABLEOS_OUT" "$SABLEOS_EVIDENCE" "$SABLEOS_HOST_TOOLS"

if [[ ! -d "$SABLEOS_UPSTREAM/.repo" ]]; then
    mkdir -p "$SABLEOS_UPSTREAM"
    cd "$SABLEOS_UPSTREAM"
    repo init -u https://github.com/GrapheneOS/platform_manifest.git -b "refs/tags/$SABLEOS_GRAPHENE_TAG"
fi

cd "$SABLEOS_UPSTREAM"
repo sync -j"${JOBS:-8}"
repo manifest -r > "$SABLEOS_EVIDENCE/grapheneos-${SABLEOS_GRAPHENE_TAG}-pinned-manifest.xml"
sha256sum "$SABLEOS_EVIDENCE/grapheneos-${SABLEOS_GRAPHENE_TAG}-pinned-manifest.xml"

echo "BOOTSTRAP=PASS"
echo "UPSTREAM=$SABLEOS_UPSTREAM"
