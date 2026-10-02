#!/usr/bin/env bash
# Prepare the Titan 2 N1D C3B engineering source graph.
#
# C3B uses a separate Android workspace so the sealed C3A control tree and its
# evidence remain immutable. This driver never builds Android, contacts a
# device, signs an image, or flashes.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STORAGE_PROFILE="$ROOT/build/config/storage.env"
HOST_PROFILE="$ROOT/build/config/host-tools.env"
SOURCE_LOCK="$ROOT/build/titan2/n1d-source-lock.env"
TRANSITION="$ROOT/build/titan2/n1d-c3b-transition.env"
SCAFFOLD_MANIFEST="$ROOT/build/titan2/n1d-c3b-scaffold-add.xml"
ENGINEERING_DELTA="$ROOT/build/titan2/n1d-c3b-engineering.mk"
HARDENER="$ROOT/build/titan2/apply-n1d-c3b-phh-base-hardening.py"
SCAFFOLD_COMPAT_PATCH="$ROOT/patches/android-16-n1d-trebledroid/scaffold-compat/0001-vendor-interfaces-quarantine-lge-vibrator.patch"
PHH_LGE_COMPAT_PATCH="$ROOT/patches/android-16-n1d-trebledroid/scaffold-compat/0002-device-phh-quarantine-vibrator-lge-helper.patch"
BUILD_MAKE_COMPAT_PATCH_1="$ROOT/patches/android-16-n1d-trebledroid/c3b-compat/0001-build-make-graphene-treble-graph.patch"
BUILD_MAKE_COMPAT_PATCH_2="$ROOT/patches/android-16-n1d-trebledroid/c3b-compat/0002-build-make-preserve-adb-auth.patch"
TRANSITION_GATE="$ROOT/build/gates/n1d-c3b-transition-contract.sh"
STORAGE_VERIFY="$ROOT/build/host/verify-storage-root.sh"

fail() {
    echo "N1D_C3B_PREP=FAIL $*" >&2
    exit 1
}

for f in     "$STORAGE_PROFILE"     "$HOST_PROFILE"     "$SOURCE_LOCK"     "$TRANSITION"     "$SCAFFOLD_MANIFEST"     "$ENGINEERING_DELTA"     "$HARDENER"     "$SCAFFOLD_COMPAT_PATCH"     "$PHH_LGE_COMPAT_PATCH"     "$BUILD_MAKE_COMPAT_PATCH_1"     "$BUILD_MAKE_COMPAT_PATCH_2"     "$TRANSITION_GATE"     "$STORAGE_VERIFY"
do
    [[ -f "$f" ]] || fail "missing_file=$f"
done

# shellcheck source=/dev/null
source "$STORAGE_PROFILE"
# shellcheck source=/dev/null
source "$HOST_PROFILE"
# shellcheck source=/dev/null
source "$SOURCE_LOCK"
# shellcheck source=/dev/null
source "$TRANSITION"

