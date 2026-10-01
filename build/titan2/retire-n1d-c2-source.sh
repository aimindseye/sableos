#!/usr/bin/env bash
# Retire failed partial C2 source admission and restore the sealed N1D base.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STORAGE_PROFILE="$ROOT/build/config/storage.env"
HOST_PROFILE="$ROOT/build/config/host-tools.env"
SOURCE_LOCK="$ROOT/build/titan2/n1d-source-lock.env"
FRESH_PROFILE="$ROOT/build/titan2/n1d-fresh-source.env"
ADMISSION_PROFILE="$ROOT/build/titan2/n1d-c2-source-admission.env"
CONTROL_PROFILE="$ROOT/build/titan2/n1d-c2-prebuilt-control.env"
STORAGE_VERIFY="$ROOT/build/host/verify-storage-root.sh"
DERIVE="$ROOT/build/titan2/derive-n1d-c2-public-manifest.py"

fail() { echo "N1D_C2_SOURCE_RETIREMENT=FAIL $*" >&2; exit 1; }

for f in "$STORAGE_PROFILE" "$HOST_PROFILE" "$SOURCE_LOCK" "$FRESH_PROFILE" "$ADMISSION_PROFILE" "$CONTROL_PROFILE" "$STORAGE_VERIFY" "$DERIVE"; do
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
source "$ADMISSION_PROFILE"
# shellcheck source=/dev/null
source "$CONTROL_PROFILE"

