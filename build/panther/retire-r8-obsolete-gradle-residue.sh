#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SOURCE_MUTATION_AUTHORIZED="${SOURCE_MUTATION_AUTHORIZED:-NO}"

if [[ "$SOURCE_MUTATION_AUTHORIZED" != YES ]]; then
    echo "R8_OBSOLETE_GRADLE_RESIDUE=REFUSED_SOURCE_MUTATION_NOT_AUTHORIZED"
    exit 2
fi

[[ -d "$ROOT/.git" ]] || {
    echo "R8_OBSOLETE_GRADLE_RESIDUE=FAIL_NOT_GIT_REPO root=$ROOT"
    exit 3
}

echo "===== R8 OBSOLETE GRADLE MODULE RESIDUE RETIREMENT ====="
echo "SOURCE_MUTATION_AUTHORIZED=YES_EXACT_PATHS_ONLY"
echo "GENERAL_DELETE_AUTHORIZED=NO"

retired_paths=(
    "apps/r8/android/start-preview"
    "apps/r8/android/system-preview"
)

for rel in "${retired_paths[@]}"; do
    target="$ROOT/$rel"
    expected="$ROOT/$rel"

    [[ "$target" == "$expected" ]] || {
        echo "R8_OBSOLETE_GRADLE_RESIDUE=FAIL_PATH_MISMATCH path=$target"
        exit 4
    }

    tracked="$(git -C "$ROOT" ls-files -- "$rel")"
    if [[ -n "$tracked" ]]; then
        echo "R8_OBSOLETE_GRADLE_RESIDUE=FAIL_TRACKED_CONTENT path=$rel"
        printf '%s\n' "$tracked"
        exit 5
    fi

    if [[ -L "$target" ]]; then
        echo "R8_OBSOLETE_GRADLE_RESIDUE=FAIL_SYMLINK path=$rel"
        exit 6
    fi

    if [[ -e "$target" ]]; then
        [[ -d "$target" ]] || {
            echo "R8_OBSOLETE_GRADLE_RESIDUE=FAIL_NOT_DIRECTORY path=$rel"
            exit 7
        }

        echo "R8_OBSOLETE_GRADLE_RESIDUE_INVENTORY_BEGIN path=$rel"
        find "$target" -xdev -mindepth 1 -maxdepth 5 -print | sort
        echo "R8_OBSOLETE_GRADLE_RESIDUE_INVENTORY_END path=$rel"

        rm -rf --one-file-system -- "$target"

        [[ ! -e "$target" && ! -L "$target" ]] || {
            echo "R8_OBSOLETE_GRADLE_RESIDUE=FAIL_REMOVE path=$rel"
            exit 8
        }

        echo "R8_OBSOLETE_GRADLE_RESIDUE=REMOVED path=$rel"
    else
        echo "R8_OBSOLETE_GRADLE_RESIDUE=PASS_ABSENT path=$rel"
    fi
done

for rel in "${retired_paths[@]}"; do
    [[ ! -e "$ROOT/$rel" && ! -L "$ROOT/$rel" ]] || {
        echo "R8_OBSOLETE_GRADLE_RESIDUE=FAIL_POSTCHECK path=$rel"
        exit 9
    }
done

echo "R8_OBSOLETE_GRADLE_RESIDUE=PASS"
