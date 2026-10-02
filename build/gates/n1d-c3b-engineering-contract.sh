#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TRANSITION="$ROOT/build/titan2/n1d-c3b-transition.env"
HARDENER="$ROOT/build/titan2/apply-n1d-c3b-phh-base-hardening.py"
PREP="$ROOT/build/titan2/prepare-n1d-c3b-engineering.sh"
PARSE="$ROOT/build/titan2/qualify-n1d-c3b-product-parse.sh"
BUILD="$ROOT/build/titan2/build-n1d-c3b-systemimage.sh"
SCAFFOLD_COMPAT_PATCH="$ROOT/patches/android-16-n1d-trebledroid/scaffold-compat/0001-vendor-interfaces-quarantine-lge-vibrator.patch"
PHH_LGE_COMPAT_PATCH="$ROOT/patches/android-16-n1d-trebledroid/scaffold-compat/0002-device-phh-quarantine-vibrator-lge-helper.patch"
TRANSITION_GATE="$ROOT/build/gates/n1d-c3b-transition-contract.sh"

fail() {
    echo "N1D_C3B_ENGINEERING_CONTRACT=FAIL $*" >&2
    exit 1
}

for f in "$TRANSITION" "$HARDENER" "$PREP" "$PARSE" "$BUILD" "$SCAFFOLD_COMPAT_PATCH" "$PHH_LGE_COMPAT_PATCH" "$TRANSITION_GATE"; do
    [[ -f "$f" ]] || fail "missing_file=$f"
done

for f in "$TRANSITION" "$PREP" "$PARSE" "$BUILD" "$TRANSITION_GATE"; do
    bash -n "$f" || fail "syntax=$f"
done
PYTHONPYCACHEPREFIX="${TMPDIR:-/tmp}/sable-pycache" \
    python3 -m py_compile "$HARDENER" || fail "python_syntax=$HARDENER"

bash "$TRANSITION_GATE"

for token in     'network_action_requires_--authorize-network'     'source_action_requires_--authorize-source-mutation'     'BUILD_AUTHORIZED=NO'     'N1D_C3B_WORKSPACE_SCOPE=PASS'     'N1D_C3B_GRAPHENE_BASE_PROJECT_COUNT=PASS'     'N1D_C3B_SCAFFOLD_HEADS=PASS_EXACT count=5'     'N1D_C3B_DROPPED_C3A_SCAFFOLD=PASS_ABSENT'     '"$SABLE_PYTHON" "$HARDENER" apply --repo "$PHH_ROOT"'     'bash generate.sh "$N1D_C3B_GENERATOR_CONFIG"'     'N1D_C3B_MANAGED_PROJECT_COUNT=PASS'     'N1D_C3B_GRAPHENE_REMOVALS=PASS_ZERO'     'N1D_C3B_RESTLESS_PATCHES=PASS_ZERO'     'N1D_C3B_PREP_VERIFY=PASS'
do
    grep -Fq -- "$token" "$PREP" || fail "prep_missing=$token"
done

grep -Fq '"$SABLE_REPO_TOOL" init' "$PREP" || fail repo_init_missing
repo_sync_count="$(grep -c '"$SABLE_REPO_TOOL" sync' "$PREP" || true)"
[[ "$repo_sync_count" == 2 ]] || fail "prep_repo_sync_count=$repo_sync_count"

for forbidden in     'n1d-c3a-trebledroid-remove.xml'     'treble_restlessos'
do
    if grep -Fq "$forbidden" "$PREP"; then
        fail "forbidden_prep_control_input=$forbidden"
    fi
done

if grep -Eq '(^|[[:space:]])(clean|clobber)([[:space:]]|$)' "$PREP" "$PARSE" "$BUILD"; then
    fail clean_or_clobber_present
fi
if grep -Eq '^[[:space:]]*(adb|fastboot)([[:space:]]|$)' "$PREP" "$PARSE" "$BUILD"; then
    fail device_command_present
fi

