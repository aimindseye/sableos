#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT/build/config/r8-host-tools.env"

echo "===== SABLE HOST TOOL INVENTORY ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "HOST_TOOL_MUTATION_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "DELETE_AUTHORIZED=NO"
echo "HOST_TOOLS_ROOT=$SABLE_HOST_TOOLS_ROOT"
echo "SECURITY_BIN=$SABLE_SECURITY_BIN"
echo "MOBSFSCAN_ROOT=$SABLE_MOBSFSCAN_ROOT"

show_exec() {
    local label="$1"
    local path="$2"
    shift 2
    if [[ -x "$path" ]]; then
        echo "$label=FOUND path=$path"
        "$path" "$@" 2>&1 | head -n 2 | sed "s/^/$label.VERSION=/"
    else
        echo "$label=MISSING path=$path"
    fi
}

show_command() {
    local name="$1"
    local path
    path="$(command -v "$name" 2>/dev/null || true)"
    if [[ -n "$path" ]]; then
        echo "PATH_CANDIDATE_$name=$path"
        "$path" --version 2>&1 | head -n 2 | sed "s/^/PATH_CANDIDATE_$name.VERSION=/" || true
    else
        echo "PATH_CANDIDATE_$name=NONE"
    fi
}

echo
echo "===== CANONICAL BUILD TOOLCHAIN ====="
show_exec ANDROID_SDKMANAGER "$SABLE_SDKMANAGER" --version
show_exec ANDROID_APKANALYZER "$SABLE_APKANALYZER" --version
show_exec RUSTC "$SABLE_RUSTC" --version
show_exec CARGO "$SABLE_CARGO" --version
show_exec RUSTUP "$SABLE_RUSTUP" --version
show_exec JDK17 "$SABLE_JDK17/bin/java" -version
show_exec JDK21 "$SABLE_JDK21/bin/java" -version
show_exec PYTHON "$SABLE_PYTHON" --version

echo
echo "===== CANONICAL SECURITY TOOLS ====="
python3 "$ROOT/build/install-pinned-tool.py" --verify-dir "$SABLE_SECURITY_BIN" 2>&1     || echo "CANONICAL_SECURITY_TOOL_VERIFY=INCOMPLETE"

echo
echo "===== PATH SECURITY TOOL CANDIDATES ====="
for tool in cargo-audit cargo-deny cargo-llvm-cov gitleaks mobsfscan; do
    show_command "$tool"
done

echo
echo "===== KNOWN LOCAL-CI CACHE CANDIDATES ====="
CACHE_ROOT="${SABLE_LOCAL_CI_CACHE_ROOT:-/srv/data/sable-build/sableos/local-ci-cache}"
for tool in cargo-audit cargo-deny cargo-llvm-cov gitleaks; do
    candidate="$CACHE_ROOT/pinned-tools/$tool"
    if [[ -x "$candidate" ]]; then
        echo "LOCAL_CI_CACHE_CANDIDATE_$tool=$candidate"
    else
        echo "LOCAL_CI_CACHE_CANDIDATE_$tool=NONE"
    fi
done

echo
echo "===== RUST COMPONENTS ====="
if [[ -x "$SABLE_RUSTUP" ]]; then
    "$SABLE_RUSTUP" component list --installed --toolchain "$SABLE_RUST_TOOLCHAIN"         | sed 's/^/RUST_COMPONENT=/'
fi

echo
echo "===== PYTHON CAPABILITIES ====="
"$SABLE_PYTHON" - <<'PY' 2>&1 || true
import sys
print(f"PYTHON_EXECUTABLE={sys.executable}")
print(f"PYTHON_VERSION={sys.version.split()[0]}")
for module in ("venv", "ensurepip", "mobsfscan", "semgrep", "libsast", "sarif_om"):
    try:
        imported = __import__(module)
        version = getattr(imported, "__version__", "UNKNOWN")
        print(f"PYTHON_MODULE_{module}=FOUND version={version}")
    except Exception as exc:
        print(f"PYTHON_MODULE_{module}=MISSING reason={type(exc).__name__}:{exc}")
PY

echo
echo "===== MOBSFSCAN CANDIDATES ====="
if [[ -d "$SABLE_MOBSFSCAN_SOURCE/.git" ]]; then
    echo "CANONICAL_MOBSFSCAN_SOURCE=$SABLE_MOBSFSCAN_SOURCE"
    echo "CANONICAL_MOBSFSCAN_COMMIT=$(git -C "$SABLE_MOBSFSCAN_SOURCE" rev-parse HEAD 2>/dev/null || true)"
else
    echo "CANONICAL_MOBSFSCAN_SOURCE=NONE"
fi
if [[ -x "$SABLE_MOBSFSCAN" ]]; then
    echo "CANONICAL_MOBSFSCAN_EXEC=$SABLE_MOBSFSCAN"
    "$SABLE_MOBSFSCAN" --version 2>&1 | sed 's/^/CANONICAL_MOBSFSCAN_VERSION=/'
else
    echo "CANONICAL_MOBSFSCAN_EXEC=NONE"
fi

if [[ -d "$CACHE_ROOT/mobsfscan-source/.git" ]]; then
    echo "LOCAL_CI_MOBSFSCAN_SOURCE=$CACHE_ROOT/mobsfscan-source"
    echo "LOCAL_CI_MOBSFSCAN_COMMIT=$(git -C "$CACHE_ROOT/mobsfscan-source" rev-parse HEAD 2>/dev/null || true)"
else
    echo "LOCAL_CI_MOBSFSCAN_SOURCE=NONE"
fi

shopt -s nullglob
venvs=("$CACHE_ROOT"/mobsfscan-venv-*)
shopt -u nullglob
if [[ "${#venvs[@]}" -eq 0 ]]; then
    echo "LOCAL_CI_MOBSFSCAN_VENVS=NONE"
else
    for venv in "${venvs[@]}"; do
        if [[ -x "$venv/bin/python" ]]; then
            echo "LOCAL_CI_MOBSFSCAN_VENV=FOUND path=$venv"
        else
            echo "LOCAL_CI_MOBSFSCAN_VENV=INCOMPLETE path=$venv"
        fi
    done
fi

echo
echo "===== LEGACY ROOTS ====="
for path in     /srv/data/sable-build/host-tools/r8-final-v1     "$HOME/.cargo/bin"     "$HOME/.local/bin"     /usr/local/bin
do
    if [[ -e "$path" ]]; then
        echo "LEGACY_OR_SYSTEM_PATH=EXISTS path=$path"
    else
        echo "LEGACY_OR_SYSTEM_PATH=ABSENT path=$path"
    fi
done

echo "SABLE_HOST_TOOL_AUDIT=COMPLETE"
