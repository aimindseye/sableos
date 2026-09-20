#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

profile="$ROOT/build/config/r8-host-tools.env"
release="$ROOT/build/config/r8-release.env"
verify="$ROOT/build/host/verify-r8-host-tools.sh"
migrate="$ROOT/build/host/migrate-r8-final-v1-host-tools.sh"
host_audit="$ROOT/build/host/audit-r8-host-tools.sh"
host_bootstrap="$ROOT/build/host/bootstrap-r8-host-tools.sh"
host_centralize="$ROOT/build/host/centralize-r8-security-tools.sh"
host_cleanup="$ROOT/build/host/cleanup-r8-host-tool-duplicates.sh"
release_entry="$ROOT/build/panther/run-release.sh"
render="$ROOT/build/panther/render-r8-build-driver.sh"
runner="$ROOT/build/panther/run-r8-release-candidate.sh"
retire="$ROOT/build/panther/retire-r8-obsolete-gradle-residue.sh"
retire_device_product="$ROOT/build/panther/retire-r8-legacy-sable-device-product.sh"
retire_vendor_config="$ROOT/build/panther/retire-r8-legacy-vendor-config.sh"
stage="$ROOT/build/panther/stage-r8-product-apps.sh"
finalbuild="$ROOT/build/panther/build-r8-final-ui.sh"
nostale="$ROOT/build/gates/r8-no-stale-product-code.sh"
inventory="$ROOT/build/gates/verify-r8-vendor-sable-inventory.py"
target_files_gate="$ROOT/build/gates/r8-final-target-files.sh"
visual_acceptance="$ROOT/build/gates/r9-launcher-visual-acceptance.py"
start_bp="$ROOT/src/android/packages/apps/SableStart/Android.bp"
android_settings="$ROOT/apps/r8/android/settings.gradle.kts"
start_check="$ROOT/apps/r8/android/sablestart-presentation-check/build.gradle.kts"
local_ci="$ROOT/build/local-ci/run.sh"
ci_policy="$ROOT/build/check-ci-policy.py"

for f in "$profile" "$release" "$verify" "$migrate" "$host_audit" "$host_bootstrap" "$host_centralize" "$host_cleanup" "$release_entry" "$render" "$runner" "$retire" "$retire_device_product" "$retire_vendor_config" "$stage" "$finalbuild" "$nostale" "$inventory" "$target_files_gate" "$visual_acceptance" "$start_bp" "$android_settings" "$start_check" "$local_ci" "$ci_policy"; do
    [[ -f "$f" ]] || {
        echo "R8_BUILD_DRIVER_CONTRACT=FAIL_MISSING path=$f"
        exit 2
    }
done

for f in "$verify" "$migrate" "$host_audit" "$host_bootstrap" "$host_centralize" "$host_cleanup" "$release_entry" "$render" "$runner" "$retire" "$retire_device_product" "$retire_vendor_config" "$stage" "$finalbuild" "$nostale" "$local_ci"; do
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

grep -Fq 'SABLE_SECURITY_BIN' "$profile"
grep -Fq 'SABLE_CARGO_LLVM_COV' "$profile"
grep -Fq 'SABLE_GITLEAKS' "$profile"
grep -Fq 'SABLE_MOBSFSCAN' "$profile"
grep -Fq 'HOST_TOOL_BOOTSTRAP_AUTHORIZED' "$host_bootstrap"
grep -Fq 'HOST_PACKAGE_INSTALL_AUTHORIZED' "$host_bootstrap"
grep -Fq 'NETWORK_FETCH_AUTHORIZED' "$host_bootstrap"
grep -Fq 'SABLE_MOBSFSCAN_VENV' "$profile"
grep -Fq -- '--verify-dir "$SABLE_SECURITY_BIN"' "$verify"
grep -Fq 'R8_MOBSFSCAN_VERSION' "$verify"
! grep -Fq 'component add' "$local_ci"
! grep -Fq 'python3 -m venv' "$local_ci"
! grep -Fq 'pip install' "$local_ci"
! grep -Fq 'PINNED_TOOLS_DIR' "$local_ci"

echo "R8_SHARED_HOST_SECURITY_TOOLCHAIN_CONTRACT=PASS"

echo "R8_HOST_GATE_OFFLINE_RUST_VERIFICATION=PASS"

