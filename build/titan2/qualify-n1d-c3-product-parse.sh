#!/usr/bin/env bash
# Parse the pinned TrebleDroid-generated N1D C3 product without target compilation.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STORAGE_PROFILE="$ROOT/build/config/storage.env"
FRESH_PROFILE="$ROOT/build/titan2/n1d-fresh-source.env"
TD_PROFILE="$ROOT/build/titan2/n1d-c3-trebledroid.env"
PHASE_PROFILE="$ROOT/build/titan2/n1d-c3-phase-split.env"
PRODUCT_PROFILE="$ROOT/build/titan2/n1d-product-contract.env"
PREP="$ROOT/build/titan2/prepare-n1d-c3-trebledroid.sh"
STORAGE_VERIFY="$ROOT/build/host/verify-storage-root.sh"

fail() { echo "N1D_C3_PRODUCT_PARSE=FAIL $*" >&2; exit 1; }

for f in "$STORAGE_PROFILE" "$FRESH_PROFILE" "$TD_PROFILE" "$PHASE_PROFILE" "$PRODUCT_PROFILE" "$PREP" "$STORAGE_VERIFY"; do
    [[ -f "$f" ]] || fail "missing_file=$f"
done

# shellcheck source=/dev/null
source "$STORAGE_PROFILE"
# shellcheck source=/dev/null
source "$FRESH_PROFILE"
# shellcheck source=/dev/null
source "$TD_PROFILE"
# shellcheck source=/dev/null
source "$PHASE_PROFILE"
# shellcheck source=/dev/null
source "$PRODUCT_PROFILE"
[[ "$N1D_C3A_ROLE" == RESTLESS_TREBLEDROID_REPRODUCTION_CONTROL ]] || fail c3a_role_mismatch
[[ "$N1D_C3A_RELEASE_ELIGIBLE" == NO ]] || fail c3a_release_boundary_mismatch
[[ "$N1D_C3B_BUILD_AUTHORIZED" == NO_UNTIL_C3A_CONTROL_EVIDENCE ]] || fail c3b_build_boundary_mismatch
[[ "$N1D_C3_RELEASE_ELIGIBLE" == NO ]] || fail c3_release_boundary_mismatch

PARSE_AUTHORIZED=NO
while (($#)); do
    case "$1" in
        --authorize-product-parse) PARSE_AUTHORIZED=YES; shift ;;
        *) fail "unknown_arg=$1" ;;
    esac
done
[[ "$PARSE_AUTHORIZED" == YES ]] || fail product_parse_requires_--authorize-product-parse

ANDROID_ROOT="$SABLE_BUILD_ROOT/$N1D_ANDROID_ROOT_REL"
PARSE_ROOT="$SABLE_BUILD_ROOT/$N1D_ANDROID_WORKSPACE_REL/out-c3a-td-parse"
EVIDENCE_ROOT="$SABLE_EVIDENCE_ROOT/titan2/n1d-c3a-trebledroid-parse"
LUNCH_TARGET="${N1D_C3_GENERATED_PRODUCT}-${N1D_C3_RELEASE_CONFIG}-${N1D_C3_FIRST_VARIANT}"

echo "===== N1D C3A RESTLESS/TREBLEDROID CONTROL PARSE ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "PRODUCT_PARSE_AUTHORIZED=YES_EXPLICIT"
echo "ANDROID_TARGET_COMPILATION_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "N1D_C3_ACTIVE_PHASE=C3A_CONTROL"
echo "N1D_C3A_RELEASE_ELIGIBLE=$N1D_C3A_RELEASE_ELIGIBLE"
echo "N1D_C3B_BUILD_AUTHORIZED=$N1D_C3B_BUILD_AUTHORIZED"
echo "N1D_C3_RELEASE_ELIGIBLE=$N1D_C3_RELEASE_ELIGIBLE"
echo "LUNCH_TARGET=$LUNCH_TARGET"

bash "$STORAGE_VERIFY" runtime
bash "$PREP" verify

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="$EVIDENCE_ROOT/$stamp-trebledroid-parse"
PARSE_OUT="$PARSE_ROOT/$stamp"
mkdir -p "$EVIDENCE_DIR" "$PARSE_OUT"

