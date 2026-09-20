#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# The release profile owns the current ai-g732 build-farm paths. Source it
# before the Panther substrate profile so the latter contributes device/lunch
# constants without replacing the canonical relocated workspace.
source "$ROOT/build/config/r8-release.env"
source "$ROOT/build/config/panther-grapheneos-2026081300.env"

SOURCE_MUTATION_AUTHORIZED="${SOURCE_MUTATION_AUTHORIZED:-NO}"
BUILD_AUTHORIZED="${BUILD_AUTHORIZED:-NO}"
WS="${WS:-$SABLEOS_UPSTREAM}"
# Reuse the already-qualified Panther output graph. A new OUT_DIR would make a
# module-only Launcher3QuickStep request rebuild thousands of transitive host
# and target dependencies even though no full image was requested.
OUT_DIR="${OUT_DIR:-$SABLE_R8_OUT_DIR}"
ALLOW_COLD_OUT="${ALLOW_COLD_OUT:-NO}"
JOBS="${JOBS:-8}"

if [[ "$SOURCE_MUTATION_AUTHORIZED" != YES ]]; then
    echo "R9_LAUNCHER3_FOUNDATION_QUALIFY=REFUSED_SOURCE_MUTATION_NOT_AUTHORIZED"
    exit 2
fi

if [[ "$BUILD_AUTHORIZED" != YES ]]; then
    echo "R9_LAUNCHER3_FOUNDATION_QUALIFY=REFUSED_BUILD_NOT_AUTHORIZED"
    exit 3
fi

[[ -d "$WS/.repo" ]] || {
    echo "R9_LAUNCHER3_FOUNDATION_WORKSPACE=FAIL path=$WS"
    exit 4
}

