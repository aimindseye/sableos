#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DERIVER="$ROOT/build/titan2/derive-n1i-c1-runtime-classpath.py"
AUDIT="$ROOT/build/titan2/audit-n1i-c1-runtime-linkage.py"
DRIVER="$ROOT/build/titan2/run-n1i-c1-runtime-linkage-audit.sh"
APEX_PARITY="$ROOT/build/titan2/audit-n1i-c1-apex-runtime-parity.py"
GAP_CLASSIFIER="$ROOT/build/titan2/audit-n1i-c1-member-gap-classification.py"
HOST_TOOLS_PROFILE="$ROOT/build/config/host-tools.env"

fail() {
  echo "N1I_C1_RUNTIME_LINKAGE_TEST_$1=FAIL"
  exit 1
}

pass() {
  echo "N1I_C1_RUNTIME_LINKAGE_TEST_$1=PASS"
}

has_fixed_marker() {
  local marker="$1"
  local file="$2"
  grep -Fq -- "$marker" "$file"
}

GREP_PATTERN_PROBE="$(mktemp)"
trap 'rm -f "$GREP_PATTERN_PROBE"' EXIT
printf '%s\n' '--leading-dash-marker' > "$GREP_PATTERN_PROBE"
has_fixed_marker '--leading-dash-marker' "$GREP_PATTERN_PROBE" ||
  fail LEADING_DASH_MARKER_SAFE
pass LEADING_DASH_MARKER_SAFE

[[ -f "$DERIVER" ]] || fail DERIVER_PRESENT
[[ -f "$AUDIT" ]] || fail AUDIT_PRESENT
[[ -f "$DRIVER" ]] || fail DRIVER_PRESENT
[[ -f "$APEX_PARITY" ]] || fail APEX_PARITY_PRESENT
[[ -f "$GAP_CLASSIFIER" ]] || fail GAP_CLASSIFIER_PRESENT
[[ -f "$HOST_TOOLS_PROFILE" ]] || fail HOST_TOOLS_PROFILE_PRESENT

source "$HOST_TOOLS_PROFILE"
[[ -x "$SABLE_PYTHON" ]] || fail CANONICAL_PYTHON_EXECUTABLE
AAPT2="$SABLE_ANDROID_BUILD_TOOLS/aapt2"
[[ -x "$AAPT2" ]] || fail CANONICAL_AAPT2_EXECUTABLE
pass CANONICAL_HOST_TOOLS

bash -n "$DRIVER" || fail DRIVER_SYNTAX
pass DRIVER_SYNTAX

"$SABLE_PYTHON" - "$DERIVER" "$AUDIT" "$APEX_PARITY" "$GAP_CLASSIFIER" <<'PY'
from pathlib import Path
import sys
for raw in sys.argv[1:]:
    p = Path(raw)
    compile(p.read_text(encoding="utf-8"), str(p), "exec")
PY
pass DERIVER_AND_AUDIT_SYNTAX

"$SABLE_PYTHON" "$APEX_PARITY" --selftest
pass APEX_PARITY_SELFTEST

"$SABLE_PYTHON" "$GAP_CLASSIFIER" --selftest
pass GAP_CLASSIFIER_SELFTEST

"$SABLE_PYTHON" "$DERIVER" --selftest
pass DERIVER_SELFTEST

for marker in \
  'n1i-b2-members.py' \
  'def load_members_tool' \
  'emit_target("COMMON", *common)' \
  'emit_target("IMS_BASE", *imsbase)' \
  'emit_target("IMS_APK", *app)' \
  'FAIL_UNRESOLVED_MEMBERS' \
  'PASS_ALL_RESOLVED' \
  'N1I_C1_LINKAGE_IMPORTED_BOOT_DUPLICATE_CLASS_COUNT=' \
  'def duplicate_involves_import' \
  'unmodeled_required_uses_libraries=' \
  'unmodeled_static_uses_library=' \
  'OMITTED_OPTIONAL_MINIMAL_MODEL' \
  'N1I_C1_LINKAGE_REQUIRED_USES_LIBRARY_COUNT=' \
  'N1I_C1_LINKAGE_OPTIONAL_USES_LIBRARY_COUNT=' \
  'Boot-loader code must never resolve against app-loader classes.' \
  'def require_core_runtime' \
  'N1I_C1_LINKAGE_RUNTIME_CORE_SANITY=PASS' \
  'REPORT_ONLY_PARENT_FIRST_ART'
