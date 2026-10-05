#!/usr/bin/env bash
# Host-only end-to-end regression for the C1 recovery collector.
# Uses mocked adb/fastboot only; never contacts a real device.
set -u
set -o pipefail
umask 077

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
COLLECTOR="$ROOT/build/titan2/collect-n1i-c1-recovery-failure.sh"

FAILS=0
pass() { echo "N1I_C1_RECOVERY_TEST_$1=PASS"; }
fail() {
  echo "N1I_C1_RECOVERY_TEST_$1=FAIL ${2:-}" >&2
  FAILS=$((FAILS + 1))
}

bash -n "$COLLECTOR" "$0" || {
  fail SYNTAX
  exit 1
}
pass SYNTAX

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

SERIAL='TITAN20000006073'
SERIAL_SHA='bcfdee61b23e3cb002919c27a055389ffe37e284bf5150dfc1d0bbbd7564090a'
FLASH_EVIDENCE="$TMP/flash-evidence"
MOCK_LOG="$TMP/mock.log"
STATE_FILE="$TMP/state"
ADB="$TMP/adb"
FASTBOOT="$TMP/fastboot"

mkdir -p   "$FLASH_EVIDENCE/write-proof"   "$FLASH_EVIDENCE/attempt-journal"   "$FLASH_EVIDENCE/command-journal"

cat > "$FLASH_EVIDENCE/write-proof/N1I_C1_WRITE_COMPLETED.env" <<EOF_WRITE
N1I_C1_WRITE_PROOF_VERSION=1
DEVICE_SERIAL_SHA256=$SERIAL_SHA
ARTIFACT_ROLE=N1I_C1_ANDROID16_CELLULAR_ISOLATION
IMAGE_SOURCE_COMMIT=a745c7daa08267d851f45785a5bb7ff762ed4604
SYSTEM_SHA256=137bc8771c817c0afb3122d9f03e7a94575e03bcccc643b56235edd1075f2160
SYSTEM_BYTES=3210661888
TARGET_PARTITION=system_a
PREFLASH_BASELINE=STOCK_V010014
PREFLASH_SYSTEM_A_BYTES=757059584
FLASH_ATTEMPT_COUNT=1
FLASH_RESULT=PASS
POSTFLASH_SYSTEM_A_BYTES=3210661888
POSTFLASH_MODE=FASTBOOTD
POSTFLASH_SLOT=a
TOOL_SOURCE_COMMIT=347a1e6e56d556f994cea5dfe826024e6edb50b1
EOF_WRITE

printf '%s\n' mock > "$FLASH_EVIDENCE/attempt-journal/mock.txt"
printf '%s\n' mock > "$FLASH_EVIDENCE/command-journal/mock.txt"

(
  cd "$FLASH_EVIDENCE/write-proof" || exit 1
  sha256sum N1I_C1_WRITE_COMPLETED.env > SHA256SUMS.txt
)
(
  cd "$FLASH_EVIDENCE/attempt-journal" || exit 1
  sha256sum mock.txt > SHA256SUMS.txt
)
(
  cd "$FLASH_EVIDENCE/command-journal" || exit 1
  sha256sum mock.txt > SHA256SUMS.txt
)

cat > "$ADB" <<'EOF_ADB'
#!/usr/bin/env bash
echo "adb $*" >> "$MOCK_LOG"

if [[ "$1" == devices && "$2" == -l ]]; then
  echo "List of devices attached"
  case "$(cat "$STATE_FILE")" in
    recovery|shell-fail)
      echo "$MOCK_SERIAL recovery usb:1-4 product:Titan_2 model:Titan_2 device:Titan_2 transport_id:1"
      ;;
    offline)
      echo "$MOCK_SERIAL offline usb:1-4 product:Titan_2 model:Titan_2 device:Titan_2 transport_id:1"
      ;;
  esac
  exit 0
fi

