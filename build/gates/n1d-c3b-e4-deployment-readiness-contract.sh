#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DRIVER="$ROOT/build/titan2/qualify-n1d-c3b-e4-deployment-readiness.sh"

fail(){ echo "N1D_C3B_E4_CONTRACT_FAIL=$1" >&2; exit 1; }

bash -n "$DRIVER"

for token in   'DEVICE_CONTACT_AUTHORIZED=NO'   'FLASH_AUTHORIZED=NO'   'LP_MUTATION_AUTHORIZED=NO'   'AVB_MUTATION_AUTHORIZED=NO'   'NETWORK_FETCH_AUTHORIZED=NO'   'N1D_C3B_E4_E3_IMAGE_SEAL=PASS'   'N1D_C3B_E4_SYSTEM_AVB_INFO=PASS'   'N1D_C3B_E4_STOCK_RESTORE_PROOF=PASS'   'N1D_C3B_E4_PARTITION_FIT='   'N1D_C3B_E4_DEPLOYMENT_READINESS=PASS_REVIEW_READY'
do
  grep -Fq "$token" "$DRIVER" || fail "missing_token=$token"
done

if grep -Eq '(^|[;&|[:space:]])adb([[:space:]]|$)|(^|[;&|[:space:]])fastboot([[:space:]]|$)' "$DRIVER"; then
  fail device_command_present
fi
if grep -Eq 'fastboot[[:space:]]+(flash|erase|reboot|set_active|delete-logical-partition|resize-logical-partition)|avbtool[[:space:]]+(add_|erase_)' "$DRIVER"; then
  fail mutation_command_present
fi
if grep -Eq 'curl[[:space:]]|wget[[:space:]]|git[[:space:]]+(fetch|pull|clone)|repo[[:space:]]+sync' "$DRIVER"; then
  fail network_command_present
fi
if grep -Eq '(^|[;&|[:space:]])(m|make|ninja)[[:space:]]' "$DRIVER"; then
  fail build_command_present
fi

echo "N1D_C3B_E4_DEVICE_COMMANDS=PASS_ABSENT"
echo "N1D_C3B_E4_MUTATION_COMMANDS=PASS_ABSENT"
echo "N1D_C3B_E4_NETWORK_COMMANDS=PASS_ABSENT"
echo "N1D_C3B_E4_BUILD_COMMANDS=PASS_ABSENT"
echo "N1D_C3B_E4_DEPLOYMENT_READINESS_CONTRACT=PASS"
