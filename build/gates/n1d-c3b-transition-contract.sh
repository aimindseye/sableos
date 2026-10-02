#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TRANSITION="$ROOT/build/titan2/n1d-c3b-transition.env"
C3A_EVIDENCE="$ROOT/build/titan2/n1d-c3a-control-evidence.env"
C3A_EVIDENCE_GATE="$ROOT/build/gates/n1d-c3a-control-evidence-contract.sh"
SOURCE_LOCK="$ROOT/build/titan2/n1d-source-lock.env"
MANIFEST="$ROOT/build/titan2/n1d-c3b-scaffold-add.xml"
DECISIONS="$ROOT/build/titan2/n1d-c3b-scaffold-decisions.tsv"
DELTA="$ROOT/build/titan2/n1d-c3b-engineering.mk"
HARDENER="$ROOT/build/titan2/apply-n1d-c3b-phh-base-hardening.py"
RUNTIME_ALLOWLIST="$ROOT/build/titan2/n1d-c3b-runtime-patch-allowlist.txt"
HOST_PATCH_1="$ROOT/patches/android-16-n1d-trebledroid/host-layout/0001-soong-ci-tests-skip-out-of-tree-host-paths.patch"
HOST_PATCH_2="$ROOT/patches/android-16-n1d-trebledroid/host-layout/0002-soong-dexpreopt-gen-support-out-of-tree-product-packages.patch"
SCAFFOLD_COMPAT_PATCH="$ROOT/patches/android-16-n1d-trebledroid/scaffold-compat/0001-vendor-interfaces-quarantine-lge-vibrator.patch"
PHH_LGE_COMPAT_PATCH="$ROOT/patches/android-16-n1d-trebledroid/scaffold-compat/0002-device-phh-quarantine-vibrator-lge-helper.patch"
COMPAT_PEEL="$ROOT/build/titan2/n1d-c3b-compatibility-peel-r2.tsv"
CONTROL_PATCH_INVENTORY="$ROOT/build/titan2/n1d-c3a-control-patch-inventory-r2.tsv"
BUILD_MAKE_COMPAT_PATCH_1="$ROOT/patches/android-16-n1d-trebledroid/c3b-compat/0001-build-make-graphene-treble-graph.patch"
BUILD_MAKE_COMPAT_PATCH_2="$ROOT/patches/android-16-n1d-trebledroid/c3b-compat/0002-build-make-preserve-adb-auth.patch"

fail() {
    echo "N1D_C3B_TRANSITION_CONTRACT=FAIL $*" >&2
    exit 1
}

for f in     "$TRANSITION"     "$C3A_EVIDENCE"     "$C3A_EVIDENCE_GATE"     "$SOURCE_LOCK"     "$MANIFEST"     "$DECISIONS"     "$DELTA"     "$HARDENER"     "$RUNTIME_ALLOWLIST"     "$HOST_PATCH_1"     "$HOST_PATCH_2"     "$SCAFFOLD_COMPAT_PATCH"     "$PHH_LGE_COMPAT_PATCH"     "$COMPAT_PEEL"     "$CONTROL_PATCH_INVENTORY"     "$BUILD_MAKE_COMPAT_PATCH_1"     "$BUILD_MAKE_COMPAT_PATCH_2"
do
    [[ -f "$f" ]] || fail "missing_file=$f"
done

for f in "$TRANSITION" "$C3A_EVIDENCE" "$SOURCE_LOCK"; do
    bash -n "$f" || fail "syntax=$f"
done
PYTHONPYCACHEPREFIX="${TMPDIR:-/tmp}/sable-pycache" \
    python3 -m py_compile "$HARDENER" || fail "python_syntax=$HARDENER"

bash "$C3A_EVIDENCE_GATE"

require_line() {
    local file="$1"
    local line="$2"
    grep -Fxq "$line" "$file" || fail "missing_line=$line file=$file"
}

