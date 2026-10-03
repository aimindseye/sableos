#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROFILE="$ROOT/build/titan2/n1d-c3b-e2-product-composition.env"
ADMISSION_GATE="$ROOT/build/gates/n1d-c3b-e2-product-admission-contract.sh"
E1_COMPOSITION_GATE="$ROOT/build/gates/n1d-c3-product-composition-contract.sh"
APP_BUILD="$ROOT/build/titan2/build-n1d-c3b-e2-product-apps.sh"
STAGER="$ROOT/build/titan2/stage-n1d-c3b-e2-product-composition.sh"
PARSE_DRIVER="$ROOT/build/titan2/qualify-n1d-c3b-e2-product-parse.sh"
MODULE_BUILD="$ROOT/build/titan2/build-n1d-c3b-e2-modules.sh"
ORCHESTRATOR="$ROOT/build/titan2/qualify-n1d-c3b-e2-product-composition.sh"
TEMPLATE="$ROOT/product/titan2/c3b"
MODULE_LEDGER="$ROOT/docs/C3B_PRODUCT_SOURCE_MODULES.tsv"

fail() {
    echo "N1D_C3B_E2_PRODUCT_COMPOSITION_CONTRACT=FAIL $*" >&2
    exit 1
}

for f in \
    "$PROFILE" \
    "$ADMISSION_GATE" \
    "$E1_COMPOSITION_GATE" \
    "$APP_BUILD" \
    "$STAGER" \
    "$PARSE_DRIVER" \
    "$MODULE_BUILD" \
    "$ORCHESTRATOR" \
    "$TEMPLATE/Android.bp" \
    "$TEMPLATE/AndroidProducts.mk" \
    "$TEMPLATE/sable-titan2-apps.mk" \
    "$TEMPLATE/sable_titan2.mk" \
    "$MODULE_LEDGER"
do
    [[ -f "$f" ]] || fail "missing_file=$f"
done

bash -n "$PROFILE" || fail "syntax=$PROFILE"
bash -n "$APP_BUILD" || fail "syntax=$APP_BUILD"
bash -n "$STAGER" || fail "syntax=$STAGER"
bash -n "$PARSE_DRIVER" || fail "syntax=$PARSE_DRIVER"
bash -n "$MODULE_BUILD" || fail "syntax=$MODULE_BUILD"
bash -n "$ORCHESTRATOR" || fail "syntax=$ORCHESTRATOR"

bash "$ADMISSION_GATE"
bash "$E1_COMPOSITION_GATE"

require_line() {
    local line="$1"
    grep -Fxq "$line" "$PROFILE" || fail "missing_profile_line=$line"
}

