#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT/build/config/panther-grapheneos-2026081300.env"

SOURCE_MUTATION_AUTHORIZED="${SOURCE_MUTATION_AUTHORIZED:-NO}"
R8_APP_BUNDLE="${R8_APP_BUNDLE:-${1:-}}"

if [[ "$SOURCE_MUTATION_AUTHORIZED" != YES ]]; then
    echo "R8_PRODUCT_STAGE=REFUSED_SOURCE_MUTATION_NOT_AUTHORIZED"
    exit 2
fi

if [[ -z "$R8_APP_BUNDLE" || ! -d "$R8_APP_BUNDLE" ]]; then
    echo "R8_APP_BUNDLE=FAIL_MISSING"
    exit 3
fi

WS="$SABLEOS_UPSTREAM"
[[ -d "$WS/.repo" ]] || {
    echo "R8_ANDROID_WORKSPACE=FAIL path=$WS"
    exit 4
}

BUNDLE_MANIFEST="$R8_APP_BUNDLE/manifest.tsv"
BUNDLE_SUMS="$R8_APP_BUNDLE/SHA256SUMS.txt"
BUNDLE_PREBUILT="$R8_APP_BUNDLE/prebuilt"

for f in "$BUNDLE_MANIFEST" "$BUNDLE_SUMS"; do
    [[ -f "$f" ]] || {
        echo "R8_APP_BUNDLE_CONTROL_FILE=FAIL path=$f"
        exit 5
    }
done

(
    cd "$BUNDLE_PREBUILT"
    sha256sum -c "$BUNDLE_SUMS"
) || {
    echo "R8_APP_BUNDLE_HASHES=FAIL"
    exit 6
}
echo "R8_APP_BUNDLE_HASHES=PASS"

python3 - "$BUNDLE_MANIFEST" <<'PY'
import csv
import pathlib
import sys

manifest = pathlib.Path(sys.argv[1])
expected = {
    "org.sableos.calculator": "SableCalculator.apk",
    "org.sableos.sudoku": "SableSudoku.apk",
    "org.sableos.minesweeper": "SableMinesweeper.apk",
    "org.sableos.game2048": "Sable2048.apk",
    "org.sableos.media": "SableMedia.apk",
    "org.sableos.reader": "SableReader.apk",
    "org.sableos.hub": "SableHub.apk",
}

with manifest.open(newline="", encoding="utf-8") as f:
    rows = list(csv.DictReader(f, delimiter="\t"))

seen = {}
for row in rows:
    package = row.get("package", "")
    filename = row.get("filename", "")
    if package in seen:
        raise SystemExit(f"R8_BUNDLE_MANIFEST_DUPLICATE={package}")
    seen[package] = filename

if seen != expected:
    raise SystemExit(
        "R8_BUNDLE_MANIFEST_SET=FAIL "
        f"expected={expected!r} actual={seen!r}"
    )

print("R8_BUNDLE_MANIFEST_SET=PASS")
PY

DEST="$WS/vendor/sable/r8"
DEVICE_MK="$WS/device/google/pantah/device-panther.mk"
MARKER_BEGIN="# BEGIN SABLEOS R8 PRODUCT INTEGRATION"
MARKER_END="# END SABLEOS R8 PRODUCT INTEGRATION"
INHERIT_LINE='$(call inherit-product, vendor/sable/r8/r8-product.mk)'

[[ -f "$DEVICE_MK" ]] || {
    echo "R8_DEVICE_PRODUCT_FILE=FAIL path=$DEVICE_MK"
    exit 7
}

DEVICE_REPO="$WS/device/google/pantah"
DEVICE_HEAD="$(git -C "$DEVICE_REPO" rev-parse HEAD)"
echo "R8_DEVICE_GOOGLE_PANTAH_HEAD=$DEVICE_HEAD"

marker_count="$(grep -Fc "$MARKER_BEGIN" "$DEVICE_MK" || true)"
if [[ "$marker_count" -gt 1 ]]; then
    echo "R8_PRODUCT_INCLUDE=FAIL_DUPLICATE_MARKER"
    exit 8
fi

if [[ "$marker_count" -eq 0 ]]; then
    if ! git -C "$DEVICE_REPO" diff --quiet -- device-panther.mk; then
        echo "R8_DEVICE_PRODUCT_FILE=FAIL_PREEXISTING_DIRT"
        git -C "$DEVICE_REPO" status --short -- device-panther.mk
        exit 9
    fi

    cat >> "$DEVICE_MK" <<EOF

$MARKER_BEGIN
$INHERIT_LINE
$MARKER_END
EOF
    echo "R8_PRODUCT_INCLUDE=APPLIED"
else
    block="$(
        sed -n "/^$MARKER_BEGIN$/,/^$MARKER_END$/p" "$DEVICE_MK"
    )"
    expected_block="$MARKER_BEGIN
$INHERIT_LINE
$MARKER_END"
    [[ "$block" == "$expected_block" ]] || {
        echo "R8_PRODUCT_INCLUDE=FAIL_EXISTING_BLOCK_MISMATCH"
        exit 10
    }
    echo "R8_PRODUCT_INCLUDE=ALREADY_APPLIED"
fi

mkdir -p "$DEST/prebuilt"
rm -f "$DEST/prebuilt/"*.apk

install -m 0644     "$ROOT/product/r8/panther/Android.bp"     "$DEST/Android.bp"
install -m 0644     "$ROOT/product/r8/panther/r8-product.mk"     "$DEST/r8-product.mk"
install -m 0644     "$BUNDLE_MANIFEST"     "$DEST/manifest.tsv"
install -m 0644     "$BUNDLE_SUMS"     "$DEST/SHA256SUMS.txt"

for apk in     SableCalculator.apk     SableSudoku.apk     SableMinesweeper.apk     Sable2048.apk     SableMedia.apk     SableReader.apk     SableHub.apk
do
    install -m 0644         "$BUNDLE_PREBUILT/$apk"         "$DEST/prebuilt/$apk"
done

(
    cd "$DEST/prebuilt"
    sha256sum -c "$DEST/SHA256SUMS.txt"
) || {
    echo "R8_STAGED_PREBUILT_HASHES=FAIL"
    exit 11
}

cmp -s "$ROOT/product/r8/panther/Android.bp" "$DEST/Android.bp" || {
    echo "R8_PRODUCT_ANDROID_BP=FAIL"
    exit 12
}
cmp -s "$ROOT/product/r8/panther/r8-product.mk" "$DEST/r8-product.mk" || {
    echo "R8_PRODUCT_MK=FAIL"
    exit 13
}
cmp -s "$BUNDLE_MANIFEST" "$DEST/manifest.tsv" || {
    echo "R8_PRODUCT_MANIFEST=FAIL"
    exit 14
}

include_count="$(grep -Fc "$INHERIT_LINE" "$DEVICE_MK" || true)"
[[ "$include_count" -eq 1 ]] || {
    echo "R8_PRODUCT_INCLUDE=FAIL count=$include_count"
    exit 15
}

echo "R8_PRODUCT_ANDROID_BP=PASS"
echo "R8_PRODUCT_MK=PASS"
echo "R8_PRODUCT_MANIFEST=PASS"
echo "R8_STAGED_PREBUILT_HASHES=PASS"
echo "R8_PRODUCT_INCLUDE=PASS"
echo "R8_PRODUCT_STAGE=PASS"
echo "R8_PRODUCT_DEST=$DEST"
