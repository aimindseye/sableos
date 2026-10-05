#!/usr/bin/env bash
# Governed Titan 2 N1I-C1 system_a deployment.
#
# This is intentionally separate from the read-only physical qualifier.
# Exactly one partition write is admitted: system_a <- the exact sealed C1 image.
set -uo pipefail
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/build/config/storage.env"
source "$ROOT/build/config/host-tools.env"
source "$ROOT/build/titan2/n1i-f-stock-v010014-control.env"

COMMON="$ROOT/build/titan2/n1i-c1-flash-common.sh"
FASTBOOT_QUAL="$ROOT/build/titan2/qualify-n1i-c1-fastboot-state.py"
SELFTEST="$ROOT/tests/titan2/n1i-c1/test-flash-executor.sh"

IMAGE_SOURCE_COMMIT="a745c7daa08267d851f45785a5bb7ff762ed4604"
SYSTEM_SHA256="137bc8771c817c0afb3122d9f03e7a94575e03bcccc643b56235edd1075f2160"
SYSTEM_BYTES="3210661888"
ARTIFACT_ROLE="N1I_C1_ANDROID16_CELLULAR_ISOLATION"
TARGET_PARTITION="system_a"

ACTION="${1:-}"
if (($#)); then shift; fi

AUTH_CONTACT=""
AUTH_FLASH=""
SERIAL=""
ARTIFACT_DIR=""
CLI_SHA=""
WRITE_EVIDENCE_DIR=""
POSTBOOT_TIMEOUT=240

fail() {
  echo "N1I_C1_GOVERNED_FLASH=FAIL reason=$1" >&2
  exit "${2:-1}"
}

usage() {
  cat <<'EOF'
Usage:

  Flash the exact sealed C1 image once:
    bash build/titan2/flash-n1i-c1-cellular-isolation.sh flash \
      --authorize-device-contact YES_FLASH_SYSTEM_A_ONCE \
      --authorize-flash YES_SYSTEM_A_ONCE \
      --serial SERIAL \
      --artifact-dir POSTBUILD_ARTIFACT_DIR \
      --system-image-sha256 SHA256

  Finalize a receipt after a write succeeded but Android observation was
  interrupted/timed out. This mode is read-only and never flashes:
    bash build/titan2/flash-n1i-c1-cellular-isolation.sh finalize-receipt \
      --authorize-device-contact YES_READ_ONLY \
      --serial SERIAL \
      --artifact-dir POSTBUILD_ARTIFACT_DIR \
      --system-image-sha256 SHA256 \
      --write-evidence-dir FLASH_EVIDENCE_DIR
EOF
}

while (($#)); do
  case "$1" in
    --authorize-device-contact)
      [[ "$#" -ge 2 ]] || fail missing_device_contact_authorization 64
      AUTH_CONTACT="$2"; shift 2
      ;;
    --authorize-flash)
      [[ "$#" -ge 2 ]] || fail missing_flash_authorization 64
      AUTH_FLASH="$2"; shift 2
      ;;
    --serial)
      [[ "$#" -ge 2 ]] || fail missing_serial 64
      SERIAL="$2"; shift 2
      ;;
    --artifact-dir)
      [[ "$#" -ge 2 ]] || fail missing_artifact_dir 64
      ARTIFACT_DIR="$2"; shift 2
      ;;
    --system-image-sha256)
      [[ "$#" -ge 2 ]] || fail missing_system_sha256 64
      CLI_SHA="$2"; shift 2
      ;;
    --write-evidence-dir)
      [[ "$#" -ge 2 ]] || fail missing_write_evidence_dir 64
      WRITE_EVIDENCE_DIR="$2"; shift 2
      ;;
    --postboot-timeout)
      [[ "$#" -ge 2 ]] || fail missing_postboot_timeout 64
      POSTBOOT_TIMEOUT="$2"; shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      fail "unknown_argument=$1" 64
      ;;
  esac
done

case "$ACTION" in
  flash)
    [[ "$AUTH_CONTACT" == YES_FLASH_SYSTEM_A_ONCE ]] ||
      fail device_contact_authorization_required 64
    [[ "$AUTH_FLASH" == YES_SYSTEM_A_ONCE ]] ||
      fail flash_authorization_required 64
    [[ -z "$WRITE_EVIDENCE_DIR" ]] ||
      fail write_evidence_dir_not_allowed_for_flash_mode 64
    ;;
  finalize-receipt)
    [[ "$AUTH_CONTACT" == YES_READ_ONLY ]] ||
      fail readonly_device_contact_authorization_required 64
    [[ -z "$AUTH_FLASH" ]] ||
      fail flash_authorization_forbidden_in_finalize_mode 64
    [[ -n "$WRITE_EVIDENCE_DIR" && -d "$WRITE_EVIDENCE_DIR" ]] ||
      fail write_evidence_dir_required 64
    ;;
  *)
    usage >&2
    fail invalid_action 64
    ;;
esac

[[ "$SERIAL" =~ ^[A-Za-z0-9._:-]{1,128}$ ]] || fail invalid_serial 64
[[ "$CLI_SHA" =~ ^[0-9a-f]{64}$ ]] || fail invalid_system_sha256 64
[[ "$CLI_SHA" == "$SYSTEM_SHA256" ]] || fail c1_system_sha_not_authorized 64
[[ "$POSTBOOT_TIMEOUT" =~ ^[1-9][0-9]*$ ]] || fail invalid_postboot_timeout 64
[[ -d "$ARTIFACT_DIR" ]] || fail artifact_dir_missing 64

for required in "$COMMON" "$FASTBOOT_QUAL" "$SELFTEST"; do
  [[ -f "$required" ]] || fail "required_tool_missing=$required" 69
done

# shellcheck source=/dev/null
source "$COMMON"

# Host-only checks. No adb or fastboot invocation is permitted above the device
# contact boundary below.
n1i_c1_verify_artifact \
  "$ARTIFACT_DIR" \
  "$IMAGE_SOURCE_COMMIT" \
  "$SYSTEM_SHA256" \
  "$SYSTEM_BYTES" \
  "$ARTIFACT_ROLE" ||
  fail artifact_binding_failed 65

[[ -z "$(git -C "$ROOT" status --porcelain=v1 --untracked-files=all)" ]] ||
  fail tooling_repo_dirty 65

