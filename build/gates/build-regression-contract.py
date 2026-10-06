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
    "T2-019", "T2-020", "T2-021", "T2-022", "T2-023", "T2-024",
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
entrypoint = read("build/sable.sh")
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
c2_native_preflight = read("build/titan2/run-n1i-c2-native-install-preflight.sh")
c2_native_baseline_probe = read("build/titan2/probe-n1i-c2-c1-native-baseline.sh")
c2_platform_provider = read("product/titan2/n1i-c2/platform-native-provider.tsv")
c2_postbuild_qualifier = read("build/titan2/qualify-n1i-c2-postbuild-linkage.sh")
c2_postbuild_contract = read("build/gates/n1i-c2-postbuild-linkage-contract.sh")
c1_runtime_linkage_driver = read("build/titan2/run-n1i-c1-runtime-linkage-audit.sh")
c1_apex_runtime_parity = read("build/titan2/audit-n1i-c1-apex-runtime-parity.py")
c1_runtime_classpath_deriver = read("build/titan2/derive-n1i-c1-runtime-classpath.py")
c2_agentpremain_classifier = read("build/titan2/classify-n1i-c2-agentpremain-gap.py")
d0_runner = read("build/titan2/run-n1i-d0-0h.sh")
d0_prep = read("build/titan2/prepare-n1i-d0-0h-inputs.sh")
d0_qual = read("build/titan2/qualify-n1i-d0-0h.py")
d0_contract = read("build/gates/n1i-d0-0h-contract.sh")
d0_apex = read("build/titan2/materialize-n1i-d0-apex.py")
d0_native_scan = read("build/titan2/scan-n1i-d0-native-loads.py")
c2_platform_provider_rows = [
    line.split("\t")
    for line in c2_platform_provider.splitlines()[1:]
    if line.strip()
]
c2_platform_provider_targets = {
    row[1]
    for row in c2_platform_provider_rows
    if len(row) >= 4
}
central_guard = read("build/gates/titan2-central-flash-guard-contract.sh")

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
    and '--a4-reference "$A4"' in c2_native_preflight
    and 'N1I_C2_C1_NATIVE_AUTHORITY=PASS_ZERO_PRESENT present=0 absent=33'
        in c2_native_preflight
    and "IMPORT_FROZEN_STOCK" in c2_native_planner
    and "USE_ANDROID_PLATFORM_PROVIDER" in c2_native_planner
    and "c1_native_present_not_allowed=" in c2_native_planner
    and 'row["disposition"].startswith("REUSE_C1_")'
        in c2_native_planner
    and "REUSE_C1_IDENTICAL" not in c2_native_planner
    and "REUSE_C1_PLATFORM_DIFFERENT" not in c2_native_planner,
    "a4_reference_only_with_zero_c1_reuse_and_collision_filtered_c2_admission",
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
    and len(c2_prebuilt_targets) == 28
    and len(c2_platform_provider_rows) == 5
    and len(c2_platform_provider_targets) == 5
    and c2_prebuilt_targets
        == set(a4_rows) - c2_platform_provider_targets
    and not c2_prebuilt_targets & c2_platform_provider_targets
    and c2_prebuilt_targets | c2_platform_provider_targets
        == set(a4_rows)
    and not c2_direct_native_packages
    and "native-packages.mk" in c2_mk
    and all(
        provider in c2_mk
        for provider in (
            "android.hardware.radio-V4-ndk",
            "android.hardware.graphics.common-V6-ndk",
            "android.hardware.drm-V1-ndk",
            "libheif",
            "libsuspend",
        )
    )
    and 'PLATFORM_PROVIDER_AUTHORITY="$C2_TEMPLATE/platform-native-provider.tsv"'
        in c2_driver
    and "missing Android platform provider package" in c2_driver
    and "USE_ANDROID_PLATFORM_PROVIDER" in c2_native_planner
    and "IMPORT_FROZEN_STOCK" in c2_native_planner
    and "EXPECTED_ANDROID_PLATFORM_PROVIDERS" in c2_native_planner
    and "c1_native_present_not_allowed=" in c2_native_planner
    and "platform_provider_admission_blocked=" in c2_native_planner
    and c2_platform_provider.count("\nM") == 5
    and "expected_android_owner" in c2_platform_provider
    and "M008\t/system/lib64/android.hardware.radio-V4-ndk.so\tandroid.hardware.radio-V4-ndk" in c2_platform_provider
    and "M017\t/system/lib64/android.hardware.graphics.common-V6-ndk.so\tandroid.hardware.graphics.common-V6-ndk" in c2_platform_provider
    and "M029\t/system/lib64/android.hardware.drm-V1-ndk.so\tandroid.hardware.drm-V1-ndk" in c2_platform_provider
    and "M038\t/system/lib64/libheif.so\tlibheif" in c2_platform_provider
    and "M039\t/system/lib64/libsuspend.so\tlibsuspend" in c2_platform_provider
    and "--collision-tsv" in c2_native_planner
    and "n1i-c1-cellular-isolation/20261005T133622Z-a745c7daa082-postbuild"
        in c2_native_preflight
    and "36b53950faebc954cadb30756833ae5ec857f054"
        in c2_native_preflight
    and "audit-n1i-c2-install-collisions.py" in c2_native_preflight
    and 'PRIOR_FAILED_INSTALLS="$PRIOR_FAILED_OUT/soong/installs-treble_arm64_bvN.mk"' in c2_native_preflight
    and '--installs-file "$PRIOR_FAILED_INSTALLS"' in c2_native_preflight
    and "plan-n1i-c2-native-install.py" in c2_native_preflight
    and "--platform-provider-decisions" in c2_native_preflight
    and 'N1I_C2_C1_NATIVE_AUTHORITY=PASS_ZERO_PRESENT present=0 absent=33'
        in c2_native_preflight
    and "NATIVE_BASELINE_PROBE.tsv" in c2_native_preflight
    and "NATIVE_COMPOSITION.tsv" in c2_native_preflight
    and "EXPECTED_C1_SHA=\"137bc8771c817c0afb3122d9f03e7a94575e03bcccc643b56235edd1075f2160\"" in c2_native_baseline_probe
    and "N1I_C2_C1_NATIVE_BASELINE_PROBE=PASS" in c2_native_baseline_probe
    and "NATIVE_BASELINE_PROBE.tsv" in c2_native_baseline_probe
    and "android.hardware.drm-V1-ndk.so" in c2_native_preflight
    and "N1I_C2_NATIVE_INSTALL_PREFLIGHT=PASS" in c2_native_preflight
    and "android.hardware.drm-V1-ndk.so" in c2_native_plan_test
    and "N1I_C2_NATIVE_INSTALL_PLAN_KNOWN_KATI_COLLISION_ANDROID_PLATFORM_PROVIDER=PASS"
        in c2_native_plan_test
    and "N1I_C2_NATIVE_INSTALL_PLAN_PLATFORM_PROVIDER_SET=PASS"
        in c2_native_plan_test,
    "c2_native_install_is_collision_qualified_with_zero_c1_reuse_and_finite_android_provider_set",
)

