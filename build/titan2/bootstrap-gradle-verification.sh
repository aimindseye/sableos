#!/usr/bin/env bash
# ONE-TIME OPERATOR ACTION (online). Generates Gradle dependency-verification metadata for each Gradle graph of this repository:
#   apps/titan2/platform/gradle/verification-metadata.xml
#   apps/titan2/screens/gradle/verification-metadata.xml
# The generated files must be reviewed and committed to the same deliverable PR. Afterwards qualification is offline and strict.
# Refuses to run without --authorized-online-bootstrap. Never used by the developer lane or by --static/--full.
#   build/titan2/bootstrap-gradle-verification.sh --authorized-online-bootstrap [--keys]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
[[ "${1:-}" == "--authorized-online-bootstrap" ]] || { echo "BOOTSTRAP_REFUSED: pass --authorized-online-bootstrap (explicit operator authorization for network fetch)" >&2; exit 2; }
MODE="sha256"; [[ "${2:-}" == "--keys" ]] && MODE="sha256,pgp"

# Operator bootstrap must use the canonical qualified host SDK/JDK/Gradle cache.
# Git worktrees do not inherit local.properties, so bind the toolchain explicitly
# instead of allowing AGP to fail later with "SDK location not found".
CANONICAL_REPO="${CANONICAL_REPO:-/srv/sable-build/sableos/repo}"
HOST_TOOLS_ENV="${SABLE_HOST_TOOLS_ENV:-$CANONICAL_REPO/build/config/host-tools.env}"
[[ -r "$HOST_TOOLS_ENV" ]] || {
    echo "BOOTSTRAP_FAIL=HOST_TOOLS_ENV_MISSING path=$HOST_TOOLS_ENV" >&2
    exit 1
}
# shellcheck disable=SC1090
source "$HOST_TOOLS_ENV"

export ANDROID_HOME="$SABLE_ANDROID_SDK"
export ANDROID_SDK_ROOT="$SABLE_ANDROID_SDK"
export JAVA_HOME="$SABLE_JDK17"
export GRADLE_USER_HOME="$SABLE_GRADLE_USER_HOME"
export PATH="$JAVA_HOME/bin:$PATH"

[[ -d "$ANDROID_HOME" ]] || { echo "BOOTSTRAP_FAIL=ANDROID_SDK_MISSING path=$ANDROID_HOME" >&2; exit 1; }
[[ -x "$JAVA_HOME/bin/java" ]] || { echo "BOOTSTRAP_FAIL=JAVA_MISSING path=$JAVA_HOME/bin/java" >&2; exit 1; }
mkdir -p "$GRADLE_USER_HOME"

echo "C3B_PRODUCT_BOOTSTRAP_ANDROID_HOME=$ANDROID_HOME"
echo "C3B_PRODUCT_BOOTSTRAP_JAVA_HOME=$JAVA_HOME"
echo "C3B_PRODUCT_BOOTSTRAP_GRADLE_USER_HOME=$GRADLE_USER_HOME"
for ws in apps/titan2/platform apps/titan2/screens; do
    [[ -x "$ws/gradlew" ]] || { echo "BOOTSTRAP_FAIL=NO_GRADLEW $ws" >&2; exit 1; }
    ( cd "$ws" && ./gradlew --write-verification-metadata "$MODE" assembleRelease test lint detekt ktlintCheck --stacktrace --console=plain --no-daemon )
    [[ -s "$ws/gradle/verification-metadata.xml" ]] || { echo "BOOTSTRAP_FAIL=NO_METADATA $ws" >&2; exit 1; }
    echo "BOOTSTRAP_OK $ws/gradle/verification-metadata.xml"
done
echo "C3B_PRODUCT_DEPENDENCY_VERIFICATION_BOOTSTRAP=DONE_REVIEW_AND_COMMIT"
