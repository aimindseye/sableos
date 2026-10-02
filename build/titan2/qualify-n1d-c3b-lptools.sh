#!/usr/bin/env bash
# Focused incremental qualification for the C3B vendor/lptools Android 16 API adaptation.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STORAGE_PROFILE="$ROOT/build/config/storage.env"
TRANSITION="$ROOT/build/titan2/n1d-c3b-transition.env"
PREP="$ROOT/build/titan2/prepare-n1d-c3b-engineering.sh"
STORAGE_VERIFY="$ROOT/build/host/verify-storage-root.sh"
LPTOOLS_COMPAT_PATCH="$ROOT/patches/android-16-n1d-trebledroid/c3b-compat/0003-vendor-lptools-android16-fs-mgr-api.patch"

fail() {
    echo "N1D_C3B_LPTOOLS_QUALIFICATION=FAIL $*" >&2
    exit 1
}

for f in "$STORAGE_PROFILE" "$TRANSITION" "$PREP" "$STORAGE_VERIFY" "$LPTOOLS_COMPAT_PATCH"; do
    [[ -f "$f" ]] || fail "missing_file=$f"
done

# shellcheck source=/dev/null
source "$STORAGE_PROFILE"
# shellcheck source=/dev/null
source "$TRANSITION"

BUILD_COMPAT_MUTATION_AUTHORIZED=NO
JOBS="$(nproc --all)"
OUT_DIR_C3B=""

