#!/usr/bin/env bash
# Host-only static regression for sealed C1 runtime-layout audit.
# Never contacts a device and never reads large image inputs.
set -u
set -o pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AUDIT="$ROOT/build/titan2/audit-n1i-c1-sealed-runtime-layout.sh"
HOST_TOOLS_PROFILE="$ROOT/build/config/host-tools.env"

FAILS=0
pass() { echo "N1I_C1_SEALED_AUDIT_TEST_$1=PASS"; }
fail() {
  echo "N1I_C1_SEALED_AUDIT_TEST_$1=FAIL ${2:-}" >&2
  FAILS=$((FAILS + 1))
}

bash -n "$AUDIT" || {
  fail SYNTAX
  exit 1
}
pass SYNTAX

if [[ -f "$HOST_TOOLS_PROFILE" ]]; then
  source "$HOST_TOOLS_PROFILE"
else
  fail HOST_TOOLS_PROFILE "missing=$HOST_TOOLS_PROFILE"
fi

if [[ -n "${SABLE_SIMG2IMG:-}" &&
      -x "$SABLE_SIMG2IMG" &&
      "$SABLE_SIMG2IMG" == "$SABLE_AOSP_HOST_BIN/simg2img" ]]; then
  pass CANONICAL_SIMG2IMG_EXECUTABLE
else
  fail CANONICAL_SIMG2IMG_EXECUTABLE "path=${SABLE_SIMG2IMG:-UNSET} expected=$SABLE_AOSP_HOST_BIN/simg2img"
fi

for marker in \
  'DEVICE_CONTACT_AUTHORIZED=NO' \
  'BUILD_AUTHORIZED=NO' \
  'FLASH_AUTHORIZED=NO' \
  'SOURCE_MUTATION_AUTHORIZED=NO' \
  'HOST_TOOLS_PROFILE="$ROOT/build/config/host-tools.env"' \
  'source "$HOST_TOOLS_PROFILE"' \
  'SIMG2IMG="$SABLE_SIMG2IMG"' \
  'PYTHON="$SABLE_PYTHON"' \
  'HOST_TOOL_RESOLUTION_MODE="CANONICAL_PROFILE_ONLY"' \
  'N1I_C1_HOST_TOOLS_PROFILE=' \
  'N1I_C1_HOST_TOOL_RESOLUTION_MODE=' \
  'N1I_C1_TOOL_SIMG2IMG=' \
  '===== N1I-C1 SEALED RUNTIME AUDIT PREFLIGHT =====' \
  'N1I_C1_${label}_INPUT_TYPE=' \
  'N1I_C1_${label}_NORMALIZED_TYPE=' \
  'run_host_tool() {' \
  'EXPECTED_SYSTEM_SHA="137bc8771c817c0afb3122d9f03e7a94575e03bcccc643b56235edd1075f2160"' \
  'EXPECTED_SYSTEM_BYTES="3210661888"' \
  'EXPECTED_COMMON_SHA="511b674b91dd29e84e06c8e46c718e35650745c0359edd665d5fb3e88e6ed549"' \
  'EXPECTED_IMS_BASE_SHA="bb5769a098b59f9d299495981e87500da32e0667cf6a22931de2894d324a82ab"' \
  'N1I_C1_STOCK_BOOTCLASSPATH_PATH=' \
  'N1I_C1_STOCK_COMMON_PATH=' \
  'N1I_C1_STOCK_IMS_BASE_PATH=' \
  'N1I_C1_STOCK_IMS_APK_PATH=' \
  'N1I_C1_PRODUCT_OUT_TO_SEALED_BOOTCLASSPATH=PASS_EXACT' \
  'N1I_C1_PRODUCT_OUT_TO_SEALED_COMMON=PASS_EXACT' \
  'N1I_C1_PRODUCT_OUT_TO_SEALED_IMS_BASE=PASS_EXACT' \
  'N1I_C1_PRODUCT_OUT_TO_SEALED_IMS_APK=PASS_EXACT' \
  'N1I_C1_PRODUCT_OUT_TO_SEALED_PROPERTY_CONTEXTS=PASS_EXACT' \
  'N1I_C1_PRODUCT_OUT_TO_SEALED_SERVICE_CONTEXTS=PASS_EXACT' \
  'N1I_C1_MTK_MUTUAL_ORDER=' \
  'N1I_C1_MTK_ABSOLUTE_POSITION=' \
  'N1I_C1_SEALED_RUNTIME_AUDIT=PASS'