ACTION="${1:-preflight}"
if (($#)); then
    shift
fi

NETWORK_AUTHORIZED=NO
SOURCE_MUTATION_AUTHORIZED=NO
while (($#)); do
    case "$1" in
        --authorize-network)
            NETWORK_AUTHORIZED=YES
            shift
            ;;
        --authorize-source-mutation)
            SOURCE_MUTATION_AUTHORIZED=YES
            shift
            ;;
        *)
            fail "unknown_arg=$1"
            ;;
    esac
done

WORKSPACE="$SABLE_BUILD_ROOT/$N1D_C3B_WORKSPACE_REL"
ANDROID_ROOT="$SABLE_BUILD_ROOT/$N1D_C3B_ANDROID_ROOT_REL"
OUT_ROOT="$SABLE_BUILD_ROOT/$N1D_C3B_OUT_ROOT_REL"
EVIDENCE_ROOT="$SABLE_BUILD_ROOT/$N1D_C3B_BASE_EVIDENCE_REL"
LOCAL_MANIFEST="$ANDROID_ROOT/.repo/local_manifests/n1d-c3b-scaffold.xml"
PHH_ROOT="$ANDROID_ROOT/device/phh/treble"
BUILD_MAKE_ROOT="$ANDROID_ROOT/build/make"
STAGED_DELTA="$PHH_ROOT/sable-c3b-engineering.mk"

assert_global_boundaries() {
    echo "BUILD_AUTHORIZED=NO"
    echo "DEVICE_CONTACT_AUTHORIZED=NO"
    echo "FLASH_AUTHORIZED=NO"
    echo "TARGET_FILES_BUILD_AUTHORIZED=NO"
    echo "OTA_BUILD_AUTHORIZED=NO"
    echo "SIGNING_AUTHORIZED=NO"
    echo "RELEASE_ELIGIBLE=NO"
}

require_network_and_mutation() {
    [[ "$NETWORK_AUTHORIZED" == YES ]] ||
        fail "network_action_requires_--authorize-network"
    [[ "$SOURCE_MUTATION_AUTHORIZED" == YES ]] ||
        fail "source_action_requires_--authorize-source-mutation"
    echo "NETWORK_FETCH_AUTHORIZED=YES_EXPLICIT"
    echo "SOURCE_MUTATION_AUTHORIZED=YES_C3B_WORKSPACE_ONLY"
}

verify_workspace_scope() {
    [[ "$WORKSPACE" == "$SABLE_WORKSPACES_ROOT/"* ]] ||
        fail "workspace_outside_canonical_root=$WORKSPACE"
    [[ "$ANDROID_ROOT" == "$WORKSPACE/"* ]] ||
        fail "android_root_outside_workspace=$ANDROID_ROOT"
    [[ "$OUT_ROOT" == "$WORKSPACE/"* ]] ||
        fail "out_root_outside_workspace=$OUT_ROOT"

    local build_dev workspace_dev
    build_dev="$(stat -c '%d' "$SABLE_BUILD_ROOT")"
    workspace_dev="$(stat -c '%d' "$SABLE_WORKSPACES_ROOT")"
    [[ "$build_dev" == "$workspace_dev" ]] ||
        fail "workspace_wrong_filesystem build_dev=$build_dev workspace_dev=$workspace_dev"

    echo "N1D_C3B_WORKSPACE_SCOPE=PASS"
}

verify_manifest_checkout() {
    [[ -d "$ANDROID_ROOT/.repo/manifests/.git" ]] ||
        fail manifest_checkout_missing

    local head
    head="$(git -C "$ANDROID_ROOT/.repo/manifests" rev-parse HEAD)"
    [[ "$head" == "$N1D_C3B_GRAPHENE_MANIFEST_COMMIT" ]] ||
        fail "manifest_head expected=$N1D_C3B_GRAPHENE_MANIFEST_COMMIT actual=$head"

    echo "N1D_C3B_GRAPHENE_MANIFEST_HEAD=PASS value=$head"
}

capture_project_state() {
    local heads="$1"
    local dirty="$2"
    local raw

    raw="$(mktemp)"
    (
        cd "$ANDROID_ROOT"
        "$SABLE_REPO_TOOL" forall -c '
            head="$(git rev-parse HEAD)"
            printf "H\t%s\t%s\n" "$REPO_PATH" "$head"
            status="$(git status --porcelain --untracked-files=all)"
            if [ -n "$status" ]; then
                printf "D\t%s\n" "$REPO_PATH"
            fi
        '
    ) > "$raw"

    awk -F '\t' '$1=="H" {print $2 "\t" $3}' "$raw" > "$heads"
    awk -F '\t' '$1=="D" {print $2}' "$raw" > "$dirty"
    rm -f "$raw"
}

verify_base_clean() {
    local heads dirty count dirty_count

    heads="$(mktemp)"
    dirty="$(mktemp)"
    capture_project_state "$heads" "$dirty"

    count="$(grep -cve '^$' "$heads" || true)"
    dirty_count="$(grep -cve '^$' "$dirty" || true)"

    [[ "$count" == "$N1D_C3B_GRAPHENE_BASE_PROJECT_COUNT" ]] || {
        rm -f "$heads" "$dirty"
        fail "base_project_count expected=$N1D_C3B_GRAPHENE_BASE_PROJECT_COUNT actual=$count"
    }
    [[ "$dirty_count" == 0 ]] || {
        cat "$dirty"
        rm -f "$heads" "$dirty"
        fail "base_dirty_project_count=$dirty_count"
    }

    rm -f "$heads" "$dirty"

    [[ ! -e "$PHH_ROOT" ]] || fail scaffold_present_before_stage
    [[ ! -e "$ANDROID_ROOT/vendor/cawilliamson-priv" ]] ||
        fail private_restless_vendor_present

    echo "N1D_C3B_GRAPHENE_BASE_PROJECT_COUNT=PASS value=$count"
    echo "N1D_C3B_GRAPHENE_BASE_DIRTY=PASS_ZERO"
}

seal_base() {
    verify_manifest_checkout

    if [[ -d "$ANDROID_ROOT/.repo/local_manifests" ]] &&
       [[ -n "$(find "$ANDROID_ROOT/.repo/local_manifests" -mindepth 1 -maxdepth 1 -type f -print -quit)" ]]
    then
        fail base_local_manifest_present
    fi

    verify_base_clean

    local stamp out dirty_count project_count
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    out="$EVIDENCE_ROOT/$stamp-graphene-base"
    mkdir -p "$out"

    (
        cd "$ANDROID_ROOT"
        "$SABLE_REPO_TOOL" manifest -r > "$out/repo-manifest-pinned.xml"
        "$SABLE_REPO_TOOL" list > "$out/repo-list.txt"
    )
    capture_project_state "$out/all-project-heads.tsv" "$out/dirty-projects.tsv"

    project_count="$(grep -cve '^$' "$out/all-project-heads.tsv" || true)"
    dirty_count="$(grep -cve '^$' "$out/dirty-projects.tsv" || true)"

    [[ "$project_count" == "$N1D_C3B_GRAPHENE_BASE_PROJECT_COUNT" ]] ||
        fail "sealed_project_count=$project_count"
    [[ "$dirty_count" == 0 ]] ||
        fail "sealed_dirty_count=$dirty_count"

    {
        echo "N1D_C3B_GRAPHENE_MANIFEST_COMMIT=$N1D_C3B_GRAPHENE_MANIFEST_COMMIT"
        echo "N1D_C3B_PROJECT_COUNT=$project_count"
        echo "N1D_C3B_DIRTY_PROJECT_COUNT=$dirty_count"
        echo "N1D_C3B_C3A_REMOVE_SET_INHERITED=NO"
        echo "N1D_C3B_RESTLESS_PATCH_COUNT=0"
        echo "BUILD_AUTHORIZED=NO"
        echo "DEVICE_CONTACT_AUTHORIZED=NO"
        echo "FLASH_AUTHORIZED=NO"
    } > "$out/source-state.env"

    (
        cd "$out"
        find . -type f ! -name SHA256SUMS.txt -print0 |
            LC_ALL=C sort -z |
            xargs -0 sha256sum > SHA256SUMS.txt
        sha256sum -c SHA256SUMS.txt >/dev/null
    )

    echo "N1D_C3B_GRAPHENE_BASE_SEAL=PASS"
    echo "EVIDENCE_DIR=$out"
}

verify_scaffold_heads() {
    local entries=(
        "device/phh/treble:$N1D_C3B_DEVICE_PHH_TREBLE_COMMIT"
        "prebuilts/vndk/v28:$N1D_C3B_VNDK28_COMMIT"
        "prebuilts/vndk/v29:$N1D_C3B_VNDK29_COMMIT"
        "vendor/interfaces:$N1D_C3B_VENDOR_INTERFACES_COMMIT"
        "vendor/lptools:$N1D_C3B_LPTOOLS_COMMIT"
    )
    local entry path expected actual

    for entry in "${entries[@]}"; do
        path="${entry%%:*}"
        expected="${entry#*:}"
        [[ -e "$ANDROID_ROOT/$path" ]] || fail "scaffold_path_missing=$path"
        actual="$(git -C "$ANDROID_ROOT/$path" rev-parse HEAD)"
        [[ "$actual" == "$expected" ]] ||
            fail "scaffold_head path=$path expected=$expected actual=$actual"
    done

    echo "N1D_C3B_SCAFFOLD_HEADS=PASS_EXACT count=5"
}

verify_dropped_paths_absent() {
    local path
    for path in         packages/apps/QcRilAm         prebuilts/vndk/v30         treble_app         vendor/apn         vendor/hardware_overlay         vendor/magisk         vendor/vndk-tests         vendor/cawilliamson-priv
    do
        [[ ! -e "$ANDROID_ROOT/$path" ]] ||
            fail "dropped_scaffold_path_present=$path"
    done

    echo "N1D_C3B_DROPPED_C3A_SCAFFOLD=PASS_ABSENT"
}

verify_device_phh_generated_state() {
    "$SABLE_PYTHON" "$HARDENER" verify --repo "$PHH_ROOT"

    local status_file line
    local base_seen=0
    status_file="$(mktemp)"
    git -C "$PHH_ROOT" status --porcelain --untracked-files=all > "$status_file"

    [[ -s "$status_file" ]] || {
        rm -f "$status_file"
        fail device_phh_generated_state_missing
    }

    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        case "$line" in
            " M base.mk")
                base_seen=$((base_seen + 1))
                ;;
            " M cmds/Android.bp") ;;
            "?? AndroidProducts.mk") ;;
            "?? sable-c3b-engineering.mk") ;;
            "?? treble_"*.mk) ;;
            *)
                cat "$status_file"
                rm -f "$status_file"
                fail "device_phh_unexpected_generated_state=$line"
                ;;
        esac
    done < "$status_file"

    rm -f "$status_file"

    [[ "$base_seen" == 1 ]] || fail "device_phh_hardened_base_status_count=$base_seen"
    [[ -f "$PHH_ROOT/treble_arm64_bvN.mk" ]] || fail generated_product_missing
    cmp -s "$ENGINEERING_DELTA" "$STAGED_DELTA" ||
        fail staged_engineering_delta_mismatch

    echo "N1D_C3B_GENERATED_PRODUCT_STATE=PASS"
}

