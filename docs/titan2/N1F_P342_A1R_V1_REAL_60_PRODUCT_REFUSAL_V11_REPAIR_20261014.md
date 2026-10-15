# PR342 — A1R V1 actual safe refusal; V1.1 exact 60-product generator repair

Date 2026-10-14. PR342 engineering lane. Operator previously completed A1P 12/12 payload+policy source leaves; A1Q three borrowed Git object stores fsck independent 3/3. A1Q graph config had failed on nonexistent `treble_arm64_bvN` product. A1R V1 was the selected source replay operation.

## Actual A1R V1 ai-g732 result

ZIP outer SHA PASS, 12/12 bundled SHA PASS, Python AST/Bash syntax PASS, 30/30 fixture regressions PASS (0.095s), plan confirms zero host I/O and 48 expected product matrix. The real V1 operation returned:

```json
{"build_ready":false,"reason":"generated_product_registry_wrong_count_or_duplicate:60","status":"REFUSED_A1R_PREFLIGHT_NO_SOURCE_WRITE","systemimage":false}
```

**No A1R source writes or one-use A1R evidence creation occurred.** The result was a controlled preflight refusal. A1P source, A1Q three Git project repacks, ROM, policy and guard stay untouched. DO NOT rerun V1 or the completed earlier A1F–A1Q tasks.

## Source-of-truth root cause, no new discovery step

The SableOS main `build/titan2/n1d-c3-trebledroid.env` pins PHH TrebleDroid generator and source project commit **`39ba82ef89ff5bf6b22ca8f147dbf317bffa20ed`**. Actual GitHub upstream `TrebleDroid/device_phh_treble/generate.sh` at this exact commit contains:

```sh
for part in a ab;do
    for apps in vanilla gapps foss gapps-go old;do
        for arch in arm64 arm a64;do
            for su in yes no;do
```

The fifth `old` variant generates suffix **`y`**, alongside `vanilla=v`, `gapps=g`, `foss=f`, `gapps-go=o`. Thus generator output is **2×5×3×2=60** product makefiles plus one `AndroidProducts.mk` registry, not V1's **48**. V1 fixture copied its own wrong four-variant assumption and missed this mismatch. This is a test coverage defect, **not** evidence of 60 unexpected user-source files.

## Replacement A1R V1.1 exact operator deliverable

External ZIP **`N1F_P342_A1R_GENERATED_PRODUCT_GRAPH_REPAIR_V1_1.zip`** has exact SHA256 **`d2a7424c4249c4ac24a681f74b85d95033a423b6c40e2e97fec72647fea6932f`**, **42,731 bytes**. 13 archive members (12 sealed members + `SHA256SUMS.txt`); main production Python `n1f_p342_a1r_generated_product_graph_repair_v1.py` SHA256 **`f05b580f451bb5095c96e34f3aed1f908b4bd2eabef79704ed2cf893aa4b0b6e`**; revised operator wrapper `n1f_p342_a1r_one_command_v1_1.sh` SHA256 **`288eaadc669265bbdc53304c4a52a39331137ccf8922b9107705c9110d1f8ea2`**. Other inherited A1D/A1M/A1O/A1P/A1Q source/validators remain unchanged in ZIP.

Only production changes: `EXPECTED_COUNT=60` and `ALLOWED_RE` fifth `y` suffix; required exact 60-file cartesian matrix v/g/f/o/y; explicit generator source line `for apps in vanilla gapps foss gapps-go old;do` required in both matching A1 and M4 generator files. Neither the graph code nor the exclusive source-write logic nor project paths were broadened. V1.1 plan now reports 60 generated mk files, one registry = 61 maximum create paths. Existing A1 generated files must be byte-exact, otherwise refuse. `rom.mk` is NOT overwritten, historical generator not executed, `.repo` not created, no Git repacks, no old audits/reimports.

**One operator command**, from ZIP SHA-verified fresh extraction:

```sh
bash ./n1f_p342_a1r_one_command_v1_1.sh --authorize-a1r-exact-generated-product-replay-and-graph-only
```

Wrapper first runs inner checksums, Python AST/compile, Bash syntax, 35 tests and I/O-free plan; then single opt-in A1R source replay and config-only `lunch treble_arm64_bvN-bp4a-user; m -j4 nothing`. Prior A1R V1 refusal left its receipt absent and permits this exact one-use replacement. If graph fails, preserve one-use A1R receipt, generated output and `config-graph.log`; **do not automatically retry, clean or roll back**. Only a real complete graph PASS makes `BUILD_READY=true` for a host-only engineering image build candidate; no systemimage or flash in this package.

## Syntax, performance, and synthetic regressions

- Assistant sandbox ZIP CRC PASS, **12/12 SHA256 internal members PASS**, 7 Python AST/compile PASS, Bash syntax PASS.
- **35/35 focused synthetic tests PASS** with umask 077 (0.217s) and 022 (0.220s); from freshly extracted exact ZIP both umasks again **35/35 PASS** (0.252s / 0.247s), SHA12 and compile7 PASS.
- New explicit tests cover all 12 `old/y` matrix combinations, tampered/missing y variants, arbitrary new suffix refusal, 60 count/plan, and mismatch between synthetic 60 registry and four-variant historical generator source. Existing one-use 61-leaf, partial present, symlink, source-hash mismatch, and graph-only fixtures remain.
- Local synthetic parser 1200 iterations median **0.031811ms**, p95 **0.062291ms**. Bounded complete 61-leaf fixture preflight 50 iterations median **3.995432ms**, p95 **5.074323ms**. These are **not** actual ai-g732 historical read or Soong runtime benchmarks.

**A1R V1.1 actual ai-g732 execution NOT RUN**. PR #342 remains OPEN/DRAFT/UNMERGED. No network, image build, mount, super, device, or flash. `.A1_INCOMPLETE_DO_NOT_BUILD` must remain preserved and `out-a1` absent.

```text
A1P_PAYLOAD_AND_POLICY_STAGE=ACTUAL_PASS_12
A1Q_GIT_INDEPENDENCE=ACTUAL_PASS_3
A1Q_ANDROID_CONFIG=FAILED_MISSING_TREBLE_PRODUCT
A1R_V1_ACTUAL=REFUSED_PREFLIGHT_WRONG_48_ASSUMPTION_REAL_COUNT_60_NO_WRITES
A1R_V11_LOCAL_PACKAGE=PASS_ZIP_CRC_SHA12_AST7_BASH_TEST35_BOTH_UMASKS
A1R_V11_REAL_HOST=NOT_EXECUTED
BUILD_READY=NO SYSTEMIMAGE=NO SUPER=NO DEVICE=NO FLASH=NO
```