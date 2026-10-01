#!/usr/bin/env bash
# Titan 2 N1D fresh-source preparation.
#
# Actions are deliberately separated so a read-only/offline preflight cannot
# accidentally become a network sync. This script never builds Android,
# contacts a device, or flashes anything.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STORAGE_PROFILE="$ROOT/build/config/storage.env"
HOST_PROFILE="$ROOT/build/config/host-tools.env"
SOURCE_LOCK="$ROOT/build/titan2/n1d-source-lock.env"
FRESH_PROFILE="$ROOT/build/titan2/n1d-fresh-source.env"
SOURCE_GATE="$ROOT/build/gates/n1d-source-lock-contract.sh"
STORAGE_VERIFY="$ROOT/build/host/verify-storage-root.sh"
DERIVE_C2="$ROOT/build/titan2/derive-n1d-c2-public-manifest.py"

fail() {
    echo "N1D_FRESH_SOURCE=FAIL $*" >&2
    exit 1
}

for required_file in \
    "$STORAGE_PROFILE" \
    "$HOST_PROFILE" \
    "$SOURCE_LOCK" \
    "$FRESH_PROFILE" \
    "$SOURCE_GATE" \
    "$STORAGE_VERIFY" \
    "$DERIVE_C2"
do
    [[ -f "$required_file" ]] || fail "missing_file=$required_file"
done

# shellcheck source=/dev/null
source "$STORAGE_PROFILE"
# shellcheck source=/dev/null
source "$HOST_PROFILE"
# shellcheck source=/dev/null
source "$SOURCE_LOCK"
# shellcheck source=/dev/null
source "$FRESH_PROFILE"

