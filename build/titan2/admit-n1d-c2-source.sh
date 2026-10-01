#!/usr/bin/env bash
# Titan 2 N1D C2 exact public source admission.
# C2 is diagnostic/control-only. No Android build, device contact, or flash.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STORAGE_PROFILE="$ROOT/build/config/storage.env"
HOST_PROFILE="$ROOT/build/config/host-tools.env"
SOURCE_LOCK="$ROOT/build/titan2/n1d-source-lock.env"
FRESH_PROFILE="$ROOT/build/titan2/n1d-fresh-source.env"
ADMISSION_PROFILE="$ROOT/build/titan2/n1d-c2-source-admission.env"
STORAGE_VERIFY="$ROOT/build/host/verify-storage-root.sh"
SOURCE_GATE="$ROOT/build/gates/n1d-source-lock-contract.sh"
DERIVE="$ROOT/build/titan2/derive-n1d-c2-public-manifest.py"
HEAD_VERIFY="$ROOT/build/titan2/verify-n1d-c2-heads.py"

fail() {
    echo "N1D_C2_SOURCE_ADMISSION=FAIL $*" >&2
    exit 1
}

for required in \
    "$STORAGE_PROFILE" \
    "$HOST_PROFILE" \
    "$SOURCE_LOCK" \
    "$FRESH_PROFILE" \
    "$ADMISSION_PROFILE" \
    "$STORAGE_VERIFY" \
    "$SOURCE_GATE" \
    "$DERIVE" \
    "$HEAD_VERIFY"
do
    [[ -f "$required" ]] || fail "missing_file=$required"
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

ANDROID_ROOT="$SABLE_BUILD_ROOT/$N1D_ANDROID_ROOT_REL"
OUT_C2="$SABLE_BUILD_ROOT/$N1D_OUT_C2_REL"
OUT_C3="$SABLE_BUILD_ROOT/$N1D_OUT_C3_REL"
BASE_SEAL="$SABLE_BUILD_ROOT/$N1D_C2_BASE_SEAL_REL"
BASE_HEADS="$BASE_SEAL/all-project-heads.tsv"
BASE_STATE="$BASE_SEAL/source-state.env"
HISTORICAL_C2_SEAL="$SABLE_BUILD_ROOT/$N1D_C2_PIN_SEAL_REL"
HISTORICAL_C2_PACKAGE="$HISTORICAL_C2_SEAL/$N1D_C2_PIN_PACKAGE_LABEL"
HISTORICAL_C2_MANIFEST="$HISTORICAL_C2_PACKAGE/$N1D_C2_PIN_MANIFEST_NAME"
LOCAL_MANIFEST_DIR="$ANDROID_ROOT/.repo/local_manifests"
LOCAL_MANIFEST="$LOCAL_MANIFEST_DIR/$N1D_C2_LOCAL_MANIFEST_NAME"
EVIDENCE_ROOT="$SABLE_EVIDENCE_ROOT/titan2/n1d-c2-source-admission"

assert_no_build_device_flash() {
    echo "BUILD_AUTHORIZED=NO"
    echo "DEVICE_CONTACT_AUTHORIZED=NO"
    echo "FLASH_AUTHORIZED=NO"
}

require_network_authorization() {
    [[ "$NETWORK_AUTHORIZED" == YES ]] ||
        fail "network_action_requires_--authorize-network"
    echo "NETWORK_FETCH_AUTHORIZED=YES_EXPLICIT"
    echo "SOURCE_MUTATION_AUTHORIZED=YES_C2_LOCAL_MANIFEST_AND_13_PROJECT_PATHS_ONLY"
}

verify_no_out() {
    local path
    for path in "$OUT_C2" "$OUT_C3" "$ANDROID_ROOT/out"; do
        [[ ! -e "$path" ]] || fail "preexisting_out_forbidden=$path"
    done
    echo "N1D_C2_BUILD_OUTPUT=PASS_ABSENT"
}

verify_manifest_head() {
    [[ -d "$ANDROID_ROOT/.repo/manifests/.git" ]] ||
        fail "manifest_checkout_missing"
    local actual
    actual="$(git -C "$ANDROID_ROOT/.repo/manifests" rev-parse HEAD)"
    [[ "$actual" == "$N1D_GRAPHENE_MANIFEST_COMMIT" ]] ||
        fail "manifest_head expected=$N1D_GRAPHENE_MANIFEST_COMMIT actual=$actual"
    echo "N1D_C2_GRAPHENE_MANIFEST_HEAD=PASS value=$actual"
}

