#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CI="$ROOT/build/local-ci/run.sh"
AUDIT_CONFIG="$ROOT/apps/r8/rust/.cargo/audit.toml"

fail() {
  echo "N1D_LOCAL_CI_SCOPE_CONTRACT=FAIL $*" >&2
  exit 1
}

[[ -f "$CI" ]] || fail "missing_local_ci=$CI"
[[ -f "$AUDIT_CONFIG" ]] || fail "missing_audit_config=$AUDIT_CONFIG"
bash -n "$CI" || fail "local_ci_syntax"

require() {
  local needle="$1"
  grep -Fq "$needle" "$CI" || fail "missing=$needle"
}

require 'if [[ "$SABLEOS_DEVICE" == panther && "$SABLEOS_RELEASE_VERSION" == R9 ]]; then'
require 'SABLE_LOCAL_CI_PANTHER_R9_STATIC_CONTRACTS=SKIP'
require 'SABLE_LOCAL_CI_R9_LAUNCHER3_FOUNDATION=SKIP'
require 'SABLE_LOCAL_CI_R9_SABLESTART_DESIGN=SKIP_NONSELECTED_PANTHER_R9_PRODUCT'
require ':messages:detekt'
require ':messages:ktlintCheck'
require ':messages:testDebugUnitTest'
require ':messages:assembleDebug'
require ':messages:lintDebug'
require '"$SABLE_CARGO" audit --no-fetch --deny warnings'
require '"$SABLE_CARGO" deny --offline check advisories bans sources'
grep -Fxq 'fetch = false' "$AUDIT_CONFIG" || fail 'audit_database_fetch_not_disabled'
grep -Fxq 'stale = false' "$AUDIT_CONFIG" || fail 'audit_stale_policy_not_fail_closed'
grep -Fxq 'enabled = true' "$AUDIT_CONFIG" || fail 'audit_yanked_check_not_enabled'
grep -Fxq 'update_index = false' "$AUDIT_CONFIG" || fail 'audit_yanked_index_update_not_disabled'

for panther_only in   'r8-build-driver-contract.sh'   'r9-physical-remediation-contract.py'   'r9-system-cohesion-contract.py'   'r9-physical-ux-closure-contract.py'   'r9-launcher3-foundation-contract.py'
do
  count="$(grep -Fc "$panther_only" "$CI")"
  [[ "$count" -ge 1 ]] || fail "missing_panther_contract=$panther_only"
done

for shared in   'sable-pipeline-contract.sh'   'r9-textreader-standalone-contract.py'   'r9-sms-mms-blocking-contract.py'   'r9-first-party-app-icon-contract.py'   'r9-media-flow-contract.py'   'r9-messages-native-first-contract.py'   'r9-messages-local-conversation-contract.py'   'r9-standalone-messages-quality-contract.py'   'r9-messages-source-style.py'   'r9-sablestart-design-contract.py'
do
  grep -Fq "$shared" "$CI" || fail "missing_shared_contract=$shared"
done

python3 - "$CI" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
start = text.index('if [[ "$SABLEOS_DEVICE" == panther && "$SABLEOS_RELEASE_VERSION" == R9 ]]; then')
end = text.index('  run_static_contract r9-textreader-standalone', start)
block = text[start:end]

required = [
    "r8-build-driver-contract.sh",
    "r9-physical-remediation-contract.py",
    "r9-system-cohesion-contract.py",
    "r9-physical-ux-closure-contract.py",
]
for token in required:
    if token not in block:
        raise SystemExit(f"N1D_LOCAL_CI_SCOPE_CONTRACT=FAIL panther_scope_missing={token}")

launcher_start = text.index(
    'if [[ "$SABLEOS_DEVICE" == panther && "$SABLEOS_RELEASE_VERSION" == R9 ]]; then',
    end,
)
launcher_end = text.index('  if [[ "$static_contract_failures"', launcher_start)
launcher_block = text[launcher_start:launcher_end]
if "r9-launcher3-foundation-contract.py" not in launcher_block:
    raise SystemExit(
        "N1D_LOCAL_CI_SCOPE_CONTRACT=FAIL panther_scope_missing=launcher3_foundation"
    )

# The Panther R9 production design requirement is NEVER waived; only the
# selected Titan2/TB2 product gets an exact-scoped non-applicable disposition.
# The shared contract's self-test must remain active for all products.
design_start = text.index('  run_static_contract r9-sablestart-design-self-test')
design_end = text.index(
    '  if [[ "$SABLEOS_DEVICE" == panther && "$SABLEOS_RELEASE_VERSION" == R9 ]]; then',
    design_start,
)
design_block = text[design_start:design_end]
expected_design_block = r'''  run_static_contract r9-sablestart-design-self-test \
    python3 "$ROOT/build/gates/r9-sablestart-design-contract.py" --self-test
  if [[ "$SABLEOS_DEVICE" == titan2 && "${SABLEOS_RELEASE_VERSION^^}" == TB2 ]]; then
    # PR347 Titan2/TB2 has a separately reviewed A16 launcher source/design.
    # Keep the R9 contract self-test, but do not impose Panther R9 UI literals.
    echo "SABLE_LOCAL_CI_R9_SABLESTART_DESIGN=SKIP_NONSELECTED_PANTHER_R9_PRODUCT"
  else
    run_static_contract r9-sablestart-design \
      python3 "$ROOT/build/gates/r9-sablestart-design-contract.py"
  fi
'''
if design_block != expected_design_block:
    raise SystemExit(
        "N1D_LOCAL_CI_SCOPE_CONTRACT=FAIL r9_design_nonselected_exception_drift"
    )

for shared in (
    "r9-textreader-standalone-contract.py",
    "r9-first-party-app-icon-contract.py",
    "r9-messages-native-first-contract.py",
    "r9-sablestart-design-contract.py",
):
    if shared in block or shared in launcher_block:
        raise SystemExit(
            f"N1D_LOCAL_CI_SCOPE_CONTRACT=FAIL shared_contract_scoped_to_panther={shared}"
        )

print("N1D_LOCAL_CI_SCOPE_PANTHER_R9=PASS")
print("N1D_LOCAL_CI_SCOPE_SHARED_CHECKS=PASS")
PY

echo "N1D_LOCAL_CI_SCOPE_CONTRACT=PASS"
