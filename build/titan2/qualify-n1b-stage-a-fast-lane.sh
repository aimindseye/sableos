#!/usr/bin/env bash

REPO="${REPO:-$(pwd)}"
APP_ROOT="${APP_ROOT:-$REPO/apps/r8/android}"
EVIDENCE_DIR="${EVIDENCE_DIR:-$REPO/out/n1b-stage-a-fast-lane-evidence}"
RUN_GRADLE_BUILDS="${RUN_GRADLE_BUILDS:-YES}"
REQUIRE_SETUPWIZARD_SOURCE="${REQUIRE_SETUPWIZARD_SOURCE:-NO}"
SETUPWIZARD2_SOURCE="${SETUPWIZARD2_SOURCE:-}"

FAILURES=0
FIRST_FAILURE=""
ANDROID_SDK_READY=NO
ANDROID_HOME_EFFECTIVE=""

say() {
  printf '%s\n' "$1"
}

record_failure() {
  NAME="$1"
  DETAIL="$2"
  FAILURES=$((FAILURES + 1))
  if [ -z "$FIRST_FAILURE" ]; then
    FIRST_FAILURE="$NAME"
  fi
  say "$NAME=FAIL"
  say "$DETAIL"
}

pass() {
  say "$1=PASS"
}

warn() {
  say "$1=WARN"
}

require_file() {
  NAME="$1"
  PATH_VALUE="$2"
  if [ -f "$PATH_VALUE" ]; then
    pass "$NAME"
  else
    record_failure "$NAME" "MISSING_PATH=$PATH_VALUE"
  fi
}

sdk_candidate_valid() {
  CANDIDATE="$1"
  [ -n "$CANDIDATE" ] || return 1
  [ -d "$CANDIDATE" ] || return 1
  [ -d "$CANDIDATE/platforms" ] || return 1
  [ -d "$CANDIDATE/build-tools" ] || return 1
  return 0
}

local_properties_sdk_dir() {
  LOCAL_PROPERTIES="$APP_ROOT/local.properties"
  if [ ! -f "$LOCAL_PROPERTIES" ]; then
    return 1
  fi
  awk -F= '/^sdk\.dir=/{print substr($0, index($0, "=") + 1)}' \
    "$LOCAL_PROPERTIES" \
    | tail -1
}

resolve_android_sdk() {
  say "===== N1B STAGE A ANDROID SDK PREFLIGHT ====="

  if sdk_candidate_valid "${ANDROID_HOME:-}"; then
    ANDROID_HOME_EFFECTIVE="$ANDROID_HOME"
    export ANDROID_HOME="$ANDROID_HOME_EFFECTIVE"
    export ANDROID_SDK_ROOT="$ANDROID_HOME_EFFECTIVE"
    pass "N1B_STAGE_A_ANDROID_HOME"
    say "ANDROID_HOME_EFFECTIVE=$ANDROID_HOME_EFFECTIVE"
    ANDROID_SDK_READY=YES
    return 0
  fi

  if sdk_candidate_valid "${ANDROID_SDK_ROOT:-}"; then
    ANDROID_HOME_EFFECTIVE="$ANDROID_SDK_ROOT"
    export ANDROID_HOME="$ANDROID_HOME_EFFECTIVE"
    export ANDROID_SDK_ROOT="$ANDROID_HOME_EFFECTIVE"
    pass "N1B_STAGE_A_ANDROID_SDK_ROOT"
    say "ANDROID_HOME_EFFECTIVE=$ANDROID_HOME_EFFECTIVE"
    ANDROID_SDK_READY=YES
    return 0
  fi

  SDK_DIR_FROM_LOCAL="$(local_properties_sdk_dir 2>/dev/null || true)"
  if sdk_candidate_valid "$SDK_DIR_FROM_LOCAL"; then
    ANDROID_HOME_EFFECTIVE="$SDK_DIR_FROM_LOCAL"
    export ANDROID_HOME="$ANDROID_HOME_EFFECTIVE"
    export ANDROID_SDK_ROOT="$ANDROID_HOME_EFFECTIVE"
    pass "N1B_STAGE_A_LOCAL_PROPERTIES_SDK"
    say "ANDROID_HOME_EFFECTIVE=$ANDROID_HOME_EFFECTIVE"
    ANDROID_SDK_READY=YES
    return 0
  fi

  for CANDIDATE in \
    /srv/data/android-sdk \
    /srv/data/sable-build/android-sdk \
    /opt/android-sdk \
    "$HOME/Android/Sdk" \
    "$HOME/Library/Android/sdk"
  do
    if sdk_candidate_valid "$CANDIDATE"; then
      ANDROID_HOME_EFFECTIVE="$CANDIDATE"
      export ANDROID_HOME="$ANDROID_HOME_EFFECTIVE"
      export ANDROID_SDK_ROOT="$ANDROID_HOME_EFFECTIVE"
      pass "N1B_STAGE_A_ANDROID_SDK_AUTO_DETECTED"
      say "ANDROID_HOME_EFFECTIVE=$ANDROID_HOME_EFFECTIVE"
      ANDROID_SDK_READY=YES
      return 0
    fi
  done

  record_failure "N1B_STAGE_A_ANDROID_SDK" \
    "Define ANDROID_HOME, ANDROID_SDK_ROOT, or $APP_ROOT/local.properties sdk.dir before RUN_GRADLE_BUILDS=YES"
  say "N1B_STAGE_A_GRADLE_BUILDS=SKIPPED_ANDROID_SDK_PRECONDITION"
  ANDROID_SDK_READY=NO
  return 1
}

