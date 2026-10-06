#!/usr/bin/env bash
# Read-only Titan 2 N1I-C2 recovery-entry qualification.
# Observes and seals current recovery state. It never transitions modes or writes.
set -u
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/build/config/storage.env" || exit 64
source "$ROOT/build/config/host-tools.env" || exit 64
source "$ROOT/build/titan2/titan2-flash-mode.sh" || exit 64

SERIAL=""
BIND_SEALED_RECOVERY=NO
BINDING_METHOD=""
BUILD_SOURCE=""
ARTIFACT_DIR=""
POSTBUILD_EVIDENCE=""
EXPECTED_SYSTEM_SHA=""
EXPECTED_SYSTEM_BYTES=""

EXPECTED_BINDING_SHA256="bcfdee61b23e3cb002919c27a055389ffe37e284bf5150dfc1d0bbbd7564090a"
EXPECTED_ANDROID_PRODUCT="Titan_2"
EXPECTED_BOOTLOADER_PRODUCT="g71v78c2k_dfl_tee"
EXPECTED_FASTBOOTD_PRODUCT="Titan_2"
EXPECTED_TARGET_PARTITION="system_a"
EXPECTED_SLOT="a"

fail() {
  echo "N1I_C2_RECOVERY_ENTRY_QUALIFICATION=FAIL reason=$1" >&2
  exit "${2:-1}"
}

usage() {
  cat <<'EOF'
Usage:
  bash build/titan2/qualify-n1i-c2-recovery-entry.sh \
    (--serial <exact-titan2-transport-serial> | --bind-sealed-recovery) \
    --source-commit <40-hex-build-source> \
    --artifact-dir <sealed-C2-artifact-dir> \
    --postbuild-evidence <sealed-C2-postbuild-evidence-dir> \
    --expected-system-sha <64-hex-system-sha256> \
    --expected-system-bytes <decimal-bytes>

Read-only device contact is performed through bounded adb/fastboot discovery.
No reboot, mode transition, flash, erase, format, slot change, LP mutation,
factory reset, build, source mutation, or network fetch is performed.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --serial)
      [[ "$#" -ge 2 ]] || fail missing_serial_value 64
      SERIAL="$2"; shift 2 ;;
    --bind-sealed-recovery)
      BIND_SEALED_RECOVERY=YES; shift ;;
    --source-commit)
      [[ "$#" -ge 2 ]] || fail missing_source_commit_value 64
      BUILD_SOURCE="$2"; shift 2 ;;
    --artifact-dir)
      [[ "$#" -ge 2 ]] || fail missing_artifact_dir_value 64
      ARTIFACT_DIR="$2"; shift 2 ;;
    --postbuild-evidence)
      [[ "$#" -ge 2 ]] || fail missing_postbuild_evidence_value 64
      POSTBUILD_EVIDENCE="$2"; shift 2 ;;
    --expected-system-sha)
      [[ "$#" -ge 2 ]] || fail missing_expected_system_sha_value 64
      EXPECTED_SYSTEM_SHA="$2"; shift 2 ;;
    --expected-system-bytes)
      [[ "$#" -ge 2 ]] || fail missing_expected_system_bytes_value 64
      EXPECTED_SYSTEM_BYTES="$2"; shift 2 ;;
    -h|--help)
      usage
      exit 0 ;;
    *)
      fail "unknown_argument=$1" 64 ;;
  esac
done

if [[ -n "$SERIAL" && "$BIND_SEALED_RECOVERY" == YES ]]; then
  fail serial_and_bound_recovery_are_mutually_exclusive 64
fi
if [[ -z "$SERIAL" && "$BIND_SEALED_RECOVERY" != YES ]]; then
  fail serial_or_bound_recovery_required 64
