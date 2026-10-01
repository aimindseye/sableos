#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/build/config/host-tools.env"

PROFILE="${1:-core}"
case "$PROFILE" in
    core|aosp-host|all) ;;
    *) echo "SABLE_HOST_TOOLS=FAIL_PROFILE value=$PROFILE"; exit 64 ;;
esac

fail() {
    echo "$1=FAIL${2:+ $2}"
    echo "SABLE_HOST_TOOLS=FAIL"
    exit 1
}

require_dir() {
    local key="$1" path="$2"
    [[ -d "$path" ]] || fail "$key" "path=$path"
}

require_exe() {
    local key="$1" path="$2"
    [[ -x "$path" ]] || fail "$key" "path=$path"
}

echo "===== SABLEOS CANONICAL HOST-TOOL GATE ====="
echo "PROFILE=$PROFILE"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "HOST_TOOLS_ROOT=$SABLE_HOST_TOOLS_ROOT"
echo "ANDROID_SDK=$SABLE_ANDROID_SDK"
echo "AOSP_HOST_TOOLS_ROOT=$SABLE_AOSP_HOST_TOOLS_ROOT"
echo "JAVA_TOOLS_ROOT=$SABLE_JAVA_TOOLS_ROOT"
echo "RUST_ROOT=$SABLE_RUST_ROOT"
echo "GRADLE_USER_HOME=$SABLE_GRADLE_USER_HOME"
echo "SECURITY_TOOLS_ROOT=$SABLE_SECURITY_TOOLS_ROOT"
echo "REPO_TOOL=$SABLE_REPO_TOOL"

case "$SABLE_ANDROID_SDK:$SABLE_AOSP_HOST_TOOLS_ROOT:$SABLE_JAVA_TOOLS_ROOT" in
    *'/r8/'*|*'/r9/'*|*'/n0/'*|*'/n1'*|*'titan2-'*|*'panther-'*)
        fail SABLE_HOST_TOOL_LAYOUT "build_or_release_specific_path"
        ;;
esac

if [[ "$PROFILE" == core || "$PROFILE" == all ]]; then
    require_dir SABLE_ANDROID_SDK_PATH "$SABLE_ANDROID_SDK"
    require_dir SABLE_ANDROID_PLATFORM_TOOLS_PATH "$SABLE_ANDROID_PLATFORM_TOOLS"
    require_dir SABLE_ANDROID_BUILD_TOOLS_PATH "$SABLE_ANDROID_BUILD_TOOLS"
    require_dir SABLE_ANDROID_NDK_PATH "$SABLE_ANDROID_NDK"
    require_dir SABLE_GRADLE_HOME_PATH "$SABLE_GRADLE_USER_HOME"
    require_dir SABLE_RUST_TOOLCHAIN_PATH "$SABLE_RUST_TOOLCHAIN_ROOT"
    require_dir SABLE_SECURITY_BIN_PATH "$SABLE_SECURITY_BIN"
    require_dir SABLE_JDK17_PATH "$SABLE_JDK17"
    require_dir SABLE_JDK21_PATH "$SABLE_JDK21"

    require_exe SABLE_REPO_TOOL_EXECUTABLE "$SABLE_REPO_TOOL"
    require_exe SABLE_ADB_EXECUTABLE "$SABLE_ADB"
    require_exe SABLE_FASTBOOT_EXECUTABLE "$SABLE_FASTBOOT"
    require_exe SABLE_SDKMANAGER_EXECUTABLE "$SABLE_SDKMANAGER"
    require_exe SABLE_APKANALYZER_EXECUTABLE "$SABLE_APKANALYZER"
    require_exe SABLE_CARGO_EXECUTABLE "$SABLE_CARGO"
    require_exe SABLE_RUSTC_EXECUTABLE "$SABLE_RUSTC"
    require_exe SABLE_RUSTUP_EXECUTABLE "$SABLE_RUSTUP"
    require_exe SABLE_JDK17_JAVA_EXECUTABLE "$SABLE_JDK17/bin/java"
    require_exe SABLE_JDK21_JAVA_EXECUTABLE "$SABLE_JDK21/bin/java"
    require_exe SABLE_PYTHON_EXECUTABLE "$SABLE_PYTHON"

    echo "SABLE_HOST_TOOLS_CORE=PASS"
fi

if [[ "$PROFILE" == aosp-host || "$PROFILE" == all ]]; then
    require_dir SABLE_AOSP_HOST_BIN_PATH "$SABLE_AOSP_HOST_BIN"
    require_dir SABLE_AOSP_HOST_LIB64_PATH "$SABLE_AOSP_HOST_LIB64"

    require_exe SABLE_LPDUMP_EXECUTABLE "$SABLE_LPDUMP"
    require_exe SABLE_LPUNPACK_EXECUTABLE "$SABLE_LPUNPACK"
    require_exe SABLE_LPMAKE_EXECUTABLE "$SABLE_LPMAKE"
    require_exe SABLE_SIMG2IMG_EXECUTABLE "$SABLE_SIMG2IMG"
    require_exe SABLE_AVBTOOL_EXECUTABLE "$SABLE_AVBTOOL"
    require_exe SABLE_CHECKVINTF_EXECUTABLE "$SABLE_CHECKVINTF"
    require_exe SABLE_SECILC_EXECUTABLE "$SABLE_SECILC"
    require_exe SABLE_UNPACK_BOOTIMG_EXECUTABLE "$SABLE_UNPACK_BOOTIMG"

    LD_LIBRARY_PATH="$SABLE_AOSP_HOST_LIBRARY_PATH" "$SABLE_LPDUMP" --help >/dev/null 2>&1 || {
        rc=$?
        [[ "$rc" == 64 ]] || fail SABLE_LPDUMP_RUNTIME "rc=$rc"
    }
    LD_LIBRARY_PATH="$SABLE_AOSP_HOST_LIBRARY_PATH" "$SABLE_LPUNPACK" --help >/dev/null 2>&1 || {
        rc=$?
        [[ "$rc" == 64 ]] || fail SABLE_LPUNPACK_RUNTIME "rc=$rc"
    }

    echo "SABLE_HOST_TOOLS_AOSP_HOST=PASS"
fi

echo "SABLE_HOST_TOOLS=PASS"
