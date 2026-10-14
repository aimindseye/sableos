# Titan 2 PR342 — A1Q real product-discovery failure and A1R exact PHH generated product replay

Date: 2026-10-14 (US/Eastern). PR342 remains OPEN/DRAFT/UNMERGED. **No image build / device / flash authorized by this evidence.**

## Actual ai-g732 A1Q error and completed scope

Operator A1Q V1 outer+11 inner SHA and 16/16 tests PASS, real three A1 borrowed Git project stores independently fsck PASSED (alternates files moved to preserved backups), source HEADs unchanged, no-build marker preserved. `git_independent_count=3`; do NOT rerun A1Q or any earlier A1F–A1P.

A1Q Android config-only execution returned rc=2. User pasted the exact retained `config-graph.log` root error:

```
build/make/core/product_config.mk:226: error: Cannot locate config makefile for product "treble_arm64_bvN".
09:34:02 dumpvars failed with: exit status 1
CONFIG_VARS=NOT_GENERATED
```

The warning `Build sandboxing disabled due to nsjail error` precedes the failure but is **not established as causal**. No Kati/Soong evaluation reached C1/C3B modules. Missing `.repo` was NOT implicated by this actual failure. The error indicates the product registration/generation layer is incomplete in selected isolated A1, not a new APK, stock image, policy or Git independence problem.

## Reuse of historical successful source production

- Canonical SableOS `build/titan2/n1d-c3-trebledroid.env` declares `device/phh/treble/generate.sh` and generated `treble_arm64_bvN` product; `docs/titan2/N1D_C3_PRODUCT_COMPOSITION_R1.md` explains the generator -> `treble_arm64_bvN` and generated product layer.
- Prior C1/N1F scripts call `lunch treble_arm64_bvN-bp4a-user` and evaluate product variables; they assume Treble generator output already exists. The historical retained M4 project had performed the generator stage prior to producing its failed-boot image. **Reuse only those generated textual declarations, not any built M4 image, ROM policy, or device state.**
- Upstream PHH/TrebleDroid `generate.sh` writes `AndroidProducts.mk` and a matrix of 48 `treble_*.mk` files. A1R checks that the actual historical M4 generator script and selected A1 generator bytes have identical SHA256 before using its outputs. Does **not execute any historical generator**.

## New A1R external deliverable

`N1F_P342_A1R_GENERATED_PRODUCT_GRAPH_REPAIR_V1.zip` **SHA256 `3fbb04440e5eb0922b1a69d32c44a1d49c65b8f371122bd49b1c357ea1c2f2ce`**, **42,551 bytes**, 13 archive entries (12 inner SHA256-sealed members plus `SHA256SUMS.txt`). Main Python SHA256 **`b42e423b0cfd99f6698b2972c51e45e3242982bdd771f8ebfe80aa1bf77c0534`**. Earlier A1D/A1M/A1O/A1P/A1Q Python modules imported **unchanged**.

One operator command from verified fresh ZIP:

```sh
bash ./n1f_p342_a1r_one_command_v1.sh --authorize-a1r-exact-generated-product-replay-and-graph-only
```

One-use exact scoped source replay: first require A1Q receipt shows exactly three independently detached Git projects and the literal config-product error in A1Q log; require A1P 12 files/receipt and original A1F–A1L source hashes; preserve `.A1_INCOMPLETE_DO_NOT_BUILD`, absent `out-a1` and `.repo`. In historical M4 `device/phh/treble`, read generator and `AndroidProducts.mk`, require exact 48 generated distinct allowed product registrations plus 48 corresponding bounded, regular non-symlink makefiles with correct `PRODUCT_NAME`, and selected target `PRODUCT_DEVICE := tdgsi_arm64_ab` and `device/phh/treble/rom.mk` inheritance. Compare selected A1 generator bytes to historical generator bytes. All source identities checked **before any write**. Existing generated files must be byte-identical or refusal. Create **only missing generated registration files** in isolated A1 with exclusive `O_NOFOLLOW|O_EXCL`, SHA readback, no overwrite or external donor edits. Maximum 49 source files, original PHH `rom.mk` untouched. Never executes generator in A1 or M4.

Then direct exact `lunch treble_arm64_bvN-bp4a-user` with `OUT_DIR` isolated under one-use A1R evidence (`.A1R_GENERATED_PRODUCT_GRAPH_NO_IMAGE_V1/out-config`), all eleven A1Q Kati variable assertions and `m -j4 nothing`. No image build. A real complete config-only graph yields `PASS_A1R_GENERATED_PRODUCT_RESTORED_ANDROID_CONFIG_GRAPH_ONLY` with `build_ready=true` scoped **engineering image-build candidate only**. If another Android error appears, receipt is `INCOMPLETE_STOP_PRESERVE_GENERATED_PRODUCT_AND_EVIDENCE`, `build_ready=false`, actual `config-graph.log` retained, no retry/resume/rollback. No network fetch, no `.repo` init/sync, no donor or Git repack, no systemimage, no device/flash.

## Local integrity, regressions and performance

Exact ZIP CRC PASS, all 12/12 inner SHA256 PASS, **seven Python AST/compile PASS**, Bash `bash -n` PASS. **30/30 dedicated source replay and graph-fixture regression tests PASS under umask 077 (0.312s) and 022 (0.188s)**. Fresh extracted actual ZIP independently verified SHA12, Bash and no-host-I/O plan, **30/30 tests PASS under umask 077 (0.166s) and umask 022 (0.179s)**. Fixture includes full 48-product/49-file write, partial exactly-matching existing file, symlink/changed existing refusal, generator mismatch, malformed registration and incomplete graph one-use receipt. Synthetic 48-entry registry parsing benchmark, 1000 loops: median **0.02802ms**, p95 **0.08019ms**, worst **2.1367ms**. No real ai-g732 product-generator files or Android build runtime measured yet; do not extrapolate.

**Actual A1R ai-g732 NOT EXECUTED**. Do not claim complete image build, Android graphic success or runtime device testing.

```text
A1P_TWELVE_STAGE=ACTUAL_PASS
A1Q_THREE_INDEPENDENT_GIT_STORES=ACTUAL_PASS
A1Q_CONFIG_ERROR=PRODUCT_CONFIG_MAKEFILE_NOT_REGISTERED
A1R_LOCAL_ZIP_SHA12_AST7_BASH_TEST30_BOTH_UMASKS=PASS
A1R_AI_G732=NOT_EXECUTED
BUILD_READY=NO IMAGE_BUILD=NO SUPER=NO DEVICE=NO FLASH=NO
```