#!/usr/bin/env bash
# Compatibility wrapper. The handcrafted C3 product path is retired.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
echo "N1D_C3_HANDCRAFTED_PRODUCT_PATH=RETIRED"
exec bash "$ROOT/build/titan2/prepare-n1d-c3-trebledroid.sh" "$@"
