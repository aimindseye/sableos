#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROFILE="$ROOT/build/titan2/n1d-c3b-e2-product-composition.env"
ADMISSION_PROFILE="$ROOT/build/titan2/n1d-c3b-e2-product-admission.env"
COMPOSITION_GATE="$ROOT/build/gates/n1d-c3b-e2-product-composition-contract.sh"
PREP="$ROOT/build/titan2/prepare-n1d-c3b-engineering.sh"
TEMPLATE_ROOT="$ROOT/product/titan2/c3b"

ANDROID_ROOT=""
BUNDLE=""
AUTHORIZE_SOURCE_MUTATION=NO

usage() {
    cat <<'USAGE'
usage: build/titan2/stage-n1d-c3b-e2-product-composition.sh \
  --android-root <C3B Android workspace> \
  --bundle <source-bound app artifact directory> \
  --authorize-source-mutation
USAGE
}

fail() {
    echo "N1D_C3B_E2_PRODUCT_STAGE=FAIL $*" >&2
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --android-root)
            [[ $# -ge 2 ]] || fail missing_android_root
            ANDROID_ROOT="$2"
            shift 2
            ;;
        --bundle)
            [[ $# -ge 2 ]] || fail missing_bundle
            BUNDLE="$2"
            shift 2
            ;;
        --authorize-source-mutation)
            AUTHORIZE_SOURCE_MUTATION=YES
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "unknown_arg=$1"
            ;;
    esac
done

[[ "$AUTHORIZE_SOURCE_MUTATION" == YES ]] || fail explicit_source_mutation_authority_required
[[ -n "$ANDROID_ROOT" && "$ANDROID_ROOT" = /* ]] || fail android_root_must_be_absolute
[[ -n "$BUNDLE" && "$BUNDLE" = /* ]] || fail bundle_must_be_absolute
[[ -d "$ANDROID_ROOT/.repo" ]] || fail "android_workspace_missing=$ANDROID_ROOT"
[[ -d "$BUNDLE/prebuilt" ]] || fail "bundle_prebuilt_missing=$BUNDLE/prebuilt"

# shellcheck source=/dev/null
source "$PROFILE"
# shellcheck source=/dev/null
source "$ADMISSION_PROFILE"

bash "$COMPOSITION_GATE"
bash "$PREP" verify

current_head="$(git -C "$ROOT" rev-parse HEAD)"
bundle_source="$(tr -d '[:space:]' < "$BUNDLE/CANONICAL_SOURCE_IMPORT_COMMIT.txt")"
bundle_build_head="$(tr -d '[:space:]' < "$BUNDLE/CANONICAL_BUILD_HEAD.txt")"
[[ "$bundle_source" == "$N1D_C3B_E2_SOURCE_IMPORT_COMMIT" ]] ||
    fail "bundle_source expected=$N1D_C3B_E2_SOURCE_IMPORT_COMMIT actual=$bundle_source"
[[ "$bundle_build_head" == "$current_head" ]] ||
    fail "bundle_build_head expected=$current_head actual=$bundle_build_head"

MANIFEST="$BUNDLE/manifest.tsv"
SUMS="$BUNDLE/SHA256SUMS.txt"
[[ -f "$MANIFEST" ]] || fail "bundle_manifest_missing=$MANIFEST"
[[ -f "$SUMS" ]] || fail "bundle_sums_missing=$SUMS"
(
    cd "$BUNDLE/prebuilt"
    sha256sum -c "$SUMS"
)

python3 - "$MANIFEST" <<'PY'
from __future__ import annotations
import csv
import pathlib
import sys

manifest = pathlib.Path(sys.argv[1])
expected = {
    "SableTitan2Keyboard": ("keyboard", "org.sableos.titan2.keyboard", "SableTitan2Keyboard.apk"),
    "SableTitan2Camera": ("camera", "org.sableos.titan2.camera", "SableTitan2Camera.apk"),
    "SableTitan2DisplayCompat": ("displaycompat", "org.sableos.titan2.displaycompat", "SableTitan2DisplayCompat.apk"),
    "SableTitan2Setup": ("setup", "org.sableos.titan2.setup", "SableTitan2Setup.apk"),
    "SableTitan2RadioDiag": ("radiodiag", "org.sableos.titan2.radiodiag", "SableTitan2RadioDiag.apk"),
}
with manifest.open(encoding="utf-8", newline="") as fh:
    rows = list(csv.DictReader(fh, delimiter="\t"))
seen = {}
for row in rows:
    module = row.get("module", "")
    seen[module] = (
        row.get("gradle_module", ""),
        row.get("package", ""),
        row.get("filename", ""),
    )
    if row.get("signature_state") != "UNSIGNED":
        raise SystemExit(f"N1D_C3B_E2_PRODUCT_STAGE=FAIL artifact_not_unsigned module={module}")
if seen != expected:
    raise SystemExit(
        "N1D_C3B_E2_PRODUCT_STAGE=FAIL artifact_module_set "
        f"expected={expected!r} actual={seen!r}"
    )
print("N1D_C3B_E2_PRODUCT_STAGE_BUNDLE=PASS_EXACT_5_UNSIGNED")
PY

[[ -f "$ANDROID_ROOT/$N1D_C3B_E2_BASE_PRODUCT_MK" ]] ||
    fail "generated_e1_product_missing=$N1D_C3B_E2_BASE_PRODUCT_MK"
[[ ! -e "$ANDROID_ROOT/vendor/sable/n1d" ]] ||
    fail retired_vendor_sable_n1d_present

DEST="$ANDROID_ROOT/$N1D_C3B_E2_ANDROID_STAGE_ROOT"
EVIDENCE_ROOT="${SABLE_EVIDENCE_ROOT:-/srv/sable-build/evidence}"
run_id="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="$EVIDENCE_ROOT/titan2/n1d-c3b-e2-product-stage/$run_id"
mkdir -p "$EVIDENCE_DIR"

copy_exact() {
    local src="$1" dst="$2"
    [[ -f "$src" ]] || fail "source_missing=$src"
    if [[ -e "$dst" ]]; then
        [[ -f "$dst" && ! -L "$dst" ]] || fail "target_not_regular=$dst"
        cmp -s "$src" "$dst" || fail "differing_existing_target=$dst"
        echo "IDENTICAL $dst"
        return
    fi
    mkdir -p "$(dirname "$dst")"
    install -m 0644 "$src" "$dst"
    cmp -s "$src" "$dst" || fail "copy_mismatch=$dst"
    echo "COPIED $dst"
}

mkdir -p "$DEST/prebuilt"
for name in Android.bp AndroidProducts.mk sable-titan2-apps.mk sable_titan2.mk README.md; do
    copy_exact "$TEMPLATE_ROOT/$name" "$DEST/$name"
done

for apk in \
    SableTitan2Keyboard.apk \
    SableTitan2Camera.apk \
    SableTitan2DisplayCompat.apk \
    SableTitan2Setup.apk \
    SableTitan2RadioDiag.apk
do
    copy_exact "$BUNDLE/prebuilt/$apk" "$DEST/prebuilt/$apk"
done

cat > "$DEST/source-binding.env" <<EOF
N1D_C3B_E2_SOURCE_IMPORT_COMMIT=$N1D_C3B_E2_SOURCE_IMPORT_COMMIT
N1D_C3B_E2_CANONICAL_BUILD_HEAD=$current_head
N1D_C3B_E2_ARTIFACT_MANIFEST_SHA256=$(sha256sum "$MANIFEST" | awk '{print $1}')
N1D_C3B_E2_PRODUCT_NAME=$N1D_C3B_E2_PRODUCT_NAME
N1D_C3B_E2_LUNCH_TARGET=$N1D_C3B_E2_LUNCH_TARGET
N1D_C3B_E2_MODULE_COUNT=$N1D_C3B_E2_MODULE_COUNT
EOF

grep -Fxq '$(call inherit-product, device/phh/treble/treble_arm64_bvN.mk)' "$DEST/sable_titan2.mk" ||
    fail base_product_inherit_missing
grep -Fxq '$(call inherit-product, vendor/sable/titan2/sable-titan2-apps.mk)' "$DEST/sable_titan2.mk" ||
    fail sable_apps_inherit_missing
grep -Fxq 'PRODUCT_NAME := sable_titan2' "$DEST/sable_titan2.mk" ||
    fail final_product_name_missing

if grep -Eq 'generic_system_arm64|gsi_release|vendor/sable/n1d' "$DEST/sable_titan2.mk"; then
    fail retired_or_direct_gsi_inheritance_present
fi
if grep -Eq 'presigned:[[:space:]]*true|certificate:[[:space:]]*"platform"|privileged:[[:space:]]*true' "$DEST/Android.bp"; then
    fail forbidden_app_import_privilege_or_signing
fi

default_cert_count="$(grep -Ec '^[[:space:]]*default_dev_cert:[[:space:]]*true,' "$DEST/Android.bp")"
product_specific_count="$(grep -Ec '^[[:space:]]*product_specific:[[:space:]]*true,' "$DEST/Android.bp")"
privileged_false_count="$(grep -Ec '^[[:space:]]*privileged:[[:space:]]*false,' "$DEST/Android.bp")"
[[ "$default_cert_count" == 5 ]] || fail "default_dev_cert_count=$default_cert_count"
[[ "$product_specific_count" == 5 ]] || fail "product_specific_count=$product_specific_count"
[[ "$privileged_false_count" == 5 ]] || fail "privileged_false_count=$privileged_false_count"

find "$DEST" -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > "$EVIDENCE_DIR/staged-tree.sha256"
cp "$DEST/source-binding.env" "$EVIDENCE_DIR/source-binding.env"
cp "$MANIFEST" "$EVIDENCE_DIR/artifact-manifest.tsv"

echo "N1D_C3B_E2_PRODUCT_STAGE_SOURCE_BINDING=PASS"
echo "N1D_C3B_E2_PRODUCT_STAGE_BASE_INHERIT=PASS_GENERATED_E1_TREBLE"
echo "N1D_C3B_E2_PRODUCT_STAGE_MODULES=PASS count=5"
echo "N1D_C3B_E2_PRODUCT_STAGE_PARTITION=PASS_PRODUCT"
echo "N1D_C3B_E2_PRODUCT_STAGE_SIGNING=PASS_DEFAULT_DEV_CERT"
echo "N1D_C3B_E2_PRODUCT_STAGE_PRIVILEGED=PASS_ZERO"
echo "N1D_C3B_E2_PRODUCT_STAGE=PASS"
echo "ANDROID_STAGE_ROOT=$DEST"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
