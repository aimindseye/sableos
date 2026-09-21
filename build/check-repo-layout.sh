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
  src/android/packages/apps/SableStart/src/com/sable/start/live/LiveSurfaceModels.kt
  src/android/packages/apps/SableStart/src/com/sable/start/model/AppEntry.kt
  src/android/packages/apps/SableStart/src/com/sable/start/platform/LiveSurfaceRepository.kt
  src/android/packages/apps/SableStart/src/com/sable/start/platform/SableAppearanceProvider.kt
  src/android/packages/apps/SableStart/src/com/sable/start/platform/StartStateRepository.kt
  src/android/packages/apps/SableStart/src/com/sable/start/ui/SableStartScreen.kt
)

for rel in "${required[@]}"; do
    test -f "$ROOT/$rel" || { echo "MISSING=$rel"; exit 1; }
done

retired_sablestart=(
  build/panther/build-sablestart.sh
  src/android/packages/apps/SableStart/AndroidManifest.xml
  src/android/packages/apps/SableStart/res/values/strings.xml
  src/android/packages/apps/SableStart/rust/src/lib.rs
  src/android/packages/apps/SableStart/src/com/sable/start/SableStartActivity.kt
  src/android/packages/apps/SableStart/src/com/sable/start/bridge/SableStartNative.kt
  src/android/packages/apps/SableStart/src/com/sable/start/platform/LauncherAppsRepository.kt
)

for rel in "${retired_sablestart[@]}"; do
    if [[ -e "$ROOT/$rel" ]]; then
        echo "SABLEOS_REPO_LAYOUT=FAIL_RETIRED_SABLESTART_SOURCE path=$rel"
        exit 1
    fi
done

grep -Fq 'name: "sable_start_presentation_srcs"'     "$ROOT/src/android/packages/apps/SableStart/Android.bp"
if grep -Fq 'android_app {'     "$ROOT/src/android/packages/apps/SableStart/Android.bp"
then
    echo "SABLEOS_REPO_LAYOUT=FAIL_STANDALONE_SABLESTART_APP_MODULE"
    exit 1
fi

grep -Fq 'AndroidManifest.xml'     "$ROOT/build/panther/sync-sablestart.sh"
grep -Fq 'retired=('     "$ROOT/build/panther/sync-sablestart.sh"

echo "R9_STANDALONE_SABLESTART_BUILD_ENTRYPOINT=PASS_ABSENT"
echo "R9_STANDALONE_SABLESTART_MANIFEST=PASS_ABSENT"
echo "R9_SABLESTART_PRESENTATION_FILEGROUP=PASS"
echo "R9_LAUNCHER3_HOSTED_SABLESTART_LAYOUT=PASS"

for sh in "$ROOT"/build/*.sh "$ROOT"/build/panther/*.sh "$ROOT"/build/gates/*.sh "$ROOT"/tests/sablestart/host/*.sh "$ROOT"/tests/sablestart/device/*.sh; do
    test -f "$sh" || continue
    bash -n "$sh"
done

echo "SABLEOS_REPO_LAYOUT=PASS"
