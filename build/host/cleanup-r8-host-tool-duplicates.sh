#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT/build/config/r8-host-tools.env"

HOST_TOOL_CLEANUP_AUTHORIZED="${HOST_TOOL_CLEANUP_AUTHORIZED:-NO}"
CACHE_ROOT="${SABLE_LOCAL_CI_CACHE_ROOT:-/srv/data/sable-build/sableos/local-ci-cache}"

if [[ "$HOST_TOOL_CLEANUP_AUTHORIZED" != YES ]]; then
    echo "SABLE_HOST_TOOL_CLEANUP=REFUSED_NOT_AUTHORIZED"
    exit 2
fi

echo "===== SABLE HOST TOOL DUPLICATE CLEANUP ====="
echo "HOST_TOOL_CLEANUP_AUTHORIZED=YES"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "CLEAN_OR_CLOBBER_AUTHORIZED=NO"
echo "DELETE_AUTHORIZED=KNOWN_DUPLICATE_TOOL_CACHE_ONLY"

# Never remove a duplicate until the canonical host gate proves the replacement.
bash "$ROOT/build/host/verify-r8-host-tools.sh"

remove_known_duplicate() {
    local path="$1"
    if [[ -e "$path" || -L "$path" ]]; then
        rm -rf --one-file-system -- "$path"
        echo "REMOVED_DUPLICATE=$path"
    else
        echo "DUPLICATE_ALREADY_ABSENT=$path"
    fi
}

remove_known_duplicate "$CACHE_ROOT/pinned-tools"

shopt -s nullglob
for path in "$CACHE_ROOT"/mobsfscan-venv-*; do
    remove_known_duplicate "$path"
done
shopt -u nullglob

# mobsfscan-source may have been moved by the centralization script. Only
# remove a leftover duplicate when the canonical exact source checkout exists.
if [[ -d "$SABLE_MOBSFSCAN_SOURCE/.git" ]]     && [[ "$(git -C "$SABLE_MOBSFSCAN_SOURCE" rev-parse HEAD)" == "$SABLE_MOBSFSCAN_COMMIT" ]]
then
    if [[ -d "$CACHE_ROOT/mobsfscan-source/.git" ]]; then
        remove_known_duplicate "$CACHE_ROOT/mobsfscan-source"
    fi
fi

echo "SABLE_HOST_TOOL_CLEANUP=PASS"
