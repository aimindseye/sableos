#!/usr/bin/env bash

# Source this file before Titan 2 N1B app-build qualification, or use
# qualify-n1b-stage-a-fast-lane-sable-host.sh. It binds the known-good
# Sable host Android SDK and Rust toolchain proven on ai-g732.
#
# Guardrails:
# - no source mutation
# - no SDK or Rust installation
# - no image build
# - no device contact
# - no flash

SABLE_HOST_ANDROID_SDK_DEFAULT="/srv/data/sable-build/toolchains/r8-a2/android-sdk"
SABLE_HOST_RUST_TOOLCHAIN_DEFAULT="/srv/data/sable-host-tools/rust/1.98.1/rustup/toolchains/1.98.1-x86_64-unknown-linux-gnu"
SABLE_HOST_RUST_TARGET="aarch64-linux-android"

sable_n1b_say() {
  printf '%s\n' "$1"
}

sable_n1b_require_dir() {
  NAME="$1"
  PATH_VALUE="$2"
  if [ -d "$PATH_VALUE" ]; then
    sable_n1b_say "$NAME=PASS"
    return 0
  fi

  sable_n1b_say "$NAME=FAIL"
  sable_n1b_say "MISSING_DIR=$PATH_VALUE"
  return 1
}

sable_n1b_require_executable() {
  NAME="$1"
  PATH_VALUE="$2"
  if [ -x "$PATH_VALUE" ]; then
    sable_n1b_say "$NAME=PASS"
    return 0
  fi

  sable_n1b_say "$NAME=FAIL"
  sable_n1b_say "MISSING_EXECUTABLE=$PATH_VALUE"
  return 1
}

sable_n1b_prepend_path() {
  PATH_VALUE="$1"
  if [ -z "$PATH_VALUE" ] || [ ! -d "$PATH_VALUE" ]; then
    return 0
  fi

  case ":$PATH:" in
    *":$PATH_VALUE:"*) ;;
    *) PATH="$PATH_VALUE:$PATH" ;;
  esac
  export PATH
}

sable_n1b_export_host_toolchain() {
  sable_n1b_say "===== N1B SABLE HOST TOOLCHAIN ENV ====="
  sable_n1b_say "SOURCE_MUTATION_AUTHORIZED=NO"
  sable_n1b_say "BUILD_AUTHORIZED=ENV_ONLY"
  sable_n1b_say "IMAGE_BUILD_AUTHORIZED=NO"
  sable_n1b_say "DEVICE_CONTACT_AUTHORIZED=NO"
  sable_n1b_say "FLASH_AUTHORIZED=NO"
  sable_n1b_say "ADB_COMMANDS_RUN=NO"
  sable_n1b_say "FASTBOOT_COMMANDS_RUN=NO"
  sable_n1b_say "PUBLIC_RELEASE=NO"

  if ! sable_n1b_require_dir \
    "N1B_SABLE_HOST_ANDROID_SDK" \
    "$SABLE_HOST_ANDROID_SDK_DEFAULT"; then
    return 1
  fi

  if ! sable_n1b_require_dir \
    "N1B_SABLE_HOST_ANDROID_SDK_PLATFORMS" \
    "$SABLE_HOST_ANDROID_SDK_DEFAULT/platforms"; then
    return 1
  fi

  if ! sable_n1b_require_dir \
    "N1B_SABLE_HOST_ANDROID_SDK_BUILD_TOOLS" \
    "$SABLE_HOST_ANDROID_SDK_DEFAULT/build-tools"; then
    return 1
  fi

  CARGO_PATH="$SABLE_HOST_RUST_TOOLCHAIN_DEFAULT/bin/cargo"
  RUSTC_PATH="$SABLE_HOST_RUST_TOOLCHAIN_DEFAULT/bin/rustc"
  RUST_TARGET_LIB="$SABLE_HOST_RUST_TOOLCHAIN_DEFAULT/lib/rustlib/$SABLE_HOST_RUST_TARGET/lib"

  if ! sable_n1b_require_executable \
    "N1B_SABLE_HOST_CARGO" \
    "$CARGO_PATH"; then
    return 1
  fi

  if ! sable_n1b_require_executable \
    "N1B_SABLE_HOST_RUSTC" \
    "$RUSTC_PATH"; then
    return 1
  fi

  if ! sable_n1b_require_dir \
    "N1B_SABLE_HOST_RUST_TARGET_AARCH64_ANDROID" \
    "$RUST_TARGET_LIB"; then
    return 1
  fi

  export ANDROID_HOME="$SABLE_HOST_ANDROID_SDK_DEFAULT"
  export ANDROID_SDK_ROOT="$ANDROID_HOME"
  export SABLE_CARGO="$CARGO_PATH"
  export CARGO="$SABLE_CARGO"
  export SABLE_RUSTC="$RUSTC_PATH"
  export RUSTC="$SABLE_RUSTC"
  sable_n1b_prepend_path "$SABLE_HOST_RUST_TOOLCHAIN_DEFAULT/bin"

  sable_n1b_say "ANDROID_HOME=$ANDROID_HOME"
  sable_n1b_say "ANDROID_SDK_ROOT=$ANDROID_SDK_ROOT"
  sable_n1b_say "SABLE_CARGO=$SABLE_CARGO"
  sable_n1b_say "SABLE_RUSTC=$SABLE_RUSTC"
  sable_n1b_say "N1B_SABLE_HOST_TOOLCHAIN_ENV=PASS"
}

sable_n1b_export_host_toolchain