fi
[[ "$BUILD_SOURCE" =~ ^[0-9a-f]{40}$ ]] || fail invalid_source_commit 64
[[ "$EXPECTED_SYSTEM_SHA" =~ ^[0-9a-f]{64}$ ]] || fail invalid_expected_system_sha 64
[[ "$EXPECTED_SYSTEM_BYTES" =~ ^[0-9]+$ ]] || fail invalid_expected_system_bytes 64
[[ -d "$ARTIFACT_DIR" ]] || fail artifact_dir_missing 64
[[ -d "$POSTBUILD_EVIDENCE" ]] || fail postbuild_evidence_missing 64
[[ -x "$SABLE_ADB" ]] || fail "adb_missing=$SABLE_ADB" 64
[[ -x "$SABLE_FASTBOOT" ]] || fail "fastboot_missing=$SABLE_FASTBOOT" 64
for tool in git grep sha256sum stat tee awk sed tail date find sort xargs; do
  command -v "$tool" >/dev/null 2>&1 ||
    fail "required_tool_missing=$tool" 64
done

ARTIFACT_DIR="$(cd "$ARTIFACT_DIR" && pwd -P)" ||
  fail artifact_dir_resolve 64
POSTBUILD_EVIDENCE="$(cd "$POSTBUILD_EVIDENCE" && pwd -P)" ||
  fail postbuild_evidence_resolve 64

ARTIFACT_ENV="$ARTIFACT_DIR/artifact.env"
ARTIFACT_SUMS="$ARTIFACT_DIR/SHA256SUMS.txt"
SYSTEM_IMG="$ARTIFACT_DIR/system.img"
POSTBUILD_SUMMARY="$POSTBUILD_EVIDENCE/POSTBUILD_SUMMARY.env"
POSTBUILD_SUMS="$POSTBUILD_EVIDENCE/SHA256SUMS.txt"

for path in "$ARTIFACT_ENV" "$ARTIFACT_SUMS" "$SYSTEM_IMG" "$POSTBUILD_SUMMARY" "$POSTBUILD_SUMS"; do
  [[ -f "$path" ]] || fail "required_file_missing=$path" 64
done

CURRENT_TOOL_HEAD="$(git -C "$ROOT" rev-parse HEAD)" ||
  fail tool_source_head_unavailable 64
TOOL_STATUS="$(git -C "$ROOT" status --porcelain=v1 --untracked-files=all)" ||
  fail tool_source_status_unavailable 64
[[ -z "$TOOL_STATUS" ]] ||
  fail tool_source_worktree_not_clean 64

if [[ "$BIND_SEALED_RECOVERY" == YES ]]; then
  BINDING_METHOD=SEALED_HASH_MATCH_READ_ONLY_DISCOVERY
  requested_hash="$EXPECTED_BINDING_SHA256"
else
  BINDING_METHOD=EXPLICIT_SERIAL
  requested_hash="$(titan2_mode_hash_serial "$SERIAL")" ||
    fail requested_serial_hash_failed 64
  [[ "$requested_hash" == "$EXPECTED_BINDING_SHA256" ]] ||
    fail "serial_binding_mismatch=expected:$EXPECTED_BINDING_SHA256:actual:$requested_hash" 65
fi

for expected in \
  "BUILD_SOURCE_COMMIT=$BUILD_SOURCE" \
  "SYSTEM_SHA256=$EXPECTED_SYSTEM_SHA" \
  "SYSTEM_BYTES=$EXPECTED_SYSTEM_BYTES" \
  'C1_NATIVE_REUSE_COUNT=0' \
  'ANDROID_PLATFORM_PROVIDER_COUNT=5' \
  'NATIVE_IMPORT_COUNT=28' \
  'IMPLEMENTATION_RECEIPT_ROWS=41' \
  'APEX_JAVA_BOOT_RUNTIME_PARITY=PASS' \
  'AGENTPREMAIN_BROAD_RUNTIME_FAILURE_SUPPRESSION=NO' \
  'DEVICE_CONTACT=NONE' \
  'REBOOT=NONE' \
  'FLASH=NONE'
do
  grep -Fxq -- "$expected" "$POSTBUILD_SUMMARY" ||
    fail "postbuild_authority_missing=$expected" 65
