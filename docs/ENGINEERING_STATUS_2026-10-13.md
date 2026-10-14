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

## October 13 source-state admission completion — R1/B1 POST/POST actual ai-g732

Operator's exact authorized two-file source inspector on `/srv/data/sable-build/workspaces/n1f-m4-localrepo/android` **PASS**: R1 `AndroidManifest.xml` 541779 bytes SHA256 `2e3ffb1d771cb6977670a800f0a27ffd24a9cf252ff0890e92ac98f9f90e37ca` POST_EXACT; B1 `TelephonyMetrics.java` 2547 bytes Git blob `9d5108e0ddb8d4960d21cda021813b53dbbf4da8`, SHA256 `2bc30b0df7c12eed9157aad57682562a4a0b928794ac55a8b650fa927d2fce1e` POST_EXACT; 544326 bytes read total and no enumeration/writes/other tools/images/device. Status `PASS_TWO_SOURCE_STATES_IDENTIFIED_NOT_SOURCE_LINEAGE`. `R1_B1_PATCH_REAPPLY=NO_NO`; the one-time two-file source read **was consumed**. Independent R1/B1 source-slice closure is now concrete; it is not final G1/G2/G3 admission or proof selected build state produced Oct03 known booting image.

Review-only next deliverable [source-to-parent/boot-critical decision](titan2/N1F_P342_M4_R1B1_OPERATOR_PASS_SOURCE_PARENT_HOLD_V1_20261013.md); distribution ZIP `N1F_P342_SOURCE_TO_PARENT_DECISION_V1.zip` SHA `cedada92caab92b130268b477bac2aed31a95b17011948a824a795dc4997cf5d`, internal 3/3 SHA/JSON 8 invariants PASS. Existing Python R1/B1 checker revalidated ZIP+4 inner, AST both, 34/34 local unittest (0.034s; 0.81s process/100488KiB RSS) and 400 synthetic 589866-byte in-memory classifications median 0.5179ms/p95 0.7166ms (not host timing). No additional script needed. Earlier Oct03 booting image SHA `dc1f917d...` and M4 failed-to-Recovery image SHA `261ee714...` are separate; M4 exact full build source-to-final-image manifest and boot-critical delta *not fully bound*. Prior M4 11/11 embedded hash and API36 bootclasspath, five R2 bounded native and A4 two-receipt PASS preserved. Seven Oct03 companion/LP/AVB/rollback, process-effective G3 and fresh build/device permissions stay held.

```text
R1_B1_SELECTED_M4_SOURCE=PASS_POST_EXACT_POST_EXACT
R1_B1_PATCH_NEEDED=NO_NO
R1_B1_TWO_FILE_AUTHORITY=CONSUMED
NEXT_DELIVERABLE=SOURCE_PARENT_BOOT_CRITICAL_RECONCILIATION_NO_BUILD
NEXT_BUILD=NO
SOURCE_MUTATION=NO NETWORK=NO DEVICE=NO FLASH=NO
```

## M4 archived build receipt and derived hybrid-super counterfactual — review completed

Under the new operator authorization, reviewed the exact **existing archived PR #339 M4 operator [postbuild receipt](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5502246106)** plus prior [frozen image 11/11/BCP receipt](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5502638731), [actual Recovery result](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5505341540) and [build-engineer revised hybrid decision](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5508562816). This is **GitHub textual receipt review**, not an additional unnamed ai-g732 log file read. Original complete M4 system.img 3,194,466,304 bytes SHA `261ee714db92c188eec7effc1afb6edd26627aaa1741e5f887915e078e1000ce` both output locations PASS existing operator hash; Ninja completed, but V1.1 driver `SYSTEMIMAGE=FAIL_MISSING` is contradicted by postbuild artifacts and its underlying observation reason unproven. Physical M4 transport 12/12 OKAY / 79.351s, Android **FAIL_RECOVERY** with generic “Can't load Android system. Your data may be corrupt”; **recovery logs unavailable; cannot prove userdata, AVB, Rescue Party, SELinux or missing ViLTE cause**.