verify_seal() {
    local dir="$1" expected="$2" label="$3"
    [[ -d "$dir" ]] || fail "${label}_seal_missing=$dir"
    [[ -f "$dir/SHA256SUMS.txt" ]] ||
        fail "${label}_checksums_missing=$dir/SHA256SUMS.txt"
    local actual
    actual="$(sha256sum "$dir/SHA256SUMS.txt" | awk '{print $1}')"
    [[ "$actual" == "$expected" ]] ||
        fail "${label}_seal_hash expected=$expected actual=$actual"
    (
        cd "$dir"
        sha256sum -c SHA256SUMS.txt >/dev/null
    ) || fail "${label}_seal_content_verification"
    echo "${label}_SEAL=PASS"
}

verify_base_seal() {
    verify_seal "$BASE_SEAL" "$N1D_C2_BASE_SEAL_SHA256" N1D_C2_BASE
    [[ -f "$BASE_HEADS" ]] || fail "base_heads_missing=$BASE_HEADS"
    [[ -f "$BASE_STATE" ]] || fail "base_state_missing=$BASE_STATE"
    grep -Fxq "N1D_PROJECT_COUNT=$N1D_C2_BASE_PROJECT_COUNT" "$BASE_STATE" ||
        fail "base_project_count_binding"
    grep -Fxq 'N1D_DIRTY_PROJECT_COUNT=0' "$BASE_STATE" ||
        fail "base_dirty_count_binding"
    grep -Fxq 'N1D_C2_TREBLE_SOURCE_PRESENT=NO' "$BASE_STATE" ||
        fail "base_c2_absence_binding"
    grep -Fxq 'N1D_PRIVATE_RESTLESS_VENDOR_PRESENT=NO' "$BASE_STATE" ||
        fail "base_private_vendor_absence_binding"
    local count
    count="$(grep -cve '^$' "$BASE_HEADS" || true)"
    [[ "$count" == "$N1D_C2_BASE_PROJECT_COUNT" ]] ||
        fail "base_head_count expected=$N1D_C2_BASE_PROJECT_COUNT actual=$count"
    echo "N1D_C2_BASE_EVIDENCE=PASS"
}

verify_historical_c2_seal() {
    verify_seal \
        "$HISTORICAL_C2_SEAL" \
        "$N1D_C2_PIN_SEAL_SHA256" \
        N1D_C2_HISTORICAL
    [[ -f "$HISTORICAL_C2_MANIFEST" ]] ||
        fail "historical_c2_manifest_missing=$HISTORICAL_C2_MANIFEST"
    echo "N1D_C2_HISTORICAL_MANIFEST=PASS"
}

derive_install_manifest() {
    local manifest="$1" ledger="$2"
    "$SABLE_PYTHON" "$DERIVE" \
        --input "$HISTORICAL_C2_MANIFEST" \
        --output "$manifest" \
        --remote-prefix "$N1D_C2_REMOTE_PREFIX" \
        --project-tsv "$ledger"
    [[ "$(grep -c '<project ' "$manifest")" == "$N1D_C2_PROJECT_COUNT" ]] ||
        fail "derived_project_count"
    [[ "$(grep -cve '^$' "$ledger" || true)" == "$N1D_C2_PROJECT_COUNT" ]] ||
        fail "derived_ledger_count"
    if grep -Eiq \
        'cawilliamson|ssh://|git@|revision="(main|master)"|upstream=|dest-branch=' \
        "$manifest"
    then
        fail "derived_manifest_forbidden_token"
    fi
    if grep '<remote ' "$manifest" |
       grep -v "name=\"$N1D_C2_REMOTE_PREFIX" >/dev/null
    then
        fail "derived_manifest_unprefixed_remote"
    fi
    while IFS=}

capture_current_heads() {
    local output="$1"
    (
        cd "$ANDROID_ROOT"
        "$SABLE_REPO_TOOL" forall -c \
            'printf "%s\t%s\n" "$REPO_PATH" "$(git rev-parse HEAD)"'
    ) > "$output"
}

capture_dirty_projects() {
    local output="$1"
    (
        cd "$ANDROID_ROOT"
        "$SABLE_REPO_TOOL" forall -c '
            status="$(git status --porcelain --untracked-files=all)"
            if [ -n "$status" ]; then
                printf "%s\n" "$REPO_PATH"
            fi
        '
    ) > "$output"
}