run_cmd() {
  NAME="$1"
  shift
  say "===== $NAME ====="
  say "COMMAND=$*"
  "$@"
  RC="$?"
  say "${NAME}_RC=$RC"
  if [ "$RC" -eq 0 ]; then
    pass "$NAME"
  else
    record_failure "$NAME" "FAILED_COMMAND=$*"
  fi
}

say "===== N1B STAGE A FAST-LANE DRIVER ====="
say "REPO=$REPO"
say "APP_ROOT=$APP_ROOT"
say "EVIDENCE_DIR=$EVIDENCE_DIR"
say "RUN_GRADLE_BUILDS=$RUN_GRADLE_BUILDS"
say "REQUIRE_SETUPWIZARD_SOURCE=$REQUIRE_SETUPWIZARD_SOURCE"
say "SOURCE_MUTATION_AUTHORIZED=NO"
say "BUILD_AUTHORIZED=YES_APPS_AND_STATIC_GATES_ONLY"
say "IMAGE_BUILD_AUTHORIZED=NO"
say "DEVICE_CONTACT_AUTHORIZED=NO"
say "FLASH_AUTHORIZED=NO"
say "ADB_COMMANDS_RUN=NO"
say "FASTBOOT_COMMANDS_RUN=NO"
say "PUBLIC_RELEASE=NO"
say "PRODUCTION_SIGNING=NO"

mkdir -p "$EVIDENCE_DIR" 2>/dev/null

require_file "N1B_STAGE_A_APP_ROOT_GRADLEW" "$APP_ROOT/gradlew"
require_file "N1B_STAGE_A_GRADLE_SETTINGS" "$APP_ROOT/settings.gradle.kts"

if [ -f "$APP_ROOT/settings.gradle.kts" ]; then
  for MODULE in \
    design \
    calculator \
    convert \
    games \
    media \
    hub \
    sablestart-presentation-check \
    sablestart-visual-review \
    weather \
    calendar
  do
    if grep -Fq "include(\":$MODULE\")" "$APP_ROOT/settings.gradle.kts"; then
      pass "N1B_STAGE_A_MODULE_${MODULE}_DECLARED"
    else
      record_failure "N1B_STAGE_A_MODULE_${MODULE}_DECLARED" \
        "MISSING_INCLUDE=include(\":$MODULE\")"
    fi
  done
fi

if [ -n "$SETUPWIZARD2_SOURCE" ]; then
  if [ -f "$SETUPWIZARD2_SOURCE/Android.bp" ] \
    && [ -f "$SETUPWIZARD2_SOURCE/AndroidManifest.xml" ]; then
    pass "GRAPHENEOS_SETUPWIZARD2_SOURCE_BOUND"
    say "GRAPHENEOS_SETUPWIZARD2_SOURCE=$SETUPWIZARD2_SOURCE"
  else
    record_failure "GRAPHENEOS_SETUPWIZARD2_SOURCE_BOUND" \
      "SETUPWIZARD2_SOURCE_MISSING_REQUIRED_FILES=$SETUPWIZARD2_SOURCE"
  fi
else
  say "GRAPHENEOS_SETUPWIZARD2_SOURCE_BOUND=NOT_PROVIDED"
  if [ "$REQUIRE_SETUPWIZARD_SOURCE" = "YES" ]; then
    record_failure "GRAPHENEOS_SETUPWIZARD2_SOURCE_REQUIRED" \
      "SETUPWIZARD2_SOURCE must point to GrapheneOS platform_packages_apps_SetupWizard2"
  fi
fi

if [ "$RUN_GRADLE_BUILDS" = "YES" ]; then
  resolve_android_sdk

  if [ "$ANDROID_SDK_READY" = "YES" ]; then
    if [ -x "$APP_ROOT/gradlew" ]; then
      cd "$APP_ROOT" || {
        record_failure "N1B_STAGE_A_APP_ROOT_CD" "CD_FAILED=$APP_ROOT"
      }

      if [ "$FAILURES" -eq 0 ]; then
        for MODULE in \
          design \
          calculator \
          convert \
          games \
          media \
          hub \
          sablestart-presentation-check \
          sablestart-visual-review \
          weather \
          calendar
        do
          run_cmd "N1B_STAGE_A_BUILD_${MODULE}" ./gradlew ":$MODULE:assembleDebug"
        done
      fi
    else
      record_failure "N1B_STAGE_A_GRADLEW_EXECUTABLE" \
        "gradlew is missing or not executable at $APP_ROOT/gradlew"
    fi
  fi
else
  say "N1B_STAGE_A_GRADLE_BUILDS=SKIPPED_BY_REQUEST"
fi

say "===== N1B STAGE A FAST-LANE RESULT ====="
say "FAILURES=$FAILURES"
if [ -n "$FIRST_FAILURE" ]; then
  say "FIRST_FAILURE=$FIRST_FAILURE"
fi

if [ "$FAILURES" -eq 0 ]; then
  say "N1B_STAGE_A_FAST_LANE=PASS"
  exit 0
fi

say "N1B_STAGE_A_FAST_LANE=FAIL"
exit 1
