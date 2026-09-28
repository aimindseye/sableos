#!/usr/bin/env bash

REPO="${REPO:-$(pwd)}"
APP_ROOT="${APP_ROOT:-$REPO/apps/r8/android}"
EVIDENCE_DIR="${EVIDENCE_DIR:-$REPO/out/n1b-stage-a-fast-lane-evidence}"
RUN_GRADLE_BUILDS="${RUN_GRADLE_BUILDS:-YES}"
REQUIRE_SETUPWIZARD_SOURCE="${REQUIRE_SETUPWIZARD_SOURCE:-NO}"
SETUPWIZARD2_SOURCE="${SETUPWIZARD2_SOURCE:-}"
N1A_EVIDENCE_DIR="${N1A_EVIDENCE_DIR:-}"

FAILURES=0
FIRST_FAILURE=""
ANDROID_SDK_READY=NO
ANDROID_HOME_EFFECTIVE=""
RUST_TOOLCHAIN_READY=NO
SABLE_CARGO_EFFECTIVE=""
SABLE_RUSTC_EFFECTIVE=""

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

require_file() {
  NAME="$1"
  PATH_VALUE="$2"
  if [ -f "$PATH_VALUE" ]; then
    pass "$NAME"
  else
    record_failure "$NAME" "MISSING_PATH=$PATH_VALUE"
  fi
}

sdk_candidate_status() {
  CANDIDATE="$1"
  if [ -z "$CANDIDATE" ]; then
    printf '%s\n' "UNSET"
    return 1
  fi
  if [ ! -d "$CANDIDATE" ]; then
    printf '%s\n' "MISSING_DIR"
    return 1
  fi

  MISSING=""
  if [ ! -d "$CANDIDATE/platforms" ]; then
    MISSING="${MISSING}platforms,"
  fi
  if [ ! -d "$CANDIDATE/build-tools" ]; then
    MISSING="${MISSING}build-tools,"
  fi

  if [ -n "$MISSING" ]; then
    printf '%s\n' "MISSING_${MISSING%,}"
    return 1
  fi

  printf '%s\n' "PASS"
  return 0
}

try_sdk_candidate() {
  LABEL="$1"
  CANDIDATE="$2"
  STATUS="$(sdk_candidate_status "$CANDIDATE")"

  say "N1B_STAGE_A_SDK_CANDIDATE_${LABEL}_PATH=${CANDIDATE:-UNSET}"
  say "N1B_STAGE_A_SDK_CANDIDATE_${LABEL}=$STATUS"

  if [ "$STATUS" = "PASS" ]; then
    ANDROID_HOME_EFFECTIVE="$CANDIDATE"
    export ANDROID_HOME="$ANDROID_HOME_EFFECTIVE"
    export ANDROID_SDK_ROOT="$ANDROID_HOME_EFFECTIVE"
    say "ANDROID_HOME_EFFECTIVE=$ANDROID_HOME_EFFECTIVE"
    ANDROID_SDK_READY=YES
    return 0
  fi

  return 1
}

executable_candidate_status() {
  CANDIDATE="$1"
  if [ -z "$CANDIDATE" ]; then
    printf '%s\n' "UNSET"
    return 1
  fi
  if [ ! -e "$CANDIDATE" ]; then
    printf '%s\n' "MISSING_FILE"
    return 1
  fi
  if [ ! -x "$CANDIDATE" ]; then
    printf '%s\n' "NOT_EXECUTABLE"
    return 1
  fi

  printf '%s\n' "PASS"
  return 0
}

prepend_toolchain_bin() {
  BIN_DIR="$1"
  if [ -z "$BIN_DIR" ] || [ ! -d "$BIN_DIR" ]; then
    return 0
  fi
  case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) PATH="$BIN_DIR:$PATH" ;;
  esac
  export PATH
  say "N1B_STAGE_A_RUST_TOOLCHAIN_PATH_PREPENDED=$BIN_DIR"
}

