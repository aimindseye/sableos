#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
WS="${WS:-/srv/data/sableos/upstream/panther/grapheneos-2026081300}"
OUT="${OUT:-/tmp/SABLE_METRO_R3_REPO_UNIT_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$OUT"

KOTLINC="${KOTLINC:-$WS/external/kotlinc/bin/kotlinc}"
MODELS="$ROOT/src/android/packages/apps/SableStart/src/com/sable/start/live/LiveSurfaceModels.kt"
TESTS="$ROOT/tests/sablestart/host/LiveSurfaceModelsTest.kt"

echo "===== SABLE METRO R3 REPOSITORY HOST UNIT TESTS ====="
echo "APP_BUILD_AUTHORIZED=NO"
echo "TMP_TEST_OUTPUT_AUTHORIZED=YES"
echo "KOTLINC=$KOTLINC"

if [[ ! -x "$KOTLINC" ]]; then
    echo "SABLE_METRO_R3_KOTLINC=BLOCKED"
    exit 3
fi

"$KOTLINC" "$MODELS" "$TESTS" -include-runtime -d "$OUT/tests.jar" > "$OUT/compile.txt" 2>&1

echo "SABLE_METRO_R3_UNIT_COMPILE=PASS"
java -jar "$OUT/tests.jar" | tee "$OUT/test-output.txt"

sha256sum "$OUT/tests.jar" "$OUT/compile.txt" "$OUT/test-output.txt" > "$OUT/SHA256SUMS.txt"
sha256sum "$OUT/SHA256SUMS.txt"
