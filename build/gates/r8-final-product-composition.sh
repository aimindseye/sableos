#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT/build/config/panther-grapheneos-2026081300.env"

WS="${WS:-$SABLEOS_UPSTREAM}"
DEST="$WS/vendor/sable/r8"
PRODUCT_MK="$WS/vendor/google_devices/panther/panther.mk"

echo "===== R8 FINAL UI PRODUCT COMPOSITION GATE ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=NO"
echo "CLEAN_AUTHORIZED=NO"
echo "CLOBBER_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "WORKSPACE=$WS"

fail() {
    echo "$1=FAIL"
    echo "R8_FINAL_UI_PRODUCT_COMPOSITION=FAIL"
    echo "NEXT_FULL_PANTHER_BUILD_AUTHORIZED=NO"
    exit "${2:-1}"
}

[[ -d "$WS/.repo" ]] || fail R8_ANDROID_WORKSPACE 2

echo
echo "===== NO-STALE PRODUCT CODE / PACKAGE GATE ====="

WS="$WS" SABLEOS_UPSTREAM="$WS"     bash "$ROOT/build/gates/r8-no-stale-product-code.sh"     || fail R8_NO_STALE_PRODUCT_CODE

echo
echo "===== R8-A SHARED DESIGN ====="

THEME="$ROOT/src/android/shared/sabledesign/src/main/java/org/sableos/design/SableTheme.kt"
START="$ROOT/src/android/packages/apps/SableStart/src/com/sable/start/ui/SableStartScreen.kt"
STATE="$ROOT/src/android/packages/apps/SableStart/src/com/sable/start/platform/StartStateRepository.kt"

for needle in     'FollowSystem("follow-system")'     'Light("light")'     'Dark("dark")'     'Blue("blue", "Sable Blue"'     'Green("green", "Green"'     'Purple("purple", "Purple"'     'Orange("orange", "Orange"'     'Slate("slate", "Slate"'     'appearance: SableAppearance = SableAppearance()'
do
    grep -Fq "$needle" "$THEME" || fail R8_A_SHARED_DESIGN
done

for needle in     'SableTheme('     'SableStartDestination.Appearance'     'AppearanceMode.entries'     'AccentPreset.entries'     'Reset to Follow system · Sable Blue'
do
    grep -Fq "$needle" "$START" || fail R8_A_SHARED_DESIGN
done

for needle in     'fun loadAppearance()'     'fun saveAppearance('     'fun resetAppearance()'     '.remove(SableDesignContract.KEY_APPEARANCE_MODE)'     '.remove(SableDesignContract.KEY_ACCENT)'
do
    grep -Fq "$needle" "$STATE" || fail R8_A_SHARED_DESIGN
done

echo "R8_A_SHARED_DESIGN_SOURCE=PASS"

GLOBAL_APPEARANCE="$ROOT/src/android/shared/sabledesign/src/main/java/org/sableos/design/SableGlobalAppearance.kt"
SYSTEM_BARS="$ROOT/src/android/shared/sabledesign/src/main/java/org/sableos/design/SableSystemBars.kt"
START_PROVIDER="$ROOT/src/android/packages/apps/SableStart/src/com/sable/start/platform/SableAppearanceProvider.kt"

for needle in     'org.sableos.start.appearance'     'rememberGlobalSableAppearance'     'SableGlobalTheme'
do
    grep -Fq "$needle" "$GLOBAL_APPEARANCE" || fail R8_GLOBAL_APPEARANCE_SOURCE
done

for needle in     'SableGlobalAppearanceContract.CONTENT_URI'     'SableAppearanceProvider'
do
    grep -R -Fq "$needle"         "$ROOT/src/android/packages/apps/SableStart"         || fail R8_GLOBAL_APPEARANCE_PROVIDER
done

for source in     "$ROOT/apps/r8/android/calculator/src/main/java/org/sableos/calculator/MainActivity.kt"     "$ROOT/apps/r8/android/games/src/main/java/org/sableos/games/MainActivity.kt"     "$ROOT/apps/r8/android/media/src/main/java/org/sableos/media/MainActivity.kt"     "$ROOT/apps/r8/android/hub/src/main/java/org/sableos/hub/MainActivity.kt"
do
    grep -Fq 'SableGlobalTheme(window = window)' "$source"         || fail R8_GLOBAL_APPEARANCE_CONSUMER
done

grep -Fq 'SableGlobalAppearance.kt'     "$ROOT/apps/r8/reader/apply_sable_flavor.py"     || fail R8_GLOBAL_APPEARANCE_READER

