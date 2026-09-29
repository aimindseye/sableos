#!/usr/bin/env bash
set -euo pipefail

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
  "docs/titan2/N1B2_RADIO_COMPAT_R1.md"
  "build/titan2/capture-n1b2-radio-compat-runtime.sh"
  "build/gates/n1b2-radio-compat-contract.sh"
)

for f in "${required_files[@]}"; do
  if [[ -f "$f" ]]; then
    pass "N1B2_RADIO_COMPAT_R1_FILE" "path=$f"
  else
    fail "N1B2_RADIO_COMPAT_R1_FILE" "missing=$f"
  fi
done

for f in \
  build/titan2/capture-n1b2-radio-compat-runtime.sh \
  build/gates/n1b2-radio-compat-contract.sh
do
  if [[ -f "$f" ]] && bash -n "$f"; then
    pass "N1B2_RADIO_COMPAT_R1_BASH_N" "path=$f"
  else
    fail "N1B2_RADIO_COMPAT_R1_BASH_N" "path=$f"
  fi
done

required_doc_markers=(
  "N1B2_RADIO_COMPAT_R1_SUPERSEDES_PR208=YES"
  "N1B2_RADIO_COMPAT_R1_NO_STOCK_APK_IMPORT=YES"
  "N1B2_RADIO_COMPAT_R1_NO_FLASH=YES"
  "N1B2_RADIO_COMPAT_R1_NO_VENDOR_COPY=YES"
  "N1B2_RADIO_COMPAT_R1_GOOD_WINDOW_PROVEN=YES"
  "N1B2_RADIO_COMPAT_R1_DROP_WINDOW_PROVEN=YES"
  "N1B2_RADIO_COMPAT_R1_MTK_INDICATION_SUSPECT=YES"
  "N1B2_RADIO_COMPAT_R1_IMS_BINDING_SUSPECT=YES"
)

for marker in "${required_doc_markers[@]}"; do
  if grep -Fq "$marker" docs/titan2/N1B2_RADIO_COMPAT_R1.md; then
    pass "N1B2_RADIO_COMPAT_R1_DOC_MARKER" "marker=$marker"
  else
    fail "N1B2_RADIO_COMPAT_R1_DOC_MARKER" "missing=$marker"
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

check_token build/titan2/capture-n1b2-radio-compat-runtime.sh "timeout" "N1B2_RADIO_COMPAT_R1_CAPTURE_TOKEN"
check_token build/titan2/capture-n1b2-radio-compat-runtime.sh "logcat" "N1B2_RADIO_COMPAT_R1_CAPTURE_TOKEN"
check_token build/titan2/capture-n1b2-radio-compat-runtime.sh "dumpsys phone" "N1B2_RADIO_COMPAT_R1_CAPTURE_TOKEN"
check_token build/titan2/capture-n1b2-radio-compat-runtime.sh "mtkNetworkIndication == NULL" "N1B2_RADIO_COMPAT_R1_CAPTURE_TOKEN"
check_token build/titan2/capture-n1b2-radio-compat-runtime.sh "ERROR_UNSPECIFIED" "N1B2_RADIO_COMPAT_R1_CAPTURE_TOKEN"
check_token build/titan2/capture-n1b2-radio-compat-runtime.sh "N1B2_RADIO_COMPAT_CAPTURE_GREP_SCOPE=EXPLICIT_CAPTURE_FILES_ONLY" "N1B2_RADIO_COMPAT_R1_CAPTURE_TOKEN"

if git ls-files \
  | grep -Ei '(^|/)(MtkMmsService|MtkTelecom|MtkTelephonyProvider|MtkTeleService|ImsService)\.apk$|(^|/)mediatek-.*\.jar$|(^|/)lib(imsma|sink|source|vcodec_cap|comutils|signal).*\.so$' \
  >/tmp/n1b2_radio_compat_committed_payloads.txt
then
  cat /tmp/n1b2_radio_compat_committed_payloads.txt
  fail "N1B2_RADIO_COMPAT_R1_PROPRIETARY_PAYLOAD_COMMITTED" "see=/tmp/n1b2_radio_compat_committed_payloads.txt"
else
  pass "N1B2_RADIO_COMPAT_R1_PROPRIETARY_PAYLOAD_COMMITTED" "none"
fi

changed_files="$(
  {
    git diff --name-only origin/main...HEAD 2>/dev/null || true
    git diff --name-only 2>/dev/null || true
    git diff --cached --name-only 2>/dev/null || true
  } | sort -u
)"

allowed_regex='^(docs/titan2/N1B2_RADIO_COMPAT_R1\.md|build/titan2/capture-n1b2-radio-compat-runtime\.sh|build/gates/n1b2-radio-compat-contract\.sh)$'
unexpected="$(
  printf '%s\n' "$changed_files" \
    | sed '/^$/d' \
    | grep -Ev "$allowed_regex" || true
)"

if [[ -z "$unexpected" ]]; then
  changed_count="$(printf '%s\n' "$changed_files" | sed '/^$/d' | wc -l | tr -d ' ')"
  pass "N1B2_RADIO_COMPAT_R1_SCOPE_ONLY" "changed_files=$changed_count"
else
  printf '%s\n' "$unexpected"
  fail "N1B2_RADIO_COMPAT_R1_SCOPE_ONLY" "unexpected_files_present"
fi

if grep -R --line-number -E 'PRODUCT_COPY_FILES|build-n1b2-image-candidate-with-mtk-telephony|MtkTeleService\.apk|MtkTelephonyProvider\.apk|MtkMmsService\.apk|MtkTelecom\.apk' \
  docs/titan2/N1B2_RADIO_COMPAT_R1.md \
  build/titan2/capture-n1b2-radio-compat-runtime.sh \
  >/tmp/n1b2_radio_compat_payload_tokens.txt
then
  cat /tmp/n1b2_radio_compat_payload_tokens.txt
  fail "N1B2_RADIO_COMPAT_R1_NO_PAYLOAD_WIRING_TOKENS" "see=/tmp/n1b2_radio_compat_payload_tokens.txt"
else
  pass "N1B2_RADIO_COMPAT_R1_NO_PAYLOAD_WIRING_TOKENS" "clean"
fi

echo "N1B2_RADIO_COMPAT_R1_CONTRACT_PASSES=$passes"
echo "N1B2_RADIO_COMPAT_R1_CONTRACT_WARNINGS=$warnings"
echo "N1B2_RADIO_COMPAT_R1_CONTRACT_FAILURES=$failures"

if [[ "$failures" -eq 0 ]]; then
  echo "N1B2_RADIO_COMPAT_R1_CONTRACT=PASS"
else
  echo "N1B2_RADIO_COMPAT_R1_CONTRACT=FAIL"
  exit 1
fi
