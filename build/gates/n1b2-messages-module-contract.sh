#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_ROOT="$ROOT/apps/r8/android"
MODULE_DIR="$APP_ROOT/messages"
PLATFORM_SABLE_ROOT="${PLATFORM_SABLE_ROOT:-/srv/data/sable-build/platform_sable}"
HOST_TOOLS_ENV="$ROOT/build/config/r8-host-tools.env"
BUILD_MODE="NO"

usage() {
  cat <<'USAGE'
usage:
  bash build/gates/n1b2-messages-module-contract.sh [--build YES|NO]

Restored Sable Messages module gate. This gate validates the module against the
existing Hub/Messages reference, platform_sable Messages UX, visual confirmation
checklist, and source-controlled Titan2 Messages/Hub visual artifacts without
Android image builds, Soong builds, device contact, adb, fastboot, flash, public
release, or production signing.
USAGE
}

while (($#)); do
  case "$1" in
    --build) BUILD_MODE="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "N1B2_MESSAGES_MODULE=FAIL_UNKNOWN_ARG arg=$1"; usage; exit 64 ;;
  esac
done

case "$BUILD_MODE" in
  YES|NO) ;;
  *) echo "N1B2_MESSAGES_MODULE=FAIL_BAD_BUILD_MODE value=$BUILD_MODE"; exit 64 ;;
esac

passes=0
warnings=0
failures=0

emit() {
  local status="$1"
  local key="$2"
  local detail="${3:-}"

  printf '%s=%s' "$key" "$status"
  [[ -z "$detail" ]] || printf ' %s' "$detail"
  printf '\n'

  case "$status" in
    PASS) passes=$((passes + 1)) ;;
    FAIL) failures=$((failures + 1)) ;;
    *) warnings=$((warnings + 1)) ;;
  esac
}

require_file() {
  local key="$1"
  local path="$2"

  [[ -f "$path" ]] \
    && emit PASS "$key" "path=$path" \
    || emit FAIL "$key" "missing=$path"
}

require_dir() {
  local key="$1"
  local path="$2"

  [[ -d "$path" ]] \
    && emit PASS "$key" "path=$path" \
    || emit FAIL "$key" "missing=$path"
}

require_text() {
  local key="$1"
  local pattern="$2"
  local path="$3"

  grep -Fq "$pattern" "$path" \
    && emit PASS "$key" "pattern=$pattern path=$path" \
    || emit FAIL "$key" "missing_pattern=$pattern path=$path"
}

forbid_text() {
  local key="$1"
  local pattern="$2"
  local path="$3"

  if grep -Fq "$pattern" "$path"; then
    emit FAIL "$key" "forbidden_pattern=$pattern path=$path"
  else
    emit PASS "$key" "absent=$pattern path=$path"
  fi
}

source_canonical_host_tools() {
  require_file N1B2_CANONICAL_HOST_TOOLS_ENV_PRESENT "$HOST_TOOLS_ENV"
  (( failures == 0 )) || {
    echo "N1B2_MESSAGES_MODULE_BUILD=FAIL_HOST_TOOLS_ENV"
    exit 1
  }

  # shellcheck source=/dev/null
  source "$HOST_TOOLS_ENV"
  emit PASS N1B2_CANONICAL_HOST_TOOLS_ENV_SOURCED "path=$HOST_TOOLS_ENV"

  export ANDROID_SDK_ROOT="$SABLE_ANDROID_SDK"
  export ANDROID_HOME="$SABLE_ANDROID_SDK"
  export GRADLE_USER_HOME="$SABLE_GRADLE_USER_HOME"
  export CARGO_HOME="$SABLE_CARGO_HOME"
  export RUSTUP_HOME="$SABLE_RUSTUP_HOME"
  export JAVA_HOME="$SABLE_JDK17"
  export PATH="$JAVA_HOME/bin:$SABLE_ANDROID_SDK/platform-tools:$SABLE_ANDROID_SDK/build-tools/$SABLE_ANDROID_BUILD_TOOLS_VERSION:$SABLE_ANDROID_SDK/cmdline-tools/latest/bin:$SABLE_CARGO_HOME/bin:$SABLE_RUST_TOOLCHAIN_ROOT/bin:$PATH"

  require_dir N1B2_CANONICAL_ANDROID_SDK "$ANDROID_SDK_ROOT"
  require_dir N1B2_CANONICAL_GRADLE_USER_HOME "$GRADLE_USER_HOME"
  require_dir N1B2_CANONICAL_CARGO_HOME "$CARGO_HOME"
  require_dir N1B2_CANONICAL_RUSTUP_HOME "$RUSTUP_HOME"
  require_dir N1B2_CANONICAL_JAVA_HOME "$JAVA_HOME"
  require_file N1B2_CANONICAL_CARGO "$SABLE_CARGO"
  require_file N1B2_CANONICAL_RUSTC "$SABLE_RUSTC"

  if (( failures == 0 )); then
    emit PASS N1B2_CANONICAL_BUILD_ENV_READY "sdk=$ANDROID_SDK_ROOT"
  else
    echo "N1B2_MESSAGES_MODULE_BUILD=FAIL_CANONICAL_BUILD_ENV"
    exit 1
  fi
}

