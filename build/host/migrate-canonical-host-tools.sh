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

jdk_tree_valid() {
    local root="$1" major="$2" marker
    marker="$root/.sable-canonical-jdk.env"
    [[ -d "$root" && -x "$root/bin/java" && -f "$marker" ]] || return 1
    grep -Fxq "SABLE_CANONICAL_JDK=YES" "$marker" || return 1
    grep -Fxq "JAVA_MAJOR=$major" "$marker" || return 1
    "$root/bin/java" -version 2>&1 | head -n1 | grep -Eq "\"$major\\."
}

copy_jdk_transactional() {
    local src="$1" dst="$2" key="$3" major="$4"
    local parent base stage quarantine stamp marker java_sha

    if jdk_tree_valid "$dst" "$major"; then
        echo "$key=ALREADY_CANONICAL_VERIFIED path=$dst"
        return 0
    fi

    [[ -d "$src" ]] || {
        echo "$key=FAIL_SOURCE_MISSING path=$src"
        exit 3
    }
    [[ -x "$src/bin/java" ]] || {
        echo "$key=FAIL_SOURCE_JAVA_MISSING path=$src/bin/java"
        exit 3
    }
    "$src/bin/java" -version 2>&1 | head -n1 | grep -Eq "\"$major\\." || {
        echo "$key=FAIL_SOURCE_VERSION path=$src expected_major=$major"
        exit 3
    }

    parent="$(dirname "$dst")"
    base="$(basename "$dst")"
    mkdir -p "$parent"
    stage="$(mktemp -d "$parent/.${base}.stage.XXXXXX")"

    # Preserve symlinks exactly. Do not dereference optional links such as
    # lib/src.zip, which may legitimately point to an uninstalled source package.
    if ! cp -a --reflink=auto "$src/." "$stage/"; then
        echo "$key=FAIL_COPY stage=$stage"
        rm -rf --one-file-system -- "$stage"
        exit 4
    fi

    [[ -x "$stage/bin/java" ]] || {
        echo "$key=FAIL_STAGED_JAVA_MISSING stage=$stage"
        rm -rf --one-file-system -- "$stage"
        exit 4
    }
    "$stage/bin/java" -version 2>&1 | head -n1 | grep -Eq "\"$major\\." || {
        echo "$key=FAIL_STAGED_VERSION stage=$stage expected_major=$major"
        rm -rf --one-file-system -- "$stage"
        exit 4
    }

    java_sha="$(sha256sum "$stage/bin/java" | awk '{print $1}')"
    marker="$stage/.sable-canonical-jdk.env"
    {
        echo "SABLE_CANONICAL_JDK=YES"
        echo "JAVA_MAJOR=$major"
        echo "SOURCE_PATH=$src"
        echo "JAVA_SHA256=$java_sha"
    } > "$marker"

    jdk_tree_valid "$stage" "$major" || {
        echo "$key=FAIL_STAGED_VERIFICATION stage=$stage"
        rm -rf --one-file-system -- "$stage"
        exit 4
    }

    if [[ -e "$dst" || -L "$dst" ]]; then
        stamp="$(date -u +%Y%m%dT%H%M%SZ)"
        quarantine="$parent/.${base}.incomplete-$stamp"
        mv "$dst" "$quarantine"
        echo "$key=QUARANTINED_INCOMPLETE path=$quarantine"
    fi

    mv "$stage" "$dst"
    echo "$key=COPIED_VERIFIED destination=$dst"
}
copy_jdk_transactional "$LEGACY_JDK17" "$SABLE_JDK17" JDK17 17
copy_jdk_transactional "$LEGACY_JDK21" "$SABLE_JDK21" JDK21 21

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