done

grep -Eq '^RUNTIME_MEMBER_LINKAGE=(PASS_ALL_RESOLVED|PASS_FULL_CLASSIFICATION_AGENTPREMAIN_8)$' \
  "$POSTBUILD_SUMMARY" ||
  fail postbuild_runtime_linkage_not_accepted 65

for expected in \
  "SOURCE_COMMIT=$BUILD_SOURCE" \
  "SYSTEM_SHA256=$EXPECTED_SYSTEM_SHA" \
  "SYSTEM_BYTES=$EXPECTED_SYSTEM_BYTES" \
  'C1_NATIVE_REUSE_COUNT=0' \
  'ANDROID_PLATFORM_PROVIDER_COUNT=5' \
  'NATIVE_IMPORT_COUNT=28' \
  'IMPLEMENTATION_RECEIPT_ROWS=41' \
  'DEVICE_CONTACT=NONE' \
  'FLASH=NONE'
do
  grep -Fxq -- "$expected" "$ARTIFACT_ENV" ||
    fail "artifact_authority_missing=$expected" 65
done

actual_bytes="$(stat -c '%s' "$SYSTEM_IMG")" ||
  fail artifact_size_read_failed 65
[[ "$actual_bytes" == "$EXPECTED_SYSTEM_BYTES" ]] ||
  fail "artifact_size_mismatch=expected:$EXPECTED_SYSTEM_BYTES:actual:$actual_bytes" 65

grep -Fq "system.img" "$ARTIFACT_SUMS" ||
  fail artifact_system_not_in_seal_manifest 65

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE="$SABLE_EVIDENCE_ROOT/titan2/n1i-c2-recovery-entry/${STAMP}-${BUILD_SOURCE:0:12}"
[[ ! -e "$EVIDENCE" ]] || fail "evidence_dir_exists=$EVIDENCE" 64
mkdir -p "$EVIDENCE" ||
  fail evidence_dir_create_failed 64
exec > >(tee "$EVIDENCE/qualify.log") 2>&1

echo "===== TITAN 2 N1I-C2 RECOVERY-ENTRY QUALIFICATION ====="
echo "TOOL_SOURCE_COMMIT=$CURRENT_TOOL_HEAD"
echo "BUILD_SOURCE_COMMIT=$BUILD_SOURCE"
echo "SYSTEM_SHA256=$EXPECTED_SYSTEM_SHA"
echo "SYSTEM_BYTES=$EXPECTED_SYSTEM_BYTES"
echo "TARGET_PARTITION=$EXPECTED_TARGET_PARTITION"
echo "EXPECTED_SLOT=$EXPECTED_SLOT"
echo "EXPECTED_ANDROID_PRODUCT=$EXPECTED_ANDROID_PRODUCT"
echo "EXPECTED_FASTBOOTD_PRODUCT=$EXPECTED_FASTBOOTD_PRODUCT"
echo "EXPECTED_DEVICE_BINDING_SHA256=$EXPECTED_BINDING_SHA256"
echo "DEVICE_BINDING_METHOD=$BINDING_METHOD"
echo "BUILD_AUTHORIZED=NO"
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "NETWORK_FETCH_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY_RECOVERY_STATE_ONLY"
echo "ADB_READ_ONLY_AUTHORIZED=YES"
echo "FASTBOOT_READ_ONLY_DISCOVERY_AUTHORIZED=YES"
echo "MODE_TRANSITION_AUTHORIZED=NO"
echo "REBOOT_AUTHORIZED=NO"
echo "FLASH_AUTHORIZED=NO"
echo "FACTORY_RESET_AUTHORIZED=NO"
echo "SLOT_CHANGE_AUTHORIZED=NO"
echo "LP_MUTATION_AUTHORIZED=NO"
echo "AVB_MUTATION_AUTHORIZED=NO"

