#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

RELEASE_VERSION="${1:-}"
MODE="${2:---tmux}"

usage() {
    echo "usage: bash build/panther/run-release.sh <release-version> [--tmux|--direct]" >&2
}

[[ -n "$RELEASE_VERSION" ]] || {
    usage
    exit 64
}
[[ "$RELEASE_VERSION" =~ ^[A-Za-z0-9._-]+$ ]] || {
    echo "SABLE_RELEASE_BUILD=FAIL_RELEASE_VERSION value=$RELEASE_VERSION"
    exit 64
}
case "$MODE" in
    --tmux|--direct) ;;
    *)
        usage
        exit 64
        ;;
esac

REPO="${SABLEOS_REPO:-/srv/data/sable-build/sableos/repo}"
[[ -d "$REPO/.git" ]] || {
    echo "SABLE_RELEASE_BUILD=FAIL_REPO path=$REPO"
    exit 2
}

SOURCE_COMMIT="${EXPECTED_SOURCE_COMMIT:-$(git -C "$REPO" rev-parse HEAD)}"
[[ "$SOURCE_COMMIT" =~ ^[0-9a-f]{40}$ ]] || {
    echo "SABLE_RELEASE_BUILD=FAIL_SOURCE_COMMIT value=$SOURCE_COMMIT"
    exit 3
}

actual="$(git -C "$REPO" rev-parse HEAD)"
[[ "$actual" == "$SOURCE_COMMIT" ]] || {
    echo "SABLE_RELEASE_BUILD=FAIL_SOURCE_IDENTITY expected=$SOURCE_COMMIT actual=$actual"
    exit 4
}

release_key="$(printf '%s' "$RELEASE_VERSION" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9._-' '-')"
SESSION="${SABLE_TMUX_SESSION:-sable-${release_key}-panther-${SOURCE_COMMIT:0:12}}"
AUTO_REGISTER="${SABLE_AUTO_REGISTER_ARTIFACT:-NO}"
case "$AUTO_REGISTER" in
    YES|NO) ;;
    *)
        echo "SABLE_RELEASE_BUILD=FAIL_AUTO_REGISTER value=$AUTO_REGISTER"
        exit 64
        ;;
esac

run_direct() {
    echo "===== SABLEOS CANONICAL RELEASE BUILD ====="
    echo "SABLEOS_RELEASE_VERSION=$RELEASE_VERSION"
    echo "SOURCE_COMMIT=$SOURCE_COMMIT"
    echo "ENTRYPOINT=build/panther/run-release.sh"
    echo "RELEASE_SPECIFIC_BUILD_SCRIPT=NO"
    echo "CUSTOM_TMP_DRIVER=NO"

    exec env \
        SABLEOS_RELEASE_VERSION="$RELEASE_VERSION" \
        EXPECTED_SOURCE_COMMIT="$SOURCE_COMMIT" \
        SOURCE_MUTATION_AUTHORIZED=YES \
        BUILD_AUTHORIZED=YES \
        bash "$ROOT/build/panther/run-r8-release-candidate.sh"
}

if [[ "$MODE" == "--direct" ]]; then
    run_direct
fi

if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "SABLE_RELEASE_BUILD=FAIL_SESSION_EXISTS session=$SESSION"
    exit 5
fi

self="$ROOT/build/panther/run-release.sh"
tmux new-session -d -s "$SESSION" \
    "SABLE_AUTO_REGISTER_ARTIFACT='$AUTO_REGISTER' EXPECTED_SOURCE_COMMIT='$SOURCE_COMMIT' bash '$self' '$RELEASE_VERSION' --direct; rc=\$?; echo; echo SABLE_RELEASE_BUILD_RC=\$rc; echo BUILD_DRIVER_EXITED=YES; exec bash"

echo "SABLE_RELEASE_BUILD=PASS_STARTED"
echo "SABLEOS_RELEASE_VERSION=$RELEASE_VERSION"
echo "SOURCE_COMMIT=$SOURCE_COMMIT"
echo "SESSION=$SESSION"
echo "ATTACH=tmux attach -t $SESSION"
