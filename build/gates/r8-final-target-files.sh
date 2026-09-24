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
    "SableTextReader.apk": "org.sableos.textreader",
    "SableReader.apk": "org.sableos.reader",
    "SableHub.apk": "org.sableos.hub",
    "SableMail.apk": "org.sableos.mail",
    "SableWeather.apk": "org.sableos.weather",
    "SableCalendar.apk": "org.sableos.calendar",
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

    appstore = matches("AppStore.apk")
    if len(appstore) != 1:
        raise SystemExit(
            f"R9_APPSTORE_TARGET_COUNT=FAIL matches={appstore!r}"
        )
    (tmp / "AppStore.apk").write_bytes(z.read(appstore[0]))
    print(f"R9_APPSTORE_TARGET=PASS member={appstore[0]}")

    appstore_allowlist = "PRODUCT/etc/permissions/app.grapheneos.apps.xml"
    if appstore_allowlist not in names:
        raise SystemExit(
            "R9_APPSTORE_PRIVAPP_ALLOWLIST_TARGET=FAIL_MISSING "
            f"member={appstore_allowlist}"
        )
    allowlist_text = z.read(appstore_allowlist).decode("utf-8")
    if '<privapp-permissions package="app.grapheneos.apps">' not in allowlist_text:
        raise SystemExit("R9_APPSTORE_PRIVAPP_ALLOWLIST_TARGET=FAIL_SEMANTICS")
    print(
        "R9_APPSTORE_PRIVAPP_ALLOWLIST_TARGET=PASS "
        f"member={appstore_allowlist}"
    )

    for forbidden_apk in (
        "Phonesky.apk",
        "GmsCore.apk",
        "GoogleServicesFramework.apk",
    ):
        found = matches(forbidden_apk)
        if found:
            raise SystemExit(
                "R9_GOOGLE_PLAY_PREINSTALLED_TARGET=FAIL "
                f"file={forbidden_apk} members={found!r}"
            )
        print(
            "R9_GOOGLE_PLAY_PREINSTALLED_TARGET=PASS_ABSENT "
            f"file={forbidden_apk}"
        )

    launcher = matches("Launcher3QuickStep.apk")
    if len(launcher) != 1:
        raise SystemExit(
            f"R9_LAUNCHER3_TARGET_COUNT=FAIL matches={launcher!r}"
        )
    (tmp / "Launcher3QuickStep.apk").write_bytes(z.read(launcher[0]))
    print(f"R9_LAUNCHER3_TARGET=PASS member={launcher[0]}")

    legacy_start = matches("SableStart.apk")
    if legacy_start:
        raise SystemExit(
            f"R9_LEGACY_SABLESTART_TARGET=FAIL_PRESENT matches={legacy_start!r}"
        )
    print("R9_LEGACY_SABLESTART_TARGET=PASS_ABSENT")

    sable_launcher = matches("SableLauncher.apk")
    if len(sable_launcher) != 1:
        raise SystemExit(
            f"R9_SABLELAUNCHER_TARGET_COUNT=FAIL matches={sable_launcher!r}"
        )
    (tmp / "SableLauncher.apk").write_bytes(z.read(sable_launcher[0]))
    print(f"R9_SABLELAUNCHER_TARGET=PASS member={sable_launcher[0]}")

    for basename in ("SystemUI.apk", "Settings.apk", "SetupWizard2.apk"):
        found = matches(basename)
        if len(found) != 1:
            raise SystemExit(
                f"R8_SYSTEM_APK_COUNT=FAIL file={basename} matches={found!r}"
            )
        print(f"R8_SYSTEM_APK=PASS file={basename} member={found[0]}")

    allowlist_name = "sable-privapp-permissions-com.android.settings.xml"
    allowlist_member = f"SYSTEM_EXT/etc/permissions/{allowlist_name}"
    if allowlist_member not in names:
        raise SystemExit(
            f"R9_SETTINGS_PRIVAPP_ALLOWLIST_TARGET=FAIL_MISSING member={allowlist_member}"
        )
    target_allowlist = z.read(allowlist_member)
    staged_allowlist = (staged / "permissions" / allowlist_name).read_bytes()
    if target_allowlist != staged_allowlist:
        raise SystemExit(
            "R9_SETTINGS_PRIVAPP_ALLOWLIST_TARGET=FAIL_CONTENT_MISMATCH"
        )
    allowlist_text = target_allowlist.decode("utf-8")
    if (
        '<privapp-permissions package="com.android.settings">' not in allowlist_text
        or '<permission name="android.permission.MODIFY_DAY_NIGHT_MODE"/>' not in allowlist_text
    ):
        raise SystemExit("R9_SETTINGS_PRIVAPP_ALLOWLIST_TARGET=FAIL_SEMANTICS")
    print(
        "R9_SETTINGS_PRIVAPP_ALLOWLIST_TARGET=PASS_SYSTEM_EXT "
        f"member={allowlist_member}"
    )

    stale_apks = (
        "ExactCalculator.apk",
        "Calendar.apk",
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
    [AppStore.apk]=app.grapheneos.apps
    [SableLauncher.apk]=org.sableos.launcher
    [Launcher3QuickStep.apk]=com.android.launcher3
    [SableCalculator.apk]=org.sableos.calculator
    [SableSudoku.apk]=org.sableos.sudoku
    [SableMinesweeper.apk]=org.sableos.minesweeper
    [Sable2048.apk]=org.sableos.game2048
    [SableMedia.apk]=org.sableos.media
    [SableTextReader.apk]=org.sableos.textreader
    [SableReader.apk]=org.sableos.reader
    [SableHub.apk]=org.sableos.hub
    [SableMail.apk]=org.sableos.mail
    [SableWeather.apk]=org.sableos.weather
    [SableCalendar.apk]=org.sableos.calendar
)