echo "R8_GLOBAL_APPEARANCE_SOURCE=PASS"

for needle in \
    'val decorView = window.decorView' \
    'decorView.windowInsetsController?.setSystemBarsAppearance(' \
    'if (decorView.isAttachedToWindow)' \
    'decorView.post { applyAppearance() }'
do
    grep -Fq "$needle" "$SYSTEM_BARS" || fail R8_SABLESTART_SYSTEM_BARS_LIFECYCLE
done

if grep -Fq 'window.insetsController' "$SYSTEM_BARS"; then
    fail R8_SABLESTART_SYSTEM_BARS_DIRECT_PHONEWINDOW_ACCESS
fi

START_BP="$ROOT/src/android/packages/apps/SableStart/Android.bp"
grep -Fq 'name: "sable_start_presentation_srcs"' "$START_BP" \
    || fail R9_SABLESTART_PRESENTATION_FILEGROUP
if grep -Fq 'android_app {' "$START_BP"; then
    fail R9_STANDALONE_SABLESTART_ANDROID_APP
fi

echo "R8_SABLESTART_SYSTEM_BARS_LIFECYCLE=PASS"
echo "R9_SABLESTART_PRESENTATION_FILEGROUP=PASS"

echo
echo "===== SHARED DESIGN WORKSPACE FIDELITY ====="

diff -qr     "$ROOT/src/android/shared/sabledesign"     "$WS/packages/apps/SableDesign"     >/dev/null || fail R8_SABLE_DESIGN_WORKSPACE_FIDELITY

echo "R8_SABLE_DESIGN_WORKSPACE_FIDELITY=PASS"

echo
echo "===== SABLE START WORKSPACE FIDELITY ====="

if ! python3 -     "$ROOT/src/android/packages/apps/SableStart"     "$WS/packages/apps/SableStart" <<'PY'
import hashlib
import pathlib
import sys

repo = pathlib.Path(sys.argv[1])
workspace = pathlib.Path(sys.argv[2])
ignore = {"PORTABILITY_STATUS.md", "SHA256SUMS.txt"}

