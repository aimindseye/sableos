#!/usr/bin/env bash
# Parse the C3B E2 thin-wrapper Sable product without target compilation.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STORAGE_PROFILE="$ROOT/build/config/storage.env"
TRANSITION="$ROOT/build/titan2/n1d-c3b-transition.env"
PROFILE="$ROOT/build/titan2/n1d-c3b-e2-product-composition.env"
COMPOSITION_GATE="$ROOT/build/gates/n1d-c3b-e2-product-composition-contract.sh"
STORAGE_VERIFY="$ROOT/build/host/verify-storage-root.sh"

fail() {
    echo "N1D_C3B_E2_PRODUCT_PARSE=FAIL $*" >&2
    exit 1
}

for f in "$STORAGE_PROFILE" "$TRANSITION" "$PROFILE" "$COMPOSITION_GATE" "$STORAGE_VERIFY"; do
    [[ -f "$f" ]] || fail "missing_file=$f"
done

# shellcheck source=/dev/null
source "$STORAGE_PROFILE"
# shellcheck source=/dev/null
source "$TRANSITION"
# shellcheck source=/dev/null
source "$PROFILE"

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
[[ "$N1D_C3B_RUNTIME_PATCH_ALLOWLIST_COUNT" == 0 ]] ||
    fail runtime_allowlist_not_zero

ANDROID_ROOT="$SABLE_BUILD_ROOT/$N1D_C3B_ANDROID_ROOT_REL"
OUT_ROOT="$SABLE_BUILD_ROOT/$N1D_C3B_OUT_ROOT_REL"
PARSE_ROOT="$OUT_ROOT/e2-parse"
EVIDENCE_ROOT="$SABLE_EVIDENCE_ROOT/titan2/n1d-c3b-e2-product-parse"
STAGE_ROOT="$ANDROID_ROOT/$N1D_C3B_E2_ANDROID_STAGE_ROOT"
LUNCH_TARGET="$N1D_C3B_E2_LUNCH_TARGET"

echo "===== N1D C3B E2 SABLE PRODUCT PARSE ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "PRODUCT_PARSE_AUTHORIZED=YES_EXPLICIT"
echo "ANDROID_TARGET_COMPILATION_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "PRODUCTION_SIGNING_AUTHORIZED=NO"
echo "RELEASE_ELIGIBLE=NO"
echo "LUNCH_TARGET=$LUNCH_TARGET"

bash "$STORAGE_VERIFY" runtime
bash "$COMPOSITION_GATE"

[[ -f "$STAGE_ROOT/source-binding.env" ]] ||
    fail "product_stage_missing=$STAGE_ROOT"
grep -Fxq "N1D_C3B_E2_SOURCE_IMPORT_COMMIT=$N1D_C3B_E2_SOURCE_IMPORT_COMMIT" "$STAGE_ROOT/source-binding.env" ||
    fail staged_source_binding
grep -Fxq "N1D_C3B_E2_PRODUCT_NAME=$N1D_C3B_E2_PRODUCT_NAME" "$STAGE_ROOT/source-binding.env" ||
    fail staged_product_identity
grep -Fxq "N1D_C3B_E2_MODULE_COUNT=$N1D_C3B_E2_MODULE_COUNT" "$STAGE_ROOT/source-binding.env" ||
    fail staged_module_count

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="$EVIDENCE_ROOT/$stamp-e2-parse"
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

    [[ "${TARGET_PRODUCT:-}" == "$N1D_C3B_E2_PRODUCT_NAME" ]] ||
        fail "target_product=${TARGET_PRODUCT:-unset}"
    [[ "${TARGET_RELEASE:-}" == "$N1D_C3B_E2_RELEASE_CONFIG" ]] ||
        fail "target_release=${TARGET_RELEASE:-unset}"
    [[ "${TARGET_BUILD_VARIANT:-}" == "$N1D_C3B_E2_BUILD_VARIANT" ]] ||
        fail "target_variant=${TARGET_BUILD_VARIANT:-unset}"

    build/soong/soong_ui.bash \
        --dumpvars-mode \
        --vars="TARGET_PRODUCT TARGET_BUILD_VARIANT PRODUCT_DEVICE PRODUCT_BRAND PRODUCT_MODEL PRODUCT_MANUFACTURER BUILD_ID PLATFORM_VERSION PRODUCT_OUT" \
        > "$EVIDENCE_DIR/product-vars.env"
)

