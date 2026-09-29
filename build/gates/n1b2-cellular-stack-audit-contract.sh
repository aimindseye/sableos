#!/usr/bin/env bash
set -euo pipefail

# PR 207 is an audit-only, read-only gate. It validates evidence plumbing and
# explicitly blocks implementation, image build, and flash enablement changes.
ROOT="${ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
STATIC_SCRIPT="$ROOT/build/titan2/audit-n1b2-cellular-stack.sh"
RUNTIME_SCRIPT="$ROOT/build/titan2/capture-n1b2-cellular-runtime.sh"
AUDIT_DOC="$ROOT/docs/titan2/N1B2_CELLULAR_STACK_AUDIT.md"
ROOT_CAUSE_DOC="$ROOT/docs/titan2/N1B2_CELLULAR_ROOT_CAUSE.md"
SELF="$ROOT/build/gates/n1b2-cellular-stack-audit-contract.sh"

passes=0
warnings=0
failures=0
RUN_STATIC_SMOKE=NO

while [[ $# -gt 0 ]]; do
  case "$1" in
    --static-smoke)
      if [[ $# -lt 2 ]]; then
        echo "ARG_VALUE_REQUIRED=--static-smoke" >&2
        exit 2
      fi
      RUN_STATIC_SMOKE="$2"
      shift 2
      ;;
    --static-smoke=*)
      RUN_STATIC_SMOKE="${1#*=}"
      shift
      ;;
    *)
      echo "UNKNOWN_ARG=$1" >&2
      exit 2
      ;;
  esac
done

case "$RUN_STATIC_SMOKE" in
  YES|NO) ;;
  *)
    echo "STATIC_SMOKE_INVALID=$RUN_STATIC_SMOKE expected=YES_OR_NO" >&2
    exit 2
    ;;
esac

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

require_executable_or_bashable() {
  local label="$1"
  local path="$2"
  if [[ -f "$path" ]] && head -n 1 "$path" | grep -Fq '#!/usr/bin/env bash'; then
    pass "$label" "path=$path"
  else
    fail "$label" "missing_bash_shebang path=$path"
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
  if [[ -f "$path" ]] && grep -Eq -- "$pattern" "$path"; then
    fail "$label" "forbidden_pattern=$pattern path=$path"
  else
    pass "$label" "absent=$pattern path=$path"
  fi
}

echo "===== N1B2 CELLULAR STACK AUDIT CONTRACT ====="
echo "ROOT=$ROOT"
echo "DOCS_CHANGED=YES"
echo "GATE_CHANGED=YES"
echo "SCRIPT_CHANGED=YES"
echo "SOURCE_MUTATION=NO"
echo "MODULE_CHANGES=NO"
echo "OVERLAY_CHANGES=NO"
echo "SEPOLICY_CHANGES=NO"
echo "PERMISSION_CHANGES=NO"
echo "PRODUCT_PACKAGE_CHANGES=NO"
echo "IMAGE_BUILD=NO"
echo "FLASH_ENABLEMENT=NO"
echo "FASTBOOT_REQUIRED=NO"
echo "FASTBOOTD_REQUIRED=NO"
echo "ANDROID_MODE_RUNTIME_CAPTURE=YES"
echo "READ_ONLY_AUDIT=YES"

require_file "N1B2_CELLULAR_STATIC_SCRIPT_PRESENT" "$STATIC_SCRIPT"
require_file "N1B2_CELLULAR_RUNTIME_SCRIPT_PRESENT" "$RUNTIME_SCRIPT"
require_file "N1B2_CELLULAR_AUDIT_DOC_PRESENT" "$AUDIT_DOC"
require_file "N1B2_CELLULAR_ROOT_CAUSE_DOC_PRESENT" "$ROOT_CAUSE_DOC"
require_file "N1B2_CELLULAR_AUDIT_GATE_PRESENT" "$SELF"

require_executable_or_bashable "N1B2_CELLULAR_STATIC_SCRIPT_BASH" "$STATIC_SCRIPT"
require_executable_or_bashable "N1B2_CELLULAR_RUNTIME_SCRIPT_BASH" "$RUNTIME_SCRIPT"

bash -n "$STATIC_SCRIPT" && pass "N1B2_CELLULAR_STATIC_SCRIPT_SYNTAX" || fail "N1B2_CELLULAR_STATIC_SCRIPT_SYNTAX"
bash -n "$RUNTIME_SCRIPT" && pass "N1B2_CELLULAR_RUNTIME_SCRIPT_SYNTAX" || fail "N1B2_CELLULAR_RUNTIME_SCRIPT_SYNTAX"
bash -n "$SELF" && pass "N1B2_CELLULAR_GATE_SYNTAX" || fail "N1B2_CELLULAR_GATE_SYNTAX"

