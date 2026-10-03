#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROFILE="$ROOT/build/titan2/n1d-c3b-e2-product-composition.env"
HOST_TOOLS="$ROOT/build/config/host-tools.env"
COMPOSITION_GATE="$ROOT/build/gates/n1d-c3b-e2-product-composition-contract.sh"
APP_ROOT="$ROOT/apps/titan2/platform"

OUTPUT_DIR=""
AUTHORIZE_APP_BUILD=NO

usage() {
    cat <<'USAGE'
usage: build/titan2/build-n1d-c3b-e2-product-apps.sh \
  --authorize-app-build \
  [--output-dir <absolute path>]
USAGE
}

fail() {
    echo "N1D_C3B_E2_APP_BUILD=FAIL $*" >&2
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --authorize-app-build)
            AUTHORIZE_APP_BUILD=YES
            shift
            ;;
        --output-dir)
            [[ $# -ge 2 ]] || fail missing_output_dir
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "unknown_arg=$1"
            ;;
    esac
done

[[ "$AUTHORIZE_APP_BUILD" == YES ]] || fail explicit_build_authority_required
[[ -f "$PROFILE" ]] || fail "missing_profile=$PROFILE"
[[ -f "$HOST_TOOLS" ]] || fail "missing_host_tools=$HOST_TOOLS"
[[ -x "$APP_ROOT/gradlew" ]] || fail "missing_gradlew=$APP_ROOT/gradlew"

# shellcheck source=/dev/null
source "$PROFILE"
# shellcheck source=/dev/null
source "$HOST_TOOLS"

bash "$COMPOSITION_GATE"

current_head="$(git -C "$ROOT" rev-parse HEAD)"
git -C "$ROOT" merge-base --is-ancestor "$N1D_C3B_E2_SOURCE_IMPORT_COMMIT" "$current_head" ||
    fail "source_import_not_ancestor=$N1D_C3B_E2_SOURCE_IMPORT_COMMIT"

SOURCE_PATHS=(
    apps/titan2/platform
    config/DETEKT_PROVENANCE.env
    config/QUALITY_SUPPRESSION_BUDGET.tsv
    config/detekt.yml
    third_party/phosphor-icons
    third_party/pinyin_zh
    tools/gen_first_party_icons.py
    tools/gen_indic_rows.py
    tools/gen_phonetic.py
    tools/gen_pinyin_dict.py
    tools/gen_pinyin_license_bundle.py
    tools/indic_common.py
    tools/test_gen_pinyin_dict.py
)

git -C "$ROOT" diff --quiet "$N1D_C3B_E2_SOURCE_IMPORT_COMMIT" HEAD -- "${SOURCE_PATHS[@]}" ||
    fail "admitted_source_changed_after_import=$N1D_C3B_E2_SOURCE_IMPORT_COMMIT"

[[ -d "$SABLE_ANDROID_BUILD_TOOLS" ]] || fail "missing_build_tools=$SABLE_ANDROID_BUILD_TOOLS"
APKSIGNER="$SABLE_ANDROID_BUILD_TOOLS/apksigner"
AAPT2="$SABLE_ANDROID_BUILD_TOOLS/aapt2"
[[ -x "$APKSIGNER" ]] || fail "missing_apksigner=$APKSIGNER"
[[ -x "$AAPT2" ]] || fail "missing_aapt2=$AAPT2"
export ANDROID_HOME="$SABLE_ANDROID_SDK"
export ANDROID_SDK_ROOT="$SABLE_ANDROID_SDK"
export JAVA_HOME="$SABLE_JDK17"
export GRADLE_USER_HOME="$SABLE_GRADLE_USER_HOME"
export PATH="$JAVA_HOME/bin:$PATH"

if [[ -z "$OUTPUT_DIR" ]]; then
    run_id="$(date -u +%Y%m%dT%H%M%SZ)"
    OUTPUT_DIR="/srv/sable-build/artifacts/titan2/n1d-c3b-e2-product-apps/${N1D_C3B_E2_SOURCE_IMPORT_COMMIT}/$run_id"
fi
[[ "$OUTPUT_DIR" = /* ]] || fail output_dir_must_be_absolute
mkdir -p "$OUTPUT_DIR/prebuilt"

echo "===== TITAN 2 N1D C3B E2 SOURCE-BOUND APP BUILD ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "PRODUCTION_SIGNING_AUTHORIZED=NO"
echo "CANONICAL_SOURCE_IMPORT_COMMIT=$N1D_C3B_E2_SOURCE_IMPORT_COMMIT"
echo "CANONICAL_BUILD_HEAD=$current_head"

(
    cd "$APP_ROOT"
    ./gradlew \
        --offline \
        --dependency-verification=strict \
        --no-daemon \
        --console=plain \
        :keyboard:assembleRelease \
        :camera:assembleRelease \
        :displaycompat:assembleRelease \
        :setup:assembleRelease \
        :radiodiag:assembleRelease
)

declare -a MODULES=(
    "SableTitan2Keyboard:keyboard:org.sableos.titan2.keyboard"
    "SableTitan2Camera:camera:org.sableos.titan2.camera"
    "SableTitan2DisplayCompat:displaycompat:org.sableos.titan2.displaycompat"
    "SableTitan2Setup:setup:org.sableos.titan2.setup"
    "SableTitan2RadioDiag:radiodiag:org.sableos.titan2.radiodiag"
)

MANIFEST="$OUTPUT_DIR/manifest.tsv"
SUMS="$OUTPUT_DIR/SHA256SUMS.txt"
printf 'module\tgradle_module\tpackage\tfilename\tsha256\tbytes\tsignature_state\n' > "$MANIFEST"
: > "$SUMS"

for entry in "${MODULES[@]}"; do
    IFS=: read -r module gradle_module package <<<"$entry"
    release_dir="$APP_ROOT/$gradle_module/build/outputs/apk/release"
    [[ -d "$release_dir" ]] || fail "missing_release_dir=$release_dir"

    mapfile -t apks < <(find "$release_dir" -maxdepth 1 -type f -name '*.apk' -print | LC_ALL=C sort)
    [[ "${#apks[@]}" == 1 ]] ||
        fail "release_apk_count module=$gradle_module count=${#apks[@]}"

    apk="${apks[0]}"
    actual_package="$("$AAPT2" dump badging "$apk" | sed -n "s/^package: name='\([^']*\)'.*/\1/p" | head -n1)"
    [[ "$actual_package" == "$package" ]] ||
        fail "package_mismatch module=$module expected=$package actual=$actual_package"

    if "$APKSIGNER" verify "$apk" >/dev/null 2>&1; then
        fail "release_apk_unexpectedly_signed module=$module path=$apk"
    fi

    filename="$module.apk"
    dest="$OUTPUT_DIR/prebuilt/$filename"
    install -m 0644 "$apk" "$dest"
    sha="$(sha256sum "$dest" | awk '{print $1}')"
    bytes="$(stat -c '%s' "$dest")"
    printf '%s\t%s\t%s\t%s\t%s\t%s\tUNSIGNED\n' \
        "$module" "$gradle_module" "$package" "$filename" "$sha" "$bytes" >> "$MANIFEST"
    printf '%s  %s\n' "$sha" "$filename" >> "$SUMS"
done

printf '%s\n' "$N1D_C3B_E2_SOURCE_IMPORT_COMMIT" > "$OUTPUT_DIR/CANONICAL_SOURCE_IMPORT_COMMIT.txt"
printf '%s\n' "$current_head" > "$OUTPUT_DIR/CANONICAL_BUILD_HEAD.txt"

(
    cd "$OUTPUT_DIR/prebuilt"
    sha256sum -c "$SUMS"
)

count="$(tail -n +2 "$MANIFEST" | grep -cve '^$' || true)"
[[ "$count" == "$N1D_C3B_E2_MODULE_COUNT" ]] ||
    fail "artifact_manifest_count=$count"

echo "N1D_C3B_E2_APP_BUILD_SOURCE_BINDING=PASS"
echo "N1D_C3B_E2_APP_BUILD_NETWORK=PASS_OFFLINE"
echo "N1D_C3B_E2_APP_BUILD_UNSIGNED=PASS count=$count"
echo "N1D_C3B_E2_APP_BUILD_PACKAGE_IDS=PASS count=$count"
echo "N1D_C3B_E2_APP_BUILD=PASS count=$count"
echo "ARTIFACT_DIR=$OUTPUT_DIR"