grep -Fxq "TARGET_PRODUCT='$N1D_C3B_E2_PRODUCT_NAME'" "$EVIDENCE_DIR/product-vars.env" ||
    fail dumpvars_target_product
grep -Fxq "TARGET_BUILD_VARIANT='$N1D_C3B_E2_BUILD_VARIANT'" "$EVIDENCE_DIR/product-vars.env" ||
    fail dumpvars_target_variant
grep -Fxq "PRODUCT_DEVICE='$N1D_C3B_E2_PRODUCT_DEVICE'" "$EVIDENCE_DIR/product-vars.env" ||
    fail dumpvars_product_device
grep -Fxq "PRODUCT_BRAND='$N1D_C3B_E2_PRODUCT_BRAND'" "$EVIDENCE_DIR/product-vars.env" ||
    fail dumpvars_product_brand
grep -Fxq "PRODUCT_MODEL='$N1D_C3B_E2_PRODUCT_MODEL'" "$EVIDENCE_DIR/product-vars.env" ||
    fail dumpvars_product_model
grep -Fxq "PRODUCT_MANUFACTURER='$N1D_C3B_E2_PRODUCT_MANUFACTURER'" "$EVIDENCE_DIR/product-vars.env" ||
    fail dumpvars_product_manufacturer

if find "$PARSE_OUT" -type f \( -name '*.img' -o -name '*target_files*.zip' -o -name '*-ota*.zip' \) -print -quit | grep -q .; then
    fail "unexpected_target_artifact=$PARSE_OUT"
fi

{
    echo "N1D_C3B_E2_PRODUCT_PARSE=PASS"
    echo "N1D_C3B_E2_LUNCH_TARGET=$LUNCH_TARGET"
    echo "N1D_C3B_E2_PRODUCT=$N1D_C3B_E2_PRODUCT_NAME"
    echo "N1D_C3B_E2_PRODUCT_DEVICE=$N1D_C3B_E2_PRODUCT_DEVICE"
    echo "N1D_C3B_E2_RELEASE_CONFIG=$N1D_C3B_E2_RELEASE_CONFIG"
    echo "N1D_C3B_E2_VARIANT=$N1D_C3B_E2_BUILD_VARIANT"
    echo "N1D_C3B_RUNTIME_PATCH_ALLOWLIST_COUNT=$N1D_C3B_RUNTIME_PATCH_ALLOWLIST_COUNT"
    echo "ANDROID_TARGET_COMPILATION_AUTHORIZED=NO"
    echo "DEVICE_CONTACT_AUTHORIZED=NO"
    echo "FLASH_AUTHORIZED=NO"
    echo "PRODUCTION_SIGNING_AUTHORIZED=NO"
} > "$EVIDENCE_DIR/parse-state.env"

(
    cd "$EVIDENCE_DIR"
    find . -type f ! -name SHA256SUMS.txt ! -name parse.log -print0 |
        LC_ALL=C sort -z |
        xargs -0 sha256sum > SHA256SUMS.txt
    sha256sum -c SHA256SUMS.txt >/dev/null
)

echo "N1D_C3B_E2_PRODUCT_PARSE_IDENTITY=PASS_SABLE_TITAN2"
echo "N1D_C3B_E2_PRODUCT_PARSE_BASE_INHERIT=PASS_GENERATED_E1_TREBLE"
echo "N1D_C3B_E2_PRODUCT_PARSE_NO_TARGET_ARTIFACTS=PASS"
echo "N1D_C3B_E2_PRODUCT_PARSE=PASS"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
echo "PARSE_OUT=$PARSE_OUT"
