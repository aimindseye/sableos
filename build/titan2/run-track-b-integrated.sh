#!/usr/bin/env bash
# One build-only Titan2 Track B engineering pass from a unified Sable source checkout.
# Never flashes or grants product/image signing or IMS acceptance.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MODE="${1:---direct}"
[[ "$MODE" == --direct ]] || { echo 'TB2_BUILD=HOLD_USE_DIRECT_MODE'; exit 78; }
# Next-build source convergence gate: no full AOSP build from partial Q25/IMS work.
# This exists only on the dedicated next-build branch, not the running PR346 commit.
python3 "$ROOT/build/titan2/nextbuild/check-ready.py" --require-ready || {
  echo 'TB2_BUILD=HOLD_Q25_IMS_SOURCE_COMPLETION_BEFORE_COMPILATION'
  exit 78
}
source "$ROOT/build/config/storage.env"
source "$ROOT/build/config/host-tools.env"
ANDROID="${SABLE_TB2_ANDROID_ROOT:-$SABLE_WORKSPACES_ROOT/titan2-track-b/android}"
[[ -f "$ANDROID/build/envsetup.sh" ]] || { echo "TB2_BUILD=HOLD_ANDROID_SOURCE_MISSING path=$ANDROID"; exit 66; }
[[ -x "$SABLE_JDK17/bin/java" && -d "$SABLE_ANDROID_SDK" ]] || { echo 'TB2_BUILD=HOLD_CANONICAL_JDK_SDK_MISSING'; exit 66; }
[[ "$SABLE_GRADLE_USER_HOME" == "$SABLE_HOST_TOOLS_ROOT/gradle" ]] || { echo 'TB2_BUILD=HOLD_NONCANONICAL_GRADLE_CACHE'; exit 78; }
JOBS="${SABLE_TB2_JOBS:-4}"
[[ "$JOBS" =~ ^([1-9]|1[0-6])$ ]] || { echo 'TB2_BUILD=HOLD_INVALID_JOBS'; exit 64; }
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
printf 'IMS_SOURCE_SELECTION=PhhIms_Iwlan_FLOSS_SELECTED_RUNTIME_UNQUALIFIED\n'
printf 'APP_SOURCE_SELECTION=13_TB2Sable_MODULES_IMAGE_UNQUALIFIED\n'
rc_ci=0; rc_stage=78; rc_aosp=78
# Full canonical CI includes all R8 app builds, lint, Detekt, ktlint, and TB2 Titan modules.
SABLEOS_DEVICE=titan2 SABLEOS_RELEASE_VERSION=TB2 bash "$ROOT/build/local-ci/run.sh" full > "$OUT/ci.log" 2>&1 || rc_ci=$?
echo "TB2_CI_EXIT=$rc_ci"
if ((rc_ci == 0)); then
  rc_stage=0
  # Full build consumes source convergence; it does NOT mutate the Android tree.
  bash "$ROOT/build/titan2/stage-track-b-product.sh" --plan > "$OUT/product-stage.log" 2>&1 || rc_stage=$?
  if ((rc_stage == 0)); then
    if ! grep -Fxq 'PRODUCT_PACKAGES += SableLauncher' "$ANDROID/device/phh/treble/rom.mk" ||
       [[ ! -f "$ANDROID/packages/apps/SableStart/Android.bp" ]] ||
       [[ ! -f "$ANDROID/packages/apps/SableDesign/Android.bp" ]]; then
      echo 'TB2_PRODUCT=HOLD_SOURCE_CONVERGENCE_NOT_APPLIED' >> "$OUT/product-stage.log"
      rc_stage=78
    fi
  fi
else
  printf 'TB2_PRODUCT=SKIP_CANONICAL_CI_FAILED\n' > "$OUT/product-stage.log"
fi
echo "TB2_PRODUCT_STAGE_EXIT=$rc_stage"
if ((rc_stage == 0)); then
(
  cd "$ANDROID" || exit 66
  set +u # AOSP envsetup/lunch refer to optionally unset shell variables.
  source build/envsetup.sh || exit $?
  lunch treble_arm64_bvN-bp4a-userdebug || exit $?
  m -j"$JOBS" systemimage target-files-package otatools
) > "$OUT/aosp-image.log" 2>&1 || rc_aosp=$?
else
  printf 'TB2_AOSP_IMAGE=SKIP_UNQUALIFIED_PRODUCT_STAGE\n' > "$OUT/aosp-image.log"
fi
echo "TB2_AOSP_IMAGE_EXIT=$rc_aosp"
for name in ci product-stage aosp-image; do
  [[ -f "$OUT/$name.log" ]] && sha256sum "$OUT/$name.log"
done
printf 'ci\t%s\nproduct_stage\t%s\naosp_image\t%s\n' "$rc_ci" "$rc_stage" "$rc_aosp" > "$OUT/EXIT_CODES.tsv"
sha256sum "$OUT/EXIT_CODES.tsv"
if ((rc_ci || rc_stage || rc_aosp)); then
  echo 'TB2_BUILD=FAIL_INTEGRATED_BUILD_REVIEW_ALL_LOGS'
  exit 1
fi
echo 'TB2_BUILD=PASS_ENGINEERING_BUILD_ONLY_NO_Q25_IMS_OR_FLASH_QUALIFICATION'
