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
BUNDLE_SOURCE_IDENTITY="$R8_APP_BUNDLE/SABLEOS_SOURCE_COMMIT.txt"
BUNDLE_PREBUILT="$R8_APP_BUNDLE/prebuilt"

for f in "$BUNDLE_MANIFEST" "$BUNDLE_SUMS" "$BUNDLE_SOURCE_IDENTITY"; do
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

CURRENT_SOURCE_COMMIT="$(git -C "$ROOT" rev-parse HEAD)"
BUNDLE_SOURCE_COMMIT="$(tr -d '[:space:]' < "$BUNDLE_SOURCE_IDENTITY")"

[[ "$BUNDLE_SOURCE_COMMIT" =~ ^[0-9a-f]{40}$ ]] || {
    echo "R8_APP_BUNDLE_SOURCE_COMMIT=FAIL_INVALID value=$BUNDLE_SOURCE_COMMIT"
    exit 7
}

[[ "$BUNDLE_SOURCE_COMMIT" == "$CURRENT_SOURCE_COMMIT" ]] || {
    echo "R8_APP_BUNDLE_SOURCE_COMMIT=FAIL_STALE bundle=$BUNDLE_SOURCE_COMMIT current=$CURRENT_SOURCE_COMMIT"
    exit 7
}

echo "R8_APP_BUNDLE_SOURCE_COMMIT=PASS value=$BUNDLE_SOURCE_COMMIT"

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
    "org.sableos.mail": "SableMail.apk",
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
PRODUCT_MK="$WS/vendor/google_devices/panther/panther.mk"
MARKER_BEGIN="# BEGIN SABLEOS R8 PRODUCT INTEGRATION"
MARKER_END="# END SABLEOS R8 PRODUCT INTEGRATION"
INHERIT_LINE='$(call inherit-product, vendor/sable/r8/r8-product.mk)'

[[ -f "$PRODUCT_MK" ]] || {
    echo "R8_PANTHER_PRODUCT_FILE=FAIL path=$PRODUCT_MK"
    exit 7
}

grep -Eq '^PRODUCT_NAME[[:space:]]*:=[[:space:]]*panther[[:space:]]*$' "$PRODUCT_MK" || {
    echo "R8_PANTHER_PRODUCT_NAME=FAIL path=$PRODUCT_MK"
    exit 8
}

grep -Eq '^PRODUCT_DEVICE[[:space:]]*:=[[:space:]]*panther[[:space:]]*$' "$PRODUCT_MK" || {
    echo "R8_PANTHER_PRODUCT_DEVICE=FAIL path=$PRODUCT_MK"
    exit 9
}

PRODUCT_MK_SHA256_BEFORE="$(sha256sum "$PRODUCT_MK" | awk '{print $1}')"
echo "R8_PANTHER_PRODUCT_FILE=$PRODUCT_MK"
echo "R8_PANTHER_PRODUCT_SHA256_BEFORE=$PRODUCT_MK_SHA256_BEFORE"

marker_count="$(grep -Fc "$MARKER_BEGIN" "$PRODUCT_MK" || true)"
inherit_count="$(grep -Fc "$INHERIT_LINE" "$PRODUCT_MK" || true)"

if [[ "$marker_count" -gt 1 ]]; then
    echo "R8_PRODUCT_INCLUDE=FAIL_DUPLICATE_MARKER"
    exit 10
fi

if [[ "$marker_count" -eq 0 ]]; then
    [[ "$inherit_count" -eq 0 ]] || {
        echo "R8_PRODUCT_INCLUDE=FAIL_UNMARKED_EXISTING_INCLUDE count=$inherit_count"
        exit 11
    }

    cat >> "$PRODUCT_MK" <<EOF

$MARKER_BEGIN
$INHERIT_LINE
$MARKER_END
EOF
    echo "R8_PRODUCT_INCLUDE=APPLIED"
else
    block="$(
        sed -n "/^$MARKER_BEGIN$/,/^$MARKER_END$/p" "$PRODUCT_MK"
    )"
    expected_block="$MARKER_BEGIN
$INHERIT_LINE
$MARKER_END"
    [[ "$block" == "$expected_block" ]] || {
        echo "R8_PRODUCT_INCLUDE=FAIL_EXISTING_BLOCK_MISMATCH"
        exit 12
    }
    [[ "$inherit_count" -eq 1 ]] || {
        echo "R8_PRODUCT_INCLUDE=FAIL count=$inherit_count"
        exit 13
    }
    echo "R8_PRODUCT_INCLUDE=ALREADY_APPLIED"
fi

mkdir -p "$DEST/prebuilt"
rm -f "$DEST/prebuilt/"*.apk

install -m 0644     "$ROOT/product/r8/panther/Android.bp"     "$DEST/Android.bp"
install -m 0644     "$ROOT/product/r8/panther/r8-product.mk"     "$DEST/r8-product.mk"
install -m 0644     "$BUNDLE_MANIFEST"     "$DEST/manifest.tsv"
install -m 0644     "$BUNDLE_SUMS"     "$DEST/SHA256SUMS.txt"
install -m 0644     "$BUNDLE_SOURCE_IDENTITY"     "$DEST/SABLEOS_SOURCE_COMMIT.txt"

for apk in     SableCalculator.apk     SableSudoku.apk     SableMinesweeper.apk     Sable2048.apk     SableMedia.apk     SableReader.apk     SableHub.apk     SableMail.apk
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
cmp -s "$BUNDLE_SOURCE_IDENTITY" "$DEST/SABLEOS_SOURCE_COMMIT.txt" || {
    echo "R8_PRODUCT_SOURCE_IDENTITY=FAIL"
    exit 14
}

include_count="$(grep -Fc "$INHERIT_LINE" "$PRODUCT_MK" || true)"
[[ "$include_count" -eq 1 ]] || {
    echo "R8_PRODUCT_INCLUDE=FAIL count=$include_count"
    exit 15
}

PRODUCT_MK_SHA256_AFTER="$(sha256sum "$PRODUCT_MK" | awk '{print $1}')"
echo "R8_PANTHER_PRODUCT_SHA256_AFTER=$PRODUCT_MK_SHA256_AFTER"

echo "R8_PRODUCT_ANDROID_BP=PASS"
echo "R8_PRODUCT_MK=PASS"
echo "R8_PRODUCT_MANIFEST=PASS"
echo "R8_PRODUCT_SOURCE_IDENTITY=PASS"
echo "R8_STAGED_PREBUILT_HASHES=PASS"
echo "R8_PRODUCT_INCLUDE=PASS"
echo "R8_PRODUCT_STAGE=PASS"
echo "R8_PRODUCT_DEST=$DEST"
