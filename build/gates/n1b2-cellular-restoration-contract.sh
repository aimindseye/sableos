#!/usr/bin/env bash
set -euo pipefail

STAGE_SMOKE="${STAGE_SMOKE:-NO}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stage-smoke)
      STAGE_SMOKE="$2"
      shift 2
      ;;
    --stage-smoke=*)
      STAGE_SMOKE="${1#*=}"
      shift
      ;;
    *)
      echo "UNKNOWN_ARG=$1" >&2
      exit 2
      ;;
  esac
done

case "$STAGE_SMOKE" in
  YES|NO) ;;
  *)
    echo "STAGE_SMOKE_INVALID=$STAGE_SMOKE" >&2
    exit 2
    ;;
esac

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

required_files=(
  "docs/titan2/N1B2_CELLULAR_PR208_HANDOFF.md"
  "build/titan2/stage-n1b2-mtk-telephony-payload.sh"
  "build/titan2/audit-n1b2-stock-telephony-apks.sh"
  "build/titan2/prepare-n1b2-mtk-telephony-build-payload.sh"
  "build/titan2/verify-n1b2-mtk-telephony-target-files.sh"
  "build/titan2/build-n1b2-image-candidate-with-mtk-telephony.sh"
  "build/gates/n1b2-cellular-restoration-contract.sh"
)

for f in "${required_files[@]}"; do
  if [[ -f "$f" ]]; then
    pass "N1B2_CELLULAR_PR208_FILE" "path=$f"
  else
    fail "N1B2_CELLULAR_PR208_FILE" "missing=$f"
  fi
done

for f in \
  build/titan2/stage-n1b2-mtk-telephony-payload.sh \
  build/titan2/audit-n1b2-stock-telephony-apks.sh \
  build/titan2/prepare-n1b2-mtk-telephony-build-payload.sh \
  build/titan2/verify-n1b2-mtk-telephony-target-files.sh \
  build/titan2/build-n1b2-image-candidate-with-mtk-telephony.sh \
  build/gates/n1b2-cellular-restoration-contract.sh
do
  if bash -n "$f"; then
    pass "N1B2_CELLULAR_PR208_BASH_N" "path=$f"
  else
    fail "N1B2_CELLULAR_PR208_BASH_N" "path=$f"
  fi
done

for marker in \
  "PR208_PROPRIETARY_PAYLOAD_COMMITTED=NO" \
  "PR208_VENDOR_PARTITION_COPY=NO" \
  "PR208_FULL_VENDOR_COPY=NO" \
  "PR208_PAYLOAD_HASH_GATE=YES" \
  "PR208_LOCAL_STOCK_INPUT_REQUIRED=YES" \
  "PR208_SYSTEM_EXT_MTK_IMS_PAYLOAD=YES" \
  "PR208_PRODUCT_COPY_FILES_WIRING=YES" \
  "PR208_BUILD_WIRING=YES" \
  "PR208_IMAGE_PAYLOAD_VERIFICATION=YES" \
  "PR208_FLASH_SCRIPT_MUTATION=NO_NOT_REQUIRED" \
  "PR208_STOCK_APK_AUDIT=YES"
do
  if grep -Fq "$marker" docs/titan2/N1B2_CELLULAR_PR208_HANDOFF.md; then
    pass "N1B2_CELLULAR_PR208_DOC_MARKER" "marker=$marker"
  else
    fail "N1B2_CELLULAR_PR208_DOC_MARKER" "missing=$marker"
  fi
done

check_token() {
  local file="$1"
  local token="$2"
  local label="$3"
  if grep -Fq "$token" "$file"; then
    pass "$label" "file=$file token=$token"
  else
    fail "$label" "file=$file missing_token=$token"
  fi
}

check_token \
  build/titan2/prepare-n1b2-mtk-telephony-build-payload.sh \
  "PRODUCT_COPY_FILES" \
  "N1B2_CELLULAR_PR208_BUILD_WIRING_TOKEN"
check_token \
  build/titan2/prepare-n1b2-mtk-telephony-build-payload.sh \
  "sable_n1b2_product_profile.mk" \
  "N1B2_CELLULAR_PR208_BUILD_WIRING_TOKEN"
check_token \
  build/titan2/prepare-n1b2-mtk-telephony-build-payload.sh \
  "TARGET_COPY_OUT_SYSTEM_EXT" \
  "N1B2_CELLULAR_PR208_BUILD_WIRING_TOKEN"
check_token \
  build/titan2/build-n1b2-image-candidate-with-mtk-telephony.sh \
  "build-n1b2-image-candidate.sh" \
  "N1B2_CELLULAR_PR208_BUILD_WRAPPER_TOKEN"
check_token \
  build/titan2/build-n1b2-image-candidate-with-mtk-telephony.sh \
  "verify-n1b2-mtk-telephony-target-files.sh" \
  "N1B2_CELLULAR_PR208_BUILD_WRAPPER_TOKEN"