verify_current_base_exact() {
    verify_manifest_head
    verify_no_out
    if [[ -d "$LOCAL_MANIFEST_DIR" ]] &&
       [[ -n "$(find "$LOCAL_MANIFEST_DIR" -mindepth 1 -maxdepth 1 -type f -print -quit)" ]]
    then
        find "$LOCAL_MANIFEST_DIR" -mindepth 1 -maxdepth 1 -type f -print
        fail "local_manifest_present_before_admission"
    fi
    [[ ! -e "$ANDROID_ROOT/device/phh/treble" ]] ||
        fail "c2_path_present_before_admission=device/phh/treble"
    [[ ! -e "$ANDROID_ROOT/vendor/cawilliamson-priv" ]] ||
        fail "private_vendor_present_before_admission"
    local tmp current_count dirty_count
    tmp="$(mktemp -d)"
    capture_current_heads "$tmp/current-heads.tsv"
    capture_dirty_projects "$tmp/dirty-projects.tsv"
    current_count="$(grep -cve '^$' "$tmp/current-heads.tsv" || true)"
    dirty_count="$(grep -cve '^$' "$tmp/dirty-projects.tsv" || true)"
    [[ "$current_count" == "$N1D_C2_BASE_PROJECT_COUNT" ]] || {
        rm -rf "$tmp"
        fail "current_base_count expected=$N1D_C2_BASE_PROJECT_COUNT actual=$current_count"
    }
    [[ "$dirty_count" == 0 ]] || {
        cat "$tmp/dirty-projects.tsv"
        rm -rf "$tmp"
        fail "current_base_dirty_count=$dirty_count"
    }
    LC_ALL=C sort "$BASE_HEADS" > "$tmp/base-sorted.tsv"
    LC_ALL=C sort "$tmp/current-heads.tsv" > "$tmp/current-sorted.tsv"
    cmp -s "$tmp/base-sorted.tsv" "$tmp/current-sorted.tsv" || {
        diff -u "$tmp/base-sorted.tsv" "$tmp/current-sorted.tsv" || true
        rm -rf "$tmp"
        fail "current_base_heads_do_not_match_seal"
    }
    rm -rf "$tmp"
    echo "N1D_C2_CURRENT_BASE_PROJECT_COUNT=$current_count"
    echo "N1D_C2_CURRENT_BASE_DIRTY_PROJECT_COUNT=$dirty_count"
    echo "N1D_C2_CURRENT_BASE_HEADS=PASS_EXACT"
}

verify_admitted_state() {
    local expected_ledger="$1" out="$2"
    [[ -f "$LOCAL_MANIFEST" ]] ||
        fail "local_manifest_missing=$LOCAL_MANIFEST"
    [[ ! -e "$ANDROID_ROOT/vendor/cawilliamson-priv" ]] ||
        fail "private_vendor_present_after_admission"
    capture_current_heads "$out/current-all-project-heads.tsv"
    capture_dirty_projects "$out/dirty-projects.tsv"
    local dirty_count
    dirty_count="$(grep -cve '^$' "$out/dirty-projects.tsv" || true)"
    [[ "$dirty_count" == 0 ]] || {
        cat "$out/dirty-projects.tsv"
        fail "admitted_dirty_project_count=$dirty_count"
    }
    "$SABLE_PYTHON" "$HEAD_VERIFY" \
        --base "$BASE_HEADS" \
        --current "$out/current-all-project-heads.tsv" \
        --c2 "$expected_ledger" \
        --expected-base-count "$N1D_C2_BASE_PROJECT_COUNT" \
        --expected-c2-count "$N1D_C2_PROJECT_COUNT" \
        --expected-total-count "$N1D_C2_EXPECTED_TOTAL_PROJECT_COUNT"
    (
        cd "$ANDROID_ROOT"
        "$SABLE_REPO_TOOL" manifest -r > "$out/repo-manifest-pinned.xml"
        "$SABLE_REPO_TOOL" list > "$out/repo-list.txt"
    )
    echo "N1D_C2_DIRTY_PROJECT_COUNT=0"
    echo "N1D_C2_PRIVATE_VENDOR=PASS_ABSENT"
    echo "N1D_C2_ADMITTED_STATE=PASS"
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
    echo "===== TITAN 2 N1D C2 SOURCE ADMISSION PREFLIGHT ====="
    echo "SOURCE_MUTATION_AUTHORIZED=NO"
    echo "NETWORK_FETCH_AUTHORIZED=NO"
    assert_no_build_device_flash
    bash "$STORAGE_VERIFY" runtime
    bash "$SOURCE_GATE"
    verify_base_seal
    verify_historical_c2_seal
    verify_current_base_exact
    local tmp
    tmp="$(mktemp -d)"
    derive_install_manifest \
        "$tmp/$N1D_C2_LOCAL_MANIFEST_NAME" \
        "$tmp/c2-projects.tsv"
    rm -rf "$tmp"
    echo "N1D_C2_SOURCE_ADMISSION_PREFLIGHT=PASS"
}

