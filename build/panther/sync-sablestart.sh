#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$REPO_ROOT/build/config/panther-grapheneos-2026081300.env"

SOURCE_MUTATION_AUTHORIZED="${SOURCE_MUTATION_AUTHORIZED:-NO}"
if [[ "$SOURCE_MUTATION_AUTHORIZED" != YES ]]; then
    echo "Refusing upstream source mutation. Set SOURCE_MUTATION_AUTHORIZED=YES explicitly."
    exit 2
fi

SRC="$REPO_ROOT/src/android/packages/apps/SableStart"
DST="$SABLEOS_UPSTREAM/$SABLEOS_SABLESTART_REL"

required=(
  Android.bp
  AndroidManifest.xml
  res/values/strings.xml
  rust/src/lib.rs
  src/com/sable/start/SableStartActivity.kt
  src/com/sable/start/bridge/SableStartNative.kt
  src/com/sable/start/model/AppEntry.kt
  src/com/sable/start/platform/LauncherAppsRepository.kt
  src/com/sable/start/platform/LiveSurfaceRepository.kt
  src/com/sable/start/platform/StartStateRepository.kt
  src/com/sable/start/live/LiveSurfaceModels.kt
  src/com/sable/start/ui/SableStartScreen.kt
)

missing=0
for rel in "${required[@]}"; do
    if [[ ! -f "$SRC/$rel" ]]; then
        echo "MISSING_CANONICAL_SOURCE=$rel"
        missing=1
    fi
done

if [[ $missing -ne 0 ]]; then
    echo "SABLESTART_PORTABLE_SNAPSHOT=INCOMPLETE"
    exit 3
fi

mkdir -p "$DST"
rsync -a --delete \
  --exclude='/PORTABILITY_STATUS.md' \
  --exclude='/SHA256SUMS.txt' \
  "$SRC/" "$DST/"

echo "SABLESTART_SYNC=PASS"
echo "SOURCE=$SRC"
echo "DESTINATION=$DST"
