#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

OUT="${1:-$ROOT/apps/r8/out/panther-bundle}"
READER_APK="${SABLE_READER_APK:-}"

mkdir -p "$OUT/prebuilt"
rm -f "$OUT/prebuilt/"*.apk "$OUT/manifest.tsv" "$OUT/SHA256SUMS.txt"

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
    [org.sableos.reader]=SableReader.apk
)

declare -a candidates=()

while IFS= read -r -d '' apk; do
    candidates+=("$apk")
done < <(
    find "$ROOT/apps/r8/android"         -type f         -path '*/build/outputs/apk/*'         -name '*.apk'         -print0
)

if [[ -n "$READER_APK" ]]; then
    [[ -f "$READER_APK" ]] || {
        echo "R8_READER_APK=FAIL_MISSING path=$READER_APK"
        exit 3
    }
    candidates+=("$READER_APK")
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

for pkg in     org.sableos.calculator     org.sableos.sudoku     org.sableos.minesweeper     org.sableos.game2048     org.sableos.media     org.sableos.reader
do
    apk="${resolved[$pkg]:-}"
    if [[ -z "$apk" ]]; then
        echo "R8_BUNDLE_PACKAGE=FAIL_MISSING package=$pkg"
        if [[ "$pkg" == org.sableos.reader ]]; then
            echo "Set SABLE_READER_APK to the qualified composed Reader APK."
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
echo "R8_APP_BUNDLE=PASS"