for path in "$AUDIT_DOC" "$ROOT_CAUSE_DOC" "$STATIC_SCRIPT" "$RUNTIME_SCRIPT" "$SELF"; do
  require_pattern "N1B2_CELLULAR_READ_ONLY_${path//[^A-Za-z0-9]/_}" "read-only" "$path"
done

require_pattern "N1B2_CELLULAR_ANDROID_MODE_DOC" "ANDROID_MODE_REQUIRED=YES" "$AUDIT_DOC"
require_pattern "N1B2_CELLULAR_FASTBOOT_NOT_REQUIRED_DOC" "FASTBOOT_REQUIRED=NO" "$AUDIT_DOC"
require_pattern "N1B2_CELLULAR_FASTBOOTD_NOT_REQUIRED_DOC" "FASTBOOTD_REQUIRED=NO" "$AUDIT_DOC"
require_pattern "N1B2_CELLULAR_RUNTIME_ANDROID_MODE_SCRIPT" "ANDROID_MODE_REQUIRED=YES" "$RUNTIME_SCRIPT"
require_pattern "N1B2_CELLULAR_RUNTIME_FASTBOOT_NO_SCRIPT" "FASTBOOT_USED=NO" "$RUNTIME_SCRIPT"
require_pattern "N1B2_CELLULAR_RUNTIME_FASTBOOTD_NO_SCRIPT" "FASTBOOTD_USED=NO" "$RUNTIME_SCRIPT"
require_pattern "N1B2_CELLULAR_STATIC_FASTBOOT_NO_SCRIPT" "FASTBOOT_USED=NO" "$STATIC_SCRIPT"
require_pattern "N1B2_CELLULAR_STATIC_FASTBOOTD_NO_SCRIPT" "FASTBOOTD_USED=NO" "$STATIC_SCRIPT"
require_pattern "N1B2_CELLULAR_STATIC_SINGLE_PASS" "SINGLE_PASS_ROOT_INDEX=YES" "$STATIC_SCRIPT"
require_pattern "N1B2_CELLULAR_STATIC_FIND_TIMEOUT" "FIND_TIMEOUT_SECONDS" "$STATIC_SCRIPT"
require_pattern "N1B2_CELLULAR_RUNTIME_COMMAND_TIMEOUT" "COMMAND_TIMEOUT" "$RUNTIME_SCRIPT"

for marker in \
  STOCK_ROOT \
  N1B1_ROOT \
  N1B2_ROOT \
  RESTLESS_ROOT \
  AOSP_ROOT \
  TeleService \
  TelephonyProvider \
  CarrierConfig \
  CellBroadcast \
  Euicc \
  IMS \
  MmsService \
  priv-app permissions \
  VINTF; do
  require_pattern "N1B2_CELLULAR_AUDIT_DOC_MARKER_${marker//[^A-Za-z0-9]/_}" "$marker" "$AUDIT_DOC"
done

for command_marker in \
  'dumpsys telephony.registry' \
  'dumpsys phone' \
  'dumpsys isub' \
  'dumpsys carrier_config' \
  'dumpsys connectivity' \
  'logcat -b radio'; do
  require_pattern "N1B2_CELLULAR_RUNTIME_COMMAND_${command_marker//[^A-Za-z0-9]/_}" "$command_marker" "$RUNTIME_SCRIPT"
done

for class_marker in \
  'product package selection' \
  'privileged permission missing' \
  'framework overlay/config' \
  'CarrierConfig/APN' \
  'IMS/radio/vendor service' \
  'radio HAL / VINTF mismatch' \
  'SELinux denial' \
  'SIM state / carrier provisioning' \
  'Settings or Network Manager policy' \
  'Treble/AOSP composition gap' \
  'stock vendor dependency gap'; do
  require_pattern "N1B2_CELLULAR_ROOT_CAUSE_CLASS_${class_marker//[^A-Za-z0-9]/_}" "$class_marker" "$ROOT_CAUSE_DOC"
done

# Block accidental implementation in this audit PR. The gate itself contains the
# forbidden regex literals, so only evidence scripts/docs are scanned here.
mutation_scan_targets=("$STATIC_SCRIPT" "$RUNTIME_SCRIPT" "$AUDIT_DOC" "$ROOT_CAUSE_DOC")
pass "N1B2_CELLULAR_GATE_SELF_FORBIDDEN_LITERAL_EXEMPT" "reason=gate_contains_regex_literals"

