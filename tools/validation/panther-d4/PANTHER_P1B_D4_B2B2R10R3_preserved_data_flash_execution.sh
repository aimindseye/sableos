#!/usr/bin/env bash
set -euo pipefail

# Historical Panther D4 R10R3 execution harness archive.
#
# The originally checked-in executable blob is corrupted and is preserved
# byte-for-byte at:
#   tools/validation/panther-d4/archive/
#     PANTHER_P1B_D4_B2B2R10R3_preserved_data_flash_execution.corrupt
#
# Do not reconstruct or execute a write-capable flash harness from damaged
# archival bytes. Current validation belongs in tools/sablectl/ plus separately
# reviewed deployment tooling.

echo "PANTHER_D4_R10R3_HISTORICAL_EXECUTION=UNAVAILABLE_ARCHIVE_CORRUPT" >&2
echo "PANTHER_D4_R10R3_CURRENT_VALIDATION=USE_SABLECTL_AND_REVIEWED_DEPLOYMENT_TOOLING" >&2
exit 64
