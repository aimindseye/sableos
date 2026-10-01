#!/usr/bin/env bash
# Stage the Sable-owned Titan 2 N1D C3 product bundle into the sealed Android base.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STORAGE_PROFILE="$ROOT/build/config/storage.env"
HOST_PROFILE="$ROOT/build/config/host-tools.env"
SOURCE_LOCK="$ROOT/build/titan2/n1d-source-lock.env"
FRESH_PROFILE="$ROOT/build/titan2/n1d-fresh-source.env"
C2_PROFILE="$ROOT/build/titan2/n1d-c2-prebuilt-control.env"
C3_PROFILE="$ROOT/build/titan2/n1d-c3-composition.env"
STORAGE_VERIFY="$ROOT/build/host/verify-storage-root.sh"
SOURCE_GATE="$ROOT/build/gates/n1d-source-lock-contract.sh"

fail() { echo "N1D_C3_PRODUCT_STAGE=FAIL $*" >&2; exit 1; }

for f in "$STORAGE_PROFILE" "$HOST_PROFILE" "$SOURCE_LOCK" "$FRESH_PROFILE" "$C2_PROFILE" "$C3_PROFILE" "$STORAGE_VERIFY" "$SOURCE_GATE"; do
    [[ -f "$f" ]] || fail "missing_file=$f"
done

# shellcheck source=/dev/null
source "$STORAGE_PROFILE"
# shellcheck source=/dev/null
source "$HOST_PROFILE"
# shellcheck source=/dev/null
source "$SOURCE_LOCK"
# shellcheck source=/dev/null
source "$FRESH_PROFILE"
# shellcheck source=/dev/null
source "$C2_PROFILE"
# shellcheck source=/dev/null
source "$C3_PROFILE"

