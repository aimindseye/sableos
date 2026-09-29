#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
PLATFORM_SABLE_ROOT="${PLATFORM_SABLE_ROOT:-/srv/data/sable-build/platform_sable}"
EXPECTED_PLATFORM_SABLE_SHA="de9d4362f6779ddd0108fbd5804ebb25bdf4dc4c"

PLAN="$ROOT/docs/titan2/N1B2_IMAGE_PLAN.md"
BINDING="$ROOT/docs/titan2/N1B2_PLATFORM_SABLE_DOC_BINDING.tsv"
CAPABILITY="$ROOT/docs/titan2/N1B2_CAPABILITY_LEDGER.tsv"
DEFERRED="$ROOT/docs/titan2/N1B2_DEFERRED_LEDGER.tsv"
SELF="$ROOT/build/gates/n1b2-image-plan-contract.sh"

passes=0
warnings=0
failures=0

pass() {
  echo "$1=PASS${2:+ $2}"
  passes=$((passes + 1))
}

warn() {
  echo "$1=WARN${2:+ $2}"
  warnings=$((warnings + 1))
}

fail() {
  echo "$1=FAIL${2:+ $2}"
  failures=$((failures + 1))
}

require_file() {
  local label="$1"
  local path="$2"
  if [[ -f "$path" ]]; then
    pass "$label" "path=$path"
  else
    fail "$label" "missing=$path"
  fi
}

require_pattern() {
  local label="$1"
  local pattern="$2"
  local path="$3"
  if [[ -f "$path" ]] && grep -Fq -- "$pattern" "$path"; then
    pass "$label" "pattern=$pattern path=$path"
  else
    fail "$label" "missing_pattern=$pattern path=$path"
  fi
}

require_absent_pattern() {
  local label="$1"
  local pattern="$2"
  local path="$3"
  if [[ -f "$path" ]] && grep -Fq -- "$pattern" "$path"; then
    fail "$label" "forbidden_pattern=$pattern path=$path"
  else
    pass "$label" "absent=$pattern path=$path"
  fi
}

require_tsv_kind_count() {
  local label="$1"
  local kind="$2"
  local expected="$3"
  local count
  count=$(awk -F '\t' -v kind="$kind" 'NR > 1 && $5 == kind { count++ } END { print count + 0 }' "$BINDING")
  if [[ "$count" == "$expected" ]]; then
    pass "$label" "kind=$kind count=$count"
  else
    fail "$label" "kind=$kind expected=$expected actual=$count"
  fi
}

require_tsv_row() {
  local label="$1"
  local path="$2"
  local tsv="$3"
  if [[ -f "$tsv" ]] && awk -F '\t' -v path="$path" 'NR > 1 && $4 == path { found=1 } END { exit found ? 0 : 1 }' "$tsv"; then
    pass "$label" "path=$path"
  else
    fail "$label" "missing_row=$path tsv=$tsv"
  fi
}

check_platform_sable_rows() {
  local source_root="$1"
  local rel

  while IFS= read -r rel; do
    require_tsv_row "N1B2_BINDING_TOP_LEVEL_${rel//[^A-Za-z0-9]/_}" "$rel" "$BINDING"
  done < <(cd "$source_root" && find docs -maxdepth 1 -type f -name '*.md' -printf '%p\n' | sort)

  while IFS= read -r rel; do
    require_tsv_row "N1B2_BINDING_DESIGN_DOC_${rel//[^A-Za-z0-9]/_}" "$rel" "$BINDING"
  done < <(cd "$source_root" && find docs/design -maxdepth 1 -type f -name '*.md' -printf '%p\n' | sort)

  while IFS= read -r rel; do
    require_tsv_row "N1B2_BINDING_ARTIFACT_${rel//[^A-Za-z0-9]/_}" "$rel" "$BINDING"
  done < <(cd "$source_root" && find docs/design/artifacts -maxdepth 1 -type f -name '*.svg' -printf '%p\n' | sort)

  require_tsv_row "N1B2_BINDING_TITAN2_PROFILE" "docs/device-capabilities/TITAN2.md" "$BINDING"
}

echo "===== N1B2 IMAGE PLAN CONTRACT ====="
echo "ROOT=$ROOT"
echo "PLATFORM_SABLE_ROOT=$PLATFORM_SABLE_ROOT"
echo "DOCS_CHANGED=YES"
echo "GATE_CHANGED=YES"
echo "APP_CODE_CHANGED=NO"
echo "BUILD_CODE_CHANGED=NO"
echo "DEVICE_CODE_CHANGED=NO"
echo "IMAGE_BUILD=NO"
echo "FLASH_ENABLEMENT=NO"
echo "PUBLIC_RELEASE=NO"
echo "PRODUCTION_SIGNING=NO"

