#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STAGER="$ROOT/build/titan2/stage-n1d-c3b-e2-product-composition.sh"
PARSE="$ROOT/build/titan2/qualify-n1d-c3b-e2-product-parse.sh"
MODULE_BUILD="$ROOT/build/titan2/build-n1d-c3b-e2-modules.sh"
BASE_BUILD="$ROOT/build/titan2/build-n1d-c3b-systemimage.sh"
E3_BUILD="$ROOT/build/titan2/build-n1d-c3b-e3-systemimage.sh"
COMPOSITION_GATE="$ROOT/build/gates/n1d-c3b-e2-product-composition-contract.sh"

fail() {
    echo "N1D_C3B_E3_SYSTEMIMAGE_CONTRACT=FAIL $*" >&2
    exit 1
}

for f in "$STAGER" "$PARSE" "$MODULE_BUILD" "$BASE_BUILD" "$E3_BUILD" "$COMPOSITION_GATE"; do
    [[ -f "$f" ]] || fail "missing_file=$f"
    bash -n "$f" || fail "syntax=$f"
done

bash "$COMPOSITION_GATE"

for token in \
    "grep -Ev '^[[:space:]]*#' \"\$DEST/sable_titan2.mk\"" \
    "fail retired_or_direct_gsi_inheritance_present"
do
    grep -Fq -- "$token" "$STAGER" || fail "stager_missing=$token"
done

for token in \
    'TARGET_COPY_OUT_PRODUCT' \
    "grep -Fxq \"TARGET_COPY_OUT_PRODUCT='system/product'\"" \
    'fail dumpvars_product_not_folded_into_system' \
    'N1D_C3B_E2_PRODUCT_PARSE_PRODUCT_ROUTE=PASS_SYSTEM_PRODUCT'
do
    grep -Fq -- "$token" "$PARSE" || fail "parse_missing=$token"
done

for token in \
    'product_copy_out="$(get_build_var TARGET_COPY_OUT_PRODUCT)"' \
    '[[ "$product_copy_out" == "system/product" ]]' \
    'apk="$PRODUCT_OUT/$PRODUCT_COPY_OUT/app/$module/$module.apk"' \
    'N1D_C3B_E2_MODULE_BUILD_PRODUCT_COPY_OUT=PASS_SYSTEM_PRODUCT'
do
    grep -Fq -- "$token" "$MODULE_BUILD" || fail "module_build_missing=$token"
done

for token in \
    '--preflight-only' \
    'BUILD_AUTHORIZED=NO_PREFLIGHT_ONLY' \
    'N1D_C3B_SYSTEMIMAGE_PREFLIGHT=PASS' \
    'compile_requires_--authorize-c3b-compile'
do
    grep -Fq -- "$token" "$BASE_BUILD" || fail "base_build_missing=$token"
done

base_systemimage_count="$(grep -Ec '^[[:space:]]*make[[:space:]]+systemimage[[:space:]]' "$BASE_BUILD" || true)"
[[ "$base_systemimage_count" == 1 ]] ||
    fail "base_systemimage_count=$base_systemimage_count"

