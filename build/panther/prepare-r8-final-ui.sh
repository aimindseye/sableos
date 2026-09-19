#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT/build/config/panther-grapheneos-2026081300.env"

SOURCE_MUTATION_AUTHORIZED="${SOURCE_MUTATION_AUTHORIZED:-NO}"
R8_APP_BUNDLE="${R8_APP_BUNDLE:-${1:-}}"

if [[ "$SOURCE_MUTATION_AUTHORIZED" != YES ]]; then
    echo "R8_FINAL_UI_PREPARE=REFUSED_SOURCE_MUTATION_NOT_AUTHORIZED"
    exit 2
fi

WS="$SABLEOS_UPSTREAM"
[[ -d "$WS/.repo" ]] || {
    echo "R8_ANDROID_WORKSPACE=FAIL path=$WS"
    exit 3
}

[[ -n "$R8_APP_BUNDLE" && -d "$R8_APP_BUNDLE" ]] || {
    echo "R8_APP_BUNDLE=FAIL_MISSING"
    exit 4
}

echo "===== R8 FINAL UI SOURCE / PRODUCT PREPARATION ====="
echo "SOURCE_MUTATION_AUTHORIZED=YES"
echo "BUILD_AUTHORIZED=NO"
echo "CLEAN_AUTHORIZED=NO"
echo "CLOBBER_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "WORKSPACE=$WS"
echo "R8_APP_BUNDLE=$R8_APP_BUNDLE"

apply_or_verify() {
    local name="$1"
    local script="$2"

    echo
    echo "===== $name SELF-TEST ====="
    python3 "$script" --self-test

    echo
    echo "===== $name SOURCE STATE ====="
    if python3 "$script" --source "$WS" verify; then
        echo "${name}_SOURCE_STATE=ALREADY_APPLIED"
    else
        echo "${name}_SOURCE_STATE=APPLYING"
        python3 "$script" --source "$WS" apply
        python3 "$script" --source "$WS" verify
    fi

    echo "${name}=PASS"
}

apply_or_verify     SABLE_BRANDING     "$ROOT/patches/android-17-grapheneos-2026081300/apply_sable_branding.py"

apply_or_verify     UI4_SYSTEMUI     "$ROOT/patches/android-17-grapheneos-2026081300/apply_ui4_systemui.py"

apply_or_verify     UI5A_SETTINGS     "$ROOT/patches/android-17-grapheneos-2026081300/apply_ui5a_settings.py"

apply_or_verify     UI5B_APP_SECURITY     "$ROOT/patches/android-17-grapheneos-2026081300/apply_ui5b_app_security.py"

apply_or_verify     UI5C_UI6_SYSTEM_SURFACES     "$ROOT/patches/android-17-grapheneos-2026081300/apply_ui5c_ui6_system_surfaces.py"

echo
echo "===== SHARED SABLE DESIGN ====="

DESIGN_SRC="$ROOT/src/android/shared/sabledesign"
DESIGN_DST="$WS/packages/apps/SableDesign"

[[ -f "$DESIGN_SRC/Android.bp" ]] || {
    echo "R8_SABLE_DESIGN_SOURCE=FAIL"
    exit 5
}

mkdir -p "$DESIGN_DST"
rsync -a --delete "$DESIGN_SRC/" "$DESIGN_DST/"

diff -qr "$DESIGN_SRC" "$DESIGN_DST" >/dev/null || {
    echo "R8_SABLE_DESIGN_SYNC=FAIL"
    exit 6
}

echo "R8_SABLE_DESIGN_SYNC=PASS"

echo
echo "===== PRODUCTION SABLE START ====="

SOURCE_MUTATION_AUTHORIZED=YES SABLEOS_UPSTREAM="$WS"     bash "$ROOT/build/panther/sync-sablestart.sh"

echo "R8_SABLESTART_SYNC=PASS"

echo
echo "===== R8 FIRST-PARTY PRODUCT APPLICATIONS ====="

SOURCE_MUTATION_AUTHORIZED=YES SABLEOS_UPSTREAM="$WS" R8_APP_BUNDLE="$R8_APP_BUNDLE"     bash "$ROOT/build/panther/stage-r8-product-apps.sh"

echo
echo "===== FINAL SOURCE VERIFY ====="

python3     "$ROOT/patches/android-17-grapheneos-2026081300/apply_sable_branding.py"     --source "$WS" verify
python3     "$ROOT/patches/android-17-grapheneos-2026081300/apply_ui4_systemui.py"     --source "$WS" verify
python3     "$ROOT/patches/android-17-grapheneos-2026081300/apply_ui5a_settings.py"     --source "$WS" verify
python3     "$ROOT/patches/android-17-grapheneos-2026081300/apply_ui5b_app_security.py"     --source "$WS" verify
python3     "$ROOT/patches/android-17-grapheneos-2026081300/apply_ui5c_ui6_system_surfaces.py"     --source "$WS" verify

echo "R8_SYSTEM_SURFACE_SOURCE_VERIFY=PASS"
echo "R8_FINAL_UI_PREPARE=PASS"
echo "BUILD_PERFORMED=NO"
