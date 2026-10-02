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
RUNTIME_ALLOWLIST="$ROOT/build/titan2/n1d-c3b-runtime-patch-allowlist.txt"
HOST_PATCH_1="$ROOT/patches/android-16-n1d-trebledroid/host-layout/0001-soong-ci-tests-skip-out-of-tree-host-paths.patch"
HOST_PATCH_2="$ROOT/patches/android-16-n1d-trebledroid/host-layout/0002-soong-dexpreopt-gen-support-out-of-tree-product-packages.patch"

fail() {
    echo "N1D_C3B_TRANSITION_CONTRACT=FAIL $*" >&2
    exit 1
}

for f in     "$TRANSITION"     "$C3A_EVIDENCE"     "$C3A_EVIDENCE_GATE"     "$SOURCE_LOCK"     "$MANIFEST"     "$DECISIONS"     "$DELTA"     "$RUNTIME_ALLOWLIST"     "$HOST_PATCH_1"     "$HOST_PATCH_2"
do
    [[ -f "$f" ]] || fail "missing_file=$f"
done

for f in "$TRANSITION" "$C3A_EVIDENCE" "$SOURCE_LOCK"; do
    bash -n "$f" || fail "syntax=$f"
done

bash "$C3A_EVIDENCE_GATE"

require_line() {
    local file="$1"
    local line="$2"
    grep -Fxq "$line" "$file" || fail "missing_line=$line file=$file"
}

for required in     'N1D_C3B_TRANSITION_VERSION=1'     'N1D_C3B_TRANSITION_DATE=2026-10-02'     'N1D_C3B_C3A_EVIDENCE_FILE=build/titan2/n1d-c3a-control-evidence.env'     'N1D_C3B_C3A_REQUIRED_STATUS=PASS_SYSTEMIMAGE'     'N1D_C3B_C3A_REQUIRED_SYSTEM_SHA256=4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16'     'N1D_C3B_TRANSITION_PREREQUISITE=SATISFIED_BY_C3A_CONTROL_EVIDENCE'     'N1D_C3_CURRENT_ACTIVE_PHASE=C3B_ENGINEERING'     'N1D_C3B_ROLE=SABLE_MINIMAL_ENGINEERING_BASELINE'     'N1D_C3B_SOURCE_SUBSTRATE=GRAPHENEOS_A16_PINNED'     'N1D_C3B_GRAPHENE_TAG=2026061600'     'N1D_C3B_GRAPHENE_MANIFEST_COMMIT=5d82aa9610855bc0b43b9eb7ca4470d30455cfeb'     'N1D_C3B_GRAPHENE_BASE_PROJECT_COUNT=1033'     'N1D_C3B_WORKSPACE_REL=workspaces/titan2-n1d-c3b'     'N1D_C3B_ANDROID_ROOT_REL=workspaces/titan2-n1d-c3b/android'     'N1D_C3B_OUT_ROOT_REL=workspaces/titan2-n1d-c3b/out-c3b-engineering'     'N1D_C3B_SCAFFOLD_PROJECT_COUNT=3'     'N1D_C3B_REMOVE_PROJECT_COUNT=0'     'N1D_C3B_MANAGED_PROJECT_COUNT=1036'     'N1D_C3B_C3A_REMOVE_SET_INHERITED=NO'     'N1D_C3B_C3A_CONTROL_PATCH_STACK_INHERITED=NO'     'N1D_C3B_RESTLESS_PATCH_COUNT=0'     'N1D_C3B_RUNTIME_PATCH_ALLOWLIST_COUNT=0'     'N1D_C3B_GENERATOR=device/phh/treble/generate.sh'     'N1D_C3B_GENERATOR_CONFIG=sable-c3b-engineering'     'N1D_C3B_GENERATED_PRODUCT=treble_arm64_bvN'     'N1D_C3B_PRODUCT_DEVICE=tdgsi_arm64_ab'     'N1D_C3B_RELEASE_CONFIG=bp4a'     'N1D_C3B_ENGINEERING_VARIANT=userdebug'     'N1D_C3B_ENGINEERING_GOAL=systemimage'     'N1D_C3B_HOST_LAYOUT_PATCH_COUNT=2'     'N1D_C3B_HOST_LAYOUT_PATCH_ROLE=BUILD_ENVIRONMENT_COMPATIBILITY_ONLY'     'N1D_C3B_ENGINEERING_BUILD_AUTHORIZED=YES_SYSTEMIMAGE_ONLY_AFTER_STAGE_AND_PARSE'     'N1D_C3B_TARGET_FILES_AUTHORIZED=NO'     'N1D_C3B_OTA_AUTHORIZED=NO'     'N1D_C3B_DEVICE_CONTACT_AUTHORIZED=NO'     'N1D_C3B_FLASH_AUTHORIZED=NO'     'N1D_C3B_SIGNING_AUTHORIZED=NO'     'N1D_C3B_PRODUCTION_SIGNING_AUTHORIZED=NO'     'N1D_C3B_PHYSICAL_RUNTIME_AUTHORIZED=NO'     'N1D_C3B_RELEASE_ELIGIBLE=NO'     'N1D_C3B_PRODUCT_IDENTITY_STATUS=ENGINEERING_GENERATED_TREBLEDROID_PENDING_E2'     'N1D_C3B_SABLE_PRODUCT_ADMISSION_OWNER=E2_CANONICAL_ENGINEERING_LANE'     'N1D_C3B_TRANSITION=PASS'
do
    require_line "$TRANSITION" "$required"
