#!/usr/bin/env bash
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    echo "SABLESTART_SYNC=REFUSED_SOURCED_SCRIPT" >&2
    echo "Run with: bash ${BASH_SOURCE[0]}" >&2
    return 64
fi
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$REPO_ROOT/build/config/r8-release.env"
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
  src/com/sable/start/live/LiveSurfaceModels.kt
  src/com/sable/start/model/AppEntry.kt
  src/com/sable/start/platform/LiveSurfaceRepository.kt
  src/com/sable/start/platform/StartStateRepository.kt
  src/com/sable/start/ui/SableStartScreen.kt
  src/com/sable/start/ui/SableGlyphIcon.kt
)

retired=(
  AndroidManifest.xml
  res/values/strings.xml
  rust/src/lib.rs
  src/com/sable/start/SableStartActivity.kt
  src/com/sable/start/bridge/SableStartNative.kt
  src/com/sable/start/platform/LauncherAppsRepository.kt
  src/com/sable/start/platform/SableAppearanceProvider.kt
)

missing=0
for rel in "${required[@]}"; do
    if [[ ! -f "$SRC/$rel" ]]; then
        echo "MISSING_CANONICAL_PRESENTATION_SOURCE=$rel"
        missing=1
    fi
done

if [[ $missing -ne 0 ]]; then
    echo "SABLESTART_PRESENTATION_SNAPSHOT=INCOMPLETE"
    exit 3
fi

for rel in "${retired[@]}"; do
    if [[ -e "$SRC/$rel" ]]; then
        echo "SABLESTART_RETIRED_SOURCE_PRESENT=FAIL path=$rel"
        exit 4
    fi
done

mkdir -p "$DST"
rsync -a --delete   --exclude='/PORTABILITY_STATUS.md'   --exclude='/SHA256SUMS.txt'   "$SRC/" "$DST/"

for rel in "${retired[@]}"; do
    if [[ -e "$DST/$rel" ]]; then
        echo "SABLESTART_WORKSPACE_RETIRED_SOURCE_PRESENT=FAIL path=$rel"
        exit 5
    fi
done

echo "SABLESTART_PRESENTATION_SYNC=PASS"
echo "R9_SABLESTART_APPEARANCE_PROVIDER=PASS_RETIRED"
echo "R9_SABLESTART_GLOBAL_APPEARANCE_OWNER=SETTINGS"
echo "SABLESTART_STANDALONE_RUNTIME=PASS_ABSENT"
echo "SOURCE=$SRC"
echo "DESTINATION=$DST"