ACTION="${1:-preflight}"
if (($#)); then shift; fi
[[ "$#" == 0 ]] || fail unknown_args

ANDROID_ROOT="$SABLE_BUILD_ROOT/$N1D_ANDROID_ROOT_REL"
BASE_SEAL="$SABLE_BUILD_ROOT/$N1D_C2_BASE_SEAL_REL"
BASE_HEADS="$BASE_SEAL/all-project-heads.tsv"
HISTORICAL_C2_SEAL="$SABLE_BUILD_ROOT/$N1D_C2_PIN_SEAL_REL"
HISTORICAL_C2_PACKAGE="$HISTORICAL_C2_SEAL/$N1D_C2_PIN_PACKAGE_LABEL"
HISTORICAL_C2_MANIFEST="$HISTORICAL_C2_PACKAGE/$N1D_C2_PIN_MANIFEST_NAME"
LOCAL_MANIFEST="$ANDROID_ROOT/.repo/local_manifests/$N1D_C2_LOCAL_MANIFEST_NAME"
EVIDENCE_ROOT="$SABLE_EVIDENCE_ROOT/titan2/n1d-c2-source-retirement"

derive_ledger() {
    local out="$1"
    "$SABLE_PYTHON" "$DERIVE" \
        --input "$HISTORICAL_C2_MANIFEST" \
        --output "$out/c2-manifest.xml" \
        --remote-prefix "$N1D_C2_REMOTE_PREFIX" \
        --project-tsv "$out/c2-projects.tsv" \
        --preserve-upstream >/dev/null
}

verify_base_subset() {
    local tab path expected actual status checked
    tab="$(printf "\t")"
    checked=0
    while IFS="$tab" read -r path expected; do
        [[ -n "$path" && -n "$expected" ]] || continue
        [[ -d "$ANDROID_ROOT/$path" ]] || fail "base_path_missing=$path"
        actual="$(git -C "$ANDROID_ROOT/$path" rev-parse HEAD)"
        [[ "$actual" == "$expected" ]] || fail "base_head path=$path expected=$expected actual=$actual"
        status="$(git -C "$ANDROID_ROOT/$path" status --porcelain --untracked-files=all)"
        [[ -z "$status" ]] || fail "base_dirty path=$path"
        checked=$((checked + 1))
    done < "$BASE_HEADS"
    [[ "$checked" == "$N1D_C2_BASE_PROJECT_COUNT" ]] || fail "base_count expected=$N1D_C2_BASE_PROJECT_COUNT actual=$checked"
    echo "N1D_C2_SOURCE_RETIREMENT_BASE_HEADS=PASS_EXACT"
    echo "N1D_C2_SOURCE_RETIREMENT_BASE_DIRTY=PASS_ZERO"
}

verify_partial_c2() {
    local ledger="$1" tab path expected remote upstream actual status present
    tab="$(printf "\t")"
    present=0
    while IFS="$tab" read -r path expected remote upstream; do
        [[ -n "$path" && -n "$expected" ]] || continue
        if [[ -e "$ANDROID_ROOT/$path" ]]; then
            [[ -d "$ANDROID_ROOT/$path/.git" || -f "$ANDROID_ROOT/$path/.git" ]] || fail "c2_non_git_path=$path"
            actual="$(git -C "$ANDROID_ROOT/$path" rev-parse HEAD)"
            [[ "$actual" == "$expected" ]] || fail "c2_head path=$path expected=$expected actual=$actual"
            status="$(git -C "$ANDROID_ROOT/$path" status --porcelain --untracked-files=all)"
            [[ -z "$status" ]] || fail "c2_dirty path=$path"
            present=$((present + 1))
        fi
    done < "$ledger"
    echo "N1D_C2_SOURCE_RETIREMENT_EXISTING_C2_PROJECTS=$present"
    echo "N1D_C2_SOURCE_RETIREMENT_C2_STATE=PASS"
}

preflight() {
    echo "===== TITAN 2 N1D C2 SOURCE RETIREMENT PREFLIGHT ====="
    echo "SOURCE_MUTATION_AUTHORIZED=NO"
    echo "NETWORK_FETCH_AUTHORIZED=NO"
    echo "BUILD_AUTHORIZED=NO"
    echo "DEVICE_CONTACT_AUTHORIZED=NO"
    echo "FLASH_AUTHORIZED=NO"
    bash "$STORAGE_VERIFY" runtime
    [[ "$N1D_C2_EXACT_SOURCE_RECONSTRUCTION" == BLOCKED_PUBLIC_SOURCE_OBJECT_UNAVAILABLE ]] || fail source_status
    [[ "$N1D_C2_SOURCE_ADMISSION_RETRY_ALLOWED" == NO ]] || fail source_retry_policy
    [[ -f "$BASE_HEADS" ]] || fail base_heads_missing
    [[ -f "$HISTORICAL_C2_MANIFEST" ]] || fail historical_manifest_missing
    verify_base_subset
    local tmp
    tmp="$(mktemp -d)"
    derive_ledger "$tmp"
    verify_partial_c2 "$tmp/c2-projects.tsv"
    rm -rf "$tmp"
    echo "N1D_C2_SOURCE_RETIREMENT_PREFLIGHT=PASS"
}

retire() {
    echo "===== TITAN 2 N1D C2 SOURCE RETIREMENT ====="
    echo "SOURCE_MUTATION_AUTHORIZED=YES_C2_LOCAL_MANIFEST_AND_EXACT_C2_WORKTREES_ONLY"
    echo "NETWORK_FETCH_AUTHORIZED=NO"
    echo "BUILD_AUTHORIZED=NO"
    echo "DEVICE_CONTACT_AUTHORIZED=NO"
    echo "FLASH_AUTHORIZED=NO"
    bash "$STORAGE_VERIFY" runtime
    [[ "$N1D_C2_EXACT_SOURCE_RECONSTRUCTION" == BLOCKED_PUBLIC_SOURCE_OBJECT_UNAVAILABLE ]] || fail source_status
    [[ "$N1D_C2_SOURCE_ADMISSION_RETRY_ALLOWED" == NO ]] || fail source_retry_policy
    verify_base_subset
    local stamp out tab path expected remote upstream present removed current
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    out="$EVIDENCE_ROOT/$stamp-retirement"
    mkdir -p "$out"
    derive_ledger "$out"
    verify_partial_c2 "$out/c2-projects.tsv"
    if [[ -f "$LOCAL_MANIFEST" ]]; then
        cp "$LOCAL_MANIFEST" "$out/pre-retirement-local-manifest.xml"
    fi
    tab="$(printf "\t")"
    present=0
    removed=0
    while IFS="$tab" read -r path expected remote upstream; do
        [[ -n "$path" && -n "$expected" ]] || continue
        if [[ -e "$ANDROID_ROOT/$path" ]]; then
            present=$((present + 1))
            rm -rf -- "$ANDROID_ROOT/$path"
            [[ ! -e "$ANDROID_ROOT/$path" ]] || fail "c2_path_still_present=$path"
            removed=$((removed + 1))
        fi
    done < "$out/c2-projects.tsv"
    if [[ -e "$LOCAL_MANIFEST" ]]; then
        rm -f -- "$LOCAL_MANIFEST"
    fi
    [[ ! -e "$LOCAL_MANIFEST" ]] || fail local_manifest_still_present
    verify_base_subset
    (
        cd "$ANDROID_ROOT"
        "$SABLE_REPO_TOOL" forall -c 'printf "%s\t%s\n" "$REPO_PATH" "$(git rev-parse HEAD)"' > "$out/current-base-heads.tsv"
    )
    current="$(grep -cve "^$" "$out/current-base-heads.tsv" || true)"
    [[ "$current" == "$N1D_C2_BASE_PROJECT_COUNT" ]] || fail "post_retirement_project_count expected=$N1D_C2_BASE_PROJECT_COUNT actual=$current"
    LC_ALL=C sort "$BASE_HEADS" > "$out/base-expected.tsv"
    LC_ALL=C sort "$out/current-base-heads.tsv" > "$out/base-current.tsv"
    cmp -s "$out/base-expected.tsv" "$out/base-current.tsv" || { diff -u "$out/base-expected.tsv" "$out/base-current.tsv" || true; fail post_retirement_base_mismatch; }
    {
        echo "N1D_C2_EXACT_SOURCE_RECONSTRUCTION=$N1D_C2_EXACT_SOURCE_RECONSTRUCTION"
        echo "N1D_C2_SOURCE_ADMISSION_RETRY_ALLOWED=$N1D_C2_SOURCE_ADMISSION_RETRY_ALLOWED"
        echo "N1D_C2_EXISTING_PROJECTS_BEFORE=$present"
        echo "N1D_C2_REMOVED_PROJECTS=$removed"
        echo "N1D_C2_POST_RETIREMENT_PROJECT_COUNT=$current"
        echo "N1D_C2_CONTROL_MODE=$N1D_C2_CONTROL_MODE"
        echo "BUILD_AUTHORIZED=NO"
        echo "DEVICE_CONTACT_AUTHORIZED=NO"
        echo "FLASH_AUTHORIZED=NO"
    } > "$out/retirement.env"
    (cd "$out" && find . -type f ! -name SHA256SUMS.txt -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > SHA256SUMS.txt && sha256sum -c SHA256SUMS.txt >/dev/null)
    echo "N1D_C2_SOURCE_RETIREMENT_BASE_PROJECT_COUNT=PASS value=$current"
    echo "N1D_C2_SOURCE_RETIREMENT_BASE_HEADS=PASS_EXACT"
    echo "N1D_C2_SOURCE_RETIREMENT=PASS"
    echo "EVIDENCE_DIR=$out"
}

case "$ACTION" in
    preflight) preflight ;;
    retire) retire ;;
    *) fail "unknown_action=$ACTION" ;;
esac

