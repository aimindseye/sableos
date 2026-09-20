#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT/build/config/r8-release.env"
source "$ROOT/build/config/panther-grapheneos-2026081300.env"

WS="${WS:-$SABLEOS_UPSTREAM}"
OUT="${OUT_DIR:-out_sable_ui_final_qual}"
TF="${TF:-}"

if [[ "$OUT" != /* ]]; then
    OUT_ABS="$WS/$OUT"
else
    OUT_ABS="$OUT"
fi

if [[ -z "$TF" ]]; then
    TF="$(
        find "$OUT_ABS/target/product/panther/obj/PACKAGING/target_files_intermediates"             -maxdepth 1             -type f             \( -name '*target_files*.zip' -o -name '*target-files*.zip' \)             -printf '%T@ %p\n' 2>/dev/null             | sort -nr             | head -n1             | cut -d' ' -f2-
    )"
fi

fail() {
    echo "$1=FAIL"
    echo "R8_FINAL_TARGET_FILES=FAIL"
    exit "${2:-1}"
}

echo "===== R8 FINAL TARGET-FILES UI COMPOSITION GATE ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "BUILD_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "TARGET_FILES=$TF"

[[ -n "$TF" && -f "$TF" ]] || fail R8_TARGET_FILES 2

STAGED="$WS/vendor/sable/r8"
[[ -f "$STAGED/manifest.tsv" ]] || fail R8_STAGED_MANIFEST 3
[[ -f "$STAGED/SHA256SUMS.txt" ]] || fail R8_STAGED_SHA256SUMS 3

echo "TARGET_FILES_SHA256=$(sha256sum "$TF" | awk '{print $1}')"

TMP="$(mktemp -d -t sable-r8-target-files-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

python3 - "$TF" "$STAGED" "$TMP" <<'PY'
import csv
import hashlib
import pathlib
import sys
import zipfile

tf = pathlib.Path(sys.argv[1])
staged = pathlib.Path(sys.argv[2])
tmp = pathlib.Path(sys.argv[3])

expected_packages = {
    "SableCalculator.apk": "org.sableos.calculator",
    "SableSudoku.apk": "org.sableos.sudoku",
    "SableMinesweeper.apk": "org.sableos.minesweeper",
    "Sable2048.apk": "org.sableos.game2048",
    "SableMedia.apk": "org.sableos.media",
    "SableReader.apk": "org.sableos.reader",
    "SableHub.apk": "org.sableos.hub",
    "SableMail.apk": "org.sableos.mail",
}

with (staged / "manifest.tsv").open(newline="", encoding="utf-8") as f:
    rows = list(csv.DictReader(f, delimiter="\t"))
manifest_by_file = {row["filename"]: row for row in rows}

if set(manifest_by_file) != set(expected_packages):
    raise SystemExit(
        f"R8_STAGED_MANIFEST_SET=FAIL files={sorted(manifest_by_file)!r}"
    )

with zipfile.ZipFile(tf) as z:
    names = z.namelist()

    def matches(basename):
        return [name for name in names if name.endswith("/" + basename)]

    for basename, package in expected_packages.items():
        found = matches(basename)
        if len(found) != 1:
            raise SystemExit(
                f"R8_TARGET_APK_COUNT=FAIL file={basename} matches={found!r}"
            )

        data = z.read(found[0])
        digest = hashlib.sha256(data).hexdigest()
        expected_digest = manifest_by_file[basename]["sha256"]

        if digest != expected_digest:
            raise SystemExit(
                f"R8_TARGET_APK_HASH=FAIL file={basename} "
                f"expected={expected_digest} actual={digest}"
            )

        out = tmp / basename
        out.write_bytes(data)
        print(
            f"R8_TARGET_APK=PASS package={package} "
            f"member={found[0]} sha256={digest}"
        )

    launcher = matches("Launcher3QuickStep.apk")
    if len(launcher) != 1:
        raise SystemExit(
            f"R9_LAUNCHER3_TARGET_COUNT=FAIL matches={launcher!r}"
        )
    (tmp / "Launcher3QuickStep.apk").write_bytes(z.read(launcher[0]))
    print(f"R9_LAUNCHER3_TARGET=PASS member={launcher[0]}")

    start = matches("SableStart.apk")
    if start:
        raise SystemExit(
            f"R9_SABLESTART_TARGET=FAIL_PRESENT matches={start!r}"
        )
    print("R9_SABLESTART_TARGET=PASS_ABSENT")

    for basename in ("SystemUI.apk", "Settings.apk", "SetupWizard2.apk"):
        found = matches(basename)
        if len(found) != 1:
            raise SystemExit(
                f"R8_SYSTEM_APK_COUNT=FAIL file={basename} matches={found!r}"
            )
        print(f"R8_SYSTEM_APK=PASS file={basename} member={found[0]}")

    stale_apks = (
        "ExactCalculator.apk",
        "SableConvert.apk",
        "SableConverter.apk",
        "SableGames.apk",
        "VaachakTextReader.apk",
        "TextReader.apk",
        "Thunderbird.apk",
        "K9Mail.apk",
        "k9mail.apk",
    )
    for basename in stale_apks:
        legacy = matches(basename)
        if legacy:
            raise SystemExit(
                f"R8_STALE_PRODUCT_APK=FAIL file={basename} members={legacy!r}"
            )
        print(f"R8_STALE_PRODUCT_APK=PASS_ABSENT file={basename}")
PY

AAPT2="${AAPT2:-$OUT_ABS/host/linux-x86/bin/aapt2}"
[[ -x "$AAPT2" ]] || fail R8_AAPT2 4

declare -A expected_package=(
    [Launcher3QuickStep.apk]=com.android.launcher3
    [SableCalculator.apk]=org.sableos.calculator
    [SableSudoku.apk]=org.sableos.sudoku
    [SableMinesweeper.apk]=org.sableos.minesweeper
    [Sable2048.apk]=org.sableos.game2048
    [SableMedia.apk]=org.sableos.media
    [SableReader.apk]=org.sableos.reader
    [SableHub.apk]=org.sableos.hub
    [SableMail.apk]=org.sableos.mail
)

for apk in     Launcher3QuickStep.apk     SableCalculator.apk     SableSudoku.apk     SableMinesweeper.apk     Sable2048.apk     SableMedia.apk     SableReader.apk     SableHub.apk     SableMail.apk
do
    pkg="$("$AAPT2" dump packagename "$TMP/$apk" 2>/dev/null | tail -1)"
    expected="${expected_package[$apk]}"
    [[ "$pkg" == "$expected" ]] || {
        echo "R8_TARGET_PACKAGE_IDENTITY=FAIL file=$apk expected=$expected actual=$pkg"
        exit 5
    }
    echo "R8_TARGET_PACKAGE_IDENTITY=PASS file=$apk package=$pkg"
done

echo "R9_LAUNCHER3_HOME_TARGET_FILES=PASS"
echo "R9_SABLESTART_TARGET_FILES=PASS_ABSENT"
echo "R8_B_CALCULATOR_CONVERT_TARGET_FILES=PASS"
echo "R8_C_GAMES_TARGET_FILES=PASS"
echo "R8_D_READER_TARGET_FILES=PASS"
echo "R8_D2_READER_OCR_TARGET_FILES=PASS"
echo "R8_E_MEDIA_TARGET_FILES=PASS"
echo "R8_F_SABLE_HUB_MESSAGES_TARGET_FILES=PASS"
echo "R8_G_SABLE_MAIL_TARGET_FILES=PASS"
echo "R8_UI4_UI5_UI6_TARGET_FILES=PASS"
echo "R8_FINAL_TARGET_FILES=PASS"
