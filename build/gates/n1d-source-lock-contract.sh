#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOCK="$ROOT/build/titan2/n1d-source-lock.env"
PRODUCT="$ROOT/build/titan2/n1d-product-contract.env"
TRANSITION="$ROOT/build/titan2/n1d-c3b-transition.env"
C3A_EVIDENCE="$ROOT/build/titan2/n1d-c3a-control-evidence.env"
MANIFEST="$ROOT/build/titan2/n1d-c3b-scaffold-add.xml"
ALLOWLIST="$ROOT/build/titan2/n1d-c3b-runtime-patch-allowlist.txt"

fail() {
    echo "N1D_SOURCE_LOCK_CONTRACT=FAIL $*" >&2
    exit 1
}

for f in "$LOCK" "$PRODUCT" "$TRANSITION" "$C3A_EVIDENCE" "$MANIFEST" "$ALLOWLIST"; do
    [[ -f "$f" ]] || fail "missing_file=$f"
done
for f in "$LOCK" "$PRODUCT" "$TRANSITION" "$C3A_EVIDENCE"; do
    bash -n "$f" || fail "syntax=$f"
done

require_line() {
    local file="$1" line="$2"
    grep -Fxq "$line" "$file" || fail "missing_line=$line file=$file"
}

for required in     'N1D_SOURCE_LOCK_VERSION=2'     'N1D_ANDROID_MAJOR=16'     'N1D_PLATFORM_SDK=36'     'N1D_AOSP_REVISION=android-16.0.0_r4'     'N1D_RELEASE_CONFIG=bp4a'     'N1D_GRAPHENEOS_TAG=2026061600'     'N1D_GRAPHENEOS_TAG_OBJECT=d1d40ac250f31b1a92989d06fa524425c264081d'     'N1D_GRAPHENEOS_MANIFEST_COMMIT=5d82aa9610855bc0b43b9eb7ca4470d30455cfeb'     'N1D_GRAPHENEOS_REVISION_BRANCH=16-qpr2'     'N1D_RESTLESS_TAG=16.0.0-202606230923'     'N1D_RESTLESS_COMMIT=4adc5766f457849ca37e0b318bced65aef5a2233'     'N1D_RESTLESS_DEFAULT_BRANCH_ALLOWED=NO'     'N1D_RESTLESS_DYNAMIC_GRAPHENE_TAG_ALLOWED=NO'     'N1D_RESTLESS_UPSTREAM_SYNC_SCRIPT_ALLOWED=NO'     'N1D_RESTLESS_PUBLIC_ONLY_REQUIRED=YES'     'N1D_RESTLESS_PRIVATE_VENDOR_ALLOWED=NO'     'N1D_PATCH_APPLICATION_MODE=PHASE_SCOPED'     'N1D_C3A_PATCH_APPLICATION_MODE=PINNED_RESTLESS_CONTROL_RECIPE'     'N1D_C3A_PATCH_TIER_AUTOAPPLY_ALLOWED=YES_PINNED_CONTROL_ONLY'     'N1D_C3B_PATCH_APPLICATION_MODE=REPO_OWNED_REVIEWED_ALLOWLIST'     'N1D_C3B_PATCH_TIER_AUTOAPPLY_ALLOWED=NO'     'N1D_ANDROID17_SOURCE_ALLOWED=NO'     'N1D_SOURCE_SYNC_MUST_EMIT_PINNED_MANIFEST=YES'     'N1D_SOURCE_LOCK=PASS'
do
    require_line "$LOCK" "$required"
done

if grep -Eiq '=(latest|stable|main|master)$|resolve.*latest|current.*tag' "$LOCK"; then
    fail floating_source_reference
fi
if grep -Eq 'android-17|2026061800|202609[0-9]{4}' "$LOCK"; then
    fail android17_source_reference_present
fi

