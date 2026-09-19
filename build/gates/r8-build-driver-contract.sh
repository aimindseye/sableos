#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

profile="$ROOT/build/config/r8-host-tools.env"
release="$ROOT/build/config/r8-release.env"
verify="$ROOT/build/host/verify-r8-host-tools.sh"
migrate="$ROOT/build/host/migrate-r8-final-v1-host-tools.sh"
render="$ROOT/build/panther/render-r8-build-driver.sh"
runner="$ROOT/build/panther/run-r8-release-candidate.sh"

for f in "$profile" "$release" "$verify" "$migrate" "$render" "$runner"; do
    [[ -f "$f" ]] || {
        echo "R8_BUILD_DRIVER_CONTRACT=FAIL_MISSING path=$f"
        exit 2
    }
done

for f in "$verify" "$migrate" "$render" "$runner"; do
    bash -n "$f"
done

grep -Fq '/srv/data/sable-host-tools' "$profile"
! grep -R -Fq '/srv/data/sable-build/host-tools/r8-final-v1'     "$profile" "$release" "$verify" "$render" "$runner"

for needle in     'SABLE_ANDROID_API=36'     'SABLE_ANDROID_BUILD_TOOLS_VERSION=36.0.0'     'SABLE_ANDROID_NDK_VERSION=30.0.16248370'     'SABLE_RUST_VERSION=1.98.1'     'SABLE_RUST_TARGET=aarch64-linux-android'
do
    grep -Fq "$needle" "$profile"
done

grep -Fq 'SABLEOS_RELEASE_VERSION' "$release"
grep -Fq 'verify-r8-host-tools.sh' "$runner"
grep -Fq 'prepare-r8-final-ui.sh' "$runner"
grep -Fq 'build-r8-final-ui.sh' "$runner"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
bash "$render" 0123456789abcdef0123456789abcdef01234567 "$tmp" >/dev/null
bash -n "$tmp"
grep -Fq 'EXPECTED_SOURCE_COMMIT="0123456789abcdef0123456789abcdef01234567"' "$tmp"
grep -Fq 'SOURCE_MUTATION_AUTHORIZED=YES' "$tmp"
grep -Fq 'BUILD_AUTHORIZED=YES' "$tmp"

echo "R8_BUILD_DRIVER_CONTRACT=PASS"
