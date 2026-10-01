#!/usr/bin/env bash
# First N1D C3 compile using the pinned Restless/TrebleDroid-generated product.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STORAGE_PROFILE="$ROOT/build/config/storage.env"
HOST_PROFILE="$ROOT/build/config/host-tools.env"
FRESH_PROFILE="$ROOT/build/titan2/n1d-fresh-source.env"
TD_PROFILE="$ROOT/build/titan2/n1d-c3-trebledroid.env"
PHASE_PROFILE="$ROOT/build/titan2/n1d-c3-phase-split.env"
PRODUCT_PROFILE="$ROOT/build/titan2/n1d-product-contract.env"
PREP="$ROOT/build/titan2/prepare-n1d-c3-trebledroid.sh"
STORAGE_VERIFY="$ROOT/build/host/verify-storage-root.sh"
HOST_VERIFY="$ROOT/build/host/verify-host-tools.sh"

fail() { echo "N1D_C3A_TREBLEDROID_BUILD=FAIL $*" >&2; exit 1; }

for f in "$STORAGE_PROFILE" "$HOST_PROFILE" "$FRESH_PROFILE" "$TD_PROFILE" "$PHASE_PROFILE" "$PRODUCT_PROFILE" "$PREP" "$STORAGE_VERIFY" "$HOST_VERIFY"; do
    [[ -f "$f" ]] || fail "missing_file=$f"
done

# shellcheck source=/dev/null
source "$STORAGE_PROFILE"
# shellcheck source=/dev/null
source "$HOST_PROFILE"
# shellcheck source=/dev/null
source "$FRESH_PROFILE"
# shellcheck source=/dev/null
source "$TD_PROFILE"
# shellcheck source=/dev/null
source "$PRODUCT_PROFILE"
# shellcheck source=/dev/null
source "$PHASE_PROFILE"
[[ "$N1D_C3A_ROLE" == RESTLESS_TREBLEDROID_REPRODUCTION_CONTROL ]] || fail c3a_role_mismatch
[[ "$N1D_C3A_RELEASE_ELIGIBLE" == NO ]] || fail c3a_release_boundary_mismatch
[[ "$N1D_C3B_BUILD_AUTHORIZED" == NO_UNTIL_C3A_CONTROL_EVIDENCE ]] || fail c3b_build_boundary_mismatch
[[ "$N1D_C3_RELEASE_ELIGIBLE" == NO ]] || fail c3_release_boundary_mismatch
[[ "$N1D_C3_TREBLE_APP_JDK_MAJOR" == 17 ]] || fail treble_app_jdk_major_mismatch
[[ "$N1D_C3_TREBLE_APP_JDK_SOURCE" == SABLE_JDK17 ]] || fail treble_app_jdk_source_mismatch

BUILD_AUTHORIZED=NO
NETWORK_FETCH_AUTHORIZED=NO
RESUME_FAILED_BUILD_AUTHORIZED=NO
JOBS="$(nproc --all)"
while (($#)); do
    case "$1" in
        --authorize-c3-compile) BUILD_AUTHORIZED=YES; shift ;;
        --authorize-network) NETWORK_FETCH_AUTHORIZED=YES; shift ;;
        --resume-failed-c3-build) RESUME_FAILED_BUILD_AUTHORIZED=YES; shift ;;
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
OUT_C3="$SABLE_BUILD_ROOT/$N1D_ANDROID_WORKSPACE_REL/out-c3a-td"
PARSE_EVIDENCE_ROOT="$SABLE_EVIDENCE_ROOT/titan2/n1d-c3a-trebledroid-parse"
BUILD_EVIDENCE_ROOT="$SABLE_EVIDENCE_ROOT/titan2/n1d-c3a-trebledroid-build"
LUNCH_TARGET="${N1D_C3_GENERATED_PRODUCT}-${N1D_C3_RELEASE_CONFIG}-${N1D_C3_FIRST_VARIANT}"

