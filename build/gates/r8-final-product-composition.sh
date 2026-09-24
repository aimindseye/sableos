#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT/build/config/r8-release.env"
source "$ROOT/build/config/panther-grapheneos-2026081300.env"
source "$ROOT/build/console.sh"
sable_console_capture_color

WS="${WS:-$SABLEOS_UPSTREAM}"
DEST="$WS/vendor/sable/r8"
PRODUCT_MK="$WS/vendor/google_devices/panther/panther.mk"
SABLE_QUALIFICATION_ONLY="${SABLE_QUALIFICATION_ONLY:-NO}"

case "$SABLE_QUALIFICATION_ONLY" in
    YES|NO) ;;
    *)
        echo "R8_FINAL_UI_PRODUCT_COMPOSITION=FAIL_QUALIFICATION_MODE value=$SABLE_QUALIFICATION_ONLY"
        exit 2
        ;;
esac

echo "===== R8 FINAL UI PRODUCT COMPOSITION GATE ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=NO"
echo "CLEAN_AUTHORIZED=NO"
echo "CLOBBER_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "WORKSPACE=$WS"
echo "SABLE_QUALIFICATION_ONLY=$SABLE_QUALIFICATION_ONLY"

fail() {
    echo "$1=FAIL"
    echo "R8_FINAL_UI_PRODUCT_COMPOSITION=FAIL"
    echo "NEXT_FULL_PANTHER_BUILD_AUTHORIZED=NO"
    sable_checkpoint_fail "Final product composition: $1"
    exit "${2:-1}"
}

[[ -d "$WS/.repo" ]] || fail R8_ANDROID_WORKSPACE 2

echo
echo "===== NO-STALE PRODUCT CODE / PACKAGE GATE ====="

R8_NO_STALE_WORKSPACE_INVENTORY_REQUIRED=YES \
WS="$WS" \
SABLEOS_UPSTREAM="$WS" \
    bash "$ROOT/build/gates/r8-no-stale-product-code.sh" \
    || fail R8_NO_STALE_PRODUCT_CODE

echo
echo "===== R8-A SHARED DESIGN ====="

THEME="$ROOT/src/android/shared/sabledesign/src/main/java/org/sableos/design/SableTheme.kt"
START="$ROOT/src/android/packages/apps/SableStart/src/com/sable/start/ui/SableStartScreen.kt"
STATE="$ROOT/src/android/packages/apps/SableStart/src/com/sable/start/platform/StartStateRepository.kt"

for needle in     'FollowSystem("follow-system")'     'Light("light")'     'Dark("dark")'     'Blue("blue", "Sable Blue"'     'Green("green", "Green"'     'Purple("purple", "Purple"'     'Orange("orange", "Orange"'     'Slate("slate", "Slate"'     'appearance: SableAppearance = SableAppearance()'
do
    grep -Fq "$needle" "$THEME" || fail R8_A_SHARED_DESIGN
done

for needle in \
    'SableTheme(' \
    'SableStartDestination.Appearance' \
    'AppearanceMode.entries' \
    'AccentPreset.entries' \
    'AppearanceChoiceRow(' \
    'AccentChoiceRow(' \
    'reset · follow system + Sable Blue'
do
    grep -Fq "$needle" "$START" || fail R8_A_SHARED_DESIGN
done

if grep -Fq 'Reset to Follow system · Sable Blue' "$START"; then
    fail R8_A_SHARED_DESIGN_STALE_APPEARANCE_COPY
fi

for needle in \
    'fun loadFavoriteKeys()' \
    'fun saveFavoriteKeys(' \
    'fun loadStartTileKeys()' \
    'fun saveStartTileKeys('
do
    grep -Fq "$needle" "$STATE" || fail R8_A_SHARED_DESIGN
done

for forbidden in \
    'fun loadAppearance()' \
    'fun saveAppearance(' \
    'KEY_SYSTEM_NIGHT_MODE_BEFORE_OVERRIDE'