if [[ "$1" == -s && "$2" == "$MOCK_SERIAL" && "$3" == pull ]]; then
  remote="$4"
  dest="$5"
  if [[ "$(cat "$STATE_FILE")" != shell-fail ]]; then
    exit 9
  fi
  case "$remote" in
    /cache/recovery/last_log)
      printf '%s\n' 'RecoverySystem: boot failure mock' > "$dest"
      exit 0
      ;;
    /data/system/uiderrors.txt)
      printf '%s\n' 'RescueParty: system_server crash loop mock' > "$dest"
      exit 0
      ;;
    /data/system/packages.xml)
      printf '%s\n' '<packages />' > "$dest"
      exit 0
      ;;
    /sys/fs/pstore)
      mkdir -p "$dest"
      printf '%s\n' 'zygote fatal mock' > "$dest/console-ramoops-0"
      exit 0
      ;;
    *)
      exit 1
      ;;
  esac
fi

if [[ "$1" == -s && "$2" == "$MOCK_SERIAL" && "$3" == shell ]]; then
  shift 3

  if [[ "$(cat "$STATE_FILE")" == shell-fail ]]; then
    exit 7
  fi

  case "$1" in
    getprop)
      if [[ "$#" -eq 2 && "$2" == ro.bootmode ]]; then
        echo recovery
      else
        cat <<'EOF_PROP'
