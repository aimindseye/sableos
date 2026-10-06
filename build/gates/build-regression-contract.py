#!/usr/bin/env python3
from __future__ import annotations

import csv
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
LEDGER = ROOT / "build" / "BUILD_REGRESSIONS.tsv"
failures: list[str] = []
passes: list[str] = []


def read(rel: str) -> str:
    path = ROOT / rel
    if not path.is_file():
        failures.append(f"missing:{rel}")
        return ""
    return path.read_text(encoding="utf-8")


def check(regression_id: str, condition: bool, detail: str) -> None:
    if condition:
        passes.append(regression_id)
        print(f"SABLE_BUILD_REGRESSION_{regression_id}=PASS {detail}")
    else:
        failures.append(f"{regression_id}:{detail}")


if not LEDGER.is_file():
    print("SABLE_BUILD_REGRESSION_CONTRACT=FAIL")
    print("SABLE_BUILD_REGRESSION_FAILURE=ledger_missing")
    raise SystemExit(1)

with LEDGER.open(encoding="utf-8", newline="") as fp:
    reader = csv.DictReader(fp, delimiter="\t")
    expected_header = ["regression_id", "scope", "status", "invariant", "owner"]
    if reader.fieldnames != expected_header:
        failures.append(f"ledger_header:{reader.fieldnames}")
        rows: list[dict[str, str]] = []
    else:
        rows = list(reader)

ids = [row["regression_id"] for row in rows]
required_ids = {
    "BR-001", "BR-002",
    "T2-001", "T2-002", "T2-003", "T2-004", "T2-005", "T2-006",
    "T2-007", "T2-008", "T2-009", "T2-010", "T2-011", "T2-012",
    "T2-013", "T2-014", "T2-015", "T2-016", "T2-017", "T2-018",
    "T2-019",
}
if len(ids) != len(set(ids)):
    failures.append("ledger_duplicate_ids")
if set(ids) != required_ids:
    failures.append("ledger_id_set:" + ",".join(sorted(set(ids))))
for row in rows:
    if row["status"] != "ACTIVE":
        failures.append(f"{row['regression_id']}:status={row['status']}")
    if row["scope"] not in {"GLOBAL", "TITAN2"}:
        failures.append(f"{row['regression_id']}:scope={row['scope']}")
    if not row["invariant"].strip() or not row["owner"].strip():
        failures.append(f"{row['regression_id']}:blank_metadata")

local_ci = read("build/local-ci/run.sh")
adapter = read("build/devices/titan2.sh")
driver = read("build/titan2/run-n1i-c1-cellular-isolation.sh")
contract = read("build/gates/n1i-c1-android16-contract.py")
fresh = read("build/titan2/n1d-fresh-source.env")
c3 = read("build/titan2/n1d-c3-trebledroid.env")
admission = read("build/titan2/n1i-c-oem-ims-admission.env")
bp = read("product/titan2/n1i-c1/Android.bp")
mk = read("product/titan2/n1i-c1/sable-titan2-n1i-c1.mk")
property_contexts = read(
    "product/titan2/n1i-c1/sepolicy/system_ext/private/property_contexts"
)
a4_ref = read("product/titan2/n1i-c1/a4-native-superset.txt")
postbuild_qualifier = read("build/titan2/qualify-n1i-c1-postbuild.sh")
c2_driver = read("build/titan2/run-n1i-c2-cellular-mvp.sh")
c2_bp = read("product/titan2/n1i-c2/Android.bp")
c2_mk = read("product/titan2/n1i-c2/sable-titan2-n1i-c2.mk")
c2_collision_audit = read("build/titan2/audit-n1i-c2-install-collisions.py")
c2_native_planner = read("build/titan2/plan-n1i-c2-native-install.py")
c2_native_plan_test = read("tests/titan2/n1i-c2/test-native-install-plan.py")

check(
    "BR-001",
    'if ! stage_failure_scan "$name" "$stage_start_line"; then' not in local_ci
    and 'if stage_failure_scan "$name" "$stage_start_line"; then' in local_ci
    and "local scan_rc=$?" in local_ci,
    "stage_log_scan_failure_propagates",
)

