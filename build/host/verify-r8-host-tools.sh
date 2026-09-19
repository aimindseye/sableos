#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT/build/config/r8-host-tools.env"

fail() {
    echo "$1=FAIL"
    echo "R8_HOST_TOOLS=FAIL"
    exit "${2:-1}"
}

echo "===== R8 CANONICAL HOST-TOOL GATE ====="
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "HOST_TOOLS_ROOT=$SABLE_HOST_TOOLS_ROOT"
echo "ANDROID_SDK=$SABLE_ANDROID_SDK"
echo "RUSTUP_HOME=$SABLE_RUSTUP_HOME"
echo "CARGO_HOME=$SABLE_CARGO_HOME"
echo "GRADLE_USER_HOME=$SABLE_GRADLE_USER_HOME"

for path in     "$SABLE_ANDROID_SDK/platforms/android-$SABLE_ANDROID_API"     "$SABLE_ANDROID_SDK/build-tools/$SABLE_ANDROID_BUILD_TOOLS_VERSION"     "$SABLE_ANDROID_SDK/ndk/$SABLE_ANDROID_NDK_VERSION"     "$SABLE_GRADLE_USER_HOME"
do
    [[ -d "$path" ]] || fail R8_HOST_TOOL_PATH
done

for tool in     "$SABLE_SDKMANAGER"     "$SABLE_APKANALYZER"     "$SABLE_CARGO"     "$SABLE_RUSTC"     "$SABLE_RUSTUP"     "$SABLE_JDK17/bin/java"     "$SABLE_JDK21/bin/java"
do
    [[ -x "$tool" ]] || {
        echo "MISSING_EXECUTABLE=$tool"
        fail R8_HOST_EXECUTABLE
    }
done

grep -Fq "Pkg.Revision = $SABLE_ANDROID_NDK_VERSION"     "$SABLE_ANDROID_SDK/ndk/$SABLE_ANDROID_NDK_VERSION/source.properties"     || fail R8_NDK_VERSION

"$SABLE_RUSTC" --version | grep -Fq "rustc $SABLE_RUST_VERSION "     || fail R8_RUSTC_VERSION
"$SABLE_CARGO" --version | grep -Fq "cargo $SABLE_RUST_VERSION "     || fail R8_CARGO_VERSION

rust_target_lib="$SABLE_RUST_TOOLCHAIN_ROOT/lib/rustlib/$SABLE_RUST_TARGET/lib"
[[ -d "$rust_target_lib" ]] || {
    echo "MISSING_RUST_TARGET_LIB=$rust_target_lib"
    fail R8_RUST_ANDROID_TARGET
}

find "$rust_target_lib" -maxdepth 1 -type f -name 'libstd-*.rlib' -print -quit \
    | grep -q . \
    || fail R8_RUST_ANDROID_STD

"$SABLE_JDK17/bin/java" -version 2>&1 | head -n1 | grep -Eq '"17\.'     || fail R8_JDK17
"$SABLE_JDK21/bin/java" -version 2>&1 | head -n1 | grep -Eq '"21\.'     || fail R8_JDK21

echo "R8_ANDROID_API=PASS value=$SABLE_ANDROID_API"
echo "R8_ANDROID_BUILD_TOOLS=PASS value=$SABLE_ANDROID_BUILD_TOOLS_VERSION"
echo "R8_ANDROID_NDK=PASS value=$SABLE_ANDROID_NDK_VERSION"
echo "R8_RUST=PASS value=$SABLE_RUST_VERSION"
echo "R8_RUST_TARGET=PASS value=$SABLE_RUST_TARGET"
echo "R8_GRADLE_HOME=PASS"
echo "R8_JDK17=PASS"
echo "R8_JDK21=PASS"
echo "R8_HOST_TOOLS=PASS"