for required in     'N1D_C3B_TRANSITION_VERSION=2'     'N1D_C3B_TRANSITION_DATE=2026-10-02'     'N1D_C3B_C3A_EVIDENCE_FILE=build/titan2/n1d-c3a-control-evidence.env'     'N1D_C3B_C3A_REQUIRED_STATUS=PASS_SYSTEMIMAGE'     'N1D_C3B_C3A_REQUIRED_SYSTEM_SHA256=4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16'     'N1D_C3B_TRANSITION_PREREQUISITE=SATISFIED_BY_C3A_CONTROL_EVIDENCE'     'N1D_C3_CURRENT_ACTIVE_PHASE=C3B_ENGINEERING'     'N1D_C3B_ROLE=SABLE_MINIMAL_ENGINEERING_BASELINE'     'N1D_C3B_SOURCE_SUBSTRATE=GRAPHENEOS_A16_PINNED'     'N1D_C3B_GRAPHENE_TAG=2026061600'     'N1D_C3B_GRAPHENE_MANIFEST_COMMIT=5d82aa9610855bc0b43b9eb7ca4470d30455cfeb'     'N1D_C3B_GRAPHENE_BASE_PROJECT_COUNT=1033'     'N1D_C3B_WORKSPACE_REL=workspaces/titan2-n1d-c3b'     'N1D_C3B_ANDROID_ROOT_REL=workspaces/titan2-n1d-c3b/android'     'N1D_C3B_OUT_ROOT_REL=workspaces/titan2-n1d-c3b/out-c3b-engineering'     'N1D_C3B_SCAFFOLD_PROJECT_COUNT=5'     'N1D_C3B_REMOVE_PROJECT_COUNT=0'     'N1D_C3B_MANAGED_PROJECT_COUNT=1038'     'N1D_C3B_C3A_REMOVE_SET_INHERITED=NO'     'N1D_C3B_C3A_CONTROL_PATCH_STACK_INHERITED=NO'     'N1D_C3B_RESTLESS_PATCH_COUNT=0'     'N1D_C3B_RUNTIME_PATCH_ALLOWLIST_COUNT=0'     'N1D_C3B_COMPATIBILITY_PEEL_VERSION=2'     'N1D_C3B_COMPATIBILITY_PEEL_LEDGER=build/titan2/n1d-c3b-compatibility-peel-r2.tsv'     'N1D_C3B_C3A_CONTROL_PATCH_INVENTORY=build/titan2/n1d-c3a-control-patch-inventory-r2.tsv'     'N1D_C3B_C3A_CONTROL_PATCH_INVENTORY_COUNT=369'     'N1D_C3B_C3A_CONTROL_PATCH_ADMITTED_VERBATIM_COUNT=0'     'N1D_C3B_C3A_FOCUSED_COMPAT_FIX_COUNT=11'     'N1D_C3B_C3A_BUILD_MAKE_AUDIT_COUNT=9'     'N1D_C3B_C3A_HOST_LAYOUT_FIX_COUNT=2'     'N1D_C3B_RESTLESS_CONTROL_PATCH_COUNT=369'     'N1D_C3B_RESTLESS_WHOLESALE_ADMISSION_ALLOWED=NO'     'N1D_C3B_BUILD_MAKE_COMPAT_PATCH_COUNT=2'     'N1D_C3B_BUILD_MAKE_COMPAT_PATCH_ROLE=REPO_OWNED_BUILD_GRAPH_AND_SECURITY_ONLY'     'N1D_C3B_BUILD_MAKE_COMPAT_PATCH_1_BLOB_SHA=712f94e01a2f2adfeae831a97322ae8e6c984c44'     'N1D_C3B_BUILD_MAKE_COMPAT_PATCH_1_GENERIC_BASE_BLOB=1d7dcbffe746ad359a05d3c337338c8ba711e4f7'     'N1D_C3B_BUILD_MAKE_COMPAT_PATCH_1_GENERIC_POST_BLOB=5f0e346d7dbae6f98eb7f2cee4c553bfdca03952'     'N1D_C3B_BUILD_MAKE_COMPAT_PATCH_1_GSI_BASE_BLOB=3fa6e76c99e59b36187b6bf0e3868c492c22b61e'     'N1D_C3B_BUILD_MAKE_COMPAT_PATCH_1_GSI_POST_BLOB=013c2acca93dfa1eb6a2c0bb5c6103fc20f73f59'     'N1D_C3B_BUILD_MAKE_COMPAT_PATCH_2_BLOB_SHA=83cf451279b0d9ee4f6cd0820b25d744a7f17150'     'N1D_C3B_BUILD_MAKE_COMPAT_PATCH_2_BASE_BLOB=780aadc0aec5270c90f835076a3c94239c094354'     'N1D_C3B_BUILD_MAKE_COMPAT_PATCH_2_POST_BLOB=223ef974ae4d06bf2a501bb17209b2e164bcf22e'     'N1D_C3B_REJECT_RESTLESS_LLKD_REMOVAL=YES'     'N1D_C3B_REJECT_RESTLESS_APN_REMOVAL=YES'     'N1D_C3B_REJECT_RESTLESS_OPLUS_MY_MANIFEST=YES'     'N1D_C3B_DEFER_INIT_VNDK_NODEF=YES'     'N1D_C3B_DEFER_VNDK28_SEPOLICY_ATOMIC_PAIR=YES'     'N1D_C3B_DEFER_LOGVIEWER_TO_E2=YES'     'N1D_C3B_GENERATOR=device/phh/treble/generate.sh'     'N1D_C3B_GENERATOR_CONFIG=sable-c3b-engineering'     'N1D_C3B_GENERATED_PRODUCT=treble_arm64_bvN'     'N1D_C3B_PRODUCT_DEVICE=tdgsi_arm64_ab'     'N1D_C3B_RELEASE_CONFIG=bp4a'     'N1D_C3B_ENGINEERING_VARIANT=userdebug'     'N1D_C3B_ENGINEERING_GOAL=systemimage'     'N1D_C3B_DEVICE_PHH_TREBLE_COMMIT=39ba82ef89ff5bf6b22ca8f147dbf317bffa20ed'     'N1D_C3B_DEVICE_PHH_TREBLE_BASE_MK_BLOB=a29e402009d449150f1216e5d517ec0c9b36bfbd'     'N1D_C3B_PHH_BASE_HARDENING_APPLICATOR=build/titan2/apply-n1d-c3b-phh-base-hardening.py'     'N1D_C3B_PHH_BASE_SECURITY_TRANSFORM_COUNT=14'     'N1D_C3B_HOST_LAYOUT_PATCH_COUNT=2'     'N1D_C3B_HOST_LAYOUT_PATCH_ROLE=BUILD_ENVIRONMENT_COMPATIBILITY_ONLY'     'N1D_C3B_SCAFFOLD_COMPAT_PATCH_COUNT=2'     'N1D_C3B_SCAFFOLD_COMPAT_PATCH_ROLE=NON_TITAN_VENDOR_BUILD_GRAPH_QUARANTINE'     'N1D_C3B_VENDOR_INTERFACES_LGE_VIBRATOR_QUARANTINE_PATCH_BLOB_SHA=21e88ec26ef0b0d5b80abd77ce2d3381c47a1976'     'N1D_C3B_VENDOR_INTERFACES_LGE_VIBRATOR_TARGET=vendor/lge/hardware/vibrator/1.0/Android.bp'     'N1D_C3B_VENDOR_INTERFACES_LGE_VIBRATOR_BASE_BLOB=fa69894ac6b59ddb623f6f8f4426a15cef0e5df9'     'N1D_C3B_DEVICE_PHH_LGE_VIBRATOR_QUARANTINE_PATCH_BLOB_SHA=d4b63e03a8bc4f9fa589b5bde4965e6e3a4a3155'     'N1D_C3B_DEVICE_PHH_LGE_VIBRATOR_TARGET=cmds/Android.bp'     'N1D_C3B_DEVICE_PHH_LGE_VIBRATOR_BASE_BLOB=df2625f98a3df2472a3750e1345cd652902a15f3'     'N1D_C3B_ENGINEERING_BUILD_AUTHORIZED=YES_SYSTEMIMAGE_ONLY_AFTER_STAGE_AND_PARSE'     'N1D_C3B_TARGET_FILES_AUTHORIZED=NO'     'N1D_C3B_OTA_AUTHORIZED=NO'     'N1D_C3B_DEVICE_CONTACT_AUTHORIZED=NO'     'N1D_C3B_FLASH_AUTHORIZED=NO'     'N1D_C3B_SIGNING_AUTHORIZED=NO'     'N1D_C3B_PRODUCTION_SIGNING_AUTHORIZED=NO'     'N1D_C3B_PHYSICAL_RUNTIME_AUTHORIZED=NO'     'N1D_C3B_RELEASE_ELIGIBLE=NO'     'N1D_C3B_PRODUCT_IDENTITY_STATUS=ENGINEERING_GENERATED_TREBLEDROID_PENDING_E2'     'N1D_C3B_SABLE_PRODUCT_ADMISSION_OWNER=E2_CANONICAL_ENGINEERING_LANE'     'N1D_C3B_TRANSITION=PASS'
do
    require_line "$TRANSITION" "$required"
