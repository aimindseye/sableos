#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APPLY="$ROOT/build/titan2/apply-n1b3-radio-compat-product-delta.sh"
DOC="$ROOT/docs/titan2/N1B3_RADIO_COMPAT_IMPLEMENTATION_R1.md"

passes=0
failures=0

pass() {
  echo "$1=PASS${2:+ $2}"
  passes=$((passes + 1))
}

fail() {
  echo "$1=FAIL${2:+ $2}" >&2
  failures=$((failures + 1))
}

require_file() {
  local key="$1"
  local path="$2"
  if [[ -f "$path" ]]; then
    pass "$key" "path=$path"
  else
    fail "$key" "missing=$path"
  fi
}

require_text() {
  local key="$1"
  local token="$2"
  local path="$3"
  if grep -Fq "$token" "$path"; then
    pass "$key" "token=$token path=$path"
  else
    fail "$key" "missing_token=$token path=$path"
  fi
}

forbid_text() {
  local key="$1"
  local token="$2"
  local path="$3"
  if grep -Fq "$token" "$path"; then
    fail "$key" "forbidden_token=$token path=$path"
  else
    pass "$key" "token_absent=$token path=$path"
  fi
}

echo "===== N1B3 RADIO COMPAT PRODUCT DELTA CONTRACT ====="
echo "ROOT=$ROOT"
echo "APPLY=$APPLY"
echo "DOC=$DOC"

require_file N1B3_RADIO_COMPAT_PRODUCT_DELTA_SCRIPT "$APPLY"
require_file N1B3_RADIO_COMPAT_PRODUCT_DELTA_DOC "$DOC"

if bash -n "$APPLY"; then
  pass N1B3_RADIO_COMPAT_PRODUCT_DELTA_BASH_N "path=$APPLY"
else
  fail N1B3_RADIO_COMPAT_PRODUCT_DELTA_BASH_N "path=$APPLY"
fi

require_text N1B3_RADIO_COMPAT_DOC_PRODUCT_DELTA \
  "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_PRODUCT_DELTA=YES" "$DOC"
require_text N1B3_RADIO_COMPAT_DOC_DISABLES_MTK_IMS_DEFAULT \
  "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_MTK_IMS_DEFAULT_DISABLED=YES" "$DOC"
require_text N1B3_RADIO_COMPAT_DOC_APPLIES_TO_PROFILE \
  "N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_APPLIES_TO_N1B2_PRODUCT_PROFILE=YES" "$DOC"

require_text N1B3_RADIO_COMPAT_SCRIPT_PROPERTY_NAME \
  'MTK_IMS_PROPERTY="persist.sys.phh.ims.mtk"' "$APPLY"
require_text N1B3_RADIO_COMPAT_SCRIPT_PROPERTY_VALUE \
  'MTK_IMS_VALUE="false"' "$APPLY"
require_text N1B3_RADIO_COMPAT_SCRIPT_COPY \
  "radio-compat.env:system/etc/sableos/profiles/titan2/radio-compat.env" "$APPLY"
require_text N1B3_RADIO_COMPAT_SCRIPT_MARKER \
  "TITAN2_RADIO_COMPAT_PROFILE_PACKAGED=YES" "$APPLY"
require_text N1B3_RADIO_COMPAT_SCRIPT_IDEMPOTENCE \
  "SABLE_N1B3_RADIO_COMPAT_START" "$APPLY"
require_text N1B3_RADIO_COMPAT_SCRIPT_RESULT \
  "N1B3_RADIO_COMPAT_PRODUCT_DELTA=PASS" "$APPLY"
require_text N1B3_RADIO_COMPAT_SCRIPT_STALE_PAYLOAD_PATH \
  "STALE_MTK_PAYLOAD_DIR_REL=\"vendor/sable/n1b2/mtk-telephony-payload\"" "$APPLY"
require_text N1B3_RADIO_COMPAT_SCRIPT_STALE_PAYLOAD_FAIL \
  "stale_mtk_payload_present" "$APPLY"
require_text N1B3_RADIO_COMPAT_SCRIPT_STALE_PAYLOAD_PASS_MARKER \
  "N1B3_STALE_MTK_PAYLOAD_ABSENT=PASS" "$APPLY"

for forbidden in \
  "adb " \
  "fastboot " \
  "setprop " \
  "reboot " \
  "MtkTeleService.apk" \
  "MtkTelephonyProvider.apk" \
  "MtkMmsService.apk" \
  "MtkTelecom.apk" \
  "ImsService.apk" \
  ".jar:system" \
  ".so:system" \
  "vendor:system/vendor"
do
  forbid_text N1B3_RADIO_COMPAT_SCRIPT_FORBIDDEN_TOKEN "$forbidden" "$APPLY"
done

fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/vendor/sable/n1b2/profiles/titan2"

cat > "$fixture/vendor/sable/n1b2/sable_n1b2_product_profile.mk" <<'EOF'
# fixture profile
PRODUCT_SYSTEM_PROPERTIES += \
    ro.sableos.release=N1B2
