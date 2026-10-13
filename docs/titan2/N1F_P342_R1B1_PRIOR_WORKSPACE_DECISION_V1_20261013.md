# N1F PR #342 — exact R1/B1 source selection and prior-result reconciliation V1
Date: 2026-10-13. **READ-ONLY TWO-FILE AUTHORIZATION GRANTED, BUT NO UNIQUE NEXT-IMAGE SOURCE ROOT SELECTED OR INSPECTED.** Documentation-only; no source modification, build, image, network, device or flash.

## Actual operator evidence and no-repeat finding

The operator verified the existing frozen `N1F_P342_R1B1_SOURCE_V1.zip` outer SHA256 `d5d51bf25b725c6254cef39038caed60c486a0901893a33a7440a77e899dfa1b` and all four inner entries: PASS; `python3 -B -m unittest -v test_n1f_p342_r1b1_source_v1` **34/34 PASS in 0.021s**; default `plan` reported `PLAN_ONLY_NO_HOST_FILESYSTEM_ACCESS`. Afterward the operator authorized **read-only inspection of exactly R1 `frameworks/base/core/res/AndroidManifest.xml` and B1 `frameworks/opt/telephony/src/java/com/android/internal/telephony/metrics/TelephonyMetrics.java` within the selected Android16 workspace**. This new authorization is independent of the already consumed A4 two-text-receipt authority. It does not authorize choosing *multiple* trees, source edits or build.

Cross-checking PR #339 and the earlier project conversation surfaced **existing actual source state qualifications**, making an automatic re-run wrong:

| Known historical Android16 root | Actual existing evidence | Interpretation |
| --- | --- | --- |
| `/srv/data/sable-build/workspaces/titan2-n1d/android` | [PR339 V38 operator PASS](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5497214527): exact R1 `PINNED_PREVIEW_READY_NOT_APPLIED` (PRE), B1 `KNOWN_PRE_BLOB`; platform HEAD `dfb660a1fd590efed475f388870032d2d416403b` | PRE/PRE **already evidenced** at V38 time for **original** working tree, not final currently rehashed bytes and not an authorized new build checkout |
| `/srv/data/sable-build/workspaces/n1f-m4-ims01/android/frameworks/base` | same [V38 report](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5497214527): R1 one-line patch post SHA `2e3ffb1d771cb6977670a800f0a27ffd24a9cf252ff0890e92ac98f9f90e37ca` **PASS** | Different **partial** isolated R1 tree, not a complete two-file Android workspace |
| `/srv/data/sable-build/workspaces/n1f-m4-localrepo/android` | [PR339 G1 M4 selected R1 POST/B1 PRE](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5497417821), later [official B1 PRE→POST integration](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5497674970) with post Git blob `9d5108e0ddb8d4960d21cda021813b53dbbf4da8`; [actual M4 image source chain](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5504302075) | historical 991/991 reconstructed M4 source **R1 POST + B1 POST recorded**, with source-image linkage partial; subsequently used for M4 system image that booted Recovery, **not the chosen proven next parent** |

The historical **October 3 N1F** boot-qualified host `system.img` remains distinct: SHA256 `dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a`, 3,200,540,672 bytes. **Do not infer Oct03 artifact↔M4 complete source project-head equivalence** from having used a 991-project reconstruction or from R1/B1 POST. The October 11 live hybrid super journal remains unbound. Previous Oct03 source/run-log audits are already complete for their limited scopes.

### Decision on the newly authorized inspection

**Do not silently choose either earlier root or rerun V38/M4 source probes.** At this checkpoint `NEXT_OCT03_DERIVED_ANDROID16_SOURCE_ROOT=UNBOUND`; the user has not specified or previously proven that either historical root is their **selected new isolated next-image checkout**. No distinct new source-root actual ai-g732 two-file read has been executed. The one-approved inspection may be spent **once** on an explicitly selected *different* exact Android16 workspace root under `/srv/sable-build/workspaces/<project>/...` or `/srv/data/sable-build/workspaces/<project>/...`, if one is already available and source selection is independently justified. This is not authorization to create a checkout, search for roots, traverse directories, call git/repo, or infer a root from image paths. Refuse missing root rather than use a historical fallback.

## Reuse existing verified tool, do not write another implementation

The user-supplied frozen `N1F_P342_R1B1_SOURCE_V1.zip` was revalidated in the assistant environment:

