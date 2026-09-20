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
echo "SECURITY_TOOLS_ROOT=$SABLE_SECURITY_TOOLS_ROOT"
echo "SECURITY_BIN=$SABLE_SECURITY_BIN"
echo "MOBSFSCAN_ROOT=$SABLE_MOBSFSCAN_ROOT"

for path in     "$SABLE_ANDROID_SDK/platforms/android-$SABLE_ANDROID_API"     "$SABLE_ANDROID_SDK/build-tools/$SABLE_ANDROID_BUILD_TOOLS_VERSION"     "$SABLE_ANDROID_SDK/ndk/$SABLE_ANDROID_NDK_VERSION"     "$SABLE_GRADLE_USER_HOME"
do
    [[ -d "$path" ]] || fail R8_HOST_TOOL_PATH
done

for tool in     "$SABLE_SDKMANAGER"     "$SABLE_APKANALYZER"     "$SABLE_CARGO"     "$SABLE_RUSTC"     "$SABLE_RUSTUP"     "$SABLE_JDK17/bin/java"     "$SABLE_JDK21/bin/java"     "$SABLE_PYTHON"     "$SABLE_MOBSFSCAN"
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

installed_components="$("$SABLE_RUSTUP" component list --installed --toolchain "$SABLE_RUST_TOOLCHAIN")"
grep -Eq '^llvm-tools(-|$)' <<<"$installed_components" || fail R8_RUST_LLVM_TOOLS
grep -Eq '^rust-src($|-)' <<<"$installed_components" || fail R8_RUST_SRC

llvm_bin="$SABLE_RUST_TOOLCHAIN_ROOT/lib/rustlib/$SABLE_RUST_HOST/bin"
[[ -x "$llvm_bin/llvm-cov" ]] || fail R8_RUST_LLVM_COV_BINARY
[[ -x "$llvm_bin/llvm-profdata" ]] || fail R8_RUST_LLVM_PROFDATA_BINARY

rust_src_root="$SABLE_RUST_TOOLCHAIN_ROOT/lib/rustlib/src/rust/library"
[[ -d "$rust_src_root" ]] || fail R8_RUST_SRC_TREE

python3 "$ROOT/build/install-pinned-tool.py" --verify-dir "$SABLE_SECURITY_BIN" \
    || fail R8_SECURITY_PINNED_TOOLS

[[ -d "$SABLE_MOBSFSCAN_SOURCE/.git" ]] || fail R8_MOBSFSCAN_SOURCE
[[ "$(git -C "$SABLE_MOBSFSCAN_SOURCE" rev-parse HEAD 2>/dev/null || true)" == "$SABLE_MOBSFSCAN_COMMIT" ]] \
    || fail R8_MOBSFSCAN_COMMIT
"$SABLE_MOBSFSCAN" --version 2>&1 | grep -Fq "$SABLE_MOBSFSCAN_VERSION" \
    || fail R8_MOBSFSCAN_VERSION

"$SABLE_JDK17/bin/java" -version 2>&1 | head -n1 | grep -Eq '"17\.'     || fail R8_JDK17
"$SABLE_JDK21/bin/java" -version 2>&1 | head -n1 | grep -Eq '"21\.'     || fail R8_JDK21

echo "R8_ANDROID_API=PASS value=$SABLE_ANDROID_API"
echo "R8_ANDROID_BUILD_TOOLS=PASS value=$SABLE_ANDROID_BUILD_TOOLS_VERSION"
echo "R8_ANDROID_NDK=PASS value=$SABLE_ANDROID_NDK_VERSION"
echo "R8_RUST=PASS value=$SABLE_RUST_VERSION"
echo "R8_RUST_TARGET=PASS value=$SABLE_RUST_TARGET"
echo "R8_RUST_LLVM_TOOLS=PASS path=$llvm_bin"
echo "R8_RUST_SRC=PASS path=$rust_src_root"
echo "R8_SECURITY_PINNED_TOOLS=PASS"
echo "R8_MOBSFSCAN=PASS commit=$SABLE_MOBSFSCAN_COMMIT version=$SABLE_MOBSFSCAN_VERSION"
echo "R8_GRADLE_HOME=PASS"
echo "R8_JDK17=PASS"
echo "R8_JDK21=PASS"
echo "R8_HOST_TOOLS=PASS"
