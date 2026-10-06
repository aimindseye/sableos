#!/usr/bin/env python3
from __future__ import annotations

import csv
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]

LEDGER = ROOT / "build" / "TITAN2_FLASH_REGRESSIONS.tsv"
ADAPTER = ROOT / "build" / "devices" / "titan2.sh"
ELITE = ROOT / "build" / "devices" / "titan2-elite.sh"
DEPLOY = ROOT / "build" / "deploy" / "flash.sh"
CENTRAL = ROOT / "build" / "gates" / "titan2-central-flash-guard-contract.sh"
PLAN = ROOT / "build" / "titan2" / "prepare-n0-n1-flash-plan.sh"
FLASH_LEDGER = ROOT / "docs" / "titan2" / "N0_N1_FLASH_PLAN_LEDGER.md"
SOURCE_MAP = ROOT / "docs" / "titan2" / "TITAN2_DELIVERABLE_SOURCE_MAP.md"
POLICY = ROOT / "docs" / "titan2" / "TITAN2_FLASH_REGRESSION_POLICY.md"
MODE_HELPER = ROOT / "build" / "titan2" / "titan2-flash-mode.sh"
MODE_SELFTEST = ROOT / "build" / "titan2" / "tests" / "test-titan2-flash-mode.sh"
C2_RECOVERY_QUALIFIER = ROOT / "build" / "titan2" / "qualify-n1i-c2-recovery-entry.sh"
C2_RECOVERY_CONTRACT = ROOT / "build" / "gates" / "n1i-c2-recovery-entry-contract.sh"
C2_FLASH = ROOT / "build" / "titan2" / "flash-n1i-c2-cellular-mvp.sh"
C2_FASTBOOT_QUAL = ROOT / "build" / "titan2" / "qualify-n1i-c2-fastboot-state.py"
C2_FLASH_TEST = ROOT / "tests" / "titan2" / "n1i-c2" / "test-flash-executor.sh"
C2_FLASH_CONTRACT = ROOT / "build" / "gates" / "n1i-c2-flash-executor-contract.sh"
D0_IMG0_FLASH = ROOT / "build" / "titan2" / "flash-n1i-d0-img0.sh"
D0_IMG0_FASTBOOT_QUAL = ROOT / "build" / "titan2" / "qualify-n1i-d0-img0-fastboot-state.py"
D0_IMG0_FLASH_TEST = ROOT / "tests" / "titan2" / "n1i-d0-img0" / "test-flash-executor.sh"
D0_IMG0_FLASH_CONTRACT = ROOT / "build" / "gates" / "n1i-d0-img0-flash-executor-contract.sh"
E5B_EXECUTION = ROOT / "build" / "gates" / "n1d-c3b-e5b-standard-execution-contract.sh"
E6_DEPLOYMENT = ROOT / "build" / "gates" / "n1d-c3b-e6-standard-deployment-contract.sh"
N1F_DOC = ROOT / "docs" / "titan2" / "N1F_C3A_DERIVED_C3B5_BUILD_FLASH.md"
CURRENT = ROOT / "CURRENT_STATUS.md"

REQUIRED_IDS = {
    f"TF-{i:03d}" for i in range(1, 27)
}

failures: list[str] = []


def read(path: pathlib.Path) -> str:
    if not path.is_file():
        failures.append(f"missing_file:{path.relative_to(ROOT)}")
        return ""
    return path.read_text(encoding="utf-8", errors="replace")


def check(regression_id: str, condition: bool, detail: str) -> None:
    if condition:
        print(f"SABLE_TITAN2_FLASH_REGRESSION_{regression_id}=PASS {detail}")
    else:
        print(f"SABLE_TITAN2_FLASH_REGRESSION_{regression_id}=FAIL {detail}")
        failures.append(f"{regression_id}:{detail}")


adapter = read(ADAPTER)
elite = read(ELITE)
deploy = read(DEPLOY)
central = read(CENTRAL)
plan = read(PLAN)
flash_ledger = read(FLASH_LEDGER)
source_map = read(SOURCE_MAP)
policy = read(POLICY)
mode_helper = read(MODE_HELPER)
mode_selftest = read(MODE_SELFTEST)
c2_recovery_qualifier = read(C2_RECOVERY_QUALIFIER)
c2_recovery_contract = read(C2_RECOVERY_CONTRACT)
c2_flash = read(C2_FLASH)
c2_fastboot_qual = read(C2_FASTBOOT_QUAL)
c2_flash_test = read(C2_FLASH_TEST)
c2_flash_contract = read(C2_FLASH_CONTRACT)
d0_img0_flash = read(D0_IMG0_FLASH)
d0_img0_fastboot_qual = read(D0_IMG0_FASTBOOT_QUAL)
d0_img0_flash_test = read(D0_IMG0_FLASH_TEST)
d0_img0_flash_contract = read(D0_IMG0_FLASH_CONTRACT)
c2_postbuild_qualifier = read(ROOT / "build/titan2/qualify-n1i-c2-postbuild-linkage.sh")
n1f_doc = read(N1F_DOC)
current = read(CURRENT)