require_file "N1B2_IMAGE_PLAN_DOC_PRESENT" "$PLAN"
require_file "N1B2_PLATFORM_SABLE_DOC_BINDING_PRESENT" "$BINDING"
require_file "N1B2_CAPABILITY_LEDGER_PRESENT" "$CAPABILITY"
require_file "N1B2_DEFERRED_LEDGER_PRESENT" "$DEFERRED"
require_file "N1B2_IMAGE_PLAN_GATE_PRESENT" "$SELF"

require_pattern "N1B2_IMAGE_PLAN_SOURCE_SHA" "$EXPECTED_PLATFORM_SABLE_SHA" "$PLAN"
require_pattern "N1B2_BINDING_SOURCE_SHA" "$EXPECTED_PLATFORM_SABLE_SHA" "$BINDING"
require_pattern "N1B2_IMAGE_READY_RULE" "Existing APK builds != N1B2 image-ready" "$PLAN"
require_pattern "N1B2_NO_APP_PROMOTION_BY_BUILD_ONLY" "APP_PROMOTION_BY_BUILD_ONLY=NO" "$PLAN"
require_pattern "N1B2_FLASH_FAIL_CLOSED" "FLASH_ENABLEMENT=NO" "$PLAN"
require_pattern "N1B2_PUBLIC_RELEASE_FAIL_CLOSED" "PUBLIC_RELEASE=NO" "$PLAN"
require_pattern "N1B2_PRODUCTION_SIGNING_FAIL_CLOSED" "PRODUCTION_SIGNING=NO" "$PLAN"
require_pattern "N1B2_CELLULAR_RUNTIME_BAR" "CELLULAR_DATA_STABLE_30_MIN=PASS" "$PLAN"
require_pattern "N1B2_MESSAGES_BASELINE_DECLARED" "Messages implemented and validated" "$BINDING"

require_tsv_kind_count "N1B2_BINDING_TOP_LEVEL_DOC_COUNT" "top_level_doc" "17"
require_tsv_kind_count "N1B2_BINDING_DESIGN_DOC_COUNT" "design_doc" "52"
require_tsv_kind_count "N1B2_BINDING_ARTIFACT_COUNT" "design_artifact_svg" "23"
require_tsv_kind_count "N1B2_BINDING_DEVICE_CAPABILITY_COUNT" "device_capability_doc" "1"
require_tsv_kind_count "N1B2_BINDING_PLANNED_DOC_COUNT" "planned_design_doc" "2"
require_tsv_kind_count "N1B2_BINDING_PLANNED_ARTIFACT_COUNT" "planned_design_artifact" "2"

for capability in \
  TITAN_FAMILY_BASE_CAPABILITY_MATRIX \
  TITAN2_PROFILE \
  KEYBOARD_SHORTCUT_BASE \
  MINI_MODE \
  TEXT_INPUT_ALWAYS_WINS \
  TITAN2_BT_PAIRING_TEXT_ENTRY \
  TITAN2_ALT_ENTRY_SYSTEM_DIALOG \
  TITAN2_SYM_ENTRY_SYSTEM_DIALOG \
  TITAN2_SOFTWARE_KEYBOARD_FALLBACK \
  TITAN2_SETUP_WIZARD_TEXT_ENTRY \
  TITAN2_LOCKSCREEN_TEXT_ENTRY \
  TITAN2_WIFI_PASSWORD_TEXT_ENTRY \
  TITAN2_ACCOUNT_SIGNIN_TEXT_ENTRY \
  CELLULAR_STABLE_RUNTIME \
  ESIM \
  DUAL_SIM_5G \
  NETWORK_MANAGER_AUTHORITY \
  PER_APP_CELLULAR_WIFI_TOGGLES \
  CAMERA_BASE \
  CALL_RECORDER \
  SUBSCREEN \
  FM_RADIO \
  WORK_PROFILE; do
  require_tsv_row "N1B2_CAPABILITY_${capability}" "$capability" "$CAPABILITY"
done

for deferred in \
  KEYBOARD_SHORTCUT_BASE \
  MINI_MODE \
  SUBSCREEN_SHORTCUT_KEYBOARD_PTT \
  CALCULATOR \
  GAMES \
  AOD \
  PER_APP_CELLULAR_WIFI_TOGGLES \
  FM_RADIO; do
  require_tsv_row "N1B2_DEFERRED_${deferred}" "$deferred" "$DEFERRED"