ACTION="${1:-preflight}"
if (($#)); then shift; fi

NETWORK_AUTHORIZED=NO
while (($#)); do
    case "$1" in
        --authorize-network)
            NETWORK_AUTHORIZED=YES
            shift
            ;;
        *)
            fail "unknown_arg=$1"
            ;;
    esac
done

WORKSPACE="$SABLE_BUILD_ROOT/$N1D_ANDROID_WORKSPACE_REL"
ANDROID_ROOT="$SABLE_BUILD_ROOT/$N1D_ANDROID_ROOT_REL"
OUT_C2="$SABLE_BUILD_ROOT/$N1D_OUT_C2_REL"
OUT_C3="$SABLE_BUILD_ROOT/$N1D_OUT_C3_REL"
C2_SEAL="$SABLE_BUILD_ROOT/$N1D_C2_PIN_SEAL_REL"
C2_PACKAGE="$C2_SEAL/$N1D_C2_PIN_PACKAGE_LABEL"
C2_PIN_MANIFEST="$C2_PACKAGE/$N1D_C2_PIN_MANIFEST_NAME"
EVIDENCE_BASE="$SABLE_EVIDENCE_ROOT/titan2/n1d-source-prep"

assert_no_build_device_flash() {
    echo "SOURCE_MUTATION_AUTHORIZED=NO_BY_DEFAULT"
    echo "BUILD_AUTHORIZED=NO"
    echo "DEVICE_CONTACT_AUTHORIZED=NO"
    echo "FLASH_AUTHORIZED=NO"
}

verify_source_identity_contract() {
    bash "$SOURCE_GATE"
    grep -Fxq \
        "N1D_GRAPHENEOS_MANIFEST_COMMIT=$N1D_GRAPHENE_MANIFEST_COMMIT" \
        "$SOURCE_LOCK" ||
        fail "graphene_manifest_commit_profile_mismatch"
    grep -Fxq \
        "N1D_GRAPHENEOS_TAG=${N1D_GRAPHENE_MANIFEST_REF#refs/tags/}" \
        "$SOURCE_LOCK" ||
        fail "graphene_tag_profile_mismatch"
    grep -Fxq \
        "N1D_AOSP_REVISION=$N1D_AOSP_REVISION" \
        "$SOURCE_LOCK" ||
        fail "aosp_revision_profile_mismatch"
    grep -Fxq \
        "N1D_RELEASE_CONFIG=$N1D_RELEASE_CONFIG" \
        "$SOURCE_LOCK" ||
        fail "release_config_profile_mismatch"
}

verify_c2_pin_seal() {
    [[ -d "$C2_SEAL" ]] || fail "c2_pin_seal_missing=$C2_SEAL"
    [[ -f "$C2_SEAL/SHA256SUMS.txt" ]] ||
        fail "c2_pin_seal_checksums_missing"

    local actual
    actual="$(sha256sum "$C2_SEAL/SHA256SUMS.txt" | awk '{print $1}')"
    [[ "$actual" == "$N1D_C2_PIN_SEAL_SHA256" ]] ||
        fail "c2_pin_seal_hash expected=$N1D_C2_PIN_SEAL_SHA256 actual=$actual"

    (
        cd "$C2_SEAL"
        sha256sum -c SHA256SUMS.txt >/dev/null
    ) || fail "c2_pin_seal_content_verification"

    [[ -f "$C2_PIN_MANIFEST" ]] ||
        fail "c2_pin_manifest_missing=$C2_PIN_MANIFEST"
    [[ -f "$C2_PACKAGE/all-project-heads.tsv" ]] ||
        fail "c2_pin_project_heads_missing"

    if grep -n $'\tUNRESOLVED$' "$C2_PACKAGE/all-project-heads.tsv"; then
        fail "c2_pin_contains_unresolved_project_head"
    fi

    echo "N1D_C2_PIN_SEAL=PASS"
    echo "N1D_C2_PIN_MANIFEST=$C2_PIN_MANIFEST"
}

derive_c2_to() {
    local output="$1"
    "$SABLE_PYTHON" "$DERIVE_C2" \
        --input "$C2_PIN_MANIFEST" \
        --output "$output"
}

verify_workspace_scope() {
    [[ "$WORKSPACE" == "$SABLE_WORKSPACES_ROOT/"* ]] ||
        fail "workspace_outside_canonical_root=$WORKSPACE"
    [[ "$ANDROID_ROOT" == "$WORKSPACE/"* ]] ||
        fail "android_root_outside_workspace=$ANDROID_ROOT"

    local parent="$SABLE_WORKSPACES_ROOT"
    [[ -d "$parent" ]] || fail "workspaces_root_missing=$parent"
    [[ -w "$parent" ]] || fail "workspaces_root_not_writable=$parent"

    local build_dev parent_dev
    build_dev="$(stat -c '%d' "$SABLE_BUILD_ROOT")"
    parent_dev="$(stat -c '%d' "$parent")"
    [[ "$build_dev" == "$parent_dev" ]] ||
        fail "workspaces_root_wrong_filesystem build_dev=$build_dev workspace_dev=$parent_dev"

    echo "N1D_WORKSPACE_SCOPE=PASS"
}

verify_no_preexisting_out() {
    local hit
    for hit in "$OUT_C2" "$OUT_C3" "$ANDROID_ROOT/out"; do
        [[ ! -e "$hit" ]] || fail "preexisting_out_forbidden=$hit"
    done

    if [[ -d "$ANDROID_ROOT" ]]; then
        while IFS= read -r hit; do
            [[ -n "$hit" ]] || continue
            fail "preexisting_android_out_forbidden=$hit"
        done < <(
            find "$ANDROID_ROOT" -maxdepth 1 -mindepth 1 \
                -type d -name 'out*' -print 2>/dev/null
        )
    fi

    echo "N1D_PREEXISTING_ANDROID_OUT=PASS_ABSENT"
}

verify_manifest_checkout() {
    [[ -d "$ANDROID_ROOT/.repo/manifests/.git" ]] ||
        fail "manifest_checkout_missing"

    local manifest_head
    manifest_head="$(git -C "$ANDROID_ROOT/.repo/manifests" rev-parse HEAD)"
    [[ "$manifest_head" == "$N1D_GRAPHENE_MANIFEST_COMMIT" ]] ||
        fail "manifest_head expected=$N1D_GRAPHENE_MANIFEST_COMMIT actual=$manifest_head"

    echo "N1D_GRAPHENE_MANIFEST_HEAD=PASS value=$manifest_head"
}

verify_no_local_manifests() {
    local local_dir="$ANDROID_ROOT/.repo/local_manifests"
    if [[ -d "$local_dir" ]] &&
       [[ -n "$(find "$local_dir" -mindepth 1 -maxdepth 1 -type f -print -quit)" ]]
    then
        find "$local_dir" -mindepth 1 -maxdepth 1 -type f -print
        fail "base_sync_local_manifests_present"
    fi
    echo "N1D_BASE_LOCAL_MANIFESTS=PASS_ABSENT"
}

seal_directory() {
    local dir="$1"
    (
        cd "$dir"
        find . -type f ! -name SHA256SUMS.txt -print0 |
            LC_ALL=C sort -z |
            xargs -0 sha256sum > SHA256SUMS.txt
        sha256sum -c SHA256SUMS.txt >/dev/null
    )
    sha256sum "$dir/SHA256SUMS.txt" | awk '{print $1}'
}

preflight() {
    echo "===== TITAN 2 N1D FRESH SOURCE PREFLIGHT ====="
    assert_no_build_device_flash
    echo "NETWORK_FETCH_AUTHORIZED=NO"

    bash "$STORAGE_VERIFY" runtime
    verify_source_identity_contract
    verify_workspace_scope
    verify_no_preexisting_out
    verify_c2_pin_seal

    [[ -x "$SABLE_REPO_TOOL" ]] ||
        fail "canonical_repo_tool_missing=$SABLE_REPO_TOOL"

    "$SABLE_REPO_TOOL" version | head -20

    local tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN
    derive_c2_to "$tmp/c2-public-pinned.xml" >/dev/null
    rm -rf "$tmp"
    trap - RETURN

    if [[ -e "$ANDROID_ROOT" ]]; then
        if [[ -d "$ANDROID_ROOT/.repo" ]]; then
            echo "N1D_ANDROID_ROOT_STATE=INITIALIZED"
        elif [[ -d "$ANDROID_ROOT" ]] &&
             [[ -z "$(find "$ANDROID_ROOT" -mindepth 1 -maxdepth 1 -print -quit)" ]]
        then
            echo "N1D_ANDROID_ROOT_STATE=EMPTY_DIRECTORY"
        else
            fail "android_root_preexists_nonfresh=$ANDROID_ROOT"
        fi
    else
        echo "N1D_ANDROID_ROOT_STATE=ABSENT"
    fi

    echo "N1D_FRESH_SOURCE_PREFLIGHT=PASS"
}

derive_c2_manifest() {
    echo "===== TITAN 2 N1D C2 PUBLIC PIN DERIVATION ====="
    assert_no_build_device_flash
    echo "NETWORK_FETCH_AUTHORIZED=NO"

    bash "$STORAGE_VERIFY" runtime
    verify_source_identity_contract
    verify_c2_pin_seal

    local stamp out manifest seal
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    out="$EVIDENCE_BASE/$stamp-c2-public-pins"
    manifest="$out/c2-public-pinned.xml"
    mkdir -p "$out"

    derive_c2_to "$manifest" | tee "$out/derive.log"

    {
        echo "N1D_C2_PIN_SEAL=$C2_SEAL"
        echo "N1D_C2_PIN_SEAL_SHA256=$N1D_C2_PIN_SEAL_SHA256"
        echo "N1D_C2_PIN_PACKAGE=$C2_PACKAGE"
        echo "N1D_C2_PIN_MANIFEST=$C2_PIN_MANIFEST"
        echo "N1D_C2_PRIVATE_VENDOR_ALLOWED=NO"
        echo "N1D_C2_MUTABLE_REVISION_ALLOWED=NO"
        echo "NETWORK_FETCH_AUTHORIZED=NO"
        echo "BUILD_AUTHORIZED=NO"
        echo "DEVICE_CONTACT_AUTHORIZED=NO"
        echo "FLASH_AUTHORIZED=NO"
    } > "$out/provenance.env"

    seal="$(seal_directory "$out")"
    echo "N1D_C2_PIN_DERIVATION_SEAL_SHA256=$seal"
    echo "N1D_C2_PIN_DERIVATION=PASS"
    echo "EVIDENCE_DIR=$out"
}

require_network_authorization() {
    [[ "$NETWORK_AUTHORIZED" == YES ]] ||
        fail "network_action_requires_--authorize-network"
    echo "NETWORK_FETCH_AUTHORIZED=YES_EXPLICIT"
}

init_base() {
    echo "===== TITAN 2 N1D GRAPHENE BASE INIT ====="
    assert_no_build_device_flash
    require_network_authorization

    bash "$STORAGE_VERIFY" runtime
    verify_source_identity_contract
    verify_workspace_scope
    verify_no_preexisting_out
    verify_c2_pin_seal

    [[ -x "$SABLE_REPO_TOOL" ]] ||
        fail "canonical_repo_tool_missing=$SABLE_REPO_TOOL"

    if [[ -d "$ANDROID_ROOT/.repo" ]]; then
        verify_manifest_checkout
        echo "N1D_GRAPHENE_REPO_INIT=PASS_ALREADY_INITIALIZED"
        return
    fi

    [[ ! -e "$ANDROID_ROOT" ||
       ( -d "$ANDROID_ROOT" &&
          -z "$(find "$ANDROID_ROOT" -mindepth 1 -maxdepth 1 -print -quit)" ) ]] ||
        fail "android_root_not_fresh=$ANDROID_ROOT"

    mkdir -p "$ANDROID_ROOT"
    (
        cd "$ANDROID_ROOT"
        printf 'y\n' |
            "$SABLE_REPO_TOOL" init \
                --depth="$N1D_SOURCE_SYNC_DEPTH" \
                --git-lfs \
                --manifest-url "$N1D_GRAPHENE_MANIFEST_URL" \
                --manifest-branch "$N1D_GRAPHENE_MANIFEST_REF"
    )

    verify_manifest_checkout
    verify_no_local_manifests
    echo "N1D_GRAPHENE_REPO_INIT=PASS"
}

seal_base() {
    echo "===== TITAN 2 N1D GRAPHENE BASE SEAL ====="
    assert_no_build_device_flash
    echo "NETWORK_FETCH_AUTHORIZED=NO"

    bash "$STORAGE_VERIFY" runtime
    verify_source_identity_contract
    verify_workspace_scope
    verify_no_preexisting_out
    verify_manifest_checkout
    verify_no_local_manifests

    [[ -f "$ANDROID_ROOT/build/make/target/product/generic_system_arm64.mk" ]] ||
        fail "generic_system_arm64_missing"
    [[ -f "$ANDROID_ROOT/build/make/target/product/gsi_release.mk" ]] ||
        fail "gsi_release_missing"

    [[ ! -e "$ANDROID_ROOT/device/phh/treble" ]] ||
        fail "c2_treble_source_present_in_base"
    [[ ! -e "$ANDROID_ROOT/vendor/cawilliamson-priv" ]] ||
        fail "private_restless_vendor_present"

    local stamp out dirty_count project_count seal
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    out="$EVIDENCE_BASE/$stamp-graphene-base"
    mkdir -p "$out"

    (
        cd "$ANDROID_ROOT"
        "$SABLE_REPO_TOOL" manifest -r > "$out/repo-manifest-pinned.xml"
        "$SABLE_REPO_TOOL" list > "$out/repo-list.txt"
        "$SABLE_REPO_TOOL" forall -c \
            'printf "%s\t%s\n" "$REPO_PATH" "$(git rev-parse HEAD)"' \
            > "$out/all-project-heads.tsv"

        "$SABLE_REPO_TOOL" forall -c '
            status="$(git status --porcelain --untracked-files=all)"
            if [[ -n "$status" ]]; then
                printf "%s\n" "$REPO_PATH"
            fi
        ' > "$out/dirty-projects.tsv"
    )

    if grep -n $'\tUNRESOLVED$' "$out/all-project-heads.tsv"; then
        fail "base_seal_unresolved_project_head"
    fi

    dirty_count="$(grep -cve '^$' "$out/dirty-projects.tsv" || true)"
    project_count="$(grep -cve '^$' "$out/all-project-heads.tsv" || true)"

    [[ "$dirty_count" == "$N1D_BASE_DIRTY_PROJECT_COUNT_REQUIRED" ]] || {
        cat "$out/dirty-projects.tsv"
        fail "dirty_projects expected=$N1D_BASE_DIRTY_PROJECT_COUNT_REQUIRED actual=$dirty_count"
    }

    {
        echo "N1D_GRAPHENE_MANIFEST_COMMIT=$N1D_GRAPHENE_MANIFEST_COMMIT"
        echo "N1D_GRAPHENE_MANIFEST_REF=$N1D_GRAPHENE_MANIFEST_REF"
        echo "N1D_AOSP_REVISION=$N1D_AOSP_REVISION"
        echo "N1D_RELEASE_CONFIG=$N1D_RELEASE_CONFIG"
        echo "N1D_ANDROID_ROOT=$ANDROID_ROOT"
        echo "N1D_PROJECT_COUNT=$project_count"
        echo "N1D_DIRTY_PROJECT_COUNT=$dirty_count"
        echo "N1D_C2_TREBLE_SOURCE_PRESENT=NO"
        echo "N1D_PRIVATE_RESTLESS_VENDOR_PRESENT=NO"
        echo "BUILD_AUTHORIZED=NO"
        echo "DEVICE_CONTACT_AUTHORIZED=NO"
        echo "FLASH_AUTHORIZED=NO"
    } > "$out/source-state.env"

    cp "$SOURCE_LOCK" "$out/n1d-source-lock.env"
    cp "$FRESH_PROFILE" "$out/n1d-fresh-source.env"

    seal="$(seal_directory "$out")"

    echo "N1D_BASE_PROJECT_COUNT=$project_count"
    echo "N1D_BASE_DIRTY_PROJECT_COUNT=$dirty_count"
    echo "N1D_BASE_MANIFEST_PINNED=PASS"
    echo "N1D_BASE_SOURCE_SEAL_SHA256=$seal"
    echo "N1D_GRAPHENE_BASE_SEAL=PASS"
    echo "EVIDENCE_DIR=$out"
}

sync_base() {
    echo "===== TITAN 2 N1D GRAPHENE BASE SYNC ====="
    assert_no_build_device_flash
    require_network_authorization

    bash "$STORAGE_VERIFY" runtime
    verify_source_identity_contract
    verify_workspace_scope
    verify_no_preexisting_out

    [[ -d "$ANDROID_ROOT/.repo" ]] ||
        fail "repo_not_initialized_run_init_base_first"

    verify_manifest_checkout
    verify_no_local_manifests

    local stamp out rc
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    out="$EVIDENCE_BASE/$stamp-graphene-sync"
    mkdir -p "$out"

    set +e
    (
        cd "$ANDROID_ROOT"
        "$SABLE_REPO_TOOL" sync \
            --jobs="$N1D_SOURCE_SYNC_JOBS" \
            --no-clone-bundle \
            --no-tags
    ) 2>&1 | tee "$out/repo-sync.log"
    rc="${PIPESTATUS[0]}"
    set -e

    echo "REPO_SYNC_RC=$rc" > "$out/sync-result.env"
    [[ "$rc" == 0 ]] || fail "repo_sync_rc=$rc log=$out/repo-sync.log"

    echo "N1D_GRAPHENE_REPO_SYNC=PASS"
    seal_base
}

case "$ACTION" in
    preflight)
        preflight
        ;;
    derive-c2-manifest)
        derive_c2_manifest
        ;;
    init-base)
        init_base
        ;;
    sync-base)
        sync_base
        ;;
    seal-base)
        seal_base
        ;;
    *)
        fail "unknown_action=$ACTION"
        ;;
esac
