#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$REPO_ROOT/build/config/panther-grapheneos-2026081300.env"

APP_DIR="${APP_DIR:-$SABLEOS_UPSTREAM/packages/apps/SableStart}"
DEST="${DEST:-$REPO_ROOT/src/android/packages/apps/SableStart}"

if [[ ! -d "$APP_DIR" ]]; then
    echo "APP_DIR not found: $APP_DIR"
    exit 2
fi

mkdir -p "$DEST"
rsync -a \
  --include='*/' \
  --include='*.kt' \
  --include='*.java' \
  --include='*.xml' \
  --include='Android.bp' \
  --include='Android.mk' \
  --exclude='*' \
  "$APP_DIR/" "$DEST/"

find "$DEST" -type f -print0 | sort -z | xargs -0 sha256sum > "$DEST/SHA256SUMS.txt"

echo "SABLESTART_CAPTURE=PASS"
echo "DEST=$DEST"
echo "Review git diff before committing. This script never commits automatically."
