#!/usr/bin/env bash
# N1I-B capture-script CLI / identity-gate / end-to-end self-test against a FAKE adb.
# No real device is contacted: PATH is rebuilt so that `adb` resolves to lib/fake-adb, and the
# fake logs every invocation so the tests can prove what was (not) sent.
#   --quick   skip the three ~65 s end-to-end runs
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$HERE/lib/common.sh"
ROOT="$(git -C "$HERE" rev-parse --show-toplevel)"
SCRIPT="$ROOT/build/titan2/capture-n1b2-cellular-runtime.sh"
SANITIZER="$ROOT/build/titan2/sanitize-n1i-stock-control.py"
CTL="$ROOT/build/titan2/n1i-f-stock-v010014-control.env"
C=capture_cli
QUICK=0; [[ "${1:-}" == "--quick" ]] && QUICK=1

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
cp "$HERE/lib/fake-adb" "$TMP/bin/adb"; chmod +x "$TMP/bin/adb"
BASH_BIN="$(command -v bash)"
SAFE_PATH="$TMP/bin:/usr/bin:/bin"
NOADB_PATH="$TMP/noadb"; mkdir -p "$NOADB_PATH"
for t in python3 sha256sum timeout date sed awk grep cut tr wc mkdir cat sleep dirname basename mktemp rm touch printf; do
  p="$(command -v "$t" 2>/dev/null)" && ln -sf "$p" "$NOADB_PATH/$t"
done
SYS_FP="$(sed -n 's/^STOCK_BUILD_FINGERPRINT=//p' "$CTL")"
VEN_FP="$(sed -n 's/^STOCK_VENDOR_FINGERPRINT=//p' "$CTL")"
SERIAL=SYNTHSERIAL0003
SHA_OK="$(printf 'synthetic-c3a-artifact' | sha256sum | cut -d' ' -f1)"
VBMETA="ab01234567890123456cd0f1e2d3c4b5a69788796a5b4c3d2e1f00112233aabb"

mkprops() { # name sysfp venfp type debuggable vbmeta slot
  cat > "$TMP/$1.props" <<EOF
ro.build.fingerprint=$2
ro.vendor.build.fingerprint=$3
ro.build.type=$4
ro.debuggable=$5
ro.boot.vbmeta.digest=$6
ro.boot.slot_suffix=$7
ro.serialno=$SERIAL
ro.product.device=Titan_2
ro.product.model=Titan 2
sys.boot_completed=1
gsm.sim.state=LOADED,ABSENT
EOF
}
mkprops stock "$SYS_FP" "$VEN_FP" user 0 "$VBMETA" _a
mkprops stock_badvendor "$SYS_FP" "Unihertz/Titan_2/Titan_2:14/UP1A.231005.007/V01.00.13:user/release-keys" user 0 "$VBMETA" _a
mkprops stock_debuggable "$SYS_FP" "$VEN_FP" user 1 "$VBMETA" _a
mkprops stock_userdebug "$SYS_FP" "$VEN_FP" userdebug 0 "$VBMETA" _a
mkprops c3a "SableOS/c3a/tdgsi_arm64_ab:16/BP2A/eng.synthetic:userdebug/test-keys" "$VEN_FP" userdebug 1 "$VBMETA" _a
mkprops c3a_is_stock "$SYS_FP" "$VEN_FP" user 0 "$VBMETA" _a
mkprops c3a_novbmeta "SableOS/c3a/tdgsi_arm64_ab:16/BP2A/eng.synthetic:userdebug/test-keys" "$VEN_FP" userdebug 1 "" _a

# run NAME PROPS PATH args... -> sets RC, OUTD, ALOG
run() {
  local name="$1" props="$2" path="$3"; shift 3
  OUTD="$TMP/out-$name"; ALOG="$TMP/adb-$name.log"; : > "$ALOG"
  env -i HOME="$TMP" PATH="$path" FAKE_ADB_LOG="$ALOG" FAKE_PROPS="$TMP/$props.props" FAKE_SERIAL="$SERIAL" \
    "$BASH_BIN" "$SCRIPT" --serial "$SERIAL" --label "t-$name" --out "$OUTD" "$@" > "$TMP/$name.stdout" 2> "$TMP/$name.stderr"
  RC=$?
}
ok() { [[ "$1" ]] && echo 1 || echo 0; }

