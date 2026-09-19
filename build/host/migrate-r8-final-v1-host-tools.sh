#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT/build/config/r8-host-tools.env"

HOST_TOOL_MIGRATION_AUTHORIZED="${HOST_TOOL_MIGRATION_AUTHORIZED:-NO}"
LEGACY_ROOT="${LEGACY_ROOT:-/srv/data/sable-build/host-tools/r8-final-v1}"
LEGACY_GRADLE_HOME="${LEGACY_GRADLE_HOME:-$HOME/.gradle}"

if [[ "$HOST_TOOL_MIGRATION_AUTHORIZED" != YES ]]; then
    echo "R8_HOST_TOOL_MIGRATION=REFUSED_NOT_AUTHORIZED"
    exit 2
fi

echo "===== R8 HOST-TOOL CENTRALIZATION ====="
echo "HOST_TOOL_MIGRATION_AUTHORIZED=YES"
echo "BUILD_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "LEGACY_ROOT=$LEGACY_ROOT"
echo "LEGACY_GRADLE_HOME=$LEGACY_GRADLE_HOME"
echo "DEST_ROOT=$SABLE_HOST_TOOLS_ROOT"

legacy_sdk="$LEGACY_ROOT/android-sdk"
legacy_cargo="$LEGACY_ROOT/cargo"
legacy_rustup="$LEGACY_ROOT/rustup"

mkdir -p     "$SABLE_HOST_TOOLS_ROOT/android/r8"     "$SABLE_HOST_TOOLS_ROOT/rust/$SABLE_RUST_VERSION"

move_once() {
    local src="$1"
    local dst="$2"
    local name="$3"

    if [[ -d "$dst" ]]; then
        echo "$name=ALREADY_CENTRAL"
        return 0
    fi

    [[ -d "$src" ]] || {
        echo "$name=FAIL_SOURCE_MISSING path=$src"
        exit 3
    }

    mv "$src" "$dst"
    echo "$name=MOVED destination=$dst"
}

move_once "$legacy_sdk" "$SABLE_ANDROID_SDK" R8_ANDROID_SDK
move_once "$legacy_cargo" "$SABLE_CARGO_HOME" R8_CARGO_HOME
move_once "$legacy_rustup" "$SABLE_RUSTUP_HOME" R8_RUSTUP_HOME

if [[ ! -d "$SABLE_GRADLE_USER_HOME" ]]; then
    if [[ -d "$LEGACY_GRADLE_HOME" && ! -L "$LEGACY_GRADLE_HOME" ]]; then
        mv "$LEGACY_GRADLE_HOME" "$SABLE_GRADLE_USER_HOME"
        echo "R8_GRADLE_HOME=MOVED destination=$SABLE_GRADLE_USER_HOME"
    else
        mkdir -p "$SABLE_GRADLE_USER_HOME"
        echo "R8_GRADLE_HOME=CREATED destination=$SABLE_GRADLE_USER_HOME"
    fi
else
    echo "R8_GRADLE_HOME=ALREADY_CENTRAL"
fi

# Compatibility links preserve old evidence/scripts while all canonical build
# entry points use /srv/data/sable-host-tools directly.
mkdir -p "$LEGACY_ROOT"
[[ -e "$legacy_sdk" ]] || ln -s "$SABLE_ANDROID_SDK" "$legacy_sdk"
[[ -e "$legacy_cargo" ]] || ln -s "$SABLE_CARGO_HOME" "$legacy_cargo"
[[ -e "$legacy_rustup" ]] || ln -s "$SABLE_RUSTUP_HOME" "$legacy_rustup"
[[ -e "$LEGACY_GRADLE_HOME" ]] || ln -s "$SABLE_GRADLE_USER_HOME" "$LEGACY_GRADLE_HOME"

bash "$ROOT/build/host/verify-r8-host-tools.sh"

echo "R8_HOST_TOOL_MIGRATION=PASS"
echo "CANONICAL_ROOT=$SABLE_HOST_TOOLS_ROOT"