bash -n "$0" "$COMMON" "$SELFTEST" || fail shell_syntax_selftest 65
python3 - "$FASTBOOT_QUAL" <<'PY_SYNTAX' || fail python_syntax_selftest 65
import pathlib
import sys
path = pathlib.Path(sys.argv[1])
compile(path.read_text(encoding="utf-8"), str(path), "exec")
PY_SYNTAX
bash "$SELFTEST" --static-only >/dev/null 2>&1 || fail flash_static_selftest 65

TOOL_SOURCE_COMMIT="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || true)"
[[ "$TOOL_SOURCE_COMMIT" =~ ^[0-9a-f]{40}$ ]] || fail tool_source_commit_unknown 65

ADB_BIN="${SABLE_ADB:-}"
FASTBOOT_BIN="${SABLE_FASTBOOT:-}"
if [[ -z "$ADB_BIN" || ! -x "$ADB_BIN" ]]; then
  ADB_BIN="$(command -v adb || true)"
fi
if [[ -z "$FASTBOOT_BIN" || ! -x "$FASTBOOT_BIN" ]]; then
  FASTBOOT_BIN="$(command -v fastboot || true)"
fi
[[ -x "$ADB_BIN" ]] || fail adb_unavailable 69
[[ -x "$FASTBOOT_BIN" ]] || fail fastboot_unavailable 69