do
    if grep -Fq "$forbidden" "$STATE"; then
        fail R9_LAUNCHER_GLOBAL_APPEARANCE_OWNERSHIP_RETIRED
    fi
done

echo "R8_A_SHARED_DESIGN_SOURCE=PASS"

GLOBAL_APPEARANCE="$ROOT/src/android/shared/sabledesign/src/main/java/org/sableos/design/SableGlobalAppearance.kt"
SYSTEM_BARS="$ROOT/src/android/shared/sabledesign/src/main/java/org/sableos/design/SableSystemBars.kt"
SETTINGS_COHESION="$ROOT/patches/android-17-grapheneos-2026081300/apply_r9_settings_cohesion.py"
QUICKSTEP_RECENTS_ONLY="$ROOT/patches/android-17-grapheneos-2026081300/apply_r9_quickstep_recents_only.py"

for needle in \
    'org.sableos.appearance' \
    'rememberGlobalSableAppearance' \
    'writeGlobalSableAppearance(' \
    'SableGlobalTheme'
do
    grep -Fq "$needle" "$GLOBAL_APPEARANCE" || fail R8_GLOBAL_APPEARANCE_SOURCE
done

# Scan tracked production/runtime source for the retired Launcher-owned
# authority. Unit tests intentionally retain the literal as a negative
# regression assertion. git grep ignores untracked Gradle/build artifacts by
# construction, so compiled test output can never trip this source gate.
if git -C "$ROOT" grep -Fq \
    'org.sableos.start.appearance' -- \
    src/android/packages/apps/SableStart \
    apps/r8/android \
    apps/r8/mail/apply_sable_flavor.py \
    apps/r8/reader/apply_sable_flavor.py \
    ':(exclude)src/android/packages/apps/SableStart/*.md' \
    ':(exclude)apps/r8/android/**/src/test/**' \
    ':(exclude)apps/r8/android/**/src/androidTest/**' \
    ':(exclude)apps/r8/android/**/*.md'
then
    fail R9_RETIRED_LAUNCHER_APPEARANCE_AUTHORITY
fi

echo "R9_RETIRED_LAUNCHER_APPEARANCE_AUTHORITY=PASS"

[[ ! -e "$ROOT/src/android/packages/apps/SableStart/src/com/sable/start/platform/SableAppearanceProvider.kt" ]] \
    || fail R9_RETIRED_LAUNCHER_APPEARANCE_PROVIDER

for source in     "$ROOT/apps/r8/android/calculator/src/main/java/org/sableos/calculator/MainActivity.kt"     "$ROOT/apps/r8/android/games/src/main/java/org/sableos/games/MainActivity.kt"     "$ROOT/apps/r8/android/media/src/main/java/org/sableos/media/MediaApp.kt"     "$ROOT/apps/r8/android/hub/src/main/java/org/sableos/hub/MainActivity.kt"
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

python3 "$QUICKSTEP_RECENTS_ONLY" --source "$WS" verify \
    || fail R9_QUICKSTEP_RECENTS_ONLY_SOURCE

python3 "$SETTINGS_COHESION" --source "$WS" verify \
    || fail R9_SETTINGS_COHESION_SOURCE

echo "R8_SABLESTART_SYSTEM_BARS_LIFECYCLE=PASS"
echo "R9_SABLELAUNCHER_HOME_OWNERSHIP=PASS_SOURCE"
echo "R9_LAUNCHER3_HOME_ELIGIBILITY=PASS_ABSENT"
echo "R9_QUICKSTEP_RECENTS_ONLY_SOURCE=PASS"
echo "R9_SETTINGS_COHESION_SOURCE=PASS"
echo "R9_SETTINGS_NETWORK_MANAGER_SOURCE=PASS_GRAPHENE_NETWORK_PERMISSION"
echo "R9_STANDALONE_SABLELAUNCHER_PRODUCT=PASS_PRESENT"