rows: list[dict[str, str]] = []
if LEDGER.is_file():
    with LEDGER.open(encoding="utf-8", newline="") as fp:
        reader = csv.DictReader(fp, delimiter="\t")
        expected_columns = {
            "regression_id", "scope", "status", "invariant", "owner", "evidence"
        }
        if reader.fieldnames is None or set(reader.fieldnames) != expected_columns:
            failures.append("ledger_columns")
        else:
            rows = list(reader)
else:
    failures.append("ledger_missing")

ids = [row.get("regression_id", "") for row in rows]
if set(ids) != REQUIRED_IDS or len(ids) != len(REQUIRED_IDS):
    failures.append(
        "ledger_id_set:"
        + ",".join(sorted(set(ids) ^ REQUIRED_IDS))
    )
if len(ids) != len(set(ids)):
    failures.append("ledger_duplicate_ids")
for row in rows:
    if row.get("scope") != "TITAN2":
        failures.append(f"ledger_scope:{row.get('regression_id')}")
    if row.get("status") != "ACTIVE":
        failures.append(f"ledger_status:{row.get('regression_id')}")
    for key in ("invariant", "owner", "evidence"):
        if not row.get(key, "").strip():
            failures.append(f"ledger_blank:{row.get('regression_id')}:{key}")

check(
    "TF-001",
    "PIXEL_FASTBOOT_ASSUMPTIONS_ALLOWED=NO" in flash_ledger
    and "PANTHER_ARTIFACT_FLASH_TO_TITAN2_ALLOWED=NO" in flash_ledger
    and "SABLE_DEVICE_FLASH_TRANSPORT=titan2-fastbootd-ledger-only" in adapter,
    "titan_specific_not_pixel",
)

check(
    "TF-002",
    "TITAN2_FASTBOOT_BOOT_SUPPORTED=NO" in adapter
    and "FASTBOOT_BOOT_SUPPORTED=NO" in source_map
    and not re.search(r'FASTBOOT_BIN[^\n]*\bboot\b', adapter),
    "fastboot_boot_forbidden",
)

check(
    "TF-003",
    "SABLE_DEVICE_FLASH_ENTRY_MODE=fastbootd" in adapter
    and '"is-userspace": "yes"' in adapter
    and "TITAN2_N1D_POSTFLASH_FASTBOOTD=PASS" in adapter,
    "userspace_fastbootd_required",
)

check(
    "TF-004",
    'sable_require_fastboot_serial_exact_once "$FASTBOOT_BIN" "$SERIAL"' in adapter
    and '"$FASTBOOT_BIN" -s "$SERIAL"' in adapter
    and "--serial <adb/transport-serial>" in deploy,
    "explicit_serial_binding",
)

check(
    "TF-005",
    '"unlocked": "yes"' in adapter
    and '"product": expected_product' in adapter
    and '"is-userspace": "yes"' in adapter
    and "HOST_OKAY_IS_NOT_DEVICE_STATE_PROOF=YES" in policy,
    "live_state_revalidated",
)

check(
    "TF-006",
    "TITAN2_VIRTUAL_AB=YES" in adapter
    and '"current-slot": expected_slot' in adapter
    and "system_b_bytes != 0" in adapter
    and "TARGET_PARTITION=system_a" in policy
    and "SYSTEM_B_MAY_BE_NOT_MATERIALIZED_WHILE_SLOT_A_ACTIVE=YES" in policy,
    "virtual_ab_active_materialized_target",
)

check(
    "TF-007",
    '"is-logical:system_a": "yes"' in adapter
    and "partition-size:system_a" in adapter
    and "TARGET_PARTITION=system_a" in policy,
    "slot_qualified_logical_target",
)

check(
    "TF-008",
    '"snapshot-update-status": "none"' in adapter
    and "TITAN2_N1D_POSTFLASH_SNAPSHOT=PASS_NONE" in adapter,
    "snapshot_none_pre_and_post",
)

check(
    "TF-009",
    "COW_DELETION_ALLOWED=NO" in adapter
    and "FLASH_COW_DELETION=NO" in adapter
    and "COW logical partitions may exist" in policy,
    "cow_not_blindly_deleted",
)

