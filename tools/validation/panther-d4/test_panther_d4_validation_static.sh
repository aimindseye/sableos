#!/usr/bin/env bash
set -euo pipefail

DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
WRAPPER="$DIR/run_sablectl_b2_smoke.sh"
R10R3="$DIR/PANTHER_P1B_D4_B2B2R10R3_preserved_data_flash_execution.sh"
CORRUPT="$DIR/archive/PANTHER_P1B_D4_B2B2R10R3_preserved_data_flash_execution.corrupt"

bash -n "$WRAPPER"
grep -Fq 'panther-target_files.zip' "$WRAPPER"
if grep -Fq 'panther-target-files.zip' "$WRAPPER"; then
  echo 'CANONICAL_TARGET_FILES_FILENAME=FAIL' >&2
  exit 1
fi

bash -n "$R10R3"

set +e
r10r3_output="$("$R10R3" 2>&1)"
r10r3_rc=$?
set -e

[[ "$r10r3_rc" -eq 64 ]] || {
  echo "R10R3_FAIL_CLOSED_STUB=FAIL rc=$r10r3_rc" >&2
  exit 1
}
grep -Fq 'PANTHER_D4_R10R3_HISTORICAL_EXECUTION=UNAVAILABLE_ARCHIVE_CORRUPT' <<<"$r10r3_output"
grep -Fq 'PANTHER_D4_R10R3_CURRENT_VALIDATION=USE_SABLECTL_AND_REVIEWED_DEPLOYMENT_TOOLING' <<<"$r10r3_output"

[[ -f "$CORRUPT" ]] || {
  echo 'R10R3_CORRUPT_ARCHIVE=FAIL_MISSING' >&2
  exit 1
}

corrupt_blob="$(git -C "$DIR" hash-object "$CORRUPT")"
[[ "$corrupt_blob" == 'c1e600a98b3dc285a585d8098d426f8a236a27d8' ]] || {
  echo "R10R3_CORRUPT_ARCHIVE=FAIL_BLOB expected=c1e600a98b3dc285a585d8098d426f8a236a27d8 actual=$corrupt_blob" >&2
  exit 1
}

(
  cd "$DIR"
  sha256sum -c SHA256SUMS
)

echo 'CANONICAL_TARGET_FILES_FILENAME=PASS'
echo 'R10R3_FAIL_CLOSED_STUB=PASS'
echo 'R10R3_CORRUPT_ARCHIVE_BLOB=PASS'
echo 'PANTHER_D4_VALIDATION_STATIC=PASS'
