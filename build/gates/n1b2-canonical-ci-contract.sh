#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SABLE="$ROOT/build/sable.sh"
CI="$ROOT/build/local-ci/run.sh"
TITAN="$ROOT/build/devices/titan2.sh"

fail() {
  echo "N1B2_CANONICAL_CI_CONTRACT=FAIL $*" >&2
  exit 1
}

for file in "$SABLE" "$CI" "$TITAN"; do
  [[ -f "$file" ]] || fail "missing=$file"
  bash -n "$file" || fail "shell_syntax=$file"
done

grep -Fq 'bash build/sable.sh titan2 N1B2 ci core' "$SABLE"   || fail "canonical_command_not_documented"

for marker in   'SABLE_DEVICE_QUALIFY_SUPPORTED=NO'   'TITAN2_N1B2_BUILD_SUPPORTED=NO'   'TITAN2_N1B2_QUALIFY_SUPPORTED=NO'   'TITAN2_N1B2_FLASH_EXECUTION_SUPPORTED=NO'   'TITAN2_N1B2_WRITE_CAPABLE_SCRIPT_ALLOWED=NO'
do
  grep -Fq "$marker" "$TITAN" || fail "missing_titan_fail_closed_marker=$marker"
done

for marker in   'run_titan2_n1b2_evidence()'   'stage TITAN2_N1B2_EVIDENCE run_titan2_n1b2_evidence'   'N1I_TOOL_DX="$EVIDENCE_DIR/NO_LEGACY_DX"'   'N1I_TOOL_D8="$SABLE_ANDROID_BUILD_TOOLS/d8"'   'N1I_TOOL_DEXDUMP="$SABLE_ANDROID_BUILD_TOOLS/dexdump"'   'N1I_TOOL_CLANG="$ndk_llvm_bin/clang"'   'N1I_TOOL_LD_LLD="$ndk_llvm_bin/ld.lld"'   'N1I_TOOL_LLVM_OBJCOPY="$ndk_llvm_bin/llvm-objcopy"'   'N1I_TOOL_READELF="$ndk_llvm_bin/llvm-readelf"'   'N1I_B_TOOL_HISTORICAL_WORKSPACE_DISCOVERY=NO'   'TITAN2_N1B2_EVIDENCE_TOOLCHAIN=PASS_CANONICAL'   'TITAN2_N1B2_EVIDENCE_SELFTESTS=PASS'   'TITAN2_N1B2_IMPORT_AUTHORIZED=NO'   'TITAN2_N1B2_DEVICE_MUTATION_AUTHORIZED=NO'
do
  grep -Fq "$marker" "$CI" || fail "missing_ci_marker=$marker"
done

python3 - "$CI" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
start = text.index("run_titan2_n1b2_evidence() {")
end = text.index("\nrun_rust() {", start)
block = text[start:end]

if not re.search(
    r'if \[\[ "\$SABLEOS_DEVICE" == titan2 && "\$\{SABLEOS_RELEASE_VERSION\^\^\}" == N1B2 \]\]; then'
    r'[\s\S]*?stage TITAN2_N1B2_EVIDENCE run_titan2_n1b2_evidence',
    text,
):
    raise SystemExit("N1B2_CANONICAL_CI_CONTRACT=FAIL missing_exact_device_release_scope")

if re.search(r'(^|[;&|\s])(adb|fastboot)([\s]|$)', block, re.MULTILINE):
    raise SystemExit("N1B2_CANONICAL_CI_CONTRACT=FAIL real_device_command_in_evidence_stage")

required = (
    "DEVICE_CONTACT_AUTHORIZED=NO",
    "ADB_COMMANDS_RUN=NO_REAL_DEVICE",
    "FASTBOOT_COMMANDS_RUN=NO",
    "FLASH_AUTHORIZED=NO",
    "TITAN_CELLULAR_MUTATION_AUTHORIZED=NO",
    "NETWORK_FETCH_AUTHORIZED=NO",
)
for token in required:
    if token not in block:
        raise SystemExit(f"N1B2_CANONICAL_CI_CONTRACT=FAIL missing_safety_marker={token}")

print("N1B2_CANONICAL_CI_SCOPE=PASS_TITAN2_N1B2_ONLY")
print("N1B2_CANONICAL_CI_DEVICE_CONTACT=PASS_ABSENT")
PY

echo "N1B2_CANONICAL_CI_ENTRYPOINT=PASS_SABLE_SH"
echo "N1B2_CANONICAL_CI_FAIL_CLOSED_DEVICE_POLICY=PASS"
echo "N1B2_CANONICAL_CI_CONTRACT=PASS"
