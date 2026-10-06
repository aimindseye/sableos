#!/usr/bin/env python3
from __future__ import annotations

import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[2]
failures: list[str] = []

def read(rel: str) -> str:
    p = ROOT / rel
    if not p.is_file():
        failures.append(f"missing:{rel}")
        return ""
    return p.read_text(encoding="utf-8")

fresh = read("build/titan2/n1d-fresh-source.env")
c3 = read("build/titan2/n1d-c3-trebledroid.env")
decisions = read("docs/titan2/N1I_B_DECISIONS.env")
admission = read("build/titan2/n1i-c-oem-ims-admission.env")
adapter = read("build/devices/titan2.sh")
driver = read("build/titan2/run-n1i-c1-cellular-isolation.sh")
bp = read("product/titan2/n1i-c1/Android.bp")
mk = read("product/titan2/n1i-c1/sable-titan2-n1i-c1.mk")
a4_native_superset = [
    x for x in read("product/titan2/n1i-c1/a4-native-superset.txt").splitlines()
    if x and not x.startswith("#")
]
config = [x for x in read("product/titan2/n1i-c1/config-paths.txt").splitlines() if x]
property_contexts = read("product/titan2/n1i-c1/sepolicy/system_ext/private/property_contexts")
policy = "\n".join([
    read("product/titan2/n1i-c1/sepolicy/system_ext/private/radio.te"),
    property_contexts,
    read("product/titan2/n1i-c1/sepolicy/system_ext/private/service_contexts"),
])

def need(text: str, value: str, label: str) -> None:
    if value not in text:
        failures.append(f"{label}:missing:{value}")

for line in (
    "N1D_AOSP_REVISION=android-16.0.0_r4",
    "N1D_GRAPHENE_MANIFEST_REF=refs/tags/2026061600",
    "N1D_RELEASE_CONFIG=bp4a",
):
    need(fresh, line, "fresh")
for line in (
    "N1D_C3_GRAPHENEOS_TAG=2026061600",
    "N1D_C3_RESTLESS_TAG=16.0.0-202606230923",
    "N1D_C3_RELEASE_CONFIG=bp4a",
    "N1D_C3_CONTROL_PATCH_COUNT=369",
):
    need(c3, line, "c3")
for line in (
    "FRAMEWORK_PATCH_REQUIRED_NOW=NO",
    "MTK_RADIOEX_SHIM_REQUIRED_NOW=NO",
    "PROPERTY_HOLD_REQUIRED=NO",
    "APN_ONLY_FIX_JUSTIFIED=NO",
    "STOCK_SUPER_HYBRID_REQUIRED_NOW=NO",
    "TREBLEDROID_MTK_IMS_RUNTIME_TRIAL=FAIL_BOUND_READY_BUT_UNREGISTERED",
    "OEM_MTKIMS_WORKING_STOCK_REFERENCE=YES",
    "DUAL_SIM_SINGLE_SIM_TRAY1_REQUIRED=YES",
    "DUAL_SIM_SINGLE_SIM_TRAY2_REQUIRED=YES",
    "DUAL_SIM_DSDS_REQUIRED=YES",
):
    need(decisions, line, "decision")
for line in (
    "N1I_C_REGISTRATION_DATA_AND_IMS_VOICE_EXPERIMENTS_SEPARATE=YES",
    "N1I_C_APN_ONLY_FIX_JUSTIFIED=NO",
    "N1I_C_PROPERTY_HOLD_ALLOWED=NO",
    "N1I_C_PERIODIC_RIL_RESTART_ALLOWED=NO",
    "N1I_C_PERMISSIVE_SELINUX_ALLOWED=NO",
    "N1I_C_FULL_STOCK_SYSTEM_EXT_IMPORT_ALLOWED=NO",
    "N1I_C_FULL_STOCK_VENDOR_COPY_ALLOWED=NO",
    "N1I_C_TREBLEDROID_MTK_IMS_RETRY_ALLOWED=NO",
    "N1I_C_OEM_MTKIMS_NEXT_IMPLEMENTATION_PATH=YES",
    "N1I_C1_BASE_MAIN=177ef4fb76d661725165c5224f6a8495b2b420ec",
    "N1I_C1_ANDROID_PLATFORM=16",
    "N1I_C1_ANDROID_17_ALLOWED=NO",
    "N1I_C1_INITIAL_REGISTRATION_DATA_DELTA=NONE_PRESERVE_C3A_N1F",
    "N1I_C_A4_NATIVE_SUPERSET_ROLE=REFERENCE_ONLY_B2_SUPERSEDES_IMPORT_AUTHORITY",
    "N1I_C_B2_NATIVE_IMPORT_AUTHORITY=NO_CANDIDATE_COVERAGE_ONLY",
    "N1I_C1_INITIAL_STOCK_NATIVE_IMPORT_COUNT=0",
):
    need(admission, line, "admission")

