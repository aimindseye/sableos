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

APPSTORE_BP="$WS/external/AppStore/Android.bp"
APPSTORE_APK="$WS/external/AppStore/prebuilt/app-release.apk"
APPSTORE_IDSIG="$WS/external/AppStore/prebuilt/app-release.apk.idsig"
APPSTORE_PERMISSIONS="$WS/external/AppStore/permissions/app.grapheneos.apps.xml"
APPSTORE_EXPECTED_SHA256="0247e7ad3f244cf7d79a00b1bc5780cbf195da6484ad6545b4940223ddb24e52"
APPSTORE_IDSIG_EXPECTED_SHA256="bec9d90b6cc574a4a04e3fb37e97eaba7325d4f22e0023712bc321e7ed048080"

for f in "$APPSTORE_BP" "$APPSTORE_APK" "$APPSTORE_IDSIG" "$APPSTORE_PERMISSIONS"; do
    [[ -f "$f" ]] || {
        echo "R9_APPSTORE_UPSTREAM=FAIL_MISSING path=$f"
        exit 4
    }
done

for needle in     'name: "AppStore"'     'product_specific: true'     'privileged: true'     'apk: "prebuilt/app-release.apk"'     'preprocessed: true'     '"privapp-permissions_app.grapheneos.apps.xml"'
do
    grep -Fq "$needle" "$APPSTORE_BP" || {
        echo "R9_APPSTORE_UPSTREAM=FAIL_ANDROID_BP token=$needle"
        exit 4
    }
done

grep -Fq '<privapp-permissions package="app.grapheneos.apps">' "$APPSTORE_PERMISSIONS" || {
    echo "R9_APPSTORE_UPSTREAM=FAIL_PERMISSION_PACKAGE"
    exit 4
}

APPSTORE_ACTUAL_SHA256="$(sha256sum "$APPSTORE_APK" | awk '{print $1}')"
APPSTORE_IDSIG_ACTUAL_SHA256="$(sha256sum "$APPSTORE_IDSIG" | awk '{print $1}')"
[[ "$APPSTORE_ACTUAL_SHA256" == "$APPSTORE_EXPECTED_SHA256" ]] || {
    echo "R9_APPSTORE_UPSTREAM=FAIL_APK_SHA expected=$APPSTORE_EXPECTED_SHA256 actual=$APPSTORE_ACTUAL_SHA256"
    exit 4
}
[[ "$APPSTORE_IDSIG_ACTUAL_SHA256" == "$APPSTORE_IDSIG_EXPECTED_SHA256" ]] || {
    echo "R9_APPSTORE_UPSTREAM=FAIL_IDSIG_SHA expected=$APPSTORE_IDSIG_EXPECTED_SHA256 actual=$APPSTORE_IDSIG_ACTUAL_SHA256"
    exit 4
}
echo "R9_APPSTORE_APK_SHA256=$APPSTORE_ACTUAL_SHA256"
echo "R9_APPSTORE_IDSIG_SHA256=$APPSTORE_IDSIG_ACTUAL_SHA256"
echo "R9_APPSTORE_UPSTREAM=PASS_PINNED_GRAPHENE_MODULE"
echo "R9_GOOGLE_PLAY_PREINSTALLED=NO_USER_OPTIONAL"

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
    "org.sableos.textreader": "SableTextReader.apk",
    "org.sableos.reader": "SableReader.apk",
    "org.sableos.hub": "SableHub.apk",
    "org.sableos.mail": "SableMail.apk",
    "org.sableos.weather": "SableWeather.apk",
    "org.sableos.calendar": "SableCalendar.apk",
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

echo
echo "===== LEGACY SABLE DEVICE PRODUCT RETIREMENT ====="

SOURCE_MUTATION_AUTHORIZED=YES SABLEOS_UPSTREAM="$WS" \
    bash "$ROOT/build/panther/retire-r8-legacy-sable-device-product.sh"

echo
echo "===== LEGACY SABLE VENDOR CONFIG RETIREMENT ====="

SOURCE_MUTATION_AUTHORIZED=YES SABLEOS_UPSTREAM="$WS" \
    bash "$ROOT/build/panther/retire-r8-legacy-vendor-config.sh"

DEST="$WS/vendor/sable/r8"
LEGACY_PARENT="$WS/vendor/sable/prebuilts"
LEGACY_DEST="$LEGACY_PARENT/r8"
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

echo
echo "===== BOUNDED LEGACY R8 PRODUCT TREE RETIREMENT ====="
echo "LEGACY_PRODUCT_TREE_REMOVAL_AUTHORIZED=YES_EXACT_PATH_ONLY"
echo "LEGACY_PRODUCT_TREE=$LEGACY_DEST"

if [[ -L "$LEGACY_DEST" ]]; then
    echo "R8_LEGACY_PRODUCT_TREE=FAIL_SYMLINK path=$LEGACY_DEST"
    exit 14
fi

