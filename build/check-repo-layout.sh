#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

required=(
  CURRENT_STATUS.md
  docs/BUILD_LAYOUT.md
  docs/PORTABLE_DEVELOPMENT.md
  docs/MAINLINE_POLICY.md
  build/config/panther-grapheneos-2026081300.env
  build/panther/bootstrap.sh
  build/panther/sync-sablestart.sh
  build/panther/prepare-r8-final-ui.sh
  build/panther/build-r8-final-ui.sh
  build/panther/qualify-r9-physical-ux.sh
  patches/android-17-grapheneos-2026081300/apply_r9_launcher3_foundation.py
  patches/android-17-grapheneos-2026081300/r9_launcher3/SableQuickstepLauncher.kt
  src/android/packages/apps/SableStart/Android.bp
  src/android/packages/apps/SableStart/AndroidManifest.xml
)

for rel in "${required[@]}"; do
    test -f "$ROOT/$rel" || { echo "MISSING=$rel"; exit 1; }
done

if [[ -e "$ROOT/build/panther/build-sablestart.sh" ]]; then
    echo "SABLEOS_REPO_LAYOUT=FAIL_OBSOLETE_STANDALONE_SABLESTART_BUILD"
    exit 1
fi

echo "R9_STANDALONE_SABLESTART_BUILD_ENTRYPOINT=PASS_ABSENT"
echo "R9_LAUNCHER3_HOSTED_SABLESTART_LAYOUT=PASS"

for sh in "$ROOT"/build/*.sh "$ROOT"/build/panther/*.sh "$ROOT"/build/gates/*.sh "$ROOT"/tests/sablestart/host/*.sh "$ROOT"/tests/sablestart/device/*.sh; do
    test -f "$sh" || continue
    bash -n "$sh"
done

python3 - "$ROOT/src/android/packages/apps/SableStart/AndroidManifest.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
ET.parse(sys.argv[1])
PY

echo "SABLEOS_REPO_LAYOUT=PASS"