do
  grep -Fq "$marker" "$AUDIT" ||
    fail REQUIRED_MARKER "missing=$marker"
done
[[ "$FAILS" -eq 0 ]] && pass REQUIRED_MARKERS

if grep -Fq 'retained_stock_extraction_missing' "$AUDIT" ||
   grep -Fq 'AUDIT_EVIDENCE/work/stock' "$AUDIT"; then
  fail PINNED_STOCK_DIRECT "transient stock extraction dependency remains"
elif grep -Fq 'prepare_fs_view "$STOCK_SYSTEM" STOCK_SYSTEM' "$AUDIT" &&
     grep -Fq 'prepare_fs_view "$STOCK_SYSTEM_EXT" STOCK_SYSTEM_EXT' "$AUDIT" &&
     grep -Fq 'dump_view_file "$STOCK_SYSTEM_READ_TYPE"' "$AUDIT" &&
     grep -Fq 'dump_view_file "$STOCK_SYSTEM_EXT_READ_TYPE"' "$AUDIT"; then
  pass PINNED_STOCK_DIRECT
else
  fail PINNED_STOCK_DIRECT "direct normalized pinned-stock views missing"
fi

if grep -Fq 'run_host_tool "$SIMG2IMG" "$image" "$raw"' "$AUDIT" &&
   grep -Fq 'ext4|erofs)' "$AUDIT" &&
   grep -Fq 'prepare_fs_view "$STOCK_SYSTEM" STOCK_SYSTEM' "$AUDIT" &&
   grep -Fq 'prepare_fs_view "$STOCK_SYSTEM_EXT" STOCK_SYSTEM_EXT' "$AUDIT"; then
  pass SPARSE_NORMALIZATION_FAIL_CLOSED
else
  fail SPARSE_NORMALIZATION_FAIL_CLOSED "canonical sparse normalization or ext4/erofs support missing"
fi

if grep -Fq 'command -v simg2img' "$AUDIT" ||
   grep -Eq '(^|[[:space:]])simg2img[[:space:]]' "$AUDIT"; then
  fail CANONICAL_SIMG2IMG_ONLY "ambient_or_bare_simg2img_found"
elif grep -Fq 'SIMG2IMG="$SABLE_SIMG2IMG"' "$AUDIT" &&
     grep -Fq 'run_host_tool "$SIMG2IMG" "$image" "$raw"' "$AUDIT"; then
  pass CANONICAL_SIMG2IMG_ONLY
else
  fail CANONICAL_SIMG2IMG_ONLY "canonical SABLE_SIMG2IMG binding/use missing"
fi

if grep -Eq 'out/host|out_[A-Za-z0-9._/-]*/host|workspaces/.*/host' "$AUDIT"; then
  fail NO_BUILD_SPECIFIC_HOST_TOOLS "historical/build-specific host-tool path found"
else
  pass NO_BUILD_SPECIFIC_HOST_TOOLS
fi

if grep -Eq 'STOCK_SYSTEM_READ=.*\$\(prepare_fs_view|STOCK_SYSTEM_EXT_READ=.*\$\(prepare_fs_view' "$AUDIT"; then
  fail NO_PREPARE_SUBSHELL "prepare_fs_view called through command substitution"
else
  pass NO_PREPARE_SUBSHELL
fi