if [[ -e "$LEGACY_DEST" ]]; then
    [[ -d "$LEGACY_DEST" ]] || {
        echo "R8_LEGACY_PRODUCT_TREE=FAIL_NOT_DIRECTORY path=$LEGACY_DEST"
        exit 14
    }

    expected_legacy="$WS/vendor/sable/prebuilts/r8"
    [[ "$LEGACY_DEST" == "$expected_legacy" ]] || {
        echo "R8_LEGACY_PRODUCT_TREE=FAIL_PATH_MISMATCH path=$LEGACY_DEST"
        exit 14
    }

    echo "R8_LEGACY_PRODUCT_TREE_INVENTORY_BEGIN"
    find "$LEGACY_DEST" -maxdepth 3 -mindepth 1 -print | sort
    echo "R8_LEGACY_PRODUCT_TREE_INVENTORY_END"

    rm -rf --one-file-system -- "$LEGACY_DEST"

    [[ ! -e "$LEGACY_DEST" ]] || {
        echo "R8_LEGACY_PRODUCT_TREE=FAIL_REMOVE path=$LEGACY_DEST"
        exit 14
    }

    echo "R8_LEGACY_PRODUCT_TREE=REMOVED"
else
    echo "R8_LEGACY_PRODUCT_TREE=PASS_ABSENT"
fi

if [[ -L "$LEGACY_PARENT" ]]; then
    echo "R8_LEGACY_PRODUCT_PARENT=FAIL_SYMLINK path=$LEGACY_PARENT"
    exit 14
fi

if [[ -d "$LEGACY_PARENT" ]]; then
    if find "$LEGACY_PARENT" -mindepth 1 -print -quit | grep -q .; then
        echo "R8_LEGACY_PRODUCT_PARENT=FAIL_NONEMPTY path=$LEGACY_PARENT"
        find "$LEGACY_PARENT" -mindepth 1 -maxdepth 3 -print | sort
        exit 14
    fi
    rmdir -- "$LEGACY_PARENT"
    echo "R8_LEGACY_PRODUCT_PARENT=REMOVED_EMPTY"
else
    echo "R8_LEGACY_PRODUCT_PARENT=PASS_ABSENT"
fi

mkdir -p "$DEST/prebuilt" "$DEST/permissions"
rm -f "$DEST/prebuilt/"*.apk
rm -f "$DEST/permissions/"*.xml

install -m 0644     "$ROOT/product/r8/panther/Android.bp"     "$DEST/Android.bp"
install -m 0644     "$ROOT/product/r8/panther/r8-product.mk"     "$DEST/r8-product.mk"
install -m 0644     "$ROOT/product/r8/panther/permissions/sable-privapp-permissions-com.android.settings.xml"     "$DEST/permissions/sable-privapp-permissions-com.android.settings.xml"
install -m 0644     "$BUNDLE_MANIFEST"     "$DEST/manifest.tsv"
install -m 0644     "$BUNDLE_SUMS"     "$DEST/SHA256SUMS.txt"
install -m 0644     "$BUNDLE_SOURCE_IDENTITY"     "$DEST/SABLEOS_SOURCE_COMMIT.txt"

for apk in     SableCalculator.apk     SableSudoku.apk     SableMinesweeper.apk     Sable2048.apk     SableMedia.apk     SableTextReader.apk     SableReader.apk     SableHub.apk     SableMail.apk     SableWeather.apk     SableCalendar.apk
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
cmp -s "$ROOT/product/r8/panther/permissions/sable-privapp-permissions-com.android.settings.xml" "$DEST/permissions/sable-privapp-permissions-com.android.settings.xml" || {
    echo "R9_SETTINGS_PRIVAPP_ALLOWLIST_STAGE=FAIL"
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
grep -Eq '^[[:space:]]*AppStore([[:space:]\\]|$)' "$DEST/r8-product.mk" || {
    echo "R9_APPSTORE_PRODUCT_MODULE=FAIL"
    exit 13
}
echo "R9_APPSTORE_PRODUCT_MODULE=PASS"
echo "R9_SETTINGS_PRIVAPP_ALLOWLIST_STAGE=PASS_SYSTEM_EXT"
echo "R8_PRODUCT_MANIFEST=PASS"
echo "R8_PRODUCT_SOURCE_IDENTITY=PASS"
echo "R8_STAGED_PREBUILT_HASHES=PASS"
[[ ! -e "$LEGACY_DEST" ]] || {
    echo "R8_LEGACY_PRODUCT_TREE=FAIL_POST_STAGE"
    exit 16
}
echo "R8_LEGACY_PRODUCT_TREE=PASS_ABSENT_POST_STAGE"
[[ ! -e "$LEGACY_PARENT" && ! -L "$LEGACY_PARENT" ]] || {
    echo "R8_LEGACY_PRODUCT_PARENT=FAIL_POST_STAGE"
    exit 16
}
echo "R8_LEGACY_PRODUCT_PARENT=PASS_ABSENT_POST_STAGE"
echo "R8_PRODUCT_INCLUDE=PASS"
echo "R8_PRODUCT_STAGE=PASS"
echo "R8_PRODUCT_DEST=$DEST"
