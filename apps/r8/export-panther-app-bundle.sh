#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

OUT="${1:-$ROOT/apps/r8/out/panther-bundle}"
TEXTREADER_APK="${SABLE_TEXTREADER_APK:-}"
READER_APK="${SABLE_READER_APK:-}"
MAIL_APK="${SABLE_MAIL_APK:-}"
SOURCE_IDENTITY="$OUT/SABLEOS_SOURCE_COMMIT.txt"

SOURCE_COMMIT="$(git -C "$ROOT" rev-parse HEAD)"
if ! git -C "$ROOT" diff --quiet || ! git -C "$ROOT" diff --cached --quiet; then
    echo "R8_BUNDLE_SOURCE_TREE=FAIL_TRACKED_DIRT"
    git -C "$ROOT" status --short
    exit 3
fi
echo "R8_BUNDLE_SOURCE_TREE=PASS"
echo "R8_BUNDLE_SOURCE_COMMIT=$SOURCE_COMMIT"

mkdir -p "$OUT/prebuilt"
rm -f "$OUT/prebuilt/"*.apk "$OUT/manifest.tsv" "$OUT/SHA256SUMS.txt" "$SOURCE_IDENTITY"
printf '%s\n' "$SOURCE_COMMIT" > "$SOURCE_IDENTITY"

APKANALYZER="${APKANALYZER:-$(command -v apkanalyzer || true)}"
if [[ -z "$APKANALYZER" ]]; then
    echo "R8_BUNDLE_APKANALYZER=FAIL"
    echo "Set APKANALYZER to the Android SDK apkanalyzer executable."
    exit 2
fi

declare -A expected=(
    [org.sableos.calculator]=SableCalculator.apk
    [org.sableos.sudoku]=SableSudoku.apk
    [org.sableos.minesweeper]=SableMinesweeper.apk
    [org.sableos.game2048]=Sable2048.apk
    [org.sableos.media]=SableMedia.apk
    [org.sableos.textreader]=SableTextReader.apk
    [org.sableos.reader]=SableReader.apk
    [org.sableos.hub]=SableHub.apk
    [org.sableos.mail]=SableMail.apk
    [org.sableos.weather]=SableWeather.apk
    [org.sableos.calendar]=SableCalendar.apk
)

declare -a candidates=()

# Explicit build outputs only. Do not recursively scan the standalone build tree:
# stale variant APKs must never become accidental Panther bundle candidates.
for apk in \
    "$ROOT/apps/r8/android/calculator/build/outputs/apk/debug/calculator-debug.apk" \
    "$ROOT/apps/r8/android/games/build/outputs/apk/sudoku/debug/games-sudoku-debug.apk" \
    "$ROOT/apps/r8/android/games/build/outputs/apk/minesweeper/debug/games-minesweeper-debug.apk" \
    "$ROOT/apps/r8/android/games/build/outputs/apk/game2048/debug/games-game2048-debug.apk" \
    "$ROOT/apps/r8/android/media/build/outputs/apk/debug/media-debug.apk" \
    "$ROOT/apps/r8/android/hub/build/outputs/apk/debug/hub-debug.apk" \
    "$ROOT/apps/r8/android/weather/build/outputs/apk/debug/weather-debug.apk" \
    "$ROOT/apps/r8/android/calendar/build/outputs/apk/debug/calendar-debug.apk"
do
    if [[ -f "$apk" ]]; then
        candidates+=("$apk")
    fi
done

if [[ -n "$TEXTREADER_APK" ]]; then
    [[ -f "$TEXTREADER_APK" ]] || {
        echo "R9_TEXTREADER_APK=FAIL_MISSING path=$TEXTREADER_APK"
        exit 3
    }
    candidates+=("$TEXTREADER_APK")
fi

if [[ -n "$READER_APK" ]]; then
    [[ -f "$READER_APK" ]] || {
        echo "R8_READER_APK=FAIL_MISSING path=$READER_APK"
        exit 3
    }
    candidates+=("$READER_APK")
