#!/usr/bin/env bash
# Qualify Titan 2 N1D C3 product resolution without target compilation.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STORAGE_PROFILE="$ROOT/build/config/storage.env"
HOST_PROFILE="$ROOT/build/config/host-tools.env"
SOURCE_LOCK="$ROOT/build/titan2/n1d-source-lock.env"
FRESH_PROFILE="$ROOT/build/titan2/n1d-fresh-source.env"
C3_PROFILE="$ROOT/build/titan2/n1d-c3-composition.env"
STAGE_DRIVER="$ROOT/build/titan2/stage-n1d-c3-product.sh"
STORAGE_VERIFY="$ROOT/build/host/verify-storage-root.sh"
SOURCE_GATE="$ROOT/build/gates/n1d-source-lock-contract.sh"

fail() {
    echo "N1D_C3_PRODUCT_PARSE=FAIL $*" >&2
    exit 1
}

for f in \
    "$STORAGE_PROFILE" \
    "$HOST_PROFILE" \
    "$SOURCE_LOCK" \
    "$FRESH_PROFILE" \
    "$C3_PROFILE" \
    "$STAGE_DRIVER" \
    "$STORAGE_VERIFY" \
    "$SOURCE_GATE"
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
source "$FRESH_PROFILE"
# shellcheck source=/dev/null
source "$C3_PROFILE"

PARSE_AUTHORIZED=NO
while (($#)); do
    case "$1" in
        --authorize-product-parse)
            PARSE_AUTHORIZED=YES
            shift
            ;;
        *)
            fail "unknown_arg=$1"
            ;;
    esac
done

[[ "$PARSE_AUTHORIZED" == YES ]] || fail "product_parse_requires_--authorize-product-parse"

ANDROID_ROOT="$SABLE_BUILD_ROOT/$N1D_ANDROID_ROOT_REL"
OUT_C2="$SABLE_BUILD_ROOT/$N1D_OUT_C2_REL"
OUT_C3="$SABLE_BUILD_ROOT/$N1D_OUT_C3_REL"
STAGE_TARGET="$ANDROID_ROOT/$N1D_C3_STAGE_TARGET_REL"
STAGE_EVIDENCE_ROOT="$SABLE_EVIDENCE_ROOT/titan2/n1d-c3-product-composition"
PARSE_EVIDENCE_ROOT="$SABLE_EVIDENCE_ROOT/titan2/n1d-c3-product-parse"
PARSE_WORK_ROOT="$SABLE_BUILD_ROOT/$N1D_ANDROID_WORKSPACE_REL/out-c3-parse"
LUNCH_TARGET="${N1D_C3_PRODUCT_NAME}-${N1D_C3_RELEASE_CONFIG}-${N1D_C3_FIRST_BUILD_VARIANT}"

echo "===== TITAN 2 N1D C3 PRODUCT PARSE ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "PRODUCT_PARSE_AUTHORIZED=YES_EXPLICIT"
echo "ANDROID_TARGET_COMPILATION_AUTHORIZED=NO"
echo "NINJA_BUILD_AUTHORIZED=NO"
echo "TARGET_ARTIFACT_BUILD_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "SIGNING_AUTHORIZED=NO"
echo "LUNCH_TARGET=$LUNCH_TARGET"

bash "$STORAGE_VERIFY" runtime
bash "$SOURCE_GATE"
bash "$STAGE_DRIVER" verify

[[ -d "$ANDROID_ROOT" ]] || fail "android_root_missing=$ANDROID_ROOT"
[[ -f "$ANDROID_ROOT/build/envsetup.sh" ]] || fail "envsetup_missing=$ANDROID_ROOT/build/envsetup.sh"
[[ -x "$ANDROID_ROOT/build/soong/soong_ui.bash" ]] || fail "soong_ui_missing=$ANDROID_ROOT/build/soong/soong_ui.bash"
[[ -d "$STAGE_TARGET" ]] || fail "stage_target_missing=$STAGE_TARGET"
[[ ! -e "$OUT_C2" ]] || fail "unexpected_c2_out=$OUT_C2"
if [[ -e "$OUT_C3" ]]; then
    echo "N1D_C3_PRIOR_BUILD_OUT=PRESENT_ISOLATED"