echo
echo "===== VERIFY POSTBUILD AUTHORITY ====="
(
  cd "$POSTBUILD_EVIDENCE"
  sha256sum -c SHA256SUMS.txt >/dev/null
) || fail postbuild_evidence_seal_invalid 66
echo "N1I_C2_RECOVERY_POSTBUILD_AUTHORITY=PASS"
echo "N1I_C2_RECOVERY_ARTIFACT_SIZE_BINDING=PASS bytes=$actual_bytes"
echo "N1I_C2_RECOVERY_ARTIFACT_HASH_RECHECK=DEFERRED_TO_FASTBOOTD_PREWRITE_GATE"

echo
echo "===== BIND SEALED TITAN RECOVERY IDENTITY ====="
if [[ "$BIND_SEALED_RECOVERY" == YES ]]; then
  titan2_mode_find_bound_adb "$SABLE_ADB" "$EXPECTED_BINDING_SHA256"
  bind_rc=$?
  [[ "$bind_rc" -eq 0 ]] ||
    fail "sealed_recovery_binding_discovery_rc=$bind_rc" 65
  [[ -n "$TITAN2_MODE_ADB_SERIAL" ]] ||
    fail sealed_recovery_binding_serial_missing 65
  SERIAL="$TITAN2_MODE_ADB_SERIAL"
  requested_hash="$(titan2_mode_hash_serial "$SERIAL")" ||
    fail sealed_recovery_serial_hash_failed 65
fi
[[ "$requested_hash" == "$EXPECTED_BINDING_SHA256" ]] ||
  fail "serial_binding_mismatch=expected:$EXPECTED_BINDING_SHA256:actual:$requested_hash" 65
echo "N1I_C2_RECOVERY_DEVICE_BINDING_METHOD=$BINDING_METHOD"
echo "N1I_C2_RECOVERY_DEVICE_BINDING_SHA256=$requested_hash"

echo
echo "===== READ-ONLY CURRENT MODE DISCOVERY ====="
titan2_detect_device_mode \
  "$SABLE_ADB" \
  "$SABLE_FASTBOOT" \
  "$SERIAL" \
  "$EXPECTED_BINDING_SHA256" \
  "$EXPECTED_BINDING_SHA256" \
  "$EXPECTED_ANDROID_PRODUCT" \
  "$EXPECTED_BOOTLOADER_PRODUCT" \
  "$EXPECTED_FASTBOOTD_PRODUCT"
mode_rc=$?

echo "N1I_C2_RECOVERY_MODE_DISCOVERY_RC=$mode_rc"
echo "N1I_C2_RECOVERY_MODE_DETECTED=$TITAN2_MODE_DETECTED"

[[ "$mode_rc" -eq 0 ]] ||
  fail "mode_discovery_rc=$mode_rc mode=$TITAN2_MODE_DETECTED" 67
[[ "$TITAN2_MODE_DETECTED" == RECOVERY_ADB ]] ||
  fail "expected_recovery_adb_actual=$TITAN2_MODE_DETECTED" 67
[[ "$TITAN2_MODE_ADB_TRANSPORT_STATE" == recovery ]] ||
  fail "expected_recovery_transport_actual=$TITAN2_MODE_ADB_TRANSPORT_STATE" 67
[[ "$TITAN2_MODE_ADB_PROPERTIES_READABLE" == NO ]] ||
  fail "unexpected_recovery_property_probe_state=$TITAN2_MODE_ADB_PROPERTIES_READABLE" 67
[[ -n "$TITAN2_MODE_ADB_SERIAL" ]] ||
  fail recovery_adb_serial_missing 67
[[ "$(titan2_mode_hash_serial "$TITAN2_MODE_ADB_SERIAL")" == "$EXPECTED_BINDING_SHA256" ]] ||
  fail recovery_adb_binding_changed 67
[[ -z "$TITAN2_MODE_FASTBOOT_SERIAL" ]] ||
  fail simultaneous_fastboot_transport_present 67