def inventory(root, repository):
    result = {}
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        rel = path.relative_to(root)
        if any(part in {".git", "out", "build", ".gradle", "target"} for part in rel.parts):
            continue
        if repository and rel.as_posix() in ignore:
            continue
        result[rel.as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result

expected = inventory(repo, True)
actual = inventory(workspace, False)

missing = sorted(set(expected) - set(actual))
extra = sorted(set(actual) - set(expected))
mismatch = sorted(k for k in set(expected) & set(actual) if expected[k] != actual[k])

print(f"R8_SABLESTART_EXPECTED_FILES={len(expected)}")
print(f"R8_SABLESTART_WORKSPACE_FILES={len(actual)}")

if missing:
    print("R8_SABLESTART_MISSING=" + ",".join(missing))
if extra:
    print("R8_SABLESTART_EXTRA=" + ",".join(extra))
if mismatch:
    print("R8_SABLESTART_MISMATCH=" + ",".join(mismatch))

if missing or extra or mismatch:
    raise SystemExit(1)

print("R8_SABLESTART_WORKSPACE_FIDELITY=PASS")
PY
then
    fail R8_SABLESTART_WORKSPACE_FIDELITY
fi

grep -Fq 'src/com/sable/start/ui/SableStartScreen.kt'     "$ROOT/build/panther/sync-sablestart.sh"     || fail R8_SABLESTART_SYNC_CONTRACT

if grep -Fq 'SableStartRoot.kt' "$ROOT/build/panther/sync-sablestart.sh"; then
    fail R8_SABLESTART_STALE_ROOT_REFERENCE
fi

echo "R8_SABLESTART_SYNC_CONTRACT=PASS"

echo
echo "===== R9 LAUNCHER3 / QUICKSTEP FOUNDATION VERIFY ====="

python3 \
    "$ROOT/patches/android-17-grapheneos-2026081300/apply_r9_launcher3_foundation.py" \
    --source "$WS" verify \
    || fail R9_LAUNCHER3_FOUNDATION

if grep -Fq 'SableStart' "$ROOT/product/r8/panther/r8-product.mk"; then
    fail R9_STANDALONE_SABLESTART_PRODUCT
fi

echo "R9_LAUNCHER3_FOUNDATION=PASS"
echo "R8_START_PRODUCT_INTEGRATION=PASS_LAUNCHER3_FOUNDATION"

echo
echo "===== CUMULATIVE SYSTEM SURFACE SOURCE GATE ====="

python3 \
    "$ROOT/patches/android-17-grapheneos-2026081300/apply_ui5c_ui6_system_surfaces.py" \
    --source "$WS" verify \
    || fail R8_UI4_UI5_UI6_CUMULATIVE_SOURCE

echo "R8_UI4_UI5_UI6_CUMULATIVE_SOURCE=PASS"

echo
echo "===== FIRST-PARTY PRODUCT INTEGRATION ====="

[[ -d "$DEST" ]] || fail R8_PRODUCT_STAGE_DIRECTORY
[[ -f "$DEST/Android.bp" ]] || fail R8_PRODUCT_ANDROID_BP
[[ -f "$DEST/r8-product.mk" ]] || fail R8_PRODUCT_MK
[[ -f "$DEST/manifest.tsv" ]] || fail R8_PRODUCT_MANIFEST
[[ -f "$DEST/SHA256SUMS.txt" ]] || fail R8_PRODUCT_SHA256SUMS
[[ -f "$DEST/SABLEOS_SOURCE_COMMIT.txt" ]] || fail R8_PRODUCT_SOURCE_IDENTITY

CURRENT_SOURCE_COMMIT="$(git -C "$ROOT" rev-parse HEAD)"
STAGED_SOURCE_COMMIT="$(tr -d '[:space:]' < "$DEST/SABLEOS_SOURCE_COMMIT.txt")"
[[ "$STAGED_SOURCE_COMMIT" == "$CURRENT_SOURCE_COMMIT" ]] || fail R8_PRODUCT_SOURCE_IDENTITY
echo "R8_PRODUCT_SOURCE_COMMIT=PASS value=$STAGED_SOURCE_COMMIT"

cmp -s     "$ROOT/product/r8/panther/Android.bp"     "$DEST/Android.bp"     || fail R8_PRODUCT_ANDROID_BP

cmp -s     "$ROOT/product/r8/panther/r8-product.mk"     "$DEST/r8-product.mk"     || fail R8_PRODUCT_MK

(
    cd "$DEST/prebuilt"
    sha256sum -c "$DEST/SHA256SUMS.txt"
) || fail R8_PRODUCT_PREBUILT_HASHES

if ! python3 - "$DEST/manifest.tsv" "$DEST/prebuilt" <<'PY'
import csv
import pathlib
import sys

expected = {
    "org.sableos.calculator": "SableCalculator.apk",
    "org.sableos.sudoku": "SableSudoku.apk",
    "org.sableos.minesweeper": "SableMinesweeper.apk",
    "org.sableos.game2048": "Sable2048.apk",
    "org.sableos.media": "SableMedia.apk",
    "org.sableos.reader": "SableReader.apk",
    "org.sableos.hub": "SableHub.apk",
    "org.sableos.mail": "SableMail.apk",
}

with pathlib.Path(sys.argv[1]).open(newline="", encoding="utf-8") as f:
    rows = list(csv.DictReader(f, delimiter="\t"))

actual = {row["package"]: row["filename"] for row in rows}

if actual != expected or len(rows) != len(expected):
    print(f"R8_PRODUCT_PACKAGE_SET=FAIL actual={actual!r}")
    raise SystemExit(1)

prebuilt = pathlib.Path(sys.argv[2])
actual_apks = sorted(path.name for path in prebuilt.glob("*.apk"))
expected_apks = sorted(expected.values())

if actual_apks != expected_apks:
    print(
        "R8_PRODUCT_PREBUILT_SET=FAIL "
        f"expected={expected_apks!r} actual={actual_apks!r}"
    )
    raise SystemExit(1)

print("R8_PRODUCT_PACKAGE_SET=PASS")
print("R8_PRODUCT_PREBUILT_SET=PASS")
PY
then
    fail R8_PRODUCT_PACKAGE_SET
fi

[[ -f "$PRODUCT_MK" ]] || fail R8_PANTHER_PRODUCT_FILE
grep -Eq '^PRODUCT_NAME[[:space:]]*:=[[:space:]]*panther[[:space:]]*$' "$PRODUCT_MK"     || fail R8_PANTHER_PRODUCT_NAME
grep -Eq '^PRODUCT_DEVICE[[:space:]]*:=[[:space:]]*panther[[:space:]]*$' "$PRODUCT_MK"     || fail R8_PANTHER_PRODUCT_DEVICE

PRODUCT_MK_SHA256="$(sha256sum "$PRODUCT_MK" | awk '{print $1}')"
echo "R8_PANTHER_PRODUCT_FILE=$PRODUCT_MK"
echo "R8_PANTHER_PRODUCT_SHA256=$PRODUCT_MK_SHA256"

INHERIT_LINE='$(call inherit-product, vendor/sable/r8/r8-product.mk)'
include_count="$(grep -Fc "$INHERIT_LINE" "$PRODUCT_MK" || true)"
[[ "$include_count" -eq 1 ]] || fail R8_PRODUCT_INCLUDE

grep -Fq 'overrides: ["ExactCalculator"]' "$DEST/Android.bp"     || fail R8_EXACT_CALCULATOR_REPLACEMENT

if ! python3 - "$DEST/Android.bp" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

expected = {
    "SableCalculator",
    "SableSudoku",
    "SableMinesweeper",
    "Sable2048",
    "SableMedia",
    "SableReader",
    "SableHub",
    "SableMail",
}

blocks = re.findall(r"android_app_import\s*\{(.*?)\n\}", text, flags=re.S)
seen = set()

for block in blocks:
    match = re.search(r'name:\s*"([^"]+)"', block)
    if not match:
        continue
    name = match.group(1)
    if name not in expected:
        continue

    seen.add(name)

    required = (
        "presigned: true,",
        "preprocessed: true,",
        "dex_preopt:",
        "enabled: false,",
    )
    missing = [needle for needle in required if needle not in block]
    if missing:
        raise SystemExit(
            "R8_PRESIGNED_APK_IMPORT=FAIL "
            f"module={name} missing={missing!r}"
        )

if seen != expected:
    raise SystemExit(
        "R8_PRESIGNED_APK_IMPORT_SET=FAIL "
        f"missing={sorted(expected - seen)!r} "
        f"extra={sorted(seen - expected)!r}"
    )

print("R8_PRESIGNED_APK_IMPORT_SET=PASS")
print("R8_PRESIGNED_APK_PREPROCESSED=PASS count=8")
PY
then
    fail R8_PRESIGNED_APK_PREPROCESSED
fi

for module in     SableStart     SableCalculator     SableSudoku     SableMinesweeper     Sable2048     SableMedia     SableReader     SableHub     SableMail
do
    grep -Fq "$module" "$DEST/r8-product.mk"         || fail "R8_PRODUCT_MODULE_${module}"
done

echo "R8_PRODUCT_INCLUDE=PASS"
echo "R8_PRODUCT_SOURCE_IDENTITY=PASS"
echo "R8_PRODUCT_PREBUILT_HASHES=PASS"
echo "R8_EXACT_CALCULATOR_REPLACEMENT=PASS"

echo
echo "===== READER D2 SOURCE CLOSURE ====="

READER_APPLIER="$ROOT/apps/r8/reader/apply_sable_flavor.py"

for needle in     'SABLE_READER_OCR=CAMERA_GALLERY_LATIN_DEVANAGARI_ENABLED'     'SABLE_READER_OCR_CAMERA_PERMISSION=OPTIONAL_RUNTIME_ONLY'     'SABLE_READER_OCR_NETWORK_FALLBACK=DISABLED'     'text-recognition:16.0.1'     'text-recognition-devanagari:16.0.1'     'SableOcrActivity'
do
    grep -Fq "$needle" "$READER_APPLIER" || fail R8_D2_READER_OCR_SOURCE
done

echo "R8_D2_READER_OCR_SOURCE=PASS"

echo
echo "===== R8-F SABLE HUB SOURCE CLOSURE ====="

HUB_DIR="$ROOT/apps/r8/android/hub"
HUB_MANIFEST="$HUB_DIR/src/main/AndroidManifest.xml"
HUB_MODELS="$HUB_DIR/src/main/java/org/sableos/hub/HubModels.kt"
HUB_REPOSITORY="$HUB_DIR/src/main/java/org/sableos/hub/HubRepository.kt"
HUB_CAPSULE="$HUB_DIR/src/main/java/org/sableos/hub/web/ProviderCapsuleActivity.kt"

for f in "$HUB_MANIFEST" "$HUB_MODELS" "$HUB_REPOSITORY" "$HUB_CAPSULE"; do
    [[ -f "$f" ]] || fail R8_F_SABLE_HUB_SOURCE
done

for permission in     android.permission.INTERNET     android.permission.READ_SMS     android.permission.SEND_SMS     android.permission.READ_CONTACTS
do
    grep -Fq "$permission" "$HUB_MANIFEST" || fail R8_F_SABLE_HUB_PERMISSION_CONTRACT
done

for provider in whatsapp instagram messenger linkedin; do
    grep -Fq "id = \"$provider\"" "$HUB_MODELS" || fail R8_F_SABLE_HUB_PROVIDER_CONTRACT
done

grep -Fq 'ProviderCapabilityClass.Web' "$HUB_MODELS"     || fail R8_F_SABLE_HUB_PROVIDER_CONTRACT
grep -Fq 'RoleManager.ROLE_SMS' "$HUB_REPOSITORY"     || fail R8_F_SABLE_HUB_SMS_ROLE_OBSERVATION
if grep -Fq 'createRequestRoleIntent' "$HUB_DIR/src/main/java/org/sableos/hub/MainActivity.kt"; then
    fail R8_F_SABLE_HUB_DEFAULT_SMS_ROLE_REQUEST
fi
grep -Fq 'WebView.setDataDirectorySuffix(provider.id)' "$HUB_CAPSULE"     || fail R8_F_SABLE_HUB_WEB_ISOLATION
grep -Fq 'scheme == "https"' "$HUB_CAPSULE"     || fail R8_F_SABLE_HUB_WEB_HTTPS

echo "R8_F_SABLE_HUB_SOURCE=PASS"

echo
echo "===== R8-G SABLE MAIL SOURCE CLOSURE ====="

MAIL_ENV="$ROOT/apps/r8/mail/upstream.env"
MAIL_APPLIER="$ROOT/apps/r8/mail/apply_sable_flavor.py"
MAIL_POLICY="$ROOT/apps/r8/mail/verify_sable_mail.py"

for f in "$MAIL_ENV" "$MAIL_APPLIER" "$MAIL_POLICY"; do
    [[ -f "$f" ]] || fail R8_G_SABLE_MAIL_SOURCE
done

grep -Fq 'THUNDERBIRD_COMMIT=c733317d933c22bcd790a4790306f30ccf2026b8'     "$MAIL_ENV" || fail R8_G_SABLE_MAIL_PIN
grep -Fq 'SABLE_MAIL_APPLICATION_ID=org.sableos.mail'     "$MAIL_ENV" || fail R8_G_SABLE_MAIL_ID
grep -Fq 'SABLE_MAIL_OAUTH=DISABLED_UNTIL_SABLE_CLIENT_REGISTRATION'     "$MAIL_APPLIER" || fail R8_G_SABLE_MAIL_OAUTH_POLICY
grep -Fq 'SABLE_MAIL_GLOBAL_APPEARANCE=FOLLOW_SYSTEM_LIGHT_DARK_PLUS_5_ACCENTS'     "$MAIL_APPLIER" || fail R8_G_SABLE_MAIL_THEME_POLICY

echo "R8_G_SABLE_MAIL_SOURCE=PASS"

echo
echo "===== R9 SABLESTART COMBINED DESIGN GATE ====="

python3 "$ROOT/build/gates/r9-sablestart-design-contract.py" \
    || fail R9_SABLESTART_COMBINED_DESIGN_CONTRACT

python3 "$ROOT/build/gates/r9-launcher3-foundation-contract.py" \
    || fail R9_LAUNCHER3_FOUNDATION_CONTRACT

echo
echo "===== FINAL COMPOSITION RESULT ====="
echo "R8_A_SHARED_DESIGN=PASS"
echo "R8_START_PRODUCT_INTEGRATION=PASS_LAUNCHER3_FOUNDATION"
echo "R9_L7_LAUNCHER3_FOUNDATION_SOURCE=PASS"
echo "R8_B_CALCULATOR_CONVERT=PASS_PRODUCT_STAGED"
echo "R8_C_GAMES=PASS_PRODUCT_STAGED"
echo "R8_D_READER_PUBLICATION=PASS_PRODUCT_STAGED"
echo "R8_D2_READER_TEXT_ACCESSIBILITY_OCR=PASS_SOURCE_AND_PRODUCT_STAGED"
echo "R8_E_MEDIA=PASS_PRODUCT_STAGED"
echo "R8_F_SABLE_HUB_MESSAGES=PASS_PRODUCT_STAGED"
echo "R8_G_GLOBAL_APPEARANCE=PASS_SOURCE_AND_PRODUCT_STAGED"
echo "R8_G_SABLE_MAIL=PASS_PRODUCT_STAGED"
echo "R8_UI4_SYSTEMUI=PASS_SOURCE"
echo "R8_UI5_SETTINGS=PASS_SOURCE"
echo "R8_UI5C_UI6_SYSTEM_SURFACES=PASS_SOURCE"
echo "R8_FINAL_UI_PRODUCT_COMPOSITION=PASS"
echo "R9_SABLESTART_SOURCE_COMPOSITION=PASS"
echo "R9_L6_VISUAL_REVIEW_STATUS=PENDING"
echo "NEXT_FULL_PANTHER_BUILD_AUTHORIZED=NO"