for path in "${mutation_scan_targets[@]}"; do
  require_absent_pattern "N1B2_CELLULAR_NO_FASTBOOT_FLASH_${path//[^A-Za-z0-9]/_}" '(^|[;&|[:space:]])fastboot[[:space:]]+(flash|erase|format|reboot|boot|update|set_active)([[:space:]]|$)' "$path"
  require_absent_pattern "N1B2_CELLULAR_NO_ADB_REBOOT_${path//[^A-Za-z0-9]/_}" '(^|[;&|[:space:]])adb([[:space:]-][^\n]*)?[[:space:]]reboot([[:space:]]|$)' "$path"
  require_absent_pattern "N1B2_CELLULAR_NO_ADB_ROOT_${path//[^A-Za-z0-9]/_}" '(^|[;&|[:space:]])adb([[:space:]-][^\n]*)?[[:space:]]root([[:space:]]|$)' "$path"
  require_absent_pattern "N1B2_CELLULAR_NO_ADB_REMOUNT_${path//[^A-Za-z0-9]/_}" '(^|[;&|[:space:]])adb([[:space:]-][^\n]*)?[[:space:]]remount([[:space:]]|$)' "$path"
  require_absent_pattern "N1B2_CELLULAR_NO_ADB_INSTALL_${path//[^A-Za-z0-9]/_}" '(^|[;&|[:space:]])adb([[:space:]-][^\n]*)?[[:space:]]install([[:space:]]|$)' "$path"
  require_absent_pattern "N1B2_CELLULAR_NO_SETTINGS_PUT_${path//[^A-Za-z0-9]/_}" '(^|[;&|[:space:]])settings[[:space:]]+put([[:space:]]|$)' "$path"
  require_absent_pattern "N1B2_CELLULAR_NO_SVC_DATA_${path//[^A-Za-z0-9]/_}" '(^|[;&|[:space:]])svc[[:space:]]+data([[:space:]]|$)' "$path"
  require_absent_pattern "N1B2_CELLULAR_NO_SVC_WIFI_${path//[^A-Za-z0-9]/_}" '(^|[;&|[:space:]])svc[[:space:]]+wifi([[:space:]]|$)' "$path"
  require_absent_pattern "N1B2_CELLULAR_NO_SETENFORCE_${path//[^A-Za-z0-9]/_}" '(^|[;&|[:space:]])setenforce([[:space:]]|$)' "$path"
  require_absent_pattern "N1B2_CELLULAR_NO_IMAGE_TOOLS_${path//[^A-Za-z0-9]/_}" '(^|[;&|[:space:]])(mkbootimg|avbtool|lpmake)([[:space:]]|$)' "$path"
done

if [[ "$RUN_STATIC_SMOKE" == "YES" ]]; then
  smoke_dir="/tmp/SABLE_N1B2_CELLULAR_STATIC_SMOKE_$(date -u +%Y%m%dT%H%M%SZ)"
  bash "$STATIC_SCRIPT" --evidence-dir "$smoke_dir" >/tmp/n1b2-cellular-static-smoke.log 2>&1 \
    && pass "N1B2_CELLULAR_STATIC_SMOKE" "evidence_dir=$smoke_dir" \
    || fail "N1B2_CELLULAR_STATIC_SMOKE" "log=/tmp/n1b2-cellular-static-smoke.log"
else
  warn "N1B2_CELLULAR_STATIC_SMOKE" "skipped use --static-smoke=YES"
fi

# Guard PR 207 scope when origin/main is available.
if git -C "$ROOT" rev-parse --verify origin/main >/dev/null 2>&1; then
  changed=$(git -C "$ROOT" diff --name-only origin/main...HEAD || true)
  if [[ -n "$changed" ]]; then
    forbidden=$(printf '%s\n' "$changed" | grep -Ev '^(build/titan2/audit-n1b2-cellular-stack.sh|build/titan2/capture-n1b2-cellular-runtime.sh|build/gates/n1b2-cellular-stack-audit-contract.sh|docs/titan2/N1B2_CELLULAR_STACK_AUDIT.md|docs/titan2/N1B2_CELLULAR_ROOT_CAUSE.md)$' || true)
    if [[ -z "$forbidden" ]]; then
      pass "N1B2_CELLULAR_PR207_SCOPE_ONLY" "changed_files=$(printf '%s' "$changed" | wc -l | tr -d ' ')"
    else
      fail "N1B2_CELLULAR_PR207_SCOPE_ONLY" "forbidden_files=$(printf '%s' "$forbidden" | paste -sd ',' -)"
    fi
  else
    warn "N1B2_CELLULAR_PR207_SCOPE_ONLY" "no_diff_against_origin_main"
  fi
else
  warn "N1B2_CELLULAR_PR207_SCOPE_ONLY" "origin_main_not_available"
fi

echo "N1B2_CELLULAR_STACK_AUDIT_PASSES=$passes"
echo "N1B2_CELLULAR_STACK_AUDIT_WARNINGS=$warnings"
echo "N1B2_CELLULAR_STACK_AUDIT_FAILURES=$failures"

if [[ "$failures" -eq 0 ]]; then
  echo "N1B2_CELLULAR_STACK_AUDIT_CONTRACT=PASS"
else
  echo "N1B2_CELLULAR_STACK_AUDIT_CONTRACT=FAIL"
  exit 1
fi