do
  has_fixed_marker "$marker" "$AUDIT" || fail REQUIRED_AUDIT_MARKERS
done
pass REQUIRED_AUDIT_MARKERS

for marker in \
  'source "$HOST_TOOLS_PROFILE"' \
  'AAPT2="$SABLE_ANDROID_BUILD_TOOLS/aapt2"' \
  '"$AAPT2" dump badging "$IMS_APK"' \
  'N1I_C1_AAPT2_AUTHORITY=SABLE_ANDROID_BUILD_TOOLS' \
  'EXPECTED_N1I_A_AUDIT_BLOB="02f7b7330b468a31be8cfc60551673cad127313e"' \
  'C3A_HISTORY="/srv/sable-build/artifacts/titan2/c3a-boot-qualified/20261003T221350Z"' \
  'N1I_C1_RUNTIME_LINKAGE_CONTROL=SEALED_C3A_HISTORY_PLUS_PROVEN_N1I_A_REPLAY' \
  'git -C "$ROOT" hash-object "$N1I_A_AUDIT"' \
  'sha256sum -c SHA256SUMS.txt' \
  'bash "$N1I_A_AUDIT"' \
  'STOCK_REF_AUTHORITY="N1I_A_AUTO_RESOLVE_CONFIGURED_TEE14"' \
  'echo "N1I_C1_STOCK_REF_AUTHORITY=$STOCK_REF_AUTHORITY"' \
  'stock-ref-resolution.txt' \
  'N1I_C1_STOCK_REF_RESOLVED=' \
  '--c3a-system "$C3A_SYSTEM"' \
  'N1I_C1_N1I_A_REPLAY_PARITY=PASS' \
  'N1I_C1_N1I_A_A3_FRAMEWORK_PARITY=PASS_EXACT' \
  '"$SABLE_PYTHON" "$APEX_PARITY"' \
  '--v6-evidence "$OUT"' \
  '--out "$APEX_PARITY_DIR"' \
  'sha256sum -c SHA256SUMS.txt' \
  'N1I_C1_APEX_JAVA_BOOT_RUNTIME_PARITY=PASS_EXACT_SEALED' \
  '--apex-parity-evidence "$APEX_PARITY_DIR"' \
  '"$SABLE_PYTHON" "$DERIVER"' \
  '"$SABLE_PYTHON" "$AUDIT"' \
  'runtime-classpath-derivation.txt' \
  'bootclasspath-sha256.tsv' \
  'sha256sum "$host"'
do
  has_fixed_marker "$marker" "$DRIVER" || fail REQUIRED_DRIVER_MARKERS
done
pass REQUIRED_DRIVER_MARKERS

if grep -Eq -- '(^|[^A-Za-z_])(adb|fastboot)[[:space:](]' "$DERIVER" "$AUDIT" "$DRIVER" "$APEX_PARITY" "$GAP_CLASSIFIER"; then
  fail NO_DEVICE_COMMANDS
fi
pass NO_DEVICE_COMMANDS

if grep -Eq -- 'curl|wget|requests|urllib|socket|git[[:space:]]+(fetch|pull|clone)|http://|https://' "$APEX_PARITY"; then
  fail APEX_PARITY_NO_NETWORK
fi
pass APEX_PARITY_NO_NETWORK

if grep -Eq -- 'curl|wget|requests|urllib|socket|git[[:space:]]+(fetch|pull|clone)|http://|https://' "$GAP_CLASSIFIER"; then
  fail GAP_CLASSIFIER_NO_NETWORK
fi
pass GAP_CLASSIFIER_NO_NETWORK

if grep -Eq -- 'curl|wget|requests|urllib|socket|subprocess|git[[:space:]]+(fetch|pull|clone)|http://|https://' "$DERIVER" "$AUDIT" "$DRIVER"; then
  fail NO_NETWORK
fi
pass NO_NETWORK

if grep -Eq -- 'fastboot[[:space:]].*(flash|erase|format|reboot)|adb[[:space:]].*(reboot|push)|mount[[:space:]].*-o[[:space:]]*(rw|remount)' "$DERIVER" "$AUDIT" "$DRIVER"; then
  fail NO_MUTATION_SURFACE
