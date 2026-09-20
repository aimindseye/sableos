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
retire="$ROOT/build/panther/retire-r8-obsolete-gradle-residue.sh"
retire_device_product="$ROOT/build/panther/retire-r8-legacy-sable-device-product.sh"
retire_vendor_config="$ROOT/build/panther/retire-r8-legacy-vendor-config.sh"
stage="$ROOT/build/panther/stage-r8-product-apps.sh"
finalbuild="$ROOT/build/panther/build-r8-final-ui.sh"
nostale="$ROOT/build/gates/r8-no-stale-product-code.sh"
inventory="$ROOT/build/gates/verify-r8-vendor-sable-inventory.py"
foundation_applier="$ROOT/patches/android-17-grapheneos-2026081300/apply_r9_launcher3_foundation.py"
foundation_contract="$ROOT/build/gates/r9-launcher3-foundation-contract.py"
foundation_qualifier="$ROOT/build/panther/qualify-r9-launcher3-foundation.sh"
target_files_gate="$ROOT/build/gates/r8-final-target-files.sh"
start_bp="$ROOT/src/android/packages/apps/SableStart/Android.bp"
android_settings="$ROOT/apps/r8/android/settings.gradle.kts"
start_check="$ROOT/apps/r8/android/sablestart-production-check/build.gradle.kts"
android_ci="$ROOT/.github/workflows/r8-android.yml"
android_static="$ROOT/.github/workflows/r8-android-static.yml"

for f in "$profile" "$release" "$verify" "$migrate" "$render" "$runner" "$retire" "$retire_device_product" "$retire_vendor_config" "$stage" "$finalbuild" "$nostale" "$inventory" "$foundation_applier" "$foundation_contract" "$foundation_qualifier" "$target_files_gate" "$start_bp" "$android_settings" "$start_check" "$android_ci" "$android_static"; do
    [[ -f "$f" ]] || {
        echo "R8_BUILD_DRIVER_CONTRACT=FAIL_MISSING path=$f"
        exit 2
    }
done

for f in "$verify" "$migrate" "$render" "$runner" "$retire" "$retire_device_product" "$retire_vendor_config" "$stage" "$finalbuild" "$nostale" "$foundation_qualifier"; do
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

grep -Fq 'apps/r8/android/start-preview' "$retire"
grep -Fq 'apps/r8/android/system-preview' "$retire"
grep -Fq 'git -C "$ROOT" ls-files -- "$rel"' "$retire"
grep -Fq 'R8_OBSOLETE_GRADLE_RESIDUE=FAIL_TRACKED_CONTENT' "$retire"
grep -Fq 'rm -rf --one-file-system -- "$target"' "$retire"
grep -Fq 'R8_OBSOLETE_GRADLE_RESIDUE=PASS' "$retire"
grep -Fq 'retire-r8-obsolete-gradle-residue.sh' "$runner"
grep -Fq 'obsolete-gradle-residue.log' "$runner"

cleanup_line="$(grep -nF '===== RETIRE OBSOLETE GRADLE MODULE RESIDUE =====' "$runner" | head -n1 | cut -d: -f1)"
host_line="$(grep -nF '===== CANONICAL HOST-TOOL GATE =====' "$runner" | head -n1 | cut -d: -f1)"
[[ -n "$cleanup_line" && -n "$host_line" && "$cleanup_line" -lt "$host_line" ]]

mkdir -p "$ROOT/apps/r8/android/start-preview/build/test"
mkdir -p "$ROOT/apps/r8/android/system-preview/build/test"
printf 'stale\n' > "$ROOT/apps/r8/android/start-preview/build/test/sentinel.txt"
printf 'stale\n' > "$ROOT/apps/r8/android/system-preview/build/test/sentinel.txt"

SOURCE_MUTATION_AUTHORIZED=YES bash "$retire" > "$ROOT/.r8-retire-self-test.log"