required_lines=(
    'N1D_C3B_E2_COMPOSITION_VERSION=1'
    'N1D_C3B_E2_COMPOSITION_DATE=2026-10-02'
    'N1D_C3B_E2_COMPOSITION_PHASE=C3B_E2_PRODUCT_COMPOSITION'
    'N1D_C3B_E2_SOURCE_IMPORT_COMMIT=aafb543565c9d59ed5e0d9cda876aabb4967f8aa'
    'N1D_C3B_E2_SOURCE_IMPORT_PARENT=8a7d933d1aabfc16ea207c2094aaf2a59960f7fc'
    'N1D_C3B_E2_SOURCE_IMPORT_FILE_COUNT=178'
    'N1D_C3B_E2_SOURCE_ADMISSION_STATUS=PASS_CANONICAL_SOURCE_STAGED'
    'N1D_C3B_E2_BASE_GENERATED_PRODUCT=treble_arm64_bvN'
    'N1D_C3B_E2_BASE_PRODUCT_MK=device/phh/treble/treble_arm64_bvN.mk'
    'N1D_C3B_E2_PRODUCT_NAME=sable_titan2'
    'N1D_C3B_E2_PRODUCT_DEVICE=tdgsi_arm64_ab'
    'N1D_C3B_E2_RELEASE_CONFIG=bp4a'
    'N1D_C3B_E2_BUILD_VARIANT=userdebug'
    'N1D_C3B_E2_BUILD_GOAL=systemimage'
    'N1D_C3B_E2_PRODUCT_BRAND=SableOS'
    'N1D_C3B_E2_PRODUCT_MODEL=SableOS Titan 2'
    'N1D_C3B_E2_PRODUCT_MANUFACTURER=SableOS'
    'N1D_C3B_E2_PRODUCT_WRAPPER_MODEL=INHERIT_PROVEN_E1_GENERATED_TREBLE_PRODUCT'
    'N1D_C3B_E2_RETIRED_HANDCRAFTED_PRODUCT_ALLOWED=NO'
    'N1D_C3B_E2_RETIRED_VENDOR_SABLE_N1D_ALLOWED=NO'
    'N1D_C3B_E2_ANDROID_STAGE_ROOT=vendor/sable/titan2'
    'N1D_C3B_E2_LUNCH_TARGET=sable_titan2-bp4a-userdebug'
    'N1D_C3B_E2_APP_BUILD_MODEL=PINNED_GRADLE_SOURCE_TO_UNSIGNED_RELEASE_APK'
    'N1D_C3B_E2_ANDROID_PACKAGING_MODEL=ANDROID_APP_IMPORT_DEFAULT_DEV_CERT'
    'N1D_C3B_E2_APP_PARTITION=PRODUCT'
    'N1D_C3B_E2_DEFAULT_DEV_CERT_REQUIRED=YES'
    'N1D_C3B_E2_PLATFORM_CERTIFICATE_ALLOWED=NO'
    'N1D_C3B_E2_PRESIGNED_ALLOWED=NO'
    'N1D_C3B_E2_PRIVILEGED_APP_COUNT=0'
    'N1D_C3B_E2_APP_OVERRIDE_COUNT=0'
    'N1D_C3B_E2_MODULE_COUNT=5'
    'N1D_C3B_E2_SABLESCREENS_PRODUCT_ADMISSION=NO_PROTOTYPE'
    'N1D_C3B_E2_STANDALONE_HOME_PRODUCT_ADMISSION=NO_RETIRED'
    'N1D_C3B_E2_REFERENCE_SOURCE_PRODUCT_ADMISSION=NO_REFERENCE_ONLY'
    'N1D_C3B_E2_DEFAULT_IME_PROVISIONING=DEFERRED_IR005'
    'N1D_C3B_E2_SETUP_WIZARD_OWNERSHIP=NO_HELPER_ONLY'
    'N1D_C3B_E2_CAMERA_OVERRIDE_STOCK=NO_PENDING_RUNTIME'
    'N1D_C3B_E2_PHYSICAL_RUNTIME_AUTHORIZED=NO'
    'N1D_C3B_E2_DEVICE_CONTACT_AUTHORIZED=NO'
    'N1D_C3B_E2_FLASH_AUTHORIZED=NO'
    'N1D_C3B_E2_PRODUCTION_SIGNING_AUTHORIZED=NO'
    'N1D_C3B_E2_TARGET_FILES_AUTHORIZED=NO'
    'N1D_C3B_E2_OTA_AUTHORIZED=NO'
    'N1D_C3B_E2_RELEASE_ELIGIBLE=NO'
    'N1D_C3B_E2_PRODUCT_COMPOSITION_STATUS=DEFINED_PENDING_APP_BUILD_STAGE_AND_PARSE'
)
for line in "${required_lines[@]}"; do
    require_line "$line"
done

# No qualified app/source input may drift after the canonical source import.
source_paths=(
    apps/titan2/platform
    config/DETEKT_PROVENANCE.env
    config/QUALITY_SUPPRESSION_BUDGET.tsv
    config/detekt.yml
    third_party/phosphor-icons
    third_party/pinyin_zh
    tools/gen_first_party_icons.py
    tools/gen_indic_rows.py
    tools/gen_phonetic.py
    tools/gen_pinyin_dict.py
    tools/gen_pinyin_license_bundle.py
    tools/indic_common.py
    tools/test_gen_pinyin_dict.py
)
git -C "$ROOT" diff --quiet aafb543565c9d59ed5e0d9cda876aabb4967f8aa HEAD -- "${source_paths[@]}" ||
    fail qualified_product_source_drift_after_import