check(
    "TF-010",
    '[[ "$PRIMARY_SHA" == "$TITAN2_N1D_ACTIVE_SYSTEM_SHA256" ]]' in adapter
    and "SYSTEM_SHA256=$TITAN2_N1D_ACTIVE_SYSTEM_SHA256" in adapter
    and "SYSTEM_LOGICAL_BYTES=$TITAN2_N1D_ACTIVE_SYSTEM_LOGICAL_BYTES" in adapter
    and "GSI_IMAGE_LOGICAL_BYTES=$TITAN2_N1D_ACTIVE_SYSTEM_LOGICAL_BYTES" in adapter,
    "artifact_hash_and_logical_size_bound",
)

check(
    "TF-011",
    "RESTORE_REPORT=REQUIRED" in flash_ledger
    and "RESTORE_PATH_VERIFIED=REQUIRED" in flash_ledger
    and "VERIFIED_MATCHED_STOCK_RESTORE_SET_REQUIRED=YES" in policy
    and "NO_WRITE_CAPABLE_SCRIPT_WITHOUT_VERIFIED_RESTORE_PATH=YES" in policy,
    "verified_restore_path_required",
)

check(
    "TF-012",
    "STOCK_SYSTEM_A_ONLY_RESTORE_ALLOWED=NO" in policy
    and "STOCK_SYSTEM_A_ONLY_FLASH_ALLOWED=NO" in current,
    "stock_system_only_restore_forbidden",
)

flash_super_patterns = (
    r'\bflash\s+super\b',
    r'\bflash\s+super_[ab]\b',
)
check(
    "TF-013",
    "WHOLE_SUPER_FLASH_ALLOWED=NO" in adapter
    and "WHOLE_SUPER_PRIMARY_SABLE_PATH=NO" in policy
    and all(re.search(pattern, adapter) is None for pattern in flash_super_patterns),
    "whole_super_not_primary",
)

forbidden_targets = (
    "boot", "init_boot", "vendor_boot", "dtbo",
    "vbmeta", "vbmeta_system", "vbmeta_vendor",
    "vendor", "vendor_dlkm", "odm_dlkm",
)
forbidden_flash_found = []
for target in forbidden_targets:
    if re.search(rf'FASTBOOT_BIN[^\n]*\bflash\s+{re.escape(target)}(?:_[ab])?\b', adapter):
        forbidden_flash_found.append(target)
check(
    "TF-014",
    not forbidden_flash_found
    and "FLASH_AVB_MUTATION=NO" in adapter
    and "FLASH_BOOT_CHAIN_MUTATION=NO" in adapter
    and "FLASH_SLOT_CHANGE=NO" in adapter,
    "boot_avb_slot_mutation_forbidden",
)

check(
    "TF-015",
    "USERDATA_WIPE_IMPLICIT_ALLOWED=NO" in flash_ledger
    and "USERDATA_WIPE_REQUIRES_EXPLICIT_APPROVAL=YES" in flash_ledger
    and "FLASH_FACTORY_RESET=NO" in adapter
    and "USERDATA_OR_METADATA_WIPE_AUTHORIZED=NO" in deploy,
    "userdata_reset_separate_authorization",
)

flash_calls = re.findall(
    r'"\$FASTBOOT_BIN"\s+-s\s+"\$SERIAL"\s+flash\s+system_a\s+"\$PRIMARY_PATH"',
    adapter,
)
check(
    "TF-016",
    len(flash_calls) == 1
    and "TITAN2_N1D_FLASH=FAIL_NO_AUTOMATIC_RETRY" in adapter
    and "NO_AUTOMATIC_FLASH_RETRY=YES" in policy,
    f"single_flash_call_no_retry count={len(flash_calls)}",
)

check(
    "TF-017",
    "TITAN2_N1D_POSTFLASH_SYSTEM_A_BYTES=PASS" in adapter
    and "TITAN2_N1D_POSTFLASH_SLOT=PASS" in adapter
    and "TITAN2_N1D_POSTFLASH_FASTBOOTD=PASS" in adapter
    and "TITAN2_N1D_POSTFLASH_SNAPSHOT=PASS_NONE" in adapter,
    "postwrite_state_verified",
)

