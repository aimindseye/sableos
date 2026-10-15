# PR342 A1R V1.1 missing historical generated makefile — A1R V1.2 scratch reproduction

2026-10-14. Engineering lane. PR #342 remains open/draft. No Android image build or device/flash authorization from this checkpoint.

## Actual ai-g732 V1.1 refusal

User reran the correct direct sealed Python `apply` (not the prior wrapper typo): outer SHA and twelve inner SHA PASS; wrapper syntax PASS; 35/35 regressions PASS (0.126s). Real `apply` produced exactly:

```json
{"build_ready":false,"reason":"[Errno 2] No such file or directory: 'treble_arm64_avS.mk'","status":"REFUSED_A1R_PREFLIGHT_NO_SOURCE_WRITE","systemimage":false}
```

Then SSH closed. V1.1 Python source code `source_generated_assets()` read M4's historical `AndroidProducts.mk` (60 entries), then unconditionally attempted to read ALL 60 historical M4 mk leaves; the historical file `treble_arm64_avS.mk` was absent. **This does not establish that A1 itself is missing it because it was read on M4; it establishes a false assumption that historical generated file retention is complete**. Preflight refused before A1R evidence directory or A1R staged generated files. **DO NOT rerun A1F–A1Q or A1R V1/V1.1.** A1P 12 payload/policy files and A1Q three Git-independent stores remain completed, immutable.

## Existing source authority reviewed

Main SableOS `build/titan2/n1d-c3-trebledroid.env` pins `device/phh/treble/generate.sh` on TrebleDroid commit `39ba82ef89ff5bf6b22ca8f147dbf317bffa20ed`; the upstream `TrebleDroid/device_phh_treble/generate.sh` at that exact commit has Git blob ID **`8f24152e399360831f344c0759afd266493ab869`**. The generator loops 2 partition choices × 5 app variants × 3 arches × 2 superuser choices = 60 mk files plus a registry. Old historical M4 may retain the complete registry yet have missing generated leaves. The correct remedy is faithful regeneration by the exact pinned script in scratch, **not guessing content**. There is no reason to reconstruct `.repo`, run repo sync, rebuild apps, rehash the stock partitions, or rework 991 source HEADs.

## New A1R V1.2 source-only replay + Android graph package

`N1F_P342_A1R_GENERATED_PRODUCT_GRAPH_REPAIR_V1_2.zip` outer **SHA256 `942d61576da6509ece1df3d142c3d86fce45ee8a534de2be54d629f734ee322f`**, **44,687 bytes**, 14 members (13 SHA256-sealed + checksums file). Main `n1f_p342_a1r_generated_product_graph_repair_v1.py` SHA256 **`8cee1c0e54d1e79afec0df8c32633b219f79f3a72ea8a7abb47387a3acdb4f0e`**, wrapper `n1f_p342_a1r_one_command_v1_2.sh` SHA256 **`ef28a20b492af744b744b5c76d998dfa1ebc298a5a3a234f87aa460f81d2831b`**. Inherited A1D/A1M/A1O/A1P/A1Q Python source files unmodified.

One command from independent SHA-verified fresh extracted ZIP:

```sh
bash ./n1f_p342_a1r_one_command_v1_2.sh --authorize-a1r-exact-generated-product-replay-and-graph-only
```

Changes limited to original A1R generated source preflight, not its authorized source staging scope or Android graph command. If historical M4 contains all 60 registered mk files, retain prior byte-exact behavior. If any historical generated mk missing: require identical A1 and M4 generator bytes, require exact pinned public generator git blob ID, execute only that script as `/bin/bash generate.sh rom` in a fresh temporary directory with fixed minimal env and 20s bound, require exactly 60 registered product mk + registry, require generated `AndroidProducts.mk` bytes exactly equal historical M4 registry and all existing historical M4 mk bytes exactly equal scratch output. Unknown symlink, tampered historical file, mismatched pinned generator or unsafe output => prewrite refusal. On success, exclusive-source-create only missing A1 generated mk leaves, preserving `rom.mk`, complete payload/policy source and no-build marker; direct config-only lunch and `m -j4 nothing` in one-use evidence directory. **No systemimage, repack, .repo creation, network fetch, mount/super/device/flash.** No automatic retry, rollback, cleanup or resumed source mutation on a partial run.

## Validation and timings

Assistant local exact archive: ZIP CRC PASS, 13/13 internal SHA256 PASS, Python AST/compile PASS, Bash `-n` wrapper PASS. **43/43 unit tests PASS under both umask 077 and 022**, including **freshly unzipped archive** 43/43 at both umasks. Original 35 tests retained; eight additional tests model M4 missing `treble_arm64_avS.mk` (and two missing), scratch generator exact name/byte replay, missing-source end-to-end 61 A1 leaf staging, malicious/changed retained historical file, symlink, wrong blob pin, bad registry, and prewrite discipline. Synthetic 15-run 60-leaf scratch generator reproduction median **130.03ms**, p95 **142.10ms**, worst **174.15ms**; excludes real A1R source I/O and Android config/Soong graph. No assistant run on actual ai-g732 inputs, so **A1R V1.2 ai-g732 NOT EXECUTED**.

Operator success would be `PASS_A1R_GENERATED_PRODUCT_RESTORED_ANDROID_CONFIG_GRAPH_ONLY` with scoped `build_ready=true` only for host-only engineering image-build consideration, not a built image or device readiness. Refusal before source creation reports `REFUSED_A1R_PREFLIGHT_NO_SOURCE_WRITE`, and after one-use evidence creation reports `INCOMPLETE_STOP_PRESERVE_GENERATED_PRODUCT_AND_EVIDENCE`: do not retry either one-use source stage without review. No Android image builds are performed by this package.

```text
A1P=ACTUAL_PASS_STAGE12
A1Q_GIT=ACTUAL_PASS_INDEPENDENT3
A1Q_GRAPH=ACTUAL_FAIL_NO_PRODUCT_REGISTRATION
A1R_V1=ACTUAL_REFUSED_BAD_EXPECTED_COUNT48_NO_WRITE
A1R_V11=ACTUAL_REFUSED_M4_MISSING_TREBLE_ARM64_AVS_MK_NO_WRITE
A1R_V12_LOCAL=PASS_ZIP_CRC_SHA13_BASH_AST_TEST43_BOTH_UMASKS
A1R_V12_REAL_HOST=NOT_EXECUTED
BUILD_READY=NO IMAGE_BUILD=NO SUPER=NO DEVICE=NO FLASH=NO
```