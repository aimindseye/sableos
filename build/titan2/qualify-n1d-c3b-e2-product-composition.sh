#!/usr/bin/env bash
# End-to-end E2 composition qualification through focused module build only.
# This does not build systemimage, target-files, OTA, contact a device, flash,
# or authorize production signing/release.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROFILE="$ROOT/build/titan2/n1d-c3b-e2-product-composition.env"
TRANSITION="$ROOT/build/titan2/n1d-c3b-transition.env"
STORAGE_PROFILE="$ROOT/build/config/storage.env"
GATE="$ROOT/build/gates/n1d-c3b-e2-product-composition-contract.sh"
APP_BUILD="$ROOT/build/titan2/build-n1d-c3b-e2-product-apps.sh"
STAGER="$ROOT/build/titan2/stage-n1d-c3b-e2-product-composition.sh"
PARSE="$ROOT/build/titan2/qualify-n1d-c3b-e2-product-parse.sh"
MODULE_BUILD="$ROOT/build/titan2/build-n1d-c3b-e2-modules.sh"

AUTHORIZE_COMPOSITION_QUALIFICATION=NO
JOBS=16

fail() {
    echo "N1D_C3B_E2_PRODUCT_COMPOSITION_QUALIFICATION=FAIL $*" >&2
    exit 1
}