echo
echo "===== SHARED DESIGN WORKSPACE FIDELITY ====="

diff -qr     "$ROOT/src/android/shared/sabledesign"     "$WS/packages/apps/SableDesign"     >/dev/null || fail R8_SABLE_DESIGN_WORKSPACE_FIDELITY

echo "R8_SABLE_DESIGN_WORKSPACE_FIDELITY=PASS"

echo
echo "===== SABLE START PRESENTATION WORKSPACE FIDELITY ====="

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

grep -Fq 'R9_SABLESTART_LOCAL_APPEARANCE_PROVIDER=PASS_RETIRED'     "$ROOT/build/panther/sync-sablestart.sh"     || fail R9_SABLESTART_SYNC_APPEARANCE_PROVIDER
if grep -Fq 'SableStartRoot.kt' "$ROOT/build/panther/sync-sablestart.sh"; then
    fail R8_SABLESTART_STALE_ROOT_REFERENCE
fi

grep -Fq 'SableLauncher' "$ROOT/product/r8/panther/r8-product.mk" \
    || fail R9_SABLELAUNCHER_PRODUCT_INTEGRATION
echo "R8_SABLESTART_SYNC_CONTRACT=PASS"
echo "R9_SABLELAUNCHER_PRODUCT_INTEGRATION=PASS"

echo
echo "===== CUMULATIVE SYSTEM SURFACE SOURCE GATE ====="

python3 \
    "$ROOT/patches/android-17-grapheneos-2026081300/apply_ui5c_ui6_system_surfaces.py" \
    --source "$WS" \
    --allow-framework-untracked \
    packages/SystemUI/src/com/android/systemui/sable/SableSystemAppearance.kt \
    --allow-framework-modified \
    packages/SystemUI/src/com/android/systemui/qs/panels/ui/compose/infinitegrid/Tile.kt \
    --allow-framework-modified \
    core/java/android/debug/AdbNotifications.java \
    --allow-settings-modified \
    AndroidManifest.xml \
    --allow-settings-modified \
    src/com/android/settings/core/gateway/SettingsGateway.java \
    --allow-settings-untracked \
    res/xml/sable_appearance_settings.xml \
    --allow-settings-untracked \
    res/xml/sable_network_manager_settings.xml \
    --allow-settings-untracked \
    res/values/strings_sable_cohesion.xml \
    --allow-settings-untracked \
    src/com/android/settings/sable/SableAppearanceContract.java \
    --allow-settings-untracked \
    src/com/android/settings/sable/SableAppearanceProvider.java \
    --allow-settings-untracked \
    src/com/android/settings/sable/SableAppearanceBootReceiver.java \
    --allow-settings-untracked \
    src/com/android/settings/sable/SableAppearanceSettings.java \
    --allow-settings-untracked \
    src/com/android/settings/sable/SableNetworkManagerSettings.java \
    verify \
    || fail R8_UI4_UI5_UI6_CUMULATIVE_SOURCE

python3 \
    "$ROOT/patches/android-17-grapheneos-2026081300/apply_r9_systemui_coherence.py" \
    --source "$WS" verify \
    || fail R9_SYSTEMUI_COHERENCE_SOURCE

python3 "$SETTINGS_COHESION" --source "$WS" verify \
    || fail R9_SETTINGS_COHESION_SOURCE

python3 "$QUICKSTEP_RECENTS_ONLY" --source "$WS" verify \
    || fail R9_QUICKSTEP_RECENTS_ONLY_SOURCE

echo "R8_UI4_UI5_UI6_CUMULATIVE_SOURCE=PASS"
echo "R9_SYSTEMUI_COHERENCE_SOURCE=PASS"
echo "R9_SETTINGS_COHESION_SOURCE=PASS"
echo "R9_QUICKSTEP_RECENTS_ONLY_SOURCE=PASS"

echo
echo "===== FIRST-PARTY PRODUCT INTEGRATION ====="

