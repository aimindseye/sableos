#!/usr/bin/env bash
# Pure Q25 launcher policy smoke checks. No Android, device, image, Gradle or network.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SOURCE="$ROOT/src/android/packages/apps/SableStart/src/com/sable/start"
test -f "$SOURCE/model/CommandQuery.kt"
test -f "$SOURCE/privacy/AllAppsInteraction.kt"
test -f "$SOURCE/privacy/AllAppsPermissionChips.kt"
command -v kotlinc >/dev/null || { echo 'Q25_PORTABLE_POLICY_SMOKE=HOLD_KOTLINC_MISSING'; exit 66; }
command -v java >/dev/null || { echo 'Q25_PORTABLE_POLICY_SMOKE=HOLD_JAVA_MISSING'; exit 66; }
OUT="$(mktemp -d)"
trap 'rm -rf -- "$OUT"' EXIT
kotlinc   "$SOURCE/model/CommandQuery.kt"   "$SOURCE/privacy/AllAppsInteraction.kt"   "$SOURCE/privacy/AllAppsPermissionChips.kt"   "$ROOT/tests/titan2/q25-nextbuild/Q25PortablePoliciesSmoke.kt"   -include-runtime -d "$OUT/q25-portable-smoke.jar"
java -jar "$OUT/q25-portable-smoke.jar"