WRAPPER="$TEMPLATE/sable_titan2.mk"
APPS_MK="$TEMPLATE/sable-titan2-apps.mk"
PRODUCTS="$TEMPLATE/AndroidProducts.mk"
BP="$TEMPLATE/Android.bp"

grep -Fxq '$(call inherit-product, device/phh/treble/treble_arm64_bvN.mk)' "$WRAPPER" ||
    fail generated_e1_product_inherit_missing
grep -Fxq '$(call inherit-product, vendor/sable/titan2/sable-titan2-apps.mk)' "$WRAPPER" ||
    fail sable_apps_inherit_missing
for line in \
    'PRODUCT_NAME := sable_titan2' \
    'PRODUCT_DEVICE := tdgsi_arm64_ab' \
    'PRODUCT_BRAND := SableOS' \
    'PRODUCT_MODEL := SableOS Titan 2' \
    'PRODUCT_MANUFACTURER := SableOS'
do
    grep -Fxq "$line" "$WRAPPER" || fail "wrapper_identity_missing=$line"
done

if grep -Eq 'generic_system_arm64|gsi_release|vendor/sable/n1d|sable_titan2_n1d_arm64' "$WRAPPER"; then
    fail retired_or_direct_gsi_product_reintroduced
fi

grep -Fxq '    sable_titan2-bp4a-userdebug' "$PRODUCTS" ||
    fail lunch_target_missing

python3 - "$BP" "$APPS_MK" "$MODULE_LEDGER" <<'PY'
from __future__ import annotations
import csv
import pathlib
import re
import sys

bp = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
apps = pathlib.Path(sys.argv[2]).read_text(encoding="utf-8")
ledger_path = pathlib.Path(sys.argv[3])

expected = {
    "SableTitan2Keyboard": ("apps/titan2/platform/keyboard", "org.sableos.titan2.keyboard"),
    "SableTitan2Camera": ("apps/titan2/platform/camera", "org.sableos.titan2.camera"),
    "SableTitan2DisplayCompat": ("apps/titan2/platform/displaycompat", "org.sableos.titan2.displaycompat"),
    "SableTitan2Setup": ("apps/titan2/platform/setup", "org.sableos.titan2.setup"),
    "SableTitan2RadioDiag": ("apps/titan2/platform/radiodiag", "org.sableos.titan2.radiodiag"),
}

if bp.count("android_app_import {") != len(expected):
    raise SystemExit("N1D_C3B_E2_PRODUCT_COMPOSITION_CONTRACT=FAIL android_app_import_count")
for module in expected:
    if f'name: "{module}"' not in bp:
        raise SystemExit(f"N1D_C3B_E2_PRODUCT_COMPOSITION_CONTRACT=FAIL missing_bp_module={module}")
    if f'apk: "prebuilt/{module}.apk"' not in bp:
        raise SystemExit(f"N1D_C3B_E2_PRODUCT_COMPOSITION_CONTRACT=FAIL missing_bp_apk={module}")

for token, count in (
    ("default_dev_cert: true,", 5),
    ("product_specific: true,", 5),
    ("privileged: false,", 5),
):
    if bp.count(token) != count:
        raise SystemExit(
            "N1D_C3B_E2_PRODUCT_COMPOSITION_CONTRACT=FAIL "
            f"bp_token={token!r} expected={count} actual={bp.count(token)}"
        )

for forbidden in (
    "presigned: true",
    'certificate: "platform"',
    "privileged: true",
    "overrides:",
):
    if forbidden in bp:
        raise SystemExit(
            "N1D_C3B_E2_PRODUCT_COMPOSITION_CONTRACT=FAIL "
            f"forbidden_bp_token={forbidden}"
        )