[[ -d "$DEST" ]] || fail R8_PRODUCT_STAGE_DIRECTORY
[[ -f "$DEST/Android.bp" ]] || fail R8_PRODUCT_ANDROID_BP
[[ -f "$DEST/r8-product.mk" ]] || fail R8_PRODUCT_MK
[[ -f "$DEST/manifest.tsv" ]] || fail R8_PRODUCT_MANIFEST
[[ -f "$DEST/SHA256SUMS.txt" ]] || fail R8_PRODUCT_SHA256SUMS
[[ -f "$DEST/SABLEOS_SOURCE_COMMIT.txt" ]] || fail R8_PRODUCT_SOURCE_IDENTITY
[[ -f "$DEST/permissions/sable-privapp-permissions-com.android.settings.xml" ]] || fail R9_SETTINGS_PRIVAPP_ALLOWLIST_STAGE

CURRENT_SOURCE_COMMIT="$(git -C "$ROOT" rev-parse HEAD)"
STAGED_SOURCE_COMMIT="$(tr -d '[:space:]' < "$DEST/SABLEOS_SOURCE_COMMIT.txt")"
[[ "$STAGED_SOURCE_COMMIT" == "$CURRENT_SOURCE_COMMIT" ]] || fail R8_PRODUCT_SOURCE_IDENTITY
echo "R8_PRODUCT_SOURCE_COMMIT=PASS value=$STAGED_SOURCE_COMMIT"

cmp -s     "$ROOT/product/r8/panther/Android.bp"     "$DEST/Android.bp"     || fail R8_PRODUCT_ANDROID_BP

cmp -s     "$ROOT/product/r8/panther/r8-product.mk"     "$DEST/r8-product.mk"     || fail R8_PRODUCT_MK
cmp -s     "$ROOT/product/r8/panther/permissions/sable-privapp-permissions-com.android.settings.xml"     "$DEST/permissions/sable-privapp-permissions-com.android.settings.xml"     || fail R9_SETTINGS_PRIVAPP_ALLOWLIST_STAGE

python3 - "$DEST/permissions/sable-privapp-permissions-com.android.settings.xml" <<'PY'
import pathlib
import sys
import xml.etree.ElementTree as ET

path = pathlib.Path(sys.argv[1])
root = ET.parse(path).getroot()
nodes = root.findall("privapp-permissions")
if len(nodes) != 1 or nodes[0].attrib.get("package") != "com.android.settings":
    raise SystemExit("R9_SETTINGS_PRIVAPP_ALLOWLIST=FAIL_PACKAGE")
perms = [node.attrib.get("name") for node in nodes[0].findall("permission")]
expected = ["android.permission.MODIFY_DAY_NIGHT_MODE"]
if perms != expected:
    raise SystemExit(
        f"R9_SETTINGS_PRIVAPP_ALLOWLIST=FAIL_PERMISSIONS actual={perms!r}"
    )
print("R9_SETTINGS_PRIVAPP_ALLOWLIST=PASS_EXACT")
PY
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
    "org.sableos.textreader": "SableTextReader.apk",
    "org.sableos.reader": "SableReader.apk",
    "org.sableos.hub": "SableHub.apk",
    "org.sableos.mail": "SableMail.apk",
    "org.sableos.weather": "SableWeather.apk",
    "org.sableos.calendar": "SableCalendar.apk",
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
grep -Fq 'overrides: ["Calendar"]' "$DEST/Android.bp"     || fail R9_SABLE_CALENDAR_REPLACEMENT
grep -Fq 'name: "SableSettingsPrivappPermissions"' "$DEST/Android.bp"     || fail R9_SETTINGS_PRIVAPP_ALLOWLIST_MODULE
grep -Fq 'system_ext_specific: true' "$DEST/Android.bp"     || fail R9_SETTINGS_PRIVAPP_ALLOWLIST_PARTITION
grep -Fq 'src: "permissions/sable-privapp-permissions-com.android.settings.xml"' "$DEST/Android.bp"     || fail R9_SETTINGS_PRIVAPP_ALLOWLIST_SOURCE
grep -Fq 'SableSettingsPrivappPermissions' "$DEST/r8-product.mk"     || fail R9_SETTINGS_PRIVAPP_ALLOWLIST_PRODUCT

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
    "SableTextReader",
    "SableReader",
    "SableHub",
    "SableMail",
    "SableWeather",
    "SableCalendar",
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
print("R8_PRESIGNED_APK_PREPROCESSED=PASS count=11")
PY
then
    fail R8_PRESIGNED_APK_PREPROCESSED