admit() {
    echo "===== TITAN 2 N1D C2 SOURCE ADMISSION ====="
    require_network_authorization
    assert_no_build_device_flash
    bash "$STORAGE_VERIFY" runtime
    bash "$SOURCE_GATE"
    verify_base_seal
    verify_historical_c2_seal
    verify_current_base_exact
    local stamp out staged_manifest ledger rc seal
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    out="$EVIDENCE_ROOT/$stamp-c2-admission"
    mkdir -p "$out"
    staged_manifest="$out/$N1D_C2_LOCAL_MANIFEST_NAME"
    ledger="$out/c2-projects.tsv"
    derive_install_manifest "$staged_manifest" "$ledger"
    mkdir -p "$LOCAL_MANIFEST_DIR"
    [[ ! -e "$LOCAL_MANIFEST" ]] ||
        fail "local_manifest_already_exists=$LOCAL_MANIFEST"
    cp "$staged_manifest" "$LOCAL_MANIFEST"
    mapfile -t project_paths < <(cut -f1 "$ledger")
    [[ "${#project_paths[@]}" == "$N1D_C2_PROJECT_COUNT" ]] ||
        fail "project_path_count expected=$N1D_C2_PROJECT_COUNT actual=${#project_paths[@]}"
    set +e
    (
        cd "$ANDROID_ROOT"
        "$SABLE_REPO_TOOL" sync \
            --jobs="$N1D_C2_SYNC_JOBS" \
            --no-clone-bundle \
            --no-tags \
            "${project_paths[@]}"
    ) 2>&1 | tee "$out/repo-sync-c2.log"
    rc="${PIPESTATUS[0]}"
    set -e
    echo "REPO_SYNC_C2_RC=$rc" > "$out/sync-result.env"
    [[ "$rc" == 0 ]] ||
        fail "c2_repo_sync_rc=$rc log=$out/repo-sync-c2.log"
    verify_admitted_state "$ledger" "$out"
    {
        echo "N1D_C2_BASE_SEAL=$BASE_SEAL"
        echo "N1D_C2_BASE_SEAL_SHA256=$N1D_C2_BASE_SEAL_SHA256"
        echo "N1D_C2_HISTORICAL_SEAL=$HISTORICAL_C2_SEAL"
        echo "N1D_C2_HISTORICAL_SEAL_SHA256=$N1D_C2_PIN_SEAL_SHA256"
        echo "N1D_C2_LOCAL_MANIFEST=$LOCAL_MANIFEST"
        echo "N1D_C2_PROJECT_COUNT=$N1D_C2_PROJECT_COUNT"
        echo "N1D_C2_TOTAL_PROJECT_COUNT=$N1D_C2_EXPECTED_TOTAL_PROJECT_COUNT"
        echo "N1D_C2_PRODUCT_ROLE=$N1D_C2_PRODUCT_ROLE"
        echo "BUILD_AUTHORIZED=NO"
        echo "DEVICE_CONTACT_AUTHORIZED=NO"
        echo "FLASH_AUTHORIZED=NO"
    } > "$out/source-state.env"
    cp "$SOURCE_LOCK" "$out/n1d-source-lock.env"
    cp "$FRESH_PROFILE" "$out/n1d-fresh-source.env"
    cp "$ADMISSION_PROFILE" "$out/n1d-c2-source-admission.env"
    seal="$(seal_directory "$out")"
    echo "N1D_C2_SOURCE_ADMISSION_SEAL_SHA256=$seal"
    echo "N1D_C2_SOURCE_ADMISSION=PASS"
    echo "EVIDENCE_DIR=$out"
}

case "$ACTION" in
    preflight)
        preflight
        ;;
    admit)
        admit
        ;;
    *)
        fail "unknown_action=$ACTION"
        ;;
esac

\t' read -r path revision remote; do
        [[ -n "$path" && -n "$revision" && -n "$remote" ]] ||
            fail "derived_ledger_bad_row"
        [[ "$revision" =~ ^[0-9a-f]{40}$ ]] ||
            fail "derived_revision_not_pinned path=$path revision=$revision"
        [[ "$remote" == "$N1D_C2_REMOTE_PREFIX"* ]] ||
            fail "derived_remote_not_prefixed path=$path remote=$remote"
        if grep -Fq -- "$path"}

capture_current_heads() {
    local output="$1"
    (
        cd "$ANDROID_ROOT"
        "$SABLE_REPO_TOOL" forall -c \
            'printf "%s\t%s\n" "$REPO_PATH" "$(git rev-parse HEAD)"'
    ) > "$output"
}

capture_dirty_projects() {
    local output="$1"
    (
        cd "$ANDROID_ROOT"
        "$SABLE_REPO_TOOL" forall -c '
            status="$(git status --porcelain --untracked-files=all)"
            if [ -n "$status" ]; then
                printf "%s\n" "$REPO_PATH"
            fi
        '
    ) > "$output"
}

