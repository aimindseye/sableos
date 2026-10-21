#!/usr/bin/env bash
# Build-time product source composer, called ONCE from canonical sable.sh TB2.
# This stages only nonprivileged app imports and SableLauncher source. It does
# not change default role, privileged permissions, radio, AVB or flashing.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/build/config/host-tools.env"
ANDROID="${SABLE_TB2_ANDROID_ROOT:-/srv/sable-build/workspaces/titan2-track-b/android}"
PRODUCT="$ROOT/product/titan2/track-b-integrated"
IMS="${SABLE_TB2_IMS_PROVIDER:-UNSELECTED}"
[[ -f "$ANDROID/build/envsetup.sh" && -f "$ANDROID/device/phh/treble/rom.mk" ]] || {
  echo "TB2_PRODUCT=HOLD_SELECTED_ANDROID16_ROOT_MISSING"; exit 66;
}
[[ "$IMS" == OEM || "$IMS" == FLOSS ]] || {
  echo "TB2_PRODUCT=HOLD_EXPLICIT_SINGLE_IMS_PROVIDER_REQUIRED"; exit 78;
}
case "$IMS" in
 OEM) provider="$ANDROID/vendor/sable/titan2/n1i-c1/sable-titan2-n1i-c1.mk" ;;
 FLOSS) provider="$ANDROID/vendor/sable/trackb13ims/selected-provider.mk" ;;
esac
[[ -f "$provider" ]] || { echo "TB2_PRODUCT=HOLD_PROVIDER_PRODUCT_MK_MISSING path=$provider"; exit 78; }
[[ -x "$SABLE_ANDROID_BUILD_TOOLS/aapt2" ]] || { echo "TB2_PRODUCT=HOLD_CANONICAL_AAPT2"; exit 66; }
# Resolve all release-scoped inputs before mutating the AOSP checkout.
entries=()
while IFS=$'\t' read -r module rel package; do
  [[ -z "$module" || "${module:0:1}" == "#" ]] && continue
  [[ "$module" =~ ^SableTB2[A-Za-z0-9]+$ && "$rel" == apps/* && "$rel" != *..* && "$package" =~ ^org\.sableos\.[A-Za-z0-9._]+$ ]] || {
    echo "TB2_PRODUCT=HOLD_INVALID_APK_ROW"; exit 78;
  }
  apk="$ROOT/$rel"
  [[ -f "$apk" && ! -L "$apk" ]] || { echo "TB2_PRODUCT=HOLD_APP_NOT_BUILT module=$module path=$apk"; exit 78; }
  found="$("$SABLE_ANDROID_BUILD_TOOLS/aapt2" dump badging "$apk" | sed -n "s/^package: name='\([^']*\)'.*/\1/p" | head -n1)"
  [[ "$found" == "$package" ]] || { echo "TB2_PRODUCT=HOLD_APK_PACKAGE_MISMATCH module=$module actual=$found expected=$package"; exit 78; }
  entries+=("$module|$apk|$package")
done < "$PRODUCT/selected-apps.tsv"
[[ "${#entries[@]}" -eq 10 ]] || { echo "TB2_PRODUCT=HOLD_APP_SET_INCOMPLETE count=${#entries[@]}"; exit 78; }
# Copy without deleting or silently replacing historical N1B2/native34 sources.
copy_source_tree() {
  local src="$1" dst="$2" file rel
  [[ -d "$src" ]] || { echo "TB2_PRODUCT=HOLD_REQUIRED_SOURCE_MISSING path=$src"; return 78; }
  while IFS= read -r -d '' file; do
    rel="${file#"$src"/}"
    [[ ! -L "$file" ]] || { echo "TB2_PRODUCT=HOLD_SOURCE_SYMLINK path=$file"; return 78; }
    if [[ -e "$dst/$rel" ]]; then
      cmp -s "$file" "$dst/$rel" || { echo "TB2_PRODUCT=HOLD_EXISTING_AOSP_SOURCE_DIFF path=$dst/$rel"; return 78; }
    else
      install -D -m 0644 "$file" "$dst/$rel"
    fi
  done < <(find "$src" -type f -print0 | LC_ALL=C sort -z)
}
copy_source_tree "$ROOT/src/android/packages/apps/SableStart" "$ANDROID/packages/apps/SableStart"
copy_source_tree "$ROOT/src/android/shared/sabledesign" "$ANDROID/packages/apps/SableDesign"
STAGE="$ANDROID/vendor/sable/trackb"
mkdir -p "$STAGE/prebuilt"
if [[ -f "$STAGE/Android.bp" ]] && ! grep -Fq 'TB2_MANAGED_BY_CANONICAL_STAGE' "$STAGE/Android.bp"; then
  echo "TB2_PRODUCT=HOLD_UNMANAGED_ANDROID_BP_COLLISION"; exit 78;
fi
{
  echo '// TB2_MANAGED_BY_CANONICAL_STAGE: engineering, nonprivileged, signed debug APKs.'
  for entry in "${entries[@]}"; do
    IFS='|' read -r module apk package <<< "$entry"
    printf 'android_app_import {\n    name: "%s",\n    apk: "prebuilt/%s.apk",\n    presigned: true,\n    product_specific: true,\n    privileged: false,\n    dex_preopt: { enabled: false },\n}\n\n' "$module" "$module"
  done
} > "$STAGE/.Android.bp.tb2-new"
for entry in "${entries[@]}"; do
  IFS='|' read -r module apk package <<< "$entry"
  dest="$STAGE/prebuilt/$module.apk"
  if [[ -f "$dest" && ! -f "$STAGE/Android.bp" ]]; then
    echo "TB2_PRODUCT=HOLD_UNMANAGED_PREBUILT_COLLISION module=$module"; exit 78;
  fi
  install -m 0644 "$apk" "$dest"
done
mv -f "$STAGE/.Android.bp.tb2-new" "$STAGE/Android.bp"
install -m 0644 "$PRODUCT/sable-track-b.mk" "$STAGE/sable-track-b.mk"
install -m 0644 "$PRODUCT/ims-oem-only.mk" "$STAGE/ims-oem-only.mk"
ROM="$ANDROID/device/phh/treble/rom.mk"
inc='$(call inherit-product, vendor/sable/trackb/sable-track-b.mk)'
if ! grep -Fxq "$inc" "$ROM"; then
  printf '\n# SableOS TB2 build-owned product composition (host-only engineering).\n%s\n' "$inc" >> "$ROM"
fi
echo "TB2_PRODUCT=STAGED_ENGINEERING_APPS_10_AND_SABLE_HOME_SOURCE IMS_REQUESTED=$IMS"
echo "TB2_PRODUCT_HOME_ROLE=OPEN_LAUNCHER3_RECENTS_ONLY_SOURCE_ADAPTATION"
echo "TB2_PRODUCT_PRIVILEGED_BACKENDS=OPEN"
echo "TB2_PRODUCT_IMS_G123=OPEN"