check(
    "T2-020",
    c2_driver.count("#!/usr/bin/env bash") == 1
    and c2_driver.count("selfcheck() {") == 1
    and c2_driver.count('echo "===== APPLY EXACT C2 SOURCE DELTA ====="') == 1
    and c2_driver.count(
        'echo "===== BUILD ONE ANDROID 16 CELLULAR MVP SYSTEMIMAGE ====="'
    ) == 1
    and c2_driver.count('make systemimage -j"$JOBS"') == 1,
    "c2_build_driver_singleton_structure",
)

central_guard_lines = central_guard.splitlines()
check(
    "T2-021",
    central_guard_lines.count("#!/usr/bin/env bash") == 1
    and central_guard_lines.count(
        'say "===== TITAN2 CENTRAL FLASH GUARD CONTRACT ====="'
    ) == 1
    and central_guard_lines.count(
        '  say "TITAN2_CENTRAL_FLASH_GUARD_CONTRACT=PASS"'
    ) == 1
    and 'TITAN2_CENTRAL_GUARD_SINGLETON_STRUCTURE' in central_guard,
    "titan2_central_guard_singleton_structure",
)

check(
    "T2-022",
    'sable_device_build "$RELEASE" "$MODE"' in entrypoint
    and 'TITAN2_N1I_BUILD_LANE=C2_CELLULAR_MVP' in adapter
    and 'bash "$ROOT/build/titan2/run-n1i-c2-cellular-mvp.sh" "$mode"' in adapter
    and '--authorize-source-mutation --authorize-build' in adapter
    and 'bash "$ROOT/build/titan2/run-n1i-c1-cellular-isolation.sh" N1I "$mode"'
        not in adapter,
    "canonical_sable_n1i_build_routes_to_c2_only",
)