done

require_line "$C3A_EVIDENCE" 'N1D_C3A_CONTROL_EVIDENCE_STATUS=PASS_SYSTEMIMAGE'
require_line "$C3A_EVIDENCE" 'N1D_C3A_SYSTEM_SHA256=4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16'
require_line "$C3A_EVIDENCE" 'N1D_C3B_TRANSITION_PREREQUISITE=SATISFIED_BY_C3A_CONTROL_EVIDENCE'

for required in     'N1D_C3B_PATCH_APPLICATION_MODE=REPO_OWNED_REVIEWED_ALLOWLIST'     'N1D_C3B_PATCH_TIER_AUTOAPPLY_ALLOWED=NO'     'N1D_SELINUX_PERMISSIVE_DOMAINS_ALLOWED=NO'
do
    require_line "$SOURCE_LOCK" "$required"
done

project_count="$(grep -c '<project ' "$MANIFEST")"
remove_count="$(grep -c '<remove-project ' "$MANIFEST" || true)"
[[ "$project_count" == 5 ]] || fail "scaffold_project_count=$project_count"
[[ "$remove_count" == 0 ]] || fail "scaffold_remove_project_count=$remove_count"

for required in     'path="device/phh/treble"'     'revision="39ba82ef89ff5bf6b22ca8f147dbf317bffa20ed"'     'path="prebuilts/vndk/v28"'     'revision="204f1bad00aaf480ba33233f7b8c2ddaa03155dd"'     'path="prebuilts/vndk/v29"'     'revision="bef5d37dda9360940964f097d612c8032e140961"'     'path="vendor/interfaces"'     'revision="a2271d260e226e8de5cb1e8c15a229dc90c007dd"'     'path="vendor/lptools"'     'revision="c8be7de57b80eab61a6f94ec86464a01fb9056f2"'
do
    grep -Fq "$required" "$MANIFEST" || fail "manifest_missing=$required"
