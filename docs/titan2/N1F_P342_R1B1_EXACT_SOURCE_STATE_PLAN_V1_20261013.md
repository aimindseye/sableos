# N1F PR #342 — two-file R1/B1 exact source-state preflight V1

Date 2026-10-13. **Distribution script prepared, tested and packaged; ai-g732 execution = PLAN-ONLY / NOT RUN.** Source inspection and any source mutation/build require a separate future operator authorization. The previously authorized October 5 A4 two-text receipt inspection has now executed successfully and cannot be reused to read Android source.

## Why this is the next small technical gate, rather than an R2 or A4 rescan

Actual N1I-A A4 inspection returned `PASS_HISTORICAL_A4_RECEIPTS_NOT_RUNTIME_NAMESPACE` for **two SHA-bound host text receipts**, bytes 25,683 + 6,678, both A4 PASS markers true and `native_unresolved_none=true`. This is exactly *historical* source-dependent native closure, not new N1F privileged IMS process namespace admission. Existing C2 33-path finite manifest, five R2 SHA/ELF, 56 direct NEEDED, 19 tested Bionic cases, six N1F-vs-stock provider exported-name matches, V28 four direct GNU label/version checks, M4 six provider ELF metadata and two API36 boot JARs **remain PASS_PRIOR_SCOPE**, no reanalysis.