verify_optional_phh_lge_vibrator_quarantine_state() {
    local target="$N1D_C3B_DEVICE_PHH_LGE_VIBRATOR_TARGET"
    local patch="$PHH_LGE_COMPAT_PATCH"
    local base_blob patch_blob status numstat expected_numstat

    base_blob="$(git -C "$PHH_ROOT" rev-parse "HEAD:$target")"
    [[ "$base_blob" == "$N1D_C3B_DEVICE_PHH_LGE_VIBRATOR_BASE_BLOB" ]] ||
        fail "device_phh_lge_vibrator_base_blob expected=$N1D_C3B_DEVICE_PHH_LGE_VIBRATOR_BASE_BLOB actual=$base_blob"

    patch_blob="$(git hash-object "$patch")"
    [[ "$patch_blob" == "$N1D_C3B_DEVICE_PHH_LGE_VIBRATOR_QUARANTINE_PATCH_BLOB_SHA" ]] ||
        fail "device_phh_lge_vibrator_patch_blob expected=$N1D_C3B_DEVICE_PHH_LGE_VIBRATOR_QUARANTINE_PATCH_BLOB_SHA actual=$patch_blob"

    status="$(git -C "$PHH_ROOT" status --porcelain --untracked-files=all -- "$target")"
    if [[ -z "$status" ]]; then
        grep -Fq 'name: "vibrator-lge"' "$PHH_ROOT/$target" ||
            fail device_phh_lge_vibrator_clean_module_missing
        echo "N1D_C3B_DEVICE_PHH_LGE_VIBRATOR=PASS_CLEAN_NOT_QUARANTINED"
        return
    fi

    [[ "$status" == " M $target" ]] || {
        printf '%s\n' "$status"
        fail device_phh_lge_vibrator_unexpected_dirty_state
    }
    git -C "$PHH_ROOT" apply --reverse --check "$patch" ||
        fail device_phh_lge_vibrator_reverse_check
    numstat="$(git -C "$PHH_ROOT" diff --numstat -- "$target")"
    printf -v expected_numstat '0\t12\t%s' "$target"
    [[ "$numstat" == "$expected_numstat" ]] ||
        fail "device_phh_lge_vibrator_numstat=$numstat"
    if grep -Fq 'name: "vibrator-lge"' "$PHH_ROOT/$target"; then
        fail device_phh_lge_vibrator_module_still_present
    fi
    if grep -Fq 'vendor.lge.hardware.vibrator@1.0' "$PHH_ROOT/$target"; then
        fail device_phh_lge_vibrator_dependency_still_present
    fi

    echo "N1D_C3B_DEVICE_PHH_LGE_VIBRATOR=PASS_EXACT_QUARANTINE"
}