```text
OUTER_SHA256=d5d51bf25b725c6254cef39038caed60c486a0901893a33a7440a77e899dfa1b PASS
ZIP_INTEGRITY=PASS
INNER_SHA256SUMS=PASS_4_OF_4
PYTHON_AST=PASS_SOURCE_AND_TEST
SYNTHETIC_REGRESSIONS_LOCAL_REPEAT=PASS_34_OF_34
LOCAL_REPEATED_UNITTEST_RUNTIME=0.032s (core unittest, host startup excluded)
OPERATOR_AI_G732_TESTS=PASS_34_OF_34 (0.021s core)
AI_G732_REAL_SOURCE_INSPECT=NOT_EXECUTED
```

The existing Python 3.10+ stdlib script has two fixed relative names only, 2 MiB per-file and 4 MiB combined caps, per-ancestor directory `O_NOFOLLOW`, leaf no-follow, no discovery, read-only fd-relative operations and exact PRE/POST comparisons: R1 file SHA256 pre `2fe068aa663608ef5e21108d97ba95e9b3bfa0dfaaa7add982d3eb86b8af0e7c`, post `2e3ffb1d771cb6977670a800f0a27ffd24a9cf252ff0890e92ac98f9f90e37ca`; B1 proper Git blob SHA1 pre `27638e5be9c008101c2f9b8f1e7a9af49d94f838`, post `9d5108e0ddb8d4960d21cda021813b53dbbf4da8`. Any OTHER state returns BLOCK, never patches. Original local 400-run synthetic 589,824-byte two-file inspect measured median 0.635ms / p95 0.846ms; **assistant fixture timing, not ai-g732**. No image, ELF, A4/B2/R2 scan, external tool, output write, network, build, device or flash. `unzip`/`sha256sum` are package transfer tools only.

Safe **conditional**, explicit-root invocation after verifying package, **not a guess**:
```bash
: "${SELECTED_ANDROID_ROOT:?Explicitly identify the chosen new isolated Android16 workspace before inspecting}"
python3 -B n1f_p342_r1b1_source_v1.py inspect --android-root "$SELECTED_ANDROID_ROOT" --authorize-exact-r1-b1-source-bytes
```
Do **not** set `SELECTED_ANDROID_ROOT` to the original V38 PRE/PRE source or the failed M4 POST/POST source just to get a PASS. The tool's `PASS_TWO_SOURCE_STATES_IDENTIFIED_NOT_SOURCE_LINEAGE` is a hash-state classification, **not exact next-image source lineage or any build authority**. A symlink refusal is a hard stop, not a cue to substitute a canonical alias.

## Gates after selecting source

The next source-based Android16 host-only candidate needs separate exact source lineage/allowlist and **source mutation/build** authorization. Prior R1 no-write preview, B1 official patch, six C1 modules, M11 compile, M4 image embedded 11/11, G2 M11 platform cert/API36 bootclasspath and five R2 56 direct edges/19 Bionic/four GNU, N1I-A A4 actual two pinned text SHA **all PASS at their original scope**; DO NOT repeat. New selected image effective G1/G2 and G3 selected process linker namespaces remain distinct. Seven Oct03 companion byte identities, LP/Virtual A/B, AVB, matched restore unbound. R0C 256-name TEE14 inspection unapproved.

```text
R1B1_AI_G732_PACKAGE_TESTS=PASS_34_OF_34
R1B1_TWO_FILE_READ_AUTHORITY=USER_APPROVED_ONE_SELECTED_ROOT
R1B1_CURRENT_APPROVED_ROOT=UNBOUND_NO_NEW_READ
ORIGINAL_V38_R1_B1=PRE_PRE_PRIOR_PASS
HISTORICAL_M4_R1_B1=POST_POST_PRIOR_SCOPED_PASS
OCT03_DERIVED_NEW_SOURCE_LINEAGE=NOT_BOUND
A4_ACTUAL_TWO_RECEIPT_SHA_AND_PASS=COMPLETE
R2_PRIOR_NATIVE_STATIC=COMPLETE
NEXT_IMAGE_G1_G2_G3=TARGET_SPECIFIC_GATES
SOURCE_MUTATION=NO BUILD=NO LP_AVB_IMAGE_READ=NO DEVICE=NO FLASH=NO
```

## 2026-10-13 follow-up — rooted in actual original N1F driver and the 991-project reconstruction

Operator lacked `$SELECTED_ANDROID_ROOT` and explicitly directed us to recover it from previous project chats, GitHub and PRs rather than ask the operator to guess. **Two Android16 source roots are already documented and their roles must be separated.**