check(
    "BR-002",
    'SABLE_GITLEAKS_HISTORY_SCOPE=SOURCE_COMMIT commit=$SOURCE_COMMIT' in local_ci
    and '--log-opts="$SOURCE_COMMIT"' in local_ci
    and '--log-opts="--all"' not in local_ci,
    "gitleaks_source_commit_scoped",
)

active_titan_text = "\n".join((adapter, driver, bp, mk, c2_driver, c2_bp, c2_mk))
check(
    "T2-001",
    "N1D_AOSP_REVISION=android-16.0.0_r4" in fresh
    and "N1D_GRAPHENE_MANIFEST_REF=refs/tags/2026061600" in fresh
    and "N1D_C3_GRAPHENEOS_TAG=2026061600" in c3
    and "N1D_C3_RELEASE_CONFIG=bp4a" in c3
    and "android-17" not in active_titan_text
    and "Android 17" not in active_titan_text,
    "android16_authority_preserved",
)

forbidden = (
    "SOONG_ALLOW_MISSING_DEPENDENCIES",
    "setenforce 0",
    "persist.vendor.radio.simswitch=",
    "persist.vendor.radio.c_capability_slot=",
)
check(
    "T2-002",
    all(token not in active_titan_text for token in forbidden)
    and "SABLE_ADB" not in driver
    and "SABLE_FASTBOOT" not in driver
    and "SABLE_ADB" not in c2_driver
    and "SABLE_FASTBOOT" not in c2_driver,
    "unsafe_compatibility_and_device_write_bypasses_absent",
)

check(
    "T2-003",
    'python3 "$ROOT/build/gates/build-regression-contract.py"' in adapter
    and "TITAN2_BUILD_REGRESSION_PREFLIGHT=PASS" in adapter
    and 'python3 "$ROOT/build/gates/build-regression-contract.py"' in local_ci,
    "canonical_ci_and_device_build_hooks_present",
)

check(
    "T2-004",
    'out-n1i-c1-${SOURCE_COMMIT:0:12}' in driver
    and '[[ ! -e "$OUT_DIR_N1I" ]] || fail "fresh_out_required=$OUT_DIR_N1I"' in driver,
    "source_commit_scoped_fresh_android_out",
)

app_call = driver.find('bash "$APP_BUILD" --authorize-app-build --output-dir "$APP_BUNDLE"')
precreate = driver.find('mkdir -p "$APP_BUNDLE"')
check(
    "T2-005",
    app_call >= 0 and precreate < 0,
    "delegated_app_output_not_precreated",
)

trap_pos = driver.find("trap cleanup_source EXIT")
stage_pos = driver.find('mkdir -p "$C3B_STAGE/prebuilt" "$C1_STAGE"')
check(
    "T2-006",
    trap_pos >= 0 and stage_pos >= 0 and trap_pos < stage_pos,
    "cleanup_trap_precedes_android_workspace_staging",
)

context_rows = [
    line.strip()
    for line in property_contexts.splitlines()
    if line.strip() and not line.lstrip().startswith("#")
]
property_types: list[str] = []
for line in context_rows:
    match = re.search(r":([A-Za-z0-9_]+):s0$", line.split()[-1])
    if match:
        property_types.append(match.group(1))
check(
    "T2-007",
    len(context_rows) == 9
    and len(property_types) == 9
    and len(set(property_types)) == 5
    and "unique_types = sorted(set(types))" in driver
    and "len(types) != len(set(types))" not in driver,
    "property_contexts_9_to_5_mapping_preserved",
)

check(
    "T2-008",
    "cc_prebuilt_library_shared {" not in bp
    and not (ROOT / "product/titan2/n1i-c1/native-paths.txt").exists()
    and "N1I_C_B2_NATIVE_IMPORT_AUTHORITY=NO_CANDIDATE_COVERAGE_ONLY" in admission
    and "N1I_C1_INITIAL_STOCK_NATIVE_IMPORT_COUNT=0" in admission
    and "N1I_C1_STOCK_NATIVE_PREBUILT_COUNT=0" in contract,
    "zero_initial_stock_native_import",
)