verify_optional_host_layout_state() {
    local soong="$ANDROID_ROOT/build/soong"
    local status
    status="$(git -C "$soong" status --porcelain --untracked-files=all)"

    if [[ -z "$status" ]]; then
        echo "N1D_C3B_HOST_LAYOUT_STATE=PASS_CLEAN"
        return
    fi

    local file1="ci_tests/ci_test_package_zip.go"
    local file2="dexpreopt/dexpreopt_gen/dexpreopt_gen.go"
    local count blob1 blob2
    count="$(printf '%s\n' "$status" | grep -cve '^$' || true)"
    [[ "$count" == 2 ]] || {
        printf '%s\n' "$status"
        fail "build_soong_dirty_count=$count"
    }

    printf '%s\n' "$status" | grep -Fxq " M $file1" ||
        fail build_soong_primary_fix_missing
    printf '%s\n' "$status" | grep -Fxq " M $file2" ||
        fail build_soong_secondary_fix_missing

    blob1="$(git hash-object "$soong/$file1")"
    blob2="$(git hash-object "$soong/$file2")"
    [[ "$blob1" == "$N1D_C3B_HOST_LAYOUT_PATCH_1_POST_BLOB" ]] ||
        fail "host_layout_1_blob=$blob1"
    [[ "$blob2" == "$N1D_C3B_HOST_LAYOUT_PATCH_2_POST_BLOB" ]] ||
        fail "host_layout_2_blob=$blob2"

    echo "N1D_C3B_HOST_LAYOUT_STATE=PASS_EXACT_PATCHED"
}

