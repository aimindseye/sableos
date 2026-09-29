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
  "docs/titan2/N1B3_RADIO_COMPAT_IMPLEMENTATION_R1.md"
  "build/titan2/audit-n1b3-radio-compat-source.sh"
  "build/gates/n1b3-radio-compat-implementation-contract.sh"
)

for f in "${required_files[@]}"; do
  if [[ -f "$f" ]]; then
    pass "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_FILE" "path=$f"
  else
    fail "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_FILE" "missing=$f"
  fi
done

for f in \
  build/titan2/audit-n1b3-radio-compat-source.sh \
  build/gates/n1b3-radio-compat-implementation-contract.sh
do
  if bash -n "$f"; then
    pass "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_BASH_N" "path=$f"
  else
    fail "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_BASH_N" "path=$f"
  fi
done

for marker in \
  "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1=YES" \
  "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_BASE_MAIN=e5267b928a53c8fc4861c5f8118b58e6a10d68b3" \
  "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_BUILDS_ON_PR209=YES" \
  "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_SUPERSEDES_PR208=YES" \
  "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_NO_STOCK_APK_IMPORT=YES" \
  "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_NO_MTK_JAR_SO_PAYLOAD=YES" \
  "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_NO_VENDOR_COPY=YES" \
  "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_NO_FLASH=YES" \
  "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_SOURCE_AUDIT_FIRST=YES" \
  "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_TARGETS_MTK_INDICATION=YES" \
  "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_TARGETS_IMS_BINDING=YES" \
  "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_TARGETS_WWAN_DROP=YES"
do
  if grep -Fq "$marker" docs/titan2/N1B3_RADIO_COMPAT_IMPLEMENTATION_R1.md; then
    pass "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_DOC_MARKER" "marker=$marker"
  else
    fail "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_DOC_MARKER" "missing=$marker"
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
  build/titan2/audit-n1b3-radio-compat-source.sh \
  "N1B3_RADIO_COMPAT_SOURCE_AUDIT_GREP_SCOPE=EXPLICIT_SOURCE_ROOTS_ONLY" \
  "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_AUDIT_TOKEN"

check_token \
  build/titan2/audit-n1b3-radio-compat-source.sh \
  "mtkNetworkIndication" \
  "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_AUDIT_TOKEN"

check_token \
  build/titan2/audit-n1b3-radio-compat-source.sh \
  "com\\.mediatek\\.ims" \
  "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_AUDIT_TOKEN"

check_token \
  build/titan2/audit-n1b3-radio-compat-source.sh \
  "UNSOL_DATA_CALL_LIST_CHANGED" \
  "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_AUDIT_TOKEN"

all_files="$(
  {
    git ls-files
    git ls-files --others --exclude-standard
  } | sort -u
)"

if printf '%s\n' "$all_files" \
  | grep -Ei '(^|/)(MtkMmsService|MtkTelecom|MtkTelephonyProvider|MtkTeleService|ImsService)\.apk$|(^|/)mediatek-.*\.jar$|(^|/)lib(imsma|sink|source|vcodec_cap|comutils|signal).*\.so$' \
  >/tmp/n1b3_radio_compat_payloads.txt
then
  cat /tmp/n1b3_radio_compat_payloads.txt
  fail "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_PROPRIETARY_PAYLOAD_COMMITTED" "see=/tmp/n1b3_radio_compat_payloads.txt"
else
  pass "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_PROPRIETARY_PAYLOAD_COMMITTED" "none"
fi

changed_files="$(
  {
    git diff --name-only origin/main...HEAD 2>/dev/null || true
    git diff --name-only 2>/dev/null || true
    git diff --cached --name-only 2>/dev/null || true
    git ls-files --others --exclude-standard 2>/dev/null || true
  } | sort -u
)"

allowed_regex='^(docs/titan2/N1B3_RADIO_COMPAT_IMPLEMENTATION_R1\.md|build/titan2/audit-n1b3-radio-compat-source\.sh|build/gates/n1b3-radio-compat-implementation-contract\.sh)$'

unexpected="$(
  printf '%s\n' "$changed_files" \
    | sed '/^$/d' \
    | grep -Ev "$allowed_regex" || true
)"

if [[ -z "$unexpected" ]]; then
  changed_count="$(printf '%s\n' "$changed_files" | sed '/^$/d' | wc -l | tr -d ' ')"
  pass "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_SCOPE_ONLY" "changed_files=$changed_count"
else
  printf '%s\n' "$unexpected"
  fail "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_SCOPE_ONLY" "unexpected_files_present"
fi

if git diff origin/main...HEAD -- . 2>/dev/null \
  | grep -E 'mtk-telephony-payload|build-n1b2-image-candidate-with-mtk-telephony|PRODUCT_COPY_FILES.*Mtk|MtkTeleService\.apk|MtkTelephonyProvider\.apk|MtkMmsService\.apk|MtkTelecom\.apk' \
  >/tmp/n1b3_radio_compat_payload_wiring_tokens.txt
then
  cat /tmp/n1b3_radio_compat_payload_wiring_tokens.txt
  fail "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_NO_PAYLOAD_WIRING_TOKENS" "see=/tmp/n1b3_radio_compat_payload_wiring_tokens.txt"
else
  pass "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_NO_PAYLOAD_WIRING_TOKENS" "clean"
fi

echo "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_CONTRACT_PASSES=$passes"
echo "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_CONTRACT_WARNINGS=$warnings"
echo "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_CONTRACT_FAILURES=$failures"

if [[ "$failures" -eq 0 ]]; then
  echo "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_CONTRACT=PASS"
else
  echo "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_CONTRACT=FAIL"
  exit 1
fi
