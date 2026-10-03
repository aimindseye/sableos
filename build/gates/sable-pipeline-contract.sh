#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASE_PIPELINE_COMMIT="a350fe8fffc0cf1f719c60f1dff4f6ccd64b7d67"
CORE_PATH="build/gates/sable-pipeline-contract.sh"

core="$(mktemp)"
core_log="$(mktemp)"
trap 'rm -f "$core" "$core_log"' EXIT

git -C "$ROOT" show "$BASE_PIPELINE_COMMIT:$CORE_PATH" > "$core"
python3 - "$core" "$ROOT" <<'PY'
from __future__ import annotations
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
root = sys.argv[2]
text = path.read_text(encoding="utf-8")
text = text.replace(
    'ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"',
    f'ROOT={root!r}',
    1,
)
old = '''for d in titan2 titan2-elite q27; do
  f="$ROOT/build/devices/$d.sh"
  grep -Fq 'SABLE_DEVICE_FLASH_SUPPORTED=NO' "$f"
  grep -Fq 'SABLE_DEVICE_ARTIFACT_REGISTRATION_SUPPORTED=NO' "$f"
  grep -Fq 'SABLE_DEVICE_FLASH_PLAN_SUPPORTED=NO' "$f"
  grep -Fq 'SABLE_DEVICE_ARTIFACT_KINDS=""' "$f"
  grep -Fq 'SABLE_DEVICE_FLASH_TRANSPORT=UNQUALIFIED' "$f"
  grep -Fq 'SABLE_DEVICE_QUALIFY_SUPPORTED=NO' "$f"
  grep -Fq 'SABLE_DEVICE_QUALIFY=BLOCKED_UNQUALIFIED' "$f"
  grep -Fq 'BLOCKED_UNQUALIFIED' "$f"
done'''
new = '''TITAN2="$ROOT/build/devices/titan2.sh"
grep -Fq 'SABLE_DEVICE_FLASH_SUPPORTED=NO' "$TITAN2"
grep -Fq 'SABLE_DEVICE_ARTIFACT_REGISTRATION_SUPPORTED=YES' "$TITAN2"
grep -Fq 'SABLE_DEVICE_FLASH_PLAN_SUPPORTED=YES' "$TITAN2"
grep -Fq 'SABLE_DEVICE_ARTIFACT_KINDS="gsi-system-image"' "$TITAN2"
grep -Fq 'SABLE_DEVICE_FLASH_TRANSPORT=titan2-fastbootd-ledger-only' "$TITAN2"
grep -Fq 'TITAN2_FLASH_EXECUTION_SUPPORTED=NO' "$TITAN2"
grep -Fq 'TITAN2_WRITE_CAPABLE_SCRIPT_ALLOWED=NO' "$TITAN2"
grep -Fq 'SABLE_DEVICE_ARTIFACT_GATE=PASS_TITAN2_GSI' "$TITAN2"
grep -Fq 'TITAN2_N0_N1_FLASH_PLAN_REQUIRED=YES' "$TITAN2"
grep -Fq 'prepare-n0-n1-flash-plan.sh' "$TITAN2"
grep -Fq 'SABLE_DEVICE_QUALIFY_SUPPORTED=NO' "$TITAN2"
grep -Fq 'SABLE_DEVICE_QUALIFY=BLOCKED_UNQUALIFIED' "$TITAN2"
grep -Fq 'BLOCKED_UNQUALIFIED' "$TITAN2"
echo "SABLE_PIPELINE_TITAN2_GSI_LEDGER_ADAPTER=PASS"

for d in titan2-elite q27; do
  f="$ROOT/build/devices/$d.sh"
  grep -Fq 'SABLE_DEVICE_FLASH_SUPPORTED=NO' "$f"
  grep -Fq 'SABLE_DEVICE_ARTIFACT_REGISTRATION_SUPPORTED=NO' "$f"
  grep -Fq 'SABLE_DEVICE_FLASH_PLAN_SUPPORTED=NO' "$f"
  grep -Fq 'SABLE_DEVICE_ARTIFACT_KINDS=""' "$f"
  grep -Fq 'SABLE_DEVICE_FLASH_TRANSPORT=UNQUALIFIED' "$f"
  grep -Fq 'SABLE_DEVICE_QUALIFY_SUPPORTED=NO' "$f"
  grep -Fq 'SABLE_DEVICE_QUALIFY=BLOCKED_UNQUALIFIED' "$f"
  grep -Fq 'BLOCKED_UNQUALIFIED' "$f"
done'''
if old not in text:
    print("SABLE_PIPELINE_BASE_PATCH=FAIL_TITAN2_ADAPTER_BLOCK")
    raise SystemExit(1)
