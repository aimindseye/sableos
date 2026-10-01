#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/build/config/host-tools.env"

echo "===== SABLE HOST TOOL STATUS ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "HOST_TOOL_MUTATION_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "DELETE_AUTHORIZED=NO"
echo "DISCOVERY_MODE=DISABLED"
echo "HOST_TOOLS_ROOT=$SABLE_HOST_TOOLS_ROOT"
echo "ANDROID_SDK=$SABLE_ANDROID_SDK"
echo "AOSP_HOST_TOOLS_ROOT=$SABLE_AOSP_HOST_TOOLS_ROOT"
echo "JAVA_TOOLS_ROOT=$SABLE_JAVA_TOOLS_ROOT"
echo "RUST_ROOT=$SABLE_RUST_ROOT"
echo "SECURITY_BIN=$SABLE_SECURITY_BIN"
echo "REPO_TOOL=$SABLE_REPO_TOOL"

# Historical filename retained for accepted Panther contracts. It no longer
# searches PATH, caches, home directories, or Android OUT trees.
bash "$ROOT/build/host/verify-host-tools.sh" core

echo "SABLE_HOST_TOOL_AUDIT=PASS_CANONICAL_ONLY"
