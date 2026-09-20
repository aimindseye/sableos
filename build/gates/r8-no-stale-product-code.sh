#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WS="${WS:-${SABLEOS_UPSTREAM:-}}"

fail() {
    echo "$1=FAIL"
    echo "R8_NO_STALE_PRODUCT_CODE=FAIL"
    exit "${2:-1}"
}

echo "===== R8 NO-STALE PRODUCT CODE / PACKAGE GATE ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"

stale_paths=(
    "apps/r8/android/media/src/main/java/org/sableos/media/preview/MediaDesignPreviewActivity.kt"
    "apps/r8/android/media/src/main/java/org/sableos/media/preview/MediaDesignPreviewScreen.kt"
    "src/android/packages/apps/SableStart/src/com/sable/start/ui/SableStartRoot.kt"
    "src/android/packages/apps/SableStart/src/com/sable/start/ui/SableMetroPreviewActivity.kt"
    "src/android/packages/apps/SableStart/AndroidManifest.xml"
    "src/android/packages/apps/SableStart/rust/src/lib.rs"
    "src/android/packages/apps/SableStart/src/com/sable/start/SableStartActivity.kt"
    "src/android/packages/apps/SableStart/src/com/sable/start/bridge/SableStartNative.kt"
    "src/android/packages/apps/SableStart/src/com/sable/start/platform/LauncherAppsRepository.kt"
    "build/gates/r8-sablestart-signing-policy.py"
    "apps/r8/android/start-preview"
    "apps/r8/android/system-preview"
    "build/panther/build-ui-preview.sh"
    "build/panther/flash-ui-preview-inactive-slot.sh"
    "build/panther/validate-ui-preview.sh"
)

for rel in "${stale_paths[@]}"; do
    if [[ -e "$ROOT/$rel" ]]; then
        echo "R8_STALE_SOURCE_PATH=FAIL path=$rel"
        fail R8_STALE_SOURCE_PATH
    fi
    echo "R8_STALE_SOURCE_PATH=PASS_ABSENT path=$rel"
done

stale_matches="$(
    git -C "$ROOT" grep -n -E \
        'MediaDesignPreview(Activity|Screen)|SableStartRoot|SableMetroPreviewActivity|SableStartActivity|LauncherAppsRepository|SableStartNative|DevelopmentNavigator|showDevelopmentNavigator|UI-C1A Review' \
        -- \
        apps/r8/android/media/src \
        apps/r8/android/media/src/main/AndroidManifest.xml \
        src/android/packages/apps/SableStart/src \
        src/android/packages/apps/SableStart/AndroidManifest.xml \
        2>/dev/null \
        || true
)"
if [[ -n "$stale_matches" ]]; then
    printf '%s\n' "$stale_matches"
    fail R8_STALE_PRODUCT_SOURCE_TEXT
fi

stale_tracked_paths="$(
    git -C "$ROOT" ls-files -- \
        apps/r8/android/calculator \
        apps/r8/android/games \
        apps/r8/android/media \
        apps/r8/android/hub \
        src/android/packages/apps/SableStart \
        | grep -E \
            '(^|/)(preview|prototype|mock|demo)(/|$)|(^|/)[^/]*(Preview|Prototype|Mock|Demo)[^/]*\.(kt|java|xml)$' \
        || true
)"
if [[ -n "$stale_tracked_paths" ]]; then
    printf '%s\n' "$stale_tracked_paths"
    fail R8_STALE_PRODUCT_TRACKED_PATH
fi
echo "R8_STALE_PRODUCT_TRACKED_PATH=PASS_ABSENT"

START_BP="$ROOT/src/android/packages/apps/SableStart/Android.bp"
MEDIA_MANIFEST="$ROOT/apps/r8/android/media/src/main/AndroidManifest.xml"
PRODUCT_MK="$ROOT/product/r8/panther/r8-product.mk"

