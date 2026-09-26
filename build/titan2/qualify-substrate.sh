#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/build/config/titan2-n0.env"

TREE="${1:-$SABLE_TITAN2_UPSTREAM}"
[[ -f "$TREE/build/envsetup.sh" ]] || {
  echo "TITAN2_SUBSTRATE_QUALIFICATION=FAIL_TREE path=$TREE"
  exit 2
}

mkdir -p "$SABLE_TITAN2_OUT" "$SABLE_TITAN2_EVIDENCE"
export OUT_DIR="$SABLE_TITAN2_OUT"

cd "$TREE"
# shellcheck source=/dev/null
source build/envsetup.sh >/dev/null

set +e
lunch "$SABLE_TITAN2_LUNCH_TARGET" >/tmp/titan2-lunch.out 2>/tmp/titan2-lunch.err
lunch_rc=$?
set -e
if [[ "$lunch_rc" -ne 0 ]]; then
  cat /tmp/titan2-lunch.out
  cat /tmp/titan2-lunch.err >&2
  echo "TITAN2_SUBSTRATE_QUALIFICATION=FAIL_LUNCH target=$SABLE_TITAN2_LUNCH_TARGET"
  exit 3
fi

platform_sdk="$(get_build_var PLATFORM_SDK_VERSION 2>/dev/null || true)"
platform_version="$(get_build_var PLATFORM_VERSION 2>/dev/null || true)"
target_product="$(get_build_var TARGET_PRODUCT 2>/dev/null || true)"
target_device="$(get_build_var TARGET_DEVICE 2>/dev/null || true)"
target_arch="$(get_build_var TARGET_ARCH 2>/dev/null || true)"
target_variant="$(get_build_var TARGET_BUILD_VARIANT 2>/dev/null || true)"

manifest=""
if [[ -f .repo/manifest.xml ]]; then
  manifest=.repo/manifest.xml
fi

echo "===== TITAN 2 N0 SUBSTRATE QUALIFICATION ====="
echo "SUBSTRATE_PATH=$TREE"
echo "EXPECTED_TAG=$SABLE_TITAN2_AOSP_TAG"
echo "EXPECTED_PLATFORM_SDK=$SABLE_TITAN2_REQUIRED_PLATFORM_SDK"
echo "EXPECTED_LUNCH_TARGET=$SABLE_TITAN2_LUNCH_TARGET"
echo "PLATFORM_VERSION=${platform_version:-UNOBSERVED}"
echo "PLATFORM_SDK_VERSION=${platform_sdk:-UNOBSERVED}"
echo "TARGET_PRODUCT=${target_product:-UNOBSERVED}"
echo "TARGET_DEVICE=${target_device:-UNOBSERVED}"
echo "TARGET_ARCH=${target_arch:-UNOBSERVED}"
echo "TARGET_BUILD_VARIANT=${target_variant:-UNOBSERVED}"
echo "OUT_DIR=$OUT_DIR"

if [[ -n "$manifest" ]]; then
  echo "MANIFEST_PATH=$TREE/$manifest"
  echo "MANIFEST_SHA256=$(sha256sum "$manifest" | awk '{print $1}')"
fi

pass=YES
[[ "$platform_sdk" == "$SABLE_TITAN2_REQUIRED_PLATFORM_SDK" ]] || pass=NO
[[ "$target_product" == gsi_arm64 ]] || pass=NO
[[ "$target_device" == generic_arm64 ]] || pass=NO
[[ "$target_arch" == arm64 ]] || pass=NO
[[ "$target_variant" == userdebug ]] || pass=NO

if [[ "$pass" == YES ]]; then
  echo "TITAN2_GSI_ARM64_PRODUCT_CANDIDATE=$SABLE_TITAN2_LUNCH_TARGET"
  echo "TITAN2_SUBSTRATE_QUALIFIED=YES"
  exit 0
fi

echo "TITAN2_SUBSTRATE_QUALIFIED=NO"
exit 4
