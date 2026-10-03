#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ADAPTER="$ROOT/build/devices/titan2.sh"
PLAN="$ROOT/build/titan2/prepare-c3a-v010014-standard-flash-plan.sh"
GSI_INFO="$ROOT/build/deploy/gsi_image_info.py"

fail() {
  echo "C3A_V010014_STANDARD_FLASH_PLAN_CONTRACT=FAIL reason=$*" >&2
  exit 1
}

for f in "$ADAPTER" "$PLAN" "$GSI_INFO"; do
  [[ -f "$f" ]] || fail "missing=$f"
done

bash -n "$ADAPTER"
bash -n "$PLAN"
PYTHONPYCACHEPREFIX="${TMPDIR:-/tmp}/sable-pycache"   python3 -m py_compile "$GSI_INFO"
python3 "$GSI_INFO" --self-test |
  grep -Fxq 'SABLE_GSI_IMAGE_INFO_SELF_TEST=PASS' ||
  fail gsi_info_self_test

for marker in   'EXPECTED_BUILD_SOURCE="23f6ce0055cdbbbed9d35705264b5e73737e6560"'   'CANONICAL_SYSTEM_SHA256="4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16"'   'CANONICAL_SYSTEM_BYTES=3146977280'   'CANONICAL_SYSTEM_CURRENT_BYTES=2994388992'   'CANONICAL_SUPER_BYTES=9663676416'   'EXPECTED_PREFLIGHT_SEAL_SHA256="47f28c371f13974d3a7303dc550014502401fae55a76bb365139f29e4c2da893"'   'EXPECTED_OFFLINE_SEAL_SHA256="e6ad9a20192ef7c1fcb8bf0bfc1f393afd8b9cdd7239cb19b0497512f4f8fd57"'   'EXPECTED_BASELINE_E5B_SHA256="74531923a9ea6c755a9f8ea52db511c4a4a19a5d9dba3cb51da342c04b768926"'   'EXPECTED_FASTBOOT_BINDING_SHA256="bcfdee61b23e3cb002919c27a055389ffe37e284bf5150dfc1d0bbbd7564090a"'   'PASS_READY_FOR_PHYSICAL_CONTROL_REVIEW'   'TARGET_PARTITION=system_a'   'EXPECTED_ACTIVE_SLOT=$CANONICAL_SLOT'   'EXPECTED_ACTIVE_COW_COUNT=0'   'FLASH_ENTRY_MODE=userspace-fastbootd'   'FASTBOOT_IMPLICIT_RESIZE=YES'   'MANUAL_PRE_RESIZE_REQUIRED=NO'   'COW_DELETION_ALLOWED=NO'   'SLOT_CHANGE_ALLOWED=NO'   'AVB_MUTATION_ALLOWED=NO'   'BOOT_CHAIN_FLASH_ALLOWED=NO'   'WHOLE_SUPER_FLASH_ALLOWED=NO'   'USERDATA_ERASE_ALLOWED=NO'   'FACTORY_RESET_ALLOWED=NO'   'AUTOMATIC_FLASH_RETRY_ALLOWED=NO'   'WRITE_CAPABLE_SCRIPT_CREATED=NO'   'FLASH_AUTHORIZED=NO'   'FACTORY_RESET_AUTHORIZED=NO'   'EXECUTION_GATE=SEPARATE_STANDARD_ADAPTER_SCOPE_TOKEN_BOUND_TO_THIS_PLAN_SEAL_REQUIRED'   'C3A_V010014_STANDARD_FLASH_PLAN=PASS_PREPARED_NO_WRITE'
do
  grep -Fq -- "$marker" "$PLAN" || fail "plan_marker_missing=$marker"
done

