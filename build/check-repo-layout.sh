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
  build/panther/qualify-r9-launcher3-foundation.sh
  build/gates/r9-launcher3-foundation-contract.py
  patches/android-17-grapheneos-2026081300/apply_r9_launcher3_foundation.py
  src/android/packages/apps/SableStart/Android.bp
  apps/r8/android/sablestart-production-check/src/main/AndroidManifest.xml
)

for rel in "${required[@]}"; do
    test -f "$ROOT/$rel" || { echo "MISSING=$rel"; exit 1; }
done

for sh in "$ROOT"/build/*.sh "$ROOT"/build/panther/*.sh "$ROOT"/build/gates/*.sh "$ROOT"/tests/sablestart/host/*.sh "$ROOT"/tests/sablestart/device/*.sh; do
    test -f "$sh" || continue
    bash -n "$sh"
done

python3 - "$ROOT/apps/r8/android/sablestart-production-check/src/main/AndroidManifest.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
ET.parse(sys.argv[1])
PY

python3 "$ROOT/patches/android-17-grapheneos-2026081300/apply_r9_launcher3_foundation.py" --self-test
python3 "$ROOT/build/gates/r9-launcher3-foundation-contract.py" --self-test

echo "SABLEOS_REPO_LAYOUT=PASS"