for token in     'product_parse_requires_--authorize-product-parse'     'ANDROID_TARGET_COMPILATION_AUTHORIZED=NO'     'NETWORK_FETCH_AUTHORIZED=NO'     'DEVICE_CONTACT_AUTHORIZED=NO'     'FLASH_AUTHORIZED=NO'     'N1D_C3B_PRODUCT_PARSE_NO_TARGET_ARTIFACTS=PASS'     'N1D_C3B_PRODUCT_PARSE=PASS'
do
    grep -Fq -- "$token" "$PARSE" || fail "parse_missing=$token"
done

if grep -Eq '^[[:space:]]*(make|m|ninja)([[:space:]]|$)' "$PARSE"; then
    fail compile_command_in_parse
fi
if grep -Eq 'repo[[:space:]]+sync|curl[[:space:]]|wget[[:space:]]|git[[:space:]]+fetch' "$PARSE"; then
    fail network_command_in_parse
fi

for token in     'compile_requires_--authorize-c3b-compile'     'host_layout_patch_requires_--authorize-host-layout-source-mutation'     'scaffold_compat_patch_requires_--authorize-scaffold-compat-source-mutation'     'BUILD_AUTHORIZED=YES_SYSTEMIMAGE_ONLY'     'NETWORK_FETCH_AUTHORIZED=NO'     'TARGET_FILES_BUILD_AUTHORIZED=NO'     'OTA_BUILD_AUTHORIZED=NO'     'DEVICE_CONTACT_AUTHORIZED=NO'     'FLASH_AUTHORIZED=NO'     'SIGNING_AUTHORIZED=NO'     'PHYSICAL_RUNTIME_AUTHORIZED=NO'     'N1D_C3B_VENDOR_INTERFACES_LGE_VIBRATOR=PASS_APPLIED'     'N1D_C3B_DEVICE_PHH_LGE_VIBRATOR=PASS_APPLIED'     'make systemimage -j"$JOBS"'     'N1D_C3B_POSTBUILD_PACKAGING_ARTIFACTS=PASS_ABSENT'     'N1D_C3B_SYSTEMIMAGE=PASS'
do
    grep -Fq -- "$token" "$BUILD" || fail "build_missing=$token"
done

systemimage_count="$(grep -Ec '^[[:space:]]*make[[:space:]]+systemimage[[:space:]]' "$BUILD" || true)"
[[ "$systemimage_count" == 1 ]] || fail "systemimage_count=$systemimage_count"

if grep -Eq 'bash[[:space:]]+build.sh[[:space:]]+release|TrebleApp.apk' "$BUILD"; then
    fail treble_app_build_reintroduced
fi
if grep -Eq 'repo[[:space:]]+sync|curl[[:space:]]|wget[[:space:]]|git[[:space:]]+fetch' "$BUILD"; then
    fail network_command_in_build
fi
if grep -Eq 'target-files-package|otatools|(^|[[:space:]])dist([[:space:]]|$)' "$BUILD"; then
    fail packaging_goal_present
fi

for required in     'N1D_C3_CURRENT_ACTIVE_PHASE=C3B_ENGINEERING'     'N1D_C3B_SCAFFOLD_PROJECT_COUNT=5'     'N1D_C3B_MANAGED_PROJECT_COUNT=1038'     'N1D_C3B_RESTLESS_PATCH_COUNT=0'     'N1D_C3B_RUNTIME_PATCH_ALLOWLIST_COUNT=0'     'N1D_C3B_PHH_BASE_SECURITY_TRANSFORM_COUNT=14'     'N1D_C3B_SCAFFOLD_COMPAT_PATCH_COUNT=2'     'N1D_C3B_SCAFFOLD_COMPAT_PATCH_ROLE=NON_TITAN_VENDOR_BUILD_GRAPH_QUARANTINE'     'N1D_C3B_ENGINEERING_VARIANT=userdebug'     'N1D_C3B_GENERATED_PRODUCT=treble_arm64_bvN'     'N1D_C3B_PRODUCT_IDENTITY_STATUS=ENGINEERING_GENERATED_TREBLEDROID_PENDING_E2'     'N1D_C3B_DEVICE_CONTACT_AUTHORIZED=NO'     'N1D_C3B_FLASH_AUTHORIZED=NO'     'N1D_C3B_SIGNING_AUTHORIZED=NO'     'N1D_C3B_PHYSICAL_RUNTIME_AUTHORIZED=NO'     'N1D_C3B_RELEASE_ELIGIBLE=NO'
do
    grep -Fxq "$required" "$TRANSITION" || fail "transition_missing=$required"