verify_current_base_exact() {
    verify_manifest_head
    verify_no_out
    if [[ -d "$LOCAL_MANIFEST_DIR" ]] &&
       [[ -n "$(find "$LOCAL_MANIFEST_DIR" -mindepth 1 -maxdepth 1 -type f -print -quit)" ]]
    then
        find "$LOCAL_MANIFEST_DIR" -mindepth 1 -maxdepth 1 -type f -print
        fail "local_manifest_present_before_admission"
    fi
    [[ ! -e "$ANDROID_ROOT/device/phh/treble" ]] ||
        fail "c2_path_present_before_admission=device/phh/treble"
    [[ ! -e "$ANDROID_ROOT/vendor/cawilliamson-priv" ]] ||
        fail "private_vendor_present_before_admission"
    local tmp current_count dirty_count
    tmp="$(mktemp -d)"
    capture_current_heads "$tmp/current-heads.tsv"
    capture_dirty_projects "$tmp/dirty-projects.tsv"
    current_count="$(grep -cve '^$' "$tmp/current-heads.tsv" || true)"
    dirty_count="$(grep -cve '^$' "$tmp/dirty-projects.tsv" || true)"
    [[ "$current_count" == "$N1D_C2_BASE_PROJECT_COUNT" ]] || {
        rm -rf "$tmp"
        fail "current_base_count expected=$N1D_C2_BASE_PROJECT_COUNT actual=$current_count"
    }
    [[ "$dirty_count" == 0 ]] || {
        cat "$tmp/dirty-projects.tsv"
        rm -rf "$tmp"
        fail "current_base_dirty_count=$dirty_count"
    }
    LC_ALL=C sort "$BASE_HEADS" > "$tmp/base-sorted.tsv"
    LC_ALL=C sort "$tmp/current-heads.tsv" > "$tmp/current-sorted.tsv"
    cmp -s "$tmp/base-sorted.tsv" "$tmp/current-sorted.tsv" || {
        diff -u "$tmp/base-sorted.tsv" "$tmp/current-sorted.tsv" || true
        rm -rf "$tmp"
        fail "current_base_heads_do_not_match_seal"
    }
    rm -rf "$tmp"
    echo "N1D_C2_CURRENT_BASE_PROJECT_COUNT=$current_count"
    echo "N1D_C2_CURRENT_BASE_DIRTY_PROJECT_COUNT=$dirty_count"
    echo "N1D_C2_CURRENT_BASE_HEADS=PASS_EXACT"
}

verify_admitted_state() {
    local expected_ledger="$1" out="$2"
    [[ -f "$LOCAL_MANIFEST" ]] ||
        fail "local_manifest_missing=$LOCAL_MANIFEST"
    [[ ! -e "$ANDROID_ROOT/vendor/cawilliamson-priv" ]] ||
        fail "private_vendor_present_after_admission"
    capture_current_heads "$out/current-all-project-heads.tsv"
    capture_dirty_projects "$out/dirty-projects.tsv"
    local dirty_count
    dirty_count="$(grep -cve '^$' "$out/dirty-projects.tsv" || true)"
    [[ "$dirty_count" == 0 ]] || {
        cat "$out/dirty-projects.tsv"
        fail "admitted_dirty_project_count=$dirty_count"
    }
    "$SABLE_PYTHON" "$HEAD_VERIFY" \
        --base "$BASE_HEADS" \
        --current "$out/current-all-project-heads.tsv" \
        --c2 "$expected_ledger" \
        --expected-base-count "$N1D_C2_BASE_PROJECT_COUNT" \
        --expected-c2-count "$N1D_C2_PROJECT_COUNT" \
        --expected-total-count "$N1D_C2_EXPECTED_TOTAL_PROJECT_COUNT"
    (
        cd "$ANDROID_ROOT"
        "$SABLE_REPO_TOOL" manifest -r > "$out/repo-manifest-pinned.xml"
        "$SABLE_REPO_TOOL" list > "$out/repo-list.txt"
    )
    echo "N1D_C2_DIRTY_PROJECT_COUNT=0"
    echo "N1D_C2_PRIVATE_VENDOR=PASS_ABSENT"
    echo "N1D_C2_ADMITTED_STATE=PASS"
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
    echo "===== TITAN 2 N1D C2 SOURCE ADMISSION PREFLIGHT ====="
    echo "SOURCE_MUTATION_AUTHORIZED=NO"
    echo "NETWORK_FETCH_AUTHORIZED=NO"
    assert_no_build_device_flash
    bash "$STORAGE_VERIFY" runtime
    bash "$SOURCE_GATE"
    verify_base_seal
    verify_historical_c2_seal
    verify_current_base_exact
    local tmp
    tmp="$(mktemp -d)"
    derive_install_manifest \
        "$tmp/$N1D_C2_LOCAL_MANIFEST_NAME" \
        "$tmp/c2-projects.tsv"
    rm -rf "$tmp"
    echo "N1D_C2_SOURCE_ADMISSION_PREFLIGHT=PASS"
}