**Would M4 as hybrid super boot? `UNKNOWN_NOT_TESTED`, not PASS or expected rescue.** If system and all effective companion partition bytes, LP metadata/snapshots, AVB, bootchain, mount state remain equivalent to the failed system_a run, repackaging changes no M4-internal software. A separately pinned *different* matched hybrid partition composition might address a cross-partition mismatch, but no Oct11 as-flashed super journal/digest or Oct03 same-session seven companion hashes is bound. Build engineer had explicitly **approved a complete hybrid super as an OFFLINE byte/LP control**, not a physical flash authorization; embedded IMS remains in derived system/system_ext and skip_mount.cfg must be preserved. See [full existing receipt and counterfactual](titan2/N1F_P342_M4_SUPER_COUNTERFACTUAL_AND_RECEIPT_REVIEW_V1_20261013.md). No new source/image/host byte reads, compilation, LP pack, network, device or flash. **No new script needed** for review of existing public receipt.

```text
M4_EXISTING_BUILD_RECEIPT_REVIEW=COMPLETE_GITHUB_ONLY
M4_SYSTEMIMAGE_PRODUCED_HASH=PASS_PRIOR_OPERATOR
M4_BOOT=FAIL_RECOVERY_CAUSE_UNBOUND
M4_HYBRID_AS_SUPER_SUCCESS=UNKNOWN_NOT_TESTED
OFFLINE_HYBRID_SUPER_DESIGN=PERMITTED_AS_PLAN_ONLY_NOT_EXECUTE
COMPLETE_M4_MANIFEST_EXACT_HOST_FILE=NOT_IDENTIFIED
BUILD=NO REPACK=NO DEVICE=NO FLASH=NO
```

## October 13 offline boot-critical delta review — approved and completed from retained evidence

Operator approved offline Oct03↔M4 comparison of prior first-stage mounting, PHH guard, effective SELinux and partition-set evidence. The review now compares **ten exact claim-scoped areas** without opening host/image/source/SELinux bytes. Distribution `N1F_P342_OFFLINE_BOOT_DELTA_V1.zip` SHA256 `278a9c56da39ad4e07c601f1409e62c4195db0f75c06f50fe17c1017a2691059`; full report/TSV/JSON and SHA manifest, ZIP integrity PASS, inner 4/4 SHA PASS, 10-row/9-field matrix completeness PASS, JSON/negative-operation safety invariants PASS, deterministic archive bytes PASS. No new executable code or direct system image diff was produced. [Detailed analysis](titan2/N1F_P342_OFFLINE_BOOT_CRITICAL_DELTA_V1_20261013.md).

**Findings:** Oct03 system_a boot PASS; Oct11 distinct hybrid Android boot observed with exact flashed super still UNBOUND; M4 successful 12/12 system_a writes and **FAIL_RECOVERY**. M4 source/staging/frozen-member `skip_mount.cfg` preservation PASS; earlier missing-path report is false due to absolute compatibility symlink, so no missing skip-mount inference. **Effective first-stage mount/import/fstab and M4 failed-boot policy load unknown.** M4 compiled policy and contexts are hashed selected image members but vendor-interoperable **merged effective SELinux NOT PROVEN**; there is no recorded M4 AVC/boot-panic/pstore or Rescue Party causal chain. PHH `mtkmal` source marker/guard and C3B overlay/root cleanup PASS bounded source/staging, not proof of runtime. Prior R1/B1 selected source POST/POST, IMS boot JAR API36 semantic and M11 signer, five R2 direct/Bionic/GNU/A4 studies all PASS at original scope and are not rerun. The seven Oct03 matched physical companions and actual Oct11 written hybrid journal/LP/AVB remain UNBOUND.

**Question:** would M4 have booted as hybrid `super.img`? **UNKNOWN_NOT_TESTED**. Identical M4 system bytes and equivalent companions cannot by mere repackaging repair an intrinsic image defect; a genuinely different matched set might remedy a cross-partition mismatch, if that is what happened, but **no evidence proves that premise**. Engineer previously accepted full hybrid as **OFFLINE LP/byte metadata CONTROL ONLY**, not an automatic physical restore/flash or a boot-certification. No new image/host/device experiments authorized.

```text
BOOT_DELTA_RETAINED_EVIDENCE_REVIEW=COMPLETE
FIRST_STAGE_SKIPMOUNT_STATIC=PASS_PRIOR
FIRST_STAGE_EFFECTIVE_M4=NOT_EVIDENCED
M4_COMPILED_SELINUX_MEMBERS=PASS_PRIOR
M4_EFFECTIVE_MERGED_SELINUX=NOT_EVIDENCED
M4_BOOT_CAUSE=UNBOUND
M4_SUPER_BOOT_COUNTERFACTUAL=UNKNOWN_NOT_TESTED
SUPER_REPACK=NO SOURCE_MUTATION=NO BUILD=NO DEVICE=NO FLASH=NO
```
