# PR #342 — A0 exact protected workspace and cellular/CW1 input custody V1

Date: 2026-10-13. **Engineering deliverable only; actual ai-g732 A0 inspection NOT EXECUTED.** User requested the next deliverable with project-chat, PR342 and repository cross-check, syntax/performance validation and PR342 status update. Prior Oct03/M4 PHH-policy V1.1 actual member comparisons remain PASS and are not repeated. Operator agrees future Oct03-derived A1/A2 source-build sequence but no exact selected clean new Android16 checkout, OUT path, source mutation or new build is approved.

## Prior scope already complete — no duplication

1. The [historical Oct03 / M4 R1+B1 root decision](N1F_P342_R1B1_PRIOR_WORKSPACE_DECISION_V1_20261013.md) binds original N1F source at `/srv/data/sable-build/workspaces/titan2-n1d/android` and isolated M4 991-project reconstructed source at `/srv/data/sable-build/workspaces/n1f-m4-localrepo/android`. Exact M4 two-source operator R1/B1 POST/POST PASS, 544326 source bytes already read, and independent Oct03 V38 PRE/PRE PASS. M4 partial C3B/PHH changes and image Recovery outcome mean the M4 checkout is **NOT a qualified Oct03 booting parent**, although it is useful as an exact source donor. Do not rerun R1/B1, 991 heads, M4 system.img hash/build or image member checks.
2. [Closed unmerged CW1 PR #339](https://github.com/aimindseye/sableos/pull/339) and [CW1 path registry](https://github.com/aimindseye/sableos/blob/n1i-d1r4-cw1-compiled-checkpoint-20261011/docs/titan2/N1I_CELLULAR_EVIDENCE_PATH_REGISTRY_20261011.md) bind an independent isolated Android tree `/srv/data/sable-build/workspaces/n1i-d1r4-cw1-isolated/android`, warm `out_cw1`, and one 2693-byte patch file `/srv/data/sable-build/evidence/titan2/n1i-d1r4-callwaiting-preview-v2/D1R4_CALLWAITING_SOURCE_PREVIEW.patch` SHA256 `4d2ad6b567ca725e8cc45c0362cdd788e3425c668592241aa4da007aa019635d`. Compiled telephony-common.jar 4950565 bytes SHA256 `76b335c3114c55f166edeef392889e4c908aceab9a9e92dec64f5f90c690af9f` and four DEX definitions PASS; consumer invoke-super PASS_STATIC_ONLY, runtime waiting not proven. Do NOT rebuild/re-hash compiled JAR or use CW1 source as Oct03 checkout.
3. [Merged PR327](https://github.com/aimindseye/sableos/pull/327) sealed 36 proprietary C2 input files under `/srv/data/sable-build/titan2/artifacts/n1i-c2-cellular-mvp-stock/20261005T231205Z`; [draft PR328](https://github.com/aimindseye/sableos/pull/328) established corrected 28 frozen native imports plus five Android16 platform owner reuse after a 33-native Kati collision; [draft PR331](https://github.com/aimindseye/sableos/pull/331) contains the successful C2 built system image and postbuild plan; [draft PR334](https://github.com/aimindseye/sableos/pull/334) records failed physical C1/C2 boot. No 33-file materialization/hash replay, C2 rebuild or new native G3 claim in A0.
4. [Current PR342 cellular/CW1 expansion](N1F_P342_CELLULAR_CW1_EXPANDED_HYBRID_BUILD_DECISION_V1_20261013.md) gates A1 as Oct03-derived C1/R1/B1/guard/overlay/incoming-call/observe-only readiness, A2 conditionally CW1 source and 28 native imports after exact source/owner/IMS process G3. Effective embedded `/system/system_ext` inside future Android16 system.img, preserve skip_mount. Oct11 actual as-flashed super SHA and matched companions remain unbound; neither M4 nor C2 physically passed stable Android boot.

## New A0 read-only fixed-path verifier — no 991-project census

Distribution `N1F_P342_A0_CUSTODY_V1.zip` **outer SHA256 `33cf05666b1d51992fd1a1bd7c4f127695a881062e304fb2e5f0c08c47537732`**, 9712 bytes. Main script SHA256 **`e46020ee75dbe4762794b02d6fbe789b7fdb98981eb1a872ded89680b0b76255`**. Four SHA manifest entries. Five ZIP members: `n1f_p342_a0_custody_v1.py`, `test_n1f_p342_a0_custody_v1.py`, plan, README, SHA256SUMS.

The executable is **Python 3.10+ stdlib only**. Default `plan` returns zero host evidence I/O. `inspect --authorize-readonly-a0` checks EXACT eight literals, no path discovery:
- **directory metadata only:** original Oct03 source and `out-c3a-td`; selected isolated M4 source and protected failed `out-m4-g2-fullimage-01`; CW1 isolated source and protected `out_cw1`; C2 sealed frozen stock artifact root.
- **one exact byte read:** frozen 2693-byte CW1 original patch, SHA256 must equal `4d2ad6b567ca725e8cc45c0362cdd788e3425c668592241aa4da007aa019635d`. It never prints patch content.
- Uses dirfd-relative `stat(..., follow_symlinks=False)`, `O_DIRECTORY|O_NOFOLLOW` for ancestors and `O_NOFOLLOW|O_NONBLOCK` for the 2693-byte patch leaf. A symlink/missing/non-directory component is classified, never silently followed; **no** `realpath`, `find`, directory enumeration, user `git`/`repo`, manifest/project scans, Android source-byte reads, image-byte reads, build, network, device or flash.
- Result is deliberately **always** `A0_CUSTODY_METADATA_ONLY_NEW_PARENT_AND_OUT_NOT_BOUND`, even if all eight source/evidence paths exist. Historical M4/CW1/Oct03 roots and OUT are **PROTECTED**, not claimed as a new selected clean source; the missing `new isolated Oct03 checkout` and unique fresh OUT remain **UNBOUND**. An existing artifact's presence ≠ clean source lineage or source-build readiness.

**Validation on assistant fixture only:** Python AST 2/2 PASS, README Bash `-n` PASS, ZIP CRC PASS, four inner SHA PASS, **30/30 synthetic unit regressions PASS** (`0.009–0.014s` in recent runs), including default zero-I/O plan, strict authorization, fixed paths, symlink leaf/ancestor refusal, malformed paths, SHA match/mismatch, wrong size, no-mutation assertions and unbound-build status. **1200 synthetic full eight-role nofollow + patch SHA inspections** (temporary fake directories, no ai-g732 inputs), median **0.1159 ms**, p95 **0.1486 ms**, peak local process RSS **99084 KiB**. This measures local metadata+2.7KB file reads, NOT host filesystem / Android source compile / image performance. No actual ai-g732 tool execution. No new Android build script authored or invoked; there is therefore no unsupported build performance claim.

**Run requirements for A0 only:** Python 3.10+; `unzip` and `sha256sum` for distribution. Git/repo/Soong/Ninja/Java/adb/fastboot/debugfs not called. A subsequent real Android build preflight needs independently qualified host toolchain, source and OUT; this A0 cannot attest that.

## Next admission after real A0 output

Exact next isolated Oct03-derived source root **must** be separately identified, with fully pinned Oct03 C3A source lineage and original PHH base.mk state, distinct from frozen original and M4/CW1; a **fresh nonexisting OUT_DIR** selected without cleaning existing outputs. Then gate A1 exact PRE/POST before any source mutation, C1/C2 product manifests/bootpaths/certs and static policy, CW1 exact two-source patch and original consumer linkage if A2, native install-ownership and selected-process G3 if A2. Only **after separate operator source-mutation + host-only build authorization** may a new fail-closed driver build one nonflashable system image. No hybrid super assembly/LP/AVB/VAB, device, reset or flash under A0.

```text
A0_ZIP_AST_README_AND_30_REGRESSIONS=PASS_ASSISTANT_SYNTHETIC
A0_EXECUTED_ON_AI_G732=NO
OCT03_HISTORIC_SOURCE=KNOWN_PROTECTED
M4_ISOLATED_SOURCE=KNOWN_DONOR_NOT_BOOT_PARENT
CW1_ISOLATED_SOURCE_AND_OUT=KNOWN_PROTECTED
C2_FROZEN_36_STOCK_INPUT_ROOT=PINNED_METADATA_ROLE
CW1_PATCH_SHA256=PINNED_BUT_NOT_NEWLY_READ_HOST
NEW_OCT03_DERIVED_SOURCE_ROOT=UNBOUND
NEW_A1_A2_OUT_DIR=UNBOUND
SOURCE_MUTATION=NO BUILD=NO NETWORK=NO LP_REPACK=NO DEVICE=NO FLASH=NO
```