# ---- usage-level refusals: exit 2 and zero adb invocations
usage_case() { # id path expected_rc args...
  local id="$1" path="$2" want="$3"; shift 3
  run "$id" stock "$path" "$@"
  local n; n=$(wc -l < "$ALOG" | tr -d ' ')
  case_result $C "$id" "$([[ $RC -eq $want && $n -eq 0 ]] && echo 1 || echo 0)" "rc=$RC want=$want adb_calls=$n"
}
usage_case b1_bugreport_refused_no_adb_on_path "$NOADB_PATH" 2 --profile n1i-b1 --b1-target stock --bugreport
usage_case b1_bugreport_refused_fake_adb_untouched "$SAFE_PATH" 2 --profile n1i-b1 --b1-target stock --bugreport
usage_case b1_bugreport_before_target_refused "$SAFE_PATH" 2 --bugreport --profile n1i-b1 --b1-target c3a --c3a-artifact-sha256 "$SHA_OK"
usage_case default_with_b1_target_refused "$SAFE_PATH" 2 --b1-target stock
usage_case default_with_c3a_sha_refused "$SAFE_PATH" 2 --c3a-artifact-sha256 "$SHA_OK"
usage_case b1_without_target_refused "$SAFE_PATH" 2 --profile n1i-b1
usage_case b1_bad_target_refused "$SAFE_PATH" 2 --profile n1i-b1 --b1-target root
usage_case c3a_without_sha_refused "$SAFE_PATH" 2 --profile n1i-b1 --b1-target c3a
usage_case c3a_uppercase_sha_refused "$SAFE_PATH" 2 --profile n1i-b1 --b1-target c3a --c3a-artifact-sha256 "${SHA_OK^^}"
usage_case c3a_short_sha_refused "$SAFE_PATH" 2 --profile n1i-b1 --b1-target c3a --c3a-artifact-sha256 abc123
usage_case c3a_bad_ref_refused "$SAFE_PATH" 2 --profile n1i-b1 --b1-target c3a --c3a-artifact-sha256 "$SHA_OK" --c3a-artifact-ref 'x;reboot'
usage_case stock_with_c3a_sha_refused "$SAFE_PATH" 2 --profile n1i-b1 --b1-target stock --c3a-artifact-sha256 "$SHA_OK"
usage_case unknown_profile_refused "$SAFE_PATH" 2 --profile root
usage_case adb_root_flag_unknown "$SAFE_PATH" 2 --profile n1i-b1 --b1-target stock --adb-root
usage_case root_flag_unknown "$SAFE_PATH" 2 --root
usage_case su_flag_unknown "$SAFE_PATH" 2 --su

# ---- static: no adb-root path exists in the script
subs="$(grep -oE 'adb -s "\$SERIAL" [a-z-]+' "$SCRIPT" | awk '{print $4}' | sort -u | tr '\n' ' ')"
case_result $C static_adb_subcommands_only_shell_bugreport "$([[ "$subs" == "bugreport shell " ]] && echo 1 || echo 0)" "subcommands: $subs"
hits="$(grep -nE '(^|[^-])\badb\b[^#]*\b(root|unroot|remount|disable-verity|reboot|sideload|install|push)\b' "$SCRIPT" | grep -vE '^\s*[0-9]+:\s*#' | grep -vE 'reboot (it|the phone)|PRODUCT_ADB_KEYS|fastboot reboot' || true)"
case_result $C static_no_adb_root_or_mutating_subcommand "$([[ -z "$hits" ]] && echo 1 || echo 0)" "${hits:-none}"
case_result $C static_no_su_invocation "$(ok "$(! grep -nE '(adb_ro|adb_try [0-9]+|b1_run [^ ]+ [^ ]+) "su( |")' "$SCRIPT" >/dev/null && echo y)")" "no su command issued"

# ---- identity gate: mismatch exits 6 before any dump
gate_case() { # id props want_reason args...
  local id="$1" props="$2" reason="$3"; shift 3
  run "$id" "$props" "$SAFE_PATH" --profile n1i-b1 --interval-sec 2 --duration-min 1 "$@"
  local s="$OUTD/CELLULAR_RUNTIME_SUMMARY.env"
  local dumped=0; [[ -e "$OUTD/raw/start/getprop.txt" ]] && dumped=1
  local r; r="$(sed -n 's/^B1_IDENTITY_GATE_REASONS=//p' "$s" 2>/dev/null)"
  local nonshell; nonshell=$(awk -F'\x1f' '$1!="devices" && $3!="shell"' "$ALOG" | wc -l | tr -d ' ')
  case_result $C "$id" "$([[ $RC -eq 6 && $dumped -eq 0 && "$r" == *"$reason"* && $nonshell -eq 0 ]] && grep -q '^CELLULAR_RUNTIME_CAPTURE=IDENTITY_GATE_FAILED$' "$s" && echo 1 || echo 0)" "rc=$RC reasons=$r dumped=$dumped nonshell_adb=$nonshell"
}
gate_case gate_stock_vendor_mismatch stock_badvendor VENDOR_FINGERPRINT_MISMATCH --b1-target stock
gate_case gate_stock_debuggable stock_debuggable DEBUGGABLE_NOT_0 --b1-target stock
gate_case gate_stock_userdebug stock_userdebug BUILD_TYPE_NOT_USER --b1-target stock
gate_case gate_stock_target_on_c3a_device c3a SYSTEM_FINGERPRINT_MISMATCH --b1-target stock
gate_case gate_c3a_target_on_stock_device c3a_is_stock SYSTEM_FINGERPRINT_IS_STOCK --b1-target c3a --c3a-artifact-sha256 "$SHA_OK"
gate_case gate_c3a_missing_vbmeta c3a_novbmeta VBMETA_DIGEST_UNREADABLE --b1-target c3a --c3a-artifact-sha256 "$SHA_OK"