done

for forbidden in     'packages/apps/QcRilAm'     'prebuilts/vndk/v30'     'treble_app'     'vendor/apn'     'vendor/hardware_overlay'     'vendor/magisk'     'vendor/vndk-tests'     'vendor/cawilliamson-priv'     'vendor/pixel/gsans'
do
    if grep -Fq "$forbidden" "$MANIFEST"; then
        fail "forbidden_scaffold_path=$forbidden"
    fi
done

decision_count="$(awk 'NF && $1 !~ /^#/ {c++} END {print c+0}' "$DECISIONS")"
keep_count="$(awk -F '	' 'NF && $1 !~ /^#/ && $3 ~ /^KEEP_/ {c++} END {print c+0}' "$DECISIONS")"
drop_count="$(awk -F '	' 'NF && $1 !~ /^#/ && $3 ~ /^DROP_/ {c++} END {print c+0}' "$DECISIONS")"
[[ "$decision_count" == 12 ]] || fail "scaffold_decision_count=$decision_count"
[[ "$keep_count" == 5 ]] || fail "scaffold_keep_count=$keep_count"
[[ "$drop_count" == 7 ]] || fail "scaffold_drop_count=$drop_count"

runtime_count="$(awk 'NF && $1 !~ /^#/ {c++} END {print c+0}' "$RUNTIME_ALLOWLIST")"
[[ "$runtime_count" == 0 ]] || fail "runtime_allowlist_count=$runtime_count"

grep -Fq 'E1 deliberately adds no Sable product apps' "$DELTA" ||
    fail engineering_delta_scope_marker_missing
if grep -Eq 'PRODUCT_(PACKAGES|COPY_FILES|SYSTEM_DEFAULT_PROPERTIES)|SELINUX_IGNORE_NEVERALLOWS' "$DELTA"; then
    fail engineering_delta_must_remain_composition_neutral