done

require_line "$C3A_EVIDENCE" 'N1D_C3A_CONTROL_EVIDENCE_STATUS=PASS_SYSTEMIMAGE'
require_line "$C3A_EVIDENCE" 'N1D_C3A_SYSTEM_SHA256=4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16'
require_line "$C3A_EVIDENCE" 'N1D_C3B_TRANSITION_PREREQUISITE=SATISFIED_BY_C3A_CONTROL_EVIDENCE'
require_line "$SOURCE_LOCK" 'N1D_C3B_PATCH_APPLICATION_MODE=REPO_OWNED_REVIEWED_ALLOWLIST'
require_line "$SOURCE_LOCK" 'N1D_C3B_PATCH_TIER_AUTOAPPLY_ALLOWED=NO'
require_line "$SOURCE_LOCK" 'N1D_SELINUX_PERMISSIVE_DOMAINS_ALLOWED=NO'

project_count="$(grep -c '<project ' "$MANIFEST")"
remove_count="$(grep -c '<remove-project ' "$MANIFEST" || true)"
[[ "$project_count" == 3 ]] || fail "scaffold_project_count=$project_count"
[[ "$remove_count" == 0 ]] || fail "scaffold_remove_project_count=$remove_count"

for required in     'path="device/phh/treble"'     'revision="39ba82ef89ff5bf6b22ca8f147dbf317bffa20ed"'     'path="vendor/hardware_overlay"'     'revision="bb0bbb9e1314e5312f718ca1d3ea320137d14370"'     'path="vendor/interfaces"'     'revision="a2271d260e226e8de5cb1e8c15a229dc90c007dd"'     'revision="c8be7de57b80eab61a6f94ec86464a01fb9056f2"'
do
    grep -Fq "$required" "$MANIFEST" || fail "manifest_missing=$required"
done

for forbidden in     'packages/apps/QcRilAm'     'prebuilts/vndk/v28'     'prebuilts/vndk/v29'     'prebuilts/vndk/v30'     'treble_app'     'vendor/apn'     'vendor/lptools'     'vendor/magisk'     'vendor/vndk-tests'     'vendor/cawilliamson-priv'     'vendor/pixel/gsans'
do
    if grep -Fq "$forbidden" "$MANIFEST"; then
        fail "forbidden_scaffold_path=$forbidden"
    fi
done

decision_count="$(awk 'NF && $1 !~ /^#/ {c++} END {print c+0}' "$DECISIONS")"
keep_count="$(awk -F '	' 'NF && $1 !~ /^#/ && $3 ~ /^KEEP_/ {c++} END {print c+0}' "$DECISIONS")"
drop_count="$(awk -F '	' 'NF && $1 !~ /^#/ && $3 ~ /^DROP_/ {c++} END {print c+0}' "$DECISIONS")"
[[ "$decision_count" == 12 ]] || fail "scaffold_decision_count=$decision_count"
[[ "$keep_count" == 3 ]] || fail "scaffold_keep_count=$keep_count"
[[ "$drop_count" == 9 ]] || fail "scaffold_drop_count=$drop_count"