grep -Fxq 'R8_OBSOLETE_GRADLE_RESIDUE=PASS' "$ROOT/.r8-retire-self-test.log"
test ! -e "$ROOT/apps/r8/android/start-preview"
test ! -e "$ROOT/apps/r8/android/system-preview"
rm -f "$ROOT/.r8-retire-self-test.log"

echo "R8_OBSOLETE_GRADLE_RESIDUE_CONTRACT=PASS"

grep -Fq 'vendor/sable/config/common.mk' "$retire_vendor_config"
grep -Fq 'R8_LEGACY_VENDOR_CONFIG=FAIL_REFERENCED' "$retire_vendor_config"
grep -Fq 'rm -f -- "$target"' "$retire_vendor_config"
grep -Fq 'R8_LEGACY_VENDOR_CONFIG=REMOVED_UNREFERENCED' "$retire_vendor_config"
grep -Fq 'R8_LEGACY_VENDOR_CONFIG=PASS' "$retire_vendor_config"
bash "$retire_vendor_config" --self-test

grep -Fq 'retire-r8-legacy-vendor-config.sh' "$stage"
vendor_cleanup_line="$(grep -nF '===== LEGACY SABLE VENDOR CONFIG RETIREMENT =====' "$stage" | head -n1 | cut -d: -f1)"
dest_line="$(grep -nF 'DEST="$WS/vendor/sable/r8"' "$stage" | head -n1 | cut -d: -f1)"
[[ -n "$vendor_cleanup_line" && -n "$dest_line" && "$vendor_cleanup_line" -lt "$dest_line" ]]

echo "R8_LEGACY_VENDOR_CONFIG_RETIREMENT_CONTRACT=PASS"

grep -Fq 'vendor/sable_devices/sable_panther' "$retire_device_product"
grep -Fq 'R8_LEGACY_SABLE_DEVICE_PRODUCT=FAIL_REFERENCED' "$retire_device_product"
grep -Fq 'R8_LEGACY_SABLE_DEVICE_PRODUCT=FAIL_EXTRA_PARENT_CONTENT' "$retire_device_product"
grep -Fq 'rm -rf --one-file-system -- "$target"' "$retire_device_product"
grep -Fq 'R8_LEGACY_SABLE_DEVICE_PRODUCT=REMOVED_UNREFERENCED' "$retire_device_product"
bash "$retire_device_product" --self-test

grep -Fq 'retire-r8-legacy-sable-device-product.sh' "$stage"
device_cleanup_line="$(grep -nF '===== LEGACY SABLE DEVICE PRODUCT RETIREMENT =====' "$stage" | head -n1 | cut -d: -f1)"
vendor_cleanup_line="$(grep -nF '===== LEGACY SABLE VENDOR CONFIG RETIREMENT =====' "$stage" | head -n1 | cut -d: -f1)"
[[ -n "$device_cleanup_line" && -n "$vendor_cleanup_line" && "$device_cleanup_line" -lt "$vendor_cleanup_line" ]]

grep -Fq 'R8_STALE_SABLE_DEVICE_PRODUCT' "$nostale"
grep -Fq 'R8_STALE_SABLE_DEVICE_PARENT' "$nostale"

echo "R8_LEGACY_SABLE_DEVICE_PRODUCT_RETIREMENT_CONTRACT=PASS"

grep -Fq 'LEGACY_PARENT="$WS/vendor/sable/prebuilts"' "$stage"
grep -Fq 'LEGACY_DEST="$LEGACY_PARENT/r8"' "$stage"
grep -Fq 'rm -rf --one-file-system -- "$LEGACY_DEST"' "$stage"
grep -Fq 'rmdir -- "$LEGACY_PARENT"' "$stage"
grep -Fq 'R8_LEGACY_PRODUCT_TREE=PASS_ABSENT_POST_STAGE' "$stage"
grep -Fq 'R8_LEGACY_PRODUCT_PARENT=PASS_ABSENT_POST_STAGE' "$stage"
grep -Fq 'LEGACY_WORKSPACE_PRODUCT_TREE="$WS/vendor/sable/prebuilts/r8"' "$nostale"
grep -Fq 'R8_STALE_WORKSPACE_PRODUCT_TREE' "$nostale"
grep -Fq 'verify-r8-vendor-sable-inventory.py' "$nostale"
grep -Fq 'R8_DUPLICATE_PRODUCT_BLUEPRINT' "$nostale"
grep -Fq 'R8_VENDOR_SABLE_EXACT_INVENTORY=PASS' "$inventory"
grep -Fq 'R8_VENDOR_SABLE_CANONICAL_APK_COUNT=8' "$inventory"
python3 "$inventory" --self-test

