#!/usr/bin/env bash
# SableOS PR 207 — Titan 2 cellular read-only runtime capture (release-generic: N1B, N1D, stock, ...).
#
# Captures what happens on a Titan 2 while cellular connects and then drops:
#   - boot-to-end logcat stream (main, system, radio, crash, events; kernel if readable)
#   - periodic snapshots of ServiceState / data connection state / mobile-data setting /
#     airplane mode / SIM props / com.android.phone and radio daemon PIDs
#   - an event list of every transition, the first data-loss moment, and a log excerpt
#     around it
#   - start and end dumps of telephony services, carrier config, packages and features
#   - a signature scan (SELinux denials, phone crashes, radio HAL death, data-disable
#     reasons, carrier config reloads, subscription/SIM churn, IMS)
#
# Run it on each image under test, labelled e.g. n1d-system-only, n1b2-control, stock-tee14
# (stock only if a device is ALREADY on stock)
# with the same SIM and location. Compare the outputs side by side.
#
# READ-ONLY CONTRACT
#   Every device command goes through adb_ro(), which only accepts an allowlist of
#   read-only commands (getprop, dumpsys, settings get/list, pm list, service list/check,
#   lshal list, logcat read, ps, pidof, date, uname, getenforce, dmesg).
#   Anything else (settings put, svc, cmd, am, setprop, logcat -c, reboot, rm, ...) is
#   refused before it reaches the device. The script never reboots, toggles radios,
#   changes settings, installs anything or clears logs. To capture from boot, YOU reboot
#   the phone after starting the script with --wait-for-boot.
#
# PRIVACY
#   raw/       unredacted output. Contains IMEI/IMSI/ICCID/phone numbers/cell IDs.
#              Keep local. Never commit.
#   redacted/  same files after AUTOMATED, BEST-EFFORT pattern redaction. NOT automatically safe:
#              manual privacy review is required before sharing or committing anything from it.
#              See redacted/PRIVACY_REVIEW_REQUIRED.txt for what the patterns do and do not cover.
#   Summary and report are generated from redacted data and need the same manual review.
#
# Output (under --out, default ./out/cellular-runtime-<label>-<timestamp>):
#   CELLULAR_RUNTIME_SUMMARY.env   KEY=VALUE, consumed by the release gates
#   CELLULAR_RUNTIME_REPORT.md     timeline, first data loss, signatures
#   redacted/timeline.tsv  events.tsv  signatures.tsv  data_loss_window.log  ...
#
# PROFILES
#   default  The behaviour above, unchanged (same guard, same dumps).
#   n1i-b1   N1I-B1 stock-vs-C3A registration-collapse capture. Adds:
#              - an identity gate before any dump (stock: expected system + vendor
#                fingerprints, ro.build.type=user, ro.debuggable=0; c3a: expected vendor
#                fingerprint, non-stock system fingerprint, vbmeta digest + slot recorded)
#              - an exact-literal allowlist of extra read-only commands (pm path, two
#                dumpsys activity forms, one lshal form, four `cmd phone ims get-ims-service`
#                queries, three `content query` URIs). Under this profile every other
#                cmd / content / lshal / dumpsys activity / pm path form is refused.
#              - inventory checkpoints T1 (start), T2 (T1 + 10 min), T3 (end), each command
#                stored as .txt (stdout), .err (stderr) and .rc (exit status)
#            --bugreport is refused under n1i-b1 (exit 2, before adb is looked up).
#            There is no adb root / su path in this script under any profile.
#            The host-side C3A artifact SHA-256 is recorded as HOST_ASSERTED only; it is never
#            claimed to equal any on-device block hash.
#
# Exit codes: 0 capture completed   2 usage error   3 adb/device problem
#             5 read-only guard refused a command (bug in this script; nothing was sent)
#             6 n1i-b1 identity gate mismatch (no dumps taken)

set -euo pipefail

SCRIPT_VERSION="1.4.0"
CLASSIFIER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage:
  capture-n1b2-cellular-runtime.sh --serial SERIAL --label LABEL
                                   [--duration-min 45] [--interval-sec 10]
                                   [--wait-for-boot] [--bugreport] [--out DIR]

  --serial         adb serial of the Titan 2. Required (no implicit device selection).
  --label          Free-form tag for the image under test, recorded in every output.
                   1-64 chars of [A-Za-z0-9._-], starting with a letter or digit.
                   Examples: n1d-system-only, n1d-super-r1, n1b2-control, stock-tee14. Required.
  --duration-min   Capture window after start/boot (default 45; symptom must occur inside it).
  --interval-sec   Snapshot interval (default 10).
  --wait-for-boot  Capture the NEXT boot from its first adb contact. Start the script first,
                   then reboot the phone (or run `fastboot reboot` after a flash). The script
                   records the current boot_id (if the phone is up), waits for a boot with a
                   different boot_id, starts the log streams immediately, and restarts them
                   automatically across adb disconnects. Captures continue even if
                   sys.boot_completed never arrives (failed boots are the ones you need logs for).
  --boot-timeout-sec  Seconds to wait for the new boot to appear, and again for
                   sys.boot_completed (default 900 each).
  --bugreport      Also take an adb bugreport at the end (large; read-only). Refused under n1i-b1.
  --out            Output directory.
  --profile        default (unchanged behaviour) or n1i-b1.
  --b1-target      n1i-b1 only, required: stock | c3a.
  --c3a-artifact-sha256  n1i-b1 + c3a only, required: SHA-256 of the host image artifact that was
                   verified before the (separately authorised) flash. Recorded as host-asserted.
  --c3a-artifact-ref     n1i-b1 + c3a only, optional: artifact name/reference, [A-Za-z0-9._:/+-]{1,200}.

Stop early with Ctrl-C; the capture is finalised and the report still written.
EOF
}

die() { echo "ERROR: $1" >&2; exit "${2:-1}"; }
log() { echo "[$(date +%H:%M:%S)] $*" >&2; }

SERIAL="" LABEL="" DURATION_MIN=45 INTERVAL=10 WAIT_BOOT=0 BUGREPORT=0 OUT="" BOOT_TIMEOUT=900
PROFILE="default" B1_TARGET="" C3A_SHA="" C3A_REF="" B1_OPT_SEEN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)       PROFILE="${2:-}"; shift 2 ;;
    --b1-target)     B1_TARGET="${2:-}"; B1_OPT_SEEN=1; shift 2 ;;
    --c3a-artifact-sha256) C3A_SHA="${2:-}"; B1_OPT_SEEN=1; shift 2 ;;
    --c3a-artifact-ref)    C3A_REF="${2:-}"; B1_OPT_SEEN=1; shift 2 ;;
    --boot-timeout-sec) BOOT_TIMEOUT="${2:-}"; shift 2 ;;
    --serial)        SERIAL="${2:-}"; shift 2 ;;
    --label)         LABEL="${2:-}"; shift 2 ;;
    --duration-min)  DURATION_MIN="${2:-}"; shift 2 ;;
    --interval-sec)  INTERVAL="${2:-}"; shift 2 ;;
    --wait-for-boot) WAIT_BOOT=1; shift ;;
    --bugreport)     BUGREPORT=1; shift ;;
    --out)           OUT="${2:-}"; shift 2 ;;
    -h|--help)       usage; exit 0 ;;
    *) usage >&2; die "unknown argument: $1" 2 ;;
  esac
done

[[ -n "$SERIAL" ]] || { usage >&2; die "--serial is required" 2; }
[[ "$LABEL" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]] || die "--label must be 1-64 chars of [A-Za-z0-9._-] starting with a letter or digit (e.g. n1d-system-only)" 2
[[ "$DURATION_MIN" =~ ^[0-9]+$ && "$DURATION_MIN" -ge 1 ]] || die "--duration-min must be a positive integer" 2
[[ "$INTERVAL" =~ ^[0-9]+$ && "$INTERVAL" -ge 2 ]] || die "--interval-sec must be an integer >= 2" 2
[[ "$BOOT_TIMEOUT" =~ ^[0-9]+$ && "$BOOT_TIMEOUT" -ge 1 ]] || die "--boot-timeout-sec must be a positive integer" 2
# Profile validation happens before adb is even looked up, so a refused combination can never
# reach a device.
case "$PROFILE" in
  default)
    [[ "$B1_OPT_SEEN" -eq 0 ]] || die "--b1-target/--c3a-artifact-* require --profile n1i-b1" 2 ;;
  n1i-b1)
    [[ "$BUGREPORT" -eq 0 ]] || die "--bugreport is not permitted under --profile n1i-b1" 2
    case "$B1_TARGET" in
      stock)
        [[ -z "$C3A_SHA" && -z "$C3A_REF" ]] || die "--c3a-artifact-* are only valid with --b1-target c3a" 2 ;;
      c3a)
        [[ "$C3A_SHA" =~ ^[0-9a-f]{64}$ ]] || die "--c3a-artifact-sha256 must be 64 lowercase hex chars" 2
        [[ -z "$C3A_REF" || "$C3A_REF" =~ ^[A-Za-z0-9._:/+-]{1,200}$ ]] || die "--c3a-artifact-ref has invalid characters" 2 ;;
      *) die "--profile n1i-b1 requires --b1-target stock|c3a" 2 ;;
    esac ;;
  *) die "--profile must be default or n1i-b1" 2 ;;