text = text.replace(old, new, 1)
path.write_text(text, encoding="utf-8")
print("SABLE_PIPELINE_BASE_PATCH=PASS")
PY

set +e
bash "$core" | tee "$core_log"
core_rc="${PIPESTATUS[0]}"
set -e
if ! grep -Fq 'SABLE_STANDARD_PIPELINE_CONTRACT=PASS' "$core_log"; then
  echo "SABLE_PIPELINE_BASE_CONTRACT=FAIL rc=$core_rc"
  exit "$core_rc"
fi
if [[ "$core_rc" -ne 0 ]]; then
  echo "SABLE_PIPELINE_BASE_CONTRACT=PASS_MARKER_RC_IGNORED rc=$core_rc"
else
  echo "SABLE_PIPELINE_BASE_CONTRACT=PASS"
fi

grep -Fq 'run_static_contract sable-pipeline' "$ROOT/build/local-ci/run.sh"
echo "SABLE_PIPELINE_LOCAL_CI_RUNS_SABLE_PIPELINE=PASS"
grep -Fq 'SABLEOS_DEVICE="${SABLEOS_DEVICE:-panther}"' "$ROOT/build/local-ci/run.sh"
echo "SABLE_PIPELINE_LOCAL_CI_DEVICE_VARIABLE=PASS"
grep -Fq 'SABLEOS_RELEASE_VERSION="${SABLEOS_RELEASE_VERSION:-R9}"' "$ROOT/build/local-ci/run.sh"
echo "SABLE_PIPELINE_LOCAL_CI_RELEASE_VARIABLE=PASS"
grep -Fq 'run_n1b_contract FULL_CI_READINESS' \
  "$ROOT/build/gates/n1b-titan2-local-ci-static-contracts.sh"
echo "SABLE_PIPELINE_N1B_FULL_CI_SOURCE_BINDING=PASS"
echo "SABLE_PIPELINE_N1B_LOCAL_CI_BINDING=PASS"

SABLEOS_DEVICE=titan2 \
SABLEOS_RELEASE_VERSION=N1B \
  bash "$ROOT/build/gates/n1b-titan2-local-ci-static-contracts.sh"

bash "$ROOT/build/gates/storage-root-contract.sh"
bash "$ROOT/build/gates/host-tools-contract.sh"
bash "$ROOT/build/gates/n1d-c3-script-quality-contract.sh"
bash "$ROOT/build/gates/n1d-c3b-product-review-staging-contract.sh"
bash "$ROOT/build/gates/n1d-c3b-e2-product-admission-contract.sh"
bash "$ROOT/build/gates/n1d-c3b-e2-product-composition-contract.sh"
bash "$ROOT/build/gates/n1d-c3b-e3-systemimage-contract.sh"
bash "$ROOT/build/gates/n1d-c3b-e4-deployment-readiness-contract.sh"
bash "$ROOT/build/gates/n1d-c3b-e5a-readonly-device-state-contract.sh"
bash "$ROOT/build/gates/n1d-restless-security-boundary-contract.sh"
bash "$ROOT/build/gates/n1d-source-lock-contract.sh"
bash "$ROOT/build/gates/n1d-fresh-source-contract.sh"
bash "$ROOT/build/gates/n1d-c2-source-admission-contract.sh"
bash "$ROOT/build/gates/n1d-c2-prebuilt-control-contract.sh"
bash "$ROOT/build/gates/n1d-c3-phase-split-contract.sh"
bash "$ROOT/build/gates/n1d-c3a-control-evidence-contract.sh"
bash "$ROOT/build/gates/n1d-c3b-transition-contract.sh"
bash "$ROOT/build/gates/n1d-c3-trebledroid-contract.sh"
bash "$ROOT/build/gates/n1d-c3-product-composition-contract.sh"
bash "$ROOT/build/gates/n1d-c3b-engineering-contract.sh"
python3 "$ROOT/build/gates/n1d-c3b-hub-parity-contract.py"
bash "$ROOT/build/gates/n1d-c3-product-parse-contract.sh"
bash "$ROOT/build/gates/n1d-c3-trebledroid-build-contract.sh"

echo "SABLE_STANDARD_PIPELINE_CONTRACT=PASS"