admit() {
    echo "===== TITAN 2 N1D C2 SOURCE ADMISSION ====="
    require_network_authorization
    assert_no_build_device_flash
    bash "$STORAGE_VERIFY" runtime
    bash "$SOURCE_GATE"
    verify_base_seal
    verify_historical_c2_seal
    verify_current_base_exact
    local stamp out staged_manifest ledger rc seal
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    out="$EVIDENCE_ROOT/$stamp-c2-admission"
    mkdir -p "$out"
    staged_manifest="$out/$N1D_C2_LOCAL_MANIFEST_NAME"
    ledger="$out/c2-projects.tsv"
    derive_install_manifest "$staged_manifest" "$ledger"
    mkdir -p "$LOCAL_MANIFEST_DIR"
    [[ ! -e "$LOCAL_MANIFEST" ]] ||
        fail "local_manifest_already_exists=$LOCAL_MANIFEST"
    cp "$staged_manifest" "$LOCAL_MANIFEST"
    mapfile -t project_paths < <(cut -f1 "$ledger")
    [[ "${#project_paths[@]}" == "$N1D_C2_PROJECT_COUNT" ]] ||
        fail "project_path_count expected=$N1D_C2_PROJECT_COUNT actual=${#project_paths[@]}"
    set +e
    (
        cd "$ANDROID_ROOT"
        "$SABLE_REPO_TOOL" sync \
            --jobs="$N1D_C2_SYNC_JOBS" \
            --no-clone-bundle \
            --no-tags \
            "${project_paths[@]}"
    ) 2>&1 | tee "$out/repo-sync-c2.log"
    rc="${PIPESTATUS[0]}"
    set -e
    echo "REPO_SYNC_C2_RC=$rc" > "$out/sync-result.env"
    [[ "$rc" == 0 ]] ||
        fail "c2_repo_sync_rc=$rc log=$out/repo-sync-c2.log"
    verify_admitted_state "$ledger" "$out"
    {
        echo "N1D_C2_BASE_SEAL=$BASE_SEAL"
        echo "N1D_C2_BASE_SEAL_SHA256=$N1D_C2_BASE_SEAL_SHA256"
        echo "N1D_C2_HISTORICAL_SEAL=$HISTORICAL_C2_SEAL"
        echo "N1D_C2_HISTORICAL_SEAL_SHA256=$N1D_C2_PIN_SEAL_SHA256"
        echo "N1D_C2_LOCAL_MANIFEST=$LOCAL_MANIFEST"
        echo "N1D_C2_PROJECT_COUNT=$N1D_C2_PROJECT_COUNT"
        echo "N1D_C2_TOTAL_PROJECT_COUNT=$N1D_C2_EXPECTED_TOTAL_PROJECT_COUNT"
        echo "N1D_C2_PRODUCT_ROLE=$N1D_C2_PRODUCT_ROLE"
        echo "BUILD_AUTHORIZED=NO"
        echo "DEVICE_CONTACT_AUTHORIZED=NO"
        echo "FLASH_AUTHORIZED=NO"
    } > "$out/source-state.env"
    cp "$SOURCE_LOCK" "$out/n1d-source-lock.env"
    cp "$FRESH_PROFILE" "$out/n1d-fresh-source.env"
    cp "$ADMISSION_PROFILE" "$out/n1d-c2-source-admission.env"
    seal="$(seal_directory "$out")"
    echo "N1D_C2_SOURCE_ADMISSION_SEAL_SHA256=$seal"
    echo "N1D_C2_SOURCE_ADMISSION=PASS"
    echo "EVIDENCE_DIR=$out"
}

case "$ACTION" in
    preflight)
        preflight
        ;;
    admit)
        admit
        ;;
    *)
        fail "unknown_action=$ACTION"
        ;;
esac

\t' "$BASE_HEADS"; then
            fail "c2_path_overlaps_sealed_base path=$path"
        fi
    done < "$ledger"
    echo "N1D_C2_BASE_C2_PATH_DISJOINT=PASS"
    echo "N1D_C2_INSTALL_MANIFEST_DERIVATION=PASS"
}

