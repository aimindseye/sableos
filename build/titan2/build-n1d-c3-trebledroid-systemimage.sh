#!/usr/bin/env bash
# First N1D C3 compile using the pinned Restless/TrebleDroid-generated product.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STORAGE_PROFILE="$ROOT/build/config/storage.env"
FRESH_PROFILE="$ROOT/build/titan2/n1d-fresh-source.env"
TD_PROFILE="$ROOT/build/titan2/n1d-c3-trebledroid.env"
PREP="$ROOT/build/titan2/prepare-n1d-c3-trebledroid.sh"
STORAGE_VERIFY="$ROOT/build/host/verify-storage-root.sh"

fail() { echo "N1D_C3_TREBLEDROID_BUILD=FAIL $*" >&2; exit 1; }

for f in "$STORAGE_PROFILE" "$FRESH_PROFILE" "$TD_PROFILE" "$PREP" "$STORAGE_VERIFY"; do
    [[ -f "$f" ]] || fail "missing_file=$f"
done

# shellcheck source=/dev/null
source "$STORAGE_PROFILE"
# shellcheck source=/dev/null
source "$FRESH_PROFILE"
# shellcheck source=/dev/null
source "$TD_PROFILE"

BUILD_AUTHORIZED=NO
NETWORK_FETCH_AUTHORIZED=NO
JOBS="$(nproc --all)"
while (($#)); do
    case "$1" in
        --authorize-c3-compile) BUILD_AUTHORIZED=YES; shift ;;
        --authorize-network) NETWORK_FETCH_AUTHORIZED=YES; shift ;;
        --jobs)
            [[ $# -ge 2 ]] || fail jobs_value_missing
            JOBS="$2"
            shift 2
            ;;
        *) fail "unknown_arg=$1" ;;
    esac
done

[[ "$BUILD_AUTHORIZED" == YES ]] || fail compile_requires_--authorize-c3-compile
[[ "$NETWORK_FETCH_AUTHORIZED" == YES ]] || fail build_requires_--authorize-network_for_treble_app
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || fail "invalid_jobs=$JOBS"

ANDROID_ROOT="$SABLE_BUILD_ROOT/$N1D_ANDROID_ROOT_REL"
OUT_C3="$SABLE_BUILD_ROOT/$N1D_ANDROID_WORKSPACE_REL/out-c3-td"
PARSE_EVIDENCE_ROOT="$SABLE_EVIDENCE_ROOT/titan2/n1d-c3-trebledroid-parse"
BUILD_EVIDENCE_ROOT="$SABLE_EVIDENCE_ROOT/titan2/n1d-c3-trebledroid-build"
LUNCH_TARGET="${N1D_C3_GENERATED_PRODUCT}-${N1D_C3_RELEASE_CONFIG}-${N1D_C3_FIRST_VARIANT}"

echo "===== N1D C3 TREBLEDROID SYSTEMIMAGE BUILD ====="
echo "BUILD_AUTHORIZED=YES_SYSTEMIMAGE_ONLY"
echo "TARGET_FILES_BUILD_AUTHORIZED=NO"
echo "OTA_BUILD_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=YES_TREBLE_APP_GRADLE_ONLY"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "PRODUCTION_SIGNING_AUTHORIZED=NO"
echo "RELEASE_ELIGIBLE=NO"
echo "LUNCH_TARGET=$LUNCH_TARGET"

bash "$STORAGE_VERIFY" runtime
bash "$PREP" verify

[[ ! -e "$OUT_C3" ]] || fail "out_already_exists=$OUT_C3"

mapfile -t parses < <(
    find "$PARSE_EVIDENCE_ROOT" -mindepth 1 -maxdepth 1 -type d         -name '*-trebledroid-parse' -print 2>/dev/null | LC_ALL=C sort
)
(("${#parses[@]}" > 0)) || fail parse_evidence_missing
PARSE_EVIDENCE="${parses[-1]}"
(
    cd "$PARSE_EVIDENCE"
    sha256sum -c SHA256SUMS.txt >/dev/null
) || fail parse_evidence_invalid
grep -Fxq 'N1D_C3_TREBLEDROID_PARSE=PASS' "$PARSE_EVIDENCE/parse-state.env"     || fail parse_not_passed

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="$BUILD_EVIDENCE_ROOT/$stamp-trebledroid-systemimage"
mkdir -p "$EVIDENCE_DIR"
exec > >(tee "$EVIDENCE_DIR/build.log") 2>&1

(
    cd "$ANDROID_ROOT"
    export OUT_DIR="$OUT_C3"

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

    echo "N1D_C3_TREBLE_APP_BUILD=START"
    (
        cd treble_app
        bash build.sh release
    )
    [[ -f treble_app/TrebleApp.apk ]] || fail treble_app_apk_missing
    treble_app_sha="$(sha256sum treble_app/TrebleApp.apk | awk '{print $1}')"
    treble_app_bytes="$(stat -c '%s' treble_app/TrebleApp.apk)"
    printf '%s\n' "$treble_app_sha" > "$EVIDENCE_DIR/treble-app.sha256"
    printf '%s\n' "$treble_app_bytes" > "$EVIDENCE_DIR/treble-app.bytes"
    echo "N1D_C3_TREBLE_APP_BUILD=PASS sha256=$treble_app_sha bytes=$treble_app_bytes"

    set +e +u
    product_out="$(get_build_var PRODUCT_OUT)"
    product_out_rc=$?
    set -euo pipefail
    [[ "$product_out_rc" -eq 0 ]] || fail "product_out_rc=$product_out_rc"
    printf '%s\n' "$product_out" > "$EVIDENCE_DIR/product-out.txt"

    echo "N1D_C3_TREBLEDROID_BUILD_RECIPE=TREBLE_APP_RELEASE_THEN_SYSTEMIMAGE"
    echo "N1D_C3_TREBLEDROID_BUILD_GOAL=systemimage"
    set +e +u
    m -j"$JOBS" systemimage 2>&1 | tee "$EVIDENCE_DIR/systemimage-command.log"
    build_rc="${PIPESTATUS[0]}"
    set -euo pipefail
    [[ "$build_rc" -eq 0 ]] || fail "systemimage_build_rc=$build_rc"
)

PRODUCT_OUT="$(cat "$EVIDENCE_DIR/product-out.txt")"
SYSTEM_IMG="$PRODUCT_OUT/system.img"
[[ -f "$SYSTEM_IMG" ]] || fail "system_img_missing=$SYSTEM_IMG"

if find "$OUT_C3" -type f     \( -name '*target_files*.zip' -o -name '*ota*.zip' \)     -print -quit | grep -q .
then
    fail unauthorized_packaging_artifact
fi

sha="$(sha256sum "$SYSTEM_IMG" | awk '{print $1}')"
bytes="$(stat -c '%s' "$SYSTEM_IMG")"

{
    echo "N1D_C3_TREBLEDROID_BUILD=PASS"
    echo "N1D_C3_PRODUCT=$N1D_C3_GENERATED_PRODUCT"
    echo "N1D_C3_RELEASE_CONFIG=$N1D_C3_RELEASE_CONFIG"
    echo "N1D_C3_VARIANT=$N1D_C3_FIRST_VARIANT"
    echo "N1D_C3_SYSTEM_IMG=$SYSTEM_IMG"
    echo "N1D_C3_SYSTEM_SHA256=$sha"
    echo "N1D_C3_SYSTEM_BYTES=$bytes"
    echo "N1D_C3_TREBLE_APP_SHA256=$(cat "$EVIDENCE_DIR/treble-app.sha256")"
    echo "N1D_C3_TREBLE_APP_BYTES=$(cat "$EVIDENCE_DIR/treble-app.bytes")"
    echo "N1D_C3_RELEASE_ELIGIBLE=NO"
    echo "DEVICE_CONTACT_AUTHORIZED=NO"
    echo "FLASH_AUTHORIZED=NO"
} > "$EVIDENCE_DIR/build-state.env"

(
    cd "$EVIDENCE_DIR"
    find . -type f ! -name SHA256SUMS.txt ! -name build.log ! -name systemimage-command.log -print0         | LC_ALL=C sort -z         | xargs -0 sha256sum > SHA256SUMS.txt
    sha256sum -c SHA256SUMS.txt >/dev/null
)

echo "SYSTEM_IMG=$SYSTEM_IMG"
echo "SYSTEM_SHA256=$sha"
echo "SYSTEM_BYTES=$bytes"
echo "N1D_C3_TREBLEDROID_SYSTEMIMAGE=PASS"
echo "N1D_C3_RELEASE_ELIGIBLE=NO"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