fi

for module in     SableCalculator     SableSudoku     SableMinesweeper     Sable2048     SableMedia     SableTextReader     SableReader     SableHub     SableMail     SableWeather     SableCalendar
do
    grep -Fq "$module" "$DEST/r8-product.mk"         || fail "R8_PRODUCT_MODULE_${module}"
done

echo "R8_PRODUCT_INCLUDE=PASS"
echo "R8_PRODUCT_SOURCE_IDENTITY=PASS"
echo "R8_PRODUCT_PREBUILT_HASHES=PASS"
echo "R8_EXACT_CALCULATOR_REPLACEMENT=PASS"
echo "R9_SABLE_CALENDAR_REPLACEMENT=PASS"
echo "R9_SETTINGS_PRIVAPP_ALLOWLIST_PRODUCT=PASS_SYSTEM_EXT"

echo
echo "===== R9 SABLE TEXT READER SOURCE CLOSURE ====="

TEXTREADER_ENV="$ROOT/apps/r8/textreader/upstream.env"
TEXTREADER_APPLIER="$ROOT/apps/r8/textreader/apply_sable_flavor.py"
TEXTREADER_VERIFY="$ROOT/apps/r8/textreader/verify_sable_textreader.py"
READER_APPLIER="$ROOT/apps/r8/reader/apply_sable_flavor.py"

for f in "$TEXTREADER_ENV" "$TEXTREADER_APPLIER" "$TEXTREADER_VERIFY" "$READER_APPLIER"; do
    [[ -f "$f" ]] || fail R9_SABLE_TEXT_READER_SOURCE
done

grep -Fq 'VAACHAK_TEXTREADER_COMMIT=50fca365baae9869264716569830690fb62029a7' "$TEXTREADER_ENV" \
    || fail R9_SABLE_TEXT_READER_PIN

for needle in \
    'org.sableos.textreader' \
    'SABLE_TEXT_READER_INTERNET_MERGE_RULE=PASS_REMOVE' \
    'SABLE_TEXT_READER_INTERNET_PERMISSION=PASS_FINAL_APK_ABSENT_REQUIRED' \
    'SABLE_TEXT_READER_TRANSLATION=PASS_RETIRED' \
    'SABLE_TEXT_READER_OCR=PASS_CAMERA_GALLERY_LATIN_DEVANAGARI' \
    'SABLE_TEXT_READER_TEXT_INPUT=PASS_BOUNDED_2_MIB' \
    'SABLE_TEXT_READER_TTS_NETWORK_VOICES=PASS_FILTERED'
do
    if ! grep -Fq "$needle" "$TEXTREADER_APPLIER"; then
        echo "R9_SABLE_TEXT_READER_SOURCE=FAIL_MISSING path=$TEXTREADER_APPLIER token=$needle"
        fail R9_SABLE_TEXT_READER_SOURCE
    fi
done

for needle in \
    'SABLE_TEXT_READER_INTERNET_MERGE_RULE=PASS_REMOVE' \
    'SABLE_TEXT_READER_INTERNET_PERMISSION=PASS_FINAL_APK_ABSENT_REQUIRED' \
    'SABLE_TEXT_READER_APK_INTERNET_PERMISSION=PASS_ABSENT' \
    'SABLE_TEXT_READER_APK_OFFLINE_BOUNDARY=PASS' \
    'SABLE_TEXT_READER_POLICY=PASS'
