#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
FLASH="$ROOT/build/titan2/flash-n1i-c2-cellular-mvp.sh"
QUAL="$ROOT/build/titan2/qualify-n1i-c2-fastboot-state.py"
MODE="$ROOT/build/titan2/titan2-flash-mode.sh"

FAILS=0

pass() {
  echo "N1I_C2_FLASH_TEST_$1=PASS"
}

fail() {
  echo "N1I_C2_FLASH_TEST_$1=FAIL ${2:-}" >&2
  FAILS=$((FAILS + 1))
}

for path in "$FLASH" "$QUAL" "$MODE"; do
  [[ -f "$path" ]] || fail REQUIRED_FILE "missing=$path"
done

bash -n "$FLASH" "$MODE" || fail SHELL_SYNTAX
python3 - "$QUAL" <<'PY_SYNTAX' || fail PYTHON_SYNTAX
import pathlib
import sys
path = pathlib.Path(sys.argv[1])
compile(path.read_text(encoding="utf-8"), str(path), "exec")
PY_SYNTAX
python3 "$QUAL" --selftest >/dev/null || fail QUALIFIER_SELFTEST

for token in \
  'BUILD_SOURCE="27d671b004f5ae7394f147018fc4fffdf4d78498"' \
  'SYSTEM_SHA256="630db78ef3f888b961640d17c5237495e673a953d67f1d52fabe056cbb76bb50"' \
  'SYSTEM_BYTES="3218440192"' \
  'TARGET_PARTITION="system_a"' \
  'EXPECTED_SLOT="a"' \
  'EXPECTED_ADB_BINDING_SHA256="bcfdee61b23e3cb002919c27a055389ffe37e284bf5150dfc1d0bbbd7564090a"' \
  'EXPECTED_FASTBOOT_BINDING_SHA256="bcfdee61b23e3cb002919c27a055389ffe37e284bf5150dfc1d0bbbd7564090a"' \
  'YES_C2_MODE_AWARE_FASTBOOTD_AND_FLASH_SYSTEM_A_ONCE' \
  'YES_C2_SYSTEM_A_ONCE' \
  'titan2_ensure_fastbootd_mode' \
  'N1I_C2_FLASH_ENTRY_MODE=PASS_ANDROID_ADB' \
  'N1I_C2_FLASH_ENTRY_MODE=PASS_BOOTLOADER_FASTBOOT' \
  'N1I_C2_FLASH_ENTRY_MODE=PASS_FASTBOOTD_DIRECT' \
  'N1I_C2_FLASH_MODE_TRANSITION=NONE_ALREADY_FASTBOOTD' \
  'recovery_entry_blocked_for_write' \
  'FASTBOOT_MIN_VERSION=35.0.1' \
  'POSTBOOT_RESULT=ANDROID_IDENTITY_MISMATCH' \
  'AUTOMATIC_FLASH_RETRY=NO' \
  'N1I_C2_FLASH_DUPLICATE_WRITE_GUARD=REFUSE_PRIOR_ATTEMPT' \
  'N1I_C2_FLASH_DUPLICATE_WRITE_GUARD=REFUSE_CORRUPT_PRIOR_EVIDENCE' \
  'N1I_C2_DO_NOT_REFLASH_AFTER_THIS_POINT_WITHOUT_OWNER_REVIEW=YES' \
  'N1I_C2_DO_NOT_REFLASH_IF_POSTBOOT_OBSERVATION_FAILS=YES' \
  '--phase pre' \
  '--phase post'
do
  grep -Fq -- "$token" "$FLASH" ||
    fail REQUIRED_MARKER "missing=$token"
done

FLASH_LINE='"$SABLE_FASTBOOT" -s "$SERIAL" flash system_a "$SYSTEM_IMG"'
FLASH_COUNT="$(grep -Fc -- "$FLASH_LINE" "$FLASH" || true)"
[[ "$FLASH_COUNT" == 1 ]] ||
  fail SINGLE_FLASH_CALL "count=$FLASH_COUNT"
[[ "$FLASH_COUNT" == 1 ]] && pass SINGLE_FLASH_CALL

FINAL_REBOOT_LINE='"$SABLE_FASTBOOT" -s "$SERIAL" reboot </dev/null'
FINAL_REBOOT_COUNT="$(grep -Fc -- "$FINAL_REBOOT_LINE" "$FLASH" || true)"
[[ "$FINAL_REBOOT_COUNT" == 1 ]] ||
  fail ONE_POSTFLASH_REBOOT "count=$FINAL_REBOOT_COUNT"
[[ "$FINAL_REBOOT_COUNT" == 1 ]] && pass ONE_POSTFLASH_REBOOT

IMAGE_HASH_LINE='sha256sum "$SYSTEM_IMG"'
IMAGE_HASH_COUNT="$(grep -Fc -- "$IMAGE_HASH_LINE" "$FLASH" || true)"
[[ "$IMAGE_HASH_COUNT" == 1 ]] ||
  fail SINGLE_PREWRITE_IMAGE_HASH "count=$IMAGE_HASH_COUNT"
[[ "$IMAGE_HASH_COUNT" == 1 ]] && pass SINGLE_PREWRITE_IMAGE_HASH

