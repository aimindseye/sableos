#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
AUDIT="$ROOT/build/titan2/audit-n1i-c1-bootclasspath-collisions.py"
STATIC="$ROOT/build/titan2/n1i_static.py"
HOST_TOOLS_PROFILE="$ROOT/build/config/host-tools.env"

fail() {
  echo "N1I_C1_BCP_COLLISION_TEST_$1=FAIL"
  exit 1
}

pass() {
  echo "N1I_C1_BCP_COLLISION_TEST_$1=PASS"
}

[[ -f "$AUDIT" ]] || fail AUDIT_PRESENT
[[ -f "$STATIC" ]] || fail STATIC_FOUNDATION_PRESENT
[[ -f "$HOST_TOOLS_PROFILE" ]] || fail HOST_TOOLS_PROFILE_PRESENT

source "$HOST_TOOLS_PROFILE"

[[ -x "$SABLE_PYTHON" ]] || fail CANONICAL_PYTHON_EXECUTABLE

"$SABLE_PYTHON" - "$AUDIT" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
compile(path.read_text(encoding="utf-8"), str(path), "exec")
PY
pass SYNTAX

for marker in \
  'import n1i_static as S' \
  'COMMON = "/system_ext/framework/mediatek-common.jar"' \
  'IMS_BASE = "/system_ext/framework/mediatek-ims-base.jar"' \
  'N1I_C1_BCP_COMMON_SHADOWED_BY_BASE' \
  'N1I_C1_BCP_IMS_BASE_SHADOWED_BY_BASE' \
  'N1I_C1_BCP_IMPORTED_MUTUAL_DUPLICATES' \
  'PASS_NO_DUPLICATE_CLASS_OWNERSHIP' \
  'def vdex_dexes' \
  'compact_vdex_unsupported'
do
  grep -Fq "$marker" "$AUDIT" || fail REQUIRED_MARKERS
done
pass REQUIRED_MARKERS

if grep -Eq '(^|[^A-Za-z_])(adb|fastboot)[[:space:](]' "$AUDIT"; then
  fail NO_DEVICE_COMMANDS
fi
pass NO_DEVICE_COMMANDS

if grep -Eq 'subprocess|requests|urllib|socket|http://|https://' "$AUDIT"; then
  fail NO_NETWORK_OR_PROCESS_EXEC
fi
pass NO_NETWORK_OR_PROCESS_EXEC

if grep -Eq 'write_text|write_bytes|open\([^)]*,[[:space:]]*["'"'"'][wa+]|unlink\(|rename\(|replace\(|mkdir\(|rmdir\(|shutil\.' "$AUDIT"; then
  fail READ_ONLY_INPUTS
fi
pass READ_ONLY_INPUTS

"$SABLE_PYTHON" "$AUDIT" --selftest
pass SELFTEST

echo "N1I_C1_BOOTCLASSPATH_COLLISION_AUDIT_REGRESSION=PASS"
