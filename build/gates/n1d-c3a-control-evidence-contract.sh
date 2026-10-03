#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVIDENCE="$ROOT/build/titan2/n1d-c3a-control-evidence.env"
TRANSITION="$ROOT/build/titan2/n1d-c3b-transition.env"

fail() {
    echo "N1D_C3A_CONTROL_EVIDENCE_CONTRACT=FAIL $*" >&2
    exit 1
}

for f in "$EVIDENCE" "$TRANSITION"; do
    [[ -f "$f" ]] || fail "missing_file=$f"
    bash -n "$f" || fail "syntax=$f"
done

require_line() {
    local file="$1"
    local line="$2"
    grep -Fxq "$line" "$file" || fail "missing_line=$line file=$file"
}

for required in     'N1D_C3A_CONTROL_EVIDENCE_VERSION=1'     'N1D_C3A_CONTROL_EVIDENCE_DATE=2026-10-01'     'N1D_C3A_CONTROL_EVIDENCE_STATUS=PASS_SYSTEMIMAGE'     'N1D_C3A_CONTROL_EVIDENCE_PROVENANCE=CANONICAL_BUILD_HOST_BUILD_DRIVER'     'N1D_C3A_REGISTRY_BUILD_SOURCE=e6bcd76885c6048da7cbd9f200a9b1102e6d91a2'     'N1D_C3A_REGISTRY_BUILD_SOURCE_ROLE=POSTBUILD_EVIDENCE_SEAL_COMMIT_NOT_RECORDED_BUILD_START_HEAD'     'N1D_C3A_BUILD_GOAL=systemimage'     'N1D_C3A_BUILD_RESULT=PASS'     'N1D_C3A_EVIDENCE_DIR=/srv/sable-build/evidence/titan2/n1d-c3a-trebledroid-build/20261001T214611Z-trebledroid-systemimage'     'N1D_C3A_SYSTEM_IMG=/srv/sable-build/workspaces/titan2-n1d/out-c3a-td/target/product/tdgsi_arm64_ab/system.img'     'N1D_C3A_SYSTEM_SHA256=4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16'     'N1D_C3A_SYSTEM_BYTES=3146977280'     'N1D_C3A_POSTBUILD_PACKAGING_ARTIFACTS=PASS_ABSENT'     'N1D_C3A_CONTROL_FIDELITY=PUBLIC_FUNCTIONAL_REPRODUCTION'     'N1D_C3A_MANAGED_PROJECT_COUNT=991'     'N1D_C3A_CONTROL_PATCH_COUNT=369'     'N1D_C3A_HOST_LAYOUT_PATCH_COUNT=2'     'N1D_C3A_RELEASE_ELIGIBLE=NO'     'N1D_C3A_DEVICE_CONTACT_AUTHORIZED=NO'     'N1D_C3A_FLASH_AUTHORIZED=NO'     'N1D_C3A_SIGNING_AUTHORIZED=NO'     'N1D_C3B_TRANSITION_PREREQUISITE=SATISFIED_BY_C3A_CONTROL_EVIDENCE'     'N1D_C3A_CONTROL_EVIDENCE=PASS'
do
    require_line "$EVIDENCE" "$required"
done

for required in     'N1D_C3B_C3A_REQUIRED_STATUS=PASS_SYSTEMIMAGE'     'N1D_C3B_C3A_REQUIRED_SYSTEM_SHA256=4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16'     'N1D_C3B_TRANSITION_PREREQUISITE=SATISFIED_BY_C3A_CONTROL_EVIDENCE'     'N1D_C3_CURRENT_ACTIVE_PHASE=C3B_ENGINEERING'     'N1D_C3B_RELEASE_ELIGIBLE=NO'
do
    require_line "$TRANSITION" "$required"
done

for forbidden in     'N1D_C3A_RELEASE_ELIGIBLE=YES'     'N1D_C3A_DEVICE_CONTACT_AUTHORIZED=YES'     'N1D_C3A_FLASH_AUTHORIZED=YES'     'N1D_C3A_SIGNING_AUTHORIZED=YES'
do
    if grep -Fq "$forbidden" "$EVIDENCE"; then
        fail "forbidden_evidence_state=$forbidden"
    fi
done

sha="$(awk -F= '/^N1D_C3A_SYSTEM_SHA256=/ {print $2}' "$EVIDENCE")"
[[ "$sha" =~ ^[0-9a-f]{64}$ ]] || fail "invalid_system_sha256=$sha"

bytes="$(awk -F= '/^N1D_C3A_SYSTEM_BYTES=/ {print $2}' "$EVIDENCE")"
[[ "$bytes" =~ ^[1-9][0-9]*$ ]] || fail "invalid_system_bytes=$bytes"

echo "N1D_C3A_CONTROL_EVIDENCE_SYSTEMIMAGE=PASS sha256=$sha bytes=$bytes"
echo "N1D_C3A_CONTROL_EVIDENCE_NO_PACKAGING=PASS"
echo "N1D_C3A_CONTROL_EVIDENCE_NON_RELEASE=PASS"
echo "N1D_C3B_TRANSITION_PREREQUISITE=PASS_CONSUMED"
echo "N1D_C3A_CONTROL_EVIDENCE_CONTRACT=PASS"