for marker in   'TITAN2_N1D_C3A_BUILD_SOURCE="23f6ce0055cdbbbed9d35705264b5e73737e6560"'   'TITAN2_N1D_C3A_SYSTEM_SHA256="4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16"'   'TITAN2_N1D_C3A_SYSTEM_CURRENT_BYTES=2994388992'   'TITAN2_N1D_C3A_SYSTEM_LOGICAL_BYTES=3146977280'   'TITAN2_N1D_C3A_PREFLIGHT_SEAL_SHA256="47f28c371f13974d3a7303dc550014502401fae55a76bb365139f29e4c2da893"'   'TITAN2_N1D_C3A_OFFLINE_SEAL_SHA256="e6ad9a20192ef7c1fcb8bf0bfc1f393afd8b9cdd7239cb19b0497512f4f8fd57"'   'TITAN2_N1D_C3A_EXECUTION_SUPPORTED=NO_PENDING_PLAN_SCOPE'   'TITAN2_N1D_C3A_ARTIFACT_GATE=PASS_CONTROL_ONLY'   'TITAN2_N1D_C3A_FLASH_EXECUTION_SUPPORTED=NO_PENDING_PLAN_SCOPE'   'prepare-c3a-v010014-standard-flash-plan.sh'   'artifacts.c3a_preflight.path'   'artifacts.c3a_preflight_sums.path'   'artifacts.c3a_offline_plan.path'   'artifacts.c3a_offline_sums.path'   'artifacts.c3a_baseline_e5a.path'   'artifacts.c3a_baseline_e5b.path'
do
  grep -Fq -- "$marker" "$ADAPTER" || fail "adapter_marker_missing=$marker"
done

python3 - "$ADAPTER" <<'PY'
from __future__ import annotations
import pathlib
import re
import sys

text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
match = re.search(
    r"sable_device_flash_policy\(\) \{(?P<body>.*?)\n\}\nsable_device_registry_field\(\)",
    text,
    re.S,
)
if not match:
    raise SystemExit(
        "C3A_V010014_STANDARD_FLASH_PLAN_CONTRACT=FAIL "
        "reason=flash_policy_parse"
    )
body = match.group("body")
blocked = [
    "TITAN2_N1D_C3A_BUILD_SOURCE",
    "C3A_CONTROL",
    "N1D-C3A",
]
for marker in blocked:
    if marker in body:
        raise SystemExit(
            "C3A_V010014_STANDARD_FLASH_PLAN_CONTRACT=FAIL "
            f"reason=c3a_execution_open marker={marker}"
        )
print("C3A_V010014_STANDARD_FLASH_PLAN_EXECUTION_REMAINS_BLOCKED=PASS")
PY

if grep -Eq '^[[:space:]]*(sudo[[:space:]]+)?(adb|fastboot)([[:space:]]|$)' "$PLAN"; then
  fail plan_device_command_present
fi

if grep -Eq   '^[[:space:]]*(curl|wget|make|ninja)([[:space:]]|$)|^[[:space:]]*repo[[:space:]]+sync([[:space:]]|$)|^[[:space:]]*git[[:space:]]+(fetch|pull|clone)([[:space:]]|$)'   "$PLAN"; then
  fail plan_forbidden_host_operation
fi

if grep -Fq 'fastboot flash system_a' "$PLAN"; then
  fail write_command_literal_present
fi

echo "C3A_V010014_STANDARD_FLASH_PLAN_SCRIPT_SYNTAX=PASS"
echo "C3A_V010014_STANDARD_FLASH_PLAN_ARTIFACT_GATE=PASS_STATIC"
echo "C3A_V010014_STANDARD_FLASH_PLAN_REGISTRY_ROUTING=PASS_STATIC"
echo "C3A_V010014_STANDARD_FLASH_PLAN_EVIDENCE_BINDING=PASS_STATIC"
echo "C3A_V010014_STANDARD_FLASH_PLAN_NO_DEVICE_COMMANDS=PASS"
echo "C3A_V010014_STANDARD_FLASH_PLAN_EXECUTION_GATE=PASS_CLOSED"
echo "C3A_V010014_STANDARD_FLASH_PLAN_CONTRACT=PASS"
