#!/usr/bin/env bash
# Read-only recovery evidence collector for N1I-C1 postwrite boot failure.
# Never reboots, mounts, flashes, erases, formats, remounts, or changes slots.
set -u
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/build/config/storage.env"
source "$ROOT/build/config/host-tools.env"

AUTH=""
SERIAL=""
FLASH_EVIDENCE_DIR=""
ADB_BIN="${SABLE_ADB:-adb}"
FASTBOOT_BIN="${SABLE_FASTBOOT:-fastboot}"

fail() {
  echo "N1I_C1_RECOVERY_CAPTURE=FAIL reason=$1" >&2
  exit "${2:-1}"
}

usage() {
  cat <<'EOF'
Usage:
  bash build/titan2/collect-n1i-c1-recovery-failure.sh \
    --authorize-device-contact YES_READ_ONLY_RECOVERY \
    --serial SERIAL \
    --flash-evidence-dir PATH
EOF
}

while (($#)); do
  case "$1" in
    --authorize-device-contact)
      [[ "$#" -ge 2 ]] || fail missing_authorization 64
      AUTH="$2"; shift 2 ;;
    --serial)
      [[ "$#" -ge 2 ]] || fail missing_serial 64
      SERIAL="$2"; shift 2 ;;
    --flash-evidence-dir)
      [[ "$#" -ge 2 ]] || fail missing_flash_evidence_dir 64
      FLASH_EVIDENCE_DIR="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      usage >&2
      fail "unknown_argument=$1" 64 ;;
  esac
done

[[ "$AUTH" == YES_READ_ONLY_RECOVERY ]] ||
  fail exact_readonly_authorization_required 64
[[ "$SERIAL" =~ ^[A-Za-z0-9._:-]{1,128}$ ]] || fail invalid_serial 64
[[ -d "$FLASH_EVIDENCE_DIR" ]] || fail flash_evidence_dir_missing 64

