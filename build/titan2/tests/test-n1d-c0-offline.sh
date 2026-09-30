#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DRIVER="$ROOT/build/titan2/qualify-n1d-c0-offline.sh"
HELPER="$ROOT/build/titan2/n1d-c0-inspect.py"
AUDIT="$ROOT/build/titan2/audit-n1b2-cellular-stack.sh"
CAPTURE="$ROOT/build/titan2/capture-n1b2-cellular-runtime.sh"
CLASSIFIER="$ROOT/build/titan2/classify-n1b2-nr-state.py"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass(){ echo "PASS $1"; }; fail(){ echo "FAIL $1" >&2; exit 1; }
bash -n "$DRIVER" && bash -n "$AUDIT" && bash -n "$CAPTURE" || fail shell_syntax
python3 -m py_compile "$HELPER" "$CLASSIFIER" || fail python_compile
pass syntax
[[ "$(sha256sum "$AUDIT"|awk '{print $1}')" == b02d0da22de0f0cecca8a0793acd216ddecebafd9a51fae9c708936832c17c28 ]] || fail audit_hash
[[ "$(sha256sum "$CAPTURE"|awk '{print $1}')" == 50344ffe5de82986299175587e152b493add8e930a90aa9dd55aba89351b721a ]] || fail capture_hash
[[ "$(sha256sum "$CLASSIFIER"|awk '{print $1}')" == 7833e2235a151f4ae2f628c597624c02d93cd81ed558da5af5eaa73a47f5a6e9 ]] || fail classifier_hash
pass reviewed_tool_hashes
mkdir -p "$TMP/sys/system_ext/etc/init/config" "$TMP/sys/apex/com.android.vndk.v34"
printf 'ro.build.version.sdk=36\nro.vndk.version=36\n' >"$TMP/sys/build.prop"
printf '/product\n/system_ext\n' >"$TMP/sys/system_ext/etc/init/config/skip_mount.cfg"
python3 "$HELPER" system-report --root "$TMP/sys" --label fixture --out "$TMP/system.env"
grep -q '^SKIP_PRODUCT=YES$' "$TMP/system.env" && grep -q '^SKIP_SYSTEM_EXT=YES$' "$TMP/system.env" || fail skip_mount
pass system_report
mkdir -p "$TMP/gsi/app" "$TMP/stock/app"; printf x >"$TMP/gsi/app/a.apk"; printf yy >"$TMP/stock/app/a.apk"; printf z >"$TMP/stock/app/ims.apk"
python3 "$HELPER" framework-diff --gsi-root "$TMP/gsi" --stock-root "$TMP/stock" --label fixture --out-tsv "$TMP/d.tsv" --out-md "$TMP/d.md"
grep -q 'BOTH_SIZE_DIFF' "$TMP/d.tsv" && grep -q 'STOCK_ONLY.*ims.apk' "$TMP/d.tsv" || fail framework_diff
pass framework_diff
cat >"$TMP/aosp.mk" <<'E'
BUILDING_GSI := true
PRODUCT_USE_DYNAMIC_PARTITION_SIZE := true
PRODUCT_PACKAGES += gsi_skip_mount.cfg init.gsi.rc
PRODUCT_EXTRA_VNDK_VERSIONS := 30 31 32 33 34
E
printf '%s\n' '\$(call inherit-product, build/make/target/product/gsi_release.mk)' >"$TMP/sable.mk"
python3 "$HELPER" gsi-contract --aosp "$TMP/aosp.mk" --sable "$TMP/sable.mk" --out-json "$TMP/g.json" --out-md "$TMP/g.md"
grep -q 'inherits_gsi_release' "$TMP/g.json" || fail gsi_contract
pass gsi_contract
if grep -nE '^[[:space:]]*(adb|fastboot|m |m$|ninja|soong_ui|repo sync|git fetch|curl|wget)([[:space:]]|$)' "$DRIVER"; then fail forbidden_action; fi
pass no_device_build_network_commands
[[ "$(/usr/bin/env bash "$CAPTURE" --help 2>&1 || true)" == *"--boot-timeout-sec"* ]] || fail capture_help
pass capture_contract
echo N1D_C0_OFFLINE_SELF_TEST=PASS
