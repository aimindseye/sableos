#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$REPO_ROOT/build/config/panther-grapheneos-2026081300.env"

WS="${WS:-$SABLEOS_UPSTREAM}"
APP_DIR="$WS/packages/apps/SableStart"
BUILD_AUTHORIZED="${BUILD_AUTHORIZED:-NO}"
JOBS="${JOBS:-$(nproc)}"
TS="$(date +%Y%m%d_%H%M%S)"
E="${EVIDENCE_DIR:-$SABLEOS_EVIDENCE/r3b-$TS}"
mkdir -p "$E"
R="$E/gate_report.txt"
LOG="$E/soong_build.log"
: > "$R"
rec(){ printf '%s=%s\n' "$1" "$2" | tee -a "$R"; }

if [[ "$BUILD_AUTHORIZED" != YES ]]; then
    echo "Refusing module build. Set BUILD_AUTHORIZED=YES explicitly."
    exit 2
fi

cat <<EOF
===== SABLE START R3B SOONG COMPILE GATE =====
SOURCE_MUTATION_AUTHORIZED=NO
BUILD_AUTHORIZED=YES_MODULE_ONLY
CLEAN_AUTHORIZED=NO
CLOBBER_AUTHORIZED=NO
NETWORK_FETCH_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
WS=$WS
APP_DIR=$APP_DIR
EVIDENCE_DIR=$E
EOF

[[ -d "$APP_DIR" ]] || { rec SABLE_START_R3B_APP_DIR FAIL; exit 1; }
rec SABLE_START_R3B_APP_DIR PASS

# Bind the exact R3-R1 changed files before compiling.
declare -A expected=(
 [AndroidManifest.xml]=05adaebf862dd6c81cfe8326bf92ef152556bab3b4a78f8da34fb1000dc6bd25
 [src/com/sable/start/ui/SableMetroPreviewActivity.kt]=12db1f5a6fc6584dd462395d5f30f44d8980c4edd92b901bb52f9cb921eca1a2
 [src/com/sable/start/platform/LiveSurfaceRepository.kt]=e367bc36cb82541d77fe84ec289605aaf86531c446d6f17294e247793029040b
 [src/com/sable/start/live/LiveSurfaceModels.kt]=81c8d6854f50e0ae69809f394bb8eee08573a7627c35335f5d01094fc8a15978
)
for rel in "${!expected[@]}"; do
    actual="$(sha256sum "$APP_DIR/$rel" | awk '{print $1}')"
    printf '%s  %s\n' "$actual" "$rel" >> "$E/source_hashes.txt"
    [[ "$actual" == "${expected[$rel]}" ]] || { rec SABLE_START_R3B_SOURCE_BINDING FAIL; exit 1; }
done
rec SABLE_START_R3B_SOURCE_BINDING PASS

cd "$WS"
source build/envsetup.sh > "$E/envsetup.log" 2>&1

# Reuse an already configured Panther environment when available; otherwise
# configure the canonical current release target.
if [[ "${TARGET_PRODUCT:-}" != panther || "${TARGET_BUILD_VARIANT:-}" != user ]]; then
    lunch "$SABLEOS_LUNCH_TARGET" > "$E/lunch.log" 2>&1
else
    printf 'inherited TARGET_PRODUCT=%s TARGET_RELEASE=%s TARGET_BUILD_VARIANT=%s\n' \
      "$TARGET_PRODUCT" "${TARGET_RELEASE:-}" "$TARGET_BUILD_VARIANT" > "$E/lunch.log"
fi

rec SABLE_START_R3B_TARGET_PRODUCT "${TARGET_PRODUCT:-UNKNOWN}"
rec SABLE_START_R3B_TARGET_RELEASE "${TARGET_RELEASE:-UNKNOWN}"
rec SABLE_START_R3B_TARGET_BUILD_VARIANT "${TARGET_BUILD_VARIANT:-UNKNOWN}"

set +e
m -j"$JOBS" SableStart > "$LOG" 2>&1
rc=$?
set -e

if [[ $rc -ne 0 ]]; then
    rec SABLE_START_R3B_SOONG_BUILD FAIL
    grep -nEi 'error:|unresolved reference|cannot find symbol|undefined module|depends on undefined module|kotlinx\.coroutines' "$LOG" > "$E/error_focus.txt" || true
    if grep -qiE 'unresolved reference.*(kotlinx|Dispatchers|withContext|delay)|kotlinx\.coroutines' "$LOG"; then
        rec SABLE_START_R3B_FAILURE_CLASS COROUTINES_CLASSPATH
    elif grep -qiE 'undefined module|depends on undefined module' "$LOG"; then
        rec SABLE_START_R3B_FAILURE_CLASS SOONG_DEPENDENCY
    elif grep -qiE 'unresolved reference|cannot find symbol|type mismatch|overrides nothing' "$LOG"; then
        rec SABLE_START_R3B_FAILURE_CLASS KOTLIN_TYPECHECK
    else
        rec SABLE_START_R3B_FAILURE_CLASS OTHER_BUILD
    fi
else
    rec SABLE_START_R3B_SOONG_BUILD PASS
fi

tail -n 160 "$LOG" > "$E/soong_build_tail.txt" || true

OUT_EFFECTIVE="${OUT_DIR:-$WS/out}"
find "$OUT_EFFECTIVE/target/product/panther" -type f -name 'SableStart*.apk' -print 2>/dev/null | sort > "$E/apk_candidates.txt" || true
APK="$(head -n1 "$E/apk_candidates.txt" || true)"
if [[ $rc -eq 0 && -n "$APK" && -f "$APK" ]]; then
    rec SABLE_START_R3B_APK_LOCATED PASS
    sha256sum "$APK" > "$E/apk.sha256"
else
    rec SABLE_START_R3B_APK_LOCATED FAIL
fi

FINAL=PASS
[[ $rc -eq 0 ]] || FINAL=FAIL
[[ -n "$APK" && -f "$APK" ]] || FINAL=FAIL
rec SABLE_START_R3B_GATE "$FINAL"

(
  cd "$E"
  find . -type f ! -name SHA256SUMS.txt ! -name SHA256SUMS.txt.sha256 -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS.txt
)
H="$(sha256sum "$E/SHA256SUMS.txt" | awk '{print $1}')"
printf '%s  SHA256SUMS.txt\n' "$H" > "$E/SHA256SUMS.txt.sha256"
echo "$H  $E/SHA256SUMS.txt"
echo "Evidence: $E"
echo "Result: $FINAL"
exit "$([[ "$FINAL" == PASS ]] && echo 0 || echo 1)"