manifest="$MODULE_DIR/src/main/AndroidManifest.xml"
activity="$MODULE_DIR/src/main/java/org/sableos/messages/MainActivity.kt"
ux_doc="$PLATFORM_SABLE_ROOT/docs/design/MESSAGES_CONVERSATION_UX.md"
visual_doc="$PLATFORM_SABLE_ROOT/docs/design/MESSAGES_CONVERSATION_VISUAL_CONFIRMATION.md"
messages_svg="$PLATFORM_SABLE_ROOT/docs/design/artifacts/sable-messages-conversation-titan2.svg"
hub_svg="$PLATFORM_SABLE_ROOT/docs/design/artifacts/sable-hub-titan2.svg"

cat <<EOF
===== N1B2 MESSAGES MODULE CONTRACT =====
ROOT=$ROOT
APP_ROOT=$APP_ROOT
MODULE_DIR=$MODULE_DIR
PLATFORM_SABLE_ROOT=$PLATFORM_SABLE_ROOT
BUILD_MODE=$BUILD_MODE
DEVICE_CONTACT_AUTHORIZED=NO
ADB_COMMANDS_RUN=NO
FASTBOOT_COMMANDS_RUN=NO
BUILD_AUTHORIZED=$([[ "$BUILD_MODE" == YES ]] && echo YES_GRADLE_APK_ONLY || echo NO)
IMAGE_BUILD_AUTHORIZED=NO
SOONG_BUILD_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
FACTORY_RESET_AUTHORIZED=NO
PUBLIC_RELEASE=NO
PRODUCTION_SIGNING=NO
EOF

require_file N1B2_MESSAGES_RESTORATION_DOC_PRESENT \
  "$ROOT/docs/titan2/N1B2_MESSAGES_RESTORATION.md"
require_file N1B2_APP_RESTORATION_REFERENCE_PRESENT \
  "$ROOT/docs/titan2/N1B2_APP_RESTORATION_REFERENCE.tsv"
require_file N1B2_EXISTING_APK_INVENTORY_PRESENT \
  "$ROOT/docs/titan2/N1B2_EXISTING_APK_INVENTORY.tsv"
require_dir N1B2_MESSAGES_HUB_REFERENCE_PRESENT "$APP_ROOT/hub"
require_dir N1B2_PLATFORM_SABLE_ROOT_PRESENT "$PLATFORM_SABLE_ROOT"
require_file N1B2_PLATFORM_SABLE_APP_REUSE_PRESENT \
  "$PLATFORM_SABLE_ROOT/docs/SABLE_APP_REUSE_AND_INTEGRATION_PLAN.md"
require_file N1B2_PLATFORM_SABLE_MESSAGES_UX_PRESENT "$ux_doc"
require_file N1B2_PLATFORM_SABLE_MESSAGES_VISUAL_CONFIRMATION_PRESENT \
  "$visual_doc"
require_file N1B2_PLATFORM_SABLE_MESSAGES_ARTIFACT_PRESENT "$messages_svg"
require_file N1B2_PLATFORM_SABLE_HUB_ARTIFACT_PRESENT "$hub_svg"
require_file N1B2_PANTHER_NO_REGRESSION_GATE_PRESENT \
  "$ROOT/build/gates/n1b2-panther-no-regression-contract.sh"

require_dir N1B2_MESSAGES_MODULE_DIR_PRESENT "$MODULE_DIR"
require_file N1B2_MESSAGES_BUILD_GRADLE_PRESENT "$MODULE_DIR/build.gradle.kts"
require_file N1B2_MESSAGES_MANIFEST_PRESENT "$manifest"
require_file N1B2_MESSAGES_MAIN_ACTIVITY_PRESENT "$activity"
require_file N1B2_MESSAGES_ICON_PRESENT \
  "$MODULE_DIR/src/main/res/drawable/ic_sable_messages.xml"

require_text N1B2_MESSAGES_SETTINGS_INCLUDE 'include(":messages")' \
  "$APP_ROOT/settings.gradle.kts"
require_text N1B2_MESSAGES_INVENTORY_ROW $'messages\trestored_product_apk' \
  "$ROOT/docs/titan2/N1B2_EXISTING_APK_INVENTORY.tsv"
require_text N1B2_MESSAGES_APP_ID 'applicationId = "org.sableos.messages"' \
  "$MODULE_DIR/build.gradle.kts"
require_text N1B2_MESSAGES_DESIGN_DEPENDENCY 'implementation(project(":design"))' \
  "$MODULE_DIR/build.gradle.kts"
require_text N1B2_MESSAGES_LABEL 'android:label="Sable Messages"' "$manifest"
require_text N1B2_MESSAGES_PROVIDER_HANDOFF_QUERY \
  'android.intent.action.SENDTO' "$manifest"