ACTION="${1:-preflight}"
if (($#)); then shift; fi
SOURCE_MUTATION_AUTHORIZED=NO
while (($#)); do
    case "$1" in
        --authorize-source-mutation) SOURCE_MUTATION_AUTHORIZED=YES; shift ;;
        *) fail "unknown_arg=$1" ;;
    esac
done

ANDROID_ROOT="$SABLE_BUILD_ROOT/$N1D_ANDROID_ROOT_REL"
OUT_C2="$SABLE_BUILD_ROOT/$N1D_OUT_C2_REL"
OUT_C3="$SABLE_BUILD_ROOT/$N1D_OUT_C3_REL"
BASE_SEAL="$SABLE_BUILD_ROOT/$N1D_C3_BASE_SEAL_REL"
BASE_HEADS="$BASE_SEAL/all-project-heads.tsv"
SOURCE_BUNDLE="$ROOT/$N1D_C3_SOURCE_BUNDLE_REL"
STAGE_TARGET="$ANDROID_ROOT/$N1D_C3_STAGE_TARGET_REL"
C2_ARTIFACT="$SABLE_BUILD_ROOT/$N1D_C2_CONTROL_ARTIFACT_REL"
EVIDENCE_ROOT="$SABLE_EVIDENCE_ROOT/titan2/n1d-c3-product-composition"

assert_no_build_device_flash() {
    echo "BUILD_AUTHORIZED=NO"
    echo "NETWORK_FETCH_AUTHORIZED=NO"
    echo "DEVICE_CONTACT_AUTHORIZED=NO"
    echo "FLASH_AUTHORIZED=NO"
    echo "SIGNING_AUTHORIZED=NO"
}

verify_base_seal() {
    [[ -f "$BASE_SEAL/SHA256SUMS.txt" ]] || fail "base_seal_missing=$BASE_SEAL"
    local actual
    actual="$(sha256sum "$BASE_SEAL/SHA256SUMS.txt" | awk '{print $1}')"
    [[ "$actual" == "$N1D_C3_BASE_SEAL_SHA256" ]] || fail "base_seal_hash expected=$N1D_C3_BASE_SEAL_SHA256 actual=$actual"
    (cd "$BASE_SEAL" && sha256sum -c SHA256SUMS.txt >/dev/null) || fail base_seal_content
    [[ -f "$BASE_HEADS" ]] || fail base_heads_missing
    echo "N1D_C3_BASE_SEAL=PASS"
}

verify_control_artifact() {
    [[ -f "$C2_ARTIFACT" ]] || fail "c2_control_missing=$C2_ARTIFACT"
    local size digest
    size="$(stat -c "%s" "$C2_ARTIFACT")"
    [[ "$size" == "$N1D_C2_CONTROL_ASSET_SIZE" ]] || fail "c2_control_size expected=$N1D_C2_CONTROL_ASSET_SIZE actual=$size"
    digest="$(sha256sum "$C2_ARTIFACT" | awk '{print $1}')"
    [[ "$digest" == "$N1D_C2_CONTROL_ASSET_SHA256" ]] || fail "c2_control_sha expected=$N1D_C2_CONTROL_ASSET_SHA256 actual=$digest"
    echo "N1D_C3_C2_CONTROL_BINDING=PASS"
}

capture_heads() {
    local out="$1"
    (cd "$ANDROID_ROOT" && "$SABLE_REPO_TOOL" forall -c 'printf "%s\t%s\n" "$REPO_PATH" "$(git rev-parse HEAD)"') > "$out"
}

capture_dirty() {
    local out="$1"
    (cd "$ANDROID_ROOT" && "$SABLE_REPO_TOOL" forall -c 'status="$(git status --porcelain --untracked-files=all)"; if [ -n "$status" ]; then printf "%s\n" "$REPO_PATH"; fi') > "$out"
}

verify_base_exact() {
    local out_policy="${1:-require-no-c3-out}"
    [[ -d "$ANDROID_ROOT/.repo/manifests/.git" ]] || fail manifest_checkout_missing
    local manifest_head tmp count dirty
    manifest_head="$(git -C "$ANDROID_ROOT/.repo/manifests" rev-parse HEAD)"
    [[ "$manifest_head" == "$N1D_GRAPHENE_MANIFEST_COMMIT" ]] || fail "manifest_head expected=$N1D_GRAPHENE_MANIFEST_COMMIT actual=$manifest_head"
    if [[ -d "$ANDROID_ROOT/.repo/local_manifests" ]] && [[ -n "$(find "$ANDROID_ROOT/.repo/local_manifests" -mindepth 1 -maxdepth 1 -type f -print -quit)" ]]; then
        find "$ANDROID_ROOT/.repo/local_manifests" -mindepth 1 -maxdepth 1 -type f -print
        fail local_manifest_present
    fi
    for path in device/phh/treble packages/apps/QcRilAm prebuilts/vndk/v28 prebuilts/vndk/v29 prebuilts/vndk/v30 treble_app vendor/apn vendor/hardware_overlay vendor/interfaces vendor/lptools vendor/magisk vendor/pixel/gsans vendor/vndk-tests; do
        [[ ! -e "$ANDROID_ROOT/$path" ]] || fail "retired_c2_path_present=$path"
    done
    for path in "$OUT_C2" "$ANDROID_ROOT/out"; do
        [[ ! -e "$path" ]] || fail "preexisting_out=$path"
    done
    case "$out_policy" in
        require-no-c3-out)
            [[ ! -e "$OUT_C3" ]] || fail "preexisting_out=$OUT_C3"
            ;;
        allow-c3-out)
            ;;
        *)
            fail "unknown_out_policy=$out_policy"
            ;;
    esac
    tmp="$(mktemp -d)"
    capture_heads "$tmp/current.tsv"
    capture_dirty "$tmp/dirty.tsv"
    count="$(grep -cve "^$" "$tmp/current.tsv" || true)"
    dirty="$(grep -cve "^$" "$tmp/dirty.tsv" || true)"
    [[ "$count" == "$N1D_C3_BASE_PROJECT_COUNT" ]] || { rm -rf "$tmp"; fail "base_count expected=$N1D_C3_BASE_PROJECT_COUNT actual=$count"; }
    [[ "$dirty" == 0 ]] || { cat "$tmp/dirty.tsv"; rm -rf "$tmp"; fail "base_dirty=$dirty"; }
    LC_ALL=C sort "$BASE_HEADS" > "$tmp/expected.tsv"
    LC_ALL=C sort "$tmp/current.tsv" > "$tmp/current-sorted.tsv"
    cmp -s "$tmp/expected.tsv" "$tmp/current-sorted.tsv" || { diff -u "$tmp/expected.tsv" "$tmp/current-sorted.tsv" || true; rm -rf "$tmp"; fail base_heads_mismatch; }
    rm -rf "$tmp"
    echo "N1D_C3_BASE_PROJECT_COUNT=PASS value=$count"
    echo "N1D_C3_BASE_DIRTY_PROJECT_COUNT=PASS_ZERO"
    echo "N1D_C3_BASE_HEADS=PASS_EXACT"
}