fi

grep -Fq 'EXPECTED_HEAD = "39ba82ef89ff5bf6b22ca8f147dbf317bffa20ed"' "$HARDENER" ||
    fail hardener_head_missing
grep -Fq 'EXPECTED_BASE_BLOB = "a29e402009d449150f1216e5d517ec0c9b36bfbd"' "$HARDENER" ||
    fail hardener_base_blob_missing
grep -Fq 'EXPECTED_POST_BLOB = "58edfb8713e9a1392daaf5bbf0d07778efd6d669"' "$HARDENER" ||
    fail hardener_post_blob_missing
grep -Fq 'N1D_C3B_PHH_BASE_SECURITY_REDUCTIONS=PASS' "$HARDENER" ||
    fail hardener_pass_marker_missing

hardener_blob="$(git hash-object "$HARDENER")"
[[ "$hardener_blob" == 9fdfeb59ab7826615e8c0a44ea105dfc4b7e0679 ]] ||
    fail "hardener_blob=$hardener_blob"

transform_count="$(grep -c '^        "drop_' "$HARDENER" || true)"
[[ "$transform_count" == 14 ]] || fail "hardener_transform_count=$transform_count"

for token in     'SELINUX_IGNORE_NEVERALLOWS := true'     'ro.adb.secure=0'     'persist.sys.usb.config=adb'     'vendor/hardware_overlay/overlay.mk'     'device/phh/treble/sepolicy'     'phh-on-boot.sh'     'phh-securize.sh'     'phh-remotectl'     'phh-ota'     'QcRilAm'     'MtkInCallService'
do
    grep -Fq "$token" "$HARDENER" || fail "hardener_missing_target=$token"
done

patch_1_blob="$(git hash-object "$HOST_PATCH_1")"
patch_2_blob="$(git hash-object "$HOST_PATCH_2")"
[[ "$patch_1_blob" == ce55b543e3e5ff49a9a6921ba752f6aa39d53997 ]] ||
    fail "host_patch_1_blob=$patch_1_blob"
[[ "$patch_2_blob" == 6c74503ab0f000b82b944ad545d90b517d7d6bad ]] ||
    fail "host_patch_2_blob=$patch_2_blob"

scaffold_compat_blob="$(git hash-object "$SCAFFOLD_COMPAT_PATCH")"
[[ "$scaffold_compat_blob" == 21e88ec26ef0b0d5b80abd77ce2d3381c47a1976 ]] ||
    fail "scaffold_compat_blob=$scaffold_compat_blob"
[[ "$(grep -Ec '^diff --git ' "$SCAFFOLD_COMPAT_PATCH")" == 1 ]] ||
    fail scaffold_compat_patch_file_count
grep -Fq 'vendor/lge/hardware/vibrator/1.0/Android.bp' "$SCAFFOLD_COMPAT_PATCH" ||
    fail scaffold_compat_patch_target_missing

phh_lge_patch_blob="$(git hash-object "$PHH_LGE_COMPAT_PATCH")"
[[ "$phh_lge_patch_blob" == d4b63e03a8bc4f9fa589b5bde4965e6e3a4a3155 ]] ||
    fail "phh_lge_patch_blob=$phh_lge_patch_blob"
[[ "$(grep -Ec '^diff --git ' "$PHH_LGE_COMPAT_PATCH")" == 1 ]] ||
    fail phh_lge_patch_file_count
grep -Fq 'cmds/Android.bp' "$PHH_LGE_COMPAT_PATCH" ||
    fail phh_lge_patch_target_missing
grep -Fq 'name: "vibrator-lge"' "$PHH_LGE_COMPAT_PATCH" ||
    fail phh_lge_patch_module_missing
grep -Fq 'vendor.lge.hardware.vibrator@1.0' "$PHH_LGE_COMPAT_PATCH" ||
    fail phh_lge_patch_dependency_missing

compat_count="$(awk -F '\t' 'NF && $1 !~ /^#/ {c++} END {print c+0}' "$COMPAT_PEEL")"
[[ "$compat_count" == 11 ]] || fail "compatibility_peel_row_count=$compat_count"

