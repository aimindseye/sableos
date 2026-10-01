#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DRIVER="$ROOT/build/titan2/build-n1d-c3-trebledroid-systemimage.sh"
PROFILE="$ROOT/build/titan2/n1d-c3-trebledroid.env"
PHASE="$ROOT/build/titan2/n1d-c3-phase-split.env"
PRODUCT="$ROOT/build/titan2/n1d-product-contract.env"

fail() {
    echo "N1D_C3_TREBLEDROID_BUILD_CONTRACT=FAIL $*" >&2
    exit 1
}

for f in "$DRIVER" "$PROFILE" "$PHASE" "$PRODUCT"; do
    [[ -f "$f" ]] || fail "missing_file=$f"
    bash -n "$f" || fail "syntax=$f"
done

for token in \
    'compile_requires_--authorize-c3-compile' \
    'build_requires_--authorize-network_for_treble_app' \
    'out_already_exists_requires_--resume-failed-c3-build' \
    'failed_build_evidence_missing_for_resume' \
    'prior_build_reached_systemimage_resume_not_allowed' \
    'N1D_C3A_BUILD_RESUME=PASS' \
    'BUILD_AUTHORIZED=YES_SYSTEMIMAGE_ONLY' \
    'NETWORK_FETCH_AUTHORIZED=YES_TREBLE_APP_GRADLE_ONLY' \
    'TARGET_FILES_BUILD_AUTHORIZED=NO' \
    'OTA_BUILD_AUTHORIZED=NO' \
    'DEVICE_CONTACT_AUTHORIZED=NO' \
    'FLASH_AUTHORIZED=NO' \
    'PRODUCTION_SIGNING_AUTHORIZED=NO' \
    'bash "$HOST_VERIFY" core' \
    'N1D_C3_TREBLE_APP_JDK=PASS' \
    'export JAVA_HOME="$SABLE_JDK17"' \
    'export GRADLE_USER_HOME="$SABLE_GRADLE_USER_HOME"' \
    'N1D_C3_TREBLE_APP_JAVA=PASS' \
    'bash "$PREP" verify' \
    'bash build.sh release' \
    'N1D_C3_TREBLE_APP_BUILD=PASS' \
    'make systemimage -j"$JOBS"' \
    'N1D_C3A_RELEASE_ELIGIBLE=$N1D_C3A_RELEASE_ELIGIBLE' \
    'N1D_C3B_BUILD_AUTHORIZED=$N1D_C3B_BUILD_AUTHORIZED' \
    'N1D_C3_RELEASE_ELIGIBLE=$N1D_C3_RELEASE_ELIGIBLE' \
    'N1D_C3A_TREBLEDROID_SYSTEMIMAGE=PASS'
do
    grep -Fq -- "$token" "$DRIVER" || fail "driver_missing=$token"
done

for token in \
    'N1D_C3_GENERATED_PRODUCT=treble_arm64_bvN' \
    'N1D_C3_RELEASE_CONFIG=bp4a' \
    'N1D_C3_FIRST_VARIANT=user' \
    'N1D_C3_TREBLE_APP_BUILD_REQUIRED=YES_RELEASE_PREBUILD' \
    'N1D_C3_TREBLE_APP_BUILD_COMMAND=bash_build.sh_release' \
    'N1D_C3_TREBLE_APP_NETWORK_REQUIRES_EXPLICIT_AUTH=YES' \
    'N1D_C3_TREBLE_APP_JDK_MAJOR=17' \
    'N1D_C3_TREBLE_APP_JDK_SOURCE=SABLE_JDK17'
do
    grep -Fxq "$token" "$PROFILE" || fail "profile_missing=$token"
done

for token in \
    'N1D_C3A_RELEASE_ELIGIBLE=NO' \
    'N1D_C3B_BUILD_AUTHORIZED=NO_UNTIL_C3A_CONTROL_EVIDENCE'
do
    grep -Fxq "$token" "$PHASE" || fail "phase_missing=$token"
done

for token in \
    'N1D_PRODUCT_CONTRACT_VERSION=5' \
    'N1D_PRODUCT_NAME=treble_arm64_bvN' \
    'N1D_C3_FIRST_BUILD_VARIANT=user' \
    'N1D_C3_FIRST_BUILD_GOAL=systemimage' \
    'N1D_C3_RELEASE_ELIGIBLE=NO'
do
    grep -Fxq "$token" "$PRODUCT" || fail "product_missing=$token"
done

compile_count="$(grep -Ec '^[[:space:]]*make[[:space:]]+systemimage[[:space:]]' "$DRIVER" || true)"
[[ "$compile_count" == 1 ]] || fail "systemimage_invocation_count=$compile_count"

treble_app_count="$(grep -Ec '^[[:space:]]*bash[[:space:]]+build\.sh[[:space:]]+release[[:space:]]*$' "$DRIVER" || true)"
[[ "$treble_app_count" == 1 ]] || fail "treble_app_release_build_count=$treble_app_count"

if grep -Eq 'target-files-package|otatools|(^|[[:space:]])dist([[:space:]]|$)' "$DRIVER"; then
    fail unauthorized_packaging_goal_present
fi
if grep -Eq '^[[:space:]]*(adb|fastboot)([[:space:]]|$)' "$DRIVER"; then
    fail device_command_present
fi
if grep -Eq 'repo[[:space:]]+sync|curl[[:space:]]|wget[[:space:]]|git[[:space:]]+fetch' "$DRIVER"; then
    fail unexpected_explicit_network_command_present
fi
if grep -Fq 'sable_titan2_n1d_arm64' "$DRIVER" "$PROFILE" "$PHASE" "$PRODUCT"; then
    fail retired_handcrafted_product_present
fi

echo "N1D_C3_TREBLEDROID_BUILD_POLICY_OWNERSHIP=PASS"
echo "N1D_C3_TREBLEDROID_BUILD_TREBLE_APP_RELEASE=PASS_REQUIRED"
echo "N1D_C3_TREBLEDROID_BUILD_SYSTEMIMAGE_ONLY=PASS"
echo "N1D_C3_TREBLEDROID_BUILD_NO_PACKAGING=PASS"
echo "N1D_C3_TREBLEDROID_BUILD_NO_DEVICE_COMMANDS=PASS"
echo "N1D_C3_TREBLEDROID_BUILD_NETWORK_SCOPE=PASS_TREBLE_APP_GRADLE_ONLY"
echo "N1D_C3_TREBLEDROID_BUILD_NON_RELEASE=PASS"
echo "N1D_C3A_CONTROL_BUILD_CONTRACT=PASS"
echo "N1D_C3_TREBLEDROID_BUILD_CONTRACT=PASS"
