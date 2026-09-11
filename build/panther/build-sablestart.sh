#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$REPO_ROOT/build/config/panther-grapheneos-2026081300.env"

BUILD_AUTHORIZED="${BUILD_AUTHORIZED:-NO}"
if [[ "$BUILD_AUTHORIZED" != YES ]]; then
    echo "Refusing build. Set BUILD_AUTHORIZED=YES explicitly."
    exit 2
fi

mkdir -p "$SABLEOS_OUT" "$SABLEOS_EVIDENCE"
cd "$SABLEOS_UPSTREAM"
source build/envsetup.sh

export OUT_DIR="$SABLEOS_OUT"
export SOONG_INCREMENTAL_ANALYSIS=false
lunch "$SABLEOS_LUNCH_TARGET"

LOG="$SABLEOS_EVIDENCE/SableStart-$(date +%Y%m%d_%H%M%S).log"
set +e
m -j"${JOBS:-$(nproc)}" SableStart 2>&1 | tee "$LOG"
rc=${PIPESTATUS[0]}
set -e

echo "BUILD_LOG=$LOG"
echo "BUILD_RC=$rc"
exit "$rc"