grep -Fq 'android_app {' "$START_BP" && fail R9_STANDALONE_SABLESTART_ANDROID_APP
grep -Fq 'rust_ffi_shared {' "$START_BP" && fail R9_STANDALONE_SABLESTART_RUST_JNI
grep -Fq 'name: "sable_start_presentation_srcs"' "$START_BP" || fail R9_SABLESTART_PRESENTATION_FILEGROUP
grep -Fq 'MediaDesignPreviewActivity' "$MEDIA_MANIFEST" && fail R8_STALE_MEDIA_PREVIEW_COMPONENT

for forbidden in \
    SableStart \
    start-preview \
    system-preview \
    ExactCalculator \
    SableConvert \
    SableConverter \
    SableGames \
    TextReader
do
    if grep -Fq "$forbidden" "$PRODUCT_MK"; then
        echo "R8_STALE_PRODUCT_MODULE=FAIL value=$forbidden"
        fail R8_STALE_PRODUCT_MODULE
    fi
done

GRADLE_SETTINGS="$ROOT/apps/r8/android/settings.gradle.kts"
grep -Fq 'include(":start-preview")' "$GRADLE_SETTINGS"     && fail R8_STALE_START_PREVIEW_MODULE
grep -Fq 'include(":system-preview")' "$GRADLE_SETTINGS"     && fail R8_STALE_SYSTEM_PREVIEW_MODULE
grep -Fq 'include(":sablestart-production-check")' "$GRADLE_SETTINGS"     || fail R8_SABLESTART_PRODUCTION_CHECK_MODULE
START_CHECK="$ROOT/apps/r8/android/sablestart-production-check/build.gradle.kts"
grep -Fq 'manifest.srcFile("src/main/AndroidManifest.xml")' "$START_CHECK" || fail R9_SABLESTART_PRESENTATION_CHECK_MANIFEST
! grep -Fq 'src/android/packages/apps/SableStart/AndroidManifest.xml' "$START_CHECK" || fail R9_STANDALONE_SABLESTART_MANIFEST_REFERENCE
echo "R8_PREVIEW_QUALIFICATION_MODULES=PASS_RETIRED"
echo "R8_SABLESTART_PRODUCTION_CHECK_MODULE=PASS_PRESENTATION_ONLY"

if [[ -n "$WS" ]]; then
    LEGACY_SABLE_DEVICE_PRODUCT="$WS/vendor/sable_devices/sable_panther"
    LEGACY_SABLE_DEVICE_PARENT="$WS/vendor/sable_devices"
    if [[ -e "$LEGACY_SABLE_DEVICE_PRODUCT" || -L "$LEGACY_SABLE_DEVICE_PRODUCT" ]]; then
        echo "R8_STALE_SABLE_DEVICE_PRODUCT=FAIL path=$LEGACY_SABLE_DEVICE_PRODUCT"
        find "$LEGACY_SABLE_DEVICE_PRODUCT" -maxdepth 4 -mindepth 1 -print 2>/dev/null | sort || true
        fail R8_STALE_SABLE_DEVICE_PRODUCT
    fi
    echo "R8_STALE_SABLE_DEVICE_PRODUCT=PASS_ABSENT"

    if [[ -e "$LEGACY_SABLE_DEVICE_PARENT" || -L "$LEGACY_SABLE_DEVICE_PARENT" ]]; then
        echo "R8_STALE_SABLE_DEVICE_PARENT=FAIL path=$LEGACY_SABLE_DEVICE_PARENT"
        find "$LEGACY_SABLE_DEVICE_PARENT" -maxdepth 3 -mindepth 1 -print 2>/dev/null | sort || true
        fail R8_STALE_SABLE_DEVICE_PARENT
    fi
    echo "R8_STALE_SABLE_DEVICE_PARENT=PASS_ABSENT"

    LEGACY_WORKSPACE_PRODUCT_TREE="$WS/vendor/sable/prebuilts/r8"
    if [[ -e "$LEGACY_WORKSPACE_PRODUCT_TREE" || -L "$LEGACY_WORKSPACE_PRODUCT_TREE" ]]; then
        echo "R8_STALE_WORKSPACE_PRODUCT_TREE=FAIL path=$LEGACY_WORKSPACE_PRODUCT_TREE"
        find "$LEGACY_WORKSPACE_PRODUCT_TREE" -maxdepth 3 -mindepth 1 -print 2>/dev/null | sort || true
        fail R8_STALE_WORKSPACE_PRODUCT_TREE
    fi
    echo "R8_STALE_WORKSPACE_PRODUCT_TREE=PASS_ABSENT"

    python3 "$ROOT/build/gates/verify-r8-vendor-sable-inventory.py" \
        "$WS/vendor/sable"

    mapfile -t sable_r8_blueprints < <(
        find "$WS/vendor/sable" -type f -name Android.bp -print 2>/dev/null | sort || true
    )
    [[ "${#sable_r8_blueprints[@]}" -eq 1 ]] || {
        printf '%s\n' "${sable_r8_blueprints[@]}"
        fail R8_DUPLICATE_PRODUCT_BLUEPRINT
    }
    [[ "${sable_r8_blueprints[0]}" == "$WS/vendor/sable/r8/Android.bp" ]]         || fail R8_DUPLICATE_PRODUCT_BLUEPRINT
    echo "R8_DUPLICATE_PRODUCT_BLUEPRINT=PASS_ABSENT"