check(
    "T2-023",
    "BUILD_AUTHORIZED=NO" in c2_postbuild_qualifier
    and "SOURCE_MUTATION_AUTHORIZED=NO" in c2_postbuild_qualifier
    and "NETWORK_FETCH_AUTHORIZED=NO" in c2_postbuild_qualifier
    and "DEVICE_CONTACT_AUTHORIZED=NO" in c2_postbuild_qualifier
    and "REBOOT_AUTHORIZED=NO" in c2_postbuild_qualifier
    and "FLASH_AUTHORIZED=NO" in c2_postbuild_qualifier
    and 'EXPECTED_OUT_BASENAME="out-n1i-c2-${SOURCE_COMMIT:0:12}"'
        in c2_postbuild_qualifier
    and "N1I_C2_POSTBUILD_RECEIPT=PASS rows=41" in c2_postbuild_qualifier
    and "count=33 frozen_stock=28 android_platform=5" in c2_postbuild_qualifier
    and '--expected-system-sha "$EXPECTED_SYSTEM_SHA"' in c2_postbuild_qualifier
    and '--expected-system-bytes "$EXPECTED_SYSTEM_BYTES"' in c2_postbuild_qualifier
    and "N1I_C2_POSTBUILD_LINKAGE_QUALIFICATION=PASS" in c2_postbuild_qualifier
    and "N1I_C2_READY_FOR_MERGE_REVIEW=YES" in c2_postbuild_qualifier
    and "PASS_FULL_CLASSIFICATION_AGENTPREMAIN_8" in c2_postbuild_qualifier
    and "AGENTPREMAIN_BROAD_RUNTIME_FAILURE_SUPPRESSION=NO"
        in c2_postbuild_qualifier
    and "EXPECTED_AGENT_FAILURES = 8" in c2_agentpremain_classifier
    and "PASS_EXACT_DORMANT_NON_ANDROID_DEBUG_AGENT"
        in c2_agentpremain_classifier
    and "N1I_C2_AGENTPREMAIN_BROAD_RUNTIME_FAILURE_SUPPRESSION=NO"
        in c2_agentpremain_classifier
    and '"N1I_C1_LINKAGE_COMMON_UNRESOLVED": "0"'
        in c2_agentpremain_classifier
    and '"N1I_C1_LINKAGE_IMS_BASE_UNRESOLVED": "0"'
        in c2_agentpremain_classifier
    and '"N1I_C1_LINKAGE_IMS_APK_CLASS_MISSING":'
        in c2_agentpremain_classifier
    and "sha256(system_img)" not in c2_agentpremain_classifier
    and "N1I_C2_POSTBUILD_LINKAGE_CONTRACT=PASS" in c2_postbuild_contract
    and '--expected-system-sha)' in c1_runtime_linkage_driver
    and '--expected-system-bytes)' in c1_runtime_linkage_driver
    and 'EXPECTED_C1_SHA="137bc8771c817c0afb3122d9f03e7a94575e03bcccc643b56235edd1075f2160"'
        in c1_runtime_linkage_driver
    and 'EXPECTED_C1_BYTES="3210661888"' in c1_runtime_linkage_driver
    and '"--expected-system-sha"' in c1_apex_runtime_parity
    and "default=EXPECTED_C1_SHA" in c1_apex_runtime_parity
    and '"--expected-system-sha"' in c1_runtime_classpath_deriver
    and "default=EXPECTED_C1_SHA" in c1_runtime_classpath_deriver
    and '--expected-system-sha "$EXPECTED_C1_SHA"'
        in c1_runtime_linkage_driver,
    "c2_postbuild_linkage_is_readonly_source_bound_with_exact_agentpremain_full_classification",
)

check(
    "T2-024",
    "BUILD_AUTHORIZED=NO" in d0_runner
    and "NETWORK_FETCH_AUTHORIZED=NO" in d0_runner
    and "DEVICE_CONTACT_AUTHORIZED=NO" in d0_runner
    and "MODE_TRANSITION_AUTHORIZED=NO" in d0_runner
    and "REBOOT_AUTHORIZED=NO" in d0_runner
    and "FLASH_AUTHORIZED=NO" in d0_runner
    and "N1F_APEX_ROOT=" in d0_prep
    and "C2_APEX_ROOT=" in d0_prep
    and "STOCK_APEX_ROOT=" in d0_prep
    and "init_sepolicy_version(" in d0_qual
    and '"-m", "-M", "true", "-G", "-N"' in d0_qual
    and "effective_policy_unavailable gate_a=" in d0_qual
    and "system_ext_privapp_missing=" in d0_qual
    and "SEAPP_RESULT=" in d0_qual
    and "updatable-bcp-packages.txt" in d0_qual
    and "audit-n1i-c1-runtime-linkage.py" in d0_qual
    and "boot_caller_not_proven" in d0_qual
    and "scan-n1i-d0-native-loads.py" in d0_qual
    and "UNKNOWN_NOT_IMPLEMENTED" in d0_qual
    and "A4_RETIREMENT.tsv" in d0_qual
    and "N1I_D0_C1J_COMPOSITION_READY=" in d0_qual
    and "c3a_apex_root" not in d0_qual
    and "work/apex/c3a" not in d0_qual
    and "N1I_D0_APEX_MATERIALIZE=PASS" in d0_apex
    and "N1I_D0_NATIVE_LOAD_SCAN=PASS" in d0_native_scan
    and "N1I_D0_0H_CONTRACT=PASS" in d0_contract,
    "d0_host_closure_is_control_calibrated_pinned_and_fail_closed",
)

if failures:
    print("SABLE_BUILD_REGRESSION_CONTRACT=FAIL")
    for failure in failures:
        print(f"SABLE_BUILD_REGRESSION_FAILURE={failure}")
    raise SystemExit(1)

print(f"SABLE_BUILD_REGRESSION_COUNT={len(passes)}")
print("SABLE_BUILD_REGRESSION_CONTRACT=PASS")