check(
    "T2-009",
    "get_build_var TARGET_COPY_OUT_SYSTEM_EXT" in driver
    and 'COPYOUT="$(cat "$EVIDENCE/system-ext-copyout.txt")"' in driver
    and '[[ "$COPYOUT" == system/system_ext ]]' in driver
    and 'printf \'%s/%s/%s\\n\' "$PRODUCT_OUT" "$COPYOUT"' in driver,
    "target_copy_out_system_ext_drives_verification",
)

check(
    "T2-010",
    "REGISTRATION_DATA_DELTA=NONE_PRESERVE_C3A_N1F" in driver
    and "N1I_C1_REGISTRATION_DATA_PATCH_DELTA=0" in driver
    and "NEW_FUNCTIONAL_DELTA=OEM_MTK_IMS_COMPATIBILITY_ISLAND_ONLY" in driver,
    "cellular_experiment_remains_single_delta",
)

check(
    "T2-011",
    'bash "$ROOT/build/host/verify-host-tools.sh" aosp-host' in driver
    and '"$SABLE_SIMG2IMG"' in driver
    and "command -v simg2img" not in driver
    and "which simg2img" not in driver,
    "canonical_aosp_host_tools_verified",
)

a4_rows = [
    line.strip()
    for line in a4_ref.splitlines()
    if line.strip() and not line.lstrip().startswith("#")
]
check(
    "T2-012",
    len(a4_rows) == 33
    and len(set(a4_rows)) == 33
    and "REFERENCE ONLY" in a4_ref
    and "a4-native-superset.txt" in contract
    and "native-paths.txt" not in driver
    and '--a4-reference "$C1_TEMPLATE/a4-native-superset.txt"' in c2_driver
    and "IMPORT_FROZEN_STOCK" in c2_native_planner
    and "REUSE_C1_IDENTICAL" in c2_native_planner,
    "a4_native_superset_reference_only_and_runtime_collision_filtered",
)

fragile_aapt_pipelines = (
    '"$AAPT2" dump badging "$IMS_OUT" | grep',
    '"$AAPT2" dump xmltree "$IMS_OUT" --file AndroidManifest.xml | grep',
    '"$SABLE_ANDROID_BUILD_TOOLS/aapt2" dump badging "$IMS_OUT" | grep',
    '"$SABLE_ANDROID_BUILD_TOOLS/aapt2" dump xmltree --file AndroidManifest.xml "$IMS_OUT" | grep',
)
check(
    "T2-013",
    "apk_package_name()" in driver
    and "apk_shared_uid()" in driver
    and "N1I_C1_STAGED_IMS_IDENTITY=PASS" in driver
    and "N1I_C1_BUILT_IMS_IDENTITY=PASS" in driver
    and 'out="$("$SABLE_ANDROID_BUILD_TOOLS/aapt2" dump badging "$apk")"' in driver
    and 'out="$("$SABLE_ANDROID_BUILD_TOOLS/aapt2" dump xmltree --file AndroidManifest.xml "$apk")"' in driver
    and all(token not in driver for token in fragile_aapt_pipelines),
    "aapt2_output_captured_before_identity_matching",
)

check(
    "T2-014",
    "set -euo pipefail" not in driver
    and "set -o pipefail" not in driver
    and "set -e" not in driver
    and "set +e" not in driver
    and "make systemimage -j\"$JOBS\" > >(tee \"$EVIDENCE/systemimage.log\") 2>&1" in driver
    and 'build_rc=$?' in driver
    and '[[ "$build_rc" -eq 0 ]] || fail "systemimage_rc=$build_rc"' in driver,
    "explicit_return_code_handling_without_errexit_or_pipefail",
)

check(
    "T2-015",
    'tmux set-window-option -t "$SESSION" remain-on-exit on' in driver
    and "SESSION_RETENTION=remain-on-exit" in driver
    and "exec bash" not in driver,
    "tmux_session_retained_after_driver_exit",
)

