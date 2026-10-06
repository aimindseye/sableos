#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FLASH="$ROOT/build/titan2/flash-n1i-c2-cellular-mvp.sh"
QUAL="$ROOT/build/titan2/qualify-n1i-c2-fastboot-state.py"
TEST="$ROOT/tests/titan2/n1i-c2/test-flash-executor.sh"
MODE="$ROOT/build/titan2/titan2-flash-mode.sh"

fail() {
  echo "N1I_C2_FLASH_EXECUTOR_CONTRACT=FAIL reason=$1" >&2
  exit 1
}

for path in "$FLASH" "$QUAL" "$TEST" "$MODE"; do
  [[ -f "$path" ]] || fail "required_file_missing=$path"
done

bash -n "$FLASH" "$TEST" "$MODE" || fail shell_syntax
python3 - "$QUAL" <<'PY_SYNTAX' || fail python_syntax
import pathlib
import sys
path = pathlib.Path(sys.argv[1])
compile(path.read_text(encoding="utf-8"), str(path), "exec")
PY_SYNTAX
python3 "$QUAL" --selftest >/dev/null || fail qualifier_selftest
bash "$TEST" >/dev/null || fail executor_test

marker() {
  local label="$1" file="$2" value="$3"
  grep -Fq -- "$value" "$file" || fail "missing_marker=$label:$value"
  echo "N1I_C2_FLASH_EXECUTOR_CONTRACT_$label=PASS"
}

marker SOURCE "$FLASH" 'BUILD_SOURCE="27d671b004f5ae7394f147018fc4fffdf4d78498"'
marker SHA "$FLASH" 'SYSTEM_SHA256="630db78ef3f888b961640d17c5237495e673a953d67f1d52fabe056cbb76bb50"'
marker BYTES "$FLASH" 'SYSTEM_BYTES="3218440192"'
marker TARGET "$FLASH" 'TARGET_PARTITION="system_a"'
marker SLOT "$FLASH" 'EXPECTED_SLOT="a"'
marker ADB_BINDING "$FLASH" 'EXPECTED_ADB_BINDING_SHA256="bcfdee61b23e3cb002919c27a055389ffe37e284bf5150dfc1d0bbbd7564090a"'
marker FASTBOOT_BINDING "$FLASH" 'EXPECTED_FASTBOOT_BINDING_SHA256="bcfdee61b23e3cb002919c27a055389ffe37e284bf5150dfc1d0bbbd7564090a"'
marker ANDROID_PRODUCT "$FLASH" 'EXPECTED_ANDROID_PRODUCT="Titan_2"'
marker BOOTLOADER_PRODUCT "$FLASH" 'EXPECTED_BOOTLOADER_PRODUCT="g71v78c2k_dfl_tee"'
marker FASTBOOTD_PRODUCT "$FLASH" 'EXPECTED_FASTBOOTD_PRODUCT="Titan_2"'
marker AUTH_CONTACT "$FLASH" 'YES_C2_MODE_AWARE_FASTBOOTD_AND_FLASH_SYSTEM_A_ONCE'
marker AUTH_FLASH "$FLASH" 'YES_C2_SYSTEM_A_ONCE'
marker ADB_ENTRY "$FLASH" 'N1I_C2_FLASH_ENTRY_MODE=PASS_ANDROID_ADB'
marker BOOTLOADER_ENTRY "$FLASH" 'N1I_C2_FLASH_ENTRY_MODE=PASS_BOOTLOADER_FASTBOOT'
marker FASTBOOTD_ENTRY "$FLASH" 'N1I_C2_FLASH_ENTRY_MODE=PASS_FASTBOOTD_DIRECT'
marker FASTBOOTD_NO_TRANSITION "$FLASH" 'N1I_C2_FLASH_MODE_TRANSITION=NONE_ALREADY_FASTBOOTD'
marker RECOVERY_BLOCK "$FLASH" 'recovery_entry_blocked_for_write'
marker SMART_MODE "$FLASH" 'titan2_ensure_fastbootd_mode'
marker FASTBOOT_MIN_VERSION "$FLASH" 'FASTBOOT_MIN_VERSION=35.0.1'
marker POSTBOOT_IDENTITY "$FLASH" 'POSTBOOT_RESULT=ANDROID_IDENTITY_MISMATCH'
marker PREWRITE_PHASE "$FLASH" '--phase pre'
marker POSTWRITE_PHASE "$FLASH" '--phase post'
marker PREWRITE_HASH "$FLASH" 'N1I_C2_PREWRITE_ARTIFACT_HASH=PASS'
marker DUPLICATE_GUARD "$FLASH" 'N1I_C2_FLASH_DUPLICATE_WRITE_GUARD=REFUSE_PRIOR_ATTEMPT'
marker CORRUPT_PRIOR_GUARD "$FLASH" 'N1I_C2_FLASH_DUPLICATE_WRITE_GUARD=REFUSE_CORRUPT_PRIOR_EVIDENCE'
marker JOURNAL "$FLASH" 'N1I_C2_FLASH_ATTEMPT_ARMED=YES'
marker NO_RETRY "$FLASH" 'AUTOMATIC_FLASH_RETRY=NO'
marker NO_RESET "$FLASH" 'FACTORY_RESET_AUTHORIZED=NO'
marker NO_USERDATA "$FLASH" 'USERDATA_ERASE_AUTHORIZED=NO'
marker NO_SLOT "$FLASH" 'SLOT_CHANGE_AUTHORIZED=NO'
marker NO_AVB "$FLASH" 'AVB_MUTATION_AUTHORIZED=NO'
marker NO_BOOT_CHAIN "$FLASH" 'BOOT_CHAIN_MUTATION_AUTHORIZED=NO'
marker NO_COW_DELETE "$FLASH" 'COW_DELETION_AUTHORIZED=NO'
marker POSTBOOT_NO_REFLASH "$FLASH" 'N1I_C2_DO_NOT_REFLASH_IF_POSTBOOT_OBSERVATION_FAILS=YES'
marker QUAL_TARGET "$QUAL" 'TARGET_BYTES = 3_218_440_192'
marker QUAL_SUPER "$QUAL" 'SUPER_BYTES = 9_663_676_416'
marker QUAL_MIN_HEADROOM "$QUAL" 'MIN_REMAINING_SUPER_HEADROOM_BYTES = 536_870_912'
marker QUAL_GROUP_CEILING "$QUAL" 'REVIEWED_GROUP_SAFE_SYSTEM_TARGET_CEILING_BYTES = 3_263_168_512'
marker QUAL_LIVE_BASELINE "$QUAL" 'baseline = "LIVE_CURRENT_SYSTEM_A"'
marker QUAL_COW_FAIL "$QUAL" 'N1I_C2_FASTBOOT_STATE=FAIL_ACTIVE_COWS='
marker SAME_SIZE_TEST "$TEST" 'SAME_SIZE_NOT_TREATED_AS_CONTENT_IDENTITY'