if 'N1I_C_"/system/' in admission:
    failures.append("admission:malformed_native_marker")

need(adapter, "SABLE_DEVICE_BUILD_SUPPORTED=YES", "adapter")
need(adapter, "run-n1i-c2-cellular-mvp.sh", "adapter")
need(adapter, "--authorize-source-mutation", "adapter")
need(adapter, "--authorize-build", "adapter")
need(adapter, "SABLE_DEVICE_FLASH_SUPPORTED=NO", "adapter")

if subprocess.run(["bash", "-n", str(ROOT / "build/titan2/run-n1i-c1-cellular-isolation.sh")]).returncode:
    failures.append("driver:bash_syntax")

for value in (
    "android-16.0.0_r4",
    "refs/tags/2026061600",
    "16.0.0-*",
    "bp4a",
    "REGISTRATION_DATA_DELTA=NONE_PRESERVE_C3A_N1F",
    "NEW_FUNCTIONAL_DELTA=OEM_MTK_IMS_COMPATIBILITY_ISLAND_ONLY",
    "N1I_C1_DEVICE_CONTACT=NONE",
    "N1I_C1_FLASH=NONE",
):
    need(driver, value, "driver")

for forbidden in (
    "SOONG_ALLOW_MISSING_DEPENDENCIES",
    "setenforce 0",
    "SABLE_ADB",
    "SABLE_FASTBOOT",
    "persist.vendor.radio.simswitch=",
    "persist.vendor.radio.c_capability_slot=",
    "android-17",
    "Android 17",
):
    if forbidden in driver + bp + mk:
        failures.append(f"forbidden:{forbidden}")

if "PRODUCT_COPY_FILES" in mk:
    failures.append("mk:PRODUCT_COPY_FILES_forbidden")
if bp.count("cc_prebuilt_library_shared {") != 0:
    failures.append(
        f"bp:stock_native_prebuilt_count={bp.count('cc_prebuilt_library_shared {')}"
    )
if "check_elf_files: false" in bp:
    failures.append("bp:elf_check_bypass_forbidden")
if "compile_multilib:" in bp:
    failures.append("bp:native_prebuilt_properties_forbidden")

for value in (
    'name: "ImsService"',
    'filename: "ImsService.apk"',
    'certificate: "platform"',
    'name: "SableN1IC1MediatekCommon"',
    'stem: "mediatek-common"',
    'name: "SableN1IC1MediatekImsBase"',
    'stem: "mediatek-ims-base"',
):
    need(bp, value, "bp")
for value in (
    "$(call inherit-product, vendor/sable/titan2/c3b/sable-titan2-apps.mk)",
    "    ImsService",
    "system_ext:SableN1IC1MediatekCommon",
    "system_ext:SableN1IC1MediatekImsBase",
    "PRODUCT_CONFIGURED_JAR_LOCATION_OVERRIDES",
    "system_ext:SableN1IC1MediatekCommon:system_ext:mediatek-common",
    "system_ext:SableN1IC1MediatekImsBase:system_ext:mediatek-ims-base",
    "SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS",
):
    need(mk, value, "mk")

if len(a4_native_superset) != 33 or len(set(a4_native_superset)) != 33:
    failures.append(
        "a4_native_superset:"
        f"count={len(a4_native_superset)} unique={len(set(a4_native_superset))}"
    )
if (ROOT / "product/titan2/n1i-c1/native-paths.txt").exists():
    failures.append("native_paths:retired_product_input_present")
if config != [
    "/system_ext/etc/permissions/system-ext-permissions-mediatek.xml",
    "/system_ext/etc/sysconfig/com.mediatek.ims.config.xml",
    "/system/etc/permissions/privapp-permissions-mediatek.xml",
]:
    failures.append("config_paths:not_exact")

for forbidden in (
    "system_mtk_capability_switch_prop",
    "persist.vendor.radio.simswitchstate",
    "persist.vendor.radio.wait",
    "vendor.ril.imsi.status",
    "epdg_service",
    "permissive",
):
    if forbidden in policy:
        failures.append(f"sepolicy:forbidden:{forbidden}")

for value in (
    "set_prop(radio, system_mtk_imsconfig_prop)",
    "set_prop(radio, system_mtk_wfc_entitlement_prop)",
    "get_prop(radio, system_mtk_dbg_ims_prop)",
    "set_prop(radio, system_mtk_clientapi_support_prop)",
    "get_prop(radio, system_mtk_persist_ims_data_prop)",
    "vendor.mediatek.hardware.mtkradioex.ims.IMtkRadioExIms/slot1",
    "vendor.mediatek.hardware.mtkradioex.ims.IMtkRadioExIms/slot2",
):
    need(policy, value, "sepolicy")