require_text N1B2_MESSAGES_PROVIDER_HANDOFF_SCHEME 'android:scheme="smsto"' \
  "$manifest"
require_text N1B2_MESSAGES_INTENT_HANDOFF 'Intent.ACTION_SENDTO' "$activity"
require_text N1B2_MESSAGES_SMSTO_HANDOFF 'smsto:' "$activity"

require_text N1B2_MESSAGES_UX_LATEST_REQUIREMENT \
  'LATEST_MESSAGE_ALWAYS_VISIBLE=YES' "$ux_doc"
require_text N1B2_MESSAGES_UX_CUSTOM_STACK_EXCLUSION \
  'CUSTOM_SMS_STACK=NO' "$ux_doc"
require_text N1B2_MESSAGES_VISUAL_ARTIFACT_BINDING \
  'sable-messages-conversation-titan2.svg' "$visual_doc"
require_text N1B2_MESSAGES_VISUAL_LATEST_REQUIREMENT \
  'LATEST_MESSAGE_ALWAYS_VISIBLE=PASS' "$visual_doc"
require_text N1B2_MESSAGES_ARTIFACT_TITLE \
  'Sable Messages / Conversation UX for Titan 2' "$messages_svg"
require_text N1B2_MESSAGES_ARTIFACT_LATEST_VISIBLE \
  'Latest message is always visible' "$messages_svg"
require_text N1B2_MESSAGES_ARTIFACT_HISTORY_INDICATOR \
  'New message' "$messages_svg"
require_text N1B2_HUB_ARTIFACT_MESSAGES_REFERENCE \
  'Sable Hub — Keyboard-First Communications UX' "$hub_svg"

require_text N1B2_MESSAGES_UI_VISUAL_TARGET \
  'Titan 2 visual target' "$activity"
require_text N1B2_MESSAGES_UI_SQUARE_KEYBOARD \
  'square display + physical keyboard' "$activity"
require_text N1B2_MESSAGES_UI_LATEST_VISIBLE \
  'LATEST_MESSAGE_ALWAYS_VISIBLE' "$activity"
require_text N1B2_MESSAGES_UI_HISTORY_INDICATOR \
  'New message — Enter to latest' "$activity"
require_text N1B2_MESSAGES_UI_CONVERSATION_LIST \
  'Conversation list · latest first' "$activity"
require_text N1B2_MESSAGES_UI_HUB_REFERENCE \
  'Hub handoff compatible' "$activity"
require_text N1B2_MESSAGES_UI_ONSCREEN_FALLBACK \
  'Onscreen keyboard fallback' "$activity"
require_text N1B2_MESSAGES_UI_PRIVACY_REDACTION \
  'Message body hidden when locked' "$activity"
require_text N1B2_MESSAGES_UI_NO_CUSTOM_STACK \
  'custom SMS/RCS/MMS stack: no' "$activity"

for forbidden in \
  'android.permission.READ_SMS' \
  'android.permission.SEND_SMS' \
  'android.permission.RECEIVE_SMS'; do
  forbid_text N1B2_MESSAGES_NO_SMS_PERMISSION_TAKEOVER "$forbidden" "$manifest"
done

if (( failures == 0 )); then
  echo "N1B2_MESSAGES_MODULE_PASSES=$passes"
  echo "N1B2_MESSAGES_MODULE_WARNINGS=$warnings"
  echo "N1B2_MESSAGES_MODULE_FAILURES=$failures"
  echo "N1B2_MESSAGES_MODULE=PASS"
else
  echo "N1B2_MESSAGES_MODULE_PASSES=$passes"
  echo "N1B2_MESSAGES_MODULE_WARNINGS=$warnings"
  echo "N1B2_MESSAGES_MODULE_FAILURES=$failures"
  echo "N1B2_MESSAGES_MODULE=FAIL failures=$failures"
  exit 1
fi

if [[ "$BUILD_MODE" == NO ]]; then
  echo "N1B2_MESSAGES_MODULE_BUILD=NOT_RUN use=--build YES"
  exit 0
fi

source_canonical_host_tools
(
  cd "$APP_ROOT"
  ./gradlew --no-daemon :messages:assembleDebug
)

shopt -s nullglob
apks=("$MODULE_DIR"/build/outputs/apk/debug/*.apk)
shopt -u nullglob

if ((${#apks[@]} > 0)); then
  emit PASS N1B2_MESSAGES_APK_OUTPUT "count=${#apks[@]} first=${apks[0]}"
else
  emit FAIL N1B2_MESSAGES_APK_OUTPUT \
    "missing_glob=$MODULE_DIR/build/outputs/apk/debug/*.apk"
fi

if (( failures == 0 )); then
  echo "N1B2_MESSAGES_MODULE_BUILD=PASS"
  exit 0
fi

echo "N1B2_MESSAGES_MODULE_BUILD=FAIL failures=$failures"
exit 1
