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

# set -u regression: never reference a local variable in the same declaration
# statement that initializes it. Bash expands all RHS values before the new
# locals become available, which caused C0 to abort in extract_fs().
if grep -nE '^[[:space:]]*local[[:space:]].*raw="\$img"' "$DRIVER"; then
  fail nounset_local_raw_dependency
fi
if grep -nE '^[[:space:]]*local[[:space:]].*\$part' "$DRIVER"; then
  fail nounset_local_part_dependency
fi
pass nounset_local_initialization

grep -Fq 'bc550bfaf8463324c122abb490cf4aba956b89e7e4d42168a55f0f0f0f5b638e' "$DRIVER" || fail n1b_control_hash_default
grep -Fq 'device/phh/treble/treble_arm64_bvN.mk' "$DRIVER" || fail historical_c2_product_discovery
grep -Fq 'sealed known-booting N1B/Restless-derived system compared to N1C' "$DRIVER" || fail n1b_control_c0_10
pass control_autodiscovery

grep -Fq 'n1c-stock-super-restore-artifact-r1c-20260930_200124' "$DRIVER" || fail stock_super_evidence_discovery
grep -Fq 'n1c-restore-tee14-boot-avb-direct-20260930_204335' "$DRIVER" || fail avb_evidence_discovery
grep -Fq 'RELEASE_REGISTRY' "$DRIVER" || fail n1b_registry_discovery
grep -Fq 'HOST_TOOL_RESOLUTION_MODE CANONICAL_PROFILE_ONLY' "$DRIVER" || fail canonical_host_tool_resolution
grep -Fq 'AOSP_GSI_CANDIDATES' "$DRIVER" || fail gsi_release_source_discovery
grep -Fq 'TOOL_CHECKVINTF' "$DRIVER" || fail tool_resolution_evidence
pass c0_discovery_contract

CONTRACT="$ROOT/build/titan2/n1d-product-contract.env"
[[ -f "$CONTRACT" ]] || fail n1d_product_contract_missing
for required in \
  'N1D_PRODUCT_CONTRACT_VERSION=3' \
  'N1D_SOURCE_SUBSTRATE=GRAPHENEOS_A16_PINNED' \
  'N1D_RESTLESS_ROLE=REFERENCE_AND_C2_PREBUILT_DIAGNOSTIC_CONTROL' \
  'N1D_PRODUCT_NAME=sable_titan2_n1d_arm64' \
  'N1D_AOSP_GSI_BASE=build/make/target/product/generic_system_arm64.mk' \
  'N1D_GSI_RELEASE_INCLUDE=build/make/target/product/gsi_release.mk' \
  'N1D_TREBLE_COMPAT_REFERENCE=device/phh/treble' \
  'N1D_TREBLE_COMPAT_DELTA=vendor/sable/n1d/treble_compat.mk' \
  'N1D_SABLE_DELTA=vendor/sable/n1d/sable_n1d_product_delta.mk' \
  'N1D_DIRECT_DEVICE_PHH_TREBLE_BASE_INHERIT=NO' \
  'N1D_DEVICE_PHH_TREBLE_GENERATOR_USED=NO' \
  'N1D_RESTLESS_ROM_MK_DIRECT_INHERIT=NO' \
  'N1D_INITIAL_RESTLESS_PATCH_ALLOWLIST_COUNT=0' \
  'N1D_RUNTIME_PRODUCT_OWNER=GSI_SYSTEM_IMAGE' \
  'N1D_RUNTIME_SYSTEM_EXT_OWNER=GSI_SYSTEM_IMAGE' \
  'N1D_SELINUX_ENFORCING_REQUIRED=YES' \
  'N1D_NEVERALLOW_ENFORCEMENT_REQUIRED=YES' \
  'N1D_ADB_AUTH_REQUIRED=YES' \
  'N1D_PRODUCT_CONTRACT=PASS'; do
  grep -Fxq "$required" "$CONTRACT" || fail "n1d_product_contract token=$required"
done

for forbidden in \
  'N1D_BASE_PRODUCT=treble_arm64_bvN' \
  'N1D_PRODUCT_GENERATOR=device/phh/treble/generate.sh' \
  'N1D_GENERATED_ARCH_INCLUDE=build/make/target/product/aosp_arm64.mk' \
  'N1D_TREBLE_BASE=device/phh/treble/base.mk' \
  'N1D_GSI_RELEASE_OWNER=device/phh/treble/base.mk' \
  'N1D_RESTLESS_DELTA=device/phh/treble/rom.mk'; do
  if grep -Fxq "$forbidden" "$CONTRACT"; then
    fail "n1d_product_contract stale_token=$forbidden"
  fi
done
grep -Fq 'build/config/host-tools.env' "$DRIVER" || fail canonical_host_tool_profile
grep -Fq 'SABLE_LPDUMP' "$DRIVER" || fail canonical_lpdump
grep -Fq 'SABLE_LPUNPACK' "$DRIVER" || fail canonical_lpunpack
grep -Fq 'SABLE_CHECKVINTF' "$DRIVER" || fail canonical_checkvintf
if grep -Fq 'resolve_otatools_zip' "$DRIVER"; then fail stale_otatools_discovery; fi
if grep -Fq 'resolve_tool()' "$DRIVER"; then fail stale_tool_discovery; fi
grep -Fq "IMAGES/system.img" "$DRIVER" || fail n1b_target_files_control_recovery
grep -Fq "N1B_CONTROL_TARGET_FILES_SOURCE" "$DRIVER" || fail n1b_target_files_provenance
pass c0_closure_contract

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