done

require_absent_pattern "N1B2_DEFERRED_NO_MESSAGES" "MESSAGES" "$DEFERRED"
require_absent_pattern "N1B2_DEFERRED_NO_WEATHER" "WEATHER" "$DEFERRED"

if [[ -d "$PLATFORM_SABLE_ROOT/.git" ]]; then
  actual_sha=$(git -C "$PLATFORM_SABLE_ROOT" rev-parse HEAD)
  if [[ "$actual_sha" == "$EXPECTED_PLATFORM_SABLE_SHA" ]]; then
    pass "N1B2_PLATFORM_SABLE_SHA" "sha=$actual_sha"
  else
    fail "N1B2_PLATFORM_SABLE_SHA" "expected=$EXPECTED_PLATFORM_SABLE_SHA actual=$actual_sha"
  fi
else
  warn "N1B2_PLATFORM_SABLE_GIT" "not_a_git_checkout path=$PLATFORM_SABLE_ROOT"
fi

if [[ -d "$PLATFORM_SABLE_ROOT/docs" ]]; then
  top_level_count=$(find "$PLATFORM_SABLE_ROOT/docs" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')
  design_doc_count=$(find "$PLATFORM_SABLE_ROOT/docs/design" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')
  artifact_count=$(find "$PLATFORM_SABLE_ROOT/docs/design/artifacts" -maxdepth 1 -type f -name '*.svg' | wc -l | tr -d ' ')

  [[ "$top_level_count" == "17" ]] && pass "N1B2_PLATFORM_SABLE_TOP_LEVEL_DOCS" "count=$top_level_count" || fail "N1B2_PLATFORM_SABLE_TOP_LEVEL_DOCS" "expected=17 actual=$top_level_count"
  [[ "$design_doc_count" == "52" ]] && pass "N1B2_PLATFORM_SABLE_DESIGN_DOCS" "count=$design_doc_count" || fail "N1B2_PLATFORM_SABLE_DESIGN_DOCS" "expected=52 actual=$design_doc_count"
  [[ "$artifact_count" == "23" ]] && pass "N1B2_PLATFORM_SABLE_ARTIFACTS" "count=$artifact_count" || fail "N1B2_PLATFORM_SABLE_ARTIFACTS" "expected=23 actual=$artifact_count"

  check_platform_sable_rows "$PLATFORM_SABLE_ROOT"
else
  warn "N1B2_PLATFORM_SABLE_ROOT_PRESENT" "missing=$PLATFORM_SABLE_ROOT docs_binding_only"
fi

# Guard PR 206 scope when the repository has a git base available.
if git -C "$ROOT" rev-parse --verify origin/main >/dev/null 2>&1; then
  changed=$(git -C "$ROOT" diff --name-only origin/main...HEAD || true)
  if [[ -n "$changed" ]]; then
    forbidden=$(printf '%s\n' "$changed" | grep -Ev '^(docs/titan2/N1B2_IMAGE_PLAN.md|docs/titan2/N1B2_PLATFORM_SABLE_DOC_BINDING.tsv|docs/titan2/N1B2_CAPABILITY_LEDGER.tsv|docs/titan2/N1B2_DEFERRED_LEDGER.tsv|build/gates/n1b2-image-plan-contract.sh)$' || true)
    if [[ -z "$forbidden" ]]; then
      pass "N1B2_PR206_SCOPE_ONLY" "changed_files=$(printf '%s' "$changed" | wc -l | tr -d ' ')"
    else
      fail "N1B2_PR206_SCOPE_ONLY" "forbidden_files=$(printf '%s' "$forbidden" | paste -sd ',' -)"
    fi
  else
    warn "N1B2_PR206_SCOPE_ONLY" "no_diff_against_origin_main"
  fi
else
  warn "N1B2_PR206_SCOPE_ONLY" "origin_main_not_available"
fi

echo "N1B2_IMAGE_PLAN_PASSES=$passes"
echo "N1B2_IMAGE_PLAN_WARNINGS=$warnings"
echo "N1B2_IMAGE_PLAN_FAILURES=$failures"

if [[ "$failures" -eq 0 ]]; then
  echo "N1B2_IMAGE_PLAN_CONTRACT=PASS"
else
  echo "N1B2_IMAGE_PLAN_CONTRACT=FAIL"
  exit 1
fi