for required in     'N1D_PRODUCT_CONTRACT_VERSION=6'     'N1D_SOURCE_SUBSTRATE=GRAPHENEOS_A16_PINNED'     'N1D_RESTLESS_ROLE=C2_CONTROL_C3A_REPRODUCTION_REFERENCE_C3B_PATCH_SOURCE_ONLY'     'N1D_C3_ACTIVE_PHASE=C3B_ENGINEERING'     'N1D_C3_PRODUCT_GENERATION_MODE=PINNED_TREBLEDROID_GENERATOR'     'N1D_PRODUCT_NAME=treble_arm64_bvN'     'N1D_PRODUCT_GENERATOR=device/phh/treble/generate.sh'     'N1D_PRODUCT_GENERATOR_CONFIG=sable-c3b-engineering'     'N1D_C3B_SCAFFOLD_PROJECT_COUNT=5'     'N1D_C3B_REMOVE_PROJECT_COUNT=0'     'N1D_C3B_MANAGED_PROJECT_COUNT=1038'     'N1D_C3B_RESTLESS_PATCH_COUNT=0'     'N1D_RUNTIME_PATCH_ALLOWLIST_COUNT=0'     'N1D_C3_RELEASE_ELIGIBLE=NO'     'N1D_PRODUCT_CONTRACT=PASS'
do
    require_line "$PRODUCT" "$required"
done

for required in     'N1D_C3_CURRENT_ACTIVE_PHASE=C3B_ENGINEERING'     'N1D_C3B_GRAPHENE_TAG=2026061600'     'N1D_C3B_GRAPHENE_MANIFEST_COMMIT=5d82aa9610855bc0b43b9eb7ca4470d30455cfeb'     'N1D_C3B_GRAPHENE_BASE_PROJECT_COUNT=1033'     'N1D_C3B_SCAFFOLD_PROJECT_COUNT=5'     'N1D_C3B_REMOVE_PROJECT_COUNT=0'     'N1D_C3B_MANAGED_PROJECT_COUNT=1038'     'N1D_C3B_RESTLESS_PATCH_COUNT=0'     'N1D_C3B_RUNTIME_PATCH_ALLOWLIST_COUNT=0'     'N1D_C3B_DEVICE_PHH_TREBLE_COMMIT=39ba82ef89ff5bf6b22ca8f147dbf317bffa20ed'     'N1D_C3B_RELEASE_ELIGIBLE=NO'     'N1D_C3B_TRANSITION=PASS'
do
    require_line "$TRANSITION" "$required"
done

require_line "$C3A_EVIDENCE" 'N1D_C3A_CONTROL_EVIDENCE_STATUS=PASS_SYSTEMIMAGE'
require_line "$C3A_EVIDENCE" 'N1D_C3A_SYSTEM_SHA256=4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16'

project_count="$(grep -c '<project ' "$MANIFEST")"
remove_count="$(grep -c '<remove-project ' "$MANIFEST" || true)"
runtime_count="$(awk 'NF && $1 !~ /^#/ {c++} END {print c+0}' "$ALLOWLIST")"
[[ "$project_count" == 5 ]] || fail "c3b_add_manifest_count=$project_count"
[[ "$remove_count" == 0 ]] || fail "c3b_remove_manifest_count=$remove_count"
[[ "$runtime_count" == 0 ]] || fail "c3b_runtime_patch_count=$runtime_count"

if grep -Fq 'vendor/cawilliamson-priv' "$MANIFEST"; then
    fail private_restless_vendor_present
fi
if grep -Fq 'vendor/magisk' "$MANIFEST"; then
    fail magisk_present
fi

bash "$ROOT/build/gates/n1d-c3-phase-split-contract.sh"
bash "$ROOT/build/gates/n1d-restless-security-boundary-contract.sh"
bash "$ROOT/build/gates/n1d-c3b-transition-contract.sh"

echo "N1D_SOURCE_LOCK_ANDROID16=PASS"
echo "N1D_SOURCE_LOCK_GRAPHENE_PIN=PASS"
echo "N1D_SOURCE_LOCK_RESTLESS_REFERENCE_PIN=PASS"
echo "N1D_SOURCE_LOCK_C3A_EVIDENCE=PASS_SEALED"
echo "N1D_SOURCE_LOCK_C3B_SOURCE_GRAPH=PASS base=1033 add=5 remove=0 managed=1038"
echo "N1D_SOURCE_LOCK_NO_FLOATING_TAG=PASS"
echo "N1D_SOURCE_LOCK_PUBLIC_ONLY=PASS"
echo "N1D_SOURCE_LOCK_C3B_PATCH_POLICY=PASS_REVIEWED_ALLOWLIST_ONLY"
echo "N1D_SOURCE_LOCK_RELEASE_RUNTIME_ADMISSION=PASS_ZERO"
echo "N1D_SOURCE_LOCK_PRODUCT_GRAPH_ALIGNMENT=PASS_C3B_ACTIVE"
echo "N1D_SOURCE_LOCK_CONTRACT=PASS"