EOF

cat > "$fixture/vendor/sable/n1b2/product-closure.env" <<'EOF'
N1B2_PRODUCT_PROFILE=YES
N1B2_MOBILE_NETWORK_TRIAGE_REQUIRED=YES
EOF

if bash "$APPLY" --android-root "$fixture" > "$fixture/apply-first.log"; then
  pass N1B3_RADIO_COMPAT_PRODUCT_DELTA_FIXTURE_FIRST "log=$fixture/apply-first.log"
else
  cat "$fixture/apply-first.log" || true
  fail N1B3_RADIO_COMPAT_PRODUCT_DELTA_FIXTURE_FIRST "log=$fixture/apply-first.log"
fi

profile="$fixture/vendor/sable/n1b2/sable_n1b2_product_profile.mk"
markers="$fixture/vendor/sable/n1b2/product-closure.env"
radio_env="$fixture/vendor/sable/n1b2/profiles/titan2/radio-compat.env"

require_text N1B3_RADIO_COMPAT_FIXTURE_PROPERTY \
  "persist.sys.phh.ims.mtk=false" "$profile"
require_text N1B3_RADIO_COMPAT_FIXTURE_COPY \
  "radio-compat.env:system/etc/sableos/profiles/titan2/radio-compat.env" "$profile"
require_text N1B3_RADIO_COMPAT_FIXTURE_MARKERS \
  "N1B3_MTK_IMS_DEFAULT_DISABLED=YES" "$markers"
require_text N1B3_RADIO_COMPAT_FIXTURE_ENV \
  "TITAN2_RADIO_COMPAT_PROFILE_PACKAGED=YES" "$radio_env"
require_text N1B3_RADIO_COMPAT_FIXTURE_STALE_PAYLOAD_ABSENT \
  "N1B3_STALE_MTK_PAYLOAD_ABSENT=PASS" "$fixture/apply-first.log"

if bash "$APPLY" --android-root "$fixture" > "$fixture/apply-second.log"; then
  pass N1B3_RADIO_COMPAT_PRODUCT_DELTA_FIXTURE_SECOND "log=$fixture/apply-second.log"
else
  cat "$fixture/apply-second.log" || true
  fail N1B3_RADIO_COMPAT_PRODUCT_DELTA_FIXTURE_SECOND "log=$fixture/apply-second.log"
fi

patch_count="$(grep -Fc "SABLE_N1B3_RADIO_COMPAT_START" "$profile")"
if [[ "$patch_count" == "1" ]]; then
  pass N1B3_RADIO_COMPAT_PRODUCT_DELTA_IDEMPOTENT "patch_count=$patch_count"
else
  fail N1B3_RADIO_COMPAT_PRODUCT_DELTA_IDEMPOTENT "patch_count=$patch_count"
fi

stale_fixture="$(mktemp -d)"
mkdir -p "$stale_fixture/vendor/sable/n1b2/mtk-telephony-payload"
mkdir -p "$stale_fixture/vendor/sable/n1b2/profiles/titan2"
cat > "$stale_fixture/vendor/sable/n1b2/sable_n1b2_product_profile.mk" <<'EOF'
# stale fixture profile
PRODUCT_SYSTEM_PROPERTIES += \
    ro.sableos.release=N1B2
EOF
cat > "$stale_fixture/vendor/sable/n1b2/product-closure.env" <<'EOF'
N1B2_PRODUCT_PROFILE=YES
N1B2_MOBILE_NETWORK_TRIAGE_REQUIRED=YES
EOF

if bash "$APPLY" --android-root "$stale_fixture" > "$stale_fixture/apply-stale.log" 2>&1; then
  cat "$stale_fixture/apply-stale.log" || true
  fail N1B3_RADIO_COMPAT_PRODUCT_DELTA_STALE_PAYLOAD_FIXTURE "unexpected_success"
else
  if grep -Fq "stale_mtk_payload_present" "$stale_fixture/apply-stale.log"; then
    pass N1B3_RADIO_COMPAT_PRODUCT_DELTA_STALE_PAYLOAD_FIXTURE "fail_closed=YES"
  else
    cat "$stale_fixture/apply-stale.log" || true
    fail N1B3_RADIO_COMPAT_PRODUCT_DELTA_STALE_PAYLOAD_FIXTURE "missing_fail_closed_marker"
  fi
fi

echo "N1B3_RADIO_COMPAT_PRODUCT_DELTA_CONTRACT_PASSES=$passes"
echo "N1B3_RADIO_COMPAT_PRODUCT_DELTA_CONTRACT_FAILURES=$failures"

if [[ "$failures" -eq 0 ]]; then
  echo "N1B3_RADIO_COMPAT_PRODUCT_DELTA_CONTRACT=PASS"
else
  echo "N1B3_RADIO_COMPAT_PRODUCT_DELTA_CONTRACT=FAIL"
  exit 1
fi