FLASH_LINE='"$SABLE_FASTBOOT" -s "$SERIAL" flash system_a "$SYSTEM_IMG"'
[[ "$(grep -Fc -- "$FLASH_LINE" "$FLASH")" == 1 ]] ||
  fail single_flash_call_count
echo "N1I_C2_FLASH_EXECUTOR_CONTRACT_SINGLE_FLASH_CALL=PASS"

HASH_LINE='sha256sum "$SYSTEM_IMG"'
[[ "$(grep -Fc -- "$HASH_LINE" "$FLASH")" == 1 ]] ||
  fail single_prewrite_image_hash_count
echo "N1I_C2_FLASH_EXECUTOR_CONTRACT_SINGLE_PREWRITE_IMAGE_HASH=PASS"

REBOOT_LINE='"$SABLE_FASTBOOT" -s "$SERIAL" reboot </dev/null'
[[ "$(grep -Fc -- "$REBOOT_LINE" "$FLASH")" == 1 ]] ||
  fail postflash_reboot_count
echo "N1I_C2_FLASH_EXECUTOR_CONTRACT_ONE_POSTFLASH_REBOOT=PASS"

if grep -Eq 'set[[:space:]]+[+-]e|set[[:space:]]+-[^[:space:]]*e|set[[:space:]]+-o[[:space:]]+pipefail' "$FLASH"; then
  fail forbidden_shell_error_mode
fi
echo "N1I_C2_FLASH_EXECUTOR_CONTRACT_EXPLICIT_RC=PASS"

for forbidden in \
  'fastboot boot' \
  ' erase ' \
  ' format ' \
  ' set_active ' \
  ' delete-logical-partition ' \
  ' create-logical-partition ' \
  ' resize-logical-partition ' \
  ' flash boot ' \
  ' flash vbmeta ' \
  ' flash super ' \
  ' -w '
do
  if grep -Fq -- "$forbidden" "$FLASH"; then
    fail "forbidden_mutation=$forbidden"
  fi
done
echo "N1I_C2_FLASH_EXECUTOR_CONTRACT_FORBIDDEN_MUTATIONS_ABSENT=PASS"

echo "N1I_C2_FLASH_EXECUTOR_CONTRACT=PASS"
