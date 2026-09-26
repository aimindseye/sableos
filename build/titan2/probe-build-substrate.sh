#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/build/config/titan2-n0.env"

explicit="${1:-}"
candidates=()
[[ -n "$explicit" ]] && candidates+=("$explicit")
[[ -n "${SABLE_TITAN2_UPSTREAM:-}" ]] && candidates+=("$SABLE_TITAN2_UPSTREAM")
candidates+=(
  "/srv/data/sable-build/workspaces/r8-a4-panther-base-2026081300"
  "/srv/data/sableos/upstream/panther/grapheneos-2026081300"
)

for parent in /srv/data/sable-build/workspaces /srv/data/sableos/upstream; do
  [[ -d "$parent" ]] || continue
  while IFS= read -r envsetup; do
    candidates+=("${envsetup%/build/envsetup.sh}")
  done < <(find "$parent" -maxdepth 4 -type f -path '*/build/envsetup.sh' 2>/dev/null | LC_ALL=C sort)
done

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
printf '%s\n' "${candidates[@]}" | awk 'NF && !seen[$0]++' > "$tmp"

echo "===== TITAN 2 N0 BUILD SUBSTRATE PROBE ====="
echo "REQUIRED_ANDROID_RELEASE=$SABLE_TITAN2_REQUIRED_ANDROID_RELEASE"
echo "REQUIRED_PLATFORM_SDK=$SABLE_TITAN2_REQUIRED_PLATFORM_SDK"
echo "ARTIFACT_KIND=$SABLE_TITAN2_ARTIFACT_KIND"
echo "TARGET_ARCH=$SABLE_TITAN2_ARCH"

found=0
sdk36=0
gsi=0

while IFS= read -r tree; do
  [[ -f "$tree/build/envsetup.sh" ]] || continue
  found=$((found + 1))
  echo
  echo "SUBSTRATE_PATH=$tree"

  sdk=""
  version_file="$tree/build/make/core/version_defaults.mk"
  if [[ -f "$version_file" ]]; then
    sdk="$(sed -nE 's/^[[:space:]]*PLATFORM_SDK_VERSION[[:space:]]*:?=[[:space:]]*([0-9]+).*/\1/p' "$version_file" | head -n1)"
  fi
  [[ -n "$sdk" ]] || sdk=UNOBSERVED
  echo "PLATFORM_SDK=$sdk"
  if [[ "$sdk" == "$SABLE_TITAN2_REQUIRED_PLATFORM_SDK" ]]; then
    echo "PLATFORM_SDK_MATCH=YES"
    sdk36=$((sdk36 + 1))
  else
    echo "PLATFORM_SDK_MATCH=NO"
  fi

  manifest=""
  for m in "$tree/.repo/manifest.xml" "$tree/.repo/manifests/default.xml"; do
    [[ -f "$m" ]] && { manifest="$m"; break; }
  done
  if [[ -n "$manifest" ]]; then
    echo "MANIFEST_PATH=$manifest"
    sha256sum "$manifest" | sed 's/^/MANIFEST_SHA256=/'
  else
    echo "MANIFEST_PATH=UNOBSERVED"
  fi

  echo "GENERIC_ARM64_GSI_REFERENCES_BEGIN"
  refs="$(
    grep -RIlE --include='AndroidProducts.mk' --include='*.mk'       '(gsi[_-]?arm64|aosp[_-]?arm64|generic[_-]?arm64)'       "$tree/build/make/target/product" "$tree/device/generic" 2>/dev/null       | LC_ALL=C sort -u | head -n 80 || true
  )"
  if [[ -n "$refs" ]]; then
    printf '%s\n' "$refs"
    gsi=$((gsi + 1))
  else
    echo "NONE_FOUND"
  fi
  echo "GENERIC_ARM64_GSI_REFERENCES_END"
done < "$tmp"

echo
if [[ "$found" -eq 0 ]]; then
  echo "TITAN2_SUBSTRATE_FOUND=NO"
  echo "TITAN2_SUBSTRATE_QUALIFIED=NO"
  exit 3
fi

echo "TITAN2_SUBSTRATE_FOUND=YES"
echo "SDK36_SUBSTRATE_COUNT=$sdk36"
echo "GSI_REFERENCE_SUBSTRATE_COUNT=$gsi"
if [[ "$sdk36" -gt 0 && "$gsi" -gt 0 ]]; then
  echo "TITAN2_SUBSTRATE_QUALIFIED=NEEDS_PRODUCT_SELECTION"
else
  echo "TITAN2_SUBSTRATE_QUALIFIED=NO"
fi