if "slot3" in policy or "slot4" in policy:
    failures.append("sepolicy:non_titan_slots")

property_context_rows = [
    line for line in property_contexts.splitlines()
    if line.strip() and not line.lstrip().startswith("#")
]
property_types = []
for line in property_context_rows:
    match = re.search(r":([A-Za-z0-9_]+):s0$", line.split()[-1])
    if match is None:
        failures.append(f"sepolicy:property_context_parse:{line}")
        continue
    property_types.append(match.group(1))

if len(property_context_rows) != 9:
    failures.append(
        f"sepolicy:property_context_count={len(property_context_rows)}"
    )
expected_property_types = {
    "system_mtk_clientapi_support_prop",
    "system_mtk_dbg_ims_prop",
    "system_mtk_imsconfig_prop",
    "system_mtk_persist_ims_data_prop",
    "system_mtk_wfc_entitlement_prop",
}
if set(property_types) != expected_property_types:
    failures.append(
        "sepolicy:property_type_set="
        + ",".join(sorted(set(property_types)))
    )

for value in (
    "generate_property_policy",
    "system_internal_property_type",
    "system_restricted_property_type",
    "system_public_property_type",
    "N1I_C1_PROPERTY_CONTEXT_COUNT={len(types)}",
    "N1I_C1_PROPERTY_TYPE_COUNT={len(unique_types)}",
    "N1I_C1_PROPERTY_POLICY=PASS_STOCK_DERIVED",
):
    need(driver, value, "property_policy_derivation")

if (ROOT / "product/titan2/n1i-c1/sepolicy/system_ext/private/property.te").exists():
    failures.append("sepolicy:property_type_class_must_be_generated_not_committed")

for value in (
    "N1I_C1_B2_NATIVE_AUTHORITY=PASS_NO_INITIAL_STOCK_SO_IMPORT",
    "N1I_C1_STOCK_NATIVE_IMPORT=PASS_ZERO_INITIAL",
    "N1I_C1_STOCK_NATIVE_PREBUILT_COUNT=0",
    "N1I_C1_A4_NATIVE_SUPERSET=REFERENCE_ONLY_B2_SUPERSEDES_IMPORT_AUTHORITY",
    "out-n1i-c1-${SOURCE_COMMIT:0:12}",
):
    need(driver, value, "native_admission_boundary")

for forbidden in (
    'native-paths.txt',
    'copy_stock_path "$p" "$SYSROOT" "$EXTROOT"; done < "$C1_TEMPLATE/native-paths.txt"',
    'N1I_C1_NATIVE_CLOSURE=PASS count=33',
):
    if forbidden in driver:
        failures.append(f"driver:retired_native_import:{forbidden}")

for value in (
    "get_build_var PRODUCT_CONFIGURED_JAR_LOCATION_OVERRIDES",
    "N1I_C1_BOOTJAR_LOCATION_OVERRIDES=PASS",
    "bootjar_location_override_common",
    "bootjar_location_override_ims",
):
    need(driver, value, "bootjar_location_override")

for forbidden in (
    "/system_ext/framework/SableN1IC1MediatekCommon.jar",
    "/system_ext/framework/SableN1IC1MediatekImsBase.jar",
):
    if forbidden in driver:
        failures.append(f"driver:wrong_bootjar_device_path:{forbidden}")

for value in (
    'built_payload_path',
    '/system_ext/*)',
    'printf \'%s/%s/%s\\n\' "$PRODUCT_OUT" "$COPYOUT"',
    'printf \'%s/system/%s\\n\' "$PRODUCT_OUT"',
):
    need(driver, value, "driver_output_mapping")

if failures:
    print("N1I_C1_ANDROID16_CONTRACT=FAIL")
    for x in failures:
        print(f"N1I_C1_ANDROID16_CONTRACT_FAILURE={x}")
    raise SystemExit(1)

print("N1I_C1_ANDROID_PLATFORM=16")
print("N1I_C1_ANDROID_17_ALLOWED=NO")
print("N1I_C1_A4_NATIVE_SUPERSET_COUNT=33")
print("N1I_C1_STOCK_NATIVE_PREBUILT_COUNT=0")
print("N1I_C1_CONFIG_PREBUILT_COUNT=3")
print("N1I_C1_REGISTRATION_DATA_DELTA=NONE_PRESERVE_C3A_N1F")
print("N1I_C1_NEW_FUNCTIONAL_DELTA=OEM_MTK_IMS_ONLY")
print("N1I_C1_ANDROID16_CONTRACT=PASS")