else
    echo "N1D_C3_PRIOR_BUILD_OUT=ABSENT"
fi

mapfile -t stage_evidence_candidates < <(
    find "$STAGE_EVIDENCE_ROOT" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -name '*-c3-product-stage' \
        -print 2>/dev/null | LC_ALL=C sort
)
((${#stage_evidence_candidates[@]} > 0)) || fail "stage_evidence_missing=$STAGE_EVIDENCE_ROOT"
STAGE_EVIDENCE="${stage_evidence_candidates[-1]}"
[[ -f "$STAGE_EVIDENCE/SHA256SUMS.txt" ]] || fail "stage_evidence_seal_missing=$STAGE_EVIDENCE"
(
    cd "$STAGE_EVIDENCE"
    sha256sum -c SHA256SUMS.txt >/dev/null
) || fail "stage_evidence_seal_invalid=$STAGE_EVIDENCE"

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="$PARSE_EVIDENCE_ROOT/$stamp-c3-product-parse"
PARSE_OUT="$PARSE_WORK_ROOT/$stamp"
mkdir -p "$EVIDENCE_DIR" "$PARSE_OUT"

exec > >(tee "$EVIDENCE_DIR/parse.log") 2>&1

echo "STAGE_EVIDENCE=$STAGE_EVIDENCE"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "PARSE_OUT=$PARSE_OUT"

(
    cd "$ANDROID_ROOT"
    export OUT_DIR="$PARSE_OUT"

    # envsetup/lunch are upstream shell functions and are not nounset-safe.
    set +e +u
    # shellcheck source=/dev/null
    source build/envsetup.sh
    envsetup_rc=$?
    set -euo pipefail
    [[ "$envsetup_rc" -eq 0 ]] || fail "envsetup_source_rc=$envsetup_rc"
    echo "N1D_C3_ENVSETUP=PASS"

    set +e +u
    lunch "$LUNCH_TARGET"
    lunch_rc=$?
    set -euo pipefail
    [[ "$lunch_rc" -eq 0 ]] || fail "lunch_rc=$lunch_rc"
    echo "N1D_C3_LUNCH=PASS target=$LUNCH_TARGET"

    [[ "${TARGET_PRODUCT:-}" == "$N1D_C3_PRODUCT_NAME" ]] \
        || fail "target_product expected=$N1D_C3_PRODUCT_NAME actual=${TARGET_PRODUCT:-unset}"
    [[ "${TARGET_RELEASE:-}" == "$N1D_C3_RELEASE_CONFIG" ]] \
        || fail "target_release expected=$N1D_C3_RELEASE_CONFIG actual=${TARGET_RELEASE:-unset}"
    [[ "${TARGET_BUILD_VARIANT:-}" == "$N1D_C3_FIRST_BUILD_VARIANT" ]] \
        || fail "target_variant expected=$N1D_C3_FIRST_BUILD_VARIANT actual=${TARGET_BUILD_VARIANT:-unset}"

    vars_file="$EVIDENCE_DIR/product-vars.env"
    set +e +u
    build/soong/soong_ui.bash \
        --dumpvars-mode \
        --vars="TARGET_PRODUCT TARGET_BUILD_VARIANT PRODUCT_DEVICE PRODUCT_BRAND PRODUCT_MODEL PRODUCT_MANUFACTURER BUILDING_GSI BUILD_ID PLATFORM_VERSION PRODUCT_OUT" \
        > "$vars_file"
    dumpvars_rc=$?
    set -euo pipefail
    [[ "$dumpvars_rc" -eq 0 ]] || fail "dumpvars_rc=$dumpvars_rc"
    echo "N1D_C3_DUMPVARS=PASS"
)

grep -Fxq "TARGET_PRODUCT='$N1D_C3_PRODUCT_NAME'" "$EVIDENCE_DIR/product-vars.env" \
    || fail "dumpvars_target_product"
grep -Fxq "TARGET_BUILD_VARIANT='$N1D_C3_FIRST_BUILD_VARIANT'" "$EVIDENCE_DIR/product-vars.env" \
    || fail "dumpvars_target_variant"
grep -Fxq "PRODUCT_DEVICE='$N1D_C3_PRODUCT_DEVICE'" "$EVIDENCE_DIR/product-vars.env" \
    || fail "dumpvars_product_device"
grep -Fxq "BUILDING_GSI='$N1D_C3_BUILDING_GSI_VALUE'" "$EVIDENCE_DIR/product-vars.env" \
    || fail "dumpvars_building_gsi"
grep -Fxq "PRODUCT_BRAND='SableOS'" "$EVIDENCE_DIR/product-vars.env" \
    || fail "dumpvars_product_brand"
grep -Fxq "PRODUCT_MODEL='SableOS Titan 2 N1D'" "$EVIDENCE_DIR/product-vars.env" \
    || fail "dumpvars_product_model"
grep -Fxq "PRODUCT_MANUFACTURER='SableOS'" "$EVIDENCE_DIR/product-vars.env" \
    || fail "dumpvars_product_manufacturer"

if find "$PARSE_OUT" -type f \
    \( -name '*.img' -o -name '*target_files*.zip' -o -name '*ota*.zip' \) \
    -print -quit | grep -q .
then
    fail "unexpected_target_artifact_in_parse_out=$PARSE_OUT"
fi

{
    echo "N1D_C3_PRODUCT_PARSE=PASS"
    echo "N1D_C3_LUNCH_TARGET=$LUNCH_TARGET"
    echo "N1D_C3_PRODUCT_NAME=$N1D_C3_PRODUCT_NAME"
    echo "N1D_C3_PRODUCT_DEVICE=$N1D_C3_PRODUCT_DEVICE"
    echo "N1D_C3_BUILDING_GSI=$N1D_C3_BUILDING_GSI_VALUE"
    echo "N1D_C3_SOONG_AOSP_SYSTEM_IMAGE_ENABLED=NO"
    echo "N1D_C3_RELEASE_CONFIG=$N1D_C3_RELEASE_CONFIG"
    echo "N1D_C3_BUILD_VARIANT=$N1D_C3_FIRST_BUILD_VARIANT"
    echo "N1D_C3_STAGE_EVIDENCE=$STAGE_EVIDENCE"
    echo "N1D_C3_PARSE_OUT=$PARSE_OUT"
    echo "ANDROID_TARGET_COMPILATION_AUTHORIZED=NO"
    echo "NINJA_BUILD_AUTHORIZED=NO"
    echo "TARGET_ARTIFACT_BUILD_AUTHORIZED=NO"
    echo "DEVICE_CONTACT_AUTHORIZED=NO"
    echo "FLASH_AUTHORIZED=NO"
    echo "SIGNING_AUTHORIZED=NO"
} > "$EVIDENCE_DIR/parse-state.env"

(
    cd "$EVIDENCE_DIR"
    find . -type f ! -name SHA256SUMS.txt ! -name parse.log -print0 \
        | LC_ALL=C sort -z \
        | xargs -0 sha256sum > SHA256SUMS.txt
    sha256sum -c SHA256SUMS.txt >/dev/null
)

echo "N1D_C3_PRODUCT_PARSE_IDENTITY=PASS"
echo "N1D_C3_PRODUCT_PARSE_GRAPHENE_GSI_ADAPTATION=PASS"
echo "N1D_C3_PRODUCT_PARSE_NO_TARGET_ARTIFACTS=PASS"
echo "N1D_C3_PRODUCT_PARSE=PASS"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "PARSE_OUT=$PARSE_OUT"
