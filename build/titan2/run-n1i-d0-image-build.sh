#!/usr/bin/env bash
# Titan 2 N1I-D0 IMG0 consolidated build-only driver.
#
# Deliberately avoids top-level strict shell modes. Critical return codes are
# checked explicitly. No network fetch, device contact, reboot, or flash.
set -u
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/build/config/storage.env"
source "$ROOT/build/config/host-tools.env"
source "$ROOT/build/titan2/n1d-fresh-source.env"
source "$ROOT/build/titan2/n1d-c3-trebledroid.env"
source "$ROOT/build/titan2/n1d-c3a-control-evidence.env"
source "$ROOT/build/titan2/n1d-c3b-e2-product-composition.env"

MODE=--direct
JOBS="${SABLE_BUILD_JOBS:-$(nproc --all)}"
SOURCE_MUTATION_AUTHORIZED=NO
BUILD_AUTHORIZED=NO

fail() {
    echo "N1I_D0_IMAGE_BUILD=FAIL reason=$1" >&2
    return "${2:-1}"
}

usage() {
    cat <<'USAGE'
Usage:
  run-n1i-d0-image-build.sh [--direct|--tmux] \
    --authorize-source-mutation --authorize-build [--jobs N]

Build-only N1I-D0 IMG0 candidate:
  boot-qualified C3A substrate + exact five N1F Sable apps + inert D0 marker.

No network fetch, adb, fastboot, reboot, flash, clean, or clobber.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --direct) MODE=--direct; shift ;;
        --tmux) MODE=--tmux; shift ;;
        --authorize-source-mutation) SOURCE_MUTATION_AUTHORIZED=YES; shift ;;
        --authorize-build) BUILD_AUTHORIZED=YES; shift ;;
        --jobs)
            [[ $# -ge 2 ]] || { fail missing_jobs_value 64; exit $?; }
            JOBS="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) fail "unknown_argument=$1" 64; exit $? ;;
    esac
done

[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || { fail "invalid_jobs=$JOBS" 64; exit $?; }
[[ "$SOURCE_MUTATION_AUTHORIZED" == YES ]] ||
    { fail source_mutation_requires_authorization 64; exit $?; }
[[ "$BUILD_AUTHORIZED" == YES ]] ||
    { fail build_requires_authorization 64; exit $?; }

SOURCE_COMMIT="${EXPECTED_SOURCE_COMMIT:-$(git -C "$ROOT" rev-parse HEAD)}"
[[ "$SOURCE_COMMIT" =~ ^[0-9a-f]{40}$ ]] || { fail "bad_source_commit=$SOURCE_COMMIT" 64; exit $?; }

if [[ "$MODE" == --tmux ]]; then
    SESSION="${SABLE_TMUX_SESSION:-sable-titan2-n1i-d0-img0-${SOURCE_COMMIT:0:12}}"
    if tmux has-session -t "$SESSION" 2>/dev/null; then
        fail "tmux_session_exists=$SESSION" 5
        exit $?
    fi
    self="$ROOT/build/titan2/run-n1i-d0-image-build.sh"
    tmux new-session -d -s "$SESSION" \
        "EXPECTED_SOURCE_COMMIT='$SOURCE_COMMIT' SABLE_BUILD_JOBS='$JOBS' bash '$self' --direct --authorize-source-mutation --authorize-build; rc=\$?; echo; echo N1I_D0_IMAGE_BUILD_RC=\$rc; echo BUILD_DRIVER_EXITED=YES; exit \$rc" ||
        { fail "tmux_new_session_failed=$SESSION"; exit $?; }
    tmux set-window-option -t "$SESSION" remain-on-exit on >/dev/null ||
        { fail "tmux_remain_on_exit_failed=$SESSION"; exit $?; }
    echo "N1I_D0_IMAGE_BUILD=PASS_STARTED"
    echo "SESSION=$SESSION"
    echo "SESSION_RETENTION=remain-on-exit"
    echo "ATTACH=tmux attach -t $SESSION"
    exit 0
fi

[[ "$(git -C "$ROOT" rev-parse HEAD)" == "$SOURCE_COMMIT" ]] || { fail source_identity; exit $?; }
[[ -z "$(git -C "$ROOT" status --porcelain=v1 --untracked-files=all)" ]] ||
    { fail sable_repo_dirty; git -C "$ROOT" status --short >&2; exit 65; }

ANDROID_ROOT="$SABLE_BUILD_ROOT/$N1D_ANDROID_ROOT_REL"
OUT_DIR="$SABLE_BUILD_ROOT/$N1D_ANDROID_WORKSPACE_REL/out-c3a-td"
PRODUCT_OUT="$OUT_DIR/target/product/tdgsi_arm64_ab"
ROM_MK="$ANDROID_ROOT/device/phh/treble/rom.mk"
STAGE_ROOT="$ANDROID_ROOT/vendor/sable/titan2"
C3B_STAGE="$STAGE_ROOT/c3b"
D0_STAGE="$STAGE_ROOT/n1i-d0"

C3A_CONTROL="$SABLE_ARTIFACTS_ROOT/titan2/c3a-boot-qualified/20261003T221350Z/system.img"
N1F_CONTROL="$SABLE_ARTIFACTS_ROOT/titan2/n1f-c3a-derived-c3b5/20261003T221350Z/system.img"
C3A_SHA="4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16"
N1F_SHA="dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a"
N1F_BYTES=3200540672
SYSTEM_GROUP_SAFE_CEILING=3263168512

APP_BUILD="$ROOT/build/titan2/build-n1d-c3b-e2-product-apps.sh"
C3B_TEMPLATE="$ROOT/product/titan2/c3b"
D0_TEMPLATE="$ROOT/product/titan2/n1i-d0"
GSI_INFO="$ROOT/build/deploy/gsi_image_info.py"
BUILD_REGRESSION_CONTRACT="$ROOT/build/gates/build-regression-contract.py"
IMAGE_CONTRACT="$ROOT/build/gates/n1i-d0-image-build-contract.sh"
MODULES=(SableTitan2Keyboard SableTitan2Camera SableTitan2DisplayCompat SableTitan2Setup SableTitan2RadioDiag)
D0_MARKER_MODULE=SableTitan2N1ID0Marker
D0_MARKER_REL=system/product/etc/sable/n1i-d0-image

latest_c3a_stage() {
    find "$SABLE_EVIDENCE_ROOT/titan2/n1d-c3a-trebledroid-prep" \
        -mindepth 1 -maxdepth 1 -type d -name '*-trebledroid-stage' -print 2>/dev/null |
        LC_ALL=C sort | tail -1
}

verify_c3a_source() {
    local stage tmp count
    stage="$(latest_c3a_stage)"
    [[ -n "$stage" && -f "$stage/SHA256SUMS.txt" && -f "$stage/postpatch-project-heads.tsv" ]] ||
        { fail c3a_stage_evidence_missing; return $?; }
    (cd "$stage"; sha256sum -c SHA256SUMS.txt >/dev/null) || { fail c3a_stage_seal; return $?; }

    tmp="$(mktemp -d)"
    (
        cd "$ANDROID_ROOT" || exit 1
        "$SABLE_REPO_TOOL" forall -c 'printf "%s\t%s\n" "$REPO_PATH" "$(git rev-parse HEAD)"' |
            LC_ALL=C sort > "$tmp/current.tsv"
        "$SABLE_REPO_TOOL" forall -c 's="$(git status --porcelain --untracked-files=all)"; if [ -n "$s" ]; then printf "%s\n" "$REPO_PATH"; fi' |
            LC_ALL=C sort > "$tmp/dirty.tsv"
    ) || { rm -rf "$tmp"; fail c3a_repo_state_capture; return $?; }

    count="$(grep -cve '^$' "$tmp/current.tsv" || true)"
    [[ "$count" == "$N1D_C3A_MANAGED_PROJECT_COUNT" ]] ||
        { rm -rf "$tmp"; fail "c3a_project_count=$count"; return $?; }

    LC_ALL=C sort "$stage/postpatch-project-heads.tsv" > "$tmp/expected.tsv"
    cmp -s "$tmp/expected.tsv" "$tmp/current.tsv" || {
        diff -u "$tmp/expected.tsv" "$tmp/current.tsv" >&2 || true
        rm -rf "$tmp"
        fail c3a_heads
        return $?
    }

    printf '%s\n' build/soong device/phh/treble treble_app | LC_ALL=C sort > "$tmp/expected-dirty.tsv"
    cmp -s "$tmp/expected-dirty.tsv" "$tmp/dirty.tsv" || {
        diff -u "$tmp/expected-dirty.tsv" "$tmp/dirty.tsv" >&2 || true
        rm -rf "$tmp"
        fail c3a_dirty_set
        return $?
    }
    rm -rf "$tmp"
    echo "N1I_D0_IMAGE_C3A_SOURCE=PASS projects=$count dirty=3"
}

selfcheck() {
    [[ "$N1D_AOSP_REVISION" == android-16.0.0_r4 ]] || { fail "aosp_revision=$N1D_AOSP_REVISION"; return $?; }
    [[ "$N1D_C3_GRAPHENEOS_TAG" == 2026061600 ]] || { fail "graphene_tag=$N1D_C3_GRAPHENEOS_TAG"; return $?; }
    [[ "$N1D_C3_CONTROL_PATCH_COUNT" == 369 ]] || { fail "c3a_patch_count=$N1D_C3_CONTROL_PATCH_COUNT"; return $?; }
    [[ "$N1D_C3B_E2_MODULE_COUNT" == 5 ]] || { fail "c3b_module_count=$N1D_C3B_E2_MODULE_COUNT"; return $?; }

    [[ -d "$ANDROID_ROOT/.repo" && -f "$ROM_MK" ]] || { fail android_workspace; return $?; }
    [[ ! -e "$STAGE_ROOT" ]] || { fail stage_root_present; return $?; }
    [[ -d "$OUT_DIR" ]] || { fail c3a_warm_out_missing; return $?; }

    [[ -f "$C3A_CONTROL" && "$(sha256sum "$C3A_CONTROL" | awk '{print $1}')" == "$C3A_SHA" ]] ||
        { fail c3a_control; return $?; }
    [[ -f "$N1F_CONTROL" && "$(sha256sum "$N1F_CONTROL" | awk '{print $1}')" == "$N1F_SHA" ]] ||
        { fail n1f_control; return $?; }

    [[ -f "$D0_TEMPLATE/Android.bp" && -f "$D0_TEMPLATE/sable-titan2-n1i-d0.mk" && -f "$D0_TEMPLATE/n1i-d0-image" ]] ||
        { fail d0_template_missing; return $?; }

    bash -n "$0" || { fail driver_syntax; return $?; }
    bash "$IMAGE_CONTRACT" || { fail image_contract; return $?; }
    python3 "$BUILD_REGRESSION_CONTRACT" || { fail build_regression_contract; return $?; }
    echo "N1I_D0_IMAGE_BUILD_REGRESSION_PREFLIGHT=PASS"

    bash "$ROOT/build/host/verify-host-tools.sh" aosp-host >/dev/null || { fail host_tools; return $?; }
    verify_c3a_source || return $?

    git -C "$ROOT" merge-base --is-ancestor "$N1D_C3B_E2_SOURCE_IMPORT_COMMIT" HEAD ||
        { fail e2_source_import_not_ancestor; return $?; }
    git -C "$ROOT" diff --quiet "$N1D_C3B_E2_SOURCE_IMPORT_COMMIT" HEAD -- \
        apps/titan2/platform \
        config/DETEKT_PROVENANCE.env \
        config/QUALITY_SUPPRESSION_BUDGET.tsv \
        config/detekt.yml \
        third_party/phosphor-icons \
        third_party/pinyin_zh ||
        { fail e2_source_changed; return $?; }

    echo "N1I_D0_IMAGE_SELFTEST=PASS"
}

selfcheck || exit $?

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE="$SABLE_EVIDENCE_ROOT/titan2/n1i-d0-img0-build/$STAMP"
ARTIFACT="$SABLE_ARTIFACTS_ROOT/titan2/n1i-d0-img0/$STAMP"
APP_BUNDLE="$SABLE_ARTIFACTS_ROOT/titan2/n1i-d0-img0-five-app-bundle/$STAMP"
mkdir -p "$EVIDENCE" "$ARTIFACT" || { fail evidence_dirs; exit $?; }
exec > >(tee "$EVIDENCE/build.log") 2>&1

echo "===== TITAN 2 N1I-D0 IMG0 BUILD ====="
echo "SOURCE_COMMIT=$SOURCE_COMMIT"
echo "SOURCE_MUTATION_AUTHORIZED=YES_EXACT_IMG0_STAGE"
echo "BUILD_AUTHORIZED=YES_ONE_SYSTEMIMAGE"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "MODE_TRANSITION_AUTHORIZED=NO"
echo "REBOOT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "BASELINE=N1F_BOOT_QUALIFIED"
echo "CELLULAR_DELTA=C1_C2_NOT_INCLUDED"

echo "===== BUILD EXACT FIVE N1F APPS OFFLINE ====="
bash "$APP_BUILD" --authorize-app-build --output-dir "$APP_BUNDLE"
APP_RC=$?
[[ "$APP_RC" -eq 0 ]] || { fail "app_build_rc=$APP_RC"; exit $?; }
(cd "$APP_BUNDLE/prebuilt"; sha256sum -c ../SHA256SUMS.txt >/dev/null)
APP_SEAL_RC=$?
[[ "$APP_SEAL_RC" -eq 0 ]] || { fail app_bundle_seal; exit $?; }

ROM_BACKUP="$EVIDENCE/rom.mk.c3a"
cp "$ROM_MK" "$ROM_BACKUP" || { fail rom_backup; exit $?; }
ROM_SHA="$(sha256sum "$ROM_MK" | awk '{print $1}')"

cleanup_source() {
    local rc=0
    if [[ -f "$ROM_BACKUP" ]]; then
        cp "$ROM_BACKUP" "$ROM_MK" >/dev/null 2>&1 || rc=1
    fi
    if [[ -d "$STAGE_ROOT" ]]; then
        find "$STAGE_ROOT" -depth -mindepth 1 -delete >/dev/null 2>&1 || rc=1
        rmdir "$STAGE_ROOT" >/dev/null 2>&1 || true
    fi
    return "$rc"
}
cleanup_on_exit() {
    local original_rc=$?
    local cleanup_rc=0
    trap - EXIT
    cleanup_source || cleanup_rc=$?
    if [[ "$original_rc" -ne 0 ]]; then
        if [[ "$cleanup_rc" -eq 0 ]]; then
            echo "N1I_D0_IMAGE_EMERGENCY_SOURCE_RESTORE=PASS" >&2
        else
            echo "N1I_D0_IMAGE_EMERGENCY_SOURCE_RESTORE=FAIL rc=$cleanup_rc" >&2
        fi
    fi
    if [[ "$cleanup_rc" -ne 0 && "$original_rc" -eq 0 ]]; then
        exit "$cleanup_rc"
    fi
    exit "$original_rc"
}
trap cleanup_on_exit EXIT

echo "===== STAGE N1F APPS + INERT D0 MARKER ====="
mkdir -p "$C3B_STAGE/prebuilt" "$D0_STAGE" || { fail stage_dirs; exit $?; }
install -m 0644 "$C3B_TEMPLATE/Android.bp" "$C3B_STAGE/Android.bp" || { fail stage_c3b_bp; exit $?; }
install -m 0644 "$C3B_TEMPLATE/sable-titan2-apps.mk" "$C3B_STAGE/sable-titan2-apps.mk" || { fail stage_c3b_mk; exit $?; }
for module in "${MODULES[@]}"; do
    install -m 0644 "$APP_BUNDLE/prebuilt/$module.apk" "$C3B_STAGE/prebuilt/$module.apk" ||
        { fail "stage_app=$module"; exit $?; }
done
install -m 0644 "$D0_TEMPLATE/Android.bp" "$D0_STAGE/Android.bp" || { fail stage_d0_bp; exit $?; }
install -m 0644 "$D0_TEMPLATE/sable-titan2-n1i-d0.mk" "$D0_STAGE/sable-titan2-n1i-d0.mk" || { fail stage_d0_mk; exit $?; }
install -m 0644 "$D0_TEMPLATE/n1i-d0-image" "$D0_STAGE/n1i-d0-image" || { fail stage_d0_marker; exit $?; }

grep -Fq 'vendor/sable/titan2/c3b/sable-titan2-apps.mk' "$ROM_MK" && { fail c3b_already_in_rom; exit $?; }
grep -Fq 'vendor/sable/titan2/n1i-d0/sable-titan2-n1i-d0.mk' "$ROM_MK" && { fail d0_already_in_rom; exit $?; }
cat >> "$ROM_MK" <<'ROMEOF'

# SABLE_N1I_D0_IMG0
$(call inherit-product, vendor/sable/titan2/c3b/sable-titan2-apps.mk)
$(call inherit-product, vendor/sable/titan2/n1i-d0/sable-titan2-n1i-d0.mk)
ROMEOF

diff -u "$ROM_BACKUP" "$ROM_MK" > "$EVIDENCE/rom-mk.diff" || true

echo "===== BUILD ONE N1I-D0 IMG0 SYSTEMIMAGE ====="
(
    cd "$ANDROID_ROOT" || exit 1
    export OUT_DIR="$OUT_DIR"
    set +u
    source build/envsetup.sh
    lunch treble_arm64_bvN-bp4a-user
    lunch_rc=$?
    set -u
    [[ "$lunch_rc" -eq 0 ]] || exit "$lunch_rc"

    [[ "$(get_build_var TARGET_PRODUCT)" == treble_arm64_bvN ]] || exit 71
    [[ "$(get_build_var TARGET_BUILD_VARIANT)" == user ]] || exit 72
    [[ "$(get_build_var BUILD_ID)" == BP4A.251205.006 ]] || exit 73
    [[ "$(get_build_var PLATFORM_VERSION)" == 16 ]] || exit 74
    [[ "$(get_build_var TARGET_COPY_OUT_PRODUCT)" == system/product ]] || exit 75

    pp="$(get_build_var PRODUCT_PACKAGES)"
    for module in "${MODULES[@]}" "$D0_MARKER_MODULE"; do
        grep -Eq "(^|[[:space:]])${module}([[:space:]]|$)" <<<"$pp" || exit 76
    done

    make systemimage -j"$JOBS" > >(tee "$EVIDENCE/systemimage.log") 2>&1
    exit $?
)
BUILD_RC=$?
[[ "$BUILD_RC" -eq 0 ]] || { fail "systemimage_rc=$BUILD_RC"; exit $?; }

NEW="$PRODUCT_OUT/system.img"
[[ -f "$NEW" ]] || { fail system_image_missing; exit $?; }
NEW_SHA="$(sha256sum "$NEW" | awk '{print $1}')"
NEW_BYTES="$(stat -c '%s' "$NEW")"
[[ "$NEW_SHA" != "$N1F_SHA" ]] || { fail marker_not_realized_image_unchanged; exit $?; }
[[ "$NEW_BYTES" -ge "$N1F_BYTES" && "$NEW_BYTES" -le "$SYSTEM_GROUP_SAFE_CEILING" ]] ||
    { fail "image_size=$NEW_BYTES ceiling=$SYSTEM_GROUP_SAFE_CEILING"; exit $?; }

python3 "$GSI_INFO" --image "$NEW" > "$EVIDENCE/system-image-info.txt" 2>&1
GSI_RC=$?
cat "$EVIDENCE/system-image-info.txt"
[[ "$GSI_RC" -eq 0 ]] || { fail "gsi_info_rc=$GSI_RC"; exit $?; }
grep -Fxq 'SABLE_GSI_IMAGE_INFO=PASS' "$EVIDENCE/system-image-info.txt" || { fail gsi_image_info; exit $?; }

MARKER_PATH="$PRODUCT_OUT/$D0_MARKER_REL"
[[ -f "$MARKER_PATH" ]] || { fail marker_missing; exit $?; }
cmp -s "$D0_TEMPLATE/n1i-d0-image" "$MARKER_PATH" || { fail marker_mismatch; exit $?; }

echo "===== PRESERVE SEALED N1I-D0 IMG0 ARTIFACT ====="
cp --reflink=auto --sparse=always "$NEW" "$ARTIFACT/system.img" || { fail artifact_copy; exit $?; }
cp "$EVIDENCE/system-image-info.txt" "$ARTIFACT/" || { fail artifact_info_copy; exit $?; }
cp "$APP_BUNDLE/manifest.tsv" "$ARTIFACT/app-manifest.tsv" || { fail artifact_manifest_copy; exit $?; }
cp "$D0_TEMPLATE/n1i-d0-image" "$ARTIFACT/" || { fail artifact_marker_copy; exit $?; }
cat > "$ARTIFACT/artifact.env" <<EOF2
ROLE=N1I_D0_IMG0_BUILD_PATH_CLOSURE
SOURCE_COMMIT=$SOURCE_COMMIT
BASELINE_N1F_SHA256=$N1F_SHA
BASELINE_N1F_BYTES=$N1F_BYTES
CELLULAR_DELTA=C1_C2_NOT_INCLUDED
SABLE_MODULE_COUNT=5
D0_MARKER_MODULE=$D0_MARKER_MODULE
SYSTEM_SHA256=$NEW_SHA
SYSTEM_BYTES=$NEW_BYTES
TARGET_PARTITION=system_a
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
EOF2
(
    cd "$ARTIFACT" || exit 1
    find . -type f ! -name SHA256SUMS.txt -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > SHA256SUMS.txt
    sha256sum -c SHA256SUMS.txt >/dev/null
)
ARTIFACT_RC=$?
[[ "$ARTIFACT_RC" -eq 0 ]] || { fail artifact_seal; exit $?; }

cleanup_source
CLEANUP_RC=$?
trap - EXIT
[[ "$CLEANUP_RC" -eq 0 ]] || { fail source_restore; exit $?; }
[[ "$(sha256sum "$ROM_MK" | awk '{print $1}')" == "$ROM_SHA" ]] || { fail rom_restore; exit $?; }
[[ ! -e "$STAGE_ROOT" ]] || { fail stage_restore; exit $?; }

echo "N1I_D0_IMAGE_SOURCE_RESTORE=PASS"
echo "N1I_D0_IMAGE_BUILD=PASS sha256=$NEW_SHA bytes=$NEW_BYTES"
echo "N1I_D0_IMAGE_ARTIFACT=$ARTIFACT"
echo "N1I_D0_IMAGE_EVIDENCE=$EVIDENCE"
echo "DEVICE_CONTACT=NONE"
echo "FLASH=NONE"