FASTBOOT_VERSION="$(
  "$FASTBOOT_BIN" --version 2>/dev/null |
    awk '/^fastboot version / {print $3; exit}' |
    cut -d- -f1
)"
[[ -n "$FASTBOOT_VERSION" ]] || fail fastboot_version_unreadable 69
[[ "$(
  printf '%s\n' 35.0.1 "$FASTBOOT_VERSION" |
    sort -V |
    head -n1
)" == 35.0.1 ]] || fail "fastboot_version_too_old=$FASTBOOT_VERSION" 69

SERIAL_SHA256="$(printf '%s' "$SERIAL" | sha256sum | awk '{print $1}')"
SYSTEM_IMG="$ARTIFACT_DIR/system.img"

echo "===== TITAN 2 N1I-C1 GOVERNED FLASH ====="
echo "ACTION=$ACTION"
echo "N1I_C1_IMAGE_SOURCE_COMMIT=$IMAGE_SOURCE_COMMIT"
echo "N1I_C1_SYSTEM_IMAGE_SHA256=$SYSTEM_SHA256"
echo "N1I_C1_SYSTEM_IMAGE_BYTES=$SYSTEM_BYTES"
echo "N1I_C1_TARGET_PARTITION=$TARGET_PARTITION"
echo "N1I_C1_DEVICE_SERIAL_SHA256=$SERIAL_SHA256"
echo "N1I_C1_TOOL_SOURCE_COMMIT=$TOOL_SOURCE_COMMIT"
echo "N1I_C1_FACTORY_RESET_AUTHORIZED=NO"
echo "N1I_C1_USERDATA_ERASE_AUTHORIZED=NO"
echo "N1I_C1_SLOT_CHANGE_AUTHORIZED=NO"
echo "N1I_C1_AVB_MUTATION_AUTHORIZED=NO"
echo "N1I_C1_BOOT_CHAIN_MUTATION_AUTHORIZED=NO"
echo "N1I_C1_COW_DELETION_AUTHORIZED=NO"
echo "N1I_C1_AUTOMATIC_FLASH_RETRY=NO"

verify_android_identity() {
  local runtime_serial vendor_device vendor_mfr vendor_fp release sdk slot boot
  runtime_serial="$("$ADB_BIN" -s "$SERIAL" shell getprop ro.serialno </dev/null 2>/dev/null | tr -d '\r')"
  vendor_device="$("$ADB_BIN" -s "$SERIAL" shell getprop ro.product.vendor.device </dev/null 2>/dev/null | tr -d '\r')"
  vendor_mfr="$("$ADB_BIN" -s "$SERIAL" shell getprop ro.product.vendor.manufacturer </dev/null 2>/dev/null | tr -d '\r')"
  vendor_fp="$("$ADB_BIN" -s "$SERIAL" shell getprop ro.vendor.build.fingerprint </dev/null 2>/dev/null | tr -d '\r')"
  release="$("$ADB_BIN" -s "$SERIAL" shell getprop ro.build.version.release </dev/null 2>/dev/null | tr -d '\r')"
  sdk="$("$ADB_BIN" -s "$SERIAL" shell getprop ro.build.version.sdk </dev/null 2>/dev/null | tr -d '\r')"
  slot="$("$ADB_BIN" -s "$SERIAL" shell getprop ro.boot.slot_suffix </dev/null 2>/dev/null | tr -d '\r')"
  boot="$("$ADB_BIN" -s "$SERIAL" shell getprop sys.boot_completed </dev/null 2>/dev/null | tr -d '\r')"

  [[ "$runtime_serial" == "$SERIAL" ]] || return 1
  [[ "$vendor_device" == Titan_2 ]] || return 1
  [[ "$vendor_mfr" == Unihertz ]] || return 1
  [[ "$vendor_fp" == "$STOCK_VENDOR_FINGERPRINT" ]] || return 1
  [[ "$release" == 16 && "$sdk" == 36 ]] || return 1
  [[ "$slot" == _a ]] || return 1
  [[ "$boot" == 1 ]] || return 1
  return 0
}

verify_attempt_journal() {
  local root journal env_file sums
  root="$1"
  journal="$root/attempt-journal"
  env_file="$journal/N1I_C1_FLASH_ATTEMPT_ARMED.env"
  sums="$journal/SHA256SUMS.txt"
  local version serial_hash role source sha bytes target number state tool_commit

  [[ -d "$journal" && -f "$env_file" && -f "$sums" ]] || return 1
  n1i_c1_manifest_safe "$sums" || return 1
  (cd "$journal" && sha256sum -c SHA256SUMS.txt >/dev/null 2>&1) || return 1

  version="$(n1i_c1_env_value "$env_file" N1I_C1_FLASH_ATTEMPT_JOURNAL_VERSION)" || return 1
  serial_hash="$(n1i_c1_env_value "$env_file" DEVICE_SERIAL_SHA256)" || return 1
  role="$(n1i_c1_env_value "$env_file" ARTIFACT_ROLE)" || return 1
  source="$(n1i_c1_env_value "$env_file" IMAGE_SOURCE_COMMIT)" || return 1
  sha="$(n1i_c1_env_value "$env_file" SYSTEM_SHA256)" || return 1
  bytes="$(n1i_c1_env_value "$env_file" SYSTEM_BYTES)" || return 1
  target="$(n1i_c1_env_value "$env_file" TARGET_PARTITION)" || return 1
  number="$(n1i_c1_env_value "$env_file" FLASH_ATTEMPT_NUMBER)" || return 1
  state="$(n1i_c1_env_value "$env_file" ATTEMPT_STATE)" || return 1
  tool_commit="$(n1i_c1_env_value "$env_file" TOOL_SOURCE_COMMIT)" || return 1

  [[ "$version" == 1 ]] || return 1
  [[ "$serial_hash" == "$SERIAL_SHA256" ]] || return 1
  [[ "$role" == "$ARTIFACT_ROLE" ]] || return 1
  [[ "$source" == "$IMAGE_SOURCE_COMMIT" ]] || return 1
  [[ "$sha" == "$SYSTEM_SHA256" ]] || return 1
  [[ "$bytes" == "$SYSTEM_BYTES" ]] || return 1
  [[ "$target" == "$TARGET_PARTITION" ]] || return 1
  [[ "$number" == 1 && "$state" == ARMED ]] || return 1
  [[ "$tool_commit" =~ ^[0-9a-f]{40}$ ]] || return 1
}

verify_attempt_retirement() {
  local root retire_dir env_file sums attempt_sums
  local version serial_hash role source sha bytes target original_tool attempt_seal
  local preflight_baseline preflight_bytes reason reached retired contact fb adb
  local actual_attempt_seal command_dir write_proof
  root="$1"
  retire_dir="$root/attempt-retirement"
  env_file="$retire_dir/N1I_C1_PREWRITE_ABORT_RETIREMENT.env"
  sums="$retire_dir/SHA256SUMS.txt"
  attempt_sums="$root/attempt-journal/SHA256SUMS.txt"
  command_dir="$root/command-journal"
  write_proof="$root/write-proof"

  [[ -d "$retire_dir" && -f "$env_file" && -f "$sums" && -f "$attempt_sums" ]] ||
    return 1
  n1i_c1_manifest_safe "$sums" || return 1
  (cd "$retire_dir" && sha256sum -c SHA256SUMS.txt >/dev/null 2>&1) || return 1

  version="$(n1i_c1_env_value "$env_file" N1I_C1_PREWRITE_ABORT_RETIREMENT_VERSION)" || return 1
  serial_hash="$(n1i_c1_env_value "$env_file" DEVICE_SERIAL_SHA256)" || return 1
  role="$(n1i_c1_env_value "$env_file" ARTIFACT_ROLE)" || return 1
  source="$(n1i_c1_env_value "$env_file" IMAGE_SOURCE_COMMIT)" || return 1
  sha="$(n1i_c1_env_value "$env_file" SYSTEM_SHA256)" || return 1
  bytes="$(n1i_c1_env_value "$env_file" SYSTEM_BYTES)" || return 1
  target="$(n1i_c1_env_value "$env_file" TARGET_PARTITION)" || return 1
  original_tool="$(n1i_c1_env_value "$env_file" ORIGINAL_ATTEMPT_TOOL_SOURCE_COMMIT)" || return 1
  attempt_seal="$(n1i_c1_env_value "$env_file" ORIGINAL_ATTEMPT_SEAL_SHA256)" || return 1
  preflight_baseline="$(n1i_c1_env_value "$env_file" PREFLIGHT_BASELINE)" || return 1
  preflight_bytes="$(n1i_c1_env_value "$env_file" PREFLIGHT_SYSTEM_A_BYTES)" || return 1
  reason="$(n1i_c1_env_value "$env_file" ABORT_REASON)" || return 1
  reached="$(n1i_c1_env_value "$env_file" FLASH_COMMAND_LINE_REACHED)" || return 1
  retired="$(n1i_c1_env_value "$env_file" ORIGINAL_ATTEMPT_RETIRED)" || return 1
  contact="$(n1i_c1_env_value "$env_file" DEVICE_CONTACT)" || return 1
  fb="$(n1i_c1_env_value "$env_file" FASTBOOT_COMMANDS_RUN)" || return 1
  adb="$(n1i_c1_env_value "$env_file" ADB_COMMANDS_RUN)" || return 1
  actual_attempt_seal="$(sha256sum "$attempt_sums" | awk '{print $1}')"

  [[ "$version" == 1 ]] || return 1
  [[ "$serial_hash" == "$SERIAL_SHA256" ]] || return 1
  [[ "$role" == "$ARTIFACT_ROLE" ]] || return 1
  [[ "$source" == "$IMAGE_SOURCE_COMMIT" ]] || return 1
  [[ "$sha" == "$SYSTEM_SHA256" ]] || return 1
  [[ "$bytes" == "$SYSTEM_BYTES" ]] || return 1
  [[ "$target" == "$TARGET_PARTITION" ]] || return 1
  [[ "$original_tool" == 4024d750e5e2eb019ff62532d2a1fe685902c0aa ]] || return 1
  [[ "$attempt_seal" == "$actual_attempt_seal" ]] || return 1
  [[ "$preflight_baseline" == STOCK_V010014 ]] || return 1
  [[ "$preflight_bytes" == 757059584 ]] || return 1
  [[ "$reason" == KNOWN_NOUNSET_JOURNAL_VERIFIER_BEFORE_FLASH_SITE ]] || return 1
  [[ "$reached" == NO && "$retired" == YES ]] || return 1
  [[ "$contact" == NONE && "$fb" == NONE && "$adb" == NONE ]] || return 1

  [[ ! -e "$write_proof/fastboot-flash-system-a.log" ]] || return 1
  [[ ! -e "$write_proof/fastboot-getvar-all-post.txt" ]] || return 1
  [[ ! -e "$write_proof/post-state.env" ]] || return 1
  [[ ! -e "$write_proof/N1I_C1_WRITE_COMPLETED.env" ]] || return 1
  [[ ! -e "$write_proof/SHA256SUMS.txt" ]] || return 1
  if [[ -d "$command_dir" ]] &&
     find "$command_dir" -mindepth 1 -maxdepth 1 -type f -print -quit |
       grep -q .; then
    return 1
  fi
  return 0
}

find_prior_write_attempt() {
  local root="$SABLE_EVIDENCE_ROOT/titan2/n1i-c1-governed-flash"
  local env run journal sums serial_hash source sha target state
  [[ -d "$root" ]] || return 1
  while IFS= read -r env; do
    [[ -f "$env" ]] || continue
    journal="$(dirname "$env")"
    run="$(dirname "$journal")"
    sums="$journal/SHA256SUMS.txt"

    if [[ ! -f "$sums" ]] ||
       ! n1i_c1_manifest_safe "$sums" ||
       ! (cd "$journal" && sha256sum -c SHA256SUMS.txt >/dev/null 2>&1); then
      printf 'CORRUPT:%s\n' "$run"
      return 2
    fi

    serial_hash="$(n1i_c1_env_value "$env" DEVICE_SERIAL_SHA256 2>/dev/null || true)"
    source="$(n1i_c1_env_value "$env" IMAGE_SOURCE_COMMIT 2>/dev/null || true)"
    sha="$(n1i_c1_env_value "$env" SYSTEM_SHA256 2>/dev/null || true)"
    target="$(n1i_c1_env_value "$env" TARGET_PARTITION 2>/dev/null || true)"
    state="$(n1i_c1_env_value "$env" ATTEMPT_STATE 2>/dev/null || true)"
    if [[ -z "$serial_hash" || -z "$source" || -z "$sha" || -z "$target" || -z "$state" ]]; then
      printf 'CORRUPT:%s\n' "$run"
      return 2
    fi

    if [[ "$serial_hash" == "$SERIAL_SHA256" &&
          "$source" == "$IMAGE_SOURCE_COMMIT" &&
          "$sha" == "$SYSTEM_SHA256" &&
          "$target" == "$TARGET_PARTITION" &&
          "$state" == ARMED ]]; then
      verify_attempt_journal "$run" || {
        printf 'CORRUPT:%s\n' "$run"
        return 2
      }
      if [[ -d "$run/attempt-retirement" ]]; then
        verify_attempt_retirement "$run" || {
          printf 'CORRUPT:%s\n' "$run"
          return 2
        }
        continue
      fi
      printf '%s\n' "$run"
      return 0
    fi
  done < <(
    find "$root" -type f \
      -path '*/attempt-journal/N1I_C1_FLASH_ATTEMPT_ARMED.env' \
      -print 2>/dev/null |
      LC_ALL=C sort
  )
  return 1
}
verify_command_journal() {
  local root journal env_file sums
  root="$1"
  journal="$root/command-journal"
  env_file="$journal/N1I_C1_FLASH_COMMAND_SUCCEEDED.env"
  sums="$journal/SHA256SUMS.txt"
  local version serial_hash source sha target attempts rc result log_sha actual_log_sha

  [[ -d "$journal" && -f "$env_file" && -f "$sums" ]] || return 1
  n1i_c1_manifest_safe "$sums" || return 1
  (cd "$journal" && sha256sum -c SHA256SUMS.txt >/dev/null 2>&1) || return 1

  version="$(n1i_c1_env_value "$env_file" N1I_C1_FLASH_COMMAND_JOURNAL_VERSION)" || return 1
  serial_hash="$(n1i_c1_env_value "$env_file" DEVICE_SERIAL_SHA256)" || return 1
  source="$(n1i_c1_env_value "$env_file" IMAGE_SOURCE_COMMIT)" || return 1
  sha="$(n1i_c1_env_value "$env_file" SYSTEM_SHA256)" || return 1
  target="$(n1i_c1_env_value "$env_file" TARGET_PARTITION)" || return 1
  attempts="$(n1i_c1_env_value "$env_file" FLASH_ATTEMPT_COUNT)" || return 1
  rc="$(n1i_c1_env_value "$env_file" FASTBOOT_FLASH_RC)" || return 1
  result="$(n1i_c1_env_value "$env_file" FLASH_COMMAND_RESULT)" || return 1
  log_sha="$(n1i_c1_env_value "$env_file" FLASH_LOG_SHA256)" || return 1
  [[ -f "$journal/fastboot-flash-system-a.log" ]] || return 1
  actual_log_sha="$(sha256sum "$journal/fastboot-flash-system-a.log" | awk '{print $1}')"

  [[ "$version" == 1 ]] || return 1
  [[ "$serial_hash" == "$SERIAL_SHA256" ]] || return 1
  [[ "$source" == "$IMAGE_SOURCE_COMMIT" ]] || return 1
  [[ "$sha" == "$SYSTEM_SHA256" ]] || return 1
  [[ "$target" == "$TARGET_PARTITION" ]] || return 1
  [[ "$attempts" == 1 && "$rc" == 0 && "$result" == PASS ]] || return 1
  [[ "$log_sha" == "$actual_log_sha" ]] || return 1
}

find_prior_successful_flash() {
  local root="$SABLE_EVIDENCE_ROOT/titan2/n1i-c1-governed-flash"
  local env run journal sums
  local version serial_hash source sha target attempts rc result
  [[ -d "$root" ]] || return 1
  while IFS= read -r env; do
    [[ -f "$env" ]] || continue
    journal="$(dirname "$env")"
    run="$(dirname "$journal")"
    sums="$journal/SHA256SUMS.txt"

    if [[ ! -f "$sums" ]] ||
       ! n1i_c1_manifest_safe "$sums" ||
       ! (cd "$journal" && sha256sum -c SHA256SUMS.txt >/dev/null 2>&1); then
      printf 'CORRUPT:%s\n' "$run"
      return 2
    fi

    version="$(n1i_c1_env_value "$env" N1I_C1_FLASH_COMMAND_JOURNAL_VERSION 2>/dev/null || true)"
    serial_hash="$(n1i_c1_env_value "$env" DEVICE_SERIAL_SHA256 2>/dev/null || true)"
    source="$(n1i_c1_env_value "$env" IMAGE_SOURCE_COMMIT 2>/dev/null || true)"
    sha="$(n1i_c1_env_value "$env" SYSTEM_SHA256 2>/dev/null || true)"
    target="$(n1i_c1_env_value "$env" TARGET_PARTITION 2>/dev/null || true)"
    attempts="$(n1i_c1_env_value "$env" FLASH_ATTEMPT_COUNT 2>/dev/null || true)"
    rc="$(n1i_c1_env_value "$env" FASTBOOT_FLASH_RC 2>/dev/null || true)"
    result="$(n1i_c1_env_value "$env" FLASH_COMMAND_RESULT 2>/dev/null || true)"
    if [[ -z "$version" || -z "$serial_hash" || -z "$source" || -z "$sha" ||
          -z "$target" || -z "$attempts" || -z "$rc" || -z "$result" ]]; then
      printf 'CORRUPT:%s\n' "$run"
      return 2
    fi

    if [[ "$serial_hash" == "$SERIAL_SHA256" &&
          "$source" == "$IMAGE_SOURCE_COMMIT" &&
          "$sha" == "$SYSTEM_SHA256" &&
          "$target" == "$TARGET_PARTITION" &&
          "$attempts" == 1 &&
          "$rc" == 0 &&
          "$result" == PASS ]]; then
      verify_command_journal "$run" || {
        printf 'CORRUPT:%s\n' "$run"
        return 2
      }
      printf '%s\n' "$run"
      return 0
    fi
  done < <(
    find "$root" -type f       -path '*/command-journal/N1I_C1_FLASH_COMMAND_SUCCEEDED.env'       -print 2>/dev/null |
      LC_ALL=C sort
  )
  return 1
}

verify_write_proof() {
  local root proof env_file sums
  root="$1"
  proof="$root/write-proof"
  env_file="$proof/N1I_C1_WRITE_COMPLETED.env"
  sums="$proof/SHA256SUMS.txt"
  local serial_hash source sha target attempts result
  verify_attempt_journal "$root" || return 1
  verify_command_journal "$root" || return 1
  [[ -d "$proof" && -f "$env_file" && -f "$sums" ]] || return 1
  n1i_c1_manifest_safe "$sums" || return 1
  (cd "$proof" && sha256sum -c SHA256SUMS.txt >/dev/null 2>&1) || return 1

  serial_hash="$(n1i_c1_env_value "$env_file" DEVICE_SERIAL_SHA256)" || return 1
  source="$(n1i_c1_env_value "$env_file" IMAGE_SOURCE_COMMIT)" || return 1
  sha="$(n1i_c1_env_value "$env_file" SYSTEM_SHA256)" || return 1
  target="$(n1i_c1_env_value "$env_file" TARGET_PARTITION)" || return 1
  attempts="$(n1i_c1_env_value "$env_file" FLASH_ATTEMPT_COUNT)" || return 1
  result="$(n1i_c1_env_value "$env_file" FLASH_RESULT)" || return 1

  [[ "$serial_hash" == "$SERIAL_SHA256" ]] || return 1
  [[ "$source" == "$IMAGE_SOURCE_COMMIT" ]] || return 1
  [[ "$sha" == "$SYSTEM_SHA256" ]] || return 1
  [[ "$target" == "$TARGET_PARTITION" ]] || return 1
  [[ "$attempts" == 1 ]] || return 1
  [[ "$result" == PASS ]] || return 1
}

finalize_receipt() {
  local evidence="$1" mode runtime_serial release sdk vendor_device vendor_mfr vendor_fp
  local slot boot build_fp proof_seal attempt_journal_seal command_journal_seal receipt_root receipt_dir stamp
  local receipt runtime

  verify_write_proof "$evidence" || fail write_proof_invalid 66

  mode="$(n1i_c1_probe_mode)"
  [[ "$mode" == ANDROID_ADB ]] || fail "receipt_requires_android_adb mode=$mode" 67
  verify_android_identity || fail receipt_runtime_identity 67

  runtime_serial="$("$ADB_BIN" -s "$SERIAL" shell getprop ro.serialno </dev/null 2>/dev/null | tr -d '\r')"
  release="$("$ADB_BIN" -s "$SERIAL" shell getprop ro.build.version.release </dev/null 2>/dev/null | tr -d '\r')"
  sdk="$("$ADB_BIN" -s "$SERIAL" shell getprop ro.build.version.sdk </dev/null 2>/dev/null | tr -d '\r')"
  vendor_device="$("$ADB_BIN" -s "$SERIAL" shell getprop ro.product.vendor.device </dev/null 2>/dev/null | tr -d '\r')"
  vendor_mfr="$("$ADB_BIN" -s "$SERIAL" shell getprop ro.product.vendor.manufacturer </dev/null 2>/dev/null | tr -d '\r')"
  vendor_fp="$("$ADB_BIN" -s "$SERIAL" shell getprop ro.vendor.build.fingerprint </dev/null 2>/dev/null | tr -d '\r')"
  slot="$("$ADB_BIN" -s "$SERIAL" shell getprop ro.boot.slot_suffix </dev/null 2>/dev/null | tr -d '\r')"
  boot="$("$ADB_BIN" -s "$SERIAL" shell getprop sys.boot_completed </dev/null 2>/dev/null | tr -d '\r')"
  build_fp="$("$ADB_BIN" -s "$SERIAL" shell getprop ro.build.fingerprint </dev/null 2>/dev/null | tr -d '\r')"

  proof_seal="$(sha256sum "$evidence/write-proof/SHA256SUMS.txt" | awk '{print $1}')"
  attempt_journal_seal="$(sha256sum "$evidence/attempt-journal/SHA256SUMS.txt" | awk '{print $1}')"
  command_journal_seal="$(sha256sum "$evidence/command-journal/SHA256SUMS.txt" | awk '{print $1}')"
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  receipt_root="$SABLE_ARTIFACTS_ROOT/titan2/n1i-c1-flash-receipts"
  receipt_dir="$receipt_root/${stamp}-${SYSTEM_SHA256:0:12}-${SERIAL_SHA256:0:12}"
  mkdir -p "$receipt_dir" || fail receipt_dir_create 68
  chmod 700 "$receipt_dir" 2>/dev/null || true

  receipt="$receipt_dir/TITAN2_FLASH_RECEIPT.env"
  runtime="$receipt_dir/postboot-runtime.env"

  cat > "$receipt" <<EOF_RECEIPT
TITAN2_FLASH_RECEIPT_VERSION=1
DEVICE_SERIAL=$SERIAL
DEVICE_SERIAL_SHA256=$SERIAL_SHA256
ARTIFACT_ROLE=$ARTIFACT_ROLE
IMAGE_SOURCE_COMMIT=$IMAGE_SOURCE_COMMIT
SYSTEM_SHA256=$SYSTEM_SHA256
SYSTEM_BYTES=$SYSTEM_BYTES
TARGET_PARTITION=$TARGET_PARTITION
FLASH_RESULT=PASS
FLASH_ATTEMPT_COUNT=1
FLASH_ATTEMPT_JOURNAL_SHA256=$attempt_journal_seal
FLASH_COMMAND_JOURNAL_SHA256=$command_journal_seal
FLASH_WRITE_PROOF_SHA256=$proof_seal
POST_FLASH_DEVICE_SERIAL=$runtime_serial
POST_FLASH_MODE=ANDROID_ADB
POST_FLASH_SLOT=$slot
POST_FLASH_ANDROID_RELEASE=$release
POST_FLASH_ANDROID_SDK=$sdk
POST_FLASH_VENDOR_FINGERPRINT=$vendor_fp
TOOL_SOURCE_COMMIT=$TOOL_SOURCE_COMMIT
EOF_RECEIPT

  cat > "$runtime" <<EOF_RUNTIME
DEVICE_SERIAL_SHA256=$SERIAL_SHA256
SYS_BOOT_COMPLETED=$boot
RO_BUILD_VERSION_RELEASE=$release
RO_BUILD_VERSION_SDK=$sdk
RO_PRODUCT_VENDOR_DEVICE=$vendor_device
RO_PRODUCT_VENDOR_MANUFACTURER=$vendor_mfr
RO_VENDOR_BUILD_FINGERPRINT=$vendor_fp
RO_BOOT_SLOT_SUFFIX=$slot
RO_BUILD_FINGERPRINT=$build_fp
EOF_RUNTIME

  (
    cd "$receipt_dir" || exit 1
    sha256sum TITAN2_FLASH_RECEIPT.env postboot-runtime.env > SHA256SUMS.txt
    sha256sum -c SHA256SUMS.txt >/dev/null
  ) || fail receipt_seal 68
  chmod 600 "$receipt" "$runtime" "$receipt_dir/SHA256SUMS.txt" 2>/dev/null || true

  echo "N1I_C1_FLASH_RECEIPT=PASS"
  echo "N1I_C1_FLASH_RECEIPT_DIR=$receipt_dir"
}

if [[ "$ACTION" == flash ]]; then
  PRIOR_ATTEMPT="$(find_prior_write_attempt 2>/dev/null)"
  PRIOR_ATTEMPT_RC=$?
  if [[ "$PRIOR_ATTEMPT_RC" -eq 0 ]]; then
    echo "N1I_C1_FLASH_DUPLICATE_WRITE_GUARD=REFUSE_PRIOR_ATTEMPT"
    echo "N1I_C1_PRIOR_FLASH_ATTEMPT_EVIDENCE=$PRIOR_ATTEMPT"
    echo "N1I_C1_DO_NOT_REFLASH=YES"
    exit 19
  fi
  if [[ "$PRIOR_ATTEMPT_RC" -eq 2 ]]; then
    echo "N1I_C1_FLASH_DUPLICATE_WRITE_GUARD=REFUSE_CORRUPT_ATTEMPT_EVIDENCE"
    echo "N1I_C1_CORRUPT_FLASH_EVIDENCE=$PRIOR_ATTEMPT"
    echo "N1I_C1_DO_NOT_REFLASH=YES"
    exit 21
  fi
  [[ "$PRIOR_ATTEMPT_RC" -eq 1 ]] || fail "attempt_guard_rc=$PRIOR_ATTEMPT_RC" 65

  PRIOR_SUCCESS="$(find_prior_successful_flash 2>/dev/null)"
  PRIOR_RC=$?
  if [[ "$PRIOR_RC" -eq 0 ]]; then
    echo "N1I_C1_FLASH_DUPLICATE_WRITE_GUARD=REFUSE"
    echo "N1I_C1_PRIOR_SUCCESSFUL_FLASH_EVIDENCE=$PRIOR_SUCCESS"
    echo "N1I_C1_DO_NOT_REFLASH=YES"
    exit 20
  fi
  if [[ "$PRIOR_RC" -eq 2 ]]; then
    echo "N1I_C1_FLASH_DUPLICATE_WRITE_GUARD=REFUSE_CORRUPT_EVIDENCE"
    echo "N1I_C1_CORRUPT_FLASH_EVIDENCE=$PRIOR_SUCCESS"
    echo "N1I_C1_DO_NOT_REFLASH=YES"
    exit 21
  fi
  [[ "$PRIOR_RC" -eq 1 ]] || fail "duplicate_guard_rc=$PRIOR_RC" 65
fi

# ----------------------------- DEVICE CONTACT BOUNDARY -----------------------------

if [[ "$ACTION" == finalize-receipt ]]; then
  echo "N1I_C1_DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY"
  echo "N1I_C1_FLASH_AUTHORIZED=NO"
  finalize_receipt "$WRITE_EVIDENCE_DIR"
  echo "N1I_C1_GOVERNED_FLASH=PASS_RECEIPT_FINALIZED_READ_ONLY"
  exit 0
fi

echo "N1I_C1_DEVICE_CONTACT_AUTHORIZED=YES_FLASH_SYSTEM_A_ONCE"
echo "N1I_C1_DEVICE_REBOOT_AUTHORIZED=YES_MODE_TRANSITION_AND_POSTFLASH_ONCE"
echo "N1I_C1_FLASH_AUTHORIZED=YES_SYSTEM_A_ONCE"

INITIAL_MODE="$(n1i_c1_probe_mode)"
if [[ "$INITIAL_MODE" == ANDROID_ADB ]]; then
  verify_android_identity || fail adb_entry_identity 70
fi

n1i_c1_enter_fastbootd || fail unable_to_enter_fastbootd 70

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="$SABLE_EVIDENCE_ROOT/titan2/n1i-c1-governed-flash/${STAMP}-${SYSTEM_SHA256:0:12}"
WRITE_PROOF="$EVIDENCE_DIR/write-proof"
ATTEMPT_JOURNAL="$EVIDENCE_DIR/attempt-journal"
COMMAND_JOURNAL="$EVIDENCE_DIR/command-journal"
mkdir -p "$WRITE_PROOF" "$ATTEMPT_JOURNAL" "$COMMAND_JOURNAL" || fail evidence_dir_create 71
chmod 700 "$EVIDENCE_DIR" "$WRITE_PROOF" "$ATTEMPT_JOURNAL" "$COMMAND_JOURNAL" 2>/dev/null || true
echo "N1I_C1_FLASH_EVIDENCE_DIR=$EVIDENCE_DIR"

echo "===== N1I-C1 FASTBOOTD PREWRITE STATE ====="
"$FASTBOOT_BIN" -s "$SERIAL" getvar all </dev/null \
  > "$WRITE_PROOF/fastboot-getvar-all-pre.txt" 2>&1
GETVAR_PRE_RC=$?
if [[ "$GETVAR_PRE_RC" -ne 0 ]]; then
  echo "N1I_C1_FLASH_EVIDENCE_DIR=$EVIDENCE_DIR"
  fail "pre_getvar_all_rc=$GETVAR_PRE_RC" 72
fi

python3 "$FASTBOOT_QUAL" \
  --getvar-all "$WRITE_PROOF/fastboot-getvar-all-pre.txt" \
  --phase pre \
  --out-env "$WRITE_PROOF/pre-state.env"
PRE_RC=$?
[[ "$PRE_RC" -eq 0 ]] || {
  [[ "$PRE_RC" -eq 20 ]] &&
    echo "N1I_C1_FLASH_REFUSED=ALREADY_TARGET_SIZE_USE_EXISTING_WRITE_PROOF_OR_OWNER_REVIEW"
  echo "N1I_C1_FLASH_EVIDENCE_DIR=$EVIDENCE_DIR"
  echo "N1I_C1_PREFLIGHT_GETVAR_ALL=$WRITE_PROOF/fastboot-getvar-all-pre.txt"
  echo "N1I_C1_PREFLIGHT_STATE_ENV=$WRITE_PROOF/pre-state.env"
  fail "fastboot_preflight_rc=$PRE_RC" 72
}

# shellcheck source=/dev/null
source "$WRITE_PROOF/pre-state.env"
echo "N1I_C1_PREFLASH_BASELINE=$N1I_C1_FASTBOOT_BASELINE"
echo "N1I_C1_PREFLASH_SYSTEM_A_BYTES=$N1I_C1_FASTBOOT_SYSTEM_A_BYTES"
echo "N1I_C1_PREFLASH_ACTIVE_COW_COUNT=0"
echo "N1I_C1_PREFLASH=PASS"

cat > "$EVIDENCE_DIR/policy.env" <<EOF_POLICY
N1I_C1_DEVICE_CONTACT_AUTHORIZED=YES_FLASH_SYSTEM_A_ONCE
N1I_C1_FLASH_AUTHORIZED=YES_SYSTEM_A_ONCE
N1I_C1_FLASH_TARGET=system_a
N1I_C1_FLASH_ATTEMPT_LIMIT=1
N1I_C1_AUTOMATIC_FLASH_RETRY=NO
N1I_C1_FACTORY_RESET_AUTHORIZED=NO
N1I_C1_USERDATA_ERASE_AUTHORIZED=NO
N1I_C1_SLOT_CHANGE_AUTHORIZED=NO
N1I_C1_AVB_MUTATION_AUTHORIZED=NO
N1I_C1_BOOT_CHAIN_MUTATION_AUTHORIZED=NO
N1I_C1_COW_DELETION_AUTHORIZED=NO
EOF_POLICY

cat > "$ATTEMPT_JOURNAL/N1I_C1_FLASH_ATTEMPT_ARMED.env" <<EOF_ATTEMPT
N1I_C1_FLASH_ATTEMPT_JOURNAL_VERSION=1
DEVICE_SERIAL_SHA256=$SERIAL_SHA256
ARTIFACT_ROLE=$ARTIFACT_ROLE
IMAGE_SOURCE_COMMIT=$IMAGE_SOURCE_COMMIT
SYSTEM_SHA256=$SYSTEM_SHA256
SYSTEM_BYTES=$SYSTEM_BYTES
TARGET_PARTITION=$TARGET_PARTITION
PREFLASH_BASELINE=$N1I_C1_FASTBOOT_BASELINE
PREFLASH_SYSTEM_A_BYTES=$N1I_C1_FASTBOOT_SYSTEM_A_BYTES
FLASH_ATTEMPT_NUMBER=1
ATTEMPT_STATE=ARMED
TOOL_SOURCE_COMMIT=$TOOL_SOURCE_COMMIT
AUTOMATIC_FLASH_RETRY=NO
EOF_ATTEMPT
(
  cd "$ATTEMPT_JOURNAL" || exit 1
  sha256sum N1I_C1_FLASH_ATTEMPT_ARMED.env > SHA256SUMS.txt
  sha256sum -c SHA256SUMS.txt >/dev/null
) || fail flash_attempt_journal_seal 73
verify_attempt_journal "$EVIDENCE_DIR" || fail flash_attempt_journal_verify 73

echo "N1I_C1_FLASH_ATTEMPT_JOURNAL=PASS"
echo "N1I_C1_FLASH_ATTEMPT_ARMED=YES"
echo "N1I_C1_DO_NOT_REFLASH_AFTER_THIS_POINT_WITHOUT_OWNER_REVIEW=YES"

echo "===== N1I-C1 SINGLE SYSTEM_A WRITE ====="
"$FASTBOOT_BIN" -s "$SERIAL" flash system_a "$SYSTEM_IMG" </dev/null \
  > "$WRITE_PROOF/fastboot-flash-system-a.log" 2>&1
FLASH_RC=$?
cat "$WRITE_PROOF/fastboot-flash-system-a.log"
echo "N1I_C1_FASTBOOT_FLASH_SYSTEM_A_RC=$FLASH_RC"
if [[ "$FLASH_RC" -ne 0 ]]; then
  echo "N1I_C1_FLASH_WRITE=FAIL_NO_AUTOMATIC_RETRY"
  echo "N1I_C1_DO_NOT_REFLASH_WITHOUT_OWNER_REVIEW=YES"
  echo "N1I_C1_FLASH_EVIDENCE_DIR=$EVIDENCE_DIR"
  fail "system_a_flash_rc=$FLASH_RC" 73
fi

cp "$WRITE_PROOF/fastboot-flash-system-a.log" "$COMMAND_JOURNAL/fastboot-flash-system-a.log" ||
  fail flash_command_journal_log_copy 73
FLASH_LOG_SHA256="$(sha256sum "$COMMAND_JOURNAL/fastboot-flash-system-a.log" | awk '{print $1}')"
cat > "$COMMAND_JOURNAL/N1I_C1_FLASH_COMMAND_SUCCEEDED.env" <<EOF_COMMAND
N1I_C1_FLASH_COMMAND_JOURNAL_VERSION=1
DEVICE_SERIAL_SHA256=$SERIAL_SHA256
ARTIFACT_ROLE=$ARTIFACT_ROLE
IMAGE_SOURCE_COMMIT=$IMAGE_SOURCE_COMMIT
SYSTEM_SHA256=$SYSTEM_SHA256
SYSTEM_BYTES=$SYSTEM_BYTES
TARGET_PARTITION=$TARGET_PARTITION
PREFLASH_BASELINE=$N1I_C1_FASTBOOT_BASELINE
PREFLASH_SYSTEM_A_BYTES=$N1I_C1_FASTBOOT_SYSTEM_A_BYTES
FLASH_ATTEMPT_COUNT=1
FASTBOOT_FLASH_RC=0
FLASH_COMMAND_RESULT=PASS
FLASH_LOG_SHA256=$FLASH_LOG_SHA256
TOOL_SOURCE_COMMIT=$TOOL_SOURCE_COMMIT
AUTOMATIC_FLASH_RETRY=NO
EOF_COMMAND
(
  cd "$COMMAND_JOURNAL" || exit 1
  sha256sum N1I_C1_FLASH_COMMAND_SUCCEEDED.env fastboot-flash-system-a.log > SHA256SUMS.txt
  sha256sum -c SHA256SUMS.txt >/dev/null
) || fail flash_command_journal_seal 73
verify_command_journal "$EVIDENCE_DIR" || fail flash_command_journal_verify 73

echo "N1I_C1_FLASH_COMMAND_JOURNAL=PASS"
echo "N1I_C1_FLASH_COMMAND_SUCCEEDED=YES"
echo "N1I_C1_DO_NOT_REFLASH=YES"

echo "===== N1I-C1 POSTWRITE FASTBOOTD STATE ====="
"$FASTBOOT_BIN" -s "$SERIAL" getvar all </dev/null \
  > "$WRITE_PROOF/fastboot-getvar-all-post.txt" 2>&1
GETVAR_POST_RC=$?
[[ "$GETVAR_POST_RC" -eq 0 ]] || {
  echo "N1I_C1_FLASH_WRITE_COMPLETED=YES"
  echo "N1I_C1_DO_NOT_REFLASH=YES"
  fail "post_getvar_all_rc=$GETVAR_POST_RC" 74
}

python3 "$FASTBOOT_QUAL" \
  --getvar-all "$WRITE_PROOF/fastboot-getvar-all-post.txt" \
  --phase post \
  --out-env "$WRITE_PROOF/post-state.env"
POST_RC=$?
[[ "$POST_RC" -eq 0 ]] || {
  echo "N1I_C1_FLASH_WRITE_COMPLETED=YES"
  echo "N1I_C1_DO_NOT_REFLASH=YES"
  fail "fastboot_postflight_rc=$POST_RC" 74
}

cat > "$WRITE_PROOF/N1I_C1_WRITE_COMPLETED.env" <<EOF_WRITE
N1I_C1_WRITE_PROOF_VERSION=1
DEVICE_SERIAL_SHA256=$SERIAL_SHA256
ARTIFACT_ROLE=$ARTIFACT_ROLE
IMAGE_SOURCE_COMMIT=$IMAGE_SOURCE_COMMIT
SYSTEM_SHA256=$SYSTEM_SHA256
SYSTEM_BYTES=$SYSTEM_BYTES
TARGET_PARTITION=$TARGET_PARTITION
PREFLASH_BASELINE=$N1I_C1_FASTBOOT_BASELINE
PREFLASH_SYSTEM_A_BYTES=$N1I_C1_FASTBOOT_SYSTEM_A_BYTES
FLASH_ATTEMPT_COUNT=1
FLASH_RESULT=PASS
POSTFLASH_SYSTEM_A_BYTES=$SYSTEM_BYTES
POSTFLASH_MODE=FASTBOOTD
POSTFLASH_SLOT=a
TOOL_SOURCE_COMMIT=$TOOL_SOURCE_COMMIT
EOF_WRITE

(
  cd "$WRITE_PROOF" || exit 1
  sha256sum \
    N1I_C1_WRITE_COMPLETED.env \
    fastboot-flash-system-a.log \
    fastboot-getvar-all-pre.txt \
    fastboot-getvar-all-post.txt \
    pre-state.env \
    post-state.env \
    > SHA256SUMS.txt
  sha256sum -c SHA256SUMS.txt >/dev/null
) || fail write_proof_seal 74

echo "N1I_C1_FLASH_WRITE_COMPLETED=YES"
echo "N1I_C1_FLASH_ATTEMPT_COUNT=1"
echo "N1I_C1_FLASH_WRITE_PROOF=PASS"
echo "N1I_C1_DO_NOT_REFLASH_IF_POSTBOOT_OBSERVATION_FAILS=YES"

"$FASTBOOT_BIN" -s "$SERIAL" reboot </dev/null
REBOOT_RC=$?
if [[ "$REBOOT_RC" -ne 0 ]]; then
  echo "N1I_C1_POSTFLASH_REBOOT=FAIL rc=$REBOOT_RC"
  echo "N1I_C1_FLASH_WRITE_COMPLETED=YES"
  echo "N1I_C1_DO_NOT_REFLASH=YES"
  echo "N1I_C1_FLASH_EVIDENCE_DIR=$EVIDENCE_DIR"
  exit 75
fi
echo "N1I_C1_POSTFLASH_REBOOT=PASS_SENT_ONCE"

n1i_c1_wait_android_boot "$POSTBOOT_TIMEOUT"
BOOT_RC=$?
if [[ "$BOOT_RC" -ne 0 ]]; then
  echo "N1I_C1_POSTBOOT_OBSERVATION=FAIL rc=$BOOT_RC"
  echo "N1I_C1_FLASH_WRITE_COMPLETED=YES"
  echo "N1I_C1_DO_NOT_REFLASH=YES"
  echo "N1I_C1_RECEIPT_STATUS=PENDING_READ_ONLY_FINALIZATION"
  echo "N1I_C1_FLASH_EVIDENCE_DIR=$EVIDENCE_DIR"
  exit 76
fi

verify_android_identity || {
  echo "N1I_C1_POSTBOOT_IDENTITY=FAIL"
  echo "N1I_C1_FLASH_WRITE_COMPLETED=YES"
  echo "N1I_C1_DO_NOT_REFLASH=YES"
  echo "N1I_C1_RECEIPT_STATUS=PENDING_OWNER_REVIEW"
  echo "N1I_C1_FLASH_EVIDENCE_DIR=$EVIDENCE_DIR"
  exit 77
}

echo "N1I_C1_POSTBOOT_ANDROID=PASS"
finalize_receipt "$EVIDENCE_DIR"

echo "N1I_C1_FLASH_WRITE=PASS_SYSTEM_A_ONCE"
echo "N1I_C1_AUTOMATIC_FLASH_RETRY=NO"
echo "N1I_C1_FACTORY_RESET=NOT_PERFORMED"
echo "N1I_C1_GOVERNED_FLASH=PASS"
echo "N1I_C1_FLASH_EVIDENCE_DIR=$EVIDENCE_DIR"
