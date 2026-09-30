#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DRIVER="$ROOT/build/titan2/qualify-n1d-c0-offline.sh"
HELPER="$ROOT/build/titan2/n1d-c0-inspect.py"
AUDIT="$ROOT/build/titan2/audit-n1b2-cellular-stack.sh"
CAPTURE="$ROOT/build/titan2/capture-n1b2-cellular-runtime.sh"
CLASSIFIER="$ROOT/build/titan2/classify-n1b2-nr-state.py"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass() { echo "PASS $1"; }
fail() { echo "FAIL $1" >&2; exit 1; }

bash -n "$DRIVER" || fail driver_bash_n
bash -n "$AUDIT" || fail audit_bash_n
bash -n "$CAPTURE" || fail capture_bash_n
python3 -m py_compile "$HELPER" "$CLASSIFIER" || fail python_compile
pass syntax

# Reviewed Engineer-2 tool hashes are immutable inputs to C0_12.
[[ "$(sha256sum "$AUDIT" | awk '{print $1}')" == "b02d0da22de0f0cecca8a0793acd216ddecebafd9a51fae9c708936832c17c28" ]] || fail audit_hash
[[ "$(sha256sum "$CAPTURE" | awk '{print $1}')" == "50344ffe5de82986299175587e152b493add8e930a90aa9dd55aba89351b721a" ]] || fail capture_hash
[[ "$(sha256sum "$CLASSIFIER" | awk '{print $1}')" == "7833e2235a151f4ae2f628c597624c02d93cd81ed558da5af5eaa73a47f5a6e9" ]] || fail classifier_hash
pass reviewed_tool_hashes

# system-report fixture
mkdir -p "$TMP/sys/system_ext/etc/init/config" "$TMP/sys/apex/com.android.vndk.v34"
printf 'ro.build.version.sdk=36\nro.vndk.version=36\n' > "$TMP/sys/build.prop"
printf '/product\n/system_ext\n' > "$TMP/sys/system_ext/etc/init/config/skip_mount.cfg"
python3 "$HELPER" system-report --root "$TMP/sys" --label fixture --out "$TMP/system.env"
grep -q '^SKIP_PRODUCT=YES$' "$TMP/system.env" || fail skip_product
grep -q '^SKIP_SYSTEM_EXT=YES$' "$TMP/system.env" || fail skip_system_ext
pass system_report

# framework diff fixture
mkdir -p "$TMP/gsi/app" "$TMP/stock/app"
printf x > "$TMP/gsi/app/a.apk"
printf yy > "$TMP/stock/app/a.apk"
printf z > "$TMP/stock/app/ims.apk"
python3 "$HELPER" framework-diff --gsi-root "$TMP/gsi" --stock-root "$TMP/stock" --label fixture --out-tsv "$TMP/diff.tsv" --out-md "$TMP/diff.md"
grep -q 'BOTH_SIZE_DIFF' "$TMP/diff.tsv" || fail framework_both_diff
grep -q 'STOCK_ONLY.*ims.apk' "$TMP/diff.tsv" || fail framework_stock_only
pass framework_diff

# GSI contract fixture
cat > "$TMP/gsi_release.mk" <<'EOF'
BUILDING_GSI := true
PRODUCT_USE_DYNAMIC_PARTITION_SIZE := true
PRODUCT_PACKAGES += gsi_skip_mount.cfg init.gsi.rc
PRODUCT_EXTRA_VNDK_VERSIONS := 30 31 32 33 34
EOF
cat > "$TMP/sable.mk" <<'EOF'
$(call inherit-product, build/make/target/product/gsi_release.mk)
EOF
python3 "$HELPER" gsi-contract --aosp "$TMP/gsi_release.mk" --sable "$TMP/sable.mk" --out-json "$TMP/gsi.json" --out-md "$TMP/gsi.md"
grep -q 'inherits_gsi_release' "$TMP/gsi.json" || fail gsi_contract
pass gsi_contract

# LP diff fixture
cat > "$TMP/stock.json" <<'EOF'
{"partitions":[{"name":"system","group_name":"main","size":"100"},{"name":"vendor","group_name":"main","size":"50"}],"groups":[{"name":"main","maximum_size":"200"}],"block_devices":[{"name":"super","size":"256"}]}
EOF
cat > "$TMP/n1c.json" <<'EOF'
{"partitions":[{"name":"system","group_name":"main","size":"110"},{"name":"vendor","group_name":"main","size":"50"}],"groups":[{"name":"main","maximum_size":"200"}],"block_devices":[{"name":"super","size":"256"}]}
EOF
python3 "$HELPER" lp-diff --stock-json "$TMP/stock.json" --n1c-json "$TMP/n1c.json" --out-json "$TMP/lp.json" --out-md "$TMP/lp.md"
grep -q '| system | DIFF |' "$TMP/lp.md" || fail lp_diff_system
grep -q '| vendor | SAME |' "$TMP/lp.md" || fail lp_diff_vendor
pass lp_diff

# No device/build/flash executable invocations are allowed in the C0 driver.
# Match command-leading tokens, not policy prose/comments.
if grep -nE '^[[:space:]]*(adb|fastboot|m |m$|ninja|soong_ui|repo sync|git fetch|curl|wget)([[:space:]]|$)' "$DRIVER"; then
  fail forbidden_host_action
fi
pass no_device_build_network_commands

echo "N1D_C0_OFFLINE_SELF_TEST=PASS"
