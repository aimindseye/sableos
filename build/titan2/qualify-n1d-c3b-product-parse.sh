#!/usr/bin/env bash
# Parse the C3B generated engineering product without target compilation.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STORAGE_PROFILE="$ROOT/build/config/storage.env"
TRANSITION="$ROOT/build/titan2/n1d-c3b-transition.env"
PREP="$ROOT/build/titan2/prepare-n1d-c3b-engineering.sh"
STORAGE_VERIFY="$ROOT/build/host/verify-storage-root.sh"

fail() {
    echo "N1D_C3B_PRODUCT_PARSE=FAIL $*" >&2
    exit 1
}

for f in "$STORAGE_PROFILE" "$TRANSITION" "$PREP" "$STORAGE_VERIFY"; do
    [[ -f "$f" ]] || fail "missing_file=$f"
done

# shellcheck source=/dev/null
source "$STORAGE_PROFILE"
# shellcheck source=/dev/null
source "$TRANSITION"

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

[[ "$PARSE_AUTHORIZED" == YES ]] ||
    fail product_parse_requires_--authorize-product-parse
[[ "$N1D_C3_CURRENT_ACTIVE_PHASE" == C3B_ENGINEERING ]] ||
    fail active_phase_mismatch
[[ "$N1D_C3B_RUNTIME_PATCH_ALLOWLIST_COUNT" == 0 ]] ||
    fail runtime_allowlist_not_zero

ANDROID_ROOT="$SABLE_BUILD_ROOT/$N1D_C3B_ANDROID_ROOT_REL"
OUT_ROOT="$SABLE_BUILD_ROOT/$N1D_C3B_OUT_ROOT_REL"
PARSE_ROOT="$OUT_ROOT/parse"
EVIDENCE_ROOT="$SABLE_EVIDENCE_ROOT/titan2/n1d-c3b-product-parse"
LUNCH_TARGET="$N1D_C3B_GENERATED_PRODUCT-$N1D_C3B_RELEASE_CONFIG-$N1D_C3B_ENGINEERING_VARIANT"

echo "===== N1D C3B ENGINEERING PRODUCT PARSE ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "PRODUCT_PARSE_AUTHORIZED=YES_EXPLICIT"
echo "ANDROID_TARGET_COMPILATION_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "SIGNING_AUTHORIZED=NO"
echo "RELEASE_ELIGIBLE=NO"
echo "N1D_C3_ACTIVE_PHASE=$N1D_C3_CURRENT_ACTIVE_PHASE"
echo "LUNCH_TARGET=$LUNCH_TARGET"

bash "$STORAGE_VERIFY" runtime
bash "$PREP" verify

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="$EVIDENCE_ROOT/$stamp-c3b-parse"
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

    [[ "${TARGET_PRODUCT:-}" == "$N1D_C3B_GENERATED_PRODUCT" ]] ||
        fail "target_product=${TARGET_PRODUCT:-unset}"
    [[ "${TARGET_RELEASE:-}" == "$N1D_C3B_RELEASE_CONFIG" ]] ||
        fail "target_release=${TARGET_RELEASE:-unset}"
    [[ "${TARGET_BUILD_VARIANT:-}" == "$N1D_C3B_ENGINEERING_VARIANT" ]] ||
        fail "target_variant=${TARGET_BUILD_VARIANT:-unset}"

    build/soong/soong_ui.bash         --dumpvars-mode         --vars="TARGET_PRODUCT TARGET_BUILD_VARIANT PRODUCT_DEVICE PRODUCT_BRAND PRODUCT_MODEL BUILD_ID PLATFORM_VERSION PRODUCT_OUT"         > "$EVIDENCE_DIR/product-vars.env"
)

grep -Fxq "TARGET_PRODUCT='$N1D_C3B_GENERATED_PRODUCT'" "$EVIDENCE_DIR/product-vars.env" ||
    fail dumpvars_target_product
grep -Fxq "TARGET_BUILD_VARIANT='$N1D_C3B_ENGINEERING_VARIANT'" "$EVIDENCE_DIR/product-vars.env" ||
    fail dumpvars_target_variant
grep -Fxq "PRODUCT_DEVICE='$N1D_C3B_PRODUCT_DEVICE'" "$EVIDENCE_DIR/product-vars.env" ||
    fail dumpvars_product_device
grep -Fxq "PRODUCT_BRAND='google'" "$EVIDENCE_DIR/product-vars.env" ||
    fail dumpvars_product_brand
grep -Fxq "PRODUCT_MODEL='TrebleDroid vanilla'" "$EVIDENCE_DIR/product-vars.env" ||
    fail dumpvars_product_model

if find "$PARSE_OUT" -type f     ( -name '*.img' -o -name '*target_files*.zip' -o -name '*-ota-*.zip' -o -name '*-ota.zip' )     -print -quit | grep -q .
then
    fail "unexpected_target_artifact=$PARSE_OUT"
fi

{
    echo "N1D_C3B_PRODUCT_PARSE=PASS"
    echo "N1D_C3B_LUNCH_TARGET=$LUNCH_TARGET"
    echo "N1D_C3B_PRODUCT=$N1D_C3B_GENERATED_PRODUCT"
    echo "N1D_C3B_RELEASE_CONFIG=$N1D_C3B_RELEASE_CONFIG"
    echo "N1D_C3B_VARIANT=$N1D_C3B_ENGINEERING_VARIANT"
    echo "N1D_C3B_RUNTIME_PATCH_ALLOWLIST_COUNT=$N1D_C3B_RUNTIME_PATCH_ALLOWLIST_COUNT"
    echo "N1D_C3B_RELEASE_ELIGIBLE=$N1D_C3B_RELEASE_ELIGIBLE"
    echo "ANDROID_TARGET_COMPILATION_AUTHORIZED=NO"
    echo "DEVICE_CONTACT_AUTHORIZED=NO"
    echo "FLASH_AUTHORIZED=NO"
} > "$EVIDENCE_DIR/parse-state.env"

(
    cd "$EVIDENCE_DIR"
    find . -type f ! -name SHA256SUMS.txt ! -name parse.log -print0 |
        LC_ALL=C sort -z |
        xargs -0 sha256sum > SHA256SUMS.txt
    sha256sum -c SHA256SUMS.txt >/dev/null
)

echo "N1D_C3B_PRODUCT_PARSE_IDENTITY=PASS"
echo "N1D_C3B_PRODUCT_PARSE_NO_TARGET_ARTIFACTS=PASS"
echo "N1D_C3B_PRODUCT_PARSE=PASS"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "PARSE_OUT=$PARSE_OUT"