for bin_var in ADB_BIN FASTBOOT_BIN; do
  bin="${!bin_var}"
  if [[ "$bin" == */* ]]; then
    [[ -x "$bin" ]] || fail "tool_missing=$bin" 64
  else
    command -v "$bin" >/dev/null 2>&1 || fail "tool_missing=$bin" 64
    printf -v "$bin_var" '%s' "$(command -v "$bin")"
  fi
done

FLASH_EVIDENCE_DIR="$(cd "$FLASH_EVIDENCE_DIR" && pwd -P)"
WRITE_PROOF="$FLASH_EVIDENCE_DIR/write-proof"
ATTEMPT="$FLASH_EVIDENCE_DIR/attempt-journal"
COMMAND="$FLASH_EVIDENCE_DIR/command-journal"

for d in "$WRITE_PROOF" "$ATTEMPT" "$COMMAND"; do
  [[ -d "$d" && -f "$d/SHA256SUMS.txt" ]] || fail "sealed_dir_missing=$d" 65
  (
    cd "$d" || exit 1
    sha256sum -c SHA256SUMS.txt >/dev/null
  ) || fail "sealed_dir_invalid=$d" 65
done

WRITE_ENV="$WRITE_PROOF/N1I_C1_WRITE_COMPLETED.env"
[[ -f "$WRITE_ENV" ]] || fail write_completed_env_missing 65

expect_line() {
  local expected="$1"
  grep -Fxq "$expected" "$WRITE_ENV" || fail "write_binding_missing=$expected" 65
}

expect_line 'IMAGE_SOURCE_COMMIT=a745c7daa08267d851f45785a5bb7ff762ed4604'
expect_line 'SYSTEM_SHA256=137bc8771c817c0afb3122d9f03e7a94575e03bcccc643b56235edd1075f2160'
expect_line 'SYSTEM_BYTES=3210661888'
expect_line 'TARGET_PARTITION=system_a'
expect_line 'FLASH_ATTEMPT_COUNT=1'
expect_line 'FLASH_RESULT=PASS'
expect_line 'POSTFLASH_SYSTEM_A_BYTES=3210661888'
expect_line 'POSTFLASH_MODE=FASTBOOTD'
expect_line 'POSTFLASH_SLOT=a'

SERIAL_SHA256="$(printf '%s' "$SERIAL" | sha256sum | awk '{print $1}')"
grep -Fxq "DEVICE_SERIAL_SHA256=$SERIAL_SHA256" "$WRITE_ENV" ||
  fail serial_binding_mismatch 65

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="$SABLE_EVIDENCE_ROOT/titan2/n1i-c1-recovery-failure/${STAMP}-${SERIAL_SHA256:0:12}"
mkdir -p "$EVIDENCE_DIR" || fail evidence_dir_create 66
chmod 700 "$EVIDENCE_DIR" 2>/dev/null || true

echo "===== TITAN 2 N1I-C1 RECOVERY FAILURE CAPTURE ====="
echo "N1I_C1_RECOVERY_FLASH_EVIDENCE=$FLASH_EVIDENCE_DIR"
echo "N1I_C1_RECOVERY_WRITE_PROOF=PASS"
echo "N1I_C1_RECOVERY_DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY_RECOVERY"
echo "N1I_C1_RECOVERY_REBOOT_AUTHORIZED=NO"
echo "N1I_C1_RECOVERY_FLASH_AUTHORIZED=NO"
echo "N1I_C1_RECOVERY_MOUNT_MUTATION_AUTHORIZED=NO"
echo "N1I_C1_RECOVERY_EVIDENCE_DIR=$EVIDENCE_DIR"

"$ADB_BIN" devices -l > "$EVIDENCE_DIR/adb-devices.txt" 2>&1
ADB_LIST_RC=$?
"$FASTBOOT_BIN" devices > "$EVIDENCE_DIR/fastboot-devices.txt" 2>&1
FASTBOOT_LIST_RC=$?

ADB_COUNT="$(awk -v s="$SERIAL" 'NR>1 && $1==s {n++} END {print n+0}' "$EVIDENCE_DIR/adb-devices.txt")"
FASTBOOT_COUNT="$(awk -v s="$SERIAL" '$1==s {n++} END {print n+0}' "$EVIDENCE_DIR/fastboot-devices.txt")"
ADB_STATE="$(awk -v s="$SERIAL" 'NR>1 && $1==s {print $2; exit}' "$EVIDENCE_DIR/adb-devices.txt")"

echo "N1I_C1_RECOVERY_ADB_LIST_RC=$ADB_LIST_RC"
echo "N1I_C1_RECOVERY_FASTBOOT_LIST_RC=$FASTBOOT_LIST_RC"
echo "N1I_C1_RECOVERY_ADB_SERIAL_COUNT=$ADB_COUNT"
echo "N1I_C1_RECOVERY_FASTBOOT_SERIAL_COUNT=$FASTBOOT_COUNT"
echo "N1I_C1_RECOVERY_ADB_STATE=${ADB_STATE:-ABSENT}"

[[ "$ADB_COUNT" -le 1 && "$FASTBOOT_COUNT" -le 1 ]] ||
  fail transport_duplicate 67
[[ "$ADB_COUNT" -eq 1 && "$FASTBOOT_COUNT" -eq 0 ]] ||
  fail "expected_recovery_adb_only adb=$ADB_COUNT fastboot=$FASTBOOT_COUNT" 67

case "$ADB_STATE" in
  device|recovery)
    ;;
  *)
    (
      cd "$EVIDENCE_DIR" || exit 1
      sha256sum adb-devices.txt fastboot-devices.txt > SHA256SUMS.txt
    ) || fail evidence_seal 68
    echo "N1I_C1_RECOVERY_SHELL_CAPTURE=NOT_AVAILABLE state=${ADB_STATE:-ABSENT}"
    echo "N1I_C1_RECOVERY_CAPTURE=PASS_TRANSPORT_ONLY"
    exit 0
    ;;
esac

"$ADB_BIN" -s "$SERIAL" shell getprop ro.bootmode </dev/null \
  > "$EVIDENCE_DIR/shell-probe.txt" \
  2> "$EVIDENCE_DIR/shell-probe.stderr.txt"
SHELL_PROBE_RC=$?
printf '%s\n' "$SHELL_PROBE_RC" > "$EVIDENCE_DIR/shell-probe.rc"
echo "N1I_C1_RECOVERY_SHELL_PROBE_RC=$SHELL_PROBE_RC"

run_pull() {
  local name="$1"
  local remote="$2"
  local dest="$3"
  "$ADB_BIN" -s "$SERIAL" pull "$remote" "$dest" \
    > "$EVIDENCE_DIR/pull-$name.stdout.txt" \
    2> "$EVIDENCE_DIR/pull-$name.stderr.txt"
  local rc=$?
  printf '%s\n' "$rc" > "$EVIDENCE_DIR/pull-$name.rc"
  echo "N1I_C1_RECOVERY_PULL_ITEM=$name rc=$rc remote=$remote"
  return "$rc"
}

if [[ "$SHELL_PROBE_RC" -ne 0 ]]; then
  echo "N1I_C1_RECOVERY_SHELL_CAPTURE=NOT_AVAILABLE state=$ADB_STATE"
  echo "===== N1I-C1 RECOVERY SYNC FALLBACK ====="

  PULL_SUCCESS=0

  for spec in \
    'recovery-last-log|/cache/recovery/last_log|pull-recovery-last-log.txt' \
    'recovery-log|/cache/recovery/log|pull-recovery-log.txt' \
    'recovery-tmp-log|/tmp/recovery.log|pull-recovery-tmp-log.txt' \
    'uiderrors|/data/system/uiderrors.txt|pull-uiderrors.txt' \
    'packages-xml|/data/system/packages.xml|pull-packages.xml' \
    'proc-cmdline|/proc/cmdline|pull-proc-cmdline.txt' \
    'proc-bootconfig|/proc/bootconfig|pull-proc-bootconfig.txt'
  do
    IFS='|' read -r name remote local_name <<<"$spec"
    if run_pull "$name" "$remote" "$EVIDENCE_DIR/$local_name"; then
      PULL_SUCCESS=$((PULL_SUCCESS + 1))
    fi
  done

  mkdir -p "$EVIDENCE_DIR/pull-pstore"
  if run_pull pstore /sys/fs/pstore "$EVIDENCE_DIR/pull-pstore"; then
    PULL_SUCCESS=$((PULL_SUCCESS + 1))
  fi

  for f in \
      "$EVIDENCE_DIR"/pull-recovery-last-log.txt \
      "$EVIDENCE_DIR"/pull-recovery-log.txt \
      "$EVIDENCE_DIR"/pull-recovery-tmp-log.txt \
      "$EVIDENCE_DIR"/pull-uiderrors.txt \
      "$EVIDENCE_DIR"/pull-pstore/*; do
    [[ -f "$f" ]] || continue
    grep -Ei \
      'zygote|system_server|bootclasspath|boot class|classloader|dex2oat|art/runtime|fatal|abort|avc:|selinux|vintf|fs_mgr|mount|verity|dm-verity|apex|mediatek|ims|recovery|rescue|watchdog' \
      "$f" >> "$EVIDENCE_DIR/boot-failure-keywords.txt" 2>/dev/null || true
  done

  USERDATA_SYSTEM_READABLE=NO
  if [[ -s "$EVIDENCE_DIR/pull-packages.xml" ]]; then
    USERDATA_SYSTEM_READABLE=YES
  fi

  cat > "$EVIDENCE_DIR/capture.env" <<EOF
N1I_C1_RECOVERY_CAPTURE_VERSION=1
DEVICE_SERIAL_SHA256=$SERIAL_SHA256
IMAGE_SOURCE_COMMIT=a745c7daa08267d851f45785a5bb7ff762ed4604
SYSTEM_SHA256=137bc8771c817c0afb3122d9f03e7a94575e03bcccc643b56235edd1075f2160
FLASH_EVIDENCE_DIR=$FLASH_EVIDENCE_DIR
DEVICE_CONTACT=READ_ONLY_RECOVERY_ADB_SYNC
SHELL_PROBE_RC=$SHELL_PROBE_RC
SYNC_PULL_SUCCESS_COUNT=$PULL_SUCCESS
USERDATA_SYSTEM_READABLE=$USERDATA_SYSTEM_READABLE
REBOOT=NONE
FLASH=NONE
MOUNT_MUTATION=NONE
EOF

  (
    cd "$EVIDENCE_DIR" || exit 1
    find . -type f ! -name SHA256SUMS.txt -print0 |
      LC_ALL=C sort -z |
      xargs -0 sha256sum > SHA256SUMS.txt
    sha256sum -c SHA256SUMS.txt >/dev/null
  ) || fail evidence_seal 68

  echo "N1I_C1_RECOVERY_SYNC_PULL_SUCCESS_COUNT=$PULL_SUCCESS"
  echo "N1I_C1_RECOVERY_USERDATA_SYSTEM_READABLE=$USERDATA_SYSTEM_READABLE"
  if [[ "$PULL_SUCCESS" -gt 0 ]]; then
    echo "N1I_C1_RECOVERY_CAPTURE=PASS_SYNC_FALLBACK"
  else
    echo "N1I_C1_RECOVERY_CAPTURE=PASS_TRANSPORT_PLUS_SHELL_PROBE_NO_SYNC_FILES"
  fi
  exit 0
fi

echo "N1I_C1_RECOVERY_SHELL_CAPTURE=AVAILABLE state=$ADB_STATE"

run_capture() {
  local name="$1"
  shift
  "$ADB_BIN" -s "$SERIAL" shell "$@" </dev/null     > "$EVIDENCE_DIR/$name.txt" 2> "$EVIDENCE_DIR/$name.stderr.txt"
  local rc=$?
  printf '%s\n' "$rc" > "$EVIDENCE_DIR/$name.rc"
  echo "N1I_C1_RECOVERY_CAPTURE_ITEM=$name rc=$rc"
}

run_capture getprop getprop
run_capture proc-cmdline cat /proc/cmdline
run_capture proc-bootconfig cat /proc/bootconfig
run_capture proc-mounts cat /proc/mounts
run_capture df df -h
run_capture dmesg dmesg
run_capture logcat-all logcat -b all -d -v threadtime
run_capture recovery-last-log cat /cache/recovery/last_log
run_capture recovery-log cat /cache/recovery/log
run_capture recovery-tmp-log cat /tmp/recovery.log
run_capture pstore-list ls -1 /sys/fs/pstore
run_capture block-by-name ls -la /dev/block/by-name
run_capture block-mapper ls -la /dev/block/mapper
run_capture dropbox-list ls -1 /data/system/dropbox

if [[ -f "$EVIDENCE_DIR/pstore-list.txt" ]]; then
  while IFS= read -r name; do
    [[ "$name" =~ ^[A-Za-z0-9._-]+$ ]] || continue
    run_capture "pstore-$name" cat "/sys/fs/pstore/$name"
  done < "$EVIDENCE_DIR/pstore-list.txt"
fi

if [[ -f "$EVIDENCE_DIR/dropbox-list.txt" ]]; then
  while IFS= read -r name; do
    [[ "$name" =~ ^[A-Za-z0-9._-]+$ ]] || continue
    case "$name" in
      *SYSTEM_BOOT*|*SYSTEM_RESTART*|*system_server_crash*|*SYSTEM_SERVER*)
        run_capture "dropbox-$name" tail -n 400 "/data/system/dropbox/$name"
        ;;
    esac
  done < "$EVIDENCE_DIR/dropbox-list.txt"
fi

grep -E '^\[(ro\.bootmode|ro\.boot\.bootreason|ro\.boot\.slot_suffix|ro\.boot\.verifiedbootstate|ro\.boot\.flash\.locked|ro\.build\.fingerprint|ro\.system\.build\.fingerprint|ro\.vendor\.build\.fingerprint|ro\.build\.version\.release|ro\.build\.version\.sdk|sys\.boot_completed)\]:' \
  "$EVIDENCE_DIR/getprop.txt" > "$EVIDENCE_DIR/key-props.txt" || true

for f in "$EVIDENCE_DIR"/logcat-all.txt "$EVIDENCE_DIR"/dmesg.txt \
         "$EVIDENCE_DIR"/pstore-*.txt "$EVIDENCE_DIR"/recovery-last-log.txt \
         "$EVIDENCE_DIR"/recovery-log.txt "$EVIDENCE_DIR"/recovery-tmp-log.txt \
         "$EVIDENCE_DIR"/dropbox-*.txt; do
  [[ -f "$f" ]] || continue
  grep -Ei     'zygote|system_server|bootclasspath|boot class|classloader|dex2oat|art/runtime|fatal|abort|avc:|selinux|vintf|fs_mgr|mount|verity|dm-verity|apex|mediatek|ims|recovery|rescue|watchdog'     "$f" >> "$EVIDENCE_DIR/boot-failure-keywords.txt" 2>/dev/null || true
done

cat > "$EVIDENCE_DIR/capture.env" <<EOF
N1I_C1_RECOVERY_CAPTURE_VERSION=1
DEVICE_SERIAL_SHA256=$SERIAL_SHA256
IMAGE_SOURCE_COMMIT=a745c7daa08267d851f45785a5bb7ff762ed4604
SYSTEM_SHA256=137bc8771c817c0afb3122d9f03e7a94575e03bcccc643b56235edd1075f2160
FLASH_EVIDENCE_DIR=$FLASH_EVIDENCE_DIR
DEVICE_CONTACT=READ_ONLY_RECOVERY_ADB
REBOOT=NONE
FLASH=NONE
MOUNT_MUTATION=NONE
EOF

(
  cd "$EVIDENCE_DIR" || exit 1
  find . -maxdepth 1 -type f ! -name SHA256SUMS.txt -print0 |
    LC_ALL=C sort -z |
    xargs -0 sha256sum > SHA256SUMS.txt
  sha256sum -c SHA256SUMS.txt >/dev/null
) || fail evidence_seal 68

echo "N1I_C1_RECOVERY_CAPTURE=PASS"
echo "N1I_C1_RECOVERY_EVIDENCE_DIR=$EVIDENCE_DIR"
