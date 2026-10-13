# SableOS Titan 2 engineering status — 2026-10-13

**Authority:** documentation-only draft; [October 11 hybrid-derived reconciliation contract](titan2/N1F_OCT11_HYBRID_DERIVED_RECONCILIATION_20261013.md).

| Lane | Current state |
|---|---|
| Panther R9 | Previously accepted frozen touch-first reference, unchanged |
| Titan 2 Oct03 N1F | **Operator-selected OFFLINE PLANNING parent only**; previously boot-qualified sealed system image SHA256 `dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a` |
| Titan 2 Oct11 experiment | Android booted and brief data registration observed; exact flashed image/journal not bound |
| Titan 2 Oct13 M4 | system_a write completed; Android entered recovery; boot FAIL |
| Device after failed reset | Factory reset attempted unsuccessfully, operator returned device to fastbootd; recovery logs unavailable |
| Selected next work | Oct03 parent-source and matched LP/AVB provenance planning matrix; eventual hybrid super remains OFFLINE and requires separate build approval; embedded IMS into system/system_ext, G1/G2/G3 open |
| Device/build/release | NO new source mutation, build, device contact, flash, reboot, reset or production admission |

The [October 3 N1F parent-selection decision](titan2/N1F_OCT03_PARENT_SELECTION_DECISION_20261013.md) is for planning only: it does not select the unbound October 11 super, imply a matched whole-super parent, or authorize any image build, extraction or repack.