while (($#)); do
    case "$1" in
        --authorize-build-compat-source-mutation)
            BUILD_COMPAT_MUTATION_AUTHORIZED=YES
            shift
            ;;
        --jobs)
            [[ $# -ge 2 ]] || fail jobs_value_missing
            JOBS="$2"
            shift 2
            ;;
        --out-dir)
            [[ $# -ge 2 ]] || fail out_dir_value_missing
            OUT_DIR_C3B="$2"
            shift 2
            ;;
        *)
            fail "unknown_arg=$1"
            ;;
    esac
done

[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || fail "invalid_jobs=$JOBS"
[[ "$N1D_C3_CURRENT_ACTIVE_PHASE" == C3B_ENGINEERING ]] || fail active_phase_mismatch
[[ "$N1D_C3B_RUNTIME_PATCH_ALLOWLIST_COUNT" == 0 ]] || fail runtime_allowlist_not_zero
[[ "$N1D_C3B_RESTLESS_PATCH_COUNT" == 0 ]] || fail restless_patch_count_not_zero

ANDROID_ROOT="$SABLE_BUILD_ROOT/$N1D_C3B_ANDROID_ROOT_REL"
OUT_ROOT="$SABLE_BUILD_ROOT/$N1D_C3B_OUT_ROOT_REL"
LPTOOLS_ROOT="$ANDROID_ROOT/vendor/lptools"
EVIDENCE_ROOT="$SABLE_EVIDENCE_ROOT/titan2/n1d-c3b-lptools"
LUNCH_TARGET="$N1D_C3B_GENERATED_PRODUCT-$N1D_C3B_RELEASE_CONFIG-$N1D_C3B_ENGINEERING_VARIANT"

echo "===== N1D C3B LPTOOLS FOCUSED QUALIFICATION ====="
echo "BUILD_AUTHORIZED=YES_LPTOOLS_MODULE_ONLY"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "BUILD_COMPAT_SOURCE_MUTATION_AUTHORIZED=$BUILD_COMPAT_MUTATION_AUTHORIZED"
echo "TARGET_FILES_BUILD_AUTHORIZED=NO"
echo "OTA_BUILD_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "SIGNING_AUTHORIZED=NO"
echo "PHYSICAL_RUNTIME_AUTHORIZED=NO"
echo "RELEASE_ELIGIBLE=NO"

bash "$STORAGE_VERIFY" runtime
bash "$PREP" verify

check_lptools_compat_state() {
    local target="$N1D_C3B_LPTOOLS_API_COMPAT_TARGET"
    local head_blob current_blob patch_blob status

    [[ "$(git -C "$LPTOOLS_ROOT" rev-parse HEAD)" == "$N1D_C3B_LPTOOLS_COMMIT" ]] ||
        fail lptools_head_mismatch

    head_blob="$(git -C "$LPTOOLS_ROOT" rev-parse "HEAD:$target")"
    [[ "$head_blob" == "$N1D_C3B_LPTOOLS_API_COMPAT_BASE_BLOB" ]] ||
        fail "lptools_base_blob expected=$N1D_C3B_LPTOOLS_API_COMPAT_BASE_BLOB actual=$head_blob"

    patch_blob="$(git hash-object "$LPTOOLS_COMPAT_PATCH")"
    [[ "$patch_blob" == "$N1D_C3B_LPTOOLS_API_COMPAT_PATCH_BLOB_SHA" ]] ||
        fail "lptools_patch_blob expected=$N1D_C3B_LPTOOLS_API_COMPAT_PATCH_BLOB_SHA actual=$patch_blob"

    current_blob="$(git hash-object "$LPTOOLS_ROOT/$target")"
    if [[ "$current_blob" == "$N1D_C3B_LPTOOLS_API_COMPAT_POST_BLOB" ]]; then
        status="$(git -C "$LPTOOLS_ROOT" status --porcelain --untracked-files=all)"
        [[ "$status" == " M $target" ]] || {
            printf '%s\n' "$status"
            fail lptools_unexpected_dirty_state
        }
        git -C "$LPTOOLS_ROOT" apply --reverse --check "$LPTOOLS_COMPAT_PATCH" ||
            fail lptools_reverse_check
        if grep -Eq 'fs_mgr_get_super_partition_name\([^)]+' "$LPTOOLS_ROOT/$target"; then
            fail lptools_legacy_slot_argument_still_present
        fi
        return 0
    fi

    if [[ "$current_blob" == "$N1D_C3B_LPTOOLS_API_COMPAT_BASE_BLOB" ]]; then
        [[ -z "$(git -C "$LPTOOLS_ROOT" status --porcelain --untracked-files=all)" ]] ||
            fail lptools_dirty_at_base
        return 1
    fi

    fail "lptools_unexpected_blob=$current_blob"
}

if check_lptools_compat_state; then
    echo "N1D_C3B_LPTOOLS_COMPAT=PASS_ALREADY_PRESENT"
else
    [[ "$BUILD_COMPAT_MUTATION_AUTHORIZED" == YES ]] ||
        fail build_compat_patch_requires_--authorize-build-compat-source-mutation
    git -C "$LPTOOLS_ROOT" apply --check "$LPTOOLS_COMPAT_PATCH" ||
        fail lptools_apply_check
    git -C "$LPTOOLS_ROOT" apply "$LPTOOLS_COMPAT_PATCH" ||
        fail lptools_apply
    check_lptools_compat_state || fail lptools_post_apply_state
    echo "N1D_C3B_LPTOOLS_COMPAT=PASS_APPLIED"
fi

bash "$PREP" verify

if [[ -z "$OUT_DIR_C3B" ]]; then
    mapfile -t prior_outs < <(
        find "$OUT_ROOT" -mindepth 1 -maxdepth 1 -type d -name 'build-*' -print 2>/dev/null |
            LC_ALL=C sort
    )
    (("${#prior_outs[@]}" > 0)) || fail prior_c3b_out_missing
    OUT_DIR_C3B="${prior_outs[-1]}"
fi

[[ "$OUT_DIR_C3B" == "$OUT_ROOT/build-"* ]] || fail "out_dir_outside_c3b_build_root=$OUT_DIR_C3B"
[[ -d "$OUT_DIR_C3B" ]] || fail "out_dir_missing=$OUT_DIR_C3B"

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="$EVIDENCE_ROOT/$stamp-lptools"
mkdir -p "$EVIDENCE_DIR"

git -C "$LPTOOLS_ROOT" status --porcelain --untracked-files=all > "$EVIDENCE_DIR/vendor-lptools-status.txt"
git -C "$LPTOOLS_ROOT" diff -- "$N1D_C3B_LPTOOLS_API_COMPAT_TARGET" > "$EVIDENCE_DIR/vendor-lptools.diff"

exec > >(tee "$EVIDENCE_DIR/build.log") 2>&1

(
    cd "$ANDROID_ROOT"
    export OUT_DIR="$OUT_DIR_C3B"

    set +e +u
    # shellcheck source=/dev/null
    source build/envsetup.sh
    envsetup_rc=$?
    set -euo pipefail
    [[ "$envsetup_rc" -eq 0 ]] || fail "envsetup_rc=$envsetup_rc"

    set +e +u
    lunch "$LUNCH_TARGET"
    lunch_rc=$?
    set -euo pipefail
    [[ "$lunch_rc" -eq 0 ]] || fail "lunch_rc=$lunch_rc"

    echo "N1D_C3B_LPTOOLS_BUILD_GOAL=lptools"
    set +e +u
    make lptools -j"$JOBS" 2>&1 | tee "$EVIDENCE_DIR/lptools-command.log"
    build_rc="${PIPESTATUS[0]}"
    set -euo pipefail
    [[ "$build_rc" -eq 0 ]] || fail "lptools_build_rc=$build_rc"
)

check_lptools_compat_state || fail lptools_post_build_state

{
    echo "N1D_C3B_LPTOOLS_BUILD=PASS"
    echo "N1D_C3B_LPTOOLS_HEAD=$N1D_C3B_LPTOOLS_COMMIT"
    echo "N1D_C3B_LPTOOLS_BASE_BLOB=$N1D_C3B_LPTOOLS_API_COMPAT_BASE_BLOB"
    echo "N1D_C3B_LPTOOLS_POST_BLOB=$N1D_C3B_LPTOOLS_API_COMPAT_POST_BLOB"
    echo "N1D_C3B_LPTOOLS_PATCH_BLOB=$N1D_C3B_LPTOOLS_API_COMPAT_PATCH_BLOB_SHA"
    echo "N1D_C3B_RUNTIME_PATCH_ALLOWLIST_COUNT=0"
    echo "N1D_C3B_DEVICE_CONTACT_AUTHORIZED=NO"
    echo "N1D_C3B_RELEASE_ELIGIBLE=NO"
    echo "OUT_DIR=$OUT_DIR_C3B"
} > "$EVIDENCE_DIR/qualification-state.env"

(
    cd "$EVIDENCE_DIR"
    find . -type f ! -name SHA256SUMS.txt ! -name build.log ! -name lptools-command.log -print0 |
        LC_ALL=C sort -z |
        xargs -0 sha256sum > SHA256SUMS.txt
    sha256sum -c SHA256SUMS.txt >/dev/null
)

echo "N1D_C3B_LPTOOLS_API_COMPAT=PASS"
echo "N1D_C3B_LPTOOLS_BUILD=PASS"
echo "OUT_DIR=$OUT_DIR_C3B"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