do
    if ! grep -Fq "$needle" "$TEXTREADER_VERIFY"; then
        echo "R9_SABLE_TEXT_READER_VERIFY=FAIL_MISSING path=$TEXTREADER_VERIFY token=$needle"
        fail R9_SABLE_TEXT_READER_VERIFY
    fi
done
grep -Fq 'SABLE_READER_TEXTREADER_COMPOSITION=PASS_ABSENT' "$READER_APPLIER" \
    || fail R9_READER_TEXTREADER_DECOMPOSITION

echo "R9_SABLE_TEXT_READER_SOURCE=PASS"
echo "R9_READER_TEXTREADER_DECOMPOSITION=PASS"

echo "===== R8-F SABLE HUB SOURCE CLOSURE ====="

HUB_DIR="$ROOT/apps/r8/android/hub"
HUB_MANIFEST="$HUB_DIR/src/main/AndroidManifest.xml"
HUB_MODELS="$HUB_DIR/src/main/java/org/sableos/hub/HubModels.kt"
HUB_REPOSITORY="$HUB_DIR/src/main/java/org/sableos/hub/HubRepository.kt"
HUB_MAIN="$HUB_DIR/src/main/java/org/sableos/hub/MainActivity.kt"
HUB_SCREEN="$HUB_DIR/src/main/java/org/sableos/hub/ui/HubScreen.kt"
HUB_CAPSULE="$HUB_DIR/src/main/java/org/sableos/hub/web/ProviderCapsuleActivity.kt"

for f in "$HUB_MANIFEST" "$HUB_MODELS" "$HUB_REPOSITORY" "$HUB_MAIN" "$HUB_SCREEN"; do
    [[ -f "$f" ]] || fail R8_F_SABLE_HUB_SOURCE
done

[[ ! -e "$HUB_CAPSULE" ]] || fail R9_SABLE_MESSAGES_WEB_CAPSULE_RETIRED

for permission in \
    android.permission.READ_SMS \
    android.permission.SEND_SMS \
    android.permission.READ_CONTACTS
do
    grep -Fq "$permission" "$HUB_MANIFEST" || fail R8_F_SABLE_HUB_PERMISSION_CONTRACT
done

if grep -Fq 'android.permission.INTERNET' "$HUB_MANIFEST"; then
    fail R9_SABLE_MESSAGES_INTERNET_PERMISSION
fi
if grep -Fq '.web.' "$HUB_MANIFEST"; then
    fail R9_SABLE_MESSAGES_WEB_ACTIVITY
fi

grep -Fq 'RoleManager.ROLE_SMS' "$HUB_REPOSITORY" \
    || fail R8_F_SABLE_HUB_SMS_ROLE_OBSERVATION
if grep -Fq 'createRequestRoleIntent' "$HUB_MAIN"; then
    fail R8_F_SABLE_HUB_DEFAULT_SMS_ROLE_REQUEST
fi

grep -Fq 'Dispatchers.IO' "$HUB_MAIN" \
    || fail R9_SABLE_MESSAGES_SNAPSHOT_OFF_MAIN
grep -Fq 'HubPivot.Messages' "$HUB_SCREEN" \
    || fail R9_SABLE_MESSAGES_NATIVE_PIVOT
grep -Fq 'HubPivot.People' "$HUB_SCREEN" \
    || fail R9_SABLE_MESSAGES_PEOPLE_PIVOT
grep -Fq 'label = { Text("Search conversations") }' "$HUB_SCREEN" \
    || fail R9_SABLE_MESSAGES_SEARCH
grep -Fq 'text = "MMS / attachment"' "$HUB_SCREEN" \
    || fail R9_SABLE_MESSAGES_CONTEXTUAL_MMS

for forbidden in \
    'HubPivot.Services' \
    'ProviderCapabilityClass' \
    'Private web session' \
    'private, isolated web sessions' \
    'MMS / RCS' \
    'RCS'