reboot_calls = re.findall(
    r'"\$FASTBOOT_BIN"\s+-s\s+"\$SERIAL"\s+reboot\b',
    adapter,
)
check(
    "TF-018",
    len(reboot_calls) == 1
    and "TITAN2_N1D_FINAL_REBOOT=PASS_SENT_ONCE" in adapter
    and "TITAN2_N1D_FIRST_BOOT_OBSERVATION=FASTBOOT_RETURNED" in adapter
    and "TITAN2_N1D_FIRST_BOOT_OBSERVATION=RECOVERY" in adapter
    and "TITAN2_N1D_FIRST_BOOT_OBSERVATION=TIMEOUT_NO_TERMINAL_STATE" in adapter
    and "TITAN2_N1D_FURTHER_MUTATION=BLOCKED_OWNER_REVIEW_REQUIRED" in adapter,
    f"one_reboot_then_observe count={len(reboot_calls)}",
)

check(
    "TF-019",
    "NO_SET_EUO_PIPEFAIL_IN_DEVICE_OR_RECOVERY_SCRIPTS=YES" in policy
    and "NO_STDOUT_LOGGING_FROM_FUNCTIONS_USED_IN_COMMAND_SUBSTITUTION=YES" in policy
    and "NO_HARDCODED_HOST_TOOL_WITHOUT_RESOLVER_FALLBACK=YES" in policy
    and "set -euo pipefail" not in adapter
    and "set -o pipefail" not in adapter
    and "set +e" not in adapter
    and re.search(r"^[ \t]*set -e([ \t]|$)", adapter, re.MULTILINE) is None
    and "PIPESTATUS" not in adapter
    and '> >(tee "$EVIDENCE_DIR/fastboot-flash-system-a.log") 2>&1' in adapter,
    "titan_helper_quality_lessons_preserved",
)

check(
    "TF-020",
    "SABLE_DEVICE_FLASH_SUPPORTED=NO" in elite
    and "SABLE_DEVICE_ARTIFACT_REGISTRATION_SUPPORTED=NO" in elite
    and "SABLE_DEVICE_FLASH_PLAN_SUPPORTED=NO" in elite
    and "TITAN2_ELITE_INHERITS_TITAN2_FLASH_PASS=NO" in policy,
    "titan2_elite_independent",
)

check(
    "TF-021",
    "UNIHERTZ_TITAN2_RESEARCH_REVIEWED_MAIN=7e21667bc37b3fc80ef39d0b9e1c9a71a28cbec5" in policy
    and "TITAN2_TEMP_REVIEWED_MAIN=7570470d1c5a27ef94ed4751f5ccb91af41761fe" in policy
    and "PR142=" in policy
    and "PR143=" in policy
    and "PR183=" in policy
    and "PR262=" in policy
    and "PR264=" in policy
    and "PR309=" in policy
    and "N1F_C3A_DERIVED_C3B5_BUILD_FLASH.md" in policy
    and "SABLEOS_N1C_FIRST_WRITE_POSTMORTEM_20260930.md" in policy,
    "pinned_source_and_history_review",
)

mode_call = adapter.find("titan2_ensure_fastbootd_mode")
live_getvar = adapter.find('LIVE_GETVAR_ALL="$EVIDENCE_DIR/fastboot-getvar-all-prewrite.txt"')
check(
    "TF-022",
    "TITAN2_BOOTLOADER_FASTBOOT_PRODUCT=g71v78c2k_dfl_tee" in adapter
    and "TITAN2_FASTBOOTD_PRODUCT=Titan_2" in adapter
    and "TITAN2_FLASH_MODE_HELPER=" in adapter
    and mode_call >= 0
    and live_getvar >= 0
    and mode_call < live_getvar
    and "ANDROID_ADB_TO_BOOTLOADER_FASTBOOT" in mode_helper
    and "BOOTLOADER_FASTBOOT_TO_FASTBOOTD" in mode_helper
    and "NONE_ALREADY_FASTBOOTD" in mode_helper
    and "BLOCKED_RECOVERY_MANUAL_REVIEW_REQUIRED" in mode_helper
    and "device|recovery" in mode_helper
    and "TITAN2_MODE_ADB_TRANSPORT_STATE" in mode_helper
    and 'TITAN2_MODE_ADB_TRANSPORT_STATE" == recovery' in mode_helper
    and "TITAN2_MODE_ADB_PROPERTIES_READABLE=NO" in mode_helper
    and "reboot bootloader" in mode_helper
    and "reboot fastboot" in mode_helper
    and 'getvar "$key"' in mode_helper
    and "is-userspace" in mode_helper
    and "TITAN2_FLASH_FASTBOOTD_READY=PASS" in mode_helper,
    "mode_discovery_and_verified_transition",
)