grep -Fq 'apps/r8/android/start-preview' "$retire"
grep -Fq 'apps/r8/android/system-preview' "$retire"
grep -Fq 'apps/r8/android/sablestart-production-check' "$retire"
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
mkdir -p "$ROOT/apps/r8/android/sablestart-production-check/build/test"
printf 'stale\n' > "$ROOT/apps/r8/android/start-preview/build/test/sentinel.txt"
printf 'stale\n' > "$ROOT/apps/r8/android/system-preview/build/test/sentinel.txt"
printf 'stale\n' > "$ROOT/apps/r8/android/sablestart-production-check/build/test/sentinel.txt"

SOURCE_MUTATION_AUTHORIZED=YES bash "$retire" > "$ROOT/.r8-retire-self-test.log"

grep -Fxq 'R8_OBSOLETE_GRADLE_RESIDUE=PASS' "$ROOT/.r8-retire-self-test.log"
test ! -e "$ROOT/apps/r8/android/start-preview"
test ! -e "$ROOT/apps/r8/android/system-preview"
test ! -e "$ROOT/apps/r8/android/sablestart-production-check"
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

grep -Fq 'name: "sable_start_presentation_srcs"' "$start_bp"
! grep -Fq 'android_app {' "$start_bp"
! grep -Fq 'rust_ffi_shared {' "$start_bp"
grep -Fq 'Launcher3QuickStep.apk' "$target_files_gate"
grep -Fq 'R9_SABLESTART_TARGET=PASS_ABSENT' "$target_files_gate"

echo "R9_LAUNCHER3_HOME_TARGET_POLICY_CONTRACT=PASS"


grep -Fq 'include(":sablestart-presentation-check")' "$android_settings"
! grep -Fq 'include(":sablestart-production-check")' "$android_settings"
! grep -Fq 'include(":start-preview")' "$android_settings"
! grep -Fq 'include(":system-preview")' "$android_settings"
grep -Fq '../../../../src/android/packages/apps/SableStart/src' "$start_check"
! grep -Fq 'AndroidManifest.xml' "$start_check"
! grep -Fq 'src/android/packages/apps/SableStart/res' "$start_check"
grep -Fq ':sablestart-presentation-check:compileDebugKotlin' "$local_ci"
grep -Fq ':sablestart-presentation-check:lintDebug' "$local_ci"
! grep -Fq ':sablestart-production-check:' "$local_ci"
! grep -Fq ':start-preview:' "$local_ci"
! grep -Fq ':system-preview:' "$local_ci"
grep -Fq 'GITHUB_ACTIONS_EXECUTION=DISABLED' "$local_ci"
grep -Fq 'SELF_HOSTED_ACTIONS_RUNNER=DISABLED' "$local_ci"
grep -Fq 'hosted GitHub CI remains executable' "$ci_policy"

echo "R9_SABLESTART_PRESENTATION_GRADLE_COMPILE_CONTRACT=PASS"
echo "R9_SABLESTART_PRESENTATION_LINT_CONTRACT=PASS"

grep -Fq '===== LAUNCHER3QUICKSTEP HOME PREFLIGHT =====' "$finalbuild"
grep -Fq 'launcher3-home-preflight.log' "$finalbuild"
grep -Fq 'R9_LAUNCHER3_HOME_PREFLIGHT=PASS' "$finalbuild"
grep -Fq 'R8_FINAL_BUILD=FAIL_LAUNCHER3_HOME_PREFLIGHT' "$finalbuild"
! grep -Fq 'm -j"$JOBS" SableStart' "$finalbuild"

preflight_line="$(grep -nF '===== LAUNCHER3QUICKSTEP HOME PREFLIGHT =====' "$finalbuild" | head -n1 | cut -d: -f1)"
combined_line="$(grep -nF '===== COMBINED UI MODULE COMPILE GATE =====' "$finalbuild" | head -n1 | cut -d: -f1)"
[[ -n "$preflight_line" && -n "$combined_line" && "$preflight_line" -lt "$combined_line" ]]

echo "R9_LAUNCHER3_HOME_PREFLIGHT_CONTRACT=PASS"