1. **Original October 3 N1F source build root (historical baseline):** `/srv/data/sable-build/workspaces/titan2-n1d/android`. Operator's Oct12 [four workstreams / R1 execution record](https://github.com/aimindseye/sableos/blob/n1i-d1r4-cw1-compiled-checkpoint-20261011/docs/titan2/N1F_OCT12_FOUR_WORKSTREAM_STATUS_AND_R1_EXECUTION.md) confirms this literal root, `out-c3a-td`, `tdgsi_arm64_ab`, and original `build/titan2/run-n1f-c3a-derived-c3b5-r2.sh` selected build entrypoint; PR339 V38 already verified **R1 PRE + B1 PRE**. The actual driver builds `ANDROID_ROOT=$SABLE_BUILD_ROOT/$N1D_ANDROID_ROOT_REL` with `N1D_ANDROID_ROOT_REL=workspaces/titan2-n1d/android`; the operator report recorded the **/srv/data/sable-build** form. `build/config/storage.env` defaults to `/srv/sable-build` unless overridden; the relationship between the two prefixes **must not be guessed or silently resolved via symlink**. The `out-c3a-td` image digest `ea10fc...` did NOT match Oct03 sealed N1F system image digest `dc1f917...`; same source pathname does not imply the current output matches historical image bytes. Original canonical source is **not** an acceptable unreviewed mutation target.

2. **Isolated 991-project M4 Android16 source root (best existing source-side integration candidate):** `/srv/data/sable-build/workspaces/n1f-m4-localrepo/android`. The same original Oct12 document records a four-project pilot plus 987 local-object project materializations from the exact sealed C3A 991-row ledger, **`M4_991_PROJECT_HEADS=PASS`, `M4_OFFLINE_987=PASS_SOURCE_ONLY`**; historical PR339 reports R1 POST in selected M4 and the later official B1 PRE→POST patch PASS, and targeted 14,094-action M11/full M4 builds at separate `out-m4-ims03` / `out-m4-g2-fullimage-01` outputs. This is a **source checkout**, not the failed M4 image itself, but source-to-Oct03 booting artifact **complete lineage is not proven** and a physical M4 system_a boot later **FAIL_RECOVERY**. It is therefore the best-supported **existing isolated root for source-state assessment**, but **not a certified boot-qualified parent or permission to rebuild**.

3. **Partial R1 worktree — exclude for two-file probe:** `/srv/data/sable-build/workspaces/n1f-m4-ims01/android/frameworks/base` contains only the R1 `frameworks/base` project; cannot supply B1 under `frameworks/opt/telephony` as one Android root.

**Operational resolution:** Set `SELECTED_ANDROID_ROOT=/srv/data/sable-build/workspaces/n1f-m4-localrepo/android` **only if the purpose is a current read-only confirmation of the isolated existing M4 integration checkout**. This revalidates current on-disk R1/B1 source identities after the historic PR339 PASS; it is **not** the selection of a newly proven Oct03-derived clean build parent, and should not trigger R1/B1 patch replay. If the objective instead is to inspect the original **Oct03 baseline** source, the literal root is `/srv/data/sable-build/workspaces/titan2-n1d/android`, but its historical PRE/PRE has already passed V38. Do not run both merely to populate a form. The single authorized two-file inspection can be spent once on the isolated M4 root when current source-state re-attestation is desired; still no build/source mutation/flash authority. If a nofollow path or leaf check fails, report failure and **stop**, do not switch to another root/alias.

Verified unchanged user package in assistant container: outer ZIP sha256 `d5d51bf25b725c6254cef39038caed60c486a0901893a33a7440a77e899dfa1b` PASS; inner SHA256SUMS four members PASS; both Python AST PASS; **34/34 repeat synthetic tests PASS (0.027s core)** and `inspect` CLI still requires `--android-root` plus `--authorize-exact-r1-b1-source-bytes`. No host root byte read occurred. Actual ai-g732 current root existence/no-symlink and byte states still unverified by this assistant.

```text
ORIGINAL_OCT03_N1F_ANDROID16_ROOT=/srv/data/sable-build/workspaces/titan2-n1d/android
ISOLATED_M4_ANDROID16_ROOT=/srv/data/sable-build/workspaces/n1f-m4-localrepo/android
RECOMMENDED_CURRENT_INTEGRATED_SOURCE_ATTESTATION_ROOT=ISOLATED_M4_ONLY
EXACT_NEXT_OCT03_BOOT_PARENT_SOURCE_TO_NEW_ARTIFACT=UNBOUND
OPERATOR_ONE_TWO_SOURCE_READ_AUTHORITY=YES_SELECTED_ONE_ROOT_ONLY
CURRENT_M4_R1B1_CONTENT_READ_THIS_TURN=NOT_EXECUTED
SOURCE_MUTATION=NO BUILD=NO IMAGE_READ=NO DEVICE=NO FLASH=NO
```