inventory_count="$(awk -F '\t' 'NF && $1 !~ /^#/ {c++} END {print c+0}' "$CONTROL_PATCH_INVENTORY")"
[[ "$inventory_count" == 369 ]] || fail "control_patch_inventory_count=$inventory_count"

for tier_count in \
    "trebledroid 198" \
    "trebledroid-staging 121" \
    "rom 29" \
    "personal 17" \
    "release-builds 4"
do
    tier="${tier_count%% *}"
    expected="${tier_count##* }"
    actual="$(awk -F '\t' -v tier="$tier" 'NF && $1 !~ /^#/ && $1 == tier {c++} END {print c+0}' "$CONTROL_PATCH_INVENTORY")"
    [[ "$actual" == "$expected" ]] ||
        fail "control_patch_inventory_tier=$tier expected=$expected actual=$actual"
done

verbatim_admitted="$(awk -F '\t' 'NF && $1 !~ /^#/ && $5 ~ /^ADMIT_VERBATIM/ {c++} END {print c+0}' "$CONTROL_PATCH_INVENTORY")"
[[ "$verbatim_admitted" == 0 ]] ||
    fail "control_patch_inventory_verbatim_admitted=$verbatim_admitted"

grep -Fq $'trebledroid-staging\tplatform_hardware_interfaces\t0001-Add-HIDL-vibrator-1.0-interface-for-legacy-vendor-HA.patch' "$CONTROL_PATCH_INVENTORY" ||
    fail control_patch_inventory_lge_hidl_missing
grep -Fq $'REJECT_NON_TITAN\tKnown C3A fix for LG/legacy path; C3B quarantines the non-Titan LGE consumer instead.' "$CONTROL_PATCH_INVENTORY" ||
    fail control_patch_inventory_lge_hidl_decision_missing

for required in \
    $'BM-002\t0002-build-Remove-llkd.patch\tPRODUCT_RUNTIME_POLICY\tREJECT' \
    $'BM-004\t0004-Skip-mounting-my_manifest-on-GSIs.patch\tOEM_RUNTIME_WORKAROUND\tREJECT_NON_TITAN' \
    $'BM-008\t0008-Exclude-AOSP-sample-APN-list-from-GSI-build.patch\tCELLULAR_PRODUCT_POLICY\tREJECT' \
    $'BM-003\t0003-Include-vndk-v28-sepolicy-support.patch\tVNDK_SEPOLICY_COMPAT\tDEFER_ATOMIC_PAIR' \
    $'BM-005\t0005-Disable-Cuttlefish-only-aosp_shared_system_image-mod.patch\tBUILD_GRAPH_COMPAT\tADMIT_E1_NARROW' \
    $'BM-006\t0006-Configure-build-for-GrapheneOS-GSI-apps-and-packages.patch\tGRAPHENE_TREBLE_BUILD_GRAPH\tADMIT_E1_NARROW' \
    $'BM-009\t0009-Do-not-disable-adb-authentication-in-GSI-system_ext-.patch\tSECURITY_HARDENING\tADMIT_E1_NARROW'
do
    grep -Fq "$required" "$COMPAT_PEEL" || fail "compatibility_peel_decision_missing=$required"
done

build_make_patch_1_blob="$(git hash-object "$BUILD_MAKE_COMPAT_PATCH_1")"
build_make_patch_2_blob="$(git hash-object "$BUILD_MAKE_COMPAT_PATCH_2")"
[[ "$build_make_patch_1_blob" == 712f94e01a2f2adfeae831a97322ae8e6c984c44 ]] ||
    fail "build_make_compat_patch_1_blob=$build_make_patch_1_blob"
[[ "$build_make_patch_2_blob" == 83cf451279b0d9ee4f6cd0820b25d744a7f17150 ]] ||
    fail "build_make_compat_patch_2_blob=$build_make_patch_2_blob"
[[ "$(grep -Ec '^diff --git ' "$BUILD_MAKE_COMPAT_PATCH_1")" == 2 ]] ||
    fail build_make_compat_patch_1_file_count
[[ "$(grep -Ec '^diff --git ' "$BUILD_MAKE_COMPAT_PATCH_2")" == 1 ]] ||
    fail build_make_compat_patch_2_file_count