if grep -Eq 'set[[:space:]]+[+-]e|set[[:space:]]+-[^[:space:]]*e|set[[:space:]]+-o[[:space:]]+pipefail' "$FLASH"; then
  fail EXPLICIT_RC "errexit_or_pipefail_found"
else
  pass EXPLICIT_RC
fi

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
    fail FORBIDDEN_MUTATION "token=$forbidden"
  fi
done
[[ "$FAILS" -eq 0 ]] && pass FORBIDDEN_MUTATION

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

write_getvar() {
  local out="$1" system_bytes="$2" slot="${3:-a}" cow_bytes="${4:-0}"
  cat > "$out" <<EOF_GETVAR
(bootloader) product: Titan_2
(bootloader) current-slot: $slot
(bootloader) is-userspace: yes
(bootloader) unlocked: yes
(bootloader) snapshot-update-status: none
(bootloader) is-logical:system_a: yes
(bootloader) partition-size:system_a: $(printf '0x%x' "$system_bytes")
(bootloader) is-logical:system_ext_a: yes
(bootloader) partition-size:system_ext_a: 0x23c34600
(bootloader) is-logical:product_a: yes
(bootloader) partition-size:product_a: 0x1dcd6500
(bootloader) is-logical:vendor_a: yes
(bootloader) partition-size:vendor_a: 0x53724e00
(bootloader) is-logical:system_dlkm_a: yes
(bootloader) partition-size:system_dlkm_a: 0x03d09000
(bootloader) is-logical:vendor_dlkm_a: yes
(bootloader) partition-size:vendor_dlkm_a: 0x07a12000
(bootloader) is-logical:odm_dlkm_a: yes
(bootloader) partition-size:odm_dlkm_a: 0x03d09000
(bootloader) partition-size:super: 0x240000000
EOF_GETVAR
  if [[ "$cow_bytes" -gt 0 ]]; then
    cat >> "$out" <<EOF_COW
(bootloader) is-logical:system_a-cow: yes
(bootloader) partition-size:system_a-cow: $(printf '0x%x' "$cow_bytes")
EOF_COW
  fi
}

PRE="$TMP/pre.txt"
PRE_ENV="$TMP/pre.env"
write_getvar "$PRE" 3210661888
python3 "$QUAL" --getvar-all "$PRE" --phase pre --out-env "$PRE_ENV" >/dev/null
PRE_RC=$?
if [[ "$PRE_RC" -eq 0 ]] &&
   grep -Fxq 'N1I_C2_FASTBOOT_STATE=PASS' "$PRE_ENV" &&
   grep -Fxq 'N1I_C2_FASTBOOT_BASELINE=LIVE_CURRENT_SYSTEM_A' "$PRE_ENV"; then
  pass LIVE_CURRENT_SIZE_ACCEPTED
else
  fail LIVE_CURRENT_SIZE_ACCEPTED "rc=$PRE_RC"
fi

POST="$TMP/post.txt"
POST_ENV="$TMP/post.env"
write_getvar "$POST" 3218440192
python3 "$QUAL" --getvar-all "$POST" --phase post --out-env "$POST_ENV" >/dev/null
POST_RC=$?
if [[ "$POST_RC" -eq 0 ]] &&
   grep -Fxq 'N1I_C2_FASTBOOT_STATE=PASS' "$POST_ENV" &&
   grep -Fxq 'N1I_C2_FASTBOOT_SYSTEM_A_BYTES=3218440192' "$POST_ENV"; then
  pass POST_TARGET_SIZE
else
  fail POST_TARGET_SIZE "rc=$POST_RC"
fi

python3 "$QUAL" --getvar-all "$POST" --phase pre --out-env "$TMP/same-size.env" >/dev/null 2>&1
SAME_SIZE_RC=$?
if [[ "$SAME_SIZE_RC" -eq 0 ]] &&
   grep -Fxq 'N1I_C2_FASTBOOT_STATE=PASS' "$TMP/same-size.env"; then
  pass SAME_SIZE_NOT_TREATED_AS_CONTENT_IDENTITY
else
  fail SAME_SIZE_NOT_TREATED_AS_CONTENT_IDENTITY "rc=$SAME_SIZE_RC"
fi

BAD_COW="$TMP/cow.txt"
write_getvar "$BAD_COW" 3210661888 a 1048576
python3 "$QUAL" --getvar-all "$BAD_COW" --phase pre --out-env "$TMP/cow.env" >/dev/null 2>&1
COW_RC=$?
if [[ "$COW_RC" -ne 0 ]]; then
  pass ACTIVE_COW_REFUSED
else
  fail ACTIVE_COW_REFUSED "rc=$COW_RC"
fi

BAD_SLOT="$TMP/slot.txt"
write_getvar "$BAD_SLOT" 3210661888 b
python3 "$QUAL" --getvar-all "$BAD_SLOT" --phase pre --out-env "$TMP/slot.env" >/dev/null 2>&1
SLOT_RC=$?
if [[ "$SLOT_RC" -ne 0 ]]; then
  pass WRONG_SLOT_REFUSED
else
  fail WRONG_SLOT_REFUSED "rc=$SLOT_RC"
fi

if [[ "$FAILS" -eq 0 ]]; then
  echo "N1I_C2_FLASH_EXECUTOR_TEST=PASS"
  exit 0
fi

echo "N1I_C2_FLASH_EXECUTOR_TEST=FAIL count=$FAILS" >&2
exit 1