Prior [PR #339 exact mutation/build plan](https://github.com/aimindseye/sableos/blob/n1i-d1r4-cw1-compiled-checkpoint-20261011/docs/titan2/N1F_M4_EXACT_MUTATION_AND_BUILD_AUTHORIZATION_PLAN_20261012.md) and [R2 historical evidence reuse matrix](https://github.com/aimindseye/sableos/blob/n1i-d1r4-cw1-compiled-checkpoint-20261011/docs/titan2/N1F_M3_R2_PRIOR_EVIDENCE_REUSE_MATRIX_20261012.md) **already define the exact R1 manifest PRE/POST SHA and TelephonyMetrics B1 Git blob PRE/POST**, and include an exact R1 *no-write* patch preview PASS. There is no reason to re-run the R1 preview. The existing main `product/titan2/n1i-c1/sable-titan2-n1i-c1.mk` and `Android.bp` own the C1 integration, and `build/config/host-tools.env` declares future Android build binaries; they are **not needed for this source-state inspection**. PR #342 [actual Oct03 run-source V2](N1F_OCT03_RUN_SOURCE_LP_AUTHORITY_V2_20261013.md) already confirmed archived 991 C3A heads and exact ordered Oct03 successful system_a run markers. No project-head recensus, image hash or reflash.

The next proposed Oct03-derived isolated *host build* needs to know whether exact R1/B1 source mutations are already POST in its **chosen Android 16 workspace** or still at the reviewed PRE. This new two-file preflight answers just that, without selecting the workspace or editing its files.

## Inputs and contract

Prepared external ZIP `N1F_P342_R1B1_SOURCE_V1.zip`, SHA256 `d5d51bf25b725c6254cef39038caed60c486a0901893a33a7440a77e899dfa1b`; exactly five ZIP files (main Python source, 34-test suite, detailed plan, README, four-file internal SHA256SUMS manifest). Script SHA256 `14f03c679a9483aa5f306b5420028ade34edbd391c398699f3d9a358986c8e56`; tests SHA256 `bc337e61085574e80b3f6099d85f587524cc8c77054644104066d0b07fa09ad0`.

Exact two read-only source leaves **relative to an explicitly operator-identified selected Android 16 workspace**:
1. `frameworks/base/core/res/AndroidManifest.xml`: R1 PRE SHA256 `2fe068aa663608ef5e21108d97ba95e9b3bfa0dfaaa7add982d3eb86b8af0e7c`; exact R1 POST preview SHA256 `2e3ffb1d771cb6977670a800f0a27ffd24a9cf252ff0890e92ac98f9f90e37ca`.
2. `frameworks/opt/telephony/src/java/com/android/internal/telephony/metrics/TelephonyMetrics.java`: B1 PRE **Git blob SHA1** `27638e5be9c008101c2f9b8f1e7a9af49d94f838`; POST **Git blob SHA1** `9d5108e0ddb8d4960d21cda021813b53dbbf4da8`. Git blob hash means SHA1 of `blob <size>\0` + raw file bytes, not raw-file SHA1.

Default `plan` is no filesystem access. Future *separately approved* `inspect --android-root <exact-root> --authorize-exact-r1-b1-source-bytes` reads only those two source files, each <=2MiB (<=4MiB total), and produces PRE_EXACT, POST_EXACT or OTHER_BLOCK. It fails closed on source/root symlink, relative/dot/double-slash path, unreadable or non-regular file, overcap, unstable changed-during-read, or unexpected identities. Paths must be underneath one of the two allowed workspace parent prefixes `/srv/sable-build/workspaces` and `/srv/data/sable-build/workspaces` **with a further component**, no workspace discovery, not inferred from `system.img` path. No ELF, image, native-A4, Git/Soong/Gradle, external commands, output writes, build, network, device or flash. PRE/POST recognition does not prove selected 991-project lineage or G1/G2/G3 and is **not source mutation authority**. Use only Python >=3.10 stdlib; `unzip` and `sha256sum` for distribution validation, no dependencies installed.

### Local QA

- Python AST syntax both files **PASS**; ZIP structure and inner manifest 4/4 **PASS**; README plan-mode shell syntax **PASS**.
- **34/34 synthetic Python regression tests PASS**, 0.030 seconds isolated unittest core; complete test process 0.72s / peak RSS 100,364 KiB.
- 400 synthetic two-source scans using 256KiB + 320KiB small files (589,824 bytes total) median **0.635ms** and p95 **0.846ms** on the assistant container, not ai-g732 runtime.
- Regression scope includes plan zero filesystem, explicit inspect gating, PRE/POST/unknown, correct Git blob hashing, root/ancestor/leaf symlink refusal, oversize limit, missing or directory leaf, no partial results, descriptors closed, no mutation/subprocess/network/import, and final-image no-promotion.
- **Real ai-g732 source inspection NOT EXECUTED**; no selected exact source-root revision is bound by this package.

## Follow-on milestones (distinct authorities)

**A (source-bound host-only R1+B1+C1 systemimage specimen):** Determine exact PRE/POST results and existing C1 install/source pins first. If source differs from historical PRE/POST, **STOP**; do not apply guessed patches. If approved separately, create isolated no-clobber checkout and incremental host-only Android 16 image build, with new effective G1/G2 image-specific verification. Preserve skip_mount and no physical system_ext replacement. This package itself never creates or builds an image.

**B (five-R2 integrated candidate):** Reuse all completed historical R2/A4 evidence; final full recursive symbol/version and **new selected image's effective privileged IMS process linker namespace** remain **NOT_EVIDENCED**, not an ABI failure. Do not import the five ELF files under an unconditional G3=PASS. Android systemimage build and whole-super assembly require distinct later decisions; Oct03 physical companion seven identities, LP/Virtual A/B, AVB and matched restoration remain unbound. Device/flash always separately held.

```text
A4_OPERATOR_RECEIPTS=PASS_2_SHA_AND_NATIVE_MARKERS
A4_RECEIPT_AUTHORITY=CONSUMED
R1_B1_EXACT_PRE_POST_PINS=AVAILABLE_PR339
R1_B1_SOURCE_STATE_TOOL_LOCAL=PASS_AST_34_TESTS_ZIP_SHA
R1_B1_SOURCE_STATE_AI_G732=NOT_RUN
R1_B1_NEW_SOURCE_BYTES_AUTHORIZED=NO
R1_B1_SOURCE_WORKSPACE_SELECTED=NO
G1_G2_NEW_IMAGE=NOT_BUILT
G3_FULL_SELECTED_RUNTIME_NAMESPACE=NOT_EVIDENCED
R0C_256_TEE14_INSPECTION=NOT_AUTHORIZED
OCT03_PHYSICAL_7_AND_LP_AVB_RESTORE=UNBOUND
SOURCE_MUTATION=NO BUILD=NO NETWORK=NO DEVICE=NO FLASH=NO
```

## Actual ai-g732 34/34 PLAN PASS and later two-file read authorization — pre-existing source result found

User supplied actual checksum-pinned `N1F_P342_R1B1_SOURCE_V1.zip`: ZIP outer and four internal members `PASS`, 34/34 Python tests `PASS (0.021s)`, and `PLAN_ONLY_NO_HOST_FILESYSTEM_ACCESS`. Operator then explicitly approved **read-only inspection of exactly these two source files in the selected Android16 workspace**. This authorizes one such two-file read **once the selected exact new source-root is bound**, but not workspace discovery, a different/historical root guess, source mutation, build or phone actions. No actual ai-g732 new source-byte inspection has been performed.

A retrospective archived [PR #339 V38](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5497214527) review reveals historical `/srv/data/sable-build/workspaces/titan2-n1d/android` **already tested R1=PRE and B1=PRE**, and the separately built [M4 isolated Android source](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5497674970) finished R1=POST and B1=POST on its own lineage. Do **not** repeat either original-root check just to emit the same hash-state labels. M4 resulted in Recovery and is not itself the approved Oct03 next parent. A separate *new* Oct03-derived source checkout is **not yet selected** by exact path/source-head; operator's permission is preserved, not consumed. See [controlling no-repeat source-root decision](N1F_P342_R1B1_PRIOR_WORKSPACE_DECISION_V1_20261013.md).

Assistant repeated ZIP integrity and inner checksums, AST/test syntax and 34/34 regressions in 0.032s core unittest (new local repeat); no actual ai-g732 source files read. Original fixture benchmark 400 synthetic two-file read/hash cycles median 0.635ms/p95 0.846ms is assistant-host-only. Python3.10+ standard library suffices; checksum/unzip only for archive handling. **No additional script or provider inventory** is necessary. New-image source lineage, G1/G2/G3, LP/AVB/restoration and flash gates unaffected.

```text
R1B1_SOURCE_TESTS_AI_G732=PASS_34_OF_34
R1B1_TWO_EXACT_SOURCE_READ_OPERATOR_PERMISSION=YES_ONE_SELECTED_ROOT
R1B1_NEXT_BUILD_SOURCE_ROOT=UNBOUND
R1B1_NEW_SOURCE_CONTENT_INSPECTION=NOT_RUN
ORIGINAL_V38_SOURCE_STATES=R1_PRE_B1_PRE_PASS_PRIOR
M4_ISOLATED_SOURCE_STATES=R1_POST_B1_POST_PASS_PRIOR
SOURCE_MUTATION=NO BUILD=NO DEVICE=NO FLASH=NO
```