fi
pass NO_MUTATION_SURFACE

COMMON_ANALYZE_LINE="$(grep -nF -- 'common = analyze_container(' "$AUDIT" | cut -d: -f1 | head -n1)"
IMSBASE_ANALYZE_LINE="$(grep -nF -- 'imsbase = analyze_container(' "$AUDIT" | cut -d: -f1 | head -n1)"
APP_ADD_LINE="$(grep -nF -- 'world.add(ims, "app", "APP")' "$AUDIT" | cut -d: -f1 | head -n1)"
if [[ "$COMMON_ANALYZE_LINE" =~ ^[0-9]+$ &&
      "$IMSBASE_ANALYZE_LINE" =~ ^[0-9]+$ &&
      "$APP_ADD_LINE" =~ ^[0-9]+$ &&
      "$COMMON_ANALYZE_LINE" -lt "$APP_ADD_LINE" &&
      "$IMSBASE_ANALYZE_LINE" -lt "$APP_ADD_LINE" ]]; then
  pass BOOT_ANALYZED_BEFORE_APP_WORLD
else
  fail BOOT_ANALYZED_BEFORE_APP_WORLD
fi

for marker in \
  'Uses the retained N1I-A stock/C3A work tree as the qualified APEX extraction' \
  'Android derive_classpath merge order is reproduced:' \
  'com.android.art' \
  'c1_system_bootclasspath_not_c3a_plus_imports' \
  'validate_apex_parity(' \
  'find_extracted_apex_root(' \
  'system_apex_modules = {' \
  'runtime_apex_modules = fragment_modules | system_apex_modules' \
  'apex_parity_module_set_mismatch=' \
  'apex_parity_boot_jar_device_set_mismatch=' \
  'apex_parity_seal_mismatch=' \
  'apex_parity_sealed_path_escape=' \
  'apex_parity_count_invalid=' \
  'apex_parity_product_out_binding_mismatch=' \
  'apex_parity_v6_binding_mismatch=' \
  'apex_fragment_exports_non_apex_path=' \
  'apex_fragment_cross_module_export=' \
  'retained_n1i_a_input_missing=' \
  'N1I_C1_RUNTIME_CLASSPATH_N1I_A_AUTHORITY=PASS' \
  'N1I_C1_RUNTIME_CLASSPATH_C3A_SYSTEM_DELTA=PASS_EXACT_PLUS_TWO_MTK' \
  'N1I_C1_RUNTIME_CLASSPATH_APEX_BOOT_JAR_PARITY=' \
  'PASS_EXACT_C1_JAVA_RUNTIME' \
  'N1I_C1_RUNTIME_CLASSPATH_APEX_OUTER_MISMATCH_COUNT=' \
  'N1I_C1_RUNTIME_CLASSPATH_APEX_PAYLOAD_MISMATCH_COUNT=' \
  'N1I_C1_RUNTIME_CLASSPATH_ART_ENTRY_COUNT=' \
  'N1I_C1_RUNTIME_CLASSPATH_APEX_ENTRY_COUNT=' \
  'N1I_C1_RUNTIME_CLASSPATH_DERIVATION=PASS'
do
  has_fixed_marker "$marker" "$DERIVER" || fail REQUIRED_DERIVER_MARKERS
done
pass REQUIRED_DERIVER_MARKERS

if grep -Fq -- 'c1_apex_differs_from_c3a=' "$DERIVER" ||
   grep -Fq -- 'N1I_C1_RUNTIME_CLASSPATH_APEX_ARCHIVE_MATCH=PASS' "$DERIVER"; then
  fail WHOLE_APEX_ARCHIVE_PROXY_RETIRED
fi
pass WHOLE_APEX_ARCHIVE_PROXY_RETIRED

if grep -Fq -- 'system_fragment_apex_module_not_retained=' "$DERIVER"; then
  fail SYSTEM_FRAGMENT_APEX_REQUIRES_OWN_FRAGMENT
fi
pass SYSTEM_FRAGMENT_APEX_INDEPENDENT_AUTHORITY

