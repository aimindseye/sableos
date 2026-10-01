#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROFILE="$ROOT/build/titan2/n1d-c2-prebuilt-control.env"
FETCHER="$ROOT/build/titan2/fetch-n1d-c2-control.sh"
RETIRE="$ROOT/build/titan2/retire-n1d-c2-source.sh"
ADMISSION_PROFILE="$ROOT/build/titan2/n1d-c2-source-admission.env"

fail() { echo "N1D_C2_PREBUILT_CONTROL_CONTRACT=FAIL $*" >&2; exit 1; }

for f in "$PROFILE" "$FETCHER" "$RETIRE" "$ADMISSION_PROFILE"; do
    [[ -f "$f" ]] || fail "missing_file=$f"
done

bash -n "$PROFILE" "$FETCHER" "$RETIRE"

for required in \
    'N1D_C2_CONTROL_VERSION=1' \
    'N1D_C2_CONTROL_MODE=PINNED_PREBUILT_RESTLESS_GSI' \
    'N1D_C2_EXACT_SOURCE_RECONSTRUCTION=BLOCKED_PUBLIC_SOURCE_OBJECT_UNAVAILABLE' \
    'N1D_C2_SOURCE_ADMISSION_RETRY_ALLOWED=NO' \
    'N1D_C2_RESTLESS_TAG=16.0.0-202606230923' \
    'N1D_C2_RESTLESS_COMMIT=4adc5766f457849ca37e0b318bced65aef5a2233' \
    'N1D_C2_GRAPHENE_BASE_TAG=2026061600' \
    'N1D_C2_CONTROL_ASSET_NAME=RestlessOS-arm64-ab-16.0.0-202606230923.img.xz' \
    'N1D_C2_CONTROL_ASSET_SIZE=920490780' \
    'N1D_C2_CONTROL_ASSET_SHA256=52ea47d794faf6eafbb49a5f0d2301508757be0e30d1b73e033e1d5185bb492c' \
    'N1D_C2_UNAVAILABLE_SOURCE_1_PATH=device/phh/treble' \
    'N1D_C2_UNAVAILABLE_SOURCE_1_REVISION=db688b38d729cf33e31baea47986c3fd210b671e' \
    'N1D_C2_UNAVAILABLE_SOURCE_2_PATH=prebuilts/vndk/v29' \
    'N1D_C2_UNAVAILABLE_SOURCE_2_REVISION=0062f4721125d68951fba37361c8204b929ae178' \
    'N1D_C2_PRODUCT_ROLE=DIAGNOSTIC_CONTROL_ONLY' \
    'N1D_C2_PREBUILT_CONTROL_CONTRACT=PASS'
do
    grep -Fxq "$required" "$PROFILE" || fail "profile_missing=$required"
done

grep -Fq 'network_action_requires_--authorize-network' "$FETCHER" || fail fetch_network_guard_missing
grep -Fq 'curl --fail --location --retry 5' "$FETCHER" || fail resilient_fetch_missing
grep -Fq -- '--continue-at -' "$FETCHER" || fail resumable_fetch_missing
grep -Fq 'N1D_C2_CONTROL_ASSET_SHA256=PASS' "$FETCHER" || fail asset_sha_gate_missing
grep -Fq 'N1D_C2_CONTROL_ASSET_SIZE=PASS' "$FETCHER" || fail asset_size_gate_missing
grep -Fq 'SOURCE_MUTATION_AUTHORIZED=YES_C2_LOCAL_MANIFEST_AND_EXACT_C2_WORKTREES_ONLY' "$RETIRE" || fail retirement_scope_missing
grep -Fq 'N1D_C2_SOURCE_RETIREMENT_BASE_HEADS=PASS_EXACT' "$RETIRE" || fail retirement_base_proof_missing
grep -Fq 'N1D_C2_SOURCE_RETIREMENT=PASS' "$RETIRE" || fail retirement_pass_missing
grep -Fxq 'N1D_C2_EXACT_SOURCE_RECONSTRUCTION=BLOCKED_PUBLIC_SOURCE_OBJECT_UNAVAILABLE' "$ADMISSION_PROFILE" || fail admission_block_binding_missing
grep -Fxq 'N1D_C2_SOURCE_ADMISSION_RETRY_ALLOWED=NO' "$ADMISSION_PROFILE" || fail admission_retry_binding_missing

if grep -Fq '/srv/data/sable-build' "$PROFILE" "$FETCHER" "$RETIRE"; then
    fail legacy_build_root_hardcoded
fi
if grep -Eq '(^|[[:space:]])(adb|fastboot)([[:space:]]|$)' "$FETCHER" "$RETIRE"; then
    fail device_command_present
fi

echo "N1D_C2_PREBUILT_CONTROL_IDENTITY=PASS"
echo "N1D_C2_PREBUILT_CONTROL_ASSET_CONTRACT=PASS"
echo "N1D_C2_PREBUILT_CONTROL_SOURCE_RETRY_BLOCK=PASS"
echo "N1D_C2_PREBUILT_CONTROL_RETIREMENT_CONTRACT=PASS"
echo "N1D_C2_PREBUILT_CONTROL_CONTRACT=PASS"
