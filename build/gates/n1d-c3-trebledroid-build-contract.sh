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
    'host_layout_fix_requires_--authorize-host-layout-source-mutation' \
    'N1D_C3A_HOST_LAYOUT_FIX_APPLY=PASS_APPLIED_EXACT patch=2' \
    'N1D_C3A_HOST_LAYOUT_FIX_APPLY=PASS_COMPLETE' \
    'DEXPREOPT_OUTDIR_PATCH=' \
    'FAILED_SYSTEMIMAGE_PRE_ARTIFACT' \
    'prior_build_resume_state_inconsistent' \
    'prior_systemimage_build_product_out_evidence_missing' \
    'prior_product_out_outside_c3_out' \
    'prior_final_system_img_exists_resume_not_allowed' \
    'N1D_C3A_RESUME_FINAL_SYSTEM_IMG=PASS_ABSENT' \
    'N1D_C3A_RESUME_INTERMEDIATE_SYSTEM_IMAGES=INFO' \
    'N1D_C3A_RESUME_PACKAGING_ARTIFACT=FOUND' \
    'N1D_C3A_RESUME_PACKAGING_ARTIFACTS=PASS_ABSENT' \
    'find_c3a_packaging_artifacts()' \
    'N1D_C3A_POSTBUILD_PACKAGING_ARTIFACT=FOUND' \
    'N1D_C3A_POSTBUILD_PACKAGING_ARTIFACTS=PASS_ABSENT' \
    'otacerts_payload_count=' \
    'prior_output_contains_packaging_artifact_resume_not_allowed' \
    'failed_build_evidence_missing_for_resume' \
    'N1D_C3A_BUILD_RESUME=PASS' \
    'PREP_VERIFY_ARGS=(verify --allow-c3a-host-layout-fix)' \
    'PREP_VERIFY_ARGS+=(--allow-treble-app-build-residue)' \
    'bash "$PREP" "${PREP_VERIFY_ARGS[@]}"' \
    'treble-app-resume-status.txt' \
    'build-soong-host-layout-status.txt' \
    'build-soong-host-layout.diff' \
    'BUILD_AUTHORIZED=YES_SYSTEMIMAGE_ONLY' \
    'NETWORK_FETCH_AUTHORIZED=YES_TREBLE_APP_GRADLE_ONLY' \
    'TARGET_FILES_BUILD_AUTHORIZED=NO' \
    'OTA_BUILD_AUTHORIZED=NO' \
    'DEVICE_CONTACT_AUTHORIZED=NO' \
    'FLASH_AUTHORIZED=NO' \
    'PRODUCTION_SIGNING_AUTHORIZED=NO' \
    'canonical_gradle_user_home_missing=$SABLE_GRADLE_USER_HOME' \
    'N1D_C3_TREBLE_APP_JDK=PASS' \
    'export JAVA_HOME="$SABLE_JDK17"' \
    'export GRADLE_USER_HOME="$SABLE_GRADLE_USER_HOME"' \
    'N1D_C3_TREBLE_APP_JAVA=PASS' \
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
    'N1D_C3_TREBLE_APP_JDK_SOURCE=SABLE_JDK17' \
    'N1D_C3_TREBLE_APP_BUILD_RESIDUE_POLICY=SDK_METADATA_AND_LICENSES_ONLY' \
    'N1D_C3_TREBLE_APP_KNOWN_PACKAGES_BASE_BLOB=7b27183be84845e00318dbbd3aeb60b5d291216b' \
    'N1D_C3A_HOST_LAYOUT_PATCH_COUNT=2' \
    'N1D_C3A_HOST_LAYOUT_PATCH_ROLE=BUILD_ENVIRONMENT_COMPATIBILITY_ONLY' \
    'N1D_C3A_HOST_LAYOUT_PATCH_BLOB_SHA=ce55b543e3e5ff49a9a6921ba752f6aa39d53997' \
    'N1D_C3A_HOST_LAYOUT_TARGET_POST_BLOB=b9bc7009d822dd811c0338c5595d14f0617d1392' \
    'N1D_C3A_DEXPREOPT_OUTDIR_PATCH_BLOB_SHA=6c74503ab0f000b82b944ad545d90b517d7d6bad' \
    'N1D_C3A_DEXPREOPT_OUTDIR_TARGET_BASE_BLOB=8033b48e5cfcc2cb2f64037aca44c129f54a969b' \
    'N1D_C3A_DEXPREOPT_OUTDIR_TARGET_POST_BLOB=7024841edac715a9bd3a81af92c42da0b302e1f0'
do
    grep -Fxq "$token" "$PROFILE" || fail "profile_missing=$token"
done

for token in \
    'N1D_C3A_STATUS=SEALED_COMPLETE' \
    'N1D_C3A_RELEASE_ELIGIBLE=NO' \
    'N1D_C3B_ENGINEERING_BUILD_AUTHORIZED=YES_SYSTEMIMAGE_ONLY_AFTER_STAGE_AND_PARSE'
do
    grep -Fxq "$token" "$PHASE" || fail "phase_missing=$token"
done

for token in \
    'N1D_PRODUCT_CONTRACT_VERSION=6' \
    'N1D_PRODUCT_NAME=treble_arm64_bvN' \
    'N1D_C3_FIRST_BUILD_VARIANT=userdebug' \
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

if grep -Fq -- "*ota*.zip" "$DRIVER"; then
    fail broad_ota_zip_pattern_present
fi

echo "N1D_C3_TREBLEDROID_BUILD_POLICY_OWNERSHIP=PASS"
echo "N1D_C3_TREBLEDROID_BUILD_TREBLE_APP_RELEASE=PASS_REQUIRED"
echo "N1D_C3_TREBLEDROID_BUILD_SYSTEMIMAGE_ONLY=PASS"
echo "N1D_C3_TREBLEDROID_BUILD_NO_PACKAGING=PASS"
echo "N1D_C3_TREBLEDROID_BUILD_NO_DEVICE_COMMANDS=PASS"
echo "N1D_C3_TREBLEDROID_BUILD_NETWORK_SCOPE=PASS_TREBLE_APP_GRADLE_ONLY"
echo "N1D_C3_TREBLEDROID_BUILD_NON_RELEASE=PASS"
echo "N1D_C3A_CONTROL_BUILD_CONTRACT=PASS_HISTORICAL"
echo "N1D_C3_TREBLEDROID_BUILD_CONTRACT=PASS"