postbuild_forbidden = (
    "set -e",
    "pipefail",
    "make systemimage",
    "m systemimage",
    "ninja",
    "adb ",
    "fastboot ",
    "SABLE_ADB",
    "SABLE_FASTBOOT",
)
check(
    "T2-016",
    "--source-commit" in postbuild_qualifier
    and "--out-dir" in postbuild_qualifier
    and "out_dir_source_binding" in postbuild_qualifier
    and "BUILD_AUTHORIZED=NO" in postbuild_qualifier
    and "DEVICE_CONTACT_AUTHORIZED=NO" in postbuild_qualifier
    and "FLASH_AUTHORIZED=NO" in postbuild_qualifier
    and "N1I_C1_POSTBUILD_QUALIFICATION=PASS" in postbuild_qualifier
    and "N1I_C1_READY_FOR_PHYSICAL_REVIEW=YES" in postbuild_qualifier
    and all(token not in postbuild_qualifier for token in postbuild_forbidden),
    "postbuild_qualifier_readonly_and_source_bound",
)

check(
    "T2-017",
    "PRODUCT_CONFIGURED_JAR_LOCATION_OVERRIDES" in mk
    and "system_ext:SableN1IC1MediatekCommon:system_ext:mediatek-common" in mk
    and "system_ext:SableN1IC1MediatekImsBase:system_ext:mediatek-ims-base" in mk
    and "get_build_var PRODUCT_CONFIGURED_JAR_LOCATION_OVERRIDES" in driver
    and "N1I_C1_BOOTJAR_LOCATION_OVERRIDES=PASS" in driver
    and "/system_ext/framework/SableN1IC1MediatekCommon.jar" not in driver
    and "/system_ext/framework/SableN1IC1MediatekImsBase.jar" not in driver,
    "configured_jar_locations_match_installed_stems",
)


check(
    "T2-018",
    'python3 "$ROOT/build/gates/build-regression-contract.py"' in c2_driver
    and c2_driver.find('python3 "$ROOT/build/gates/build-regression-contract.py"')
        < c2_driver.find('mkdir -p "$C3B_STAGE/prebuilt" "$C1_STAGE" "$C2_STAGE/prebuilt"'),
    "c2_release_driver_runs_shared_regression_before_staging",
)

c2_prebuilt_targets = set(
    re.findall(
        r'srcs:\s*\["prebuilt(/(?:system|system_ext|product)/[^"]+\.so)"\]',
        c2_bp,
    )
)
c2_direct_native_packages = set(
    re.findall(r"\bSableN1IC2NativeM\d{3}\b", c2_mk)
)
check(
    "T2-019",
    "N1I_C2_INSTALL_OWNERSHIP_AUDIT" in c2_collision_audit
    and len(c2_prebuilt_targets) == 33
    and c2_prebuilt_targets == set(a4_rows)
    and not c2_direct_native_packages
    and "native-packages.mk" in c2_mk
    and "plan-n1i-c2-native-install.py" in c2_driver
    and "native-baseline-probe.tsv" in c2_driver
    and "native-composition.tsv" in c2_driver
    and "install-collision-after-failure.log" in c2_driver
    and "REUSE_C1_IDENTICAL" in c2_native_planner
    and "IMPORT_FROZEN_STOCK" in c2_native_planner
    and "BLOCK_C1_DIFFERENT" in c2_native_planner
    and "BLOCK_GRAPH_OWNER_NOT_IN_C1" in c2_native_planner
    and "--collision-tsv" in c2_native_planner
    and "N1I_C2_NATIVE_PLAN_IDENTICAL_BASELINE_REUSE=PASS" in c2_native_plan_test
    and "N1I_C2_NATIVE_PLAN_GRAPH_COLLISION_FAIL_CLOSED=PASS" in c2_native_plan_test
    and "N1I_C2_NATIVE_PLAN_DIFFERENT_BASELINE_FAIL_CLOSED=PASS" in c2_native_plan_test
    and "--collision-tsv" in c2_driver,
    "c2_native_install_is_sealed_c1_collision_planned_not_wholesale_installed",
)

if failures:
    print("SABLE_BUILD_REGRESSION_CONTRACT=FAIL")
    for failure in failures:
        print(f"SABLE_BUILD_REGRESSION_FAILURE={failure}")
    raise SystemExit(1)

print(f"SABLE_BUILD_REGRESSION_COUNT={len(passes)}")
print("SABLE_BUILD_REGRESSION_CONTRACT=PASS")