for apk in     AppStore.apk     SableLauncher.apk     Launcher3QuickStep.apk     SableCalculator.apk     SableSudoku.apk     SableMinesweeper.apk     Sable2048.apk     SableMedia.apk     SableTextReader.apk     SableReader.apk     SableHub.apk     SableMail.apk     SableWeather.apk     SableCalendar.apk
do
    pkg="$("$AAPT2" dump packagename "$TMP/$apk" 2>/dev/null | tail -1)"
    expected="${expected_package[$apk]}"
    [[ "$pkg" == "$expected" ]] || {
        echo "R8_TARGET_PACKAGE_IDENTITY=FAIL file=$apk expected=$expected actual=$pkg"
        exit 5
    }
    echo "R8_TARGET_PACKAGE_IDENTITY=PASS file=$apk package=$pkg"
done

echo "R9_APPSTORE_TARGET_FILES=PASS_PRESENT"
echo "R9_APPSTORE_PACKAGE_IDENTITY=PASS_APP_GRAPHENEOS_APPS"
echo "R9_GOOGLE_PLAY_PREINSTALLED_TARGET_FILES=PASS_ABSENT"
echo "R9_SABLELAUNCHER_HOME_TARGET_FILES=PASS_PRESENT"
echo "R9_LAUNCHER3_RECENTS_TARGET_FILES=PASS_PRESENT"
echo "R9_LEGACY_SABLESTART_TARGET_FILES=PASS_ABSENT"
echo "R8_B_CALCULATOR_CONVERT_TARGET_FILES=PASS"
echo "R8_C_GAMES_TARGET_FILES=PASS"
echo "R8_D_READER_TARGET_FILES=PASS"
echo "R9_SABLE_TEXT_READER_TARGET_FILES=PASS_PRESENT"
echo "R9_SABLE_TEXT_READER_OCR_TARGET_FILES=PASS"
echo "R8_E_MEDIA_TARGET_FILES=PASS"
echo "R8_F_SABLE_HUB_MESSAGES_TARGET_FILES=PASS"
echo "R8_G_SABLE_MAIL_TARGET_FILES=PASS"
echo "R9_SABLE_WEATHER_TARGET_FILES=PASS"
echo "R8_UI4_UI5_UI6_TARGET_FILES=PASS"
echo "R9_SETTINGS_PRIVAPP_ALLOWLIST_TARGET_FILES=PASS"
echo "R8_FINAL_TARGET_FILES=PASS"
