#!/usr/bin/env bash
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
SOURCE="$ROOT/src/android/packages/apps/SableStart/src/com/sable/start/platform/LauncherProfileSecurityGate.kt"
TEST="$ROOT/tests/titan2/q25-nextbuild/ProfileSecuritySmoke.kt"
command -v kotlinc >/dev/null || { echo "PROFILE_SECURITY_KOTLINC=HOLD" >&2; exit 78; }
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
kotlinc "$SOURCE" "$TEST" -include-runtime -d "$TMP/profile-smoke.jar"
java -jar "$TMP/profile-smoke.jar"
