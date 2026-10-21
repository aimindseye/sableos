#!/usr/bin/env bash
# One build-only Titan2 Track B engineering pass from a unified Sable source checkout.
# Never flashes or grants product/image signing or IMS acceptance.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MODE="${1:---direct}"
[[ "$MODE" == --direct ]] || { echo 'TB2_BUILD=HOLD_USE_DIRECT_MODE'; exit 78; }
source "$ROOT/build/config/storage.env"
source "$ROOT/build/config/host-tools.env"
ANDROID="${SABLE_TB2_ANDROID_ROOT:-$SABLE_WORKSPACES_ROOT/titan2-track-b/android}"
[[ -f "$ANDROID/build/envsetup.sh" ]] || { echo "TB2_BUILD=HOLD_ANDROID_SOURCE_MISSING path=$ANDROID"; exit 66; }
[[ -x "$SABLE_JDK17/bin/java" && -d "$SABLE_ANDROID_SDK" ]] || { echo 'TB2_BUILD=HOLD_CANONICAL_JDK_SDK_MISSING'; exit 66; }
[[ "$SABLE_GRADLE_USER_HOME" == "$SABLE_HOST_TOOLS_ROOT/gradle" ]] || { echo 'TB2_BUILD=HOLD_NONCANONICAL_GRADLE_CACHE'; exit 78; }
JOBS="${SABLE_TB2_JOBS:-4}"
[[ "$JOBS" =~ ^([1-9]|1[0-6])$ ]] || { echo 'TB2_BUILD=HOLD_INVALID_JOBS'; exit 64; }
shopt -s nullglob
GRADLE_BINS=("$SABLE_GRADLE_USER_HOME"/wrapper/dists/gradle-8.14.3-bin/*/gradle-8.14.3/bin/gradle)
R8_GRADLE_BINS=("$SABLE_GRADLE_USER_HOME"/wrapper/dists/gradle-8.13-bin/*/gradle-8.13/bin/gradle)
((${#GRADLE_BINS[@]} == 1 && ${#R8_GRADLE_BINS[@]} == 1)) && [[ -x "${GRADLE_BINS[0]}" && -x "${R8_GRADLE_BINS[0]}" ]] || { echo 'TB2_BUILD=HOLD_PINNED_GRADLE_NOT_UNIQUE'; exit 66; }
export GRADLE_USER_HOME="$SABLE_GRADLE_USER_HOME" JAVA_HOME="$SABLE_JDK17"
export ANDROID_HOME="$SABLE_ANDROID_SDK" ANDROID_SDK_ROOT="$SABLE_ANDROID_SDK"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="${SABLE_TB2_BUILD_EVIDENCE_DIR:-$SABLE_EVIDENCE_ROOT/titan2/track-b-unified-build/$STAMP}"
[[ ! -e "$OUT" ]] || { echo "TB2_BUILD=HOLD_EXISTING_OUTPUT path=$OUT"; exit 78; }
mkdir -p "$OUT"
exec > >(tee "$OUT/integrated.log") 2>&1
printf 'TB2_BUILD=START_SOURCE_ONLY_NOT_FLASH_READY\n'
printf 'SABLE_SOURCE_COMMIT=%s\n' "$(git -C "$ROOT" rev-parse HEAD)"
printf 'ANDROID_ROOT=%s\n' "$ANDROID"
printf 'CANONICAL_GRADLE_HOME=%s\n' "$GRADLE_USER_HOME"
printf 'EVIDENCE_DIR=%s\n' "$OUT"
printf 'IMS_PROVIDER=UNQUALIFIED_SELECTED_PRODUCT_PENDING\n'
printf 'APP_INSTALL_GRAPH=UNQUALIFIED_SELECTED_PRODUCT_PENDING\n'
rc_ci=0; rc_titan=0; rc_r8=0; rc_aosp=0
# One run; capture every stage's result rather than stopping at the first independent failure.
bash "$ROOT/build/local-ci/run.sh" full > "$OUT/ci.log" 2>&1 || rc_ci=$?
echo "TB2_CI_EXIT=$rc_ci"
TITAN_TASKS=()
for mod in keyboard camera setup tools; do
  for task in assembleDebug testDebugUnitTest lint detekt ktlintCheck; do
    TITAN_TASKS+=(":$mod:$task")
  done
done
(
  cd "$ROOT/apps/titan2/platform" || exit 66
  "${GRADLE_BINS[0]}" --offline --no-daemon --console=plain --continue --max-workers="$JOBS" "${TITAN_TASKS[@]}"
) > "$OUT/titan2-gradle.log" 2>&1 || rc_titan=$?
echo "TB2_TITAN2_APPS_EXIT=$rc_titan"
R8_TASKS=()
for mod in hub messages calendar; do
  for task in assembleDebug testDebugUnitTest lint detekt ktlintCheck; do
    R8_TASKS+=(":$mod:$task")
  done
done
(
  cd "$ROOT/apps/r8/android" || exit 66
  "${R8_GRADLE_BINS[0]}" --offline --no-daemon --console=plain --continue --max-workers="$JOBS" "${R8_TASKS[@]}"
) > "$OUT/r8-gradle.log" 2>&1 || rc_r8=$?
echo "TB2_R8_APPS_EXIT=$rc_r8"
(
  cd "$ANDROID" || exit 66
  set +u # AOSP envsetup/lunch refer to optionally unset shell variables.
  source build/envsetup.sh || exit $?
  lunch treble_arm64_bvN-bp4a-userdebug || exit $?
  m -j"$JOBS" systemimage target-files-package otatools
) > "$OUT/aosp-image.log" 2>&1 || rc_aosp=$?
echo "TB2_AOSP_IMAGE_EXIT=$rc_aosp"
for name in ci titan2-gradle r8-gradle aosp-image; do
  [[ -f "$OUT/$name.log" ]] && sha256sum "$OUT/$name.log"
done
printf 'ci\t%s\ntitan2_gradle\t%s\nr8_gradle\t%s\naosp_image\t%s\n' "$rc_ci" "$rc_titan" "$rc_r8" "$rc_aosp" > "$OUT/EXIT_CODES.tsv"
sha256sum "$OUT/EXIT_CODES.tsv"
if ((rc_ci || rc_titan || rc_r8 || rc_aosp)); then
  echo 'TB2_BUILD=FAIL_INTEGRATED_BUILD_REVIEW_ALL_LOGS'
  exit 1
fi
echo 'TB2_BUILD=PASS_ENGINEERING_BUILD_ONLY_NO_Q25_IMS_OR_FLASH_QUALIFICATION'
