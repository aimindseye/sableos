#!/usr/bin/env bash
# Track B Android16 single-source convergence: reuse selected 13 APKs + FLOSS IMS.
# Never builds, flashes, signs, downloads, or replaces historical product modules.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ANDROID="${SABLE_TB2_ANDROID_ROOT:-/srv/sable-build/workspaces/titan2-track-b/android}"
MODE="${1:---plan}"
[[ "$MODE" == --plan || "$MODE" == --apply ]] || { echo 'TB2_CONVERGENCE=HOLD_MODE'; exit 64; }
[[ -f "$ANDROID/build/envsetup.sh" ]] || { echo 'TB2_CONVERGENCE=HOLD_AOSP_ROOT'; exit 66; }
[[ -d "$ROOT/src/android/packages/apps/SableStart" && -d "$ROOT/src/android/shared/sabledesign" ]] || {
  echo 'TB2_CONVERGENCE=HOLD_SABLE_LAUNCHER_SOURCE'; exit 66;
}
ROM="$ANDROID/device/phh/treble/rom.mk"
BP="$ANDROID/vendor/sable/tb2-rebuilt/Android.bp"
APPS="$ANDROID/vendor/sable/tb2-rebuilt/tb2-apps.mk"
FLOSS="$ANDROID/vendor/sable/trackb13ims/track-b.mk"
IMS_XML="$ANDROID/vendor/sable/trackb13ims/privapp-permissions-me.phh.ims.xml"
LAUNCHER="$ANDROID/packages/apps/Launcher3/AndroidManifest.xml"
PATCH="$ROOT/build/titan2/track-b-source/launcher3-home-removal-a16.patch"
for file in "$ROM" "$BP" "$APPS" "$FLOSS" "$IMS_XML" "$LAUNCHER" "$PATCH"; do
  [[ -f "$file" && ! -L "$file" ]] || { echo "TB2_CONVERGENCE=HOLD_FILE path=$file"; exit 66; }
done
# Bind exact supplied host contents. A stale/mutated product must be investigated,
# not blindly made to match the last manifest.
check_pin() {
  local file="$1" wanted="$2" actual
  actual="$(sha256sum "$file")"; actual="${actual%% *}"
  [[ "$actual" == "$wanted" ]] || { echo "TB2_CONVERGENCE=HOLD_PIN path=$file sha=$actual"; exit 78; }
}
check_pin "$APPS" 8264edf7985b9aa1f62e36acbdd0d07767834705c6aee8680cd733e9232c6e7f
check_pin "$BP" ab2b0654ee4b560aa1b741af913898c2d22d6963d33fbf78899f399e2fffd717
check_pin "$FLOSS" 4146c78c7f4963a971117bb25003b62a294b550beff93eb124742b3fd0f1d97b
check_pin "$IMS_XML" 6ccb15dcc39495a2c2688871f84d7368871805e08b1d02823c77af09720bcba7
check_pin "$PATCH" 72df02669cda5b36b95319219cdae54f0bfb415830c89b17648a47e59f11fc04
BASE_ROM=0c654060c57fc1b639d670164055aeffa231441a595310b2f45f7badb0ba66cb
HOME_LINE='PRODUCT_PACKAGES += SableLauncher'
if grep -Fxq "$HOME_LINE" "$ROM"; then
  grep -Fxq '$(call inherit-product, vendor/sable/trackb13ims/track-b.mk)' "$ROM" || exit 78
  grep -Fxq '$(call inherit-product, vendor/sable/tb2-rebuilt/tb2-product.mk)' "$ROM" || exit 78
else
  check_pin "$ROM" "$BASE_ROM"
fi
[[ "$(grep -Fc 'vendor/sable/trackb13ims/track-b.mk' "$ROM")" -eq 1 &&
   "$(grep -Fc 'vendor/sable/tb2-rebuilt/tb2-product.mk' "$ROM")" -eq 1 ]] || {
  echo 'TB2_CONVERGENCE=HOLD_EXISTING_INHERITS'; exit 78;
}
# Source selection, not APK runtime qualification: exactly 13 product imports.
mapfile -t app_names < <(sed -n 's/^[[:space:]]*\(TB2Sable[A-Za-z0-9]*\)[[:space:]]*\\\{0,1\}[[:space:]]*$/\1/p' "$APPS" | LC_ALL=C sort)
[[ "${#app_names[@]}" -eq 13 ]] || { echo "TB2_CONVERGENCE=HOLD_APP_COUNT count=${#app_names[@]}"; exit 78; }
for name in "${app_names[@]}"; do
  [[ "$(grep -Fc "name: \"$name\"" "$BP")" -eq 1 ]] || {
    echo "TB2_CONVERGENCE=HOLD_BP_MODULE name=$name"; exit 78;
  }
  [[ -s "$ANDROID/vendor/sable/tb2-rebuilt/prebuilt/$name.apk" ]] || {
    echo "TB2_CONVERGENCE=HOLD_PREBUILT name=$name"; exit 78;
  }