fi

if [[ -n "$MAIL_APK" ]]; then
    [[ -f "$MAIL_APK" ]] || {
        echo "R8_MAIL_APK=FAIL_MISSING path=$MAIL_APK"
        exit 3
    }
    candidates+=("$MAIL_APK")
fi

if [[ ${#candidates[@]} -eq 0 ]]; then
    echo "R8_BUNDLE_CANDIDATES=FAIL_NONE"
    exit 4
fi

declare -A resolved=()

for apk in "${candidates[@]}"; do
    pkg="$("$APKANALYZER" manifest application-id "$apk" 2>/dev/null || true)"
    [[ -n "$pkg" ]] || continue

    if [[ -n "${expected[$pkg]:-}" ]]; then
        if [[ -n "${resolved[$pkg]:-}" ]]; then
            echo "R8_BUNDLE_DUPLICATE_PACKAGE=FAIL package=$pkg"
            echo "candidate_1=${resolved[$pkg]}"
            echo "candidate_2=$apk"
            exit 5
        fi
        resolved[$pkg]="$apk"
    fi
done

printf 'package\tfilename\tsha256\tsize_bytes\tsource\n' > "$OUT/manifest.tsv"

for pkg in     org.sableos.calculator     org.sableos.sudoku     org.sableos.minesweeper     org.sableos.game2048     org.sableos.media     org.sableos.textreader     org.sableos.reader     org.sableos.hub     org.sableos.mail     org.sableos.weather     org.sableos.calendar
do
    apk="${resolved[$pkg]:-}"
    if [[ -z "$apk" ]]; then
        echo "R8_BUNDLE_PACKAGE=FAIL_MISSING package=$pkg"
        if [[ "$pkg" == org.sableos.textreader ]]; then
            echo "Set SABLE_TEXTREADER_APK to the qualified standalone Text Reader APK."
        elif [[ "$pkg" == org.sableos.reader ]]; then
            echo "Set SABLE_READER_APK to the qualified Reader APK."
        elif [[ "$pkg" == org.sableos.mail ]]; then
            echo "Set SABLE_MAIL_APK to the qualified composed Sable Mail APK."
        fi
        exit 6
    fi

    filename="${expected[$pkg]}"
    dest="$OUT/prebuilt/$filename"
    install -m 0644 "$apk" "$dest"

    staged_pkg="$("$APKANALYZER" manifest application-id "$dest")"
    [[ "$staged_pkg" == "$pkg" ]] || {
        echo "R8_BUNDLE_PACKAGE_IDENTITY=FAIL file=$filename expected=$pkg actual=$staged_pkg"
        exit 7
    }

    digest="$(sha256sum "$dest" | awk '{print $1}')"
    size="$(stat -c '%s' "$dest")"
    printf '%s\t%s\t%s\t%s\t%s\n'         "$pkg" "$filename" "$digest" "$size" "$apk"         >> "$OUT/manifest.tsv"

    echo "R8_BUNDLE_PACKAGE=PASS package=$pkg file=$filename sha256=$digest"
done

(
    cd "$OUT/prebuilt"
    sha256sum ./*.apk
) > "$OUT/SHA256SUMS.txt"

(
    cd "$OUT/prebuilt"
    sha256sum -c "$OUT/SHA256SUMS.txt"
)

echo "R8_APP_BUNDLE_DIR=$OUT"
echo "R8_APP_BUNDLE_MANIFEST=$OUT/manifest.tsv"
echo "R8_APP_BUNDLE_SHA256SUMS=$OUT/SHA256SUMS.txt"
echo "R8_APP_BUNDLE_SOURCE_IDENTITY=$SOURCE_IDENTITY"
echo "R8_APP_BUNDLE_SOURCE_COMMIT=$SOURCE_COMMIT"
echo "R8_APP_BUNDLE=PASS"