echo "===== N1D C3A RESTLESS/TREBLEDROID CONTROL SYSTEMIMAGE BUILD ====="
echo "BUILD_AUTHORIZED=YES_SYSTEMIMAGE_ONLY"
echo "TARGET_FILES_BUILD_AUTHORIZED=NO"
echo "OTA_BUILD_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=YES_TREBLE_APP_GRADLE_ONLY"
echo "RESUME_FAILED_BUILD_AUTHORIZED=$RESUME_FAILED_BUILD_AUTHORIZED"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "PRODUCTION_SIGNING_AUTHORIZED=NO"
echo "RELEASE_ELIGIBLE=NO"
echo "N1D_C3_ACTIVE_PHASE=C3A_CONTROL"
echo "N1D_C3A_RELEASE_ELIGIBLE=$N1D_C3A_RELEASE_ELIGIBLE"
echo "N1D_C3B_BUILD_AUTHORIZED=$N1D_C3B_BUILD_AUTHORIZED"
echo "N1D_C3_RELEASE_ELIGIBLE=$N1D_C3_RELEASE_ELIGIBLE"
echo "LUNCH_TARGET=$LUNCH_TARGET"

bash "$STORAGE_VERIFY" runtime
bash "$HOST_VERIFY" core
[[ -x "$SABLE_JDK17/bin/java" ]] || fail "canonical_jdk17_java_missing=$SABLE_JDK17/bin/java"
[[ -x "$SABLE_JDK17/bin/jlink" ]] || fail "canonical_jdk17_jlink_missing=$SABLE_JDK17/bin/jlink"
treble_jdk_spec="$("$SABLE_JDK17/bin/java" -XshowSettings:properties -version 2>&1 | awk -F'= ' '/^[[:space:]]*java\.specification\.version = / {print $2; exit}')"
[[ "$treble_jdk_spec" == "$N1D_C3_TREBLE_APP_JDK_MAJOR" ]] \
    || fail "canonical_jdk17_spec expected=$N1D_C3_TREBLE_APP_JDK_MAJOR actual=${treble_jdk_spec:-unset}"
echo "N1D_C3_TREBLE_APP_JDK=PASS source=$N1D_C3_TREBLE_APP_JDK_SOURCE major=$treble_jdk_spec home=$SABLE_JDK17"

bash "$PREP" verify

BUILD_RESUME_MODE=FRESH
if [[ -e "$OUT_C3" ]]; then
    [[ "$RESUME_FAILED_BUILD_AUTHORIZED" == YES ]] \
        || fail "out_already_exists_requires_--resume-failed-c3-build path=$OUT_C3"

    mapfile -t prior_builds < <(
        find "$BUILD_EVIDENCE_ROOT" -mindepth 1 -maxdepth 1 -type d \
            -name '*-trebledroid-systemimage' -print 2>/dev/null | LC_ALL=C sort
    )
    (("${#prior_builds[@]}" > 0)) || fail failed_build_evidence_missing_for_resume
    PRIOR_BUILD_EVIDENCE="${prior_builds[-1]}"
    [[ -f "$PRIOR_BUILD_EVIDENCE/build.log" ]] || fail prior_build_log_missing
    grep -Fq 'N1D_C3_TREBLE_APP_BUILD=START' "$PRIOR_BUILD_EVIDENCE/build.log" \
        || fail prior_build_did_not_reach_treble_app
    if grep -Fq 'N1D_C3_TREBLE_APP_BUILD=PASS' "$PRIOR_BUILD_EVIDENCE/build.log"; then
        fail prior_build_passed_treble_app_resume_not_allowed
    fi
    [[ ! -e "$PRIOR_BUILD_EVIDENCE/systemimage-command.log" ]] \
        || fail prior_build_reached_systemimage_resume_not_allowed
    if find "$OUT_C3" -type f \
        \( -name 'system.img' -o -name '*target_files*.zip' -o -name '*ota*.zip' \) \
        -print -quit | grep -q .
    then
        fail prior_output_contains_target_artifact_resume_not_allowed
    fi
    BUILD_RESUME_MODE=FAILED_TREBLE_APP_ONLY
    echo "N1D_C3A_BUILD_RESUME=PASS mode=$BUILD_RESUME_MODE prior_evidence=$PRIOR_BUILD_EVIDENCE"
elif [[ "$RESUME_FAILED_BUILD_AUTHORIZED" == YES ]]; then
    fail resume_requested_but_out_missing
else
    echo "N1D_C3A_BUILD_RESUME=PASS mode=$BUILD_RESUME_MODE"
