#!/usr/bin/env bash
set -euo pipefail

WS="${WS:-/srv/data/sableos_panther_graphene_2026081300_workspace}"
TARGET_FILES="${TARGET_FILES:-$WS/out_d4_b2_final/target/product/panther/obj/PACKAGING/target_files_intermediates/panther-target-files.zip}"
SABLECTL="${SABLECTL:-sablectl}"
EXPECTED_SLOT="${EXPECTED_SLOT:-b}"
BASELINE="${BASELINE:-}"

[[ -f "$TARGET_FILES" ]] || {
  echo "GATE_ERROR=TARGET_FILES_MISSING path=$TARGET_FILES" >&2
  exit 33
}

args=(
  smoke
  --target-files "$TARGET_FILES"
  --expected-device panther
  --expected-slot "$EXPECTED_SLOT"
  --hash-container
)

if [[ -n "$BASELINE" ]]; then
  [[ -f "$BASELINE" ]] || {
    echo "GATE_ERROR=BASELINE_MISSING path=$BASELINE" >&2
    exit 33
  }
  args+=(--baseline "$BASELINE")
fi

exec "$SABLECTL" "${args[@]}"