fi

for manifest in \
    "$ROOT/apps/r8/android/calculator/src/main/AndroidManifest.xml" \
    "$ROOT/apps/r8/android/games/src/main/AndroidManifest.xml" \
    "$ROOT/apps/r8/android/media/src/main/AndroidManifest.xml" \
    "$ROOT/apps/r8/android/hub/src/main/AndroidManifest.xml"
do
    grep -Fq 'android:authorities="org.sableos.start.appearance"' "$manifest" \
        || fail R8_GLOBAL_APPEARANCE_VISIBILITY
done

for source in \
    "$ROOT/apps/r8/android/calculator/src/main/java/org/sableos/calculator/MainActivity.kt" \
    "$ROOT/apps/r8/android/games/src/main/java/org/sableos/games/MainActivity.kt" \
    "$ROOT/apps/r8/android/media/src/main/java/org/sableos/media/MainActivity.kt" \
    "$ROOT/apps/r8/android/hub/src/main/java/org/sableos/hub/MainActivity.kt"
do
    grep -Fq 'SableGlobalTheme(window = window)' "$source" \
        || fail R8_GLOBAL_APPEARANCE_CONSUMER
    if grep -Fq 'applySableDarkSystemBars' "$source"; then
        fail R8_STALE_PRIVATE_THEME_PATH
    fi
done

HUB_WEB="$ROOT/apps/r8/android/hub/src/main/java/org/sableos/hub/web/ProviderCapsuleActivity.kt"
grep -Fq 'readGlobalSableAppearance(this)' "$HUB_WEB" \
    || fail R8_GLOBAL_APPEARANCE_HUB_WEB
grep -Fq 'applySableSystemBars(' "$HUB_WEB" \
    || fail R8_GLOBAL_APPEARANCE_HUB_WEB

READER_APPLIER="$ROOT/apps/r8/reader/apply_sable_flavor.py"
grep -Fq 'SableGlobalAppearance.kt' "$READER_APPLIER" \
    || fail R8_GLOBAL_APPEARANCE_READER
grep -Fq 'rememberGlobalSableAppearance()' "$READER_APPLIER" \
    || fail R8_GLOBAL_APPEARANCE_READER
grep -Fq 'SableGlobalTheme(window = window)' "$READER_APPLIER" \
    || fail R8_GLOBAL_APPEARANCE_READER

EXPORTER="$ROOT/apps/r8/export-panther-app-bundle.sh"
if grep -Fq 'find "$ROOT/apps/r8/android"' "$EXPORTER"; then
    fail R8_BUNDLE_RECURSIVE_APK_DISCOVERY