while (($#)); do
    case "$1" in
        --authorize-composition-qualification)
            AUTHORIZE_COMPOSITION_QUALIFICATION=YES
            shift
            ;;
        --jobs)
            [[ $# -ge 2 && "$2" =~ ^[1-9][0-9]*$ ]] || fail invalid_jobs
            JOBS="$2"
            shift 2
            ;;
        *)
            fail "unknown_arg=$1"
            ;;
    esac
done

[[ "$AUTHORIZE_COMPOSITION_QUALIFICATION" == YES ]] ||
    fail explicit_composition_qualification_authority_required

for f in "$PROFILE" "$TRANSITION" "$STORAGE_PROFILE" "$GATE" "$APP_BUILD" "$STAGER" "$PARSE" "$MODULE_BUILD"; do
    [[ -f "$f" ]] || fail "missing_file=$f"
done

# shellcheck source=/dev/null
source "$PROFILE"
# shellcheck source=/dev/null
source "$TRANSITION"
# shellcheck source=/dev/null
source "$STORAGE_PROFILE"

bash "$GATE"

CURRENT_HEAD="$(git -C "$ROOT" rev-parse HEAD)"
git -C "$ROOT" merge-base --is-ancestor "$N1D_C3B_E2_SOURCE_IMPORT_COMMIT" "$CURRENT_HEAD" ||
    fail "source_import_not_ancestor=$N1D_C3B_E2_SOURCE_IMPORT_COMMIT"

ANDROID_ROOT="$SABLE_BUILD_ROOT/$N1D_C3B_ANDROID_ROOT_REL"
OUT_ROOT="$SABLE_BUILD_ROOT/$N1D_C3B_OUT_ROOT_REL"
[[ -d "$ANDROID_ROOT/.repo" ]] || fail "android_workspace_missing=$ANDROID_ROOT"

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_ROOT="$SABLE_EVIDENCE_ROOT/titan2/n1d-c3b-e2-composition-qualification/$stamp"
BUNDLE="$SABLE_BUILD_ROOT/artifacts/titan2/n1d-c3b-e2-product-apps/$CURRENT_HEAD/$stamp"
mkdir -p "$RUN_ROOT"

exec > >(tee "$RUN_ROOT/qualification.log") 2>&1

echo "===== N1D C3B E2 PRODUCT COMPOSITION QUALIFICATION ====="
echo "CANONICAL_HEAD=$CURRENT_HEAD"
echo "CANONICAL_SOURCE_IMPORT_COMMIT=$N1D_C3B_E2_SOURCE_IMPORT_COMMIT"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "ANDROID_WORKSPACE_SOURCE_MUTATION_AUTHORIZED=YES_EXACT_VENDOR_SABLE_TITAN2_STAGE"
echo "ANDROID_TARGET_COMPILATION_AUTHORIZED=YES_EXACT_5_MODULES"
echo "FULL_IMAGE_BUILD_AUTHORIZED=NO"
echo "TARGET_FILES_AUTHORIZED=NO"
echo "OTA_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "PRODUCTION_SIGNING_AUTHORIZED=NO"
echo "RELEASE_ELIGIBLE=NO"

echo
echo "===== STEP 1: SOURCE-BOUND OFFLINE APP BUILD ====="
bash "$APP_BUILD" \
    --authorize-app-build \
    --output-dir "$BUNDLE"

grep -Fxq "$N1D_C3B_E2_SOURCE_IMPORT_COMMIT" "$BUNDLE/CANONICAL_SOURCE_IMPORT_COMMIT.txt" ||
    fail bundle_source_identity
grep -Fxq "$CURRENT_HEAD" "$BUNDLE/CANONICAL_BUILD_HEAD.txt" ||
    fail bundle_build_identity

echo
echo "===== STEP 2: BOUNDED ANDROID PRODUCT STAGE ====="
bash "$STAGER" \
    --android-root "$ANDROID_ROOT" \
    --bundle "$BUNDLE" \
    --authorize-source-mutation

echo
echo "===== STEP 3: SABLE PRODUCT PARSE ====="
PARSE_LOG="$RUN_ROOT/parse-driver.log"
set +e
bash "$PARSE" --authorize-product-parse 2>&1 | tee "$PARSE_LOG"
parse_rc=${PIPESTATUS[0]}
set -e
[[ "$parse_rc" -eq 0 ]] || fail "parse_rc=$parse_rc"

PARSE_EVIDENCE="$(sed -n 's/^EVIDENCE_DIR=//p' "$PARSE_LOG" | tail -n1)"
[[ -n "$PARSE_EVIDENCE" && "$PARSE_EVIDENCE" = /* ]] ||
    fail "parse_evidence_not_reported=$PARSE_EVIDENCE"
[[ -f "$PARSE_EVIDENCE/parse-state.env" ]] ||
    fail "parse_state_missing=$PARSE_EVIDENCE/parse-state.env"
grep -Fxq 'N1D_C3B_E2_PRODUCT_PARSE=PASS' "$PARSE_EVIDENCE/parse-state.env" ||
    fail parse_evidence_not_pass

echo
echo "===== STEP 4: EXACT FIVE-MODULE ANDROID BUILD ====="
bash "$MODULE_BUILD" \
    --authorize-module-build \
    --parse-evidence "$PARSE_EVIDENCE" \
    --jobs "$JOBS"

if find "$OUT_ROOT/e2-modules" \
    -type f \( -name 'system.img' -o -name '*target_files*.zip' -o -name '*-ota*.zip' \) \
    -print -quit 2>/dev/null | grep -q .
then
    fail unexpected_full_image_or_release_artifact
fi

{
    echo "N1D_C3B_E2_PRODUCT_COMPOSITION_QUALIFICATION=PASS"
    echo "N1D_C3B_E2_CANONICAL_HEAD=$CURRENT_HEAD"
    echo "N1D_C3B_E2_SOURCE_IMPORT_COMMIT=$N1D_C3B_E2_SOURCE_IMPORT_COMMIT"
    echo "N1D_C3B_E2_APP_BUNDLE=$BUNDLE"
    echo "N1D_C3B_E2_PARSE_EVIDENCE=$PARSE_EVIDENCE"
    echo "N1D_C3B_E2_MODULE_COUNT=$N1D_C3B_E2_MODULE_COUNT"
    echo "N1D_C3B_E2_FULL_IMAGE_BUILD_AUTHORIZED=NO"
    echo "N1D_C3B_E2_DEVICE_CONTACT_AUTHORIZED=NO"
    echo "N1D_C3B_E2_RELEASE_ELIGIBLE=NO"
} > "$RUN_ROOT/qualification-state.env"

(
    cd "$RUN_ROOT"
    find . -type f ! -name SHA256SUMS.txt ! -name qualification.log -print0 |
        LC_ALL=C sort -z |
        xargs -0 sha256sum > SHA256SUMS.txt
    sha256sum -c SHA256SUMS.txt >/dev/null
)

echo
echo "N1D_C3B_E2_COMPOSITION_APP_BUILD=PASS"
echo "N1D_C3B_E2_COMPOSITION_ANDROID_STAGE=PASS"
echo "N1D_C3B_E2_COMPOSITION_PARSE=PASS"
echo "N1D_C3B_E2_COMPOSITION_MODULE_BUILD=PASS count=5"
echo "N1D_C3B_E2_PRODUCT_COMPOSITION_QUALIFICATION=PASS"
echo "EVIDENCE_DIR=$RUN_ROOT"
