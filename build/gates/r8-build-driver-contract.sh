#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

profile="$ROOT/build/config/r8-host-tools.env"
release="$ROOT/build/config/r8-release.env"
verify="$ROOT/build/host/verify-r8-host-tools.sh"
migrate="$ROOT/build/host/migrate-r8-final-v1-host-tools.sh"
render="$ROOT/build/panther/render-r8-build-driver.sh"
runner="$ROOT/build/panther/run-r8-release-candidate.sh"
stage="$ROOT/build/panther/stage-r8-product-apps.sh"
finalbuild="$ROOT/build/panther/build-r8-final-ui.sh"
nostale="$ROOT/build/gates/r8-no-stale-product-code.sh"
android_settings="$ROOT/apps/r8/android/settings.gradle.kts"
start_check="$ROOT/apps/r8/android/sablestart-production-check/build.gradle.kts"
android_ci="$ROOT/.github/workflows/r8-android.yml"

for f in "$profile" "$release" "$verify" "$migrate" "$render" "$runner" "$stage" "$finalbuild" "$nostale" "$android_settings" "$start_check" "$android_ci"; do
    [[ -f "$f" ]] || {
        echo "R8_BUILD_DRIVER_CONTRACT=FAIL_MISSING path=$f"
        exit 2
    }
done

for f in "$verify" "$migrate" "$render" "$runner" "$stage" "$finalbuild" "$nostale"; do
    bash -n "$f"
done

grep -Fq '/srv/data/sable-host-tools' "$profile"
! grep -R -Fq '/srv/data/sable-build/host-tools/r8-final-v1'     "$profile" "$release" "$verify" "$render" "$runner"

for needle in     'SABLE_ANDROID_API=36'     'SABLE_ANDROID_BUILD_TOOLS_VERSION=36.0.0'     'SABLE_ANDROID_NDK_VERSION=30.0.16248370'     'SABLE_RUST_VERSION=1.98.1'     'SABLE_RUST_TARGET=aarch64-linux-android'
do
    grep -Fq "$needle" "$profile"
done

grep -Fq 'SABLEOS_RELEASE_VERSION' "$release"
grep -Fq 'verify-r8-host-tools.sh' "$runner"
grep -Fq 'prepare-r8-final-ui.sh' "$runner"
grep -Fq 'build-r8-final-ui.sh' "$runner"

grep -Fq 'NETWORK_FETCH_AUTHORIZED=NO' "$verify"
grep -Fq 'lib/rustlib/$SABLE_RUST_TARGET/lib' "$verify"
grep -Fq "libstd-*.rlib" "$verify"
! grep -Fq '"$SABLE_RUSTUP" target list' "$verify"
! grep -Eq '(^|[[:space:]])rustup([[:space:]]|$).*target[[:space:]]+list' "$verify"

echo "R8_HOST_GATE_OFFLINE_RUST_VERIFICATION=PASS"

grep -Fq 'LEGACY_PARENT="$WS/vendor/sable/prebuilts"' "$stage"
grep -Fq 'LEGACY_DEST="$LEGACY_PARENT/r8"' "$stage"
grep -Fq 'rm -rf --one-file-system -- "$LEGACY_DEST"' "$stage"
grep -Fq 'rmdir -- "$LEGACY_PARENT"' "$stage"
grep -Fq 'R8_LEGACY_PRODUCT_TREE=PASS_ABSENT_POST_STAGE' "$stage"
grep -Fq 'R8_LEGACY_PRODUCT_PARENT=PASS_ABSENT_POST_STAGE' "$stage"
grep -Fq 'LEGACY_WORKSPACE_PRODUCT_TREE="$WS/vendor/sable/prebuilts/r8"' "$nostale"
grep -Fq 'R8_STALE_WORKSPACE_PRODUCT_TREE' "$nostale"
grep -Fq 'R8_VENDOR_SABLE_EXACT_INVENTORY=PASS' "$nostale"
grep -Fq 'R8_VENDOR_SABLE_CANONICAL_FILE_COUNT=13' "$nostale"
grep -Fq 'R8_VENDOR_SABLE_CANONICAL_APK_COUNT=8' "$nostale"
grep -Fq 'R8_DUPLICATE_PRODUCT_BLUEPRINT' "$nostale"

echo "R8_VENDOR_SABLE_EXACT_INVENTORY_CONTRACT=PASS"

grep -Fq 'include(":sablestart-production-check")' "$android_settings"
! grep -Fq 'include(":start-preview")' "$android_settings"
! grep -Fq 'include(":system-preview")' "$android_settings"
grep -Fq '../../../../src/android/packages/apps/SableStart/src' "$start_check"
grep -Fq '../../../../src/android/packages/apps/SableStart/AndroidManifest.xml' "$start_check"
grep -Fq '../../../../src/android/packages/apps/SableStart/res' "$start_check"
grep -Fq ':sablestart-production-check:compileDebugKotlin' "$android_ci"
! grep -Fq ':start-preview:' "$android_ci"
! grep -Fq ':system-preview:' "$android_ci"

echo "R8_SABLESTART_PRODUCTION_GRADLE_COMPILE_CONTRACT=PASS"

grep -Fq '===== SABLESTART SOONG PREFLIGHT =====' "$finalbuild"
grep -Fq 'sablestart-soong-preflight.log' "$finalbuild"
grep -Fq 'R8_SABLESTART_SOONG_PREFLIGHT=PASS' "$finalbuild"
grep -Fq 'R8_FINAL_BUILD=FAIL_SABLESTART_PREFLIGHT' "$finalbuild"

preflight_line="$(grep -nF '===== SABLESTART SOONG PREFLIGHT =====' "$finalbuild" | head -n1 | cut -d: -f1)"
combined_line="$(grep -nF '===== COMBINED UI MODULE COMPILE GATE =====' "$finalbuild" | head -n1 | cut -d: -f1)"
[[ -n "$preflight_line" && -n "$combined_line" && "$preflight_line" -lt "$combined_line" ]]

echo "R8_SABLESTART_SOONG_PREFLIGHT_CONTRACT=PASS"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
bash "$render" 0123456789abcdef0123456789abcdef01234567 "$tmp" >/dev/null
bash -n "$tmp"
grep -Fq 'EXPECTED_SOURCE_COMMIT="0123456789abcdef0123456789abcdef01234567"' "$tmp"
grep -Fq 'SOURCE_MUTATION_AUTHORIZED=YES' "$tmp"
grep -Fq 'BUILD_AUTHORIZED=YES' "$tmp"
grep -Fq 'bash "$REPO/build/panther/run-r8-release-candidate.sh"' "$tmp"
! grep -Fq '        "$REPO/build/panther/run-r8-release-candidate.sh"' "$tmp"

echo "R8_BUILD_DRIVER_RUNNER_INVOCATION=PASS"
echo "R8_BUILD_DRIVER_CONTRACT=PASS"
