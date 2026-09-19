#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SOURCE_COMMIT="${1:-}"
OUT="${2:-}"

[[ "$SOURCE_COMMIT" =~ ^[0-9a-f]{40}$ ]] || {
    echo "R8_DRIVER_RENDER=FAIL_SOURCE_COMMIT"
    exit 2
}
[[ -n "$OUT" ]] || {
    echo "R8_DRIVER_RENDER=FAIL_OUTPUT"
    exit 3
}

cat > "$OUT" <<EOF
#!/usr/bin/env bash
set -euo pipefail

EXPECTED_SOURCE_COMMIT="$SOURCE_COMMIT"
REPO="${SABLEOS_REPO:-/srv/data/sable-build/sableos/repo}"
SESSION="${SABLE_TMUX_SESSION:-sable-r8-panther}"

run_direct() {
    [[ -d "$REPO/.git" ]] || {
        echo "R8_DRIVER_REPO=FAIL path=$REPO"
        exit 10
    }

    actual="$(git -C "$REPO" rev-parse HEAD)"
    [[ "$actual" == "$EXPECTED_SOURCE_COMMIT" ]] || {
        echo "R8_DRIVER_SOURCE=FAIL expected=$EXPECTED_SOURCE_COMMIT actual=$actual"
        exit 11
    }

    exec env \
        EXPECTED_SOURCE_COMMIT="$EXPECTED_SOURCE_COMMIT" \
        SOURCE_MUTATION_AUTHORIZED=YES \
        BUILD_AUTHORIZED=YES \
        "$REPO/build/panther/run-r8-release-candidate.sh"
}

case "${1:---tmux}" in
    --direct)
        run_direct
        ;;
    --tmux)
        if tmux has-session -t "$SESSION" 2>/dev/null; then
            echo "R8_DRIVER_TMUX=FAIL_SESSION_EXISTS session=$SESSION"
            exit 12
        fi
        self="$(readlink -f "$0")"
        tmux new-session -d -s "$SESSION" \
            "bash -lc 'bash \"'$self'\" --direct; rc=\$?; echo; echo R8_BUILD_DRIVER_RC=\$rc; echo BUILD_DRIVER_EXITED=YES; exec bash'"
        echo "R8_DRIVER_TMUX=PASS session=$SESSION"
        echo "ATTACH=tmux attach -t $SESSION"
        ;;
    *)
        echo "usage: $0 [--tmux|--direct]"
        exit 64
        ;;
esac
EOF

chmod 0755 "$OUT"
bash -n "$OUT"

echo "R8_DRIVER_RENDER=PASS"
echo "R8_DRIVER_SOURCE_COMMIT=$SOURCE_COMMIT"
echo "R8_DRIVER_OUTPUT=$OUT"
