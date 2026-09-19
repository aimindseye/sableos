#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT/build/config/panther-grapheneos-2026081300.env"

WS="${WS:-$SABLEOS_UPSTREAM}"
DEST="$WS/vendor/sable/r8"
DEVICE_MK="$WS/device/google/pantah/device-panther.mk"

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

echo
echo "===== SHARED DESIGN WORKSPACE FIDELITY ====="

diff -qr     "$ROOT/src/android/shared/sabledesign"     "$WS/packages/apps/SableDesign"     >/dev/null || fail R8_SABLE_DESIGN_WORKSPACE_FIDELITY

echo "R8_SABLE_DESIGN_WORKSPACE_FIDELITY=PASS"

echo
echo "===== SABLE START WORKSPACE FIDELITY ====="

python3 -     "$ROOT/src/android/packages/apps/SableStart"     "$WS/packages/apps/SableStart" <<'PY'
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
echo "R8_START_PRODUCT_INTEGRATION=PASS"

echo
echo "===== SYSTEM SURFACE SOURCE GATES ====="

python3     "$ROOT/patches/android-17-grapheneos-2026081300/apply_sable_branding.py"     --source "$WS" verify     || fail R8_BRANDING_SOURCE

python3     "$ROOT/patches/android-17-grapheneos-2026081300/apply_ui4_systemui.py"     --source "$WS" verify     || fail R8_UI4_SYSTEMUI_SOURCE

python3     "$ROOT/patches/android-17-grapheneos-2026081300/apply_ui5a_settings.py"     --source "$WS" verify     || fail R8_UI5A_SETTINGS_SOURCE

python3     "$ROOT/patches/android-17-grapheneos-2026081300/apply_ui5b_app_security.py"     --source "$WS" verify     || fail R8_UI5B_APP_SECURITY_SOURCE

python3     "$ROOT/patches/android-17-grapheneos-2026081300/apply_ui5c_ui6_system_surfaces.py"     --source "$WS" verify     || fail R8_UI5C_UI6_SYSTEM_SURFACES_SOURCE

echo "R8_SYSTEM_SURFACE_SOURCE_GATES=PASS"

echo
echo "===== FIRST-PARTY PRODUCT INTEGRATION ====="

[[ -d "$DEST" ]] || fail R8_PRODUCT_STAGE_DIRECTORY
[[ -f "$DEST/Android.bp" ]] || fail R8_PRODUCT_ANDROID_BP
[[ -f "$DEST/r8-product.mk" ]] || fail R8_PRODUCT_MK
[[ -f "$DEST/manifest.tsv" ]] || fail R8_PRODUCT_MANIFEST
[[ -f "$DEST/SHA256SUMS.txt" ]] || fail R8_PRODUCT_SHA256SUMS

cmp -s     "$ROOT/product/r8/panther/Android.bp"     "$DEST/Android.bp"     || fail R8_PRODUCT_ANDROID_BP

cmp -s     "$ROOT/product/r8/panther/r8-product.mk"     "$DEST/r8-product.mk"     || fail R8_PRODUCT_MK

(
    cd "$DEST/prebuilt"
    sha256sum -c "$DEST/SHA256SUMS.txt"
) || fail R8_PRODUCT_PREBUILT_HASHES

if ! python3 - "$DEST/manifest.tsv" <<'PY'
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
}

with pathlib.Path(sys.argv[1]).open(newline="", encoding="utf-8") as f:
    rows = list(csv.DictReader(f, delimiter="\t"))

actual = {row["package"]: row["filename"] for row in rows}

if actual != expected or len(rows) != len(expected):
    print(f"R8_PRODUCT_PACKAGE_SET=FAIL actual={actual!r}")
    raise SystemExit(1)

print("R8_PRODUCT_PACKAGE_SET=PASS")
PY
then
    fail R8_PRODUCT_PACKAGE_SET
fi

INHERIT_LINE='$(call inherit-product, vendor/sable/r8/r8-product.mk)'
include_count="$(grep -Fc "$INHERIT_LINE" "$DEVICE_MK" || true)"
[[ "$include_count" -eq 1 ]] || fail R8_PRODUCT_INCLUDE

grep -Fq 'overrides: ["ExactCalculator"]' "$DEST/Android.bp"     || fail R8_EXACT_CALCULATOR_REPLACEMENT

for module in     SableStart     SableCalculator     SableSudoku     SableMinesweeper     Sable2048     SableMedia     SableReader
do
    grep -Fq "$module" "$DEST/r8-product.mk"         || fail "R8_PRODUCT_MODULE_${module}"
done

echo "R8_PRODUCT_INCLUDE=PASS"
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
echo "===== FINAL COMPOSITION RESULT ====="
echo "R8_A_SHARED_DESIGN=PASS"
echo "R8_START_PRODUCT_INTEGRATION=PASS"
echo "R8_B_CALCULATOR_CONVERT=PASS_PRODUCT_STAGED"
echo "R8_C_GAMES=PASS_PRODUCT_STAGED"
echo "R8_D_READER_PUBLICATION=PASS_PRODUCT_STAGED"
echo "R8_D2_READER_TEXT_ACCESSIBILITY_OCR=PASS_SOURCE_AND_PRODUCT_STAGED"
echo "R8_E_MEDIA=PASS_PRODUCT_STAGED"
echo "R8_UI4_SYSTEMUI=PASS_SOURCE"
echo "R8_UI5_SETTINGS=PASS_SOURCE"
echo "R8_UI5C_UI6_SYSTEM_SURFACES=PASS_SOURCE"
echo "R8_FINAL_UI_PRODUCT_COMPOSITION=PASS"
echo "NEXT_FULL_PANTHER_BUILD_AUTHORIZED=YES"