done

grep -Fq 'EXPECTED_BASE_BLOB = "a29e402009d449150f1216e5d517ec0c9b36bfbd"' "$HARDENER" ||
    fail hardener_base_binding_missing
grep -Fq 'EXPECTED_POST_BLOB = "58edfb8713e9a1392daaf5bbf0d07778efd6d669"' "$HARDENER" ||
    fail hardener_post_binding_missing
hardener_blob="$(git hash-object "$HARDENER")"
[[ "$hardener_blob" == 9fdfeb59ab7826615e8c0a44ea105dfc4b7e0679 ]] ||
    fail "hardener_blob=$hardener_blob"
grep -Fq 'N1D_C3B_PHH_BASE_SECURITY_REDUCTIONS=PASS' "$HARDENER" ||
    fail hardener_pass_marker_missing

scaffold_compat_patch_blob="$(git hash-object "$SCAFFOLD_COMPAT_PATCH")"
[[ "$scaffold_compat_patch_blob" == 21e88ec26ef0b0d5b80abd77ce2d3381c47a1976 ]] ||
    fail "scaffold_compat_patch_blob=$scaffold_compat_patch_blob"
grep -Fq 'deleted file mode 100644' "$SCAFFOLD_COMPAT_PATCH" ||
    fail scaffold_compat_delete_mode_missing
grep -Fq 'vendor/lge/hardware/vibrator/1.0/Android.bp' "$SCAFFOLD_COMPAT_PATCH" ||
    fail scaffold_compat_target_missing
if grep -Eq '^diff --git ' "$SCAFFOLD_COMPAT_PATCH" &&
   [[ "$(grep -Ec '^diff --git ' "$SCAFFOLD_COMPAT_PATCH")" != 1 ]]; then
    fail scaffold_compat_patch_not_single_file
fi

phh_lge_patch_blob="$(git hash-object "$PHH_LGE_COMPAT_PATCH")"
[[ "$phh_lge_patch_blob" == d4b63e03a8bc4f9fa589b5bde4965e6e3a4a3155 ]] ||
    fail "phh_lge_patch_blob=$phh_lge_patch_blob"
[[ "$(grep -Ec '^diff --git ' "$PHH_LGE_COMPAT_PATCH")" == 1 ]] ||
    fail phh_lge_patch_not_single_file
grep -Fq 'cmds/Android.bp' "$PHH_LGE_COMPAT_PATCH" ||
    fail phh_lge_patch_target_missing
grep -Fq 'name: "vibrator-lge"' "$PHH_LGE_COMPAT_PATCH" ||
    fail phh_lge_patch_module_missing
grep -Fq 'vendor.lge.hardware.vibrator@1.0' "$PHH_LGE_COMPAT_PATCH" ||
    fail phh_lge_patch_dependency_missing

echo "N1D_C3B_ENGINEERING_SCRIPT_SYNTAX=PASS"
echo "N1D_C3B_ENGINEERING_PHH_BASE_HARDENING=PASS_STATIC_BOUND"
echo "N1D_C3B_ENGINEERING_SCAFFOLD_COMPAT=PASS_EXACT_LGE_VIBRATOR_QUARANTINE count=2"
echo "N1D_C3B_ENGINEERING_PREP_SCOPE=PASS"
echo "N1D_C3B_ENGINEERING_PARSE_SCOPE=PASS_NO_COMPILE"
echo "N1D_C3B_ENGINEERING_BUILD_SCOPE=PASS_SYSTEMIMAGE_ONLY"
echo "N1D_C3B_ENGINEERING_NETWORK_SCOPE=PASS_PREP_ONLY"
echo "N1D_C3B_ENGINEERING_NO_CLEAN_CLOBBER=PASS"
echo "N1D_C3B_ENGINEERING_NO_DEVICE_COMMANDS=PASS"
echo "N1D_C3B_ENGINEERING_NO_TREBLE_APP_BUILD=PASS"
echo "N1D_C3B_ENGINEERING_NO_RELEASE_PACKAGING=PASS"
echo "N1D_C3B_ENGINEERING_CONTRACT=PASS"