check_token \
  build/titan2/verify-n1b2-mtk-telephony-target-files.sh \
  "SYSTEM/system_ext/" \
  "N1B2_CELLULAR_PR208_TARGET_FILES_VERIFY_TOKEN"
check_token \
  build/titan2/audit-n1b2-stock-telephony-apks.sh \
  "N1B2_STOCK_APK_AUDIT" \
  "N1B2_CELLULAR_PR208_STOCK_APK_AUDIT_TOKEN"
check_token \
  build/titan2/audit-n1b2-stock-telephony-apks.sh \
  "sharedUserId" \
  "N1B2_CELLULAR_PR208_STOCK_APK_AUDIT_TOKEN"

if git ls-files \
  | grep -Ei '(^|/)(MtkMmsService|MtkTelecom|MtkTelephonyProvider|MtkTeleService|ImsService)\.apk$|(^|/)mediatek-.*\.jar$|(^|/)lib(imsma|sink|source|vcodec_cap|comutils|signal).*\.so$' \
  >/tmp/n1b2_pr208_committed_payloads.txt
then
  cat /tmp/n1b2_pr208_committed_payloads.txt
  fail "N1B2_CELLULAR_PR208_PROPRIETARY_PAYLOAD_COMMITTED" "see=/tmp/n1b2_pr208_committed_payloads.txt"
else
  pass "N1B2_CELLULAR_PR208_PROPRIETARY_PAYLOAD_COMMITTED" "none"
fi

changed_files="$(
  {
    git diff --name-only origin/main...HEAD 2>/dev/null || true
    git diff --name-only 2>/dev/null || true
    git diff --cached --name-only 2>/dev/null || true
  } | sort -u
)"

allowed_regex='^(docs/titan2/N1B2_CELLULAR_PR208_HANDOFF\.md|build/titan2/stage-n1b2-mtk-telephony-payload\.sh|build/titan2/audit-n1b2-stock-telephony-apks\.sh|build/titan2/prepare-n1b2-mtk-telephony-build-payload\.sh|build/titan2/verify-n1b2-mtk-telephony-target-files\.sh|build/titan2/build-n1b2-image-candidate-with-mtk-telephony\.sh|build/gates/n1b2-cellular-restoration-contract\.sh)$'

unexpected="$(
  printf '%s\n' "$changed_files" \
    | sed '/^$/d' \
    | grep -Ev "$allowed_regex" || true
)"

if [[ -z "$unexpected" ]]; then
  changed_count="$(printf '%s\n' "$changed_files" | sed '/^$/d' | wc -l)"
  pass "N1B2_CELLULAR_PR208_SCOPE_ONLY" "changed_files=$changed_count"
else
  printf '%s\n' "$unexpected"
  fail "N1B2_CELLULAR_PR208_SCOPE_ONLY" "unexpected_files_present"
fi

if [[ "$STAGE_SMOKE" == "YES" ]]; then
  if [[ -z "${STOCK_ROOT:-}" || ! -d "${STOCK_ROOT:-}" ]]; then
    fail "N1B2_CELLULAR_PR208_STAGE_SMOKE" "STOCK_ROOT_required"
  else
    smoke_dir="/tmp/SABLE_N1B2_PR208_STAGE_SMOKE_$(date -u +%Y%m%dT%H%M%SZ)"
    if STOCK_ROOT="$STOCK_ROOT" \
      bash build/titan2/stage-n1b2-mtk-telephony-payload.sh \
        --stock-root "$STOCK_ROOT" \
        --evidence-dir "$smoke_dir" \
        --copy-payload NO
    then
      if grep -Fq 'N1B2_MTK_PAYLOAD_STAGE=PASS' "$smoke_dir/pr208-stock-mtk-payload-markers.txt"; then
        pass "N1B2_CELLULAR_PR208_STAGE_SMOKE" "evidence_dir=$smoke_dir"
      else
        fail "N1B2_CELLULAR_PR208_STAGE_SMOKE" "missing_pass_marker=$smoke_dir"
      fi
    else
      fail "N1B2_CELLULAR_PR208_STAGE_SMOKE" "script_failed"
    fi
  fi
else
  warn "N1B2_CELLULAR_PR208_STAGE_SMOKE" "skipped"
fi

echo "N1B2_CELLULAR_PR208_CONTRACT_PASSES=$passes"
echo "N1B2_CELLULAR_PR208_CONTRACT_WARNINGS=$warnings"
echo "N1B2_CELLULAR_PR208_CONTRACT_FAILURES=$failures"

if [[ "$failures" -eq 0 ]]; then
  echo "N1B2_CELLULAR_PR208_CONTRACT=PASS"
else
  echo "N1B2_CELLULAR_PR208_CONTRACT=FAIL"
  exit 1
fi