syntax_paths = (
    DEPLOY,
    ADAPTER,
    MODE_HELPER,
    MODE_SELFTEST,
    CENTRAL,
    E5B_EXECUTION,
    E6_DEPLOYMENT,
    C2_RECOVERY_QUALIFIER,
    C2_RECOVERY_CONTRACT,
    C2_FLASH,
    C2_FLASH_TEST,
    C2_FLASH_CONTRACT,
    D0_IMG0_FLASH,
    D0_IMG0_FLASH_TEST,
    D0_IMG0_FLASH_CONTRACT,
)
syntax_ok = True
syntax_detail: list[str] = []
for syntax_path in syntax_paths:
    proc = subprocess.run(
        ["bash", "-n", str(syntax_path)],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode != 0:
        syntax_ok = False
        syntax_detail.append(
            f"{syntax_path.relative_to(ROOT)}:{proc.stderr.strip() or proc.returncode}"
        )

selftest_ok = False
selftest_detail = ""
if MODE_SELFTEST.is_file():
    try:
        proc = subprocess.run(
            ["bash", str(MODE_SELFTEST)],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
            timeout=15,
        )
        selftest_detail = proc.stdout.strip()
        selftest_ok = (
            proc.returncode == 0
            and "TITAN2_FLASH_MODE_SELFTEST_CASES=5" in proc.stdout
            and "TITAN2_FLASH_MODE_SELFTEST_FAILURES=0" in proc.stdout
            and "TITAN2_FLASH_MODE_SELFTEST=PASS" in proc.stdout
        )
    except subprocess.TimeoutExpired:
        selftest_detail = "timeout"

check(
    "TF-023",
    syntax_ok
    and selftest_ok
    and "set -euo pipefail" not in mode_helper
    and "set -o pipefail" not in mode_helper
    and 'TITAN2_MODE_COMMAND_TIMEOUT_SECONDS="${TITAN2_MODE_COMMAND_TIMEOUT_SECONDS:-8}"' in mode_helper
    and 'TITAN2_MODE_BOOTLOADER_WAIT_SECONDS="${TITAN2_MODE_BOOTLOADER_WAIT_SECONDS:-45}"' in mode_helper
    and 'TITAN2_MODE_FASTBOOTD_WAIT_SECONDS="${TITAN2_MODE_FASTBOOTD_WAIT_SECONDS:-60}"' in mode_helper
    and 'TITAN2_MODE_POLL_SECONDS="${TITAN2_MODE_POLL_SECONDS:-1}"' in mode_helper
    and "timeout" in mode_helper
    and 'sleep "$TITAN2_MODE_POLL_SECONDS"' in mode_helper
    and "PIPESTATUS" not in adapter
    and "set +e" not in adapter
    and re.search(r"^[ \t]*set -e([ \t]|$)", adapter, re.MULTILINE) is None
    and 'fastboot_devices="$(titan2_mode_capture 3 "$FASTBOOT_BIN" devices)"' in adapter
    and 'adb_devices="$(titan2_mode_capture 3 "$ADB_BIN" devices)"' in adapter,
    "syntax_and_bounded_mode_selftest "
    + ("syntax=PASS " if syntax_ok else "syntax=FAIL:" + "|".join(syntax_detail) + " ")
    + ("selftest=PASS" if selftest_ok else "selftest=FAIL:" + selftest_detail[-300:]),
)

c2_recovery_authority_pos = c2_recovery_qualifier.find(
    "===== VERIFY POSTBUILD AUTHORITY ====="
)
c2_recovery_bind_pos = c2_recovery_qualifier.find(
    "===== BIND SEALED TITAN RECOVERY IDENTITY ====="
)

check(
    "TF-024",
    "DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY_RECOVERY_STATE_ONLY"
        in c2_recovery_qualifier
    and "MODE_TRANSITION_AUTHORIZED=NO" in c2_recovery_qualifier
    and "REBOOT_AUTHORIZED=NO" in c2_recovery_qualifier
    and "FLASH_AUTHORIZED=NO" in c2_recovery_qualifier
    and "FACTORY_RESET_AUTHORIZED=NO" in c2_recovery_qualifier
    and "SLOT_CHANGE_AUTHORIZED=NO" in c2_recovery_qualifier
    and "LP_MUTATION_AUTHORIZED=NO" in c2_recovery_qualifier
    and "AVB_MUTATION_AUTHORIZED=NO" in c2_recovery_qualifier
    and '[[ "$TITAN2_MODE_DETECTED" == RECOVERY_ADB ]]'
        in c2_recovery_qualifier
    and '[[ "$TITAN2_MODE_ADB_TRANSPORT_STATE" == recovery ]]'
        in c2_recovery_qualifier
    and "N1I_C2_RECOVERY_ADB_PROPERTIES=NOT_REQUIRED_KNOWN_UNREADABLE"
        in c2_recovery_qualifier
    and 'titan2_mode_adb_getprop "$SABLE_ADB"' not in c2_recovery_qualifier
    and '[[ -z "$TITAN2_MODE_FASTBOOT_SERIAL" ]]'
        in c2_recovery_qualifier
    and "N1I_C2_RECOVERY_ENTRY_QUALIFICATION=PASS_RECOVERY_CONFIRMED_NO_TRANSITION"
        in c2_recovery_qualifier
    and "N1I_C2_READY_FOR_RECOVERY_TO_FASTBOOTD_REVIEW=YES"
        in c2_recovery_qualifier
    and "N1I_C2_READY_FOR_FLASH_WRITE=NO" in c2_recovery_qualifier
    and "--bind-sealed-recovery" in c2_recovery_qualifier
    and 'titan2_mode_find_bound_adb "$SABLE_ADB" "$EXPECTED_BINDING_SHA256"'
        in c2_recovery_qualifier
    and "BINDING_METHOD=SEALED_HASH_MATCH_READ_ONLY_DISCOVERY"
        in c2_recovery_qualifier
    and "serial_and_bound_recovery_are_mutually_exclusive"
        in c2_recovery_qualifier
    and '"BUILD_SOURCE_COMMIT=$BUILD_SOURCE"' in c2_recovery_qualifier
    and "BUILD_SOURCE_COMMIT=$SOURCE_COMMIT" in c2_postbuild_qualifier
    and c2_recovery_authority_pos >= 0
    and c2_recovery_bind_pos >= 0
    and c2_recovery_authority_pos < c2_recovery_bind_pos
    and "head -n 1" not in c2_recovery_qualifier
    and "set -euo pipefail" not in c2_recovery_qualifier
    and "set -o pipefail" not in c2_recovery_qualifier
    and "set +e" not in c2_recovery_qualifier
    and "N1I_C2_RECOVERY_ENTRY_READ_ONLY_ALLOWED=YES" in policy
    and "N1I_C2_RECOVERY_AUTOMATIC_REBOOT_ALLOWED=NO" in policy
    and "N1I_C2_RECOVERY_AUTOMATIC_FASTBOOTD_TRANSITION_ALLOWED=NO" in policy
    and "N1I_C2_RECOVERY_FLASH_WRITE_ALLOWED=NO" in policy
    and "N1I_C2_RECOVERY_ENTRY_CONTRACT=PASS" in c2_recovery_contract,
    "c2_recovery_entry_is_readonly_bound_and_stops_before_transition_or_write",
)

check(
    "TF-025",
    "TITAN2_N1I_C2_EXACT_WRITE_EXECUTOR_ALLOWED=YES_REVIEWED_SCOPE_ONLY"
        in adapter
    and "TITAN2_FLASH_EXECUTION_SUPPORTED=NO" in adapter
    and "TITAN2_WRITE_CAPABLE_SCRIPT_ALLOWED=NO" in adapter
    and 'BUILD_SOURCE="27d671b004f5ae7394f147018fc4fffdf4d78498"'
        in c2_flash
    and 'SYSTEM_SHA256="630db78ef3f888b961640d17c5237495e673a953d67f1d52fabe056cbb76bb50"'
        in c2_flash
    and 'SYSTEM_BYTES="3218440192"' in c2_flash
    and 'TARGET_PARTITION="system_a"' in c2_flash
    and 'EXPECTED_SLOT="a"' in c2_flash
    and "YES_C2_MODE_AWARE_FASTBOOTD_AND_FLASH_SYSTEM_A_ONCE" in c2_flash
    and "YES_C2_SYSTEM_A_ONCE" in c2_flash
    and 'EXPECTED_ADB_BINDING_SHA256="bcfdee61b23e3cb002919c27a055389ffe37e284bf5150dfc1d0bbbd7564090a"' in c2_flash
    and 'EXPECTED_FASTBOOT_BINDING_SHA256="bcfdee61b23e3cb002919c27a055389ffe37e284bf5150dfc1d0bbbd7564090a"' in c2_flash
    and "N1I_C2_FLASH_ENTRY_MODE=PASS_ANDROID_ADB" in c2_flash
    and "N1I_C2_FLASH_ENTRY_MODE=PASS_BOOTLOADER_FASTBOOT" in c2_flash
    and "N1I_C2_FLASH_ENTRY_MODE=PASS_FASTBOOTD_DIRECT" in c2_flash
    and "N1I_C2_FLASH_MODE_TRANSITION=NONE_ALREADY_FASTBOOTD" in c2_flash
    and "recovery_entry_blocked_for_write" in c2_flash
    and "titan2_ensure_fastbootd_mode" in c2_flash
    and c2_flash.count(
        '"$SABLE_FASTBOOT" -s "$SERIAL" flash system_a "$SYSTEM_IMG"'
    ) == 1
    and c2_flash.count('sha256sum "$SYSTEM_IMG"') == 1
    and c2_flash.count(
        '"$SABLE_FASTBOOT" -s "$SERIAL" reboot </dev/null'
    ) == 1
    and "AUTOMATIC_FLASH_RETRY=NO" in c2_flash
    and "N1I_C2_FLASH_DUPLICATE_WRITE_GUARD=REFUSE_PRIOR_ATTEMPT"
        in c2_flash
    and "N1I_C2_FLASH_DUPLICATE_WRITE_GUARD=REFUSE_CORRUPT_PRIOR_EVIDENCE"
        in c2_flash
    and "N1I_C2_DO_NOT_REFLASH_AFTER_THIS_POINT_WITHOUT_OWNER_REVIEW=YES"
        in c2_flash
    and "N1I_C2_DO_NOT_REFLASH_IF_POSTBOOT_OBSERVATION_FAILS=YES"
        in c2_flash
    and "FACTORY_RESET_AUTHORIZED=NO" in c2_flash
    and "USERDATA_ERASE_AUTHORIZED=NO" in c2_flash
    and "SLOT_CHANGE_AUTHORIZED=NO" in c2_flash
    and "AVB_MUTATION_AUTHORIZED=NO" in c2_flash
    and "BOOT_CHAIN_MUTATION_AUTHORIZED=NO" in c2_flash
    and "COW_DELETION_AUTHORIZED=NO" in c2_flash
    and "TARGET_BYTES = 3_218_440_192" in c2_fastboot_qual
    and "REVIEWED_GROUP_SAFE_SYSTEM_TARGET_CEILING_BYTES = 3_263_168_512"
        in c2_fastboot_qual
    and "MIN_REMAINING_SUPER_HEADROOM_BYTES = 536_870_912"
        in c2_fastboot_qual
    and 'baseline = "LIVE_CURRENT_SYSTEM_A"' in c2_fastboot_qual
    and "N1I_C2_FASTBOOT_STATE=FAIL_ACTIVE_COWS=" in c2_fastboot_qual
    and "N1I_C2_FASTBOOT_STATE=REFUSE_ALREADY_TARGET_SIZE"
        not in c2_fastboot_qual
    and "SAME_SIZE_NOT_TREATED_AS_CONTENT_IDENTITY" in c2_flash_test
    and "N1I_C2_FLASH_EXECUTOR_TEST=PASS" in c2_flash_test
    and "N1I_C2_FLASH_EXECUTOR_CONTRACT=PASS" in c2_flash_contract,
    "c2_exact_mode_aware_fastbootd_single_write_no_retry_with_live_geometry",
)

d0_img0_python_syntax_ok = True
try:
    compile(
        d0_img0_fastboot_qual,
        str(D0_IMG0_FASTBOOT_QUAL.relative_to(ROOT)),
        "exec",
    )
except SyntaxError:
    d0_img0_python_syntax_ok = False

check(
    "TF-026",
    "TITAN2_N1I_D0_IMG0_EXACT_WRITE_EXECUTOR_ALLOWED=YES_REVIEWED_SCOPE_ONLY"
        in adapter
    and "TITAN2_FLASH_EXECUTION_SUPPORTED=NO" in adapter
    and "TITAN2_WRITE_CAPABLE_SCRIPT_ALLOWED=NO" in adapter
    and "TITAN2_N1I_D0_IMG0_CELLULAR_DELTA=C1_C2_NOT_INCLUDED" in adapter
    and 'BUILD_SOURCE="defc7f9c522336732564eb11644331691dcd92a2"'
        in d0_img0_flash
    and 'SYSTEM_SHA256="c3cff8cc9f0be512a721fae4c0b3c148688ef95b04c1df3981afb406bc928bd0"'
        in d0_img0_flash
    and 'SYSTEM_BYTES="3200548864"' in d0_img0_flash
    and 'ARTIFACT_ROLE="N1I_D0_IMG0_BUILD_PATH_CLOSURE"' in d0_img0_flash
    and 'TARGET_PARTITION="system_a"' in d0_img0_flash
    and 'EXPECTED_SLOT="a"' in d0_img0_flash
    and "YES_D0_IMG0_MODE_AWARE_FASTBOOTD_AND_FLASH_SYSTEM_A_ONCE"
        in d0_img0_flash
    and "YES_D0_IMG0_SYSTEM_A_ONCE" in d0_img0_flash
    and 'CELLULAR_DELTA=C1_C2_NOT_INCLUDED' in d0_img0_flash
    and "N1I_D0_IMG0_FLASH_HOST_AUTHORITY=PASS" in d0_img0_flash
    and "N1I_D0_IMG0_FLASH_REGRESSION_PREFLIGHT=PASS" in d0_img0_flash
    and "N1I_D0_IMG0_FLASH_ENTRY_MODE=PASS_ANDROID_ADB" in d0_img0_flash
    and "N1I_D0_IMG0_FLASH_ENTRY_MODE=PASS_BOOTLOADER_FASTBOOT" in d0_img0_flash
    and "N1I_D0_IMG0_FLASH_ENTRY_MODE=PASS_FASTBOOTD_DIRECT" in d0_img0_flash
    and "N1I_D0_IMG0_FLASH_MODE_TRANSITION=NONE_ALREADY_FASTBOOTD"
        in d0_img0_flash
    and "recovery_entry_blocked_for_write" in d0_img0_flash
    and "titan2_ensure_fastbootd_mode" in d0_img0_flash
    and d0_img0_flash.count(
        '"$SABLE_FASTBOOT" -s "$SERIAL" flash system_a "$SYSTEM_IMG"'
    ) == 1
    and d0_img0_flash.count('sha256sum "$SYSTEM_IMG"') == 1
    and d0_img0_flash.count(
        '"$SABLE_FASTBOOT" -s "$SERIAL" reboot </dev/null'
    ) == 1
    and "AUTOMATIC_FLASH_RETRY=NO" in d0_img0_flash
    and "N1I_D0_IMG0_FLASH_DUPLICATE_WRITE_GUARD=REFUSE_PRIOR_ATTEMPT"
        in d0_img0_flash
    and "N1I_D0_IMG0_FLASH_DUPLICATE_WRITE_GUARD=REFUSE_CORRUPT_PRIOR_EVIDENCE"
        in d0_img0_flash
    and "N1I_D0_IMG0_DO_NOT_REFLASH_AFTER_THIS_POINT_WITHOUT_OWNER_REVIEW=YES"
        in d0_img0_flash
    and "N1I_D0_IMG0_DO_NOT_REFLASH_IF_POSTBOOT_OBSERVATION_FAILS=YES"
        in d0_img0_flash
    and "FACTORY_RESET_AUTHORIZED=NO" in d0_img0_flash
    and "USERDATA_ERASE_AUTHORIZED=NO" in d0_img0_flash
    and "SLOT_CHANGE_AUTHORIZED=NO" in d0_img0_flash
    and "AVB_MUTATION_AUTHORIZED=NO" in d0_img0_flash
    and "BOOT_CHAIN_MUTATION_AUTHORIZED=NO" in d0_img0_flash
    and "COW_DELETION_AUTHORIZED=NO" in d0_img0_flash
    and "TARGET_BYTES = 3_200_548_864" in d0_img0_fastboot_qual
    and "REVIEWED_GROUP_SAFE_SYSTEM_TARGET_CEILING_BYTES = 3_263_168_512"
        in d0_img0_fastboot_qual
    and "MIN_REMAINING_SUPER_HEADROOM_BYTES = 536_870_912"
        in d0_img0_fastboot_qual
    and 'baseline = "LIVE_CURRENT_SYSTEM_A"' in d0_img0_fastboot_qual
    and "N1I_D0_IMG0_FASTBOOT_STATE=FAIL_ACTIVE_COWS="
        in d0_img0_fastboot_qual
    and d0_img0_python_syntax_ok
    and "SAME_SIZE_NOT_TREATED_AS_CONTENT_IDENTITY" in d0_img0_flash_test
    and "N1I_D0_IMG0_FLASH_EXECUTOR_TEST=PASS" in d0_img0_flash_test
    and "N1I_D0_IMG0_FLASH_EXECUTOR_CONTRACT=PASS"
        in d0_img0_flash_contract,
    "d0_img0_exact_mode_aware_single_write_no_retry_marker_only_authority",
)

if failures:
    print(f"SABLE_TITAN2_FLASH_REGRESSION_COUNT={len(REQUIRED_IDS)}")
    print("SABLE_TITAN2_FLASH_REGRESSION_CONTRACT=FAIL")
    for failure in failures:
        print(f"SABLE_TITAN2_FLASH_REGRESSION_FAILURE={failure}")
    raise SystemExit(1)

print(f"SABLE_TITAN2_FLASH_REGRESSION_COUNT={len(REQUIRED_IDS)}")
print("SABLE_TITAN2_FLASH_REGRESSION_CONTRACT=PASS")
