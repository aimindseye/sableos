#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT/build/config/r8-host-tools.env"

EXPECTED_SOURCE_COMMIT="${EXPECTED_SOURCE_COMMIT:-$(git -C "$ROOT" rev-parse HEAD)}"
QUALIFIED_BASE="bf86db4bcf66507f566c64d5673a0e27369102e2"

[[ "$EXPECTED_SOURCE_COMMIT" =~ ^[0-9a-f]{40}$ ]] || {
  echo "R9_MESSAGES_FOCUSED_QUALIFICATION=FAIL_SOURCE_FORMAT"
  exit 64
}

ACTUAL_SOURCE="$(git -C "$ROOT" rev-parse HEAD)"
[[ "$ACTUAL_SOURCE" == "$EXPECTED_SOURCE_COMMIT" ]] || {
  echo "R9_MESSAGES_FOCUSED_QUALIFICATION=FAIL_SOURCE_BINDING expected=$EXPECTED_SOURCE_COMMIT actual=$ACTUAL_SOURCE"
  exit 65
}

if ! git -C "$ROOT" diff --quiet || ! git -C "$ROOT" diff --cached --quiet; then
  echo "R9_MESSAGES_FOCUSED_QUALIFICATION=FAIL_TRACKED_SOURCE_DIRTY"
  git -C "$ROOT" status --short
  exit 66
fi

git -C "$ROOT" merge-base --is-ancestor "$QUALIFIED_BASE" "$ACTUAL_SOURCE" || {
  echo "R9_MESSAGES_FOCUSED_QUALIFICATION=FAIL_BASE_ANCESTRY"
  exit 67
}

echo "===== R9 MESSAGES LOCAL-CONVERSATION FOCUSED QUALIFICATION ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "WORKSPACE_OUTPUT_MUTATION_AUTHORIZED=YES_GRADLE_OUTPUT_ONLY"
echo "BUILD_AUTHORIZED=YES_HUB_MODULE_ONLY"
echo "FULL_TARGET_FILES_BUILD_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "CLEAN_AUTHORIZED=NO"
echo "CLOBBER_AUTHORIZED=NO"
echo "SOURCE=$ACTUAL_SOURCE"
echo "QUALIFIED_BASE=$QUALIFIED_BASE"

bash "$ROOT/build/host/verify-r8-host-tools.sh"

export ANDROID_HOME="$SABLE_ANDROID_SDK"
export ANDROID_SDK_ROOT="$SABLE_ANDROID_SDK"
export GRADLE_USER_HOME="$SABLE_GRADLE_USER_HOME"
export JAVA_HOME="$SABLE_JDK17"
export PATH="$JAVA_HOME/bin:$SABLE_ANDROID_SDK/platform-tools:$SABLE_ANDROID_SDK/cmdline-tools/latest/bin:$PATH"

echo "ANDROID_HOME=$ANDROID_HOME"
echo "ANDROID_SDK_ROOT=$ANDROID_SDK_ROOT"
echo "GRADLE_USER_HOME=$GRADLE_USER_HOME"
echo "JAVA_HOME=$JAVA_HOME"

test -d "$ANDROID_HOME/platforms/android-$SABLE_ANDROID_API" || {
  echo "R9_MESSAGES_ANDROID_SDK=FAIL_PLATFORM"
  exit 68
}
test -d "$ANDROID_HOME/build-tools/$SABLE_ANDROID_BUILD_TOOLS_VERSION" || {
  echo "R9_MESSAGES_ANDROID_SDK=FAIL_BUILD_TOOLS"
  exit 69
}
echo "R9_MESSAGES_ANDROID_SDK=PASS"

python3 "$ROOT/build/gates/r9-messages-native-first-contract.py"
python3 "$ROOT/build/gates/r9-messages-local-conversation-contract.py"
python3 "$ROOT/build/gates/r9-sms-mms-blocking-contract.py"
bash "$ROOT/build/gates/sable-pipeline-contract.sh"

echo
echo "===== R9 MESSAGES STATIC QUALITY PREFLIGHT ====="

cd "$ROOT/apps/r8/android"

./gradlew \
  --offline \
  :hub:detekt \
  :hub:ktlintCheck \
  --stacktrace \
  --console=plain \
  --no-daemon

echo "R9_MESSAGES_STATIC_QUALITY_PREFLIGHT=PASS"

echo
echo "===== R9 MESSAGES COMPILE TEST LINT ====="

./gradlew \
  --offline \
  :hub:compileDebugKotlin \
  :hub:testDebugUnitTest \
  :hub:lintDebug \
  --stacktrace \
  --console=plain \
  --no-daemon

echo "R9_MESSAGES_COMPILE=PASS"
echo "R9_MESSAGES_UNIT_TESTS=PASS"
echo "R9_MESSAGES_LINT=PASS"

echo
echo "===== R9 MESSAGES APK ASSEMBLY ====="

./gradlew \
  --offline \
  :hub:assembleDebug \
  --stacktrace \
  --console=plain \
  --no-daemon

APK="$ROOT/apps/r8/android/hub/build/outputs/apk/debug/hub-debug.apk"
test -f "$APK" || {
  echo "R9_MESSAGES_APK=FAIL_MISSING"
  exit 70
}

sha256sum "$APK"
echo "R9_MESSAGES_APK=PASS path=$APK"
echo "R9_MESSAGES_DETEKT=PASS"
echo "R9_MESSAGES_KTLINT=PASS"
echo "R9_MESSAGES_WARNINGS_AS_ERRORS=PASS"
echo "R9_MESSAGES_LOCAL_CONVERSATION_QUALIFICATION=PASS"
echo "R9_MESSAGES_FOCUSED_QUALIFICATION=PASS"