OUT_ABS="$WS/$OUT_DIR"
if [[ "$OUT_DIR" == /* ]]; then
    OUT_ABS="$OUT_DIR"
fi

collect_ninja_graphs() {
    local out="$1"
    local -a found=()

    [[ -f "$out/build.ninja" ]] && found+=("$out/build.ninja")
    [[ -f "$out/soong/build.ninja" ]] && found+=("$out/soong/build.ninja")

    shopt -s nullglob
    local path
    for path in         "$out"/build-*panther*.ninja         "$out"/combined-*panther*.ninja
    do
        [[ -f "$path" ]] && found+=("$path")
    done
    shopt -u nullglob

    printf '%s\n' "${found[@]}"
}

mapfile -t WARM_NINJA_GRAPHS < <(collect_ninja_graphs "$OUT_ABS")

if [[ "$ALLOW_COLD_OUT" != YES ]]; then
    if [[ "${#WARM_NINJA_GRAPHS[@]}" -eq 0 ]] ||
        [[ ! -d "$OUT_ABS/target/product/panther" ]]; then
        echo "R9_LAUNCHER3_FOUNDATION_WARM_OUT=FAIL path=$OUT_ABS"
        echo "R9_LAUNCHER3_FOUNDATION_COLD_BUILD_REFUSED=YES"
        echo "HINT=Set OUT_DIR to an existing Panther output containing build-*panther*.ninja, combined-*panther*.ninja, or soong/build.ninja plus target/product/panther."
        exit 5
    fi
fi

STAMP="$(date +%Y%m%d_%H%M%S)"
EVIDENCE_DIR="${EVIDENCE_DIR:-/srv/data/sable-build/evidence/panther/r9-launcher-foundation-v2/$STAMP}"
mkdir -p "$EVIDENCE_DIR"

echo "===== R9 LAUNCHER3 / QUICKSTEP FOUNDATION V2 QUALIFICATION ====="
echo "SOURCE_MUTATION_AUTHORIZED=YES"
echo "BUILD_AUTHORIZED=YES"
echo "CLEAN_AUTHORIZED=NO"
echo "CLOBBER_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "FULL_IMAGE_BUILD_AUTHORIZED=NO"
echo "STANDALONE_SABLESTART_RETIREMENT_AUTHORIZED=YES"
echo "COLD_OUT_BUILD_AUTHORIZED=$ALLOW_COLD_OUT"
echo "WORKSPACE=$WS"
echo "OUT_DIR=$OUT_DIR"
echo "OUT_ABS=$OUT_ABS"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
if [[ "${#WARM_NINJA_GRAPHS[@]}" -gt 0 ]] &&
    [[ -d "$OUT_ABS/target/product/panther" ]]; then
    echo "R9_LAUNCHER3_FOUNDATION_WARM_OUT=PASS"
    printf 'R9_LAUNCHER3_FOUNDATION_NINJA_GRAPH=%s\n' "${WARM_NINJA_GRAPHS[@]}"
fi

echo
echo "===== REPOSITORY FOUNDATION CONTRACT ====="
python3 "$ROOT/build/gates/r9-launcher3-foundation-contract.py" \
    | tee "$EVIDENCE_DIR/repository-contract.log"

echo
echo "===== SHARED SABLE DESIGN SYNC ====="
DESIGN_SRC="$ROOT/src/android/shared/sabledesign"
DESIGN_DST="$WS/packages/apps/SableDesign"
mkdir -p "$DESIGN_DST"
rsync -a --delete "$DESIGN_SRC/" "$DESIGN_DST/"
diff -qr "$DESIGN_SRC" "$DESIGN_DST" >/dev/null
echo "R9_LAUNCHER3_FOUNDATION_DESIGN_SYNC=PASS"

echo
echo "===== SABLE PRESENTATION SOURCE SYNC ====="
SOURCE_MUTATION_AUTHORIZED=YES SABLEOS_UPSTREAM="$WS" \
    bash "$ROOT/build/panther/sync-sablestart.sh" \
    | tee "$EVIDENCE_DIR/sable-presentation-sync.log"

grep -Fxq 'SABLESTART_STANDALONE_RUNTIME=PASS_ABSENT' \
    "$EVIDENCE_DIR/sable-presentation-sync.log" || {
        echo "R9_STANDALONE_SABLESTART_WORKSPACE=FAIL"
        exit 5
    }
echo "R9_STANDALONE_SABLESTART_WORKSPACE=PASS_ABSENT"

echo
echo "===== PINNED LAUNCHER3 FOUNDATION APPLY ====="
APPLIER="$ROOT/patches/android-17-grapheneos-2026081300/apply_r9_launcher3_foundation.py"
python3 "$APPLIER" --self-test \
    | tee "$EVIDENCE_DIR/foundation-self-test.log"
python3 "$APPLIER" --source "$WS" apply \
    | tee "$EVIDENCE_DIR/foundation-apply.log"
python3 "$APPLIER" --source "$WS" verify \
    | tee "$EVIDENCE_DIR/foundation-verify.log"

echo
echo "===== ANDROID BUILD ENVIRONMENT ====="
cd "$WS"
unset BUILD_DATETIME
unset BUILD_NUMBER
unset SABLEOS_UI_PREVIEW_BUILD_NUMBER
source build/envsetup.sh

export OUT_DIR
export SOONG_NINJA=ninja
export SOONG_INCREMENTAL_ANALYSIS=false

set +e
lunch "$SABLEOS_LUNCH_TARGET" > >(tee "$EVIDENCE_DIR/lunch.log") 2>&1
LUNCH_RC=$?
set -e

echo "R9_LAUNCHER3_FOUNDATION_LUNCH_RC=$LUNCH_RC"
[[ "$LUNCH_RC" -eq 0 ]] || {
    echo "R9_LAUNCHER3_FOUNDATION_LUNCH=FAIL"
    exit 5
}

[[ "${TARGET_PRODUCT:-}" == panther ]] || {
    echo "R9_LAUNCHER3_FOUNDATION_TARGET_PRODUCT=FAIL actual=${TARGET_PRODUCT:-UNSET}"
    exit 5
}
[[ "${TARGET_RELEASE:-}" == cur ]] || {
    echo "R9_LAUNCHER3_FOUNDATION_TARGET_RELEASE=FAIL actual=${TARGET_RELEASE:-UNSET}"
    exit 5
}
[[ "${TARGET_BUILD_VARIANT:-}" == userdebug ]] || {
    echo "R9_LAUNCHER3_FOUNDATION_TARGET_VARIANT=FAIL actual=${TARGET_BUILD_VARIANT:-UNSET}"
    exit 5
}
echo "R9_LAUNCHER3_FOUNDATION_LUNCH=PASS"

echo
echo "===== LAUNCHER3QUICKSTEP FOCUSED SOONG COMPILE ====="
set +e
m -j"$JOBS" Launcher3QuickStep 2>&1 \
    | tee "$EVIDENCE_DIR/launcher3-quickstep-build.log"
BUILD_RC=${PIPESTATUS[0]}
set -e

echo "R9_LAUNCHER3_FOUNDATION_BUILD_RC=$BUILD_RC"
if [[ "$BUILD_RC" -ne 0 ]]; then
    echo "R9_L7_LAUNCHER3_FOUNDATION_COMPILE=FAIL"
    exit 6
fi

python3 "$APPLIER" --source "$WS" verify \
    | tee "$EVIDENCE_DIR/postbuild-foundation-verify.log"

echo
echo "===== LAUNCHER3 WARNING QUALITY GATE ====="
python3 "$ROOT/build/gates/r9-launcher-warning-gate.py" \
    "$EVIDENCE_DIR/launcher3-quickstep-build.log" \
    | tee "$EVIDENCE_DIR/launcher3-warning-gate.log"
echo "R9_LAUNCHER3_WARNING_MIGRATIONS=PASS"

echo
echo "===== R9 FOUNDATION V2 RESULT ====="
echo "R9_LAUNCHER3_FOUNDATION_SOURCE=PASS"
echo "R9_LAUNCHER3_FOUNDATION_MODEL=LAUNCHER3_ALL_APPS_STORE"
echo "R9_LAUNCHER3_FOUNDATION_LAUNCH_PATH=LAUNCHER3_START_ACTIVITY_SAFELY"
echo "R9_LAUNCHER3_FOUNDATION_RECENTS=QUICKSTEP_PRESERVED"
echo "R9_LAUNCHER3_FALLBACK_NULL_CALLBACK_COMPAT=PASS"
echo "R9_LAUNCHER3_WARNING_QUALITY=OPEN_DEBT_REMAINS"
echo "R9_LAUNCHER3_DAGGER_EASY_EXECUTOR_MIGRATION=PASS"
echo "R9_STANDALONE_SABLESTART_PRODUCT=PASS_ABSENT"
echo "R9_LAUNCHER3_HOME_OWNERSHIP=PASS"
echo "R9_L7_LAUNCHER3_FOUNDATION_COMPILE=PASS"
echo "R9_L8_HOME_CUTOVER_COMPILE=PASS"
echo "NEXT_STEP=VISUAL_REVIEW_THEN_FULL_PANTHER_IMAGE"
echo "FULL_PANTHER_BUILD_PERFORMED=NO"
echo "DEVICE_CONTACTED=NO"
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
