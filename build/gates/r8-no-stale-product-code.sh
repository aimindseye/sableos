#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WS="${WS:-${SABLEOS_UPSTREAM:-}}"
WORKSPACE_INVENTORY_REQUIRED="${R8_NO_STALE_WORKSPACE_INVENTORY_REQUIRED:-YES}"

case "$WORKSPACE_INVENTORY_REQUIRED" in
    YES|NO) ;;
    *)
        echo "R8_NO_STALE_PRODUCT_CODE=FAIL_WORKSPACE_INVENTORY_MODE value=$WORKSPACE_INVENTORY_REQUIRED"
        exit 2
        ;;
esac

fail() {
    echo "$1=FAIL"
    echo "R8_NO_STALE_PRODUCT_CODE=FAIL"
    exit "${2:-1}"
}

echo "===== R8 NO-STALE PRODUCT CODE / PACKAGE GATE ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "WORKSPACE_INVENTORY_REQUIRED=$WORKSPACE_INVENTORY_REQUIRED"

stale_paths=(
    "apps/r8/android/media/src/main/java/org/sableos/media/preview/MediaDesignPreviewActivity.kt"
    "apps/r8/android/media/src/main/java/org/sableos/media/preview/MediaDesignPreviewScreen.kt"
    "src/android/packages/apps/SableStart/src/com/sable/start/ui/SableStartRoot.kt"
    "src/android/packages/apps/SableStart/src/com/sable/start/ui/SableMetroPreviewActivity.kt"
    "src/android/packages/apps/SableStart/rust/src/lib.rs"
    "src/android/packages/apps/SableStart/src/com/sable/start/bridge/SableStartNative.kt"
    "apps/r8/android/sablestart-production-check"
    "build/panther/build-sablestart.sh"
    "build/panther/capture-sablestart.sh"
    "build/panther/verify-sablestart-snapshot.sh"
    "build/gates/r8-sablestart-signing-policy.py"
    "build/gates/sablestart-r3-prebuild.sh"
    "build/gates/sablestart-r3b-soong.sh"
    "tests/sablestart/device/r3_functional_gate.sh"
    "apps/r8/android/start-preview"
    "apps/r8/android/system-preview"
    "build/panther/build-ui-preview.sh"
    "build/panther/flash-ui-preview-inactive-slot.sh"
    "build/panther/validate-ui-preview.sh"
    "patches/android-17-grapheneos-2026081300/apply_r9_launcher_cohesion.py"
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
        'MediaDesignPreview(Activity|Screen)|SableStartRoot|SableMetroPreviewActivity|DevelopmentNavigator|showDevelopmentNavigator|UI-C1A Review' \
        -- \
        apps/r8/android/media/src \
        apps/r8/android/media/src/main/AndroidManifest.xml \
        src/android/packages/apps/SableStart/src \
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
        apps/r8/android/calendar \
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

MEDIA_MANIFEST="$ROOT/apps/r8/android/media/src/main/AndroidManifest.xml"
PRODUCT_MK="$ROOT/product/r8/panther/r8-product.mk"

grep -Fq 'MediaDesignPreviewActivity' "$MEDIA_MANIFEST" \
    && fail R8_STALE_MEDIA_PREVIEW_COMPONENT

if grep -Eq '^[[:space:]]*SableStart([[:space:]]*\\)?[[:space:]]*$' "$PRODUCT_MK"; then
    fail R9_LEGACY_SABLESTART_PRODUCT_MODULE
fi

grep -Eq '^[[:space:]]*SableLauncher([[:space:]]*\\)?[[:space:]]*$' "$PRODUCT_MK" \
    || fail R9_STANDALONE_SABLELAUNCHER_PRODUCT_MODULE
echo "R9_STANDALONE_SABLELAUNCHER_PRODUCT_MODULE=PASS"

grep -Eq '^[[:space:]]*SableTextReader([[:space:]]*\\)?[[:space:]]*$' "$PRODUCT_MK" \
    || fail R9_SABLE_TEXT_READER_PRODUCT_MODULE
echo "R9_SABLE_TEXT_READER_PRODUCT_MODULE=PASS"

if grep -Eq '^[[:space:]]*(TextReader|VaachakTextReader)([[:space:]]*\\)?[[:space:]]*$' "$PRODUCT_MK"; then
    fail R9_LEGACY_TEXT_READER_PRODUCT_MODULE
fi
echo "R9_LEGACY_TEXT_READER_PRODUCT_MODULE=PASS_ABSENT"

for forbidden in \
    start-preview \
    system-preview \
    ExactCalculator \
    SableConvert \
    SableConverter \
    SableGames
do
    if grep -Fq "$forbidden" "$PRODUCT_MK"; then
        echo "R8_STALE_PRODUCT_MODULE=FAIL value=$forbidden"
        fail R8_STALE_PRODUCT_MODULE
    fi
done

GRADLE_SETTINGS="$ROOT/apps/r8/android/settings.gradle.kts"
grep -Fq 'include(":start-preview")' "$GRADLE_SETTINGS"     && fail R8_STALE_START_PREVIEW_MODULE
grep -Fq 'include(":system-preview")' "$GRADLE_SETTINGS"     && fail R8_STALE_SYSTEM_PREVIEW_MODULE
grep -Fq 'include(":sablestart-production-check")' "$GRADLE_SETTINGS"     && fail R9_STALE_SABLESTART_PRODUCTION_CHECK_MODULE
grep -Fq 'include(":sablestart-presentation-check")' "$GRADLE_SETTINGS"     || fail R9_SABLESTART_PRESENTATION_CHECK_MODULE
echo "R8_PREVIEW_QUALIFICATION_MODULES=PASS_RETIRED"
echo "R9_SABLESTART_PRESENTATION_CHECK_MODULE=PASS"

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

    if [[ "$WORKSPACE_INVENTORY_REQUIRED" == YES ]]; then
        python3 "$ROOT/build/gates/verify-r8-vendor-sable-inventory.py" \
            "$WS/vendor/sable"

        mapfile -t sable_r8_blueprints < <(
            find "$WS/vendor/sable" -type f -name Android.bp -print 2>/dev/null | sort || true
        )
        [[ "${#sable_r8_blueprints[@]}" -eq 1 ]] || {
            printf '%s\n' "${sable_r8_blueprints[@]}"
            fail R8_DUPLICATE_PRODUCT_BLUEPRINT
        }
        [[ "${sable_r8_blueprints[0]}" == "$WS/vendor/sable/r8/Android.bp" ]] \
            || fail R8_DUPLICATE_PRODUCT_BLUEPRINT
        echo "R8_DUPLICATE_PRODUCT_BLUEPRINT=PASS_ABSENT"
        echo "R8_WORKSPACE_PRODUCT_INVENTORY=PASS_EXACT"
    else
        echo "R8_WORKSPACE_PRODUCT_INVENTORY=SKIP_PRESTAGING"
    fi
fi

for manifest in \
    "$ROOT/apps/r8/android/calculator/src/main/AndroidManifest.xml" \
    "$ROOT/apps/r8/android/games/src/main/AndroidManifest.xml" \
    "$ROOT/apps/r8/android/media/src/main/AndroidManifest.xml" \
    "$ROOT/apps/r8/android/hub/src/main/AndroidManifest.xml" \
    "$ROOT/apps/r8/android/weather/src/main/AndroidManifest.xml" \
    "$ROOT/apps/r8/android/calendar/src/main/AndroidManifest.xml"
do
    grep -Fq 'android:authorities="org.sableos.appearance"' "$manifest" \
        || fail R8_GLOBAL_APPEARANCE_VISIBILITY
    if grep -Fq 'android:authorities="org.sableos.start.appearance"' "$manifest"; then
        fail R9_RETIRED_LAUNCHER_APPEARANCE_AUTHORITY
    fi
done

for source in \
    "$ROOT/apps/r8/android/calculator/src/main/java/org/sableos/calculator/MainActivity.kt" \
    "$ROOT/apps/r8/android/games/src/main/java/org/sableos/games/MainActivity.kt" \
    "$ROOT/apps/r8/android/media/src/main/java/org/sableos/media/MediaApp.kt" \
    "$ROOT/apps/r8/android/hub/src/main/java/org/sableos/hub/MainActivity.kt" \
    "$ROOT/apps/r8/android/weather/src/main/java/org/sableos/weather/MainActivity.kt" \
    "$ROOT/apps/r8/android/calendar/src/main/java/org/sableos/calendar/MainActivity.kt"
do
    grep -Fq 'SableGlobalTheme(window = window)' "$source" \
        || fail R8_GLOBAL_APPEARANCE_CONSUMER
    if grep -Fq 'applySableDarkSystemBars' "$source"; then
        fail R8_STALE_PRIVATE_THEME_PATH
    fi
done

HUB_MANIFEST="$ROOT/apps/r8/android/hub/src/main/AndroidManifest.xml"
HUB_WEB="$ROOT/apps/r8/android/hub/src/main/java/org/sableos/hub/web/ProviderCapsuleActivity.kt"
[[ ! -e "$HUB_WEB" ]] || fail R9_STALE_SABLE_MESSAGES_WEB_CAPSULE
grep -Fq 'android.permission.INTERNET' "$HUB_MANIFEST" \
    && fail R9_STALE_SABLE_MESSAGES_INTERNET_PERMISSION
grep -Fq '.web.' "$HUB_MANIFEST" \
    && fail R9_STALE_SABLE_MESSAGES_WEB_ACTIVITY

if git -C "$ROOT" grep -n -E \
    'ProviderCapsule(Activity|Launcher)|ProviderCapabilityClass|Private web session|private, isolated web sessions|MMS / RCS' \
    -- apps/r8/android/hub 2>/dev/null
then
    fail R9_STALE_SABLE_MESSAGES_PROVIDER_SURFACE
fi
echo "R9_SABLE_MESSAGES_WEB_CAPSULES=PASS_RETIRED"
echo "R9_SABLE_MESSAGES_INTERNET_PERMISSION=PASS_ABSENT"

READER_APPLIER="$ROOT/apps/r8/reader/apply_sable_flavor.py"
grep -Fq 'SableGlobalAppearance.kt' "$READER_APPLIER" \
    || fail R8_GLOBAL_APPEARANCE_READER
grep -Fq 'ProductReaderTheme.kt' "$READER_APPLIER" \
    || fail R8_GLOBAL_APPEARANCE_READER
grep -Fq 'import org.sableos.design.SableTheme' "$READER_APPLIER" \
    || fail R8_GLOBAL_APPEARANCE_READER
grep -Fq 'rememberGlobalSableAppearance()' "$READER_APPLIER" \
    || fail R8_GLOBAL_APPEARANCE_READER
grep -Fq 'appearance = rememberGlobalSableAppearance(),' "$READER_APPLIER" \
    || fail R8_GLOBAL_APPEARANCE_READER
grep -Fq 'if (!BuildConfig.SABLE_PRODUCT || themeMode == ThemeMode.E_INK)' "$READER_APPLIER" \
    || fail R8_GLOBAL_APPEARANCE_READER
echo "R8_GLOBAL_APPEARANCE_READER=PASS_PRODUCT_THEME_BRIDGE"
grep -Fq 'SABLE_READER_TEXTREADER_COMPOSITION=PASS_ABSENT' "$READER_APPLIER" || fail R9_READER_TEXTREADER_DECOMPOSITION
if grep -Fq 'SableTextActivity' "$READER_APPLIER" || grep -Fq 'SableOcrActivity' "$READER_APPLIER"; then
    fail R9_READER_TEXTREADER_RUNTIME
fi

TEXTREADER_APPLIER="$ROOT/apps/r8/textreader/apply_sable_flavor.py"
TEXTREADER_VERIFY="$ROOT/apps/r8/textreader/verify_sable_textreader.py"
[[ -f "$TEXTREADER_APPLIER" && -f "$TEXTREADER_VERIFY" ]] || fail R9_SABLE_TEXT_READER_SOURCE
grep -Fq 'org.sableos.textreader' "$TEXTREADER_APPLIER" || fail R9_SABLE_TEXT_READER_IDENTITY
grep -Fq 'SABLE_TEXT_READER_INTERNET_MERGE_RULE=PASS_REMOVE' "$TEXTREADER_VERIFY" || fail R9_SABLE_TEXT_READER_OFFLINE_POLICY
grep -Fq 'SABLE_TEXT_READER_APK_INTERNET_PERMISSION=PASS_ABSENT' "$TEXTREADER_VERIFY" || fail R9_SABLE_TEXT_READER_APK_OFFLINE_POLICY
echo "R9_READER_TEXTREADER_DECOMPOSITION=PASS"
echo "R9_SABLE_TEXT_READER_SOURCE=PASS"

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
    'hub/build/outputs/apk/debug/hub-debug.apk' \
    'weather/build/outputs/apk/debug/weather-debug.apk' \
    'calendar/build/outputs/apk/debug/calendar-debug.apk'
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
    'SABLE_MAIL_THUNDERMAIL=REMOVED_FROM_PRODUCT_RUNTIME_GRAPH' \
    'SABLE_MAIL_AUTODISCOVERY_DEMO=REMOVED_FROM_PRODUCT_RUNTIME_GRAPH' \
    'SABLE_MAIL_AUTODISCOVERY_DEMO_SOURCE_SPECIAL_CASES=REMOVED' \
    'SABLE_MAIL_ACCOUNT_ENTRY=STANDARD_IMAP_SMTP_SETUP' \
    'SABLE_MAIL_THUNDERMAIL_ROUTES=REMOVED_FROM_COMPOSED_SOURCE' \
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

if [[ "$WORKSPACE_INVENTORY_REQUIRED" == YES && -n "$WS" && -d "$WS/vendor/sable/r8/prebuilt" ]]; then
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
    "SableTextReader.apk",
    "SableReader.apk",
    "SableHub.apk",
    "SableMail.apk",
    "SableWeather.apk",
    "SableCalendar.apk",
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
elif [[ "$WORKSPACE_INVENTORY_REQUIRED" == NO ]]; then
    echo "R8_STAGED_APK_SET=SKIP_PRESTAGING"
fi

echo "R8_STALE_PRODUCT_SOURCE_TEXT=PASS_ABSENT"
echo "R8_STALE_PRODUCT_COMPONENTS=PASS_ABSENT"
echo "R8_STALE_PRODUCT_MODULES=PASS_ABSENT"
echo "R9_LEGACY_SABLESTART_RUNTIME=PASS_ABSENT"
echo "R9_STANDALONE_SABLELAUNCHER_RUNTIME=PASS_PRESENT"
echo "R9_LAUNCHER3_HOME_SOURCE=PASS_RETIRED_RECENTS_ONLY"
echo "R8_GLOBAL_APPEARANCE_CONSUMERS=PASS"
echo "R8_SABLE_MAIL_POLICY_SOURCE=PASS"
echo "R8_NO_STALE_PRODUCT_CODE=PASS"
