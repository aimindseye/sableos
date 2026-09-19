#!/usr/bin/env bash
set -euo pipefail

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

cat > "$OUT" <<'DRIVER'
#!/usr/bin/env bash
set -euo pipefail

EXPECTED_SOURCE_COMMIT="@@SOURCE_COMMIT@@"
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
            "bash \"$self\" --direct; rc=\$?; echo; echo R8_BUILD_DRIVER_RC=\$rc; echo BUILD_DRIVER_EXITED=YES; exec bash"

        echo "R8_DRIVER_TMUX=PASS session=$SESSION"
        echo "ATTACH=tmux attach -t $SESSION"
        ;;
    *)
        echo "usage: $0 [--tmux|--direct]"
        exit 64
        ;;
esac
DRIVER

python3 - "$OUT" "$SOURCE_COMMIT" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
commit = sys.argv[2]
text = path.read_text()
count = text.count("@@SOURCE_COMMIT@@")
if count != 1:
    raise SystemExit(f"R8_DRIVER_RENDER=FAIL_TOKEN_COUNT count={count}")
path.write_text(text.replace("@@SOURCE_COMMIT@@", commit))
PY

chmod 0755 "$OUT"
bash -n "$OUT"

grep -Fq "EXPECTED_SOURCE_COMMIT=\"$SOURCE_COMMIT\"" "$OUT"
! grep -Fq '@@SOURCE_COMMIT@@' "$OUT"

echo "R8_DRIVER_RENDER=PASS"
echo "R8_DRIVER_SOURCE_COMMIT=$SOURCE_COMMIT"
echo "R8_DRIVER_OUTPUT=$OUT"