for module in expected:
    if not re.search(rf"(?m)^\s+{re.escape(module)}(?:\s*\\)?$", apps):
        raise SystemExit(f"N1D_C3B_E2_PRODUCT_COMPOSITION_CONTRACT=FAIL missing_product_package={module}")
for forbidden in ("SableTitan2Screens", "SableTitan2Home"):
    if forbidden in apps:
        raise SystemExit(f"N1D_C3B_E2_PRODUCT_COMPOSITION_CONTRACT=FAIL forbidden_product_module={forbidden}")

with ledger_path.open(encoding="utf-8", newline="") as fh:
    rows = {r["module_id"]: r for r in csv.DictReader(fh, delimiter="\t")}
for module, (source_path, package) in expected.items():
    row = rows.get(module)
    if row is None:
        raise SystemExit(f"N1D_C3B_E2_PRODUCT_COMPOSITION_CONTRACT=FAIL missing_ledger_module={module}")
    if row["source_path"] != source_path or row["application_id"] != package:
        raise SystemExit(f"N1D_C3B_E2_PRODUCT_COMPOSITION_CONTRACT=FAIL ledger_identity={module}")
    if row["requested_partition"] != "PRODUCT (canonical E2)":
        raise SystemExit(f"N1D_C3B_E2_PRODUCT_COMPOSITION_CONTRACT=FAIL ledger_partition={module}")
    if row["canonical_integration_status"] != "CANONICAL_SOURCE_ADMITTED_E2_IMAGE_NOT_BUILT":
        raise SystemExit(f"N1D_C3B_E2_PRODUCT_COMPOSITION_CONTRACT=FAIL ledger_status={module}")

if rows["SableTitan2Screens"]["canonical_integration_status"] != "NOT_ADMITTED":
    raise SystemExit("N1D_C3B_E2_PRODUCT_COMPOSITION_CONTRACT=FAIL prototype_admitted")
if rows["SableTitan2Home"]["canonical_integration_status"] != "REJECTED_BY_CANONICAL_ARCHITECTURE":
    raise SystemExit("N1D_C3B_E2_PRODUCT_COMPOSITION_CONTRACT=FAIL retired_home_admitted")
if rows["SableStartTypeToFindReference"]["canonical_integration_status"] != "NOT_ADMITTED":
    raise SystemExit("N1D_C3B_E2_PRODUCT_COMPOSITION_CONTRACT=FAIL reference_source_admitted")

print("N1D_C3B_E2_PRODUCT_TEMPLATE_MODEL=PASS")
print("N1D_C3B_E2_PRODUCT_LEDGER=PASS_5_CANONICAL_SOURCE_ADMITTED")
PY

for token in \
    '--offline' \
    '--dependency-verification=strict' \
    ':keyboard:assembleRelease' \
    ':camera:assembleRelease' \
    ':displaycompat:assembleRelease' \
    ':setup:assembleRelease' \
    ':radiodiag:assembleRelease' \
    'release_apk_unexpectedly_signed' \
    'signature_state'
do
    grep -Fq -- "$token" "$APP_BUILD" || fail "app_build_token_missing=$token"
done

for token in \
    'bash "$PREP" verify' \
    'N1D_C3B_E2_PRODUCT_STAGE_BUNDLE=PASS_EXACT_5_UNSIGNED' \
    'default_dev_cert_count' \
    'product_specific_count' \
    'privileged_false_count' \
    'retired_vendor_sable_n1d_present'
do
    grep -Fq -- "$token" "$STAGER" || fail "stager_token_missing=$token"
done

for token in \
    'N1D_C3B_E2_PRODUCT_PARSE_IDENTITY=PASS_SABLE_TITAN2' \
    'N1D_C3B_E2_PRODUCT_PARSE_BASE_INHERIT=PASS_GENERATED_E1_TREBLE' \
    'ANDROID_TARGET_COMPILATION_AUTHORIZED=NO' \
    'DEVICE_CONTACT_AUTHORIZED=NO' \
    'PRODUCTION_SIGNING_AUTHORIZED=NO'
