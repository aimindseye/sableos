#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Historical filename retained for accepted Panther contracts. Canonical
# migration is build-independent.
exec bash "$ROOT/build/host/migrate-canonical-host-tools.sh" "$@"
