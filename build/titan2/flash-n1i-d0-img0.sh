#!/usr/bin/env bash
# Governed Titan 2 N1I-D0 IMG0 exact system_a deployment.
# One exact sealed IMG0 image, one write attempt, no automatic retry.
set -u
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/build/config/storage.env" || exit 64
source "$ROOT/build/config/host-tools.env" || exit 64
source "$ROOT/build/titan2/titan2-flash-mode.sh" || exit 64

BUILD_SOURCE="defc7f9c522336732564eb11644331691dcd92a2"
SYSTEM_SHA256="c3cff8cc9f0be512a721fae4c0b3c148688ef95b04c1df3981afb406bc928bd0"
SYSTEM_BYTES="3200548864"
ARTIFACT_ROLE="N1I_D0_IMG0_BUILD_PATH_CLOSURE"
TARGET_PARTITION="system_a"
EXPECTED_SLOT="a"
EXPECTED_ADB_BINDING_SHA256="bcfdee61b23e3cb002919c27a055389ffe37e284bf5150dfc1d0bbbd7564090a"
EXPECTED_FASTBOOT_BINDING_SHA256="bcfdee61b23e3cb002919c27a055389ffe37e284bf5150dfc1d0bbbd7564090a"
EXPECTED_ANDROID_PRODUCT="Titan_2"
EXPECTED_BOOTLOADER_PRODUCT="g71v78c2k_dfl_tee"
EXPECTED_FASTBOOTD_PRODUCT="Titan_2"
FASTBOOT_QUAL="$ROOT/build/titan2/qualify-n1i-d0-img0-fastboot-state.py"

ACTION="${1:-}"
if [[ "$#" -gt 0 ]]; then shift; fi

AUTH_CONTACT=""
AUTH_FLASH=""
ARTIFACT_DIR=""
POSTBOOT_TIMEOUT=240

SERIAL=""
SERIAL_SHA256=""
SYSTEM_IMG=""
TOOL_SOURCE_COMMIT=""
EVIDENCE_DIR=""
ATTEMPT_JOURNAL=""
COMMAND_JOURNAL=""
WRITE_PROOF=""

fail() {
  echo "N1I_D0_IMG0_GOVERNED_FLASH=FAIL reason=$1" >&2
  exit "${2:-1}"
}

env_value() {
  local file="$1" key="$2" out count
  out="$(sed -n "s/^${key}=//p" "$file")"
  count="$(printf '%s\n' "$out" | sed '/^$/d' | wc -l | tr -d ' ')"
  [[ "$count" == 1 ]] || return 1
  printf '%s\n' "$out"
}