capture_current_heads() {
    local output="$1"
    (
        cd "$ANDROID_ROOT"
        "$SABLE_REPO_TOOL" forall -c \
            'printf "%s\t%s\n" "$REPO_PATH" "$(git rev-parse HEAD)"'
    ) > "$output"
}

capture_dirty_projects() {
    local output="$1"
    (
        cd "$ANDROID_ROOT"
        "$SABLE_REPO_TOOL" forall -c '
            status="$(git status --porcelain --untracked-files=all)"
            if [ -n "$status" ]; then
                printf "%s\n" "$REPO_PATH"
            fi
        '
    ) > "$output"
}

verify_current_base_exact() {
    verify_manifest_head
    verify_no_out
    if [[ -d "$LOCAL_MANIFEST_DIR" ]] &&
       [[ -n "$(find "$LOCAL_MANIFEST_DIR" -mindepth 1 -maxdepth 1 -type f -print -quit)" ]]
    then
        find "$LOCAL_MANIFEST_DIR" -mindepth 1 -maxdepth 1 -type f -print
        fail "local_manifest_present_before_admission"
    fi
    [[ ! -e "$ANDROID_ROOT/device/phh/treble" ]] ||
        fail "c2_path_present_before_admission=device/phh/treble"
    [[ ! -e "$ANDROID_ROOT/vendor/cawilliamson-priv" ]] ||
        fail "private_vendor_present_before_admission"
    local tmp current_count dirty_count
    tmp="$(mktemp -d)"
    capture_current_heads "$tmp/current-heads.tsv"
    capture_dirty_projects "$tmp/dirty-projects.tsv"
    current_count="$(grep -cve '^$' "$tmp/current-heads.tsv" || true)"
    dirty_count="$(grep -cve '^$' "$tmp/dirty-projects.tsv" || true)"
    [[ "$current_count" == "$N1D_C2_BASE_PROJECT_COUNT" ]] || {
        rm -rf "$tmp"
        fail "current_base_count expected=$N1D_C2_BASE_PROJECT_COUNT actual=$current_count"
    }
    [[ "$dirty_count" == 0 ]] || {
        cat "$tmp/dirty-projects.tsv"
        rm -rf "$tmp"
        fail "current_base_dirty_count=$dirty_count"
    }
    LC_ALL=C sort "$BASE_HEADS" > "$tmp/base-sorted.tsv"
    LC_ALL=C sort "$tmp/current-heads.tsv" > "$tmp/current-sorted.tsv"
    cmp -s "$tmp/base-sorted.tsv" "$tmp/current-sorted.tsv" || {
        diff -u "$tmp/base-sorted.tsv" "$tmp/current-sorted.tsv" || true
        rm -rf "$tmp"
        fail "current_base_heads_do_not_match_seal"
    }
    rm -rf "$tmp"
    echo "N1D_C2_CURRENT_BASE_PROJECT_COUNT=$current_count"
    echo "N1D_C2_CURRENT_BASE_DIRTY_PROJECT_COUNT=$dirty_count"
    echo "N1D_C2_CURRENT_BASE_HEADS=PASS_EXACT"
}

verify_admitted_state() {
    local expected_ledger="$1" out="$2"
    [[ -f "$LOCAL_MANIFEST" ]] ||
        fail "local_manifest_missing=$LOCAL_MANIFEST"
    [[ ! -e "$ANDROID_ROOT/vendor/cawilliamson-priv" ]] ||
        fail "private_vendor_present_after_admission"
    capture_current_heads "$out/current-all-project-heads.tsv"
    capture_dirty_projects "$out/dirty-projects.tsv"
    local dirty_count
    dirty_count="$(grep -cve '^$' "$out/dirty-projects.tsv" || true)"
    [[ "$dirty_count" == 0 ]] || {
        cat "$out/dirty-projects.tsv"
        fail "admitted_dirty_project_count=$dirty_count"
    }
    "$SABLE_PYTHON" "$HEAD_VERIFY" \
        --base "$BASE_HEADS" \
        --current "$out/current-all-project-heads.tsv" \
        --c2 "$expected_ledger" \
        --expected-base-count "$N1D_C2_BASE_PROJECT_COUNT" \
        --expected-c2-count "$N1D_C2_PROJECT_COUNT" \
        --expected-total-count "$N1D_C2_EXPECTED_TOTAL_PROJECT_COUNT"
    (
        cd "$ANDROID_ROOT"
        "$SABLE_REPO_TOOL" manifest -r > "$out/repo-manifest-pinned.xml"
        "$SABLE_REPO_TOOL" list > "$out/repo-list.txt"
    )
    echo "N1D_C2_DIRTY_PROJECT_COUNT=0"
    echo "N1D_C2_PRIVATE_VENDOR=PASS_ABSENT"
    echo "N1D_C2_ADMITTED_STATE=PASS"
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
    echo "===== TITAN 2 N1D C2 SOURCE ADMISSION PREFLIGHT ====="
    echo "SOURCE_MUTATION_AUTHORIZED=NO"
    echo "NETWORK_FETCH_AUTHORIZED=NO"
    assert_no_build_device_flash
    bash "$STORAGE_VERIFY" runtime
    bash "$SOURCE_GATE"
    verify_base_seal
    verify_historical_c2_seal
    verify_current_base_exact
    local tmp
    tmp="$(mktemp -d)"
    derive_install_manifest \
        "$tmp/$N1D_C2_LOCAL_MANIFEST_NAME" \
        "$tmp/c2-projects.tsv"
    rm -rf "$tmp"
    echo "N1D_C2_SOURCE_ADMISSION_PREFLIGHT=PASS"
}