PREFLIGHT_LINE="$(grep -nF '===== N1I-C1 SEALED RUNTIME AUDIT PREFLIGHT =====' "$AUDIT" | cut -d: -f1 | head -n1)"
PREPARE_LINE="$(grep -nF 'prepare_fs_view "$STOCK_SYSTEM" STOCK_SYSTEM' "$AUDIT" | cut -d: -f1 | head -n1)"
if [[ "$PREFLIGHT_LINE" =~ ^[0-9]+$ &&
      "$PREPARE_LINE" =~ ^[0-9]+$ &&
      "$PREFLIGHT_LINE" -lt "$PREPARE_LINE" ]]; then
  pass EARLY_PREFLIGHT_EVIDENCE
else
  fail EARLY_PREFLIGHT_EVIDENCE "preflight=$PREFLIGHT_LINE prepare=$PREPARE_LINE"
fi

if grep -En '^[[:space:]]*(adb|fastboot)([[:space:]]|\()' "$AUDIT"; then
  fail NO_DEVICE_COMMANDS "adb_or_fastboot_found"
else
  pass NO_DEVICE_COMMANDS
fi

if grep -En '^[[:space:]]*(mount|umount|reboot|dd)([[:space:]]|\()' "$AUDIT"; then
  fail NO_MUTATION_COMMANDS "mutation_command_found"
else
  pass NO_MUTATION_COMMANDS
fi

if grep -Fq 'debugfs -w' "$AUDIT" ||
   grep -Eq 'mount[[:space:]].*-o[[:space:]]*(rw|remount)' "$AUDIT"; then
  fail READ_ONLY_IMAGE_ACCESS "image_write_or_mount_found"
elif grep -Fq '"$FSCK_EROFS" --extract="$tree" "$PREPARED_IMAGE"' "$AUDIT" &&
     grep -Fq 'tree="$TMP/${label,,}.erofs-tree"' "$AUDIT"; then
  pass READ_ONLY_IMAGE_ACCESS
else
  fail READ_ONLY_IMAGE_ACCESS "read-only EROFS fallback not constrained to TMP"
fi

if ! grep -Fq '"$DEBUGFS" -R "dump -p $candidate $dest"' "$AUDIT"; then
  fail TARGETED_IMAGE_DUMP "targeted_debugfs_dump_missing"
else
  pass TARGETED_IMAGE_DUMP
fi

for runtime_path in \
  '/etc/classpaths/bootclasspath.pb' \
  '/system_ext/framework/mediatek-common.jar' \
  '/system_ext/framework/mediatek-ims-base.jar' \
  '/system_ext/priv-app/ImsService/ImsService.apk' \
  '/system_ext/etc/selinux/system_ext_property_contexts' \
  '/system_ext/etc/selinux/system_ext_service_contexts'
do
  grep -Fq "$runtime_path" "$AUDIT" ||
    fail SEALED_RUNTIME_PATH "missing=$runtime_path"
done
[[ "$FAILS" -eq 0 ]] && pass SEALED_RUNTIME_PATHS

if "$SABLE_PYTHON" - "$AUDIT" <<'PY_CHECK'
from pathlib import Path
import sys

lines = Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()
start = None
for i, line in enumerate(lines):
    if "<<'PY'" in line and "$STOCK_BOOT" in line and "$C1_BOOT" in line:
        start = i + 1
        break
if start is None:
    raise SystemExit("embedded Python start not found")
end = None
for i in range(start, len(lines)):
    if lines[i] == "PY":
        end = i
        break
if end is None:
    raise SystemExit("embedded Python end not found")
compile("\n".join(lines[start:end]) + "\n", "n1i-c1-bootclasspath-parser", "exec")
PY_CHECK
then
  pass EMBEDDED_PYTHON_SYNTAX
else
  fail EMBEDDED_PYTHON_SYNTAX "bootclasspath parser missing or invalid"
fi

if [[ "$FAILS" -eq 0 ]]; then
  echo "N1I_C1_SEALED_RUNTIME_AUDIT_SELFTEST=PASS"
  exit 0
fi

echo "N1I_C1_SEALED_RUNTIME_AUDIT_SELFTEST=FAIL count=$FAILS" >&2
exit 1