do
    grep -Fq -- "$token" "$PARSE_DRIVER" || fail "parse_driver_token_missing=$token"
done

for token in \
    '--authorize-composition-qualification' \
    'N1D_C3B_E2_COMPOSITION_APP_BUILD=PASS' \
    'N1D_C3B_E2_COMPOSITION_ANDROID_STAGE=PASS' \
    'N1D_C3B_E2_COMPOSITION_PARSE=PASS' \
    'N1D_C3B_E2_COMPOSITION_MODULE_BUILD=PASS count=5' \
    'N1D_C3B_E2_PRODUCT_COMPOSITION_QUALIFICATION=PASS' \
    'FULL_IMAGE_BUILD_AUTHORIZED=NO' \
    'DEVICE_CONTACT_AUTHORIZED=NO' \
    'PRODUCTION_SIGNING_AUTHORIZED=NO'
do
    grep -Fq -- "$token" "$ORCHESTRATOR" || fail "orchestrator_token_missing=$token"
done

for token in \
    '--parse-evidence' \
    'N1D_C3B_E2_MODULE_BUILD_PARSE_PREREQUISITE=PASS' \
    'N1D_C3B_E2_MODULE_BUILD_PRODUCT_PACKAGES=PASS count=5' \
    'get_build_var PRODUCT_PACKAGES' \
    'BUILD_AUTHORIZED=YES_EXACT_5_MODULES' \
    'FULL_IMAGE_BUILD_AUTHORIZED=NO' \
    'SableTitan2Keyboard' \
    'SableTitan2Camera' \
    'SableTitan2DisplayCompat' \
    'SableTitan2Setup' \
    'SableTitan2RadioDiag' \
    'N1D_C3B_E2_MODULE_BUILD_FULL_IMAGE=PASS_ABSENT' \
    'PRODUCTION_SIGNING_AUTHORIZED=NO'
do
    grep -Fq -- "$token" "$MODULE_BUILD" || fail "module_build_token_missing=$token"
done

if grep -Eq '(^|[[:space:]])(curl|wget)([[:space:]]|$)|git[[:space:]]+(clone|fetch|pull)([[:space:]]|$)' "$APP_BUILD" "$STAGER" "$PARSE_DRIVER" "$MODULE_BUILD" "$ORCHESTRATOR"; then
    fail network_command_present
fi
if grep -Eq '^[[:space:]]*(adb|fastboot)([[:space:]]|$)' "$APP_BUILD" "$STAGER" "$PARSE_DRIVER" "$MODULE_BUILD"; then
    fail device_command_present
fi
if grep -Eq 'rm[[:space:]]+-rf|repo[[:space:]]+sync' "$APP_BUILD" "$STAGER" "$PARSE_DRIVER" "$MODULE_BUILD"; then
    fail destructive_or_sync_command_present
fi

echo "N1D_C3B_E2_SOURCE_IMPORT=PASS_CANONICAL_178"
echo "N1D_C3B_E2_SOURCE_DRIFT=PASS_ABSENT"
echo "N1D_C3B_E2_PRODUCT_IDENTITY=PASS_THIN_WRAPPER_SABLE_TITAN2"
echo "N1D_C3B_E2_BASE_INHERITANCE=PASS_GENERATED_E1_TREBLE"
echo "N1D_C3B_E2_MODULE_ADMISSION=PASS_5_NONPRIVILEGED_PRODUCT_APPS"
echo "N1D_C3B_E2_PACKAGING_MODEL=PASS_SOURCE_BUILT_UNSIGNED_DEFAULT_DEV_CERT"
echo "N1D_C3B_E2_DEFAULT_ROLE_POLICY=PASS_DEFERRED"
echo "N1D_C3B_E2_PROTOTYPE_HOME_REFERENCE_POLICY=PASS_EXCLUDED"
echo "N1D_C3B_E2_DEVICE_RELEASE_BOUNDARY=PASS_BLOCKED"
echo "N1D_C3B_E2_PRODUCT_COMPOSITION_CONTRACT=PASS"
