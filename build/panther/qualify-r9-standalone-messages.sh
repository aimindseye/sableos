#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT/build/config/r8-host-tools.env"

EXPECTED_SOURCE_COMMIT="${EXPECTED_SOURCE_COMMIT:-$(git -C "$ROOT" rev-parse HEAD)}"

[[ "$EXPECTED_SOURCE_COMMIT" =~ ^[0-9a-f]{40}$ ]] || {
  echo "R9_STANDALONE_MESSAGES_QUALIFICATION=FAIL_SOURCE_FORMAT"
  exit 64
}

ACTUAL_SOURCE="$(git -C "$ROOT" rev-parse HEAD)"
[[ "$ACTUAL_SOURCE" == "$EXPECTED_SOURCE_COMMIT" ]] || {
  echo "R9_STANDALONE_MESSAGES_QUALIFICATION=FAIL_SOURCE_BINDING expected=$EXPECTED_SOURCE_COMMIT actual=$ACTUAL_SOURCE"
  exit 65
}

if ! git -C "$ROOT" diff --quiet || ! git -C "$ROOT" diff --cached --quiet; then
  echo "R9_STANDALONE_MESSAGES_QUALIFICATION=FAIL_TRACKED_SOURCE_DIRTY"
  git -C "$ROOT" status --short
  exit 66
fi

echo "===== R9 STANDALONE MESSAGES QUALITY QUALIFICATION ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "WORKSPACE_OUTPUT_MUTATION_AUTHORIZED=YES_GRADLE_OUTPUT_ONLY"
echo "BUILD_AUTHORIZED=YES_MESSAGES_MODULE_ONLY"
echo "FULL_TARGET_FILES_BUILD_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "CLEAN_AUTHORIZED=NO"
echo "CLOBBER_AUTHORIZED=NO"
echo "SOURCE=$ACTUAL_SOURCE"

bash "$ROOT/build/host/verify-r8-host-tools.sh"
python3 "$ROOT/build/gates/r9-standalone-messages-quality-contract.py"

export ANDROID_HOME="$SABLE_ANDROID_SDK"
export ANDROID_SDK_ROOT="$SABLE_ANDROID_SDK"
export GRADLE_USER_HOME="$SABLE_GRADLE_USER_HOME"
export JAVA_HOME="$SABLE_JDK17"
export PATH="$JAVA_HOME/bin:$SABLE_ANDROID_SDK/platform-tools:$SABLE_ANDROID_SDK/cmdline-tools/latest/bin:$PATH"

test -d "$ANDROID_HOME/platforms/android-$SABLE_ANDROID_API" || {
  echo "R9_STANDALONE_MESSAGES_ANDROID_SDK=FAIL_PLATFORM"
  exit 68
}
test -d "$ANDROID_HOME/build-tools/$SABLE_ANDROID_BUILD_TOOLS_VERSION" || {
  echo "R9_STANDALONE_MESSAGES_ANDROID_SDK=FAIL_BUILD_TOOLS"
  exit 69
}
echo "R9_STANDALONE_MESSAGES_ANDROID_SDK=PASS"

cd "$ROOT/apps/r8/android"

echo
echo "===== R9 STANDALONE MESSAGES STATIC QUALITY ====="
./gradlew \
  --offline \
  --no-daemon \
  --dependency-verification=strict \
  :messages:detekt \
  :messages:ktlintCheck \
  --console=plain

echo "R9_STANDALONE_MESSAGES_DETEKT=PASS"
echo "R9_STANDALONE_MESSAGES_KTLINT=PASS"

echo
echo "===== R9 STANDALONE MESSAGES COMPILE TEST LINT ====="
./gradlew \
  --offline \
  --no-daemon \
  --dependency-verification=strict \
  :messages:compileDebugKotlin \
  :messages:testDebugUnitTest \
  :messages:lintDebug \
  --console=plain

echo "R9_STANDALONE_MESSAGES_COMPILE=PASS"
echo "R9_STANDALONE_MESSAGES_UNIT_TESTS=PASS"
echo "R9_STANDALONE_MESSAGES_LINT=PASS"

echo
echo "===== R9 STANDALONE MESSAGES APK ====="
./gradlew \
  --offline \
  --no-daemon \
  --dependency-verification=strict \
  :messages:assembleDebug \
  --console=plain

mapfile -t APKS < <(
  find "$ROOT/apps/r8/android/messages/build/outputs/apk" \
    -type f -name '*.apk' -print | sort
)

[[ "${#APKS[@]}" -eq 1 ]] || {
  echo "R9_STANDALONE_MESSAGES_APK=FAIL_COUNT count=${#APKS[@]}"
  printf '%s\n' "${APKS[@]}"
  exit 70
}

sha256sum "${APKS[0]}"
echo "R9_STANDALONE_MESSAGES_APK=PASS path=${APKS[0]}"
echo "R9_STANDALONE_MESSAGES_DEVICE_RUNTIME_VALIDATED=NO"
echo "R9_STANDALONE_MESSAGES_QUALIFICATION=PASS"
