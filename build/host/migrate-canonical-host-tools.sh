#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/build/config/host-tools.env"

HOST_TOOL_MIGRATION_AUTHORIZED="${HOST_TOOL_MIGRATION_AUTHORIZED:-NO}"
LEGACY_ANDROID_SDK="${LEGACY_ANDROID_SDK:-$SABLE_HOST_TOOLS_ROOT/android/r8/sdk}"
LEGACY_JDK17="${LEGACY_JDK17:-/usr/lib/jvm/java-17-openjdk-amd64}"
LEGACY_JDK21="${LEGACY_JDK21:-/usr/lib/jvm/java-21-openjdk-amd64}"
LEGACY_REPO_TOOL="${LEGACY_REPO_TOOL:-}"

if [[ "$HOST_TOOL_MIGRATION_AUTHORIZED" != YES ]]; then
    echo "SABLE_HOST_TOOL_MIGRATION=REFUSED_NOT_AUTHORIZED"
    exit 2
fi

if [[ -z "$LEGACY_REPO_TOOL" ]]; then
    echo "SABLE_HOST_TOOL_MIGRATION=FAIL_LEGACY_REPO_TOOL_REQUIRED"
    echo "Set LEGACY_REPO_TOOL to the existing repo executable path."
    exit 64
fi

cat <<EOF
===== SABLEOS CANONICAL HOST-TOOL MIGRATION =====
HOST_TOOL_MIGRATION_AUTHORIZED=YES
BUILD_AUTHORIZED=NO
NETWORK_FETCH_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
DEST_ROOT=$SABLE_HOST_TOOLS_ROOT
LEGACY_ANDROID_SDK=$LEGACY_ANDROID_SDK
LEGACY_JDK17=$LEGACY_JDK17
LEGACY_JDK21=$LEGACY_JDK21
LEGACY_REPO_TOOL=$LEGACY_REPO_TOOL
EOF

mkdir -p "$SABLE_ANDROID_TOOLS_ROOT" "$SABLE_JAVA_TOOLS_ROOT" "$SABLE_REPO_TOOLS_ROOT"

if [[ -d "$SABLE_ANDROID_SDK" ]]; then
    echo "ANDROID_SDK=ALREADY_CANONICAL path=$SABLE_ANDROID_SDK"
else
    [[ -d "$LEGACY_ANDROID_SDK" ]] || {
        echo "ANDROID_SDK=FAIL_SOURCE_MISSING path=$LEGACY_ANDROID_SDK"
        exit 3
    }
    mv "$LEGACY_ANDROID_SDK" "$SABLE_ANDROID_SDK"
    echo "ANDROID_SDK=MOVED destination=$SABLE_ANDROID_SDK"
fi

copy_tree_once() {
    local src="$1" dst="$2" key="$3"
    if [[ -d "$dst" ]]; then
        echo "$key=ALREADY_CANONICAL path=$dst"
        return 0
    fi
    [[ -d "$src" ]] || {
        echo "$key=FAIL_SOURCE_MISSING path=$src"
        exit 3
    }
    mkdir -p "$(dirname "$dst")"
    cp -aL --reflink=auto "$src" "$dst"
    echo "$key=COPIED destination=$dst"
}

copy_tree_once "$LEGACY_JDK17" "$SABLE_JDK17" JDK17
copy_tree_once "$LEGACY_JDK21" "$SABLE_JDK21" JDK21

if [[ -x "$SABLE_REPO_TOOL" ]]; then
    echo "REPO_TOOL=ALREADY_CANONICAL path=$SABLE_REPO_TOOL"
else
    [[ -x "$LEGACY_REPO_TOOL" ]] || {
        echo "REPO_TOOL=FAIL_SOURCE_MISSING path=$LEGACY_REPO_TOOL"
        exit 3
    }
    install -m 0755 "$LEGACY_REPO_TOOL" "$SABLE_REPO_TOOL"
    echo "REPO_TOOL=COPIED destination=$SABLE_REPO_TOOL"
fi

legacy_r8_root="$SABLE_HOST_TOOLS_ROOT/android/r8"
if [[ -d "$legacy_r8_root" ]]; then
    rmdir "$legacy_r8_root" 2>/dev/null         && echo "LEGACY_ANDROID_R8_ROOT=REMOVED_EMPTY"         || echo "LEGACY_ANDROID_R8_ROOT=RETAINED_NONEMPTY path=$legacy_r8_root"
fi

bash "$ROOT/build/host/verify-host-tools.sh" core

echo "SABLE_HOST_TOOL_MIGRATION=PASS"