echo "R8_VENDOR_SABLE_EXACT_INVENTORY_CONTRACT=PASS"

python3 "$foundation_applier" --self-test
python3 "$foundation_contract" --self-test
grep -Fq 'name: "sable_start_presentation_srcs"' "$start_bp"
! grep -Fq 'android_app {' "$start_bp"
! grep -Fq 'rust_ffi_shared {' "$start_bp"
grep -Fq '===== LAUNCHER3 QUICKSTEP SOONG PREFLIGHT =====' "$finalbuild"
grep -Fq 'm -j"$JOBS" Launcher3QuickStep' "$finalbuild"
grep -Fq 'R9_LAUNCHER3_QUICKSTEP_SOONG_PREFLIGHT=PASS' "$finalbuild"
grep -Fq 'Launcher3QuickStep.apk' "$target_files_gate"
grep -Fq 'R9_STANDALONE_SABLESTART_TARGET=PASS_ABSENT' "$target_files_gate"
grep -Fq 'R9_L7_LAUNCHER3_FOUNDATION_COMPILE=PASS' "$foundation_qualifier"

echo "R9_LAUNCHER3_FOUNDATION_CONTRACT=PASS"

grep -Fq 'include(":sablestart-production-check")' "$android_settings"
! grep -Fq 'include(":start-preview")' "$android_settings"
! grep -Fq 'include(":system-preview")' "$android_settings"
grep -Fq '../../../../src/android/packages/apps/SableStart/src' "$start_check"
grep -Fq 'manifest.srcFile("src/main/AndroidManifest.xml")' "$start_check"
! grep -Fq '../../../../src/android/packages/apps/SableStart/AndroidManifest.xml' "$start_check"
grep -Fq ':sablestart-production-check:compileDebugKotlin' "$android_ci"
! grep -Fq ':start-preview:' "$android_ci"
! grep -Fq ':system-preview:' "$android_ci"
grep -Fq ':sablestart-production-check:lintDebug' "$android_static"
! grep -Fq ':start-preview:' "$android_static"
! grep -Fq ':system-preview:' "$android_static"

echo "R9_SABLESTART_PRESENTATION_GRADLE_COMPILE_CONTRACT=PASS"
echo "R9_SABLESTART_PRESENTATION_LINT_CONTRACT=PASS"

grep -Fq '===== LAUNCHER3 QUICKSTEP SOONG PREFLIGHT =====' "$finalbuild"
grep -Fq 'launcher3-quickstep-soong-preflight.log' "$finalbuild"
grep -Fq 'R9_LAUNCHER3_QUICKSTEP_SOONG_PREFLIGHT=PASS' "$finalbuild"
grep -Fq 'R8_FINAL_BUILD=FAIL_LAUNCHER3_FOUNDATION_PREFLIGHT' "$finalbuild"

preflight_line="$(grep -nF '===== LAUNCHER3 QUICKSTEP SOONG PREFLIGHT =====' "$finalbuild" | head -n1 | cut -d: -f1)"
combined_line="$(grep -nF '===== COMBINED UI MODULE COMPILE GATE =====' "$finalbuild" | head -n1 | cut -d: -f1)"
[[ -n "$preflight_line" && -n "$combined_line" && "$preflight_line" -lt "$combined_line" ]]

echo "R9_LAUNCHER3_QUICKSTEP_SOONG_PREFLIGHT_CONTRACT=PASS"

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