done
for ims_module in PhhIms PhhImsOverlay Iwlan QualifiedNetworksService; do
  grep -Eq "^[[:space:]]+$ims_module[[:space:]\\]*$" "$FLOSS" || {
    echo "TB2_CONVERGENCE=HOLD_FLOSS_MODULE name=$ims_module"; exit 78;
  }
done
[[ $(grep -Fc 'privapp-permissions package="me.phh.ims"' "$IMS_XML") -eq 1 ]] || exit 78
# No automatic stage of OEM C1 or alternative TrackBSable/SableTB2 modules.
for dir_pair in \
  'src/android/packages/apps/SableStart:packages/apps/SableStart' \
  'src/android/shared/sabledesign:packages/apps/SableDesign'; do
  source_dir="$ROOT/${dir_pair%%:*}"
  dest_dir="$ANDROID/${dir_pair#*:}"
  while IFS= read -r -d '' source_file; do
    rel="${source_file#"$source_dir"/}"
    dest_file="$dest_dir/$rel"
    [[ ! -L "$source_file" && ! -L "$dest_file" ]] || { echo 'TB2_CONVERGENCE=HOLD_SOURCE_SYMLINK'; exit 78; }
    if [[ -e "$dest_file" ]]; then
      cmp -s "$source_file" "$dest_file" || {
        echo "TB2_CONVERGENCE=HOLD_AOSP_SOURCE_DRIFT path=$dest_file"; exit 78;
      }
    fi
  done < <(find "$source_dir" -type f -print0 | LC_ALL=C sort -z)
done
if grep -Fq 'android.intent.category.HOME' "$LAUNCHER"; then
  check_pin "$LAUNCHER" 3bcd0ddf69493f117668cdcfe82fd32a2fcb0162d062cae1ac87ccfaa5f0a919
  ( cd "$ANDROID" && git -C packages/apps/Launcher3 apply -p4 --check "$PATCH" ) || {
    echo 'TB2_CONVERGENCE=HOLD_LAUNCHER_PATCH_CONTEXT'; exit 78;
  }
else
  # Idempotence: another edit with HOME removed is not automatically admitted.
  check_pin "$LAUNCHER" 904faa32569da62de2f1c2ed774da2f2fc7d3920268720139ada1467cdf72c41
  echo 'TB2_CONVERGENCE=LAUNCHER_HOME_ALREADY_REMOVED_REVIEW_COMMIT'
fi
if [[ "$MODE" == --plan ]]; then
  echo 'TB2_CONVERGENCE=PASS_EXACT_SOURCE_PREFLIGHT_NO_WRITES'
  echo 'TB2_PRODUCT=REUSE_EXISTING_13_TB2Sable_AND_FLOSS_PHHiMS'
  exit 0
fi
# All source conflicts and original content pins were checked before mutation.
for dir_pair in \
  'src/android/packages/apps/SableStart:packages/apps/SableStart' \
  'src/android/shared/sabledesign:packages/apps/SableDesign'; do
  source_dir="$ROOT/${dir_pair%%:*}"
  dest_dir="$ANDROID/${dir_pair#*:}"
  while IFS= read -r -d '' source_file; do
    rel="${source_file#"$source_dir"/}"
    dest_file="$dest_dir/$rel"
    if [[ ! -e "$dest_file" ]]; then
      install -D -m 0644 "$source_file" "$dest_file"
    fi
  done < <(find "$source_dir" -type f -print0 | LC_ALL=C sort -z)
done
if grep -Fq 'android.intent.category.HOME' "$LAUNCHER"; then
  (cd "$ANDROID" && git -C packages/apps/Launcher3 apply -p4 "$PATCH")
fi
if ! grep -Fxq "$HOME_LINE" "$ROM"; then
  printf '\n# SableOS Track B: source-built HOME; existing 13 app/PhhIms graph retained.\n%s\n' "$HOME_LINE" >> "$ROM"
fi
echo 'TB2_CONVERGENCE=SOURCE_STAGED_REUSE_13_AND_FLOSS_HOME_SOURCE_NO_BUILD'
echo 'TB2_UNQUALIFIED=IMS_G123_PRIVILEGED_FEATURES_RUNTIME_HOME'
