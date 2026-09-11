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
  build/panther/build-sablestart.sh
  src/android/packages/apps/SableStart/Android.bp
  src/android/packages/apps/SableStart/AndroidManifest.xml
)

for rel in "${required[@]}"; do
    test -f "$ROOT/$rel" || { echo "MISSING=$rel"; exit 1; }
done

for sh in "$ROOT"/build/*.sh "$ROOT"/build/panther/*.sh "$ROOT"/build/gates/*.sh "$ROOT"/tests/sablestart/host/*.sh "$ROOT"/tests/sablestart/device/*.sh; do
    test -f "$sh" || continue
    bash -n "$sh"
done

python3 - "$ROOT/src/android/packages/apps/SableStart/AndroidManifest.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
ET.parse(sys.argv[1])
PY

echo "SABLEOS_REPO_LAYOUT=PASS"
