#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$ROOT/build/config/r8-host-tools.env"
source "$ROOT/build/config/r8-release.env"
source "$ROOT/apps/r8/textreader/upstream.env"

EXPECTED_SOURCE_COMMIT="${EXPECTED_SOURCE_COMMIT:-$(git -C "$ROOT" rev-parse HEAD)}"
[[ "$EXPECTED_SOURCE_COMMIT" =~ ^[0-9a-f]{40}$ ]] || {
    echo "R9_TEXT_READER_QUALIFICATION=FAIL_SOURCE_FORMAT"
    exit 64
}

ACTUAL_SOURCE="$(git -C "$ROOT" rev-parse HEAD)"
[[ "$ACTUAL_SOURCE" == "$EXPECTED_SOURCE_COMMIT" ]] || {
    echo "R9_TEXT_READER_QUALIFICATION=FAIL_SOURCE_BINDING expected=$EXPECTED_SOURCE_COMMIT actual=$ACTUAL_SOURCE"
    exit 65
}

if ! git -C "$ROOT" diff --quiet || ! git -C "$ROOT" diff --cached --quiet; then
    echo "R9_TEXT_READER_QUALIFICATION=FAIL_TRACKED_SOURCE_DIRTY"
    git -C "$ROOT" status --short
    exit 66
fi

echo "===== R9 SABLE TEXT READER FOCUSED QUALIFICATION ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO_REPOSITORY"
echo "TEMP_CHECKOUT_MUTATION_AUTHORIZED=YES"
echo "BUILD_AUTHORIZED=YES_TEXT_READER_ONLY"
echo "FULL_TARGET_FILES_BUILD_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "WORKSPACE_PRODUCT_INVENTORY_REQUIRED=NO_PRESTAGING"
echo "EXPECTED_SOURCE_COMMIT=$EXPECTED_SOURCE_COMMIT"

python3 "$ROOT/build/gates/r9-textreader-standalone-contract.py"
python3 "$ROOT/build/gates/r9-system-cohesion-contract.py"
python3 "$ROOT/build/gates/r9-physical-ux-closure-contract.py"
R8_NO_STALE_WORKSPACE_INVENTORY_REQUIRED=NO \
    bash "$ROOT/build/gates/r8-no-stale-product-code.sh"

[[ -d "$SABLE_R8_TEXTREADER_CACHE/.git" ]] || {
    echo "R9_TEXT_READER_CACHE=FAIL_MISSING path=$SABLE_R8_TEXTREADER_CACHE"
    exit 67
}
actual_pin="$(git -C "$SABLE_R8_TEXTREADER_CACHE" rev-parse HEAD)"
[[ "$actual_pin" == "$VAACHAK_TEXTREADER_COMMIT" ]] || {
    echo "R9_TEXT_READER_CACHE=FAIL_PIN expected=$VAACHAK_TEXTREADER_COMMIT actual=$actual_pin"
    exit 68
}
echo "R9_TEXT_READER_CACHE=PASS_PINNED"

WORK="$(mktemp -d -t sable-textreader-qual-XXXXXXXX)"
trap 'rm -rf --one-file-system -- "$WORK"' EXIT

git clone --no-hardlinks "$SABLE_R8_TEXTREADER_CACHE" "$WORK/textreader"
git -C "$WORK/textreader" checkout --detach "$VAACHAK_TEXTREADER_COMMIT"
git -C "$WORK/textreader" reset --hard "$VAACHAK_TEXTREADER_COMMIT"
git -C "$WORK/textreader" clean -ffd

python3 "$ROOT/apps/r8/textreader/apply_sable_flavor.py" "$WORK/textreader"
python3 "$ROOT/apps/r8/textreader/verify_sable_textreader.py" "$WORK/textreader"

export JAVA_HOME="$SABLE_JDK17"
export ANDROID_HOME="$SABLE_ANDROID_SDK"
export ANDROID_SDK_ROOT="$SABLE_ANDROID_SDK"
export GRADLE_USER_HOME="$SABLE_GRADLE_USER_HOME"
export PATH="$JAVA_HOME/bin:$PATH"

(
    cd "$WORK/textreader"
    chmod +x gradlew
    ./gradlew \
        --offline \
        testDebugUnitTest \
        lintDebug \
        assembleDebug \
        --stacktrace \
        --console=plain \
        --no-daemon \
        --no-configuration-cache
)

mapfile -t apks < <(
    find "$WORK/textreader/app/build/outputs/apk/debug" \
        -maxdepth 1 -type f -name 'SableTextReader-*.apk' -print | sort
)
[[ "${#apks[@]}" -eq 1 ]] || {
    echo "R9_TEXT_READER_APK=FAIL_COUNT count=${#apks[@]}"
    exit 69
}

APKANALYZER="$SABLE_APKANALYZER" \
    python3 "$ROOT/apps/r8/textreader/verify_sable_textreader.py" \
        "$WORK/textreader" "${apks[0]}"

sha256sum "${apks[0]}"

echo "R9_TEXT_READER_UNIT_TESTS=PASS"
echo "R9_TEXT_READER_LINT=PASS"
echo "R9_TEXT_READER_APK=PASS"
echo "R9_TEXT_READER_FOCUSED_QUALIFICATION=PASS"
