#!/usr/bin/env bash
set -euo pipefail

DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
WRAPPER="$DIR/run_sablectl_b2_smoke.sh"

bash -n "$WRAPPER"
grep -Fq 'panther-target_files.zip' "$WRAPPER"
if grep -Fq 'panther-target-files.zip' "$WRAPPER"; then
  echo 'CANONICAL_TARGET_FILES_FILENAME=FAIL' >&2
  exit 1
fi

echo 'CANONICAL_TARGET_FILES_FILENAME=PASS'
echo 'PANTHER_D4_VALIDATION_STATIC=PASS'
