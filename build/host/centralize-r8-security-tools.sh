#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT/build/config/r8-host-tools.env"

HOST_TOOL_CENTRALIZATION_AUTHORIZED="${HOST_TOOL_CENTRALIZATION_AUTHORIZED:-NO}"
CACHE_ROOT="${SABLE_LOCAL_CI_CACHE_ROOT:-/srv/data/sable-build/sableos/local-ci-cache}"

if [[ "$HOST_TOOL_CENTRALIZATION_AUTHORIZED" != YES ]]; then
    echo "SABLE_HOST_TOOL_CENTRALIZATION=REFUSED_NOT_AUTHORIZED"
    exit 2
fi

echo "===== SABLE HOST SECURITY TOOL CENTRALIZATION ====="
echo "HOST_TOOL_CENTRALIZATION_AUTHORIZED=YES"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "PACKAGE_INSTALL_AUTHORIZED=NO"
echo "DELETE_AUTHORIZED=NO"
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "DEST=$SABLE_SECURITY_BIN"

mkdir -p "$SABLE_SECURITY_BIN"

verify_candidate() {
    local tool="$1"
    local candidate="$2"
    [[ -x "$candidate" ]] || return 1
    python3 "$ROOT/build/install-pinned-tool.py"         --tool "$tool"         --verify-dir "$(dirname "$candidate")"         >/dev/null 2>&1
}

centralize_binary() {
    local tool="$1"
    local canonical="$SABLE_SECURITY_BIN/$tool"

    if verify_candidate "$tool" "$canonical"; then
        echo "SABLE_HOST_TOOL_$tool=ALREADY_CANONICAL path=$canonical"
        return 0
    fi

    local candidates=()
    local path_candidate
    path_candidate="$(command -v "$tool" 2>/dev/null || true)"

    candidates+=(
        "$CACHE_ROOT/pinned-tools/$tool"
        "$SABLE_CARGO_HOME/bin/$tool"
        "$HOME/.cargo/bin/$tool"
        "/usr/local/bin/$tool"
        "/usr/bin/$tool"
    )
    [[ -n "$path_candidate" ]] && candidates+=("$path_candidate")

    local candidate
    for candidate in "${candidates[@]}"; do
        [[ "$candidate" == "$canonical" ]] && continue
        if verify_candidate "$tool" "$candidate"; then
            install -m 0755 "$candidate" "$canonical"
            echo "SABLE_HOST_TOOL_$tool=CENTRALIZED source=$candidate destination=$canonical"
            return 0
        fi
    done

    echo "SABLE_HOST_TOOL_$tool=FAIL_NO_EXACT_EXISTING_CANDIDATE"
    return 1
}

rc=0
for tool in cargo-audit cargo-deny cargo-llvm-cov gitleaks; do
    centralize_binary "$tool" || rc=1
done

python3 "$ROOT/build/install-pinned-tool.py" --verify-dir "$SABLE_SECURITY_BIN"     || rc=1

mkdir -p "$SABLE_MOBSFSCAN_ROOT"
if [[ ! -d "$SABLE_MOBSFSCAN_SOURCE/.git" && -d "$CACHE_ROOT/mobsfscan-source/.git" ]]; then
    cached_commit="$(git -C "$CACHE_ROOT/mobsfscan-source" rev-parse HEAD 2>/dev/null || true)"
    if [[ "$cached_commit" == "$SABLE_MOBSFSCAN_COMMIT" ]]; then
        cp -a "$CACHE_ROOT/mobsfscan-source" "$SABLE_MOBSFSCAN_SOURCE"
        echo "SABLE_MOBSFSCAN_SOURCE=COPIED_FROM_LOCAL_CI_CACHE"
    fi
fi

if [[ -d "$SABLE_MOBSFSCAN_SOURCE/.git" ]]; then
    actual="$(git -C "$SABLE_MOBSFSCAN_SOURCE" rev-parse HEAD 2>/dev/null || true)"
    echo "SABLE_MOBSFSCAN_SOURCE_COMMIT=$actual"
    [[ "$actual" == "$SABLE_MOBSFSCAN_COMMIT" ]] || rc=1
else
    echo "SABLE_MOBSFSCAN_SOURCE=NOT_AVAILABLE"
    rc=1
fi

if [[ -x "$SABLE_MOBSFSCAN" && -x "$SABLE_MOBSFSCAN_PYTHON" ]]; then
    echo "SABLE_MOBSFSCAN_RUNTIME=ALREADY_CANONICAL"
else
    echo "SABLE_MOBSFSCAN_RUNTIME=BOOTSTRAP_REQUIRED"
fi

if [[ "$rc" -ne 0 ]]; then
    echo "SABLE_HOST_TOOL_CENTRALIZATION=INCOMPLETE"
    echo "NEXT=bash build/host/audit-r8-host-tools.sh"
    exit 3
fi

echo "SABLE_HOST_TOOL_CENTRALIZATION=PASS"