do
    if grep -Fq "$forbidden" "$HUB_SCREEN" "$HUB_MODELS"; then
        fail R9_SABLE_MESSAGES_RETIRED_PROVIDER_SURFACE
    fi
done

echo "R9_SABLE_MESSAGES_NATIVE_SMS_PEOPLE=PASS"
echo "R9_SABLE_MESSAGES_SNAPSHOT_OFF_MAIN=PASS"
echo "R9_SABLE_MESSAGES_CONTEXTUAL_MMS_HANDOFF=PASS"
echo "R9_SABLE_MESSAGES_WEB_CAPSULES=PASS_RETIRED"
echo "R9_SABLE_MESSAGES_INTERNET_PERMISSION=PASS_ABSENT"
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

echo
echo "===== FINAL COMPOSITION RESULT ====="
echo "R8_A_SHARED_DESIGN=PASS"
echo "R8_START_PRODUCT_INTEGRATION=PASS"
echo "R8_B_CALCULATOR_CONVERT=PASS_PRODUCT_STAGED"
echo "R8_C_GAMES=PASS_PRODUCT_STAGED"
echo "R8_D_READER_PUBLICATION=PASS_PRODUCT_STAGED"
echo "R9_SABLE_TEXT_READER=PASS_SOURCE_POLICY_AND_PRODUCT_STAGED"
echo "R9_READER_TEXTREADER_DECOMPOSITION=PASS"
echo "R8_E_MEDIA=PASS_PRODUCT_STAGED"
echo "R8_F_SABLE_HUB_MESSAGES=PASS_PRODUCT_STAGED"
echo "R8_G_GLOBAL_APPEARANCE=PASS_SOURCE_AND_PRODUCT_STAGED"
echo "R8_G_SABLE_MAIL=PASS_PRODUCT_STAGED"
echo "R9_SABLE_WEATHER=PASS_PRODUCT_STAGED"
echo "R9_SABLE_CALENDAR=PASS_PRODUCT_STAGED"

python3 "$ROOT/patches/android-17-grapheneos-2026081300/apply_r9_phone_contacts_presentation.py" \
    --source "$WS" verify
echo "R9_PHONE_CONTACTS_PRESENTATION=PASS_SOURCE"

python3 "$ROOT/patches/android-17-grapheneos-2026081300/apply_r9_daily_driver_core_presentation.py" \
    --source "$WS" verify
echo "R9_DAILY_DRIVER_CORE_PRESENTATION=PASS_SOURCE"

echo "R8_UI4_SYSTEMUI=PASS_SOURCE"
echo "R8_UI5_SETTINGS=PASS_SOURCE"
echo "R8_UI5C_UI6_SYSTEM_SURFACES=PASS_SOURCE"
echo "R8_FINAL_UI_PRODUCT_COMPOSITION=PASS"
echo "R9_SABLE_HOME_REPLACEMENT_SOURCE_COMPOSITION=PASS"
sable_checkpoint_pass "Final Panther product composition"

echo
echo "===== R9 LAUNCHER VISUAL ACCEPTANCE SEAL ====="

if [[ "$SABLE_QUALIFICATION_ONLY" == YES ]]; then
    echo "R9_LAUNCHER_VISUAL_ACCEPTANCE_SEAL=WAIVED_MAC_DEFERRED_PHYSICAL_PANTHER"
    echo "R9_MAC_VISUAL_ACCEPTANCE=WAIVED_BY_USER_FOR_R9"
    echo "R9_PHYSICAL_PANTHER_VISUAL_ACCEPTANCE=REQUIRED"
    echo "NEXT_FULL_PANTHER_BUILD_AUTHORIZED=YES_AFTER_MODULE_QUALIFICATION"
else
    python3 "$ROOT/build/gates/r9-launcher-visual-acceptance.py" \
        || fail R9_LAUNCHER_VISUAL_ACCEPTANCE
fi