Historical research remains available on [closed PR #339](https://github.com/aimindseye/sableos/pull/339); its branch is not the active execution authority. The new draft PR is the governing engineering review. Public repositories must remain fail-closed; no Titan 2 public flash path is enabled.

## Oct13 evening: R0B actual and R0C scope decision

Oct03 N1F retained host `system.img` 3,200,540,672-byte SHA256 **PASS_HISTORICAL_REFERENCE_ONLY** (previously concluded); historic Oct03 boot PASS. N1C historical V01.00.14 stock restoration PASS with subsequent separate recovery factory reset. Latest ai-g732: two-root R0 super evidence first-root top-level metadata PASS 18 entries including 4,189,766,872-byte regular stock-super candidate, second TEE14 root `REFUSED_ENTRY_CAP` (64); follow-up R0B tested **20/20 PASS**, and all **seven** exact boot/AVB **direct** filenames returned `NOT_PRESENT_AT_THIS_EXACT_ROOT` (not globally absent). No receipt or image content was read in R0/R0B.

New [R0C plan and roadmap](titan2/N1F_P342_N1C_R0C_TEE14_PROVENANCE_AND_NEXT_IMAGE_GATES_V1_20261013.md) proposes **only after separate scope authorization** a one-root, one-level filtered name/type/size inventory capped at **256 immediate entries** and 96 matches. Prepared test-sealed ZIP and 22/22 local synthetic tests PASS, **R0C ai-g732 NOT RUN**. This is an explicit new cap; earlier R0 approval cannot be stretched to cover it. E4/C0 merged prior discovery mechanisms already exist and must not be rerun for this metadata problem.

**On the road to next image:** available N1F source/boot-control artifact yes; not yet an admitted IMS-enabled build or qualified offline whole-super. Remaining hard gates: 7/7 Oct03 physical companion SHA, postflash LP/VAB, AVB and full matched restore; final effective G1 embedded composition, G2 signing/classpath/SELinux and G3 IMS/native namespace. New build/repack and phone/flash still **NOT AUTHORIZED**. Use prior R1/C1/M11/991-project/56-edge evidence rather than repeating broad work; plan targeted G1/G2/G3 remediation alongside the evidence-provenance work.

## 2026-10-13 scope correction — G1/G2/G3 previously qualified work

Correction after operator directed review of the archived **“Update PR 339 Findings”** milestones: unqualified generic `G1=OPEN,G2=OPEN,G3=OPEN` language understated actual M4 achievement. Reuse **[PR #339 historical scoped PASS ledger](titan2/N1F_P342_G123_PRIOR_PASS_REUSE_AND_NEXT_IMAGE_DELTA_V1_20261013.md)**: G1 6 C1 packages/2 boot-JARs/2 overrides, resolved M4 source/product variables, B1/R1/PHH, skip_mount and 11/11 M4 embedded checks; G2 cryptographically SableOS-platform-signed M11 ImsService, exact manifest/shared UID *declaration*, M4 API36 bootclasspath exactly one enabled boot entry for each JAR, embedded XML/CIL; G3 5 R2 SHA, 56 direct DT_NEEDED, 19 Bionic, V28 four unversioned bindings and 6 M4 ELF metadata. The M11 14,094-target build and later complete M4 image were **performed** historically; M4 physical boot FAIL_RECOVERY. These historic PASS results are closed *at their own input-specific scope*, not rework tickets.

**For the *next*, distinct Oct03-derived image**, still require exact artifact effective embedded composition, effective merged SELinux/mount/classloader admission and recursive native/IMS namespace closure, plus Oct03 companions/LP/AVB/restore input authority. No new image build authorized or performed. Catalog-only `N1F_P342_G123_REUSE_V1.zip` SHA256 `ad7ffeea5d5fbd00d256946d3b86136d326227c632a4aba7aaf4a391a4486850`, synthetic 20/20 PASS, no ai-g732 evidence bytes read. Separately the operator R0C report is **PLAN_ONLY_NO_FILESYSTEM_ACCESS**, ZIP and **22/22 regression tests PASS**, `256`-entry inspection still unapproved. Main PR draft, no source/device/flash escalation.

```text
G1_G2_G3_HISTORIC_M4_NARROW_PASS=REUSE
G1_G2_G3_NEXT_IMAGE=OPEN_EXACT_DELTA
OCT03_PARENT_HOST_SHA=PASS_HISTORICAL_REFERENCE_ONLY
R0C_256_INSPECT=NOT_AUTHORIZED
SOURCE_MUTATION=NO NEW_BUILD=NO REPACK=NO DEVICE=NO FLASH=NO
```

## October 13 late checkpoint — actual A4 two receipts SHA PASS; R1/B1 preflight sealed

Operator's explicit once-authorized ai-g732 exact two **historical N1I-A A4 text** inspection: `PASS_HISTORICAL_A4_RECEIPTS_NOT_RUNTIME_NAMESPACE`; `N1I_A_V010014_OEM_IMS_REPORT.md` SHA PASS (25,683 bytes), `n1i-a-v010014-oem-ims.env` SHA PASS (6,678 bytes); both `N1I_A_NATIVE_DEPENDENCY_CLOSURE=PASS` and `N1I_A_V010014_OEM_IMS_DEPENDENCY_CLOSURE=PASS` confirmed from markers. No image/ELF read, extraction, build or phone. `A4_TWO_RECEIPT_CONTENT_READ_PERMISSION=CONSUMED` and **historical A4 provenance now verified**. This does not prove selected next-image `R2_FULL_IMS_APP_NAMESPACE`; keyword-only report presence flags cannot refute possible semantic G3 evidence elsewhere.

The next [source-state V1 plan](titan2/N1F_P342_R1B1_EXACT_SOURCE_STATE_PLAN_V1_20261013.md) uses **already previewed and Git-pinned** R1 Manifest SHA PRE/POST and B1 TelephonyMetrics Git-blob PRE/POST, avoids duplicating PR339 R1 preview or R2/IMS qualified code. External ZIP `N1F_P342_R1B1_SOURCE_V1.zip` SHA `d5d51bf25b725c6254cef39038caed60c486a0901893a33a7440a77e899dfa1b`. Local source/test Python AST PASS, 34/34 synthetic regression PASS, ZIP and inner manifest PASS, 400 synthetic two-file samples median 0.635ms/p95 0.846ms, **real ai-g732 R1/B1 source reads NOT AUTHORIZED / NOT RUN**. Script defaults to no-host-access `plan`; future exact two-source read (<=4MiB total) requires identified selected Android16 checkout and separate approval. Source mutation, Android build, LP/AVB/super, device and flash still held. G1/G2/G3 new image admission must be based on new target artifact, not inherited M4 audit.

```text
A4_OPERATOR_TWO_RECEIPT_HASH_AND_MARKERS=PASS
R1_B1_SOURCE_STATE_PREFLIGHT=PREPARED_TESTED_PLAN_ONLY
R1_B1_TWO_SOURCE_READ_AUTHORIZATION=NO
R0C_256_TEE14_DIRECTORY_METADATA_AUTHORIZATION=NO
G3_FIVE_R2_EFFECTIVE_NEW_IMAGE_NAMESPACE=NOT_EVIDENCED
BUILD=NO FLASH=NO DEVICE=NO
```

## Late October 13 R1/B1 source qualification no-repeat decision

Operator R1/B1 V1 outer/inner package SHA PASS, **34/34** tests (0.021s ai-g732), `PLAN_ONLY_NO_HOST_FILESYSTEM_ACCESS` PASS; user subsequently granted one read-only 2MiB/file exact R1+B1 source check in **the selected** Android16 workspace. Before executing, archived PR #339 V38 actual result already seals original `/srv/data/sable-build/workspaces/titan2-n1d/android` R1 PRE/B1 PRE; later isolated M4 source `/srv/data/sable-build/workspaces/n1f-m4-localrepo/android` R1 POST/B1 POST after official TelephonyMetrics patch integration. Those are **different lineages** and neither is automatically the selected clean Oct03-derived *next* checkout. M4 source resulted in M4 Recovery physical boot. Do not rerun V38 or M4 checks as if new; do not spend the authorization on a guessed root. New exact source root and source→Oct03 system image lineage `UNBOUND`, actual new source bytes `NOT_READ`. Existing V1 no-write tool ZIP SHA `d5d51bf25b725c6254cef39038caed60c486a0901893a33a7440a77e899dfa1b`; assistant repeat AST/inner manifest/34 local synthetic regressions PASS. Details: [source-root selection reconciliation](titan2/N1F_P342_R1B1_PRIOR_WORKSPACE_DECISION_V1_20261013.md). No source mutation, image/build/repack, host A4/R2 redo, new LP/AVB, R0C 256 TEE14, device or flash authority.

```text
R1B1_OPERATOR_PACKAGE_TEST_PLAN=PASS
R1B1_ORIGINAL_V38=PRE_PRE_PRIOR_PASS
R1B1_M4_ISOLATED=POST_POST_PRIOR_PASS
R1B1_SINGLE_NEW_SELECTED_ROOT_READ=AUTHORIZED_CONDITIONAL_ROOT_BINDING
R1B1_NEW_OCT03_DERIVED_ROOT=UNBOUND
R1B1_NEW_FILE_READ=NOT_EXECUTED
BUILD=NO SOURCE_MUTATION=NO DEVICE=NO FLASH=NO
```
