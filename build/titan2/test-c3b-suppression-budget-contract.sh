#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

copy_tree() {
  git -C "$ROOT" ls-files -z |
    while IFS= read -r -d '' path; do
      [[ -e "$ROOT/$path" ]] || continue
      mkdir -p "$TMP/$(dirname "$path")"
      cp -p "$ROOT/$path" "$TMP/$path"
    done
}

run_gate() {
  (
    cd "$TMP"
    bash build/titan2/qualify-c3b-product-source.sh \
      --static \
      --base HEAD \
      --allow-dirty
  ) 2>&1
}

copy_tree
cd "$TMP"
git init -q .
git config user.email test@example.invalid
git config user.name test
git add -A
git commit -q -m baseline

echo "===== BASELINE ====="
BASE_OUT="$(run_gate)"
grep -q '^C3B_PRODUCT_SOURCE_STATIC_QUALIFICATION=PASS' <<<"$BASE_OUT" || {
  printf '%s\n' "$BASE_OUT" | tail -40
  echo "C3B_SUPPRESSION_BUDGET_CONTRACT=FAIL_BASELINE" >&2
  exit 1
}
echo "C3B_SUPPRESSION_BUDGET_BASELINE=PASS"

TARGET="apps/r8/android/messages/src/main/java/org/sableos/messages/MainActivity.kt"

echo
echo "===== COMPILER SUPPRESSION MUST NOT CONSUME DETEKT BUDGET ====="
printf '\n// @Suppress("DEPRECATION")\n' >> "$TARGET"
COMPILER_OUT="$(run_gate)"
grep -q '^C3B_PRODUCT_SOURCE_STATIC_QUALIFICATION=PASS' <<<"$COMPILER_OUT" || {
  printf '%s\n' "$COMPILER_OUT" | tail -40
  echo "C3B_SUPPRESSION_BUDGET_COMPILER_RULE=FAIL" >&2
  exit 1
}
echo "C3B_SUPPRESSION_BUDGET_COMPILER_RULE=PASS_IGNORED"

git reset -q --hard HEAD

echo
echo "===== DECLARED DETEKT RULE MUST FAIL OVER BUDGET ====="
for _ in $(seq 1 40); do
  printf '// @Suppress("FunctionNaming")\n' >> "$TARGET"
done

set +e
DETEKT_OUT="$(run_gate)"
DETEKT_RC=$?
set -e

[[ "$DETEKT_RC" -ne 0 ]] || {
  echo "C3B_SUPPRESSION_BUDGET_DETEKT_OVERAGE=FAIL_GATE_PASSED" >&2
  exit 1
}

grep -q 'STATIC_FAIL:.*suppression budget exceeded: FunctionNaming' <<<"$DETEKT_OUT" || {
  printf '%s\n' "$DETEKT_OUT" | tail -40
  echo "C3B_SUPPRESSION_BUDGET_DETEKT_OVERAGE=FAIL_WRONG_REASON" >&2
  exit 1
}

echo "C3B_SUPPRESSION_BUDGET_DETEKT_OVERAGE=PASS_FAIL_CLOSED"
echo "C3B_SUPPRESSION_BUDGET_CONTRACT=PASS"