fi

for expected_apk in \
    'calculator/build/outputs/apk/debug/calculator-debug.apk' \
    'games/build/outputs/apk/sudoku/debug/games-sudoku-debug.apk' \
    'games/build/outputs/apk/minesweeper/debug/games-minesweeper-debug.apk' \
    'games/build/outputs/apk/game2048/debug/games-game2048-debug.apk' \
    'media/build/outputs/apk/debug/media-debug.apk' \
    'hub/build/outputs/apk/debug/hub-debug.apk'
do
    grep -Fq "$expected_apk" "$EXPORTER" \
        || fail R8_BUNDLE_EXPLICIT_APK_INPUTS
done
echo "R8_BUNDLE_EXPLICIT_APK_INPUTS=PASS"

MAIL_APPLIER="$ROOT/apps/r8/mail/apply_sable_flavor.py"
MAIL_VERIFY="$ROOT/apps/r8/mail/verify_sable_mail.py"
MAIL_ENV="$ROOT/apps/r8/mail/upstream.env"
[[ -f "$MAIL_APPLIER" && -f "$MAIL_VERIFY" && -f "$MAIL_ENV" ]] \
    || fail R8_SABLE_MAIL_SOURCE

for needle in \
    'SABLE_MAIL_FUNDING=NOOP' \
    'SABLE_MAIL_MIGRATION_UI=NOOP' \
    'SABLE_MAIL_THUNDERMAIL=REMOVED_FROM_PRODUCT_APP' \
    'SABLE_MAIL_OAUTH=DISABLED_UNTIL_SABLE_CLIENT_REGISTRATION' \
    'SABLE_MAIL_GLOBAL_APPEARANCE=FOLLOW_SYSTEM_LIGHT_DARK_PLUS_5_ACCENTS'
do
    grep -Fq "$needle" "$MAIL_APPLIER" \
        || fail R8_SABLE_MAIL_POLICY
done

grep -Fq 'SABLE_MAIL_APPLICATION_ID=org.sableos.mail' "$MAIL_ENV" \
    || fail R8_SABLE_MAIL_ID
grep -Fq 'SABLE_MAIL_REMOTE_CONTENT_PRIVACY=PASS_UPSTREAM_PRESERVED' "$MAIL_VERIFY" \
    || fail R8_SABLE_MAIL_REMOTE_CONTENT_POLICY

if [[ -n "$WS" && -d "$WS/vendor/sable/r8/prebuilt" ]]; then
    python3 - "$WS/vendor/sable/r8/prebuilt" <<'PY'
import pathlib
import sys

prebuilt = pathlib.Path(sys.argv[1])
expected = {
    "SableCalculator.apk",
    "SableSudoku.apk",
    "SableMinesweeper.apk",
    "Sable2048.apk",
    "SableMedia.apk",
    "SableReader.apk",
    "SableHub.apk",
    "SableMail.apk",
}
actual = {path.name for path in prebuilt.glob("*.apk")}
if actual != expected:
    raise SystemExit(
        "R8_STAGED_APK_SET=FAIL "
        f"missing={sorted(expected - actual)!r} "
        f"extra={sorted(actual - expected)!r}"
    )
print("R8_STAGED_APK_SET=PASS")
PY
fi

echo "R8_STALE_PRODUCT_SOURCE_TEXT=PASS_ABSENT"
echo "R8_STALE_PRODUCT_COMPONENTS=PASS_ABSENT"
echo "R9_STANDALONE_SABLESTART_PRODUCT=PASS_ABSENT"
echo "R9_SABLESTART_PRESENTATION_SOURCE=PASS"
echo "R8_STALE_PRODUCT_MODULES=PASS_ABSENT"
echo "R8_GLOBAL_APPEARANCE_CONSUMERS=PASS"
echo "R8_SABLE_MAIL_POLICY_SOURCE=PASS"
echo "R8_NO_STALE_PRODUCT_CODE=PASS"
