#!/usr/bin/env bash

ROOT="${1:-.}"
FAILURES=0

say() {
  printf '%s\n' "$1"
}

pass() {
  say "$1=PASS"
}

fail() {
  say "$1=FAIL"
  FAILURES=$((FAILURES + 1))
}

require_file() {
  NAME="$1"
  PATH_VALUE="$2"
  if [ -f "$ROOT/$PATH_VALUE" ]; then
    pass "$NAME"
  else
    fail "$NAME"
    say "MISSING_PATH=$PATH_VALUE"
  fi
}

require_marker() {
  NAME="$1"
  PATH_VALUE="$2"
  MARKER="$3"
  if grep -Fq "$MARKER" "$ROOT/$PATH_VALUE" 2>/dev/null; then
    pass "$NAME"
  else
    fail "$NAME"
    say "MISSING_MARKER=$MARKER"
    say "IN_FILE=$PATH_VALUE"
  fi
}

say "===== N1B SABLE HOST TOOLCHAIN CONTRACT ====="
say "ROOT=$ROOT"
say "SOURCE_MUTATION_AUTHORIZED=NO"
say "BUILD_AUTHORIZED=NO"
say "IMAGE_BUILD_AUTHORIZED=NO"
say "DEVICE_CONTACT_AUTHORIZED=NO"
say "FLASH_AUTHORIZED=NO"
say "ADB_COMMANDS_RUN=NO"
say "FASTBOOT_COMMANDS_RUN=NO"
say "PUBLIC_RELEASE=NO"

ENV_SCRIPT="build/titan2/n1b-sable-host-toolchain-env.sh"
WRAPPER="build/titan2/qualify-n1b-stage-a-fast-lane-sable-host.sh"
SELF="build/gates/n1b-sable-host-toolchain-contract.sh"

require_file "N1B_SABLE_HOST_TOOLCHAIN_ENV_SCRIPT" "$ENV_SCRIPT"
require_file "N1B_SABLE_HOST_FAST_LANE_WRAPPER" "$WRAPPER"
require_file "N1B_SABLE_HOST_TOOLCHAIN_CONTRACT" "$SELF"

require_marker "ENV_ANDROID_SDK_ROOT" "$ENV_SCRIPT" \
  "/srv/data/sable-build/toolchains/r8-a2/android-sdk"
require_marker "ENV_SABLE_HOST_RUST_TOOLCHAIN" "$ENV_SCRIPT" \
  "/srv/data/sable-host-tools/rust/1.98.1/rustup/toolchains/1.98.1-x86_64-unknown-linux-gnu"
require_marker "ENV_RUST_TARGET" "$ENV_SCRIPT" \
  "aarch64-linux-android"
require_marker "ENV_EXPORT_ANDROID_HOME" "$ENV_SCRIPT" \
  "export ANDROID_HOME"
require_marker "ENV_EXPORT_SABLE_CARGO" "$ENV_SCRIPT" \
  "export SABLE_CARGO"
require_marker "ENV_EXPORT_SABLE_RUSTC" "$ENV_SCRIPT" \
  "export SABLE_RUSTC"
require_marker "ENV_RUST_TARGET_CHECK" "$ENV_SCRIPT" \
  "N1B_SABLE_HOST_RUST_TARGET_AARCH64_ANDROID"
require_marker "ENV_NO_DEVICE" "$ENV_SCRIPT" \
  "DEVICE_CONTACT_AUTHORIZED=NO"
require_marker "ENV_NO_FLASH" "$ENV_SCRIPT" \
  "FLASH_AUTHORIZED=NO"

require_marker "WRAPPER_SOURCES_ENV" "$WRAPPER" \
  "n1b-sable-host-toolchain-env.sh"
require_marker "WRAPPER_EXECUTES_FAST_LANE" "$WRAPPER" \
  "qualify-n1b-stage-a-fast-lane.sh"

if [ "$FAILURES" -eq 0 ]; then
  say "N1B_SABLE_HOST_TOOLCHAIN_CONTRACT=PASS"
  exit 0
fi

say "N1B_SABLE_HOST_TOOLCHAIN_CONTRACT=FAIL"
say "FAILURES=$FAILURES"
exit 1