for required in \
    '"TrichromeWebView"' \
    '"TrichromeChrome"' \
    '-        "Browser2"' \
    '-        "Camera2"' \
    '-        "messaging"' \
    '-        "QuickSearchBox"' \
    '+    enabled: false,'
do
    grep -Fq -- "$required" "$BUILD_MAKE_COMPAT_PATCH_1" ||
        fail "build_make_compat_patch_1_missing=$required"
done

grep -Fq -- '-ro.adb.secure=0' "$BUILD_MAKE_COMPAT_PATCH_2" ||
    fail build_make_adb_secure_removal_missing
grep -Fq -- '+# ro.adb.secure=0' "$BUILD_MAKE_COMPAT_PATCH_2" ||
    fail build_make_adb_secure_comment_missing

if grep -Fq -- '-        "apns-full-conf.xml"' "$BUILD_MAKE_COMPAT_PATCH_1"; then
    fail c3b_r2_apn_removal_forbidden
fi
if grep -Fq 'llkd' "$BUILD_MAKE_COMPAT_PATCH_1" "$BUILD_MAKE_COMPAT_PATCH_2"; then
    fail c3b_r2_llkd_mutation_forbidden
fi
if grep -Fq 'my_manifest' "$BUILD_MAKE_COMPAT_PATCH_1" "$BUILD_MAKE_COMPAT_PATCH_2"; then
    fail c3b_r2_oem_mount_workaround_forbidden
fi
if grep -Fq 'PLATFORM_SEPOLICY_COMPAT_VERSIONS' "$BUILD_MAKE_COMPAT_PATCH_1" "$BUILD_MAKE_COMPAT_PATCH_2"; then
    fail c3b_r2_vndk28_half_pair_forbidden
fi

echo "N1D_C3B_CONTROL_PATCH_INVENTORY=PASS count=$inventory_count verbatim_admitted=0"
echo "N1D_C3B_COMPATIBILITY_PEEL_AUDIT=PASS rows=$compat_count"
echo "N1D_C3B_BUILD_MAKE_COMPAT_PATCHES=PASS_EXACT count=2"
echo "N1D_C3B_RESTLESS_LLKD_REMOVAL=PASS_REJECTED"
echo "N1D_C3B_RESTLESS_APN_REMOVAL=PASS_REJECTED"
echo "N1D_C3B_RESTLESS_OPLUS_WORKAROUND=PASS_REJECTED"
echo "N1D_C3B_VNDK28_SEPOLICY=PASS_DEFERRED_ATOMIC_PAIR"

echo "N1D_C3B_TRANSITION_C3A_EVIDENCE=PASS"
echo "N1D_C3B_ACTIVE_PHASE=PASS_C3B_ENGINEERING"
echo "N1D_C3B_GRAPHENE_BASE=PASS_PINNED_1033"
echo "N1D_C3B_SCAFFOLD=PASS_MINIMAL add=5 remove=0 managed=1038"
echo "N1D_C3B_C3A_REMOVE_SET=PASS_NOT_INHERITED"
echo "N1D_C3B_RESTLESS_PATCH_STACK=PASS_ZERO"
echo "N1D_C3B_RUNTIME_PATCH_ALLOWLIST=PASS_ZERO"
echo "N1D_C3B_PHH_RUNTIME_REDUCTION=PASS_EXACT_TRANSFORMS count=14"
echo "N1D_C3B_HOST_LAYOUT_PATCHES=PASS_BUILD_ENVIRONMENT_ONLY count=2"
echo "N1D_C3B_SCAFFOLD_COMPAT=PASS_EXACT_NON_TITAN_LGE_VIBRATOR_QUARANTINE count=2"
echo "N1D_C3B_COMPATIBILITY_PEEL=PASS_R2 rows=11 build_make_patches=2 runtime_allowlist=0"
echo "N1D_C3B_ENGINEERING_BUILD_BOUNDARY=PASS_SYSTEMIMAGE_ONLY"
echo "N1D_C3B_DEVICE_CONTACT=PASS_BLOCKED"
echo "N1D_C3B_FLASH=PASS_BLOCKED"
echo "N1D_C3B_SIGNING=PASS_BLOCKED"
echo "N1D_C3B_RELEASE=PASS_BLOCKED"
echo "N1D_C3B_TRANSITION_CONTRACT=PASS"