verify_source_bundle() {
    [[ -d "$SOURCE_BUNDLE" ]] || fail "source_bundle_missing=$SOURCE_BUNDLE"
    local count compat_count allow_count
    count="$(find "$SOURCE_BUNDLE" -maxdepth 1 -type f | wc -l | tr -d " ")"
    [[ "$count" == "$N1D_C3_REQUIRED_STAGE_FILE_COUNT" ]] || fail "source_bundle_file_count expected=$N1D_C3_REQUIRED_STAGE_FILE_COUNT actual=$count"
    for name in AndroidProducts.mk sable_titan2_n1d_arm64.mk treble_compat.mk sable_n1d_product_delta.mk restless-patch-allowlist.txt; do
        [[ -f "$SOURCE_BUNDLE/$name" ]] || fail "source_bundle_file_missing=$name"
    done
    compat_count="$(awk 'NF && $1 !~ /^#/ { count++ } END { print count+0 }' "$SOURCE_BUNDLE/treble_compat.mk")"
    allow_count="$(awk 'NF && $1 !~ /^#/ { count++ } END { print count+0 }' "$SOURCE_BUNDLE/restless-patch-allowlist.txt")"
    [[ "$compat_count" == "$N1D_C3_INITIAL_TREBLE_COMPAT_ITEM_COUNT" ]] || fail "treble_compat_count expected=$N1D_C3_INITIAL_TREBLE_COMPAT_ITEM_COUNT actual=$compat_count"
    [[ "$allow_count" == "$N1D_C3_INITIAL_RESTLESS_PATCH_ALLOWLIST_COUNT" ]] || fail "restless_allowlist_count expected=$N1D_C3_INITIAL_RESTLESS_PATCH_ALLOWLIST_COUNT actual=$allow_count"
    echo "N1D_C3_SOURCE_BUNDLE=PASS"
    echo "N1D_C3_INITIAL_TREBLE_COMPAT_ITEM_COUNT=0"
    echo "N1D_C3_INITIAL_RESTLESS_PATCH_ALLOWLIST_COUNT=0"
}

verify_staged_bundle() {
    [[ -d "$STAGE_TARGET" ]] || fail "stage_target_missing=$STAGE_TARGET"
    local count name
    count="$(find "$STAGE_TARGET" -maxdepth 1 -type f | wc -l | tr -d " ")"
    [[ "$count" == "$N1D_C3_REQUIRED_STAGE_FILE_COUNT" ]] || fail "staged_file_count expected=$N1D_C3_REQUIRED_STAGE_FILE_COUNT actual=$count"
    for name in AndroidProducts.mk sable_titan2_n1d_arm64.mk treble_compat.mk sable_n1d_product_delta.mk restless-patch-allowlist.txt; do
        cmp -s "$SOURCE_BUNDLE/$name" "$STAGE_TARGET/$name" || fail "staged_file_mismatch=$name"
    done
    echo "N1D_C3_STAGED_BUNDLE=PASS"
}