if ! has_fixed_marker '--apex-parity-evidence' "$DERIVER" ||
   ! has_fixed_marker '--apex-parity-evidence "$APEX_PARITY_DIR"' "$DRIVER"; then
  fail SEALED_APEX_PARITY_BINDING
fi
pass SEALED_APEX_PARITY_BINDING

for marker in \
  'group_system_apex(' \
  'c1_system_bootclasspath_not_c3a_plus_imports' \
  'runtime_sources.append("SYSTEM_FRAGMENT")' \
  '"runtime_sources"' \
  'N1I_C1_APEX_PARITY_V6_EVIDENCE=' \
  'N1I_C1_APEX_PARITY_PRODUCT_OUT=' \
  'N1I_C1_APEX_PARITY_C1_SYSTEM_SHA256=' \
  'N1I_C1_APEX_OUTER_MISMATCH_COUNT=' \
  'N1I_C1_APEX_PAYLOAD_MISMATCH_COUNT=' \
  'N1I_C1_APEX_FRAGMENT_MISMATCH_COUNT=' \
  'N1I_C1_APEX_BOOT_JAR_HASH_MISMATCH_COUNT=' \
  'N1I_C1_APEX_JAVA_BOOT_RUNTIME_PARITY=' \
  'PASS_JAVA_BOOT_RUNTIME_IDENTICAL' \
  'FAIL_JAVA_BOOT_RUNTIME_DELTA'
do
  has_fixed_marker "$marker" "$APEX_PARITY" || fail REQUIRED_APEX_PARITY_MARKERS
done
pass REQUIRED_APEX_PARITY_MARKERS

for marker in \
  'N1I_C1_GAP_C1_WRITE_RIL_ANSWER_PROTOS=' \
  'N1I_C1_GAP_C3A_WRITE_RIL_ANSWER_PROTOS=' \
  'N1I_C1_GAP_STOCK_WRITE_RIL_ANSWER_PROTOS=' \
  'N1I_C1_GAP_STOCK_TO_C1_TELEPHONY_ABI=' \
  'N1I_C1_GAP_AGENT_EXTERNAL_INBOUND_REF_COUNT=' \
  'CANDIDATE_ISOLATED_NON_ANDROID_DEBUG_AGENT' \
  'N1I_C1_GAP_AGENTPREMAIN_FATAL_SUPPRESSION_AUTHORIZED=NO' \
  'PASS_STOCK_TO_C1_ABI_GAP_PLUS_AGENT_CANDIDATE'
do
  has_fixed_marker "$marker" "$GAP_CLASSIFIER" || fail REQUIRED_GAP_CLASSIFIER_MARKERS
done
pass REQUIRED_GAP_CLASSIFIER_MARKERS

if grep -Fq -- 'out-c3a-td' "$DRIVER" ||
   grep -Fq -- 'out-c3a-td' "$DERIVER"; then
  fail NO_MUTABLE_C3A_OUT_AUTHORITY
fi
pass NO_MUTABLE_C3A_OUT_AUTHORITY

if grep -Eq -- '/srv/[^"[:space:]]*TEE14-large-reference' "$DRIVER" ||
   grep -Fq -- '--stock-ref-dir' "$DRIVER"; then
  fail NO_HARDCODED_STOCK_REF_AUTHORITY
fi
pass NO_HARDCODED_STOCK_REF_AUTHORITY

if ! has_fixed_marker 'REPLAY="$OUT/n1i-a-replay"' "$DRIVER" ||
   ! has_fixed_marker 'c3a_tree = work / "c3a" / "system_img"' "$DERIVER" ||
   ! has_fixed_marker 'c3a_apex_root = work / "apex" / "c3a"' "$DERIVER"; then
  fail FRESH_REPLAY_WORK_BINDING
fi
pass FRESH_REPLAY_WORK_BINDING

if grep -Fq -- 'FAIL_TARGET_CLASSES_SHADOWED' "$AUDIT"; then
  fail APP_SHADOWS_NOT_FATAL
fi
pass APP_SHADOWS_NOT_FATAL

"$SABLE_PYTHON" "$AUDIT" --selftest
pass AUDIT_SELFTEST

echo "N1I_C1_RUNTIME_MEMBER_LINKAGE_AUDIT_REGRESSION=PASS"