if [[ "$QUICK" -eq 1 ]]; then
  case_result $C end_to_end_runs 1 "SKIPPED_BY_--quick (not counted as evidence)"
  exit $(( N1IB_FAILS > 0 ? 1 : 0 ))
fi

# ---- end-to-end runs (about 65 s each, run in parallel)
( run e2e_stock stock "$SAFE_PATH" --profile n1i-b1 --b1-target stock --interval-sec 2 --duration-min 1; echo "$RC" > "$TMP/e2e_stock.rc" ) &
( run e2e_c3a c3a "$SAFE_PATH" --profile n1i-b1 --b1-target c3a --c3a-artifact-sha256 "$SHA_OK" --c3a-artifact-ref c3a-synthetic.img \
      --interval-sec 2 --duration-min 1; echo "$RC" > "$TMP/e2e_c3a.rc" ) &
( run e2e_default stock "$SAFE_PATH" --interval-sec 2 --duration-min 1 --bugreport; echo "$RC" > "$TMP/e2e_default.rc" ) &
wait

source "$TMP/new_guard.sh" 2>/dev/null || {
  { extract_fn "$SCRIPT" is_read_only; extract_array "$SCRIPT" B1_EXTRA_CMDS
    extract_fn "$SCRIPT" is_b1_extra; extract_fn "$SCRIPT" is_read_only_b1; extract_fn "$SCRIPT" guard_ok; } > "$TMP/new_guard.sh"
  # shellcheck source=/dev/null
  source "$TMP/new_guard.sh"
}
all_shell_cmds_guarded() { # log profile
  local bad=0 c
  while IFS= read -r c; do
    PROFILE="$2" guard_ok "$c" || { bad=$((bad + 1)); echo "  unguarded: $c" >&2; }
  done < <(awk -F'\x1f' '$3=="shell"{print $4}' "$1")
  echo "$bad"
}