verify_refresh_prestate() {
    [[ -d "$STAGE_TARGET" ]] || fail "refresh_stage_target_missing=$STAGE_TARGET"
    local count name current_sha
    count="$(find "$STAGE_TARGET" -maxdepth 1 -type f | wc -l | tr -d " ")"
    [[ "$count" == "$N1D_C3_REQUIRED_STAGE_FILE_COUNT" ]]         || fail "refresh_staged_file_count expected=$N1D_C3_REQUIRED_STAGE_FILE_COUNT actual=$count"

    for name in AndroidProducts.mk treble_compat.mk sable_n1d_product_delta.mk restless-patch-allowlist.txt; do
        cmp -s "$SOURCE_BUNDLE/$name" "$STAGE_TARGET/$name"             || fail "refresh_unexpected_existing_file_drift=$name"
    done

    current_sha="$(sha256sum "$STAGE_TARGET/sable_titan2_n1d_arm64.mk" | awk '{print $1}')"
    [[ "$current_sha" == "$N1D_C3_PREVIOUS_PRODUCT_MK_SHA256" ]]         || fail "refresh_product_prestate expected=$N1D_C3_PREVIOUS_PRODUCT_MK_SHA256 actual=$current_sha"

    echo "N1D_C3_PRODUCT_REFRESH_PRESTATE=PASS"
    echo "N1D_C3_PRODUCT_REFRESH_FILE_COUNT=PASS value=$N1D_C3_REFRESH_FILE_COUNT"
}

preflight() {
    echo "===== TITAN 2 N1D C3 PRODUCT COMPOSITION PREFLIGHT ====="
    echo "SOURCE_MUTATION_AUTHORIZED=NO"
    assert_no_build_device_flash
    bash "$STORAGE_VERIFY" runtime
    bash "$SOURCE_GATE"
    verify_base_seal
    verify_control_artifact
    verify_base_exact
    verify_source_bundle
    [[ ! -e "$STAGE_TARGET" ]] || fail "stage_target_already_present=$STAGE_TARGET"
    echo "N1D_C3_PRODUCT_COMPOSITION_PREFLIGHT=PASS"
}

stage() {
    echo "===== TITAN 2 N1D C3 PRODUCT COMPOSITION STAGE ====="
    [[ "$SOURCE_MUTATION_AUTHORIZED" == YES ]] || fail stage_requires_--authorize-source-mutation
    echo "SOURCE_MUTATION_AUTHORIZED=YES_EXACT_C3_PRODUCT_BUNDLE_ONLY"
    assert_no_build_device_flash
    bash "$STORAGE_VERIFY" runtime
    bash "$SOURCE_GATE"
    verify_base_seal
    verify_control_artifact
    verify_base_exact
    verify_source_bundle
    [[ ! -e "$STAGE_TARGET" ]] || fail "stage_target_already_present=$STAGE_TARGET"
    mkdir -p "$STAGE_TARGET"
    cp -a "$SOURCE_BUNDLE/." "$STAGE_TARGET/"
    verify_staged_bundle
    verify_base_exact
    local stamp out
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    out="$EVIDENCE_ROOT/$stamp-c3-product-stage"
    mkdir -p "$out"
    cp -a "$SOURCE_BUNDLE/." "$out/"
    {
        echo "N1D_C3_PRODUCT_NAME=$N1D_C3_PRODUCT_NAME"
        echo "N1D_C3_STAGE_TARGET=$STAGE_TARGET"
        echo "N1D_C3_BASE_SEAL_SHA256=$N1D_C3_BASE_SEAL_SHA256"
        echo "N1D_C2_CONTROL_ASSET_SHA256=$N1D_C2_CONTROL_ASSET_SHA256"
        echo "N1D_C3_BASE_PROJECT_COUNT=$N1D_C3_BASE_PROJECT_COUNT"
        echo "N1D_C3_INITIAL_TREBLE_COMPAT_ITEM_COUNT=$N1D_C3_INITIAL_TREBLE_COMPAT_ITEM_COUNT"
        echo "N1D_C3_INITIAL_RESTLESS_PATCH_ALLOWLIST_COUNT=$N1D_C3_INITIAL_RESTLESS_PATCH_ALLOWLIST_COUNT"
        echo "BUILD_AUTHORIZED=NO"
        echo "DEVICE_CONTACT_AUTHORIZED=NO"
        echo "FLASH_AUTHORIZED=NO"
        echo "SIGNING_AUTHORIZED=NO"
    } > "$out/stage-state.env"
    (cd "$out" && find . -type f ! -name SHA256SUMS.txt -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > SHA256SUMS.txt && sha256sum -c SHA256SUMS.txt >/dev/null)
    echo "N1D_C3_PRODUCT_STAGE=PASS"
    echo "EVIDENCE_DIR=$out"
}