for token in \
    'explicit_e3_systemimage_authority_required' \
    'bash "$COMPAT_DRIVER"' \
    '--preflight-only' \
    '--authorize-host-layout-source-mutation' \
    '--authorize-scaffold-compat-source-mutation' \
    '--authorize-build-compat-source-mutation' \
    'N1D_C3B_SYSTEMIMAGE_PREFLIGHT=PASS' \
    'bash "$E2_QUALIFIER"' \
    '--authorize-composition-qualification' \
    'N1D_C3B_E2_PRODUCT_COMPOSITION_QUALIFICATION=PASS' \
    'N1D_C3B_E2_CANONICAL_HEAD=$CURRENT_HEAD' \
    'N1D_C3B_E2_CANONICAL_BUILD_HEAD=$CURRENT_HEAD' \
    'product_copy_out="$(get_build_var TARGET_COPY_OUT_PRODUCT)"' \
    '[[ "$product_copy_out" == "system/product" ]]' \
    'N1D_C3B_E3_PREBUILD_PRODUCT_ROUTE=PASS_SYSTEM_PRODUCT' \
    'make systemimage -j"$JOBS"' \
    'apk="$PRODUCT_OUT/$PRODUCT_COPY_OUT/app/$module/$module.apk"' \
    'N1D_C3B_E3_MODULES_IN_SYSTEM_TREE=PASS count=5' \
    'N1D_C3B_E3_POSTBUILD_PACKAGING_ARTIFACTS=PASS_ABSENT' \
    'N1D_C3B_E3_SYSTEMIMAGE=PASS' \
    'TARGET_FILES_AUTHORIZED=NO' \
    'OTA_AUTHORIZED=NO' \
    'DEVICE_CONTACT_AUTHORIZED=NO' \
    'FLASH_AUTHORIZED=NO' \
    'PRODUCTION_SIGNING_AUTHORIZED=NO' \
    'RELEASE_ELIGIBLE=NO'
do
    grep -Fq -- "$token" "$E3_BUILD" || fail "e3_build_missing=$token"
done

e3_systemimage_count="$(grep -Ec '^[[:space:]]*make[[:space:]]+systemimage[[:space:]]' "$E3_BUILD" || true)"
[[ "$e3_systemimage_count" == 1 ]] ||
    fail "e3_systemimage_count=$e3_systemimage_count"

compat_line="$(grep -nF 'bash "$COMPAT_DRIVER"' "$E3_BUILD" | head -n1 | cut -d: -f1)"
e2_line="$(grep -nF 'bash "$E2_QUALIFIER"' "$E3_BUILD" | head -n1 | cut -d: -f1)"
image_line="$(grep -nE '^[[:space:]]*make[[:space:]]+systemimage[[:space:]]' "$E3_BUILD" | head -n1 | cut -d: -f1)"
[[ -n "$compat_line" && -n "$e2_line" && -n "$image_line" ]] ||
    fail prebuild_order_marker_missing
(( compat_line < e2_line && e2_line < image_line )) ||
    fail "prebuild_order compat=$compat_line e2=$e2_line image=$image_line"

if grep -Eq '(^|[[:space:]])(curl|wget)([[:space:]]|$)|git[[:space:]]+(clone|fetch|pull)([[:space:]]|$)|repo[[:space:]]+sync' "$E3_BUILD"; then
    fail network_command_present
fi
if grep -Eq '^[[:space:]]*(adb|fastboot)([[:space:]]|$)' "$E3_BUILD"; then
    fail device_command_present
fi
if grep -Eq '(^|[[:space:]])(clean|clobber)([[:space:]]|$)|rm[[:space:]]+-rf' "$E3_BUILD"; then
    fail destructive_command_present
fi
if grep -Eq 'target-files-package|otatools|(^|[[:space:]])dist([[:space:]]|$)' "$E3_BUILD"; then
    fail release_packaging_goal_present
fi

echo "N1D_C3B_E3_STAGING_GUARD=PASS_COMMENT_AWARE"
echo "N1D_C3B_E3_PRODUCT_ROUTE_GATE=PASS_SYSTEM_PRODUCT"
echo "N1D_C3B_E3_MODULE_PATH_GATE=PASS_DYNAMIC_SYSTEM_PRODUCT"
echo "N1D_C3B_E3_COMPAT_PREFLIGHT_GATE=PASS_NO_COMPILE_MODE"
echo "N1D_C3B_E3_BUILD_ORDER=PASS_COMPAT_THEN_E2_THEN_SYSTEMIMAGE"
echo "N1D_C3B_E3_SYSTEMIMAGE_SCOPE=PASS_EXACT_ONE_SYSTEMIMAGE"
echo "N1D_C3B_E3_NETWORK_DEVICE_RELEASE_BOUNDARY=PASS_BLOCKED"
echo "N1D_C3B_E3_SYSTEMIMAGE_CONTRACT=PASS"