verify_optional_vendor_interfaces_quarantine_state() {
    local repo="$ANDROID_ROOT/vendor/interfaces"
    local target="$N1D_C3B_VENDOR_INTERFACES_LGE_VIBRATOR_TARGET"
    local patch="$SCAFFOLD_COMPAT_PATCH"
    local base_blob patch_blob status

    base_blob="$(git -C "$repo" rev-parse "HEAD:$target")"
    [[ "$base_blob" == "$N1D_C3B_VENDOR_INTERFACES_LGE_VIBRATOR_BASE_BLOB" ]] ||
        fail "vendor_interfaces_lge_vibrator_base_blob expected=$N1D_C3B_VENDOR_INTERFACES_LGE_VIBRATOR_BASE_BLOB actual=$base_blob"

    patch_blob="$(git hash-object "$patch")"
    [[ "$patch_blob" == "$N1D_C3B_VENDOR_INTERFACES_LGE_VIBRATOR_QUARANTINE_PATCH_BLOB_SHA" ]] ||
        fail "vendor_interfaces_lge_vibrator_patch_blob expected=$N1D_C3B_VENDOR_INTERFACES_LGE_VIBRATOR_QUARANTINE_PATCH_BLOB_SHA actual=$patch_blob"

    status="$(git -C "$repo" status --porcelain --untracked-files=all)"
    if [[ -z "$status" ]]; then
        [[ -f "$repo/$target" ]] || fail vendor_interfaces_lge_vibrator_target_missing_clean
        echo "N1D_C3B_VENDOR_INTERFACES_LGE_VIBRATOR=PASS_CLEAN_NOT_QUARANTINED"
        return
    fi

    [[ "$status" == " D $target" ]] || {
        printf '%s\n' "$status"
        fail vendor_interfaces_unexpected_dirty_state
    }
    [[ ! -e "$repo/$target" ]] || fail vendor_interfaces_lge_vibrator_target_still_present
    git -C "$repo" apply --reverse --check "$patch" ||
        fail vendor_interfaces_lge_vibrator_reverse_check

    echo "N1D_C3B_VENDOR_INTERFACES_LGE_VIBRATOR=PASS_EXACT_QUARANTINE"
}