refresh() {
    echo "===== TITAN 2 N1D C3 PRODUCT COMPOSITION REFRESH ====="
    [[ "$SOURCE_MUTATION_AUTHORIZED" == YES ]] || fail refresh_requires_--authorize-source-mutation
    echo "SOURCE_MUTATION_AUTHORIZED=YES_EXACT_C3_PRODUCT_REFRESH_ONLY"
    assert_no_build_device_flash
    bash "$STORAGE_VERIFY" runtime
    bash "$SOURCE_GATE"
    verify_base_seal
    verify_control_artifact
    verify_base_exact allow-c3-out
    verify_source_bundle
    verify_refresh_prestate

    local stamp out previous_sha
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    out="$EVIDENCE_ROOT/$stamp-c3-product-stage"
    mkdir -p "$out"

    cp -a "$STAGE_TARGET/sable_titan2_n1d_arm64.mk"         "$out/previous-sable_titan2_n1d_arm64.mk"
    previous_sha="$(sha256sum "$out/previous-sable_titan2_n1d_arm64.mk" | awk '{print $1}')"
    [[ "$previous_sha" == "$N1D_C3_PREVIOUS_PRODUCT_MK_SHA256" ]]         || fail "refresh_evidence_prestate_hash=$previous_sha"

    cp -a "$SOURCE_BUNDLE/sable_titan2_n1d_arm64.mk"         "$STAGE_TARGET/sable_titan2_n1d_arm64.mk"

    verify_staged_bundle
    verify_base_exact allow-c3-out

    cp -a "$SOURCE_BUNDLE/." "$out/"
    {
        echo "N1D_C3_PRODUCT_STAGE_MODE=REFRESH"
        echo "N1D_C3_PRODUCT_NAME=$N1D_C3_PRODUCT_NAME"
        echo "N1D_C3_PRODUCT_DEVICE=$N1D_C3_PRODUCT_DEVICE"
        echo "N1D_C3_BUILDING_GSI_VALUE=$N1D_C3_BUILDING_GSI_VALUE"
        echo "N1D_C3_REFRESH_FILE_COUNT=$N1D_C3_REFRESH_FILE_COUNT"
        echo "N1D_C3_PREVIOUS_PRODUCT_MK_SHA256=$N1D_C3_PREVIOUS_PRODUCT_MK_SHA256"
        echo "N1D_C3_STAGE_TARGET=$STAGE_TARGET"
        echo "N1D_C3_BASE_SEAL_SHA256=$N1D_C3_BASE_SEAL_SHA256"
        echo "N1D_C2_CONTROL_ASSET_SHA256=$N1D_C2_CONTROL_ASSET_SHA256"
        echo "BUILD_AUTHORIZED=NO"
        echo "DEVICE_CONTACT_AUTHORIZED=NO"
        echo "FLASH_AUTHORIZED=NO"
        echo "SIGNING_AUTHORIZED=NO"
    } > "$out/stage-state.env"
    (
        cd "$out"
        find . -type f ! -name SHA256SUMS.txt -print0             | LC_ALL=C sort -z             | xargs -0 sha256sum > SHA256SUMS.txt
        sha256sum -c SHA256SUMS.txt >/dev/null
    )

    echo "N1D_C3_PRODUCT_REFRESH=PASS"
    echo "N1D_C3_PRODUCT_STAGE=PASS"
    echo "EVIDENCE_DIR=$out"
}

verify() {
    echo "===== TITAN 2 N1D C3 PRODUCT COMPOSITION VERIFY ====="
    echo "SOURCE_MUTATION_AUTHORIZED=NO"
    assert_no_build_device_flash
    bash "$STORAGE_VERIFY" runtime
    bash "$SOURCE_GATE"
    verify_base_seal
    verify_control_artifact
    verify_base_exact allow-c3-out
    verify_source_bundle
    verify_staged_bundle
    echo "N1D_C3_PRODUCT_COMPOSITION_VERIFY=PASS"
}

case "$ACTION" in
    preflight) preflight ;;
    stage) stage ;;
    refresh) refresh ;;
    verify) verify ;;
    *) fail "unknown_action=$ACTION" ;;
esac