for t in stock c3a; do
  OUTD="$TMP/out-e2e_$t"; ALOG="$TMP/adb-e2e_$t.log"; S="$OUTD/CELLULAR_RUNTIME_SUMMARY.env"
  rc="$(cat "$TMP/e2e_$t.rc")"
  case_result $C "e2e_${t}_exit0" "$([[ "$rc" == 0 ]] && echo 1 || echo 0)" "rc=$rc"
  case_result $C "e2e_${t}_gate_pass" "$(grep -q '^B1_IDENTITY_GATE=PASS$' "$S" && echo 1 || echo 0)" "summary B1_IDENTITY_GATE"
  case_result $C "e2e_${t}_profile_recorded" "$(grep -q '^CAPTURE_PROFILE=n1i-b1$' "$S" && echo 1 || echo 0)" "summary CAPTURE_PROFILE"
  want_sha="$(printf '%s' "$SERIAL" | sha256sum | cut -d' ' -f1)"
  case_result $C "e2e_${t}_serial_sha_recorded" "$(grep -q "^B1_SERIAL_SHA256=$want_sha$" "$S" && echo 1 || echo 0)" "sha256(serial)"
  case_result $C "e2e_${t}_raw_serial_not_in_summary" "$(! grep -q "$SERIAL" "$S" && echo 1 || echo 0)" "summary is serial-free"
  miss=0
  for cp in T1 T3; do
    for slug in ims_pm_path ims_activity_services telephony_debug_service lshal_types_bcl ims_get_s0_device \
                ims_get_s0_carrier ims_get_s1_device ims_get_s1_carrier apn_preferapn siminfo \
                apn_carriers_310260_310240 getprop telephony_registry carrier_config isub logcat_radio; do
      for ext in txt err rc; do [[ -f "$OUTD/raw/b1/$cp/$slug.$ext" ]] || miss=$((miss + 1)); done
    done
  done
  case_result $C "e2e_${t}_t1_t3_inventory_complete" "$([[ $miss -eq 0 ]] && echo 1 || echo 0)" "missing=$miss (16 commands x txt/err/rc x T1,T3)"
  case_result $C "e2e_${t}_rc_and_stderr_kept" "$([[ "$(cat "$OUTD/raw/b1/T1/lshal_types_bcl.rc" 2>/dev/null)" == 3 ]] && grep -q 'stderr line' "$OUTD/raw/b1/T1/lshal_types_bcl.err" && echo 1 || echo 0)" "lshal fake rc=3 + stderr preserved"
  case_result $C "e2e_${t}_t2_not_reached_recorded" "$(grep -q '^B1_CHECKPOINT_T2=NOT_REACHED' "$S" && echo 1 || echo 0)" "1-minute run cannot reach T1+600s"
  nb="$(all_shell_cmds_guarded "$ALOG" n1i-b1)"
  case_result $C "e2e_${t}_every_sent_command_guard_approved" "$([[ "$nb" == 0 ]] && echo 1 || echo 0)" "unguarded=$nb sent=$(awk -F'\x1f' '$3=="shell"' "$ALOG" | wc -l | tr -d ' ')"
  ns=$(awk -F'\x1f' '$1!="devices" && $3!="shell"' "$ALOG" | wc -l | tr -d ' ')
  case_result $C "e2e_${t}_no_non_shell_adb_subcommand" "$([[ "$ns" == 0 ]] && echo 1 || echo 0)" "non-shell adb calls=$ns (no bugreport/root/reboot)"
  if python3 "$SANITIZER" --tree "$OUTD/raw/b1" "$TMP/san-$t" --serial "$SERIAL" > "$TMP/san-$t.log" 2>&1; then sr=1; else sr=0; fi
  case_result $C "e2e_${t}_b1_tree_sanitizes_pass" "$sr" "$(tail -1 "$TMP/san-$t.log")"
  case_result $C "e2e_${t}_sanitized_has_no_synthetic_iccid" "$(! grep -rq '89012400000000000033' "$TMP/san-$t" 2>/dev/null && [[ $sr == 1 ]] && echo 1 || echo 0)" "planted siminfo ICCID removed"
done
S="$TMP/out-e2e_c3a/raw/b1/identity.env"
case_result $C e2e_c3a_identity_recorded "$(grep -q "^B1_C3A_ARTIFACT_SHA256_HOST_ASSERTED=$SHA_OK$" "$S" && grep -q '^B1_BLOCK_HASH_EQUIVALENCE=NOT_CLAIMED$' "$S" && grep -q "^B1_DEVICE_VBMETA_DIGEST=$VBMETA$" "$S" && grep -q '^B1_DEVICE_SLOT_SUFFIX=_a$' "$S" && echo 1 || echo 0)" "host-asserted sha, NOT_CLAIMED, vbmeta, slot"

# default profile: legacy behaviour (no B1 dir, no extras sent, bugreport still requested)
OUTD="$TMP/out-e2e_default"; ALOG="$TMP/adb-e2e_default.log"; S="$OUTD/CELLULAR_RUNTIME_SUMMARY.env"
rc="$(cat "$TMP/e2e_default.rc")"
case_result $C e2e_default_exit0 "$([[ "$rc" == 0 ]] && echo 1 || echo 0)" "rc=$rc"
case_result $C e2e_default_no_b1_artifacts "$([[ ! -e "$OUTD/raw/b1" ]] && ! grep -q '^CAPTURE_PROFILE=' "$S" && ! grep -q '^B1_' "$S" && echo 1 || echo 0)" "no raw/b1, no B1 keys"
nx=0; for x in "${B1_EXTRA_CMDS[@]}"; do awk -F'\x1f' -v c="$x" '$3=="shell" && $4==c{f=1} END{exit !f}' "$ALOG" && nx=$((nx + 1)); done
case_result $C e2e_default_no_extra_commands_sent "$([[ $nx == 0 ]] && echo 1 || echo 0)" "extras sent=$nx"
nb="$(all_shell_cmds_guarded "$ALOG" default)"
case_result $C e2e_default_every_sent_command_guard_approved "$([[ "$nb" == 0 ]] && echo 1 || echo 0)" "unguarded=$nb"
case_result $C e2e_default_bugreport_still_honoured "$(awk -F'\x1f' '$3=="bugreport"{f=1} END{exit !f}' "$ALOG" && echo 1 || echo 0)" "legacy --bugreport path unchanged"

exit $(( N1IB_FAILS > 0 ? 1 : 0 ))