runtime_count="$(awk 'NF && $1 !~ /^#/ {c++} END {print c+0}' "$RUNTIME_ALLOWLIST")"
[[ "$runtime_count" == 0 ]] || fail "runtime_allowlist_count=$runtime_count"

grep -Fq 'SELINUX_IGNORE_NEVERALLOWS := false' "$DELTA" || fail selinux_neverallow_not_restored
grep -Fq 'SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS := $(filter-out device/phh/treble/sepolicy,$(SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS))' "$DELTA" || fail phh_private_sepolicy_not_removed
grep -Fq 'PRODUCT_PACKAGE_OVERLAYS := $(filter-out device/phh/treble/overlay,$(PRODUCT_PACKAGE_OVERLAYS))' "$DELTA" || fail phh_product_overlay_not_removed
grep -Fq 'PRODUCT_EXTRA_VNDK_VERSIONS :=' "$DELTA" || fail legacy_vndk_versions_not_cleared
grep -Fq 'ro.adb.secure=1' "$DELTA" || fail secure_adb_default_missing
for token in     'TrebleApp'     'QcRilAm'     'MtkInCallService'     'mtk-sms-fwk-ready'     'phh-ota'     'resetprop_phh'     'treble-overlay-%'     'device/phh/treble/phh-on-boot.sh:%'     'device/phh/treble/phh-prop-handler.sh:%'     'device/phh/treble/phh-securize.sh:%'     'device/phh/treble/files/ota.sh:%'     'device/phh/treble/remote/%'     'device/phh/treble/twrp/%'
do
    grep -Fq "$token" "$DELTA" || fail "engineering_delta_missing=$token"
done

if grep -Eq '^[[:space:]]*(adb|fastboot)([[:space:]]|$)' "$DELTA"; then
    fail device_command_in_product_delta
fi

patch_1_blob="$(git hash-object "$HOST_PATCH_1")"
patch_2_blob="$(git hash-object "$HOST_PATCH_2")"
[[ "$patch_1_blob" == ce55b543e3e5ff49a9a6921ba752f6aa39d53997 ]]     || fail "host_patch_1_blob=$patch_1_blob"
[[ "$patch_2_blob" == 6c74503ab0f000b82b944ad545d90b517d7d6bad ]]     || fail "host_patch_2_blob=$patch_2_blob"

echo "N1D_C3B_TRANSITION_C3A_EVIDENCE=PASS"
echo "N1D_C3B_ACTIVE_PHASE=PASS_C3B_ENGINEERING"
echo "N1D_C3B_GRAPHENE_BASE=PASS_PINNED_1033"
echo "N1D_C3B_SCAFFOLD=PASS_MINIMAL add=3 remove=0 managed=1036"
echo "N1D_C3B_C3A_REMOVE_SET=PASS_NOT_INHERITED"
echo "N1D_C3B_RESTLESS_PATCH_STACK=PASS_ZERO"
echo "N1D_C3B_RUNTIME_PATCH_ALLOWLIST=PASS_ZERO"
echo "N1D_C3B_PHH_RUNTIME_REDUCTION=PASS_DECLARED"
echo "N1D_C3B_HOST_LAYOUT_PATCHES=PASS_BUILD_ENVIRONMENT_ONLY count=2"
echo "N1D_C3B_ENGINEERING_BUILD_BOUNDARY=PASS_SYSTEMIMAGE_ONLY"
echo "N1D_C3B_DEVICE_CONTACT=PASS_BLOCKED"
echo "N1D_C3B_FLASH=PASS_BLOCKED"
echo "N1D_C3B_SIGNING=PASS_BLOCKED"
echo "N1D_C3B_RELEASE=PASS_BLOCKED"
echo "N1D_C3B_TRANSITION_CONTRACT=PASS"
