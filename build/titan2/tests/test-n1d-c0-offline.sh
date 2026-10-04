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
  'N1D_PRODUCT_CONTRACT_VERSION=6' \
  'N1D_SOURCE_SUBSTRATE=GRAPHENEOS_A16_PINNED' \
  'N1D_RESTLESS_ROLE=C2_CONTROL_C3A_REPRODUCTION_REFERENCE_C3B_PATCH_SOURCE_ONLY' \
  'N1D_C3_ACTIVE_PHASE=C3B_ENGINEERING' \
  'N1D_C3_PRODUCT_GENERATION_MODE=PINNED_TREBLEDROID_GENERATOR' \
  'N1D_PRODUCT_NAME=treble_arm64_bvN' \
  'N1D_PRODUCT_GENERATOR=device/phh/treble/generate.sh' \
  'N1D_PRODUCT_GENERATOR_CONFIG=sable-c3b-engineering' \
  'N1D_TREBLE_COMPAT_SUBSTRATE=device/phh/treble/base.mk' \
  'N1D_C3B_SCAFFOLD_MANIFEST=build/titan2/n1d-c3b-scaffold-add.xml' \
  'N1D_C3B_SCAFFOLD_DECISIONS=build/titan2/n1d-c3b-scaffold-decisions.tsv' \
  'N1D_C3B_ENGINEERING_DELTA=build/titan2/n1d-c3b-engineering.mk' \
  'N1D_C3B_PHH_BASE_HARDENING_APPLICATOR=build/titan2/apply-n1d-c3b-phh-base-hardening.py' \
  'N1D_C3B_RUNTIME_PATCH_ALLOWLIST=build/titan2/n1d-c3b-runtime-patch-allowlist.txt' \
  'N1D_C3_FIRST_BUILD_RELEASE_CONFIG=bp4a' \
  'N1D_C3_FIRST_BUILD_VARIANT=userdebug' \
  'N1D_C3_FIRST_BUILD_GOAL=systemimage' \
  'N1D_C3_BUILD_AUTHORIZED_BY_REBASELINE_STAGE=YES_C3B_SYSTEMIMAGE_ONLY' \
  'N1D_DIRECT_HANDCRAFTED_GSI_PRODUCT_ALLOWED=NO' \
  'N1D_DEVICE_PHH_TREBLE_GENERATOR_USED=YES_PINNED' \
  'N1D_DEVICE_PHH_TREBLE_BASE_PRESENT=YES_COMPATIBILITY_SUBSTRATE' \
  'N1D_CONTROL_FULL_RESTLESS_PATCH_TIERS=YES_PINNED_CONTROL_ONLY' \
  'N1D_RESTLESS_FULL_PATCH_TIERS_AUTOAPPLY_ALLOWED_FOR_RELEASE=NO' \
  'N1D_CONTROL_PATCH_COUNT=369' \
  'N1D_RUNTIME_PATCH_ALLOWLIST_COUNT=0' \
  'N1D_C3_RELEASE_ELIGIBLE=NO' \
  'N1D_C3_RUNTIME_SECURITY_AUDIT_REQUIRED=YES' \
  'N1D_C3A_ROLE=RESTLESS_TREBLEDROID_REPRODUCTION_CONTROL' \
  'N1D_C3A_STATUS=SEALED_COMPLETE' \
  'N1D_C3A_ADD_PROJECT_COUNT=12' \
  'N1D_C3A_REMOVE_PROJECT_COUNT=54' \
  'N1D_C3A_MANAGED_PROJECT_COUNT=991' \
  'N1D_C3A_CONTROL_FIDELITY=PUBLIC_FUNCTIONAL_REPRODUCTION' \
  'N1D_C3A_PRIVATE_RESTLESS_VENDOR=OMITTED' \
  'N1D_C3A_PIXEL_GSANS=OMITTED_UNPINNED_NONFUNCTIONAL' \
  'N1D_C3A_RELEASE_ELIGIBLE=NO' \
  'N1D_C3B_ROLE=SABLE_MINIMAL_ENGINEERING_BASELINE' \
  'N1D_C3B_GRAPHENE_BASE_PROJECT_COUNT=1033' \
  'N1D_C3B_SCAFFOLD_PROJECT_COUNT=5' \
  'N1D_C3B_REMOVE_PROJECT_COUNT=0' \
  'N1D_C3B_MANAGED_PROJECT_COUNT=1038' \
  'N1D_C3B_RESTLESS_FULL_PATCH_STACK_ALLOWED=NO' \
  'N1D_C3B_RESTLESS_PATCH_COUNT=0' \
  'N1D_C3B_RUNTIME_PATCH_ALLOWLIST_INITIAL_COUNT=0' \
  'N1D_C3B_AOSP_PHONE_STACK=SOURCE_BUILT' \
  'N1D_C3B_STOCK_TELEPHONY_APK_IMPORT_ALLOWED=NO' \
  'N1D_C3B_BUILD_AUTHORIZED=YES_SYSTEMIMAGE_ONLY_AFTER_STAGE_AND_PARSE' \
  'N1D_C3B_DEVICE_CONTACT_AUTHORIZED=NO' \
  'N1D_C3B_FLASH_AUTHORIZED=NO' \
  'N1D_C3B_SIGNING_AUTHORIZED=NO' \
  'N1D_C3B_PHYSICAL_RUNTIME_AUTHORIZED=NO' \
  'N1D_C3B_RELEASE_ELIGIBLE=NO' \
  'N1D_PRODUCT_CONTRACT=PASS'; do
  grep -Fxq "$required" "$CONTRACT" || fail "n1d_product_contract token=$required"
