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
)

for rel in "${stale_paths[@]}"; do
    if [[ -e "$ROOT/$rel" ]]; then
        echo "R8_STALE_SOURCE_PATH=FAIL path=$rel"
        fail R8_STALE_SOURCE_PATH
    fi
    echo "R8_STALE_SOURCE_PATH=PASS_ABSENT path=$rel"
done

stale_matches="$(
    git -C "$ROOT" grep -n -E         'MediaDesignPreview(Activity|Screen)|SableStartRoot|UI-C1A Review'         --         apps/r8/android/media         src/android/packages/apps/SableStart         2>/dev/null         || true
)"
if [[ -n "$stale_matches" ]]; then
    printf '%s\n' "$stale_matches"
    fail R8_STALE_PRODUCT_SOURCE_TEXT
fi

START_MANIFEST="$ROOT/src/android/packages/apps/SableStart/AndroidManifest.xml"
MEDIA_MANIFEST="$ROOT/apps/r8/android/media/src/main/AndroidManifest.xml"
PRODUCT_MK="$ROOT/product/r8/panther/r8-product.mk"

grep -Fq 'SableMetroPreviewActivity' "$START_MANIFEST"     && fail R8_STALE_START_PREVIEW_COMPONENT
grep -Fq 'MediaDesignPreviewActivity' "$MEDIA_MANIFEST"     && fail R8_STALE_MEDIA_PREVIEW_COMPONENT

for forbidden in start-preview system-preview ExactCalculator SableConvert SableConverter SableGames TextReader; do
    if grep -Fq "$forbidden" "$PRODUCT_MK"; then
        echo "R8_STALE_PRODUCT_MODULE=FAIL value=$forbidden"
        fail R8_STALE_PRODUCT_MODULE
    fi
done

echo "R8_QUALIFICATION_ONLY_PREVIEW_MODULES=PASS_NOT_PRODUCT_SELECTED"

for source in     "$ROOT/apps/r8/android/calculator/src/main/java/org/sableos/calculator/MainActivity.kt"     "$ROOT/apps/r8/android/games/src/main/java/org/sableos/games/MainActivity.kt"     "$ROOT/apps/r8/android/media/src/main/java/org/sableos/media/MainActivity.kt"     "$ROOT/apps/r8/android/hub/src/main/java/org/sableos/hub/MainActivity.kt"
do
    grep -Fq 'SableGlobalTheme(window = window)' "$source"         || fail R8_GLOBAL_APPEARANCE_CONSUMER
    if grep -Fq 'applySableDarkSystemBars' "$source"; then
        fail R8_STALE_PRIVATE_THEME_PATH
    fi
done

MAIL_APPLIER="$ROOT/apps/r8/mail/apply_sable_flavor.py"
MAIL_ENV="$ROOT/apps/r8/mail/upstream.env"
[[ -f "$MAIL_APPLIER" && -f "$MAIL_ENV" ]] || fail R8_SABLE_MAIL_SOURCE

for needle in     'SABLE_MAIL_FUNDING=NOOP'     'SABLE_MAIL_THUNDERMAIL=REMOVED_FROM_PRODUCT_APP'     'SABLE_MAIL_OAUTH=DISABLED_UNTIL_SABLE_CLIENT_REGISTRATION'     'SABLE_MAIL_GLOBAL_APPEARANCE=FOLLOW_SYSTEM_LIGHT_DARK_PLUS_5_ACCENTS'
do
    grep -Fq "$needle" "$MAIL_APPLIER" || fail R8_SABLE_MAIL_POLICY
done

grep -Fq 'SABLE_MAIL_APPLICATION_ID=org.sableos.mail' "$MAIL_ENV"     || fail R8_SABLE_MAIL_ID

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
echo "R8_STALE_PRODUCT_MODULES=PASS_ABSENT"
echo "R8_GLOBAL_APPEARANCE_CONSUMERS=PASS"
echo "R8_SABLE_MAIL_POLICY_SOURCE=PASS"
echo "R8_NO_STALE_PRODUCT_CODE=PASS"