esac
command -v adb >/dev/null || die "adb not found in PATH" 3
command -v python3 >/dev/null || die "python3 is required" 3
[[ -f "$CLASSIFIER_DIR/classify-n1b2-nr-state.py" ]] || die "classify-n1b2-nr-state.py must sit next to this script" 3

# n1i-b1: expected stock identity comes from the committed N1I-F control record (single source).
B1_EXPECT_SYSTEM_FP="" B1_EXPECT_VENDOR_FP=""
if [[ "$PROFILE" == "n1i-b1" ]]; then
  b1_ctl="$CLASSIFIER_DIR/n1i-f-stock-v010014-control.env"
  [[ -f "$b1_ctl" ]] || die "n1i-b1 needs $b1_ctl" 3
  B1_EXPECT_SYSTEM_FP="$(sed -n 's/^STOCK_BUILD_FINGERPRINT=//p' "$b1_ctl")"
  B1_EXPECT_VENDOR_FP="$(sed -n 's/^STOCK_VENDOR_FINGERPRINT=//p' "$b1_ctl")"
  [[ "$B1_EXPECT_SYSTEM_FP" =~ ^Unihertz/Titan_2/Titan_2:16/.+:user/release-keys$ ]] || die "n1i-b1: bad STOCK_BUILD_FINGERPRINT in $b1_ctl" 3
  [[ "$B1_EXPECT_VENDOR_FP" =~ ^Unihertz/Titan_2/Titan_2:14/.+:user/release-keys$ ]] || die "n1i-b1: bad STOCK_VENDOR_FINGERPRINT in $b1_ctl" 3
  command -v sha256sum >/dev/null || die "n1i-b1 needs sha256sum" 3
fi

TO=""; command -v timeout >/dev/null && TO="timeout"