[ro.bootmode]: [recovery]
[ro.boot.bootreason]: [reboot,recovery]
[ro.boot.slot_suffix]: [_a]
[ro.boot.verifiedbootstate]: [orange]
[ro.build.version.release]: [16]
[ro.build.version.sdk]: [36]
[ro.vendor.build.fingerprint]: [Unihertz/Titan_2/Titan_2:14/mock:user/release-keys]
[sys.boot_completed]: [0]
EOF_PROP
      fi
      ;;
    cat)
      case "${2:-}" in
        /proc/cmdline) echo "androidboot.slot_suffix=_a" ;;
        /proc/bootconfig) echo "androidboot.bootreason = \"reboot,recovery\"" ;;
        /proc/mounts) echo "tmpfs / tmpfs ro 0 0" ;;
        /cache/recovery/last_log) echo "recovery last log mock" ;;
        /cache/recovery/log) echo "recovery log mock" ;;
        /tmp/recovery.log) echo "recovery tmp log mock" ;;
        /sys/fs/pstore/*) echo "mock pstore" ;;
      esac
      ;;
    df)
      echo "Filesystem Size Used Avail Use% Mounted on"
      ;;
    dmesg)
      echo "mock recovery dmesg"
      ;;
    logcat)
      echo "mock recovery logcat"
      ;;
    ls)
      if [[ "${*: -1}" == /sys/fs/pstore ]]; then
        echo console-ramoops-0
      elif [[ "${*: -1}" == /data/system/dropbox ]]; then
        echo SYSTEM_BOOT@mock.txt
      else
        echo "mock ls"
      fi
      ;;
    tail)
      echo "mock dropbox"
      ;;
  esac
  exit 0
fi

exit 9
EOF_ADB

cat > "$FASTBOOT" <<'EOF_FASTBOOT'
#!/usr/bin/env bash
echo "fastboot $*" >> "$MOCK_LOG"
if [[ "$1" == devices ]]; then
  exit 0
fi
exit 9
EOF_FASTBOOT

chmod +x "$ADB" "$FASTBOOT"
export MOCK_LOG STATE_FILE MOCK_SERIAL="$SERIAL"

run_case() {
  local name="$1" state="$2" expected="$3"
  local out="$TMP/$name.out"
  echo "$state" > "$STATE_FILE"
  : > "$MOCK_LOG"
  SABLE_EVIDENCE_ROOT="$TMP/evidence-$name"   SABLE_ADB="$ADB"   SABLE_FASTBOOT="$FASTBOOT"     bash "$COLLECTOR"       --authorize-device-contact YES_READ_ONLY_RECOVERY       --serial "$SERIAL"       --flash-evidence-dir "$FLASH_EVIDENCE"       > "$out" 2>&1
  local rc=$?

  if [[ "$rc" -eq 0 ]] && grep -Fq "$expected" "$out"; then
    pass "$name"
  else
    fail "$name" "rc=$rc expected=$expected"
    cat "$out" >&2
  fi

  if grep -Eq 'adb .* (reboot|push)|fastboot .* (flash|erase|format|reboot|set_active|resize-logical-partition)| shell mount .*-(o|w)| wipe|factory.?reset' "$MOCK_LOG"; then
    fail "${name}_NO_MUTATION" "forbidden command observed"
    cat "$MOCK_LOG" >&2
  else
    pass "${name}_NO_MUTATION"
  fi
}

run_case RECOVERY_SHELL recovery   'N1I_C1_RECOVERY_CAPTURE=PASS'

if ! grep -Fq 'N1I_C1_RECOVERY_SHELL_CAPTURE=AVAILABLE state=recovery'   "$TMP/RECOVERY_SHELL.out"; then
  fail RECOVERY_STATE_SHELL_PROBED
else
  pass RECOVERY_STATE_SHELL_PROBED
fi

if ! grep -Fq 'adb -s TITAN20000006073 shell getprop ro.bootmode' "$MOCK_LOG"; then
  fail RECOVERY_STATE_SHELL_PROBE_COMMAND
else
  pass RECOVERY_STATE_SHELL_PROBE_COMMAND
fi

run_case SHELL_FAIL shell-fail   'N1I_C1_RECOVERY_CAPTURE=PASS_SYNC_FALLBACK'

SHELL_COUNT="$(grep -Fc 'adb -s TITAN20000006073 shell' "$MOCK_LOG" || true)"
if [[ "$SHELL_COUNT" == 1 ]]; then
  pass SHELL_FAIL_STOPS_AFTER_PROBE
else
  fail SHELL_FAIL_STOPS_AFTER_PROBE "shell_count=$SHELL_COUNT"
fi

PULL_COUNT="$(grep -Fc 'adb -s TITAN20000006073 pull' "$MOCK_LOG" || true)"
if [[ "$PULL_COUNT" == 8 ]]; then
  pass SHELL_FAIL_SYNC_FALLBACK_COUNT
else
  fail SHELL_FAIL_SYNC_FALLBACK_COUNT "pull_count=$PULL_COUNT"
fi

for remote in \
  /cache/recovery/last_log \
  /data/system/uiderrors.txt \
  /data/system/packages.xml \
  /sys/fs/pstore
do
  if grep -Fq "adb -s TITAN20000006073 pull $remote " "$MOCK_LOG"; then
    pass "SHELL_FAIL_PULL_$(basename "$remote" | tr '.-' '__')"
  else
    fail SHELL_FAIL_SYNC_FALLBACK "missing_pull=$remote"
  fi
done

if grep -Fq 'N1I_C1_RECOVERY_SYNC_PULL_SUCCESS_COUNT=4' "$TMP/SHELL_FAIL.out"; then
  pass SHELL_FAIL_SYNC_SUCCESS_COUNT
else
  fail SHELL_FAIL_SYNC_SUCCESS_COUNT "expected_count=4"
fi

if grep -Fq 'N1I_C1_RECOVERY_USERDATA_SYSTEM_READABLE=YES' "$TMP/SHELL_FAIL.out"; then
  pass SHELL_FAIL_USERDATA_SYSTEM_READABLE
else
  fail SHELL_FAIL_USERDATA_SYSTEM_READABLE "packages.xml pull did not classify readable"
fi

run_case OFFLINE offline   'N1I_C1_RECOVERY_CAPTURE=PASS_TRANSPORT_ONLY'

SHELL_COUNT="$(grep -Fc 'adb -s TITAN20000006073 shell' "$MOCK_LOG" || true)"
if [[ "$SHELL_COUNT" == 0 ]]; then
  pass OFFLINE_NO_SHELL
else
  fail OFFLINE_NO_SHELL "shell_count=$SHELL_COUNT"
fi

if [[ "$FAILS" -eq 0 ]]; then
  echo "N1I_C1_RECOVERY_COLLECTOR_SELFTEST=PASS"
  exit 0
fi

echo "N1I_C1_RECOVERY_COLLECTOR_SELFTEST=FAIL count=$FAILS" >&2
exit 1