recovery_slot="DEFERRED_TO_FASTBOOTD_PREWRITE"
recovery_fingerprint="NOT_QUERIED_RECOVERY_ADB_UNREADABLE"
recovery_verified_boot="DEFERRED_TO_FASTBOOTD_PREWRITE"

{
  echo "BUILD_SOURCE_COMMIT=$BUILD_SOURCE"
  echo "SYSTEM_SHA256=$EXPECTED_SYSTEM_SHA"
  echo "SYSTEM_BYTES=$EXPECTED_SYSTEM_BYTES"
  echo "TARGET_PARTITION=$EXPECTED_TARGET_PARTITION"
  echo "EXPECTED_SLOT=$EXPECTED_SLOT"
  echo "DEVICE_BINDING_SHA256=$EXPECTED_BINDING_SHA256"
  echo "DEVICE_BINDING_METHOD=$BINDING_METHOD"
  echo "INITIAL_MODE=RECOVERY_ADB"
  echo "ADB_TRANSPORT_STATE=$TITAN2_MODE_ADB_TRANSPORT_STATE"
  echo "ADB_PROPERTIES_READABLE=$TITAN2_MODE_ADB_PROPERTIES_READABLE"
  echo "ADB_PRODUCT=NOT_QUERIED_RECOVERY_ADB_UNREADABLE"
  echo "ADB_BOOTMODE=TRANSPORT_STATE_RECOVERY"
  echo "RECOVERY_SLOT_SUFFIX=$recovery_slot"
  echo "RECOVERY_FINGERPRINT=$recovery_fingerprint"
  echo "RECOVERY_VERIFIED_BOOT_STATE=$recovery_verified_boot"
  echo "SIMULTANEOUS_FASTBOOT_TRANSPORT=NO"
  echo "MODE_TRANSITION_PERFORMED=NO"
  echo "REBOOT_PERFORMED=NO"
  echo "FLASH_PERFORMED=NO"
  echo "FACTORY_RESET_PERFORMED=NO"
} > "$EVIDENCE/recovery-entry.env"

echo "N1I_C2_RECOVERY_DEVICE_BINDING=PASS"
echo "N1I_C2_RECOVERY_TRANSPORT=PASS state=recovery"
echo "N1I_C2_RECOVERY_ADB_PROPERTIES=NOT_REQUIRED_KNOWN_UNREADABLE"
echo "N1I_C2_RECOVERY_PRODUCT=DEFERRED_TO_FASTBOOTD_PREWRITE"
echo "N1I_C2_RECOVERY_SLOT=DEFERRED_TO_FASTBOOTD_PREWRITE"
echo "N1I_C2_RECOVERY_SIMULTANEOUS_FASTBOOT=PASS_ABSENT"
echo "N1I_C2_RECOVERY_MODE_TRANSITION=BLOCKED_BY_POLICY"
echo "N1I_C2_RECOVERY_FLASH=BLOCKED_BY_POLICY"

(
  cd "$EVIDENCE"
  find . -type f ! -name qualify.log ! -name SHA256SUMS.txt -print0 |
    LC_ALL=C sort -z |
    xargs -0 sha256sum > SHA256SUMS.txt
  sha256sum -c SHA256SUMS.txt >/dev/null
) || fail evidence_seal_invalid 68

echo "N1I_C2_RECOVERY_ENTRY_EVIDENCE_SEAL=PASS_EXCLUDES_QUALIFY_LOG"
echo "N1I_C2_RECOVERY_ENTRY_QUALIFICATION=PASS_RECOVERY_CONFIRMED_NO_TRANSITION"
echo "N1I_C2_READY_FOR_RECOVERY_TO_FASTBOOTD_REVIEW=YES"
echo "N1I_C2_READY_FOR_FLASH_WRITE=NO"
echo "N1I_C2_REBOOT=NONE"
echo "N1I_C2_FLASH=NONE"
echo "N1I_C2_RECOVERY_ENTRY_EVIDENCE_DIR=$EVIDENCE"