done

for forbidden in \
  'N1D_PRODUCT_CONTRACT_VERSION=5' \
  'N1D_C3_ACTIVE_PHASE=C3A_CONTROL' \
  'N1D_PRODUCT_NAME=sable_titan2_n1d_arm64' \
  'N1D_C3_FIRST_BUILD_VARIANT=user' \
  'N1D_C3B_ROLE=SABLE_MINIMAL_BASELINE' \
  'N1D_C3B_BUILD_AUTHORIZED=NO_UNTIL_C3A_CONTROL_EVIDENCE' \
  'N1D_DEVICE_PHH_TREBLE_GENERATOR_USED=NO' \
  'N1D_C3_RELEASE_ELIGIBLE=YES'; do
  if grep -Fxq "$forbidden" "$CONTRACT"; then
    fail "n1d_product_contract stale_token=$forbidden"
  fi
done
pass n1d_product_contract_v6_c3b_1038

grep -Fq 'build/config/host-tools.env' "$DRIVER" || fail canonical_host_tool_profile
grep -Fq 'SABLE_LPDUMP' "$DRIVER" || fail canonical_lpdump
grep -Fq 'SABLE_LPUNPACK' "$DRIVER" || fail canonical_lpunpack
grep -Fq 'SABLE_CHECKVINTF' "$DRIVER" || fail canonical_checkvintf
if grep -Fq 'resolve_otatools_zip' "$DRIVER"; then fail stale_otatools_discovery; fi
if grep -Fq 'resolve_tool()' "$DRIVER"; then fail stale_tool_discovery; fi
grep -Fq "IMAGES/system.img" "$DRIVER" || fail n1b_target_files_control_recovery
grep -Fq "N1B_CONTROL_TARGET_FILES_SOURCE" "$DRIVER" || fail n1b_target_files_provenance
pass c0_closure_contract

# C0_12 keeps exact-byte seals for the still-frozen Engineer-2 audit and
# classifier tools. The capture tool is an evolving N1I evidence tool, so its
# reviewed historical base remains hash-sealed while the current default
# read-only contract must prove legacy equivalence to that base.
CAPTURE_REVIEWED_BASE="8adfac494380d36dcf1951bcef4adb9dca106b5e"
CAPTURE_REVIEWED_SHA256="50344ffe5de82986299175587e152b493add8e930a90aa9dd55aba89351b721a"
CAPTURE_REL="build/titan2/capture-n1b2-cellular-runtime.sh"
CAPTURE_GUARD_TEST="$ROOT/tests/titan2/n1i-b/test-guard.sh"

[[ "$(sha256sum "$AUDIT" | awk '{print $1}')" == "b02d0da22de0f0cecca8a0793acd216ddecebafd9a51fae9c708936832c17c28" ]] || fail audit_hash
[[ "$(sha256sum "$CLASSIFIER" | awk '{print $1}')" == "7833e2235a151f4ae2f628c597624c02d93cd81ed558da5af5eaa73a47f5a6e9" ]] || fail classifier_hash

git -C "$ROOT" cat-file -e   "$CAPTURE_REVIEWED_BASE:$CAPTURE_REL" 2>/dev/null   || fail capture_reviewed_base_missing

[[ "$(
  git -C "$ROOT" show "$CAPTURE_REVIEWED_BASE:$CAPTURE_REL" |
    sha256sum |
    awk '{print $1}'
)" == "$CAPTURE_REVIEWED_SHA256" ]] || fail capture_reviewed_base_hash

[[ -f "$CAPTURE_GUARD_TEST" ]] || fail capture_guard_test_missing

if ! N1I_B_BASE_COMMIT="$CAPTURE_REVIEWED_BASE"   bash "$CAPTURE_GUARD_TEST" > "$TMP/capture-legacy-guard.log" 2>&1; then
  cat "$TMP/capture-legacy-guard.log" >&2
  fail capture_legacy_guard
fi

for case_name in   legacy_is_read_only_text_identical   legacy_default_verdicts_identical   b1_subset_of_legacy_or_extra; do
  awk -F '\t' -v case_name="$case_name" '
    $1 == "CASE" &&
    $2 == "guard" &&
    $3 == case_name &&
    $4 == "PASS" {
      found = 1
    }
    END {
      exit found ? 0 : 1
    }
  ' "$TMP/capture-legacy-guard.log" || {
    cat "$TMP/capture-legacy-guard.log" >&2
    fail "capture_legacy_case=$case_name"
  }
done

pass capture_legacy_compat
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