# ------------------------------------------------------------ read-only guard
# Returns 0 if the device shell command is on the read-only allowlist.
is_read_only() {
  local c="$1"
  # Hard deny first: anything that could write, toggle, clear, reboot or execute.
  if [[ "$c" =~ (^|[[:space:]\;\|\&\`\$\(\)\>\<])(settings[[:space:]]+(put|delete|reset)|svc|cmd|am|setprop|reboot|rm|mv|cp|dd|chmod|chown|touch|mkdir|kill|killall|stop|start|pm[[:space:]]+(install|uninstall|clear|disable|enable|grant|revoke|hide|unhide|suspend)|input|monkey|wm|content|log[[:space:]]|echo|sh|su|toybox|busybox)([[:space:]]|$) ]]; then
    return 1
  fi
  [[ "$c" =~ [\;\|\&\`\>\<] || "$c" == *'$('* ]] && return 1
  # logcat: reading only. -c clears, -G/-P change buffers/prune.
  if [[ "$c" =~ ^logcat ]]; then
    [[ "$c" =~ (^|[[:space:]])-(c|G|P|-clear|-buffer-size|-prune)([[:space:]=]|$) ]] && return 1
    [[ "$c" =~ ^logcat([[:space:]]+(-b[[:space:]]+[a-z,]+|-v[[:space:]]+[a-z,]+|-d|-T[[:space:]]+[0-9]+))*$ ]] && return 0
    return 1
  fi
  # dumpsys: plain service dumps with a few known read-only arguments.
  if [[ "$c" =~ ^dumpsys ]]; then
    [[ "$c" =~ (^|[[:space:]])(set|reset|unplug|clear|enable|disable|--reset|--wait|debug)([[:space:]]|$) ]] && return 1
    [[ "$c" =~ ^dumpsys[[:space:]]+[A-Za-z0-9_.:-]+([[:space:]]+(-a|--print|processes|[a-z]+\.[A-Za-z0-9_.]+))?$ ]] && return 0
    return 1
  fi
  case "$c" in
    getprop|"getprop "[a-z]*) [[ "$c" =~ ^getprop([[:space:]]+[A-Za-z0-9_.]+)?$ ]] && return 0 ;;
    "settings get "*|"settings list "*)
      [[ "$c" =~ ^settings[[:space:]]+(get[[:space:]]+(global|secure|system)[[:space:]]+[A-Za-z0-9_.]+|list[[:space:]]+(global|secure|system))$ ]] && return 0 ;;
    "pm list "*)
      [[ "$c" =~ ^pm[[:space:]]+list[[:space:]]+(packages|features|libraries)([[:space:]]+(-f|-U|-u|--show-versioncode))*$ ]] && return 0 ;;
    "service list"|"service check "*) [[ "$c" =~ ^service[[:space:]]+(list|check[[:space:]]+[A-Za-z0-9_.:/-]+)$ ]] && return 0 ;;
    "lshal"|"lshal list"*) [[ "$c" =~ ^lshal([[:space:]]+list)?([[:space:]]+-[a-zA-Z]+)*$ ]] && return 0 ;;
    "ps -A"*) [[ "$c" =~ ^ps[[:space:]]+-A([[:space:]]+-o[[:space:]]+[A-Za-z,]+)?$ ]] && return 0 ;;
    "pidof "*) [[ "$c" =~ ^pidof[[:space:]]+[A-Za-z0-9_.:-]+$ ]] && return 0 ;;
    "date +%s"|"date +%z"|"uname -a"|"getenforce"|"dmesg"|"cat /proc/uptime"|"cat /proc/mounts"|"cat /proc/sys/kernel/random/boot_id") return 0 ;;
    "ls -la "*|"ls -laL "*) [[ "$c" =~ ^ls[[:space:]]+-laL?[[:space:]]+/[A-Za-z0-9_./-]*$ && "$c" != *..* ]] && return 0 ;;
  esac
  return 1
}

# n1i-b1 extra commands: exact literal strings only (no patterns, no prefixes).
B1_EXTRA_CMDS=(
  "pm path com.mediatek.ims"
  "dumpsys activity services com.mediatek.ims"
  "dumpsys activity service com.android.phone/.TelephonyDebugService"
  "lshal --types=b,c,l -i"
  "cmd phone ims get-ims-service -s 0 -d -f 1"
  "cmd phone ims get-ims-service -s 0 -c -f 1"
  "cmd phone ims get-ims-service -s 1 -d -f 1"
  "cmd phone ims get-ims-service -s 1 -c -f 1"
  "content query --uri content://telephony/carriers/preferapn"
  "content query --uri content://telephony/siminfo"
  "content query --uri content://telephony/carriers --where \"numeric='310260' OR numeric='310240'\""
)
is_b1_extra() {
  local c="$1" x
  for x in "${B1_EXTRA_CMDS[@]}"; do [[ "$c" == "$x" ]] && return 0; done
  return 1
}

# n1i-b1 guard: exact extras, otherwise the legacy allowlist minus the families the extras
# belong to. Any cmd / content / lshal (other than the plain `lshal list` the fixed dumps use),
# dumpsys activity, pm path, su or adb-root-like word that is not an exact extra is refused.
is_read_only_b1() {
  local c="$1"
  is_b1_extra "$c" && return 0
  [[ "$c" =~ ^[[:space:]]*(cmd|content|su|pm[[:space:]]+path|dumpsys[[:space:]]+activity|bugreport|bugreportz|dumpstate)([[:space:]]|$) ]] && return 1
  [[ "$c" =~ ^[[:space:]]*lshal ]] && { [[ "$c" == "lshal list" ]] || return 1; }
  [[ "$c" =~ (^|[[:space:]])(root|unroot|remount|disable-verity|enable-verity)([[:space:]]|$) ]] && return 1
  is_read_only "$c"
}

# Profile dispatch. Under the default profile this is exactly is_read_only.
guard_ok() {
  if [[ "$PROFILE" == "n1i-b1" ]]; then is_read_only_b1 "$1"; else is_read_only "$1"; fi
}

# Run a read-only shell command on the device. Refuses anything off the allowlist.
adb_ro() {
  local c="$1"
  guard_ok "$c" || die "read-only guard refused device command: '$c'" 5
  ${TO:+$TO 120} adb -s "$SERIAL" shell "$c"
}

# ------------------------------------------------------------- output + timeline
OUT="${OUT:-./out/cellular-runtime-${LABEL}-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$OUT"/{raw/start,raw/end,raw/snapshots,raw/segments,redacted}
OUT="$(cd "$OUT" && pwd)"
RAW="$OUT/raw"
SEGDIR="$RAW/segments"
STOP_FLAG="$SEGDIR/.stop"
rm -f "$STOP_FLAG"
cat > "$RAW/DO_NOT_COMMIT.txt" <<'EOF'
This directory contains unredacted device output (IMEI, IMSI, ICCID, phone numbers,
cell identities, installed packages, network names). Keep it local. Never commit or share it.
../redacted/ and the summary/report are best-effort automated redactions: they still require
manual privacy review before being shared or committed.
EOF
printf 'host_epoch\tevent\tdetail\n' > "$RAW/boot_timeline.tsv"
printf 'stream\tsegment\tboot_id\thost_start\thost_end\tbytes\n' > "$SEGDIR/index.tsv"
: > "$RAW/boot_meta.env"

# Timeline event: host epoch, event, detail. Also echoed to the terminal.
tl() { printf '%s\t%s\t%s\n' "$(date +%s)" "$1" "${2:-}" >> "$RAW/boot_timeline.tsv"; log "$1 ${2:-}"; }
meta() { printf '%s=%s\n' "$1" "$2" >> "$RAW/boot_meta.env"; }

# ------------------------------------------------------------- device state helpers
# Transport state for SERIAL from the host side (never touches the device):
# device | unauthorized | offline | recovery | sideload | fastboot | absent
dev_state() {
  local s
  s="$(adb devices 2>/dev/null | awk -v s="$SERIAL" '$1 == s { print $2; exit }')"
  if [[ -z "$s" ]] && command -v fastboot >/dev/null; then
    if ${TO:+$TO 5} fastboot devices 2>/dev/null | awk -v s="$SERIAL" '$1 == s { f = 1 } END { exit !f }'; then
      s="fastboot"
    fi
  fi
  echo "${s:-absent}"
}

# Read-only command with retries that never aborts the script on transport errors.
# The guard is checked here, in the parent shell, so a refusal is always fatal.
adb_try() {
  local n="$1" c="$2" out i
  guard_ok "$c" || die "read-only guard refused device command: '$c'" 5
  for ((i = 0; i < n; i++)); do
    if out="$(${TO:+$TO 30} adb -s "$SERIAL" shell "$c" 2>/dev/null)"; then
      printf '%s' "${out//$'\r'/}"
      return 0
    fi
    sleep 1
  done
  return 1
}
BOOT_ID_CMD="cat /proc/sys/kernel/random/boot_id"

STOPPED=0
on_interrupt() { log "interrupted: finalising capture"; STOPPED=1; }
trap on_interrupt INT TERM

# ------------------------------------------------------------- wait for the new boot
BOOT_WAIT_RESULT="NOT_REQUESTED" OLD_BOOT_ID="" CURRENT_BOOT_ID="" BOOT_COMPLETED="NOT_WAITED"
start_state="$(dev_state)"
tl STATE_AT_START "$start_state"
if [[ "$WAIT_BOOT" -eq 1 ]]; then
  if [[ "$start_state" == "device" ]]; then
    OLD_BOOT_ID="$(adb_try 3 "$BOOT_ID_CMD" || true)"
    tl OLD_BOOT_ID "${OLD_BOOT_ID:-unreadable}"
    log "phone is up on the old boot. Reboot it now; logging starts on the next boot."
  else
    log "phone not in adb yet (state: $start_state). Any boot that appears will be captured."
  fi
  deadline=$(( $(date +%s) + BOOT_TIMEOUT ))
  last="$start_state" hinted=0
  BOOT_WAIT_RESULT="TIMEOUT_NO_NEW_BOOT"
  while [[ "$STOPPED" -eq 0 && "$(date +%s)" -lt "$deadline" ]]; do
    s="$(dev_state)"
    if [[ "$s" != "$last" ]]; then tl STATE "$s"; last="$s"; fi
    if [[ "$s" == "unauthorized" && "$hinted" -eq 0 ]]; then
      log "device is 'unauthorized': accept the USB debugging prompt on the phone (after a wipe, adb keys are gone; bake the host key into userdebug builds with PRODUCT_ADB_KEYS)."
      hinted=1
    fi
    if [[ "$s" == "device" ]]; then
      bid="$(adb_try 1 "$BOOT_ID_CMD" || true)"
      if [[ -n "$bid" && "$bid" != "$OLD_BOOT_ID" ]]; then
        CURRENT_BOOT_ID="$bid"; BOOT_WAIT_RESULT="NEW_BOOT_SEEN"
        tl NEW_BOOT_ID "$bid"
        break
      fi
    fi
    sleep 0.5
  done
  if [[ "$BOOT_WAIT_RESULT" != "NEW_BOOT_SEEN" ]]; then
    [[ "$STOPPED" -eq 1 ]] && BOOT_WAIT_RESULT="INTERRUPTED_NO_NEW_BOOT"
    tl BOOT_WAIT_END "$BOOT_WAIT_RESULT"
    meta BOOT_WAIT_RESULT "$BOOT_WAIT_RESULT"; meta OLD_BOOT_ID "${OLD_BOOT_ID:--}"
    {
      echo "CELLULAR_RUNTIME_CAPTURE=NO_NEW_BOOT"
      echo "CAPTURE_SCRIPT_VERSION=$SCRIPT_VERSION"
      echo "CAPTURE_LABEL=$LABEL"
      echo "READ_ONLY=YES"
      echo "REDACTION=AUTOMATED_BEST_EFFORT"
      echo "PRIVACY_REVIEW=REQUIRED_BEFORE_SHARING"
      echo "BOOT_WAIT_RESULT=$BOOT_WAIT_RESULT"
      echo "LAST_TRANSPORT_STATE=$last"
    } > "$OUT/CELLULAR_RUNTIME_SUMMARY.env"
    log "no new boot reached adb; timeline: $RAW/boot_timeline.tsv"
    echo "SUMMARY=$OUT/CELLULAR_RUNTIME_SUMMARY.env"
    exit 3
  fi
else
  [[ "$start_state" == "device" ]] || die "device $SERIAL not in 'device' state (got '$start_state'). Use --wait-for-boot to capture a boot." 3
  CURRENT_BOOT_ID="$(adb_try 3 "$BOOT_ID_CMD" || true)"
  tl CURRENT_BOOT_ID "${CURRENT_BOOT_ID:-unreadable}"
fi

# First contact with this boot: device clock and uptime give the boot start time,
# used later to measure how much of the boot the log buffers still covered.
FIRST_CONTACT_UPTIME="$(adb_try 3 "cat /proc/uptime" | cut -d' ' -f1 || true)"
FIRST_CONTACT_DEV_EPOCH="$(adb_try 3 "date +%s" || true)"
tl FIRST_CONTACT "uptime=${FIRST_CONTACT_UPTIME:-?}s"
meta BOOT_WAIT_RESULT "$BOOT_WAIT_RESULT"
meta OLD_BOOT_ID "${OLD_BOOT_ID:--}"
meta CAPTURED_BOOT_ID "${CURRENT_BOOT_ID:--}"
meta FIRST_CONTACT_UPTIME_SEC "${FIRST_CONTACT_UPTIME:--}"
meta FIRST_CONTACT_DEV_EPOCH "${FIRST_CONTACT_DEV_EPOCH:--}"

# ------------------------------------------------------------- supervised log streams
# Each stream runs in its own supervisor loop. Whenever adb drops (USB re-enumeration,
# adbd restart, reboot) the supervisor waits for the device and starts a new segment.
# logcat replays its ring buffer on every start, so segments overlap; the analysis step
# stitches them by timestamp without duplicates. Segment boot_ids reveal extra reboots.
supervise_stream() {
  local name="$1" cmd="$2" may_be_unavailable="$3" seg=0 quick_empty=0 bid start f child bytes
  while [[ ! -e "$STOP_FLAG" ]]; do
    if [[ "$(dev_state)" == "device" ]] && bid="$(adb_try 1 "$BOOT_ID_CMD")"; then
      seg=$((seg + 1)); start="$(date +%s)"
      f="$SEGDIR/$name.$(printf '%03d' "$seg").log"
      adb -s "$SERIAL" shell "$cmd" > "$f" 2> "$f.err" &
      child=$!
      echo "$child" > "$SEGDIR/$name.child"
      wait "$child" 2>/dev/null || true
      bytes="$(wc -c < "$f" | tr -d ' ')"
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$seg" "$bid" "$start" "$(date +%s)" "$bytes" >> "$SEGDIR/index.tsv"
      if [[ "$bytes" -eq 0 && $(( $(date +%s) - start )) -lt 3 ]]; then
        quick_empty=$((quick_empty + 1))
        if [[ "$may_be_unavailable" -eq 1 && "$quick_empty" -ge 3 ]]; then
          echo "UNAVAILABLE_AS_SHELL" > "$SEGDIR/$name.unavailable"
          break
        fi
      else
        quick_empty=0
      fi
    fi
    [[ -e "$STOP_FLAG" ]] || sleep $(( quick_empty > 0 ? 2 : 1 ))
  done
}

SUP_PIDS=()
start_supervisor() {
  guard_ok "$2" || die "read-only guard refused stream command: '$2'" 5
  supervise_stream "$1" "$2" "$3" &
  SUP_PIDS+=($!)
}
start_supervisor logcat_stream "logcat -b main,system,radio,crash,events -v threadtime,uid,year" 0
start_supervisor logcat_kernel "logcat -b kernel -v threadtime,year" 1
tl STREAMS_STARTED "boot_id=${CURRENT_BOOT_ID:--}"

finish_streams() {
  local p cf
  touch "$STOP_FLAG"
  for cf in "$SEGDIR"/*.child; do
    [[ -e "$cf" ]] && kill "$(cat "$cf")" 2>/dev/null || true
  done
  for p in "${SUP_PIDS[@]:-}"; do [[ -n "$p" ]] && wait "$p" 2>/dev/null || true; done
}
trap finish_streams EXIT

# ------------------------------------------------------------- boot completion
if [[ "$WAIT_BOOT" -eq 1 ]]; then
  BOOT_COMPLETED="NO"
  deadline=$(( $(date +%s) + BOOT_TIMEOUT ))
  while [[ "$STOPPED" -eq 0 && "$(date +%s)" -lt "$deadline" ]]; do
    if [[ "$(adb_try 1 "getprop sys.boot_completed" || true)" == "1" ]]; then
      BOOT_COMPLETED="YES"
      tl BOOT_COMPLETED "sys.boot_completed=1"
      break
    fi
    sleep 2
  done
  [[ "$BOOT_COMPLETED" == "YES" ]] || tl BOOT_COMPLETED_NOT_SEEN "continuing capture for diagnosis"
fi
meta BOOT_COMPLETED "$BOOT_COMPLETED"

HOST_START="$(date +%s)"
DEV_EPOCH="$(adb_try 3 "date +%s" || true)"
if [[ ! "$DEV_EPOCH" =~ ^[0-9]+$ ]]; then DEV_EPOCH="$HOST_START"; meta DEVICE_CLOCK "UNREAD_HOST_CLOCK_USED"; fi
DEV_TZ="$(adb_try 3 "date +%z" || true)"; [[ "$DEV_TZ" =~ ^[+-][0-9]{4}$ ]] || DEV_TZ="+0000"
FINGERPRINT="$(adb_try 3 "getprop ro.build.fingerprint" || echo "-")"
DEVICE="$(adb_try 3 "getprop ro.product.device" || echo "-")"
MODEL="$(adb_try 3 "getprop ro.product.model" || echo "-")"
UPTIME="$(adb_try 3 "cat /proc/uptime" | cut -d' ' -f1 || echo "-")"
log "device=$DEVICE model=$MODEL uptime=${UPTIME}s label=$LABEL"
log "fingerprint=$FINGERPRINT"

# ------------------------------------------------------------ n1i-b1 identity gate + inventory
B1_DIR="$RAW/b1"
b1_prop() { local v; v="$(adb_try 3 "getprop $1" || true)"; printf '%s' "${v:-UNREADABLE}"; }

b1_identity_gate() {
  local sys ven typ dbg vbm slot reasons=()
  mkdir -p "$B1_DIR"
  sys="$(b1_prop ro.build.fingerprint)"
  ven="$(b1_prop ro.vendor.build.fingerprint)"
  typ="$(b1_prop ro.build.type)"
  dbg="$(b1_prop ro.debuggable)"
  vbm="$(b1_prop ro.boot.vbmeta.digest)"
  slot="$(b1_prop ro.boot.slot_suffix)"
  [[ "$ven" == "$B1_EXPECT_VENDOR_FP" ]] || reasons+=("VENDOR_FINGERPRINT_MISMATCH")
  if [[ "$B1_TARGET" == "stock" ]]; then
    [[ "$sys" == "$B1_EXPECT_SYSTEM_FP" ]] || reasons+=("SYSTEM_FINGERPRINT_MISMATCH")
    [[ "$typ" == "user" ]] || reasons+=("BUILD_TYPE_NOT_USER")
    [[ "$dbg" == "0" ]] || reasons+=("DEBUGGABLE_NOT_0")
  else
    [[ "$sys" != "UNREADABLE" ]] || reasons+=("SYSTEM_FINGERPRINT_UNREADABLE")
    [[ "$sys" != "$B1_EXPECT_SYSTEM_FP" ]] || reasons+=("SYSTEM_FINGERPRINT_IS_STOCK")
    [[ "$vbm" =~ ^[0-9a-f]{64}$ ]] || reasons+=("VBMETA_DIGEST_UNREADABLE")
  fi
  [[ "$slot" =~ ^_[ab]$ ]] || reasons+=("SLOT_SUFFIX_UNREADABLE")
  {
    echo "B1_TARGET=$B1_TARGET"
    echo "B1_DEVICE_BUILD_FINGERPRINT=$sys"
    echo "B1_DEVICE_VENDOR_FINGERPRINT=$ven"
    echo "B1_DEVICE_BUILD_TYPE=$typ"
    echo "B1_DEVICE_DEBUGGABLE=$dbg"
    echo "B1_DEVICE_VBMETA_DIGEST=$vbm"
    echo "B1_DEVICE_SLOT_SUFFIX=$slot"
    echo "B1_EXPECTED_VENDOR_FINGERPRINT=$B1_EXPECT_VENDOR_FP"
    [[ "$B1_TARGET" == "stock" ]] && echo "B1_EXPECTED_BUILD_FINGERPRINT=$B1_EXPECT_SYSTEM_FP"
    if [[ "$B1_TARGET" == "c3a" ]]; then
      echo "B1_C3A_ARTIFACT_SHA256_HOST_ASSERTED=$C3A_SHA"
      echo "B1_C3A_ARTIFACT_REF=${C3A_REF:--}"
      echo "B1_BLOCK_HASH_EQUIVALENCE=NOT_CLAIMED"
    fi
    echo "B1_IDENTITY_GATE=$([[ ${#reasons[@]} -eq 0 ]] && echo PASS || echo FAIL)"
    echo "B1_IDENTITY_GATE_REASONS=$(IFS=,; echo "${reasons[*]:-NONE}")"
  } > "$B1_DIR/identity.env"
  # Every identity key also goes into the summary through boot_meta.
  grep -E '^B1_' "$B1_DIR/identity.env" >> "$RAW/boot_meta.env"
  [[ ${#reasons[@]} -eq 0 ]]
}

# One inventory command: stdout, stderr and exit status are all kept.
b1_run() {
  local dir="$1" slug="$2" c="$3" rc=0
  guard_ok "$c" || die "read-only guard refused device command: '$c'" 5
  ${TO:+$TO 120} adb -s "$SERIAL" shell "$c" > "$dir/$slug.txt" 2> "$dir/$slug.err" || rc=$?
  printf '%s\n' "$rc" > "$dir/$slug.rc"
  printf '%s\t%s\t%s\t%s\n' "$slug" "$(date +%s)" "$rc" "$c" >> "$dir/INDEX.tsv"
}

B1_SLUGS=(ims_pm_path ims_activity_services telephony_debug_service lshal_types_bcl
          ims_get_s0_device ims_get_s0_carrier ims_get_s1_device ims_get_s1_carrier
          apn_preferapn siminfo apn_carriers_310260_310240)
b1_checkpoint() {
  local name="$1" dir="$B1_DIR/$1" i
  mkdir -p "$dir"
  printf 'slug\thost_epoch\trc\tcommand\n' > "$dir/INDEX.tsv"
  log "n1i-b1 inventory checkpoint $name"
  for i in "${!B1_EXTRA_CMDS[@]}"; do b1_run "$dir" "${B1_SLUGS[$i]}" "${B1_EXTRA_CMDS[$i]}"; done
  b1_run "$dir" getprop "getprop"
  b1_run "$dir" telephony_registry "dumpsys telephony.registry"
  b1_run "$dir" carrier_config "dumpsys carrier_config"
  b1_run "$dir" isub "dumpsys isub"
  b1_run "$dir" logcat_radio "logcat -d -b radio -v threadtime,uid,year"
  meta "B1_CHECKPOINT_$name" "CAPTURED@$(date +%s)"
  tl "B1_CHECKPOINT" "$name"
}

if [[ "$PROFILE" == "n1i-b1" ]]; then
  [[ ${#B1_SLUGS[@]} -eq ${#B1_EXTRA_CMDS[@]} ]] || die "internal: B1 slug/command tables differ" 5
  meta CAPTURE_PROFILE "n1i-b1"
  meta B1_SERIAL_SHA256 "$(printf '%s' "$SERIAL" | sha256sum | cut -d' ' -f1)"
  if ! b1_identity_gate; then
    tl B1_IDENTITY_GATE "FAIL $(sed -n 's/^B1_IDENTITY_GATE_REASONS=//p' "$B1_DIR/identity.env")"
    {
      echo "CELLULAR_RUNTIME_CAPTURE=IDENTITY_GATE_FAILED"
      echo "CAPTURE_SCRIPT_VERSION=$SCRIPT_VERSION"
      echo "CAPTURE_LABEL=$LABEL"
      echo "CAPTURE_PROFILE=n1i-b1"
      echo "READ_ONLY=YES"
      grep -E '^B1_(TARGET|IDENTITY_GATE|IDENTITY_GATE_REASONS)=' "$B1_DIR/identity.env"
    } > "$OUT/CELLULAR_RUNTIME_SUMMARY.env"
    echo "SUMMARY=$OUT/CELLULAR_RUNTIME_SUMMARY.env"
    die "n1i-b1 identity gate failed; no dumps taken (see $B1_DIR/identity.env)" 6
  fi
  tl B1_IDENTITY_GATE "PASS target=$B1_TARGET"
fi

# ------------------------------------------------------------ fixed dumps
TEL_PKGS_RE='phone|telephony|telecom|carrierconfig|cellbroadcast|mms|stk|ims|euicc|lpa|radio|mediatek\.(ims|tele)|mtk.*(ims|tele)|phh|trebledroid'
TEL_SVCS_RE='^[0-9]+[[:space:]]+(telephony\.registry|phone|isub|carrier_config|telecom|ims|imms|iphonesubinfo|econtroller|euicc_card_controller|telephony_ims|connectivity|netpolicy|simphonebook|sip)[[:space:]:]'

dump_fixed() {
  local dir="$1"
  log "capturing fixed dumps -> $(basename "$dir")"
  adb_ro "getprop"                                     > "$dir/getprop.txt" 2>&1 || true
  adb_ro "getenforce"                                  > "$dir/getenforce.txt" 2>&1 || true
  adb_ro "uname -a"                                    > "$dir/uname.txt" 2>&1 || true
  adb_ro "pm list packages -f -U --show-versioncode"   > "$dir/packages.txt" 2>&1 || true
  adb_ro "pm list features"                            > "$dir/features.txt" 2>&1 || true
  adb_ro "service list"                                > "$dir/service_list.txt" 2>&1 || true
  adb_ro "lshal list"                                  > "$dir/lshal.txt" 2>&1 || true
  adb_ro "ps -A -o PID,PPID,USER,NAME"                 > "$dir/ps.txt" 2>&1 || true
  adb_ro "settings list global"                        > "$dir/settings_global.txt" 2>&1 || true
  # Mount layout: proves whether stock product/system_ext were mounted or skipped (GSI skip_mount).
  adb_ro "cat /proc/mounts"                            > "$dir/proc_mounts.txt" 2>&1 || true
  adb_ro "ls -la /"                                    > "$dir/root_symlinks.txt" 2>&1 || true
  local cfgd
  for cfgd in /system/etc/init/config /system/system_ext/etc/init/config /system_ext/etc/init/config; do
    adb_ro "ls -la $cfgd" > "$dir/ls_$(echo "$cfgd" | tr '/' '_').txt" 2>&1 || true
  done
  local s
  for s in $(grep -E "$TEL_SVCS_RE" "$dir/service_list.txt" 2>/dev/null | awk '{print $2}' | tr -d ':' | sort -u); do
    adb_ro "dumpsys $s" > "$dir/dumpsys_${s}.txt" 2>&1 || true
  done
  local p
  for p in $(grep -oE 'package:[^ ]+=[A-Za-z0-9_.]+' "$dir/packages.txt" 2>/dev/null \
             | sed 's/.*=//' | grep -Ei "$TEL_PKGS_RE" | sort -u); do
    adb_ro "dumpsys package $p" > "$dir/dumpsys_package_${p}.txt" 2>&1 || true
  done
  adb_ro "logcat -d -b main,system,radio,crash,events -v threadtime,uid,year" > "$dir/logcat_buffer.txt" 2>&1 || true
  adb_ro "dmesg" > "$dir/dmesg.txt" 2>&1 || true
}
dump_fixed "$RAW/start"
B1_T2_AT=0
if [[ "$PROFILE" == "n1i-b1" ]]; then
  b1_checkpoint T1
  B1_T2_AT=$(( $(date +%s) + 600 ))
fi

# ------------------------------------------------------------ snapshot loop
TIMELINE_RAW="$RAW/snapshots/snapshots.jsonl"
: > "$TIMELINE_RAW"
END=$(( HOST_START + DURATION_MIN * 60 ))
n=0
log "snapshotting every ${INTERVAL}s for ${DURATION_MIN} min (Ctrl-C to stop early)"
while [[ "$(date +%s)" -lt "$END" && "$STOPPED" -eq 0 ]]; do
  n=$((n + 1))
  ts="$(date +%s)"
  snap="$RAW/snapshots/$(printf '%05d' "$n")"
  adb_ro "dumpsys telephony.registry" > "$snap.registry.txt" 2>&1 || echo "CAPTURE_FAILED" > "$snap.registry.txt"
  adb_ro "settings list global"       > "$snap.settings.txt" 2>&1 || true
  adb_ro "getprop"                    > "$snap.props.txt" 2>&1 || true
  adb_ro "ps -A -o PID,NAME"          > "$snap.ps.txt" 2>&1 || true
  if python3 - "$ts" "$snap" "$CLASSIFIER_DIR" >> "$TIMELINE_RAW" <<'PYEOF'
import importlib.util, json, re, sys
ts, snap, cdir = int(sys.argv[1]), sys.argv[2], sys.argv[3]
spec = importlib.util.spec_from_file_location("nrc", cdir + "/classify-n1b2-nr-state.py")
nrc = importlib.util.module_from_spec(spec); spec.loader.exec_module(nrc)
def rd(s):
    try: return open(f"{snap}.{s}.txt", errors="replace").read()
    except OSError: return ""
reg, st, props, ps = rd("registry"), rd("settings"), rd("props"), rd("ps")
DCS = {"-1": "UNKNOWN", "0": "DISCONNECTED", "1": "CONNECTING", "2": "CONNECTED",
       "3": "SUSPENDED", "4": "DISCONNECTING", "5": "HANDOVER"}
rows = []
# Shared parser: nrState is read from the PS/WWAN registration entry only (the CS entry says NONE).
for pid, b in nrc.split_phones(reg).items():
    r = nrc.parse_registry_phone(b)
    rat = r["ps_rat"] if r["ps_rat"] not in ("-", "UNKNOWN") else r["ril_data_tech"]
    rows.append({
        "phone_id": pid,
        "voice_reg": r["voice_reg"],
        "data_reg": r["data_reg"],
        "data_rat": rat,
        "ril_data_tech": r["ril_data_tech"],
        "nr_state": r["nr_state"],
        "nr_channels": r["nr_channels"],
        "display_override": r["display_override"],
        "nr_class": r["nr_class"],
        "nr_flags": r["flags"],
        "wlan_reg": r["wlan_reg"],
        "iwlan_preferred": r["iwlan_preferred"],
        "data_conn": DCS.get(r["data_conn"], r["data_conn"]),
        "data_net_type": nrc._m(r"mDataConnectionNetworkType(?:\[\d+\])?=(\d+)", b),
    })
sg = lambda k: (re.search(rf"^{re.escape(k)}=(.*)$", st, re.M).group(1).strip() if re.search(rf"^{re.escape(k)}=(.*)$", st, re.M) else "-")
gp = lambda k: (re.search(rf"^\[{re.escape(k)}\]: \[(.*)\]$", props, re.M).group(1) if re.search(rf"^\[{re.escape(k)}\]: \[(.*)\]$", props, re.M) else "-")
procs = {}
for line in ps.splitlines():
    parts = line.split()
    if len(parts) >= 2 and re.search(r"com\.android\.phone$|rild|ril-daemon|fusionril|ims|ccci|mdinit|volte|radio", parts[-1], re.I):
        procs[parts[-1]] = parts[0]
common = {
    "ts": ts,
    "mobile_data": sg("mobile_data"),
    "mobile_data1": sg("mobile_data1"), "mobile_data2": sg("mobile_data2"),
    "airplane": sg("airplane_mode_on"),
    "data_roaming": sg("data_roaming"),
    "multi_sim_data_call": sg("multi_sim_data_call"),
    "preferred_network_mode": sg("preferred_network_mode"),
    "sim_state": gp("gsm.sim.state"),
    "network_type": gp("gsm.network.type"),
    "operator": gp("gsm.operator.alpha"),
    "phone_pid": procs.get("com.android.phone", "-"),
    "radio_procs": ";".join(f"{k}={v}" for k, v in sorted(procs.items()) if k != "com.android.phone") or "-",
    "registry_ok": "CAPTURE_FAILED" not in reg[:40],
}
for r in rows:
    r.update(common); print(json.dumps(r))
PYEOF
  then :; else log "snapshot $n parse failed; continuing"; fi
  if [[ "$PROFILE" == "n1i-b1" && "$B1_T2_AT" -gt 0 && "$(date +%s)" -ge "$B1_T2_AT" ]]; then
    b1_checkpoint T2; B1_T2_AT=0
  fi
  sleep "$INTERVAL" || true
done
if [[ "$PROFILE" == "n1i-b1" && "$B1_T2_AT" -gt 0 ]]; then
  meta B1_CHECKPOINT_T2 "NOT_REACHED_CAPTURE_ENDED_BEFORE_T1_PLUS_600S"
  tl "B1_CHECKPOINT" "T2 not reached"
fi

# ------------------------------------------------------------ end of capture
trap - INT TERM
dump_fixed "$RAW/end"
adb_ro "dumpsys dropbox --print" > "$RAW/end/dropbox.txt" 2>&1 || true
[[ "$PROFILE" == "n1i-b1" ]] && b1_checkpoint T3
finish_streams
trap - EXIT

if [[ "$BUGREPORT" -eq 1 && "$PROFILE" != "n1i-b1" ]]; then
  log "taking bugreport (read-only, may take several minutes)"
  adb -s "$SERIAL" bugreport "$RAW/end/bugreport.zip" >/dev/null 2>&1 || log "bugreport failed; continuing"
fi

# ------------------------------------------------------------ redact + analyse
log "redacting and analysing"
python3 - "$OUT" "$LABEL" "$SERIAL" "$DEVICE" "$MODEL" "$FINGERPRINT" "$HOST_START" "$DEV_EPOCH" "$DEV_TZ" \
          "$DURATION_MIN" "$INTERVAL" "$SCRIPT_VERSION" "$STOPPED" <<'PYEOF'
import datetime as dt, json, os, re, sys, hashlib
(OUT, LABEL, SERIAL, DEVICE, MODEL, FP, HOST_START, DEV_EPOCH, DEV_TZ,
 DURATION, INTERVAL, VERSION, STOPPED) = sys.argv[1:]
RAW, RED = os.path.join(OUT, "raw"), os.path.join(OUT, "redacted")
offset = int(DEV_EPOCH) - int(HOST_START)          # device clock minus host clock
tzs = DEV_TZ.strip() or "+0000"
dev_tz = dt.timezone(dt.timedelta(hours=int(tzs[1:3]), minutes=int(tzs[3:5])) * (-1 if tzs[0] == "-" else 1))

# ---- boot metadata written by the shell side
BOOT_META = {}
bm = os.path.join(RAW, "boot_meta.env")
if os.path.exists(bm):
    for line in open(bm):
        if "=" in line:
            k, v = line.rstrip("\n").split("=", 1); BOOT_META[k] = v

# ---- stitch supervised log segments into one file per stream
# Every reconnect restarts logcat, which replays its ring buffer, so segments overlap.
# Lines older than (last written timestamp - 1 s) are skipped; lines inside that 1 s
# window are skipped only if already written. Segment markers record boot_id and host time.
SEG = os.path.join(RAW, "segments")
TS_RX = re.compile(r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\.\d{3}")
def _minus_1s(ts):
    return (dt.datetime.strptime(ts[:19], "%Y-%m-%d %H:%M:%S") - dt.timedelta(seconds=1)).strftime("%Y-%m-%d %H:%M:%S")

def stitch(name):
    rows = []
    ip = os.path.join(SEG, "index.tsv")
    if os.path.exists(ip):
        for line in open(ip).read().splitlines()[1:]:
            c = line.split("\t")
            if len(c) >= 6 and c[0] == name:
                rows.append(c)
    rows.sort(key=lambda c: int(c[1]))
    st = {"segments": 0, "reconnects": 0, "boot_ids": [], "max_gap": 0, "lines": 0, "earliest": None,
          "dropped_overlap": 0}
    last_ts, tail, prev_end = None, [], None
    with open(os.path.join(RAW, name + ".log"), "w") as out:
        for c in rows:
            seg, bid, hs, he = int(c[1]), c[2], int(c[3]), int(c[4])
            f = os.path.join(SEG, f"{name}.{seg:03d}.log")
            if not os.path.exists(f):
                continue
            st["segments"] += 1
            if bid not in st["boot_ids"]:
                st["boot_ids"].append(bid)
            if prev_end is not None:
                st["reconnects"] += 1
                st["max_gap"] = max(st["max_gap"], hs - prev_end)
            prev_end = he
            out.write(f"# ---- segment {seg} boot_id={bid} host_epoch={hs}..{he}\n")
            lo = _minus_1s(last_ts) if last_ts else None
            seen_tail = {l for t, l in tail if lo is None or t >= lo}
            for line in open(f, errors="replace"):
                m = TS_RX.match(line)
                if not m:
                    if last_ts is None and line.strip():
                        out.write(line)
                    continue
                ts = m.group(1)
                if lo is not None and (ts < lo or (ts <= last_ts and line in seen_tail)):
                    st["dropped_overlap"] += 1
                    continue
                out.write(line)
                st["lines"] += 1
                if st["earliest"] is None:
                    st["earliest"] = ts
                if last_ts is None or ts > last_ts:
                    last_ts = ts
                tail.append((ts, line))
                if len(tail) > 20000:
                    del tail[:10000]
    return st

STREAMS = {n: stitch(n) for n in ("logcat_stream", "logcat_kernel")}
BOOT_SUMMARY = {}
for key, v in BOOT_META.items():
    BOOT_SUMMARY[key] = v
ms = STREAMS["logcat_stream"]
BOOT_SUMMARY["STREAM_SEGMENTS"] = str(ms["segments"])
BOOT_SUMMARY["STREAM_RECONNECTS"] = str(ms["reconnects"])
BOOT_SUMMARY["STREAM_MAX_RECONNECT_GAP_SEC"] = str(ms["max_gap"])
BOOT_SUMMARY["STREAM_OVERLAP_LINES_DROPPED"] = str(ms["dropped_overlap"])
BOOT_SUMMARY["BOOT_IDS_IN_CAPTURE"] = str(len(ms["boot_ids"]))
BOOT_SUMMARY["REBOOTS_DURING_CAPTURE"] = str(max(0, len(ms["boot_ids"]) - 1))
BOOT_SUMMARY["EARLIEST_LOG_TIME"] = ms["earliest"] or "-"
BOOT_SUMMARY["KERNEL_STREAM"] = ("UNAVAILABLE_AS_SHELL" if os.path.exists(os.path.join(SEG, "logcat_kernel.unavailable"))
                                 else ("CAPTURED" if STREAMS["logcat_kernel"]["lines"] else "EMPTY"))
cov = "-"
try:
    boot_start = int(BOOT_META["FIRST_CONTACT_DEV_EPOCH"]) - float(BOOT_META["FIRST_CONTACT_UPTIME_SEC"])
    if ms["earliest"]:
        e = dt.datetime.strptime(ms["earliest"], "%Y-%m-%d %H:%M:%S").replace(tzinfo=dev_tz).timestamp()
        # The earliest line may predate this boot if the buffer still holds the previous boot.
        cov = f"{e - boot_start:.0f}"
        BOOT_SUMMARY["LOG_COVERAGE"] = ("INCLUDES_PREVIOUS_BOOT" if e - boot_start < -5 else
                                        "EARLY_BOOT_COVERED" if e - boot_start <= 60 else "BUFFER_WRAPPED_BEFORE_FIRST_CONTACT")
except (KeyError, ValueError):
    BOOT_SUMMARY["LOG_COVERAGE"] = "UNKNOWN"
BOOT_SUMMARY["EARLIEST_LOG_SEC_AFTER_BOOT"] = cov

# ---- redaction
RULES = [
    # Keywords must start at a word boundary (so phoneId is not caught by "eid");
    # values already redacted are skipped so re-redaction is idempotent.
    (re.compile(r"(?i)\b(imei|imsi|iccid|meid|msisdn|mLine1Number|phoneNumber|number|mNumber|subscriberId|"
                r"mIccId|cardId|eid|mEid|mImsi|serial|ro\.serialno\])(\s*[=:]\s*\[?)(?!\[*REDACTED)[^\s,}\]\[]+"),
     r"\1\2[REDACTED]"),
    (re.compile(r"(?i)\b(mCi|mCid|mLac|mTac|mNci|mBasestationId|mLatitude|mLongitude|mNetworkId|mSystemId)=(?!\[*REDACTED)[^\s,}\[]+"),
     r"\1=[REDACTED]"),
    (re.compile(r"\+\d{7,15}\b"), "[REDACTED_NUMBER]"),
    (re.compile(r"\b89\d{16,18}[0-9Ff]?\b"), "[REDACTED_ICCID]"),
    (re.compile(r"\b\d{14,17}\b"), "[REDACTED_ID]"),
    (re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"), "[REDACTED_EMAIL]"),
]
serial_rx = re.compile(re.escape(SERIAL)) if SERIAL else None
def redact(text):
    for rx, rep in RULES: text = rx.sub(rep, text)
    if serial_rx: text = serial_rx.sub("[REDACTED_SERIAL]", text)
    return text

for dp, dns, fns in os.walk(RAW):
    rel = os.path.relpath(dp, RAW)
    if rel.startswith(("snapshots", "segments")): continue   # summarised in timeline / stitched streams
    for fn in fns:
        if not fn.endswith((".txt", ".log", ".err", ".tsv")) or fn == "DO_NOT_COMMIT.txt": continue
        src = os.path.join(dp, fn); dst = os.path.join(RED, rel, fn)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(src, errors="replace") as f, open(dst, "w") as g:
            for line in f: g.write(redact(line))

# ---- privacy notice: redaction is best-effort, never a clearance
with open(os.path.join(RED, "PRIVACY_REVIEW_REQUIRED.txt"), "w") as f:
    f.write("""MANUAL PRIVACY REVIEW REQUIRED BEFORE SHARING OR COMMITTING ANYTHING IN THIS DIRECTORY,
THE SUMMARY (.env) OR THE REPORT (.md).

Redaction here is automated pattern matching. It is best-effort, not a privacy clearance.

Patterns applied:
  - key=value identifiers: imei, imsi, iccid, meid, msisdn, line1/phone numbers, subscriberId,
    iccId, cardId, eid, serial, ro.serialno
  - cell identity fields: mCi, mCid, mLac, mTac, mNci, mBasestationId, mLatitude, mLongitude,
    mNetworkId, mSystemId
  - E.164 phone numbers (+ and 7-15 digits), ICCID-shaped numbers, 14-17 digit numbers
  - e-mail addresses, the adb serial passed on the command line

Known NOT covered (review for these explicitly):
  - Wi-Fi SSIDs, BSSIDs, MAC addresses, Bluetooth device names and addresses
  - IP addresses, hostnames, DNS names, URLs with tokens
  - account names, contact names, message or notification text in log lines
  - identifiers printed without a key, split across lines, or in vendor-specific formats
  - cell/location information in free-form vendor or modem logs
  - location inference from PLMN + tracking area + timestamps
  - installed-package lists (dumpsys package, pm list) that reveal personal apps
  - anything in binary files (raw/end/bugreport.zip is never redacted and is not copied here)
""")

# ---- timeline + events
rows = [json.loads(l) for l in open(os.path.join(RAW, "snapshots", "snapshots.jsonl")) if l.strip()]
cols = ["ts", "phone_id", "voice_reg", "data_reg", "data_rat", "ril_data_tech", "nr_state", "nr_channels",
        "display_override", "nr_class", "nr_flags", "wlan_reg", "iwlan_preferred", "data_conn", "data_net_type",
        "mobile_data", "mobile_data1", "mobile_data2", "airplane", "data_roaming", "multi_sim_data_call",
        "preferred_network_mode", "sim_state", "network_type", "operator", "phone_pid", "radio_procs", "registry_ok"]
iso = lambda t: dt.datetime.fromtimestamp(t + offset, dev_tz).strftime("%Y-%m-%d %H:%M:%S")
with open(os.path.join(RED, "timeline.tsv"), "w") as f:
    f.write("device_time\t" + "\t".join(cols) + "\n")
    for r in rows: f.write(iso(r["ts"]) + "\t" + "\t".join(redact(str(r.get(c, "-"))) for c in cols) + "\n")

WATCH = ["voice_reg", "data_reg", "data_rat", "nr_state", "nr_class", "display_override", "wlan_reg",
         "iwlan_preferred", "data_conn", "mobile_data", "mobile_data1",
         "mobile_data2", "airplane", "multi_sim_data_call", "preferred_network_mode", "sim_state",
         "phone_pid", "radio_procs"]
events, prev, first_loss, first_connected = [], {}, None, None
for r in rows:
    p = prev.get(r["phone_id"])
    if r["data_conn"] == "CONNECTED" and first_connected is None: first_connected = r
    if p:
        for k in WATCH:
            if r.get(k) != p.get(k):
                events.append((r["ts"], r["phone_id"], k, p.get(k), r.get(k)))
        lost = (p["data_conn"] == "CONNECTED" and r["data_conn"] != "CONNECTED") or \
               (p["data_reg"] == "IN_SERVICE" and r["data_reg"] != "IN_SERVICE")
        if lost and first_loss is None: first_loss = (r, p)
    prev[r["phone_id"]] = r
with open(os.path.join(RED, "events.tsv"), "w") as f:
    f.write("device_time\tphone_id\tfield\tbefore\tafter\n")
    for e in events: f.write(f"{iso(e[0])}\t{e[1]}\t{e[2]}\t{redact(str(e[3]))}\t{redact(str(e[4]))}\n")

# What else changed in the same snapshot as the first loss? (strong hint at the cause class)
coincident = []
if first_loss:
    t = first_loss[0]["ts"]
    coincident = [e for e in events if abs(e[0] - t) <= int(INTERVAL) and e[2] not in ("data_conn", "data_reg")]

# ---- log window around first data loss (device time)
LOG_TS = re.compile(r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\.\d{3}")
def log_epoch(line):
    m = LOG_TS.match(line)
    if not m: return None
    return dt.datetime.strptime(m.group(1), "%Y-%m-%d %H:%M:%S").replace(tzinfo=dev_tz).timestamp()

stream = os.path.join(RED, "logcat_stream.log")
start_buf = os.path.join(RED, "start", "logcat_buffer.txt")
kernel = os.path.join(RED, "logcat_kernel.log")
log_files = [f for f in (start_buf, stream, kernel) if os.path.exists(f)]
window_path = os.path.join(RED, "data_loss_window.log")
if first_loss:
    # Loss happened between previous snapshot and this one: take 120 s before the previous
    # snapshot through 60 s after the detecting snapshot.
    lo = first_loss[1]["ts"] + offset - 120; hi = first_loss[0]["ts"] + offset + 60
    seen = set()
    with open(window_path, "w") as g:
        g.write(f"# window {iso(lo - offset)} .. {iso(hi - offset)} device time\n")
        for lf in log_files:
            for line in open(lf, errors="replace"):
                e = log_epoch(line)
                if e is not None and lo <= e <= hi and line not in seen:
                    seen.add(line); g.write(line)
else:
    open(window_path, "w").write("# no data loss observed during the capture window\n")

# ---- signature scan
SIGS = [
    ("SELINUX_DENIAL_RADIO", r"avc:\s+denied.*(radio|rild|\bril|ims|phone|telephony|ccci|modem|mdinit|mtk)"),
    ("SELINUX_DENIAL_ANY", r"avc:\s+denied"),
    ("PHONE_PROCESS_CRASH", r"(FATAL EXCEPTION.*|Process: )com\.android\.phone|am_crash.*com\.android\.phone|am_proc_died.*com\.android\.phone"),
    ("NATIVE_CRASH_RADIO", r"(Fatal signal|tombstone|backtrace).*(rild|ril|ims|ccci|mdinit|fusionril|radio)"),
    ("RADIO_HAL_DEATH_OR_MISSING", r"(serviceDied|binderDied|died).*(IRadio|radio|Ims)|(servicemanager|hwservicemanager).*(Could not find|not found|Waited).*(radio|ims|mtk|mediatek)"),
    ("RADIO_NOT_AVAILABLE", r"RADIO_NOT_AVAILABLE|RADIO_UNAVAILABLE|radio.*not available"),
    ("RADIO_POWER_CHANGE", r"setRadioPower|RADIO_POWER|setRadioPowerForReason|radioPower"),
    ("DATA_ENABLED_CHANGE", r"DataSettingsManager|setDataEnabled|onDataEnabledChanged|DataEnabledOverride|userDataEnabled|setMobileDataEnabled"),
    ("DATA_DISCONNECT", r"(DataNetwork|DataConnection|DcTracker).*(disconnect|tear ?down|onDisconnected|tearDown)"),
    ("DATA_FAIL_CAUSE", r"DataFailCause|failCause|fail_cause|SETUP_DATA_CALL.*(fail|error)"),
    ("DATA_RETRY", r"DataRetryManager|data retry"),
    ("NETWORK_UNWANTED", r"onNetworkUnwanted|NetworkAgent.*unwanted|unwanted network"),
    ("CARRIER_CONFIG_RELOAD", r"CarrierConfigLoader|updateConfigForPhoneId|carrier config (changed|loaded)"),
    ("SUBSCRIPTION_CHURN", r"SubscriptionManagerService|onSubscriptionsChanged|subId.*(INVALID|-1)|SubscriptionController"),
    ("SIM_STATE_CHANGE", r"SIM_STATE|IccCardStatus|UiccController|simState|SimState"),
    ("PHONE_SWITCHER_DDS", r"PhoneSwitcher|setPreferredDataSubscriptionId|ddsSwitch|preferred data"),
    ("IMS", r"ImsService|ImsManager|ImsPhone|ImsRegistration|IMS registration"),
    ("THERMAL_OR_POWER_RADIO", r"thermal.*(radio|modem)|RADIO_POWER_REASON_THERMAL|emergency.*radio"),
    ("AIRPLANE_MODE", r"airplane_mode|AIRPLANE_MODE"),
    ("TREBLEDROID_PHH_MTK", r"\bphh\b|trebledroid|MtkIms|mediatek.*ims|mtk.*ims"),
    ("APN_PROBLEM", r"(no|missing|invalid).*apn|ApnSetting.*null|DataProfile.*(null|empty)"),
]
sig_rx = [(n, re.compile(rx, re.I)) for n, rx in SIGS]
counts = {n: 0 for n, _ in SIGS}; first = {n: "" for n, _ in SIGS}; in_window = {n: 0 for n, _ in SIGS}
for lf in log_files:
    for line in open(lf, errors="replace"):
        for n, rx in sig_rx:
            if rx.search(line):
                counts[n] += 1
                if not first[n]: first[n] = line.strip()[:300]
if os.path.exists(window_path):
    for line in open(window_path, errors="replace"):
        for n, rx in sig_rx:
            if rx.search(line): in_window[n] += 1
with open(os.path.join(RED, "signatures.tsv"), "w") as f:
    f.write("signature\tcount_total\tcount_in_loss_window\tfirst_occurrence\n")
    for n, _ in SIGS: f.write(f"{n}\t{counts[n]}\t{in_window[n]}\t{first[n].replace(chr(9), ' ')}\n")

# ---- summary
phone_pids = {r["phone_pid"] for r in rows if r["phone_pid"] != "-"}
rats = sorted({r["data_rat"] for r in rows if r["data_rat"] not in ("-", "UNKNOWN")})
lte_seen = any(r["data_rat"].startswith("LTE") for r in rows)
md_changed = any(e[2].startswith("mobile_data") for e in events)
ap_changed = any(e[2] == "airplane" for e in events)
radio_restarts = sum(1 for e in events if e[2] == "radio_procs")
end_row = {}
for r in rows: end_row[r["phone_id"]] = r
kernel_ok = os.path.exists(kernel) and os.path.getsize(kernel) > 0
summ = {
    "CELLULAR_RUNTIME_CAPTURE": "COMPLETE" if rows else "NO_SNAPSHOTS",
    "CAPTURE_SCRIPT_VERSION": VERSION,
    "CAPTURE_LABEL": LABEL,
    "READ_ONLY": "YES",
    "REDACTION": "AUTOMATED_BEST_EFFORT",
    "PRIVACY_REVIEW": "REQUIRED_BEFORE_SHARING",
    "DEVICE_SETTINGS_CHANGED_BY_SCRIPT": "NO",
    "DEVICE": DEVICE, "MODEL": MODEL, "BUILD_FINGERPRINT": FP,
    "CAPTURE_DURATION_MIN_REQUESTED": DURATION,
    "CAPTURE_STOPPED_EARLY": "YES" if STOPPED == "1" else "NO",
    "SNAPSHOT_COUNT": str(len(rows)),
    "FIRST_DATA_CONNECTED_AT": iso(first_connected["ts"]) if first_connected else "NEVER",
    "FIRST_DATA_LOSS_AT": iso(first_loss[0]["ts"]) if first_loss else "NONE_OBSERVED",
    "FIRST_DATA_LOSS_PHONE_ID": first_loss[0]["phone_id"] if first_loss else "-",
    "FIRST_DATA_LOSS_TRANSITION": (f"{first_loss[1]['data_reg']}/{first_loss[1]['data_conn']}->"
                                   f"{first_loss[0]['data_reg']}/{first_loss[0]['data_conn']}") if first_loss else "-",
    "COINCIDENT_CHANGES_AT_LOSS": ";".join(f"{e[2]}:{e[3]}->{e[4]}" for e in coincident) or "-",
    "PHONE_PROCESS_PIDS_SEEN": str(len(phone_pids)),
    "PHONE_PROCESS_RESTARTED": "YES" if len(phone_pids) > 1 else "NO",
    "RADIO_DAEMON_PID_CHANGES": str(radio_restarts),
    "MOBILE_DATA_SETTING_CHANGED": "YES" if md_changed else "NO",
    "AIRPLANE_MODE_CHANGED": "YES" if ap_changed else "NO",
    "DATA_RATS_OBSERVED": ",".join(rats) or "-",
    "LTE_OBSERVED": "YES" if lte_seen else "NO",
    # Real NR = SA (RAT NR) or NSA (nrState CONNECTED / NR serving channel). A 5G icon alone is not NR.
    "NR_OBSERVED": "YES" if any(r.get("nr_class") in ("NR_SA", "NR_NSA_CONNECTED") for r in rows) else "NO",
    "NR_SA_SNAPSHOTS": str(sum(1 for r in rows if r.get("nr_class") == "NR_SA")),
    "NR_NSA_CONNECTED_SNAPSHOTS": str(sum(1 for r in rows if r.get("nr_class") == "NR_NSA_CONNECTED")),
    "NR_ANCHOR_ONLY_SNAPSHOTS": str(sum(1 for r in rows if r.get("nr_class") == "NR_ANCHOR_ONLY")),
    "DISPLAY_5G_WITHOUT_NR_SNAPSHOTS": str(sum(1 for r in rows if "DISPLAY_5G_WITHOUT_NR" in r.get("nr_flags", ""))),
    "PHYSICAL_CHANNEL_REPORTS": "NO" if rows and all("NO_PHYSICAL_CHANNEL_REPORTS" in r.get("nr_flags", "") for r in rows) else "YES",
    "END_STATE": ";".join(f"phone{k}:{v['voice_reg']}/{v['data_reg']}/{v['data_conn']}/{v['data_rat']}" for k, v in sorted(end_row.items())) or "-",
    "KERNEL_LOG_CAPTURED": "YES" if kernel_ok else "NO_NOT_READABLE_AS_SHELL",
    "ROOT_CAUSE_CONCLUDED": "NO",
}
for n, _ in SIGS: summ[f"SIG_{n}"] = f"{counts[n]}/{in_window[n]}"
summ.update({k: v for k, v in BOOT_SUMMARY.items() if k not in summ})
with open(os.path.join(OUT, "CELLULAR_RUNTIME_SUMMARY.env"), "w") as f:
    for k, v in summ.items(): f.write(f"{k}={redact(str(v))}\n")

# ---- report
def tbl(rows, cols):
    o = ["| " + " | ".join(cols) + " |", "|" + "---|" * len(cols)]
    for r in rows: o.append("| " + " | ".join(str(x).replace("|", "\\|")[:200] for x in r) + " |")
    return "\n".join(o)
hints = []
if md_changed: hints.append("Mobile-data setting changed during capture → check Settings / Network Manager policy and DATA_ENABLED_CHANGE lines.")
if ap_changed: hints.append("Airplane mode changed during capture → confirm it was not user-initiated.")
if len(phone_pids) > 1: hints.append("com.android.phone restarted → see PHONE_PROCESS_CRASH and dropbox.txt.")
if radio_restarts: hints.append("A radio/IMS daemon PID changed → vendor service crash; check NATIVE_CRASH_RADIO and RADIO_HAL_DEATH_OR_MISSING.")
if in_window["SELINUX_DENIAL_RADIO"]: hints.append("SELinux denials involving radio domains inside the loss window.")
if in_window["CARRIER_CONFIG_RELOAD"] or in_window["SUBSCRIPTION_CHURN"]: hints.append("Carrier config reload / subscription change inside the loss window → CarrierConfig/APN or SIM provisioning class.")
if in_window["DATA_FAIL_CAUSE"] or in_window["APN_PROBLEM"]: hints.append("Data fail cause or APN problem inside the loss window → compare APN entries with the static audit.")
if in_window["RADIO_POWER_CHANGE"] or in_window["RADIO_NOT_AVAILABLE"]: hints.append("Radio power / availability change inside the loss window → radio HAL or modem state.")
if not first_loss: hints.append("No data loss observed. Extend --duration-min or reproduce the trigger (screen off, reboot, SIM reinsert).")
with open(os.path.join(OUT, "CELLULAR_RUNTIME_REPORT.md"), "w") as f:
    f.write(f"# Cellular runtime capture — {LABEL}\n\n")
    f.write("Read-only capture; no settings changed by the script.\n\n"
            "**Privacy: manual review required before sharing or committing.** This report and `redacted/` "
            "went through automated, best-effort pattern redaction only; see `redacted/PRIVACY_REVIEW_REQUIRED.txt`. "
            "`raw/` is unredacted and must stay local.\n\n")
    f.write("## Summary\n\n" + tbl([(k, redact(str(v))) for k, v in summ.items() if not k.startswith("SIG_")], ["key", "value"]) + "\n\n")
    tlp = os.path.join(RAW, "boot_timeline.tsv")
    if os.path.exists(tlp):
        tl_rows = [l.rstrip("\n").split("\t") for l in open(tlp).readlines()[1:] if l.strip()]
        f.write("## Boot capture timeline\n\n" + tbl([(dt.datetime.fromtimestamp(int(r[0])).strftime("%H:%M:%S"), r[1], r[2] if len(r) > 2 else "")
                                                   for r in tl_rows], ["host time", "event", "detail"]) + "\n\n")
    f.write("## Starting points (not conclusions)\n\n" + ("\n".join(f"- {h}" for h in hints) or "- None triggered.") + "\n\n")
    f.write("## Changes coinciding with first data loss\n\n")
    f.write(tbl([(iso(e[0]), e[1], e[2], redact(str(e[3])), redact(str(e[4]))) for e in coincident],
                ["device time", "phone", "field", "before", "after"]) + "\n\n" if coincident else "None, or no loss observed.\n\n")
    f.write("## Signatures (total / inside loss window)\n\n")
    f.write(tbl([(n, counts[n], in_window[n], redact(first[n])[:160]) for n, _ in SIGS if counts[n]],
                ["signature", "total", "in window", "first occurrence"]) + "\n\n")
    f.write(f"## State transitions ({len(events)})\n\n")
    f.write(tbl([(iso(e[0]), e[1], e[2], redact(str(e[3])), redact(str(e[4]))) for e in events[:200]],
                ["device time", "phone", "field", "before", "after"]) + "\n\n")
    f.write("## Files\n\n- `redacted/timeline.tsv` every snapshot\n- `redacted/events.tsv` every transition\n"
            "- `redacted/data_loss_window.log` logs from 120 s before to 60 s after the first loss\n"
            "- `redacted/signatures.tsv` pattern counts\n- `redacted/start/`, `redacted/end/` service dumps\n")
print(os.path.join(OUT, "CELLULAR_RUNTIME_REPORT.md"))
PYEOF

log "done: $OUT"
echo "SUMMARY=$OUT/CELLULAR_RUNTIME_SUMMARY.env"
echo "REPORT=$OUT/CELLULAR_RUNTIME_REPORT.md"