exec > >(tee "$EVIDENCE_DIR/parse.log") 2>&1

(
    cd "$ANDROID_ROOT"
    export OUT_DIR="$PARSE_OUT"

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

    [[ "${TARGET_PRODUCT:-}" == "$N1D_C3_GENERATED_PRODUCT" ]]         || fail "target_product=${TARGET_PRODUCT:-unset}"
    [[ "${TARGET_RELEASE:-}" == "$N1D_C3_RELEASE_CONFIG" ]]         || fail "target_release=${TARGET_RELEASE:-unset}"
    [[ "${TARGET_BUILD_VARIANT:-}" == "$N1D_C3_FIRST_VARIANT" ]]         || fail "target_variant=${TARGET_BUILD_VARIANT:-unset}"

    build/soong/soong_ui.bash         --dumpvars-mode         --vars="TARGET_PRODUCT TARGET_BUILD_VARIANT PRODUCT_DEVICE PRODUCT_BRAND PRODUCT_MODEL BUILD_ID PLATFORM_VERSION PRODUCT_OUT"         > "$EVIDENCE_DIR/product-vars.env"
)

grep -Fxq "TARGET_PRODUCT='$N1D_C3_GENERATED_PRODUCT'" "$EVIDENCE_DIR/product-vars.env"     || fail dumpvars_target_product
grep -Fxq "TARGET_BUILD_VARIANT='$N1D_C3_FIRST_VARIANT'" "$EVIDENCE_DIR/product-vars.env"     || fail dumpvars_target_variant
grep -Fxq "PRODUCT_DEVICE='tdgsi_arm64_ab'" "$EVIDENCE_DIR/product-vars.env"     || fail dumpvars_product_device
grep -Fxq "PRODUCT_BRAND='google'" "$EVIDENCE_DIR/product-vars.env"     || fail dumpvars_product_brand
grep -Fxq "PRODUCT_MODEL='TrebleDroid vanilla'" "$EVIDENCE_DIR/product-vars.env"     || fail dumpvars_product_model

if find "$PARSE_OUT" -type f     \( -name '*.img' -o -name '*target_files*.zip' -o -name '*ota*.zip' \)     -print -quit | grep -q .
then
    fail "unexpected_target_artifact=$PARSE_OUT"
fi

{
    echo "N1D_C3A_TREBLEDROID_PARSE=PASS"
    echo "N1D_C3_LUNCH_TARGET=$LUNCH_TARGET"
    echo "N1D_C3_PRODUCT=$N1D_C3_GENERATED_PRODUCT"
    echo "N1D_C3_RELEASE_CONFIG=$N1D_C3_RELEASE_CONFIG"
    echo "N1D_C3_VARIANT=$N1D_C3_FIRST_VARIANT"
    echo "N1D_C3A_RELEASE_ELIGIBLE=$N1D_C3A_RELEASE_ELIGIBLE"
    echo "N1D_C3B_BUILD_AUTHORIZED=$N1D_C3B_BUILD_AUTHORIZED"
    echo "N1D_C3_RELEASE_ELIGIBLE=$N1D_C3_RELEASE_ELIGIBLE"
    echo "ANDROID_TARGET_COMPILATION_AUTHORIZED=NO"
    echo "DEVICE_CONTACT_AUTHORIZED=NO"
    echo "FLASH_AUTHORIZED=NO"
} > "$EVIDENCE_DIR/parse-state.env"

(
    cd "$EVIDENCE_DIR"
    find . -type f ! -name SHA256SUMS.txt ! -name parse.log -print0         | LC_ALL=C sort -z         | xargs -0 sha256sum > SHA256SUMS.txt
    sha256sum -c SHA256SUMS.txt >/dev/null
)

echo "N1D_C3A_TREBLEDROID_PARSE_IDENTITY=PASS"
echo "N1D_C3A_TREBLEDROID_PARSE_NO_TARGET_ARTIFACTS=PASS"
echo "N1D_C3A_TREBLEDROID_PARSE=PASS"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "PARSE_OUT=$PARSE_OUT"