admit() {
    echo "===== TITAN 2 N1D C2 SOURCE ADMISSION ====="
    require_network_authorization
    assert_no_build_device_flash
    bash "$STORAGE_VERIFY" runtime
    bash "$SOURCE_GATE"
    verify_base_seal
    verify_historical_c2_seal
    verify_current_base_exact
    local stamp out staged_manifest ledger rc seal
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    out="$EVIDENCE_ROOT/$stamp-c2-admission"
    mkdir -p "$out"
    staged_manifest="$out/$N1D_C2_LOCAL_MANIFEST_NAME"
    ledger="$out/c2-projects.tsv"
    derive_install_manifest "$staged_manifest" "$ledger"
    mkdir -p "$LOCAL_MANIFEST_DIR"
    [[ ! -e "$LOCAL_MANIFEST" ]] ||
        fail "local_manifest_already_exists=$LOCAL_MANIFEST"
    cp "$staged_manifest" "$LOCAL_MANIFEST"
    mapfile -t project_paths < <(cut -f1 "$ledger")
    [[ "${#project_paths[@]}" == "$N1D_C2_PROJECT_COUNT" ]] ||
        fail "project_path_count expected=$N1D_C2_PROJECT_COUNT actual=${#project_paths[@]}"
    set +e
    (
        cd "$ANDROID_ROOT"
        "$SABLE_REPO_TOOL" sync \
            --jobs="$N1D_C2_SYNC_JOBS" \
            --no-clone-bundle \
            --no-tags \
            "${project_paths[@]}"
    ) 2>&1 | tee "$out/repo-sync-c2.log"
    rc="${PIPESTATUS[0]}"
    set -e
    echo "REPO_SYNC_C2_RC=$rc" > "$out/sync-result.env"
    [[ "$rc" == 0 ]] ||
        fail "c2_repo_sync_rc=$rc log=$out/repo-sync-c2.log"
    verify_admitted_state "$ledger" "$out"
    {
        echo "N1D_C2_BASE_SEAL=$BASE_SEAL"
        echo "N1D_C2_BASE_SEAL_SHA256=$N1D_C2_BASE_SEAL_SHA256"
        echo "N1D_C2_HISTORICAL_SEAL=$HISTORICAL_C2_SEAL"
        echo "N1D_C2_HISTORICAL_SEAL_SHA256=$N1D_C2_PIN_SEAL_SHA256"
        echo "N1D_C2_LOCAL_MANIFEST=$LOCAL_MANIFEST"
        echo "N1D_C2_PROJECT_COUNT=$N1D_C2_PROJECT_COUNT"
        echo "N1D_C2_TOTAL_PROJECT_COUNT=$N1D_C2_EXPECTED_TOTAL_PROJECT_COUNT"
        echo "N1D_C2_PRODUCT_ROLE=$N1D_C2_PRODUCT_ROLE"
        echo "BUILD_AUTHORIZED=NO"
        echo "DEVICE_CONTACT_AUTHORIZED=NO"
        echo "FLASH_AUTHORIZED=NO"
    } > "$out/source-state.env"
    cp "$SOURCE_LOCK" "$out/n1d-source-lock.env"
    cp "$FRESH_PROFILE" "$out/n1d-fresh-source.env"
    cp "$ADMISSION_PROFILE" "$out/n1d-c2-source-admission.env"
    seal="$(seal_directory "$out")"
    echo "N1D_C2_SOURCE_ADMISSION_SEAL_SHA256=$seal"
    echo "N1D_C2_SOURCE_ADMISSION=PASS"
    echo "EVIDENCE_DIR=$out"
}

case "$ACTION" in
    preflight)
        preflight
        ;;
    admit)
        admit
        ;;
    *)
        fail "unknown_action=$ACTION"
        ;;
esac

