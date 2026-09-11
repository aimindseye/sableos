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

# Capture the complete module source tree rather than guessing source extensions.
# Build/cache directories are excluded. Repository-only status/hash files already
# present in DEST are intentionally preserved for review.
rsync -a \
  --exclude='/.git/' \
  --exclude='/out/' \
  --exclude='/build/' \
  --exclude='/.gradle/' \
  --exclude='/target/' \
  "$APP_DIR/" "$DEST/"

find "$DEST" -type f \
  ! -name 'SHA256SUMS.txt' \
  -print0 | sort -z | xargs -0 sha256sum > "$DEST/SHA256SUMS.txt"

echo "SABLESTART_CAPTURE=PASS"
echo "SOURCE=$APP_DIR"
echo "DEST=$DEST"
echo "NEXT=bash build/panther/verify-sablestart-snapshot.sh"
echo "Review git status/diff before committing. This script never commits automatically."