try_cargo_candidate() {
  LABEL="$1"
  CANDIDATE="$2"
  STATUS="$(executable_candidate_status "$CANDIDATE")"

  say "N1B_STAGE_A_CARGO_CANDIDATE_${LABEL}_PATH=${CANDIDATE:-UNSET}"
  say "N1B_STAGE_A_CARGO_CANDIDATE_${LABEL}=$STATUS"

  if [ "$STATUS" = "PASS" ]; then
    SABLE_CARGO_EFFECTIVE="$CANDIDATE"
    export SABLE_CARGO="$SABLE_CARGO_EFFECTIVE"
    export CARGO="$SABLE_CARGO_EFFECTIVE"
    prepend_toolchain_bin "$(dirname "$SABLE_CARGO_EFFECTIVE")"
    say "SABLE_CARGO_EFFECTIVE=$SABLE_CARGO_EFFECTIVE"
    return 0
  fi

  return 1
}

try_rustc_candidate() {
  LABEL="$1"
  CANDIDATE="$2"
  STATUS="$(executable_candidate_status "$CANDIDATE")"

  say "N1B_STAGE_A_RUSTC_CANDIDATE_${LABEL}_PATH=${CANDIDATE:-UNSET}"
  say "N1B_STAGE_A_RUSTC_CANDIDATE_${LABEL}=$STATUS"

  if [ "$STATUS" = "PASS" ]; then
    SABLE_RUSTC_EFFECTIVE="$CANDIDATE"
    export SABLE_RUSTC="$SABLE_RUSTC_EFFECTIVE"
    export RUSTC="$SABLE_RUSTC_EFFECTIVE"
    prepend_toolchain_bin "$(dirname "$SABLE_RUSTC_EFFECTIVE")"
    say "SABLE_RUSTC_EFFECTIVE=$SABLE_RUSTC_EFFECTIVE"
    return 0
  fi

  return 1
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

n1a_result_file() {
  if [ -z "$N1A_EVIDENCE_DIR" ] || [ ! -d "$N1A_EVIDENCE_DIR" ]; then
    return 1
  fi
  find "$N1A_EVIDENCE_DIR" \
    -maxdepth 1 \
    -type f \
    \( -name '*result*.txt' -o -name '99-*.txt' \) \
    -print \
    | sort \
    | tail -1
}

n1a_result_field() {
  KEY="$1"
  RESULT_FILE="$2"
  if [ -z "$RESULT_FILE" ] || [ ! -f "$RESULT_FILE" ]; then
    return 1
  fi
  awk -F= -v key="$KEY" '$1 == key {print substr($0, index($0, "=") + 1)}' \
    "$RESULT_FILE" \
    | tail -1
}

probe_n1a_sdk_candidates() {
  RESULT_FILE="$(n1a_result_file 2>/dev/null || true)"
  if [ -z "$RESULT_FILE" ]; then
    say "N1B_STAGE_A_N1A_EVIDENCE_BOUND=NO"
    return 1
  fi

  say "N1B_STAGE_A_N1A_EVIDENCE_BOUND=YES"
  say "N1B_STAGE_A_N1A_RESULT_FILE=$RESULT_FILE"
  say "N1B_STAGE_A_N1A_BUILD_ENVIRONMENT_NOTE=AOSP_Soong_build_success_does_not_imply_standalone_Gradle_SDK"

  SRC_DIR_FROM_N1A="$(n1a_result_field SRC_DIR "$RESULT_FILE" 2>/dev/null || true)"
  R7_ROOT_FROM_N1A="$(n1a_result_field R7_ROOT "$RESULT_FILE" 2>/dev/null || true)"
  OUT_DIR_FROM_N1A="$(n1a_result_field OUT_DIR "$RESULT_FILE" 2>/dev/null || true)"

  [ -n "$SRC_DIR_FROM_N1A" ] && say "N1B_STAGE_A_N1A_SRC_DIR=$SRC_DIR_FROM_N1A"
  [ -n "$R7_ROOT_FROM_N1A" ] && say "N1B_STAGE_A_N1A_R7_ROOT=$R7_ROOT_FROM_N1A"
  [ -n "$OUT_DIR_FROM_N1A" ] && say "N1B_STAGE_A_N1A_OUT_DIR=$OUT_DIR_FROM_N1A"

  if try_sdk_candidate "N1A_SRC_PREBUILTS_SDK" "$SRC_DIR_FROM_N1A/prebuilts/sdk"; then
    return 0
  fi
  if try_sdk_candidate "N1A_SRC_PREBUILTS_FULLSDK" "$SRC_DIR_FROM_N1A/prebuilts/fullsdk/linux"; then
    return 0
  fi
  if try_sdk_candidate "N1A_OUT_HOST_SDK" "$OUT_DIR_FROM_N1A/host/linux-x86/sdk"; then
    return 0
  fi
  if try_sdk_candidate "N1A_R7_ROOT_ANDROID_SDK" "$R7_ROOT_FROM_N1A/android-sdk"; then
    return 0
  fi

  return 1
}

resolve_android_sdk() {
  say "===== N1B STAGE A ANDROID SDK PREFLIGHT ====="

  if try_sdk_candidate "ANDROID_HOME" "${ANDROID_HOME:-}"; then
    return 0
  fi
  if try_sdk_candidate "ANDROID_SDK_ROOT" "${ANDROID_SDK_ROOT:-}"; then
    return 0
  fi

  SDK_DIR_FROM_LOCAL="$(local_properties_sdk_dir 2>/dev/null || true)"
  if try_sdk_candidate "LOCAL_PROPERTIES" "$SDK_DIR_FROM_LOCAL"; then
    return 0
  fi

  if [ -n "$N1A_EVIDENCE_DIR" ]; then
    say "N1B_STAGE_A_N1A_EVIDENCE_DIR=$N1A_EVIDENCE_DIR"
    if probe_n1a_sdk_candidates; then
      return 0
    fi
  else
    say "N1B_STAGE_A_N1A_EVIDENCE_BOUND=NO"
  fi

  for CANDIDATE_ENTRY in \
    "SABLE_R8_A2_TOOLCHAIN_ANDROID_SDK=/srv/data/sable-build/toolchains/r8-a2/android-sdk" \
    "SABLE_HOST_TOOLS_R8_ANDROID_SDK=/srv/data/sable-host-tools/android/r8/sdk" \
    "SRV_DATA_ANDROID_SDK=/srv/data/android-sdk" \
    "SABLE_BUILD_ANDROID_SDK=/srv/data/sable-build/android-sdk" \
    "OPT_ANDROID_SDK=/opt/android-sdk" \
    "HOME_ANDROID_SDK=$HOME/Android/Sdk" \
    "HOME_LIBRARY_ANDROID_SDK=$HOME/Library/Android/sdk"
  do
    LABEL="${CANDIDATE_ENTRY%%=*}"
    CANDIDATE="${CANDIDATE_ENTRY#*=}"
    if try_sdk_candidate "$LABEL" "$CANDIDATE"; then
      return 0
    fi
  done

  say "N1B_STAGE_A_ANDROID_SDK_FAILURE_CLASS=GRADLE_SDK_PRECONDITION"
  record_failure "N1B_STAGE_A_ANDROID_SDK" \
    "No standalone Android SDK with platforms/ and build-tools/ was found; N1A AOSP/Soong build evidence is not sufficient for Gradle app builds"
  say "N1B_STAGE_A_GRADLE_BUILDS=SKIPPED_ANDROID_SDK_PRECONDITION"
  ANDROID_SDK_READY=NO
  return 1
}

resolve_rust_toolchain() {
  say "===== N1B STAGE A RUST TOOLCHAIN PREFLIGHT ====="

  if ! try_cargo_candidate "SABLE_CARGO" "${SABLE_CARGO:-}" &&
    ! try_cargo_candidate "CARGO" "${CARGO:-}" &&
    ! try_cargo_candidate "SABLE_CARGO_HOME" "${SABLE_CARGO_HOME:-}/bin/cargo" &&
    ! try_cargo_candidate "CARGO_HOME" "${CARGO_HOME:-}/bin/cargo" &&
    ! try_cargo_candidate "PATH" "$(command -v cargo 2>/dev/null || true)"
  then
    for CANDIDATE_ENTRY in \
      "HOME_CARGO=$HOME/.cargo/bin/cargo" \
      "SABLE_RUSTUP_1_98_1=$HOME/.rustup/toolchains/1.98.1-x86_64-unknown-linux-gnu/bin/cargo" \
      "SABLE_R8_A2_TOOLCHAIN_RUST=/srv/data/sable-build/toolchains/r8-a2/rust/bin/cargo" \
      "SABLE_HOST_TOOLS_R8_RUST=/srv/data/sable-host-tools/rust/r8/bin/cargo" \
      "USR_LOCAL_CARGO=/usr/local/bin/cargo" \
      "USR_BIN_CARGO=/usr/bin/cargo"
    do
      LABEL="${CANDIDATE_ENTRY%%=*}"
      CANDIDATE="${CANDIDATE_ENTRY#*=}"
      if try_cargo_candidate "$LABEL" "$CANDIDATE"; then
        break
      fi
    done
  fi

  if [ -z "$SABLE_CARGO_EFFECTIVE" ]; then
    say "N1B_STAGE_A_RUST_CARGO_FAILURE_CLASS=RUST_JNI_PRECONDITION"
    record_failure "N1B_STAGE_A_RUST_CARGO" \
      "No cargo executable was found for Rust JNI modules; set SABLE_CARGO, CARGO, SABLE_CARGO_HOME, or CARGO_HOME"
    say "N1B_STAGE_A_RUST_MODULE_BUILDS=SKIPPED_RUST_CARGO_PRECONDITION"
    RUST_TOOLCHAIN_READY=NO
    return 1
  fi

  CARGO_BIN_DIR="$(dirname "$SABLE_CARGO_EFFECTIVE")"
  if ! try_rustc_candidate "SABLE_RUSTC" "${SABLE_RUSTC:-}" &&
    ! try_rustc_candidate "RUSTC" "${RUSTC:-}" &&
    ! try_rustc_candidate "CARGO_SIBLING" "$CARGO_BIN_DIR/rustc" &&
    ! try_rustc_candidate "PATH" "$(command -v rustc 2>/dev/null || true)"
  then
    say "N1B_STAGE_A_RUSTC_FAILURE_CLASS=RUST_JNI_PRECONDITION"
    record_failure "N1B_STAGE_A_RUSTC" \
      "Cargo was found, but matching rustc was not executable; set SABLE_RUSTC or RUSTC, or ensure rustc is beside cargo"
    say "N1B_STAGE_A_RUST_MODULE_BUILDS=SKIPPED_RUSTC_PRECONDITION"
    RUST_TOOLCHAIN_READY=NO
    return 1
  fi

  "$SABLE_RUSTC_EFFECTIVE" -vV >/dev/null 2>&1 || {
    say "N1B_STAGE_A_RUSTC_FAILURE_CLASS=RUSTC_EXECUTION_PRECONDITION"
    record_failure "N1B_STAGE_A_RUSTC_EXECUTION" \
      "rustc exists but failed to execute: $SABLE_RUSTC_EFFECTIVE"
    say "N1B_STAGE_A_RUST_MODULE_BUILDS=SKIPPED_RUSTC_PRECONDITION"
    RUST_TOOLCHAIN_READY=NO
    return 1
  }

  pass "N1B_STAGE_A_RUST_TOOLCHAIN"
  RUST_TOOLCHAIN_READY=YES
  return 0
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
say "N1A_EVIDENCE_DIR=${N1A_EVIDENCE_DIR:-NOT_PROVIDED}"
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
    resolve_rust_toolchain
  fi

  if [ "$ANDROID_SDK_READY" = "YES" ] && [ "$RUST_TOOLCHAIN_READY" = "YES" ]; then
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