manifest_safe() {
  local file="$1" line path
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[0-9a-f]{64}[[:space:]][[:space:]][^[:space:]]+$ ]] || return 1
    path="${line#*  }"
    [[ "$path" != /* && "$path" != ".." && "$path" != ../* && "$path" != *"/../"* ]] ||
      return 1
  done < "$file"
}

usage() {
  cat <<'EOF'
Usage:
  bash build/titan2/flash-n1i-d0-img0.sh flash \
    --authorize-device-contact YES_D0_IMG0_MODE_AWARE_FASTBOOTD_AND_FLASH_SYSTEM_A_ONCE \
    --authorize-flash YES_D0_IMG0_SYSTEM_A_ONCE \
    --artifact-dir <sealed D0 IMG0 artifact directory>
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --authorize-device-contact)
      [[ "$#" -ge 2 ]] || fail missing_device_contact_authorization 64
      AUTH_CONTACT="$2"; shift 2 ;;
    --authorize-flash)
      [[ "$#" -ge 2 ]] || fail missing_flash_authorization 64
      AUTH_FLASH="$2"; shift 2 ;;
    --artifact-dir)
      [[ "$#" -ge 2 ]] || fail missing_artifact_dir 64
      ARTIFACT_DIR="$2"; shift 2 ;;
    --postboot-timeout)
      [[ "$#" -ge 2 ]] || fail missing_postboot_timeout 64
      POSTBOOT_TIMEOUT="$2"; shift 2 ;;
    -h|--help)
      usage
      exit 0 ;;
    *)
      fail "unknown_argument=$1" 64 ;;
  esac
done

[[ "$ACTION" == flash ]] || {
  usage >&2
  fail invalid_action 64
}
[[ "$AUTH_CONTACT" == YES_D0_IMG0_MODE_AWARE_FASTBOOTD_AND_FLASH_SYSTEM_A_ONCE ]] ||
  fail device_contact_authorization_required 64
[[ "$AUTH_FLASH" == YES_D0_IMG0_SYSTEM_A_ONCE ]] ||
  fail flash_authorization_required 64
[[ "$POSTBOOT_TIMEOUT" =~ ^[1-9][0-9]*$ ]] ||
  fail invalid_postboot_timeout 64
[[ -d "$ARTIFACT_DIR" ]] || fail artifact_dir_missing 64
[[ -f "$FASTBOOT_QUAL" ]] || fail fastboot_qualifier_missing 64
[[ -x "$SABLE_ADB" ]] || fail "adb_missing=$SABLE_ADB" 64
[[ -x "$SABLE_FASTBOOT" ]] || fail "fastboot_missing=$SABLE_FASTBOOT" 64

for tool in git grep sed awk wc tr sha256sum stat tee date find sort xargs \
  bash python3 cut head cat cp chmod mkdir sleep
do
  command -v "$tool" >/dev/null 2>&1 ||
    fail "required_tool_missing=$tool" 64
done

ARTIFACT_DIR="$(cd "$ARTIFACT_DIR" && pwd -P)" ||
  fail artifact_dir_resolve 64

ARTIFACT_ENV="$ARTIFACT_DIR/artifact.env"
ARTIFACT_SUMS="$ARTIFACT_DIR/SHA256SUMS.txt"
SYSTEM_IMG="$ARTIFACT_DIR/system.img"
APP_MANIFEST="$ARTIFACT_DIR/app-manifest.tsv"
D0_MARKER="$ARTIFACT_DIR/n1i-d0-image"

for path in \
  "$ARTIFACT_ENV" "$ARTIFACT_SUMS" "$SYSTEM_IMG" "$APP_MANIFEST" "$D0_MARKER"
do
  [[ -f "$path" ]] || fail "required_file_missing=$path" 64
done

D0_CONTRACT="$ROOT/build/gates/n1i-d0-img0-flash-executor-contract.sh"
FLASH_REGRESSION_CONTRACT="$ROOT/build/gates/titan2-flash-regression-contract.py"
[[ -f "$D0_CONTRACT" ]] || fail d0_flash_contract_missing 64
[[ -f "$FLASH_REGRESSION_CONTRACT" ]] || fail flash_regression_contract_missing 64

TOOL_SOURCE_COMMIT="$(git -C "$ROOT" rev-parse HEAD)" ||
  fail tooling_source_head_unavailable 64
TOOL_STATUS="$(git -C "$ROOT" status --porcelain=v1 --untracked-files=all)" ||
  fail tooling_source_status_unavailable 64
[[ -z "$TOOL_STATUS" ]] || fail tooling_repo_dirty 65

FASTBOOT_VERSION="$(
  "$SABLE_FASTBOOT" --version 2>/dev/null |
    awk '/^fastboot version / {print $3; exit}' |
    cut -d- -f1
)"
[[ -n "$FASTBOOT_VERSION" ]] || fail fastboot_version_unreadable 65
[[ "$(
  printf '%s\n' 35.0.1 "$FASTBOOT_VERSION" |
    sort -V |
    head -n1
)" == 35.0.1 ]] || fail "fastboot_version_too_old=$FASTBOOT_VERSION" 65
echo "FASTBOOT_VERSION=$FASTBOOT_VERSION"
echo "FASTBOOT_MIN_VERSION=35.0.1"

# ----------------------------- HOST-ONLY AUTHORITY -----------------------------

manifest_safe "$ARTIFACT_SUMS" || fail artifact_manifest_unsafe 65
SYSTEM_MANIFEST_COUNT="$(
  awk '$2 == "./system.img" || $2 == "system.img" {count++} END {print count+0}' \
    "$ARTIFACT_SUMS"
)"
[[ "$SYSTEM_MANIFEST_COUNT" == 1 ]] ||
  fail "artifact_system_manifest_count=$SYSTEM_MANIFEST_COUNT" 65
SYSTEM_MANIFEST_SHA="$(
  awk '$2 == "./system.img" || $2 == "system.img" {print $1}' "$ARTIFACT_SUMS"
)"
[[ "$SYSTEM_MANIFEST_SHA" == "$SYSTEM_SHA256" ]] ||
  fail artifact_system_manifest_sha_mismatch 65

# Verify all sealed metadata now, but hash the multi-GB system image exactly
# once at the immediate prewrite boundary below.
(
  cd "$ARTIFACT_DIR" || exit 1
  awk '$2 != "./system.img" && $2 != "system.img" {print}' SHA256SUMS.txt |
    sha256sum -c - >/dev/null
) || fail artifact_metadata_seal_invalid 65

for expected in \
  "ROLE=$ARTIFACT_ROLE" \
  "SOURCE_COMMIT=$BUILD_SOURCE" \
  'BASELINE_N1F_SHA256=dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a' \
  'BASELINE_N1F_BYTES=3200540672' \
  'CELLULAR_DELTA=C1_C2_NOT_INCLUDED' \
  'SABLE_MODULE_COUNT=5' \
  'D0_MARKER_MODULE=SableTitan2N1ID0Marker' \
  "SYSTEM_SHA256=$SYSTEM_SHA256" \
  "SYSTEM_BYTES=$SYSTEM_BYTES" \
  'TARGET_PARTITION=system_a' \
  'DEVICE_CONTACT_AUTHORIZED=NO' \
  'FLASH_AUTHORIZED=NO'
do
  grep -Fxq -- "$expected" "$ARTIFACT_ENV" ||
    fail "artifact_authority_missing=$expected" 65
done

APP_ROW_COUNT="$(tail -n +2 "$APP_MANIFEST" | grep -cve '^$' || true)"
[[ "$APP_ROW_COUNT" == 5 ]] ||
  fail "artifact_app_manifest_count=$APP_ROW_COUNT" 65
for module in \
  SableTitan2Keyboard \
  SableTitan2Camera \
  SableTitan2DisplayCompat \
  SableTitan2Setup \
  SableTitan2RadioDiag
do
  awk -F '\t' -v module="$module" '
    NR > 1 && $1 == module && $7 == "UNSIGNED" { count++ }
    END { exit !(count == 1) }
  ' "$APP_MANIFEST" ||
    fail "artifact_app_manifest_module=$module" 65
done

[[ "$(grep -cve '^$' "$D0_MARKER")" == 5 ]] ||
  fail d0_marker_line_count 65
for expected in \
  'ROLE=N1I_D0_IMG0_BUILD_PATH_CLOSURE' \
  'BASELINE=N1F_BOOT_QUALIFIED' \
  'CELLULAR_DELTA=C1_C2_NOT_INCLUDED' \
  'DEVICE_CONTACT_AUTHORIZED=NO' \
  'FLASH_AUTHORIZED=NO'
do
  grep -Fxq -- "$expected" "$D0_MARKER" ||
    fail "d0_marker_missing=$expected" 65
done

actual_bytes="$(stat -c '%s' "$SYSTEM_IMG")" ||
  fail artifact_size_read_failed 65
[[ "$actual_bytes" == "$SYSTEM_BYTES" ]] ||
  fail "artifact_size_mismatch=expected:$SYSTEM_BYTES:actual:$actual_bytes" 65

python3 "$FASTBOOT_QUAL" --selftest >/dev/null ||
  fail fastboot_qualifier_selftest 65
bash "$ROOT/build/titan2/tests/test-titan2-flash-mode.sh" >/dev/null ||
  fail titan2_mode_selftest 65
bash "$D0_CONTRACT" >/dev/null ||
  fail d0_flash_executor_contract 65
python3 "$FLASH_REGRESSION_CONTRACT" >/dev/null ||
  fail titan2_flash_regression_contract 65

echo "N1I_D0_IMG0_FLASH_HOST_AUTHORITY=PASS"
echo "N1I_D0_IMG0_FLASH_REGRESSION_PREFLIGHT=PASS"

# ----------------------------- DEVICE CONTACT BOUNDARY -----------------------------

ADB_BOUND=NO
FASTBOOT_BOUND=NO

titan2_mode_find_bound_adb "$SABLE_ADB" "$EXPECTED_ADB_BINDING_SHA256"
ADB_BIND_RC=$?
case "$ADB_BIND_RC" in
  0) ADB_BOUND=YES ;;
  1) ;;
  3) fail ambiguous_adb_binding 70 ;;
  *) fail "adb_binding_discovery_rc=$ADB_BIND_RC" 70 ;;
esac

titan2_mode_find_bound_fastboot "$SABLE_FASTBOOT" "$EXPECTED_FASTBOOT_BINDING_SHA256"
FASTBOOT_BIND_RC=$?
case "$FASTBOOT_BIND_RC" in
  0) FASTBOOT_BOUND=YES ;;
  1) ;;
  3) fail ambiguous_fastboot_binding 70 ;;
  *) fail "fastboot_binding_discovery_rc=$FASTBOOT_BIND_RC" 70 ;;
esac

if [[ "$ADB_BOUND" == YES && "$FASTBOOT_BOUND" == YES ]]; then
  fail simultaneous_adb_fastboot_binding 70
fi
if [[ "$ADB_BOUND" == NO && "$FASTBOOT_BOUND" == NO ]]; then
  fail sealed_device_binding_not_found 70
fi

if [[ "$ADB_BOUND" == YES ]]; then
  SERIAL="$TITAN2_MODE_ADB_SERIAL"
  EXPECTED_ENTRY_BINDING_SHA256="$EXPECTED_ADB_BINDING_SHA256"
else
  SERIAL="$TITAN2_MODE_FASTBOOT_SERIAL"
  EXPECTED_ENTRY_BINDING_SHA256="$EXPECTED_FASTBOOT_BINDING_SHA256"
fi
[[ -n "$SERIAL" ]] || fail bound_serial_missing 70

SERIAL_SHA256="$(titan2_mode_hash_serial "$SERIAL")" ||
  fail serial_hash_failed 70
[[ "$SERIAL_SHA256" == "$EXPECTED_ENTRY_BINDING_SHA256" ]] ||
  fail serial_binding_changed 70

titan2_detect_device_mode \
  "$SABLE_ADB" "$SABLE_FASTBOOT" "$SERIAL" \
  "$EXPECTED_ADB_BINDING_SHA256" "$EXPECTED_FASTBOOT_BINDING_SHA256" \
  "$EXPECTED_ANDROID_PRODUCT" "$EXPECTED_BOOTLOADER_PRODUCT" "$EXPECTED_FASTBOOTD_PRODUCT"
MODE_RC=$?
[[ "$MODE_RC" -eq 0 ]] ||
  fail "initial_mode_discovery_rc=$MODE_RC mode=$TITAN2_MODE_DETECTED" 70

case "$TITAN2_MODE_DETECTED" in
  ANDROID_ADB)
    boot_completed="$(titan2_mode_adb_getprop "$SABLE_ADB" "$SERIAL" sys.boot_completed || true)"
    android_product="$(titan2_mode_adb_getprop "$SABLE_ADB" "$SERIAL" ro.product.device || true)"
    android_slot="$(titan2_mode_adb_getprop "$SABLE_ADB" "$SERIAL" ro.boot.slot_suffix || true)"
    [[ "$boot_completed" == 1 ]] || fail "android_boot_completed=$boot_completed" 70
    [[ "$android_product" == "$EXPECTED_ANDROID_PRODUCT" ]] ||
      fail "android_product=$android_product" 70
    [[ "$android_slot" == _a ]] || fail "android_slot=$android_slot" 70
    echo "N1I_D0_IMG0_FLASH_ENTRY_MODE=PASS_ANDROID_ADB"
    ;;
  BOOTLOADER_FASTBOOT)
    echo "N1I_D0_IMG0_FLASH_ENTRY_MODE=PASS_BOOTLOADER_FASTBOOT"
    ;;
  FASTBOOTD)
    echo "N1I_D0_IMG0_FLASH_ENTRY_MODE=PASS_FASTBOOTD_DIRECT"
    ;;
  RECOVERY_ADB)
    fail recovery_entry_blocked_for_write 78
    ;;
  *)
    fail "unsupported_entry_mode=$TITAN2_MODE_DETECTED" 78
    ;;
esac

INITIAL_MODE="$TITAN2_MODE_DETECTED"
echo "N1I_D0_IMG0_FLASH_INITIAL_MODE=$INITIAL_MODE"
echo "N1I_D0_IMG0_FLASH_DEVICE_BINDING=PASS"

# Refuse any prior C2 armed/succeeded attempt for this exact device+image.
# Corrupt matching evidence is also a hard stop; absence of a valid seal is
# never interpreted as permission to write again.
EVIDENCE_ROOT="$SABLE_EVIDENCE_ROOT/titan2/n1i-d0-img0-governed-flash"
if [[ -d "$EVIDENCE_ROOT" ]]; then
  while IFS= read -r prior; do
    [[ -f "$prior" ]] || continue
    prior_dir="$(dirname "$prior")"
    prior_sums="$prior_dir/SHA256SUMS.txt"
    [[ -f "$prior_sums" ]] || {
      echo "N1I_D0_IMG0_FLASH_DUPLICATE_WRITE_GUARD=REFUSE_CORRUPT_PRIOR_EVIDENCE"
      echo "N1I_D0_IMG0_DO_NOT_REFLASH=YES"
      fail "prior_attempt_seal_missing=$prior_dir" 21
    }
    manifest_safe "$prior_sums" || {
      echo "N1I_D0_IMG0_FLASH_DUPLICATE_WRITE_GUARD=REFUSE_CORRUPT_PRIOR_EVIDENCE"
      echo "N1I_D0_IMG0_DO_NOT_REFLASH=YES"
      fail "prior_attempt_manifest_unsafe=$prior_dir" 21
    }
    (
      cd "$prior_dir" || exit 1
      sha256sum -c SHA256SUMS.txt >/dev/null
    ) || {
      echo "N1I_D0_IMG0_FLASH_DUPLICATE_WRITE_GUARD=REFUSE_CORRUPT_PRIOR_EVIDENCE"
      echo "N1I_D0_IMG0_DO_NOT_REFLASH=YES"
      fail "prior_attempt_seal_invalid=$prior_dir" 21
    }

    prior_serial="$(env_value "$prior" DEVICE_SERIAL_SHA256 2>/dev/null || true)"
    prior_source="$(env_value "$prior" BUILD_SOURCE_COMMIT 2>/dev/null || true)"
    prior_sha="$(env_value "$prior" SYSTEM_SHA256 2>/dev/null || true)"
    prior_target="$(env_value "$prior" TARGET_PARTITION 2>/dev/null || true)"
    [[ -n "$prior_serial" && -n "$prior_source" &&
       -n "$prior_sha" && -n "$prior_target" ]] || {
      echo "N1I_D0_IMG0_FLASH_DUPLICATE_WRITE_GUARD=REFUSE_CORRUPT_PRIOR_EVIDENCE"
      echo "N1I_D0_IMG0_DO_NOT_REFLASH=YES"
      fail "prior_attempt_identity_missing=$prior" 21
    }

    if [[ "$prior_serial" == "$SERIAL_SHA256" &&
          "$prior_source" == "$BUILD_SOURCE" &&
          "$prior_sha" == "$SYSTEM_SHA256" &&
          "$prior_target" == "$TARGET_PARTITION" ]]; then
      echo "N1I_D0_IMG0_FLASH_DUPLICATE_WRITE_GUARD=REFUSE_PRIOR_ATTEMPT"
      echo "N1I_D0_IMG0_DO_NOT_REFLASH=YES"
      fail prior_attempt_exists 19
    fi
  done < <(
    find "$EVIDENCE_ROOT" -type f \
      \( -name N1I_D0_IMG0_FLASH_ATTEMPT_ARMED.env -o -name N1I_D0_IMG0_FLASH_COMMAND_SUCCEEDED.env \) \
      -print 2>/dev/null | LC_ALL=C sort
  )
fi
echo "N1I_D0_IMG0_FLASH_DUPLICATE_WRITE_GUARD=PASS_NO_PRIOR_ATTEMPT"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="$EVIDENCE_ROOT/${STAMP}-${SYSTEM_SHA256:0:12}"
ATTEMPT_JOURNAL="$EVIDENCE_DIR/attempt-journal"
COMMAND_JOURNAL="$EVIDENCE_DIR/command-journal"
WRITE_PROOF="$EVIDENCE_DIR/write-proof"
mkdir -p "$ATTEMPT_JOURNAL" "$COMMAND_JOURNAL" "$WRITE_PROOF" ||
  fail evidence_dir_create 71
chmod 700 "$EVIDENCE_DIR" "$ATTEMPT_JOURNAL" "$COMMAND_JOURNAL" "$WRITE_PROOF" 2>/dev/null || true
echo "N1I_D0_IMG0_FLASH_EVIDENCE_DIR=$EVIDENCE_DIR"

titan2_ensure_fastbootd_mode \
  "$SABLE_ADB" "$SABLE_FASTBOOT" "$SERIAL" \
  "$EXPECTED_ADB_BINDING_SHA256" "$EXPECTED_FASTBOOT_BINDING_SHA256" \
  "$EXPECTED_ANDROID_PRODUCT" "$EXPECTED_BOOTLOADER_PRODUCT" "$EXPECTED_FASTBOOTD_PRODUCT" \
  "$EVIDENCE_DIR"
TRANSITION_RC=$?
[[ "$TRANSITION_RC" -eq 0 ]] ||
  fail "fastbootd_transition_rc=$TRANSITION_RC mode=${TITAN2_MODE_DETECTED:-UNKNOWN}" 71
[[ "$TITAN2_MODE_FINAL" == FASTBOOTD ]] ||
  fail "fastbootd_final_mode=$TITAN2_MODE_FINAL" 71
SERIAL="$TITAN2_MODE_FASTBOOT_SERIAL"
[[ -n "$SERIAL" ]] || fail fastboot_serial_missing 71
[[ "$(titan2_mode_hash_serial "$SERIAL")" == "$EXPECTED_FASTBOOT_BINDING_SHA256" ]] ||
  fail fastboot_binding_changed 71

if [[ "$INITIAL_MODE" == FASTBOOTD ]]; then
  [[ "$TITAN2_MODE_TRANSITION_COUNT" -eq 0 ]] ||
    fail "unexpected_fastbootd_transition_count=$TITAN2_MODE_TRANSITION_COUNT" 71
  echo "N1I_D0_IMG0_FLASH_MODE_TRANSITION=NONE_ALREADY_FASTBOOTD"
else
  [[ "$TITAN2_MODE_TRANSITION_COUNT" -ge 1 ]] ||
    fail "expected_mode_transition_missing initial=$INITIAL_MODE" 71
  echo "N1I_D0_IMG0_FLASH_MODE_TRANSITION=PASS_TO_FASTBOOTD count=$TITAN2_MODE_TRANSITION_COUNT"
fi

echo "===== N1I-D0 IMG0 FASTBOOTD PREWRITE STATE ====="
"$SABLE_FASTBOOT" -s "$SERIAL" getvar all </dev/null \
  > "$WRITE_PROOF/fastboot-getvar-all-pre.txt" 2>&1
GETVAR_PRE_RC=$?
[[ "$GETVAR_PRE_RC" -eq 0 ]] ||
  fail "pre_getvar_all_rc=$GETVAR_PRE_RC" 72

python3 "$FASTBOOT_QUAL" \
  --getvar-all "$WRITE_PROOF/fastboot-getvar-all-pre.txt" \
  --phase pre \
  --out-env "$WRITE_PROOF/pre-state.env"
PRE_RC=$?
[[ "$PRE_RC" -eq 0 ]] ||
  fail "fastboot_preflight_rc=$PRE_RC" 72

# shellcheck source=/dev/null
source "$WRITE_PROOF/pre-state.env" || fail pre_state_source 72

echo "N1I_D0_IMG0_PREFLASH_SYSTEM_A_BYTES=$N1I_D0_IMG0_FASTBOOT_SYSTEM_A_BYTES"
echo "N1I_D0_IMG0_PREFLASH_PROJECTED_REMAINING_SUPER_BYTES=$N1I_D0_IMG0_FASTBOOT_PROJECTED_REMAINING_SUPER_BYTES"
echo "N1I_D0_IMG0_PREFLASH_ACTIVE_COW_COUNT=$N1I_D0_IMG0_FASTBOOT_ACTIVE_COW_COUNT"
echo "N1I_D0_IMG0_PREFLASH=PASS"

# Fresh artifact hash immediately before arming the write.
PREWRITE_SHA256="$(sha256sum "$SYSTEM_IMG" | awk '{print $1}')"
[[ "$PREWRITE_SHA256" == "$SYSTEM_SHA256" ]] ||
  fail "prewrite_image_sha_mismatch=expected:$SYSTEM_SHA256:actual:$PREWRITE_SHA256" 72
PREWRITE_BYTES="$(stat -c '%s' "$SYSTEM_IMG")" ||
  fail prewrite_image_size_read_failed 72
[[ "$PREWRITE_BYTES" == "$SYSTEM_BYTES" ]] ||
  fail "prewrite_image_bytes_mismatch=expected:$SYSTEM_BYTES:actual:$PREWRITE_BYTES" 72

echo "N1I_D0_IMG0_PREWRITE_ARTIFACT_HASH=PASS sha256=$PREWRITE_SHA256"
echo "N1I_D0_IMG0_PREWRITE_ARTIFACT_BYTES=PASS bytes=$PREWRITE_BYTES"

cat > "$EVIDENCE_DIR/policy.env" <<EOF_POLICY
BUILD_SOURCE_COMMIT=$BUILD_SOURCE
SYSTEM_SHA256=$SYSTEM_SHA256
SYSTEM_BYTES=$SYSTEM_BYTES
TARGET_PARTITION=$TARGET_PARTITION
DEVICE_SERIAL_SHA256=$SERIAL_SHA256
DEVICE_CONTACT_AUTHORIZED=YES
MODE_TRANSITION_AUTHORIZED=YES_IF_REQUIRED_ANDROID_OR_BOOTLOADER_TO_FASTBOOTD
FLASH_AUTHORIZED=YES_SYSTEM_A_ONCE
FLASH_ATTEMPT_LIMIT=1
AUTOMATIC_FLASH_RETRY=NO
FACTORY_RESET_AUTHORIZED=NO
USERDATA_ERASE_AUTHORIZED=NO
SLOT_CHANGE_AUTHORIZED=NO
AVB_MUTATION_AUTHORIZED=NO
BOOT_CHAIN_MUTATION_AUTHORIZED=NO
COW_DELETION_AUTHORIZED=NO
EOF_POLICY

cat > "$ATTEMPT_JOURNAL/N1I_D0_IMG0_FLASH_ATTEMPT_ARMED.env" <<EOF_ATTEMPT
N1I_D0_IMG0_FLASH_ATTEMPT_JOURNAL_VERSION=1
DEVICE_SERIAL_SHA256=$SERIAL_SHA256
ARTIFACT_ROLE=$ARTIFACT_ROLE
BUILD_SOURCE_COMMIT=$BUILD_SOURCE
SYSTEM_SHA256=$SYSTEM_SHA256
SYSTEM_BYTES=$SYSTEM_BYTES
TARGET_PARTITION=$TARGET_PARTITION
PREFLASH_SYSTEM_A_BYTES=$N1I_D0_IMG0_FASTBOOT_SYSTEM_A_BYTES
PROJECTED_REMAINING_SUPER_BYTES=$N1I_D0_IMG0_FASTBOOT_PROJECTED_REMAINING_SUPER_BYTES
FLASH_ATTEMPT_NUMBER=1
ATTEMPT_STATE=ARMED
TOOL_SOURCE_COMMIT=$TOOL_SOURCE_COMMIT
AUTOMATIC_FLASH_RETRY=NO
EOF_ATTEMPT
(
  cd "$ATTEMPT_JOURNAL" || exit 1
  sha256sum N1I_D0_IMG0_FLASH_ATTEMPT_ARMED.env > SHA256SUMS.txt
  sha256sum -c SHA256SUMS.txt >/dev/null
) || fail flash_attempt_journal_seal 73

echo "N1I_D0_IMG0_FLASH_ATTEMPT_JOURNAL=PASS"
echo "N1I_D0_IMG0_FLASH_ATTEMPT_ARMED=YES"
echo "N1I_D0_IMG0_DO_NOT_REFLASH_AFTER_THIS_POINT_WITHOUT_OWNER_REVIEW=YES"

echo "===== N1I-D0 IMG0 SINGLE SYSTEM_A WRITE ====="
"$SABLE_FASTBOOT" -s "$SERIAL" flash system_a "$SYSTEM_IMG" </dev/null \
  > "$WRITE_PROOF/fastboot-flash-system-a.log" 2>&1
FLASH_RC=$?
cat "$WRITE_PROOF/fastboot-flash-system-a.log"
echo "N1I_D0_IMG0_FASTBOOT_FLASH_SYSTEM_A_RC=$FLASH_RC"
if [[ "$FLASH_RC" -ne 0 ]]; then
  echo "N1I_D0_IMG0_FLASH_WRITE=FAIL_NO_AUTOMATIC_RETRY"
  echo "N1I_D0_IMG0_DO_NOT_REFLASH_WITHOUT_OWNER_REVIEW=YES"
  fail "system_a_flash_rc=$FLASH_RC" 73
fi

FLASH_LOG_SHA256="$(sha256sum "$WRITE_PROOF/fastboot-flash-system-a.log" | awk '{print $1}')"
cat > "$COMMAND_JOURNAL/N1I_D0_IMG0_FLASH_COMMAND_SUCCEEDED.env" <<EOF_COMMAND
N1I_D0_IMG0_FLASH_COMMAND_JOURNAL_VERSION=1
DEVICE_SERIAL_SHA256=$SERIAL_SHA256
ARTIFACT_ROLE=$ARTIFACT_ROLE
BUILD_SOURCE_COMMIT=$BUILD_SOURCE
SYSTEM_SHA256=$SYSTEM_SHA256
SYSTEM_BYTES=$SYSTEM_BYTES
TARGET_PARTITION=$TARGET_PARTITION
PREFLASH_SYSTEM_A_BYTES=$N1I_D0_IMG0_FASTBOOT_SYSTEM_A_BYTES
FLASH_ATTEMPT_COUNT=1
FASTBOOT_FLASH_RC=0
FLASH_COMMAND_RESULT=PASS
FLASH_LOG_SHA256=$FLASH_LOG_SHA256
TOOL_SOURCE_COMMIT=$TOOL_SOURCE_COMMIT
AUTOMATIC_FLASH_RETRY=NO
EOF_COMMAND
cp "$WRITE_PROOF/fastboot-flash-system-a.log" "$COMMAND_JOURNAL/" ||
  fail command_journal_copy 73
(
  cd "$COMMAND_JOURNAL" || exit 1
  sha256sum N1I_D0_IMG0_FLASH_COMMAND_SUCCEEDED.env fastboot-flash-system-a.log > SHA256SUMS.txt
  sha256sum -c SHA256SUMS.txt >/dev/null
) || fail flash_command_journal_seal 73

echo "N1I_D0_IMG0_FLASH_COMMAND_JOURNAL=PASS"
echo "N1I_D0_IMG0_FLASH_COMMAND_SUCCEEDED=YES"
echo "N1I_D0_IMG0_DO_NOT_REFLASH=YES"

echo "===== N1I-D0 IMG0 POSTWRITE FASTBOOTD STATE ====="
"$SABLE_FASTBOOT" -s "$SERIAL" getvar all </dev/null \
  > "$WRITE_PROOF/fastboot-getvar-all-post.txt" 2>&1
GETVAR_POST_RC=$?
[[ "$GETVAR_POST_RC" -eq 0 ]] || {
  echo "N1I_D0_IMG0_FLASH_WRITE_COMPLETED=YES"
  echo "N1I_D0_IMG0_DO_NOT_REFLASH=YES"
  fail "post_getvar_all_rc=$GETVAR_POST_RC" 74
}

python3 "$FASTBOOT_QUAL" \
  --getvar-all "$WRITE_PROOF/fastboot-getvar-all-post.txt" \
  --phase post \
  --out-env "$WRITE_PROOF/post-state.env"
POST_RC=$?
[[ "$POST_RC" -eq 0 ]] || {
  echo "N1I_D0_IMG0_FLASH_WRITE_COMPLETED=YES"
  echo "N1I_D0_IMG0_DO_NOT_REFLASH=YES"
  fail "fastboot_postflight_rc=$POST_RC" 74
}

cat > "$WRITE_PROOF/N1I_D0_IMG0_WRITE_COMPLETED.env" <<EOF_WRITE
N1I_D0_IMG0_WRITE_PROOF_VERSION=1
DEVICE_SERIAL_SHA256=$SERIAL_SHA256
ARTIFACT_ROLE=$ARTIFACT_ROLE
BUILD_SOURCE_COMMIT=$BUILD_SOURCE
SYSTEM_SHA256=$SYSTEM_SHA256
SYSTEM_BYTES=$SYSTEM_BYTES
TARGET_PARTITION=$TARGET_PARTITION
PREFLASH_SYSTEM_A_BYTES=$N1I_D0_IMG0_FASTBOOT_SYSTEM_A_BYTES
FLASH_ATTEMPT_COUNT=1
FLASH_RESULT=PASS
POSTFLASH_SYSTEM_A_BYTES=$SYSTEM_BYTES
POSTFLASH_MODE=FASTBOOTD
POSTFLASH_SLOT=$EXPECTED_SLOT
TOOL_SOURCE_COMMIT=$TOOL_SOURCE_COMMIT
EOF_WRITE
(
  cd "$WRITE_PROOF" || exit 1
  sha256sum \
    N1I_D0_IMG0_WRITE_COMPLETED.env \
    fastboot-flash-system-a.log \
    fastboot-getvar-all-pre.txt \
    fastboot-getvar-all-post.txt \
    pre-state.env \
    post-state.env \
    > SHA256SUMS.txt
  sha256sum -c SHA256SUMS.txt >/dev/null
) || fail write_proof_seal 74

echo "N1I_D0_IMG0_FLASH_WRITE_COMPLETED=YES"
echo "N1I_D0_IMG0_FLASH_ATTEMPT_COUNT=1"
echo "N1I_D0_IMG0_FLASH_WRITE_PROOF=PASS"
echo "N1I_D0_IMG0_DO_NOT_REFLASH_IF_POSTBOOT_OBSERVATION_FAILS=YES"

"$SABLE_FASTBOOT" -s "$SERIAL" reboot </dev/null
REBOOT_RC=$?
if [[ "$REBOOT_RC" -ne 0 ]]; then
  echo "N1I_D0_IMG0_POSTFLASH_REBOOT=FAIL rc=$REBOOT_RC"
  echo "N1I_D0_IMG0_FLASH_WRITE_COMPLETED=YES"
  echo "N1I_D0_IMG0_DO_NOT_REFLASH=YES"
  fail "postflash_reboot_rc=$REBOOT_RC" 75
fi
echo "N1I_D0_IMG0_POSTFLASH_REBOOT=PASS_SENT_ONCE"

start="$(date +%s)"
POSTBOOT_RESULT=TIMEOUT
while :; do
  adb_serial=""
  titan2_mode_find_bound_adb "$SABLE_ADB" "$EXPECTED_ADB_BINDING_SHA256"
  ADB_FIND_RC=$?
  if [[ "$ADB_FIND_RC" -eq 0 && -n "$TITAN2_MODE_ADB_SERIAL" ]]; then
    adb_serial="$TITAN2_MODE_ADB_SERIAL"
    if [[ "$TITAN2_MODE_ADB_TRANSPORT_STATE" == recovery ]]; then
      POSTBOOT_RESULT=RECOVERY
      break
    fi
    boot="$(titan2_mode_adb_getprop "$SABLE_ADB" "$adb_serial" sys.boot_completed || true)"
    if [[ "$boot" == 1 ]]; then
      post_product="$(titan2_mode_adb_getprop "$SABLE_ADB" "$adb_serial" ro.product.device || true)"
      post_slot="$(titan2_mode_adb_getprop "$SABLE_ADB" "$adb_serial" ro.boot.slot_suffix || true)"
      if [[ "$post_product" == "$EXPECTED_ANDROID_PRODUCT" &&
            "$post_slot" == _a ]]; then
        POSTBOOT_RESULT=ANDROID_BOOT_COMPLETED
      else
        POSTBOOT_RESULT=ANDROID_IDENTITY_MISMATCH
      fi
      break
    fi
  fi

  now="$(date +%s)"
  if (( now - start >= POSTBOOT_TIMEOUT )); then
    break
  fi
  sleep 2
done

{
  echo "POSTBOOT_RESULT=$POSTBOOT_RESULT"
  echo "DEVICE_SERIAL_SHA256=$EXPECTED_ADB_BINDING_SHA256"
  echo "BUILD_SOURCE_COMMIT=$BUILD_SOURCE"
  echo "SYSTEM_SHA256=$SYSTEM_SHA256"
  echo "SYSTEM_BYTES=$SYSTEM_BYTES"
  echo "TARGET_PARTITION=$TARGET_PARTITION"
  echo "FLASH_ATTEMPT_COUNT=1"
  echo "AUTOMATIC_FLASH_RETRY=NO"
  echo "POSTBOOT_EXPECTED_PRODUCT=$EXPECTED_ANDROID_PRODUCT"
  echo "POSTBOOT_EXPECTED_SLOT=_a"
} > "$EVIDENCE_DIR/postboot-observation.env"

(
  cd "$EVIDENCE_DIR" || exit 1
  find . -type f ! -name SHA256SUMS.txt -print0 |
    LC_ALL=C sort -z |
    xargs -0 sha256sum > SHA256SUMS.txt
  sha256sum -c SHA256SUMS.txt >/dev/null
) || fail evidence_seal 76

echo "N1I_D0_IMG0_POSTBOOT_OBSERVATION=$POSTBOOT_RESULT"
echo "N1I_D0_IMG0_AUTOMATIC_FLASH_RETRY=NO"
echo "N1I_D0_IMG0_FACTORY_RESET=NOT_PERFORMED_BY_FLASH_EXECUTOR"
echo "N1I_D0_IMG0_FLASH_EVIDENCE_SEAL=PASS"

case "$POSTBOOT_RESULT" in
  ANDROID_BOOT_COMPLETED)
    echo "N1I_D0_IMG0_GOVERNED_FLASH=PASS_SYSTEM_A_ONCE_ANDROID_BOOT_COMPLETED"
    ;;
  RECOVERY)
    echo "N1I_D0_IMG0_GOVERNED_FLASH=WRITE_PASS_POSTBOOT_RECOVERY_OWNER_REVIEW"
    echo "N1I_D0_IMG0_DO_NOT_REFLASH=YES"
    exit 76
    ;;
  ANDROID_IDENTITY_MISMATCH)
    echo "N1I_D0_IMG0_GOVERNED_FLASH=WRITE_PASS_POSTBOOT_IDENTITY_MISMATCH_OWNER_REVIEW"
    echo "N1I_D0_IMG0_DO_NOT_REFLASH=YES"
    exit 77
    ;;
  *)
    echo "N1I_D0_IMG0_GOVERNED_FLASH=WRITE_PASS_POSTBOOT_TIMEOUT_OWNER_REVIEW"
    echo "N1I_D0_IMG0_DO_NOT_REFLASH=YES"
    exit 76
    ;;
esac

echo "N1I_D0_IMG0_FLASH_EVIDENCE_DIR=$EVIDENCE_DIR"