verify() {
    echo "===== TITAN 2 N1D C3B ENGINEERING VERIFY ====="
    assert_global_boundaries
    echo "NETWORK_FETCH_AUTHORIZED=NO"
    echo "SOURCE_MUTATION_AUTHORIZED=NO"

    bash "$STORAGE_VERIFY" runtime
    bash "$TRANSITION_GATE"
    verify_workspace_scope
    verify_manifest_checkout

    [[ -f "$LOCAL_MANIFEST" ]] || fail scaffold_local_manifest_missing
    cmp -s "$SCAFFOLD_MANIFEST" "$LOCAL_MANIFEST" ||
        fail scaffold_local_manifest_mismatch

    local count heads_file dirty_file dirty_count
    heads_file="$(mktemp)"
    dirty_file="$(mktemp)"
    capture_project_state "$heads_file" "$dirty_file"
    count="$(grep -cve '^$' "$heads_file" || true)"
    [[ "$count" == "$N1D_C3B_MANAGED_PROJECT_COUNT" ]] || {
        rm -f "$heads_file" "$dirty_file"
        fail "managed_project_count expected=$N1D_C3B_MANAGED_PROJECT_COUNT actual=$count"
    }

    verify_scaffold_heads
    verify_dropped_paths_absent
    verify_device_phh_generated_state
    verify_optional_phh_lge_vibrator_quarantine_state
    verify_optional_host_layout_state
    verify_optional_vendor_interfaces_quarantine_state

    dirty_count="$(grep -cve '^$' "$dirty_file" || true)"

    [[ "$dirty_count" -ge 1 && "$dirty_count" -le 3 ]] || {
        cat "$dirty_file"
        rm -f "$heads_file" "$dirty_file"
        fail "dirty_project_count expected=1_to_3 actual=$dirty_count"
    }

    grep -Fxq 'device/phh/treble' "$dirty_file" || {
        cat "$dirty_file"
        rm -f "$heads_file" "$dirty_file"
        fail device_phh_not_dirty_as_expected
    }

    while IFS= read -r dirty_project; do
        [[ -n "$dirty_project" ]] || continue
        case "$dirty_project" in
            device/phh/treble|build/soong|vendor/interfaces) ;;
            *)
                cat "$dirty_file"
                rm -f "$heads_file" "$dirty_file"
                fail "unexpected_dirty_project=$dirty_project"
                ;;
        esac
    done < "$dirty_file"
    rm -f "$heads_file" "$dirty_file"

    echo "N1D_C3B_MANAGED_PROJECT_COUNT=PASS value=$count"
    echo "N1D_C3B_GRAPHENE_REMOVALS=PASS_ZERO"
    echo "N1D_C3B_RESTLESS_PATCHES=PASS_ZERO"
    echo "N1D_C3B_PREP_VERIFY=PASS"
}

preflight() {
    echo "===== TITAN 2 N1D C3B ENGINEERING PREFLIGHT ====="
    assert_global_boundaries
    echo "NETWORK_FETCH_AUTHORIZED=NO"
    echo "SOURCE_MUTATION_AUTHORIZED=NO"

    bash "$STORAGE_VERIFY" runtime
    bash "$TRANSITION_GATE"
    verify_workspace_scope

    [[ -x "$SABLE_REPO_TOOL" ]] ||
        fail "repo_tool_missing=$SABLE_REPO_TOOL"
    [[ -x "$SABLE_PYTHON" ]] ||
        fail "python_missing=$SABLE_PYTHON"
    command -v git >/dev/null 2>&1 || fail git_missing

    if [[ -e "$ANDROID_ROOT" ]]; then
        if [[ -d "$ANDROID_ROOT/.repo" ]]; then
            echo "N1D_C3B_ANDROID_ROOT_STATE=INITIALIZED"
        elif [[ -d "$ANDROID_ROOT" ]] &&
             [[ -z "$(find "$ANDROID_ROOT" -mindepth 1 -maxdepth 1 -print -quit)" ]]
        then
            echo "N1D_C3B_ANDROID_ROOT_STATE=EMPTY_DIRECTORY"
        else
            fail "android_root_preexists_nonworkspace=$ANDROID_ROOT"
        fi
    else
        echo "N1D_C3B_ANDROID_ROOT_STATE=ABSENT"
    fi

    echo "N1D_C3B_ENGINEERING_PREFLIGHT=PASS"
}