fi

mapfile -t parses < <(
    find "$PARSE_EVIDENCE_ROOT" -mindepth 1 -maxdepth 1 -type d         -name '*-trebledroid-parse' -print 2>/dev/null | LC_ALL=C sort
)
(("${#parses[@]}" > 0)) || fail parse_evidence_missing
PARSE_EVIDENCE="${parses[-1]}"
(
    cd "$PARSE_EVIDENCE"
    sha256sum -c SHA256SUMS.txt >/dev/null
) || fail parse_evidence_invalid
grep -Fxq 'N1D_C3A_TREBLEDROID_PARSE=PASS' "$PARSE_EVIDENCE/parse-state.env"     || fail parse_not_passed

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
        export JAVA_HOME="$SABLE_JDK17"
        export PATH="$SABLE_JDK17/bin:$PATH"
        export GRADLE_USER_HOME="$SABLE_GRADLE_USER_HOME"

        java_spec="$("$JAVA_HOME/bin/java" -XshowSettings:properties -version 2>&1 | awk -F'= ' '/^[[:space:]]*java\.specification\.version = / {print $2; exit}')"
        [[ "$java_spec" == "$N1D_C3_TREBLE_APP_JDK_MAJOR" ]] \
            || fail "treble_app_java_spec expected=$N1D_C3_TREBLE_APP_JDK_MAJOR actual=${java_spec:-unset}"
        [[ "$JAVA_HOME" == "$SABLE_JDK17" ]] || fail treble_app_java_home_not_canonical

        printf '%s\n' "$JAVA_HOME" > "$EVIDENCE_DIR/treble-app-java-home.txt"
        "$JAVA_HOME/bin/java" -version > "$EVIDENCE_DIR/treble-app-java-version.txt" 2>&1
        echo "N1D_C3_TREBLE_APP_JAVA=PASS major=$java_spec home=$JAVA_HOME"
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

    echo "N1D_C3A_TREBLEDROID_BUILD_RECIPE=TREBLE_APP_RELEASE_THEN_SYSTEMIMAGE"
    echo "N1D_C3A_TREBLEDROID_BUILD_GOAL=systemimage"
    set +e +u
    make systemimage -j"$JOBS" 2>&1 | tee "$EVIDENCE_DIR/systemimage-command.log"
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
    echo "N1D_C3A_TREBLEDROID_BUILD=PASS"
    echo "N1D_C3_PRODUCT=$N1D_C3_GENERATED_PRODUCT"
    echo "N1D_C3_RELEASE_CONFIG=$N1D_C3_RELEASE_CONFIG"
    echo "N1D_C3_VARIANT=$N1D_C3_FIRST_VARIANT"
    echo "N1D_C3_SYSTEM_IMG=$SYSTEM_IMG"
    echo "N1D_C3_SYSTEM_SHA256=$sha"
    echo "N1D_C3_SYSTEM_BYTES=$bytes"
    echo "N1D_C3_TREBLE_APP_SHA256=$(cat "$EVIDENCE_DIR/treble-app.sha256")"
    echo "N1D_C3_TREBLE_APP_BYTES=$(cat "$EVIDENCE_DIR/treble-app.bytes")"
    echo "N1D_C3_TREBLE_APP_JDK_MAJOR=$N1D_C3_TREBLE_APP_JDK_MAJOR"
    echo "N1D_C3_TREBLE_APP_JAVA_HOME=$(cat "$EVIDENCE_DIR/treble-app-java-home.txt")"
    echo "N1D_C3A_BUILD_RESUME_MODE=$BUILD_RESUME_MODE"
    echo "N1D_C3A_RELEASE_ELIGIBLE=$N1D_C3A_RELEASE_ELIGIBLE"
    echo "N1D_C3B_BUILD_AUTHORIZED=$N1D_C3B_BUILD_AUTHORIZED"
    echo "N1D_C3_RELEASE_ELIGIBLE=$N1D_C3_RELEASE_ELIGIBLE"
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
echo "N1D_C3A_TREBLEDROID_SYSTEMIMAGE=PASS"
echo "N1D_C3_RELEASE_ELIGIBLE=$N1D_C3_RELEASE_ELIGIBLE"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