grep -Fq 'r9-launcher-visual-acceptance.py' "$ROOT/build/gates/r8-final-product-composition.sh"
grep -Fq 'NEXT_FULL_PANTHER_BUILD_AUTHORIZED=YES' "$visual_acceptance"
grep -Fq 'R9_L6_VISUAL_REVIEW_STATUS=PASS' "$visual_acceptance"
python3 "$visual_acceptance"

echo "R9_LAUNCHER_VISUAL_ACCEPTANCE_BUILD_GATE=PASS"

grep -Fq 'reset · follow system + Sable Blue' "$ROOT/build/gates/r8-final-product-composition.sh"
grep -Fq 'R8_A_SHARED_DESIGN_STALE_APPEARANCE_COPY' "$ROOT/build/gates/r8-final-product-composition.sh"
grep -Fq 'search + command' "$ROOT/build/gates/r9-sablestart-design-contract.py"
grep -Fq 'HOME_RESOLVER=com.android.launcher3/.sable.SableQuickstepLauncher' "$ROOT/docs/R9_SABLESTART_LAUNCHER_DESIGN.md"
grep -Fq 'HOME_ROLE_HOLDER=com.android.launcher3' "$ROOT/docs/R9_SABLESTART_LAUNCHER_DESIGN.md"

echo "R9_SHARED_DESIGN_ACCEPTED_COPY_CONTRACT=PASS"


tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
bash "$render" 0123456789abcdef0123456789abcdef01234567 "$tmp" >/dev/null
bash -n "$tmp"
grep -Fq 'EXPECTED_SOURCE_COMMIT="0123456789abcdef0123456789abcdef01234567"' "$tmp"
grep -Fq 'SESSION="${SABLE_TMUX_SESSION:-sable-r9-panther-${EXPECTED_SOURCE_COMMIT:0:12}}"' "$tmp"
grep -Fq 'SOURCE_MUTATION_AUTHORIZED=YES' "$tmp"
grep -Fq 'BUILD_AUTHORIZED=YES' "$tmp"
grep -Fq 'bash "$REPO/build/panther/run-r8-release-candidate.sh"' "$tmp"
! grep -Fq '        "$REPO/build/panther/run-r8-release-candidate.sh"' "$tmp"

grep -Fq 'R9_FULL_OUT_DIR="${SABLE_R9_FULL_OUT_DIR:-out_sable_r9_full_${EXPECTED_SOURCE_COMMIT:0:12}}"' "$runner"
grep -Fq 'R9_RELEASE_CANDIDATE_FRESH_OUT=FAIL_PRESENT' "$runner"
grep -Fq 'REQUIRE_FRESH_OUT=YES' "$runner"
grep -Fq 'OUT_DIR="$R9_FULL_OUT_DIR"' "$runner"
! grep -Fq 'OUT_DIR="$SABLE_R8_OUT_DIR"' "$runner"
grep -Fq 'R9_FRESH_FULL_BUILD_OUT_PRECONDITION=FAIL_PRESENT' "$finalbuild"
grep -Fq 'R9_TARGET_FILES_FRESHNESS=PASS' "$finalbuild"
grep -Fq 'R9_FULL_BUILD_CAUSALITY=PASS_ABSENT_OUT_TO_FRESH_TARGET_FILES' "$finalbuild"

echo "R9_FRESH_FULL_BUILD_CONTRACT=PASS"

grep -Fq 'usage: bash build/panther/run-release.sh <release-version> [--tmux|--direct]' "$release_entry"
grep -Fq 'SABLEOS_RELEASE_VERSION="$RELEASE_VERSION"' "$release_entry"
grep -Fq 'CUSTOM_TMP_DRIVER=NO' "$release_entry"
grep -Fq 'RELEASE_SPECIFIC_BUILD_SCRIPT=NO' "$release_entry"
grep -Fq 'bash "$ROOT/build/panther/run-r8-release-candidate.sh"' "$release_entry"
grep -Fq 'build/panther/run-release.sh <release-version>' "$ROOT/build/README.md"
grep -Fq 'Do not create a new build' "$ROOT/build/README.md"

echo "SABLE_RELEASE_NEUTRAL_ENTRYPOINT_CONTRACT=PASS"


echo "R9_BUILD_DRIVER_SOURCE_BOUND_TMUX=PASS"
echo "R8_BUILD_DRIVER_RUNNER_INVOCATION=PASS"
echo "R8_BUILD_DRIVER_CONTRACT=PASS"