init_base() {
    echo "===== TITAN 2 N1D C3B GRAPHENE INIT ====="
    assert_global_boundaries
    require_network_and_mutation

    bash "$STORAGE_VERIFY" runtime
    bash "$TRANSITION_GATE"
    verify_workspace_scope

    if [[ -d "$ANDROID_ROOT/.repo" ]]; then
        verify_manifest_checkout
        echo "N1D_C3B_GRAPHENE_INIT=PASS_ALREADY_INITIALIZED"
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
            "$SABLE_REPO_TOOL" init                 --depth=1                 --manifest-url "$N1D_GRAPHENEOS_MANIFEST_REPO"                 --manifest-branch "refs/tags/$N1D_C3B_GRAPHENE_TAG"
    )

    verify_manifest_checkout
    echo "N1D_C3B_GRAPHENE_INIT=PASS"
}

sync_base() {
    echo "===== TITAN 2 N1D C3B GRAPHENE SYNC ====="
    assert_global_boundaries
    require_network_and_mutation

    bash "$STORAGE_VERIFY" runtime
    bash "$TRANSITION_GATE"
    verify_workspace_scope
    verify_manifest_checkout

    if [[ -d "$ANDROID_ROOT/.repo/local_manifests" ]] &&
       [[ -n "$(find "$ANDROID_ROOT/.repo/local_manifests" -mindepth 1 -maxdepth 1 -type f -print -quit)" ]]
    then
        fail base_sync_local_manifest_present
    fi

    (
        cd "$ANDROID_ROOT"
        "$SABLE_REPO_TOOL" sync             --jobs=8             --no-clone-bundle             --no-tags
    )

    verify_base_clean
    seal_base
    echo "N1D_C3B_GRAPHENE_SYNC=PASS"
}

stage() {
    echo "===== TITAN 2 N1D C3B MINIMAL SCAFFOLD STAGE ====="
    assert_global_boundaries
    require_network_and_mutation

    bash "$STORAGE_VERIFY" runtime
    bash "$TRANSITION_GATE"
    verify_workspace_scope
    verify_manifest_checkout

    if [[ -e "$LOCAL_MANIFEST" ]]; then
        cmp -s "$SCAFFOLD_MANIFEST" "$LOCAL_MANIFEST" ||
            fail existing_scaffold_local_manifest_mismatch
        verify
        echo "N1D_C3B_SCAFFOLD_STAGE=PASS_ALREADY_STAGED"
        return
    fi

    verify_base_clean

    mkdir -p "$(dirname "$LOCAL_MANIFEST")"
    install -m 0644 "$SCAFFOLD_MANIFEST" "$LOCAL_MANIFEST"

    (
        cd "$ANDROID_ROOT"
        "$SABLE_REPO_TOOL" sync             --jobs=4             --no-clone-bundle             --no-tags             device/phh/treble             prebuilts/vndk/v28             prebuilts/vndk/v29             vendor/interfaces             vendor/lptools
    )

    verify_scaffold_heads
    verify_dropped_paths_absent

    "$SABLE_PYTHON" "$HARDENER" apply --repo "$PHH_ROOT"

    install -m 0644 "$ENGINEERING_DELTA" "$STAGED_DELTA"

    (
        cd "$PHH_ROOT"
        bash generate.sh "$N1D_C3B_GENERATOR_CONFIG"
    )

    verify
    echo "N1D_C3B_SCAFFOLD_STAGE=PASS"
}

case "$ACTION" in
    preflight)
        preflight
        ;;
    init-base)
        init_base
        ;;
    sync-base)
        sync_base
        ;;
    seal-base)
        echo "===== TITAN 2 N1D C3B GRAPHENE BASE SEAL ====="
        assert_global_boundaries
        echo "NETWORK_FETCH_AUTHORIZED=NO"
        echo "SOURCE_MUTATION_AUTHORIZED=NO"
        bash "$STORAGE_VERIFY" runtime
        bash "$TRANSITION_GATE"
        verify_workspace_scope
        seal_base
        ;;
    stage)
        stage
        ;;
    verify)
        verify
        ;;
    *)
        fail "unknown_action=$ACTION"
        ;;
esac
