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

## Continued investigation — Oct03 C3A-derived source versus M4 partial PHH policy peel

Reviewed exact current `build/titan2/run-n1f-c3a-derived-c3b5-r2.sh`, the separate 2026-10-02 C3B full hardening transform, existing [M4 TrebleApp source repair operator record](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5497900692), and [M4 `/bt_firmware` SELinux packaging failure](https://github.com/aimindseye/sableos/pull/339#pullrequestreview-5502058005). **Newly isolated source-level divergence:** Oct03 N1F *C3B5* was built from a C3A 369-patch, 991-row source root with only seven app files plus one `rom.mk` product inheritance and `N1F_R2_COMPATIBILITY_PATCH_DELTA=0`; **do not conflate C3B5 app bundle with different Oct02 fully hardened C3B engineering source**. M4 991-source reconstruction later removed **only two** C3B PHH blocks, including `SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += device/phh/treble/sepolicy`/external overlay inheritance and TrebleApp privilege XML. Other full hardening transforms, including removal of PHH on-boot script copy rules, were *explicitly NOT replayed* in the M4 exact repair; current installed M4 PHH boot-hook selection unproven.

M4 hit **real build-stage `e2fsdroid` missing-label for `/bt_firmware`**, same failure class as earlier C3B E1; targeted PHH board-root change plus removal of two stale generated empty dirs resolved build packaging, retained `efs`/`persist`, and yielded hashed M4 image. This demonstrates a **material build-policy/source delta**, not a demonstrated *runtime* SELinux or init failure. Historical Oct03 frozen effective `device/phh/treble/base.mk` member SHA **NOT IDENTIFIED** from existing C3A manifest/head+`rom.mk` archives, so an exact Oct03-vs-M4 PHH private-policy byte comparison must not be assumed. No new host bytes read or scripts run. The original M4 Recovery mechanism is still unknown; static skip_mount and policy image members remain prior PASS.

[Controlling forensic three-lane source comparison](titan2/N1F_P342_C3A_C3B_M4_PHH_SEPOLICY_PROVENANCE_V1_20261013.md). No image build, new policy compiles, device use or flash authorized.

```text
OCT03_C3A_PLUS_FIVE_APP_SOURCE_DELTA=CONFIRMED_7_FILES_1_INHERIT
M4_PRIVATE_PHH_SEPOLICY_BUILD_INPUT_REMOVAL=CONFIRMED_TWO_BLOCK_REPAIR
M4_BT_FIRMWARE_SOURCE_POLICY_BUILD_FAILURE=HISTORICAL_CONFIRMED_RESOLVED
OCT03_FROZEN_PHH_BASE_MK_SHA=UNBOUND
M4_RUNTIME_POLICY_BOOT_CAUSE=NOT_EVIDENCED
SOURCE_MUTATION=NO BUILD=NO DEVICE=NO FLASH=NO
```

## Later October 13 source-forensics update — C3A pinned PHH base and partial M4 policy peel

**Recovered true Oct03 source line:** Original `run-n1f-c3a-derived-c3b5-r2.sh` uses exact C3A 991-project/369-patch base and adds seven app files + one `rom.mk` inheritance, explicitly `COMPATIBILITY_PATCH_DELTA=0`. That is not the separate Oct02 C3B E1 fully hardened image. M4 later applied **only two** C3B source blocks (PHH private sepolicy/external overlay + TrebleApp privilege XML removal), not full PHH boot-hook removals. M4's preceding `e2fsdroid` root `/bt_firmware` missing SELinux label failure and later targeted PHH root repair are real build-stage facts, not proven runtime policy cause of M4 Recovery.

**Additional source pin found without host reading:** `build/titan2/n1d-c3-trebledroid.env` fixes `device/phh/treble` HEAD to `39ba82ef89ff5bf6b22ca8f147dbf317bffa20ed`; full C3B hardener fixes that HEAD's `base.mk` Git blob to `a29e402009d449150f1216e5d517ec0c9b36bfbd`. C3A generated dirty-file allowlist permits only AndroidProducts.mk/rom.mk/treble_*.mk, not `base.mk`; however the Oct03 N1F final runner checks only project-level dirtiness and the current reviewed archive did not include **contents** of `dirty-project-state.txt`. Archived Oct03 exact path `/srv/sable-build/artifacts/titan2/c3a-boot-qualified/20261003T221350Z/dirty-project-state.txt` is known present; a single bounded historical text review would close the last final on-disk `base.mk` dirty-file question without scanning images or 991 heads. No new ai-g732 file content was opened this turn. See [new three-lane code-level comparison](titan2/N1F_P342_C3A_C3B_M4_PHH_SEPOLICY_PROVENANCE_V1_20261013.md).

```text
OCT03_N1F_SOURCE_FLAVOR=PASS_C3A_PLUS_7_FILES_AND_ONE_ROM_INHERIT
C3A_PHH_UPSTREAM_GIT_HEAD=39ba82ef89ff5bf6b22ca8f147dbf317bffa20ed
C3A_PHH_HEAD_BASE_MK_GIT_BLOB=a29e402009d449150f1216e5d517ec0c9b36bfbd
OCT03_ARCHIVED_DIRTY_STATE_CONTENT=NOT_REVIEWED
M4_PARTIAL_C3B_PHH_POLICY_REMOVAL=PASS_HISTORICAL_SOURCE
M4_MERGED_SELINUX_RUNTIME_CAUSALITY=NOT_PROVEN
SOURCE_MUTATION=NO BUILD=NO DEVICE=NO FLASH=NO
```

## October 13 — exact archived PHH source and static installed image policy handoff

Operator asks actual confirmation of original Oct03 PHH file status and M4 installed hook/policy differences. GitHub code/PR review confirmed archived Oct03 source dirty-state receipt plus SHA256SUMS exists; C3A PHH project HEAD 39ba82ef89ff5bf6b22ca8f147dbf317bffa20ed, HEAD:base.mk Git blob a29e402009d449150f1216e5d517ec0c9b36bfbd. **Actual archive dirty file contents remain unread**; pinned source Git blob is not substituted for verified Oct03 on-disk bytes. M4 source exact two-block C3B private-policy peel and historical e2fsdroid packaging fix PASS, final M4 installed /system/bin/phh-on-boot.sh content not yet qualified by prior 11/11 member set.

Prepared external ZIP **N1F_P342_PHH_POLICY_EXACT_V1.zip**, SHA256 c923fe6b92fedafd0a302590dea28f052390988d4aa316b2ad3170c56330f358; [controlling plan](titan2/N1F_P342_OCT03_M4_PHH_POLICY_EXACT_HOST_CHECK_V1_20261013.md). Only two exact small Oct03 archived text reads with manifest SHA; and exact three fixed ext4 members of two historical images, with byte caps and prior M4 CIL/context hashes. Whole-image SHA is not replayed, no writes/mount/build/device. Python AST PASS, archive 4/4 SHA PASS, synthetic **30/30** PASS in 0.003s, parser fixture 4000 cycles median/p95 0.00442/0.00463 ms (not real image I/O). **Assistant container has no debugfs**, actual ai-g732 inspection NOT YET EXECUTED, no runtime merged policy admission inferred.

```text
OCT03_ARCHIVED_BASE_MK_STATUS=WAIT_OPERATOR_EXACT_TEXT_READ
OCT03_VS_M4_INSTALLED_SCRIPT_AND_PLATFORM_POLICY=WAIT_OPERATOR_BOUNDED_IMAGE_MEMBER_READ
RUNTIME_MERGED_SELINUX_AND_INIT_INVOCATION=NOT_PROVEN_BY_STATIC_PROBE
SOURCE_MUTATION=NO BUILD=NO DEVICE=NO FLASH=NO
```

## Oct13 actual PHH probe refuses historical archive ancestor — metadata handoff

Actual operator `N1F_P342_PHH_POLICY_EXACT_V1.zip` package SHA PASS, inner 4/4 PASS, tests 30/30 PASS (0.002s), plan zero evidence I/O PASS. Explicit inspect returned `REFUSED_NO_PARTIAL_EVIDENCE`, `[Errno 20] Not a directory: 'titan2'`. Frozen verifier opens archived Oct03 SHA256SUMS.txt FIRST; its `/srv/sable-build/artifacts/titan2` component refused `O_DIRECTORY|O_NOFOLLOW`. Symlink or non-directory **unresolved**. No manifest/dirty file bytes, no Oct03/M4 images, no debugfs read occurred. No runtime PHH hook / platform CIL comparison; not a negative Selinux diagnosis.

No script rerun or symlink bypass authorized. New one-purpose literal archive-ancestor `os.lstat`/possibly `os.readlink` **metadata-only** helper `N1F_P342_OCT03_PATH_METADATA_V1.py` SHA256 `bff8cb5f26c25a49a9f409eb36ce3ed387a62799d6c8bcd2ce88f0d45fc9c8a4`, source Python compile PASS, 4 synthetic refusal cases PASS and 1000 synthetic local fixture runs median 0.0099ms/p95 0.0109ms; no whole-root discovery, target resolution, directory listing, evidence content or output writes. See [controlling PHH operator refusal and diagnosis](titan2/N1F_P342_OCT03_M4_PHH_POLICY_EXACT_HOST_CHECK_V1_20261013.md). Await exact real host lstat result before any rebind; project main historic root strings do not establish safe literal contemporary physical paths.

```text
PHH_V1_AI_G732_PACKAGE_TESTS=PASS_30_OF_30
PHH_V1_AI_G732_INSPECT=REFUSED_ENOTDIR_NO_PARTIAL_EVIDENCE
OCT03_ARCHIVE_EVIDENCE_BYTES_READ=0
OCT03_M4_IMAGE_BYTES_READ=0
OCT03_ANCESTOR_METADATA_DIAGNOSIS=PREPARED_NOT_EXECUTED
SOURCE_MUTATION=NO BUILD=NO DEVICE=NO FLASH=NO
```

## October 13 final alias diagnosis — exact physical PHH V1.1 handoff

Operator completed SHA-verified metadata-only probe: `/srv`, `/srv/sable-build`, `/srv/sable-build/artifacts` are directories; `/srv/sable-build/artifacts/titan2` **is a symlink** with literal target **`/srv/data/sable-build/titan2/artifacts`**. This confirms the cause of V1's `ENOTDIR` under `O_DIRECTORY|O_NOFOLLOW` and exonerates the unread archive/image bytes from any failure classification; no content was read during V1. Frozen V1 unchanged; no `realpath` bypass or alternate guessed symlink allowed.

Prepared **V1.1** `N1F_P342_PHH_POLICY_ALIAS_V1_1.zip` SHA256 **`ae2763fe15895a0ed2d29b691d5cd845b7d4fe8020de3dcbf8677c019cf78a7f`**, 12,304 bytes. V1.1 first validates exact symlink type/target via nofollow descriptor traversal, then accesses two exact Oct03 archived receipts and one Oct03 system.img by witnessed **physical** root, while M4 image remains pinned. No physical-target symlink tolerated; size, member names/caps, M4 policy SHA pins unchanged. Python AST and README shell syntax PASS, ZIP CRC/inner 4/4 SHA PASS, **44/44 synthetic regression tests PASS** (including full synthetic source-to-member result and deliberately mismatched policy negative), default plan no FS PASS. Synthetic 1500 literal alias lstat/readlink checks median 0.00593ms/p95 0.00672ms (not ai-g732 or debugfs throughput). **Actual ai-g732 V1.1 image and archive content reads NOT_EXECUTED**. Details: [operator alias rebinding contract](titan2/N1F_P342_OCT03_PHH_ALIAS_PHYSICAL_V11_20261013.md).

```text
ORIGINAL_METADATA_TARGET=CONFIRMED_EXACT_SYMLINK
V1_REFUSAL=PASS_FAIL_CLOSED
V1_1_FROZEN_LOCAL_QA=PASS_44_SYNTHETIC_TESTS
V1_1_OPERATOR_EXACT_HOST_INSPECT=NOT_EXECUTED
OCT03_PHH_BASE_MK_DIRTY=UNBOUND_PENDING_ARCHIVE
OCT03_VS_M4_STATIC_PHH_AND_SELINUX=UNBOUND_PENDING_DEBUGFS
SOURCE_MUTATION=NO IMAGE_REPACK=NO BUILD=NO DEVICE=NO FLASH=NO
```

## October 13 — PHH V1.1 actually qualified and selective hybrid-derived host build decision

User executed V1.1 with frozen ZIP and inner SHA PASS, 44/44 tests (0.005s), and real exact read-only `PASS_STATIC_OCT03_M4_EXACT_MEMBERS_NOT_RUNTIME_POLICY`. Archived Oct03 C3A PHH `base.mk_dirty=false` from manifest-SHA-verified dirty-project-state.txt; original Git HEAD and base.mk blob prepin corroborate clean original file. Exact installed `phh-on-boot.sh` Oct03 8326 bytes SHA256 `18f4425e38510690fb06fbe9a95cfdc2239541c4f997297880026335402fc63f`, M4 8387 bytes SHA256 `ab3369f6b06b751ecd59d43368daef0057470674cc233c0d468a84b7d465386e`. These match prior PR339 Titan marker guard PRE/POST source SHA exactly. Oct03 vs M4 platform `plat_sepolicy.cil` both 3148067 bytes SHA `a7805083d63a0fda11ce7943c0c4ee90954c44971d7b85897504d64421eab758`; `plat_file_contexts` both 48918 bytes SHA `ac2ba2392c7bcdb9e75f6add88841b4d216159c6ede0e673f881aaf6b4737ff9`; **SAME_CONTENT** each. Scope: platform members only, **NOT** effective merged policy/vendor/odm, init guard execution or M4 recovery cause.

Operator asks whether M4 changes could be incorporated into Oct11 booting hybrid and built. Answer: **minimal source-integrated new Oct03-derived Android16 host-only system.img candidate IS FEASIBLE IN PRINCIPLE**, but **not** direct copy of failed M4 system.img to an unbound Oct11 as-flashed `super.img`. Actual Oct11 flashed super SHA/journal remains UNBOUND; Oct03 N1F SHA `dc1f917d...` remains separate approved **planning-only** parent. Proposed narrow changes: exact R1 protected broadcast, exact B1 TelephonyMetrics overload, six existing C1 IMS packages/two BCP JARs and overrides, exact PHH Titan guard with marker; preserve C3A default PHH base, `skip_mount.cfg` embedded system_ext/product and existing root folder policy. Do **not** automatically import M4 C3B overlay/private-policy removal, absent R2 ViLTE binaries, broad imports or risky super/boot/AVB tweaks. Candidate is **NON_FLASHABLE** pending G1/G2/G3 and physical companion/LP/AVB/restore. Need independently selected isolated Android16 checkout and OUT plus exact mutation and host build authorization; no compile tool invocation or developer source edits this turn.

[Reviewed selective host-only integration plan and V1.1 actual evidence](titan2/N1F_P342_V11_STATIC_PASS_MINIMAL_HYBRID_DERIVED_BUILD_DECISION_V1_20261013.md). No new executable, so no new source-syntax or runtime benchmark claims. All prior original/archived 44 V1.1 cases, R1/B1, M4 build, C1 BCP, A4/R2 and Oct03 seal are reused without repeat.

```text
PHH_V11_AI_G732_ACTUAL=PASS_STATIC_MEMBERS
C3A_ARCHIVED_BASE_MK_DIRTY=FALSE
M4_PHH_GUARD_INSTALLED=PASS_BOUND_SOURCE_POST
PLATFORM_CIL_AND_CONTEXTS_OCT03_M4=SAME_CONTENT
IMPLIED_FULL_SELINUX_POLICY_EQUAL=NO
OCT11_ACTUAL_AS_FLASHED_SUPER=UNBOUND
NEXT_HOST_ONLY_SOURCE_INTEGRATION=PROPOSED_NO_BUILD
SOURCE_MUTATION=NO BUILD=NO LPMAKE=NO DEVICE=NO FLASH=NO
```

## October 13 — Expanded cellular / native / CW1 hybrid-source planning

User agrees earlier Oct03-derived host build sequence, asks to add *additional cellular APKs and libraries and completed call-waiting work* to future hybrid layout. Project+GitHub research finds merged PR #327 36-file stock bundle with **ImsService.apk + two MediaTek boot JARs + 33 native A4 references**; PR #328 first wholesale 33 install Kati duplicate-target failure, corrected **28 frozen stock imports + 5 preexisting AOSP16 platform providers**, exact reviewed M008/M017/M029/M038/M039; PR #331 corrected C2 build SHA256 `630db78ef3f888b961640d17c5237495e673a953d67f1d52fabe056cbb76bb50`, 3218440192 bytes, with postbuild linkage plan; PR #334 records **C1/C2 unsuccessful physical boots**. Do not reuse entire C2 image as parent, transplant stock AOSP providers, or label all 33 native inputs image-ready G3.

Archived CW1 PR #339 **four method definitions + isolated `telephony-common` build PASS** and stock MTK consumer `invoke-super` **PASS_STATIC_ONLY**, original SHA-pinned 45-line patch against `GsmCdmaCallTracker.java`/`GsmCdmaConnection.java`; runtime call waiting still NOT_TESTED. Also reuses *separate* Restless incoming-call binder `ro.telephony.block_binder_thread_on_incoming_calls=false` C2 product property. Do not copy compiled CW1 JAR as a binary into new system image; selected original source/patch ABI gate required. C2 `SableTitan2Cellular*` readiness packages may be included with healer **DISABLED**; MTK IMS telephony RRO must be present and selected for `com.mediatek.ims`. Extra `MtkTeleService`/TelephonyProvider/MmsService/Telecom APK and other MediaTek JARs are **NOT** auto-admitted; need per-file package/service/signing+ABI/classloader proof. **Effective embedded `/system/system_ext` within new derived Android16 system image** remains only admitted target, not standalone Android14 stock `system_ext_a` in LP super.

Updated decision: **A1** isolated minimal Oct03 derived source+R1+B1+C1+guard+MMTEL RRO+incoming-call property and observe-only readiness package, then **A2 CONDITIONAL** CW1 source patch + 28 collision-filtered stock natives, five platform providers reused, **only after** selected effective IMS app linker/recursive strong symbol-version G3 PASS and exact code/manifest source pins. Both are HOST-ONLY and NON_FLASHABLE, need independent source-mutation/build approval, final G1/G2/G3, LP/AVB/VAB/restore. Oct11 actually flashed hybrid artifact still UNBOUND and radio transient-to-out-of-service separate issue. [New full 21-component/33-native evidence matrix and design](titan2/N1F_P342_CELLULAR_CW1_EXPANDED_HYBRID_BUILD_DECISION_V1_20261013.md). Review ZIP `N1F_P342_CELLULAR_CW1_EXPANSION_DECISION_V1.zip` SHA `609353b552b007e7273ed8f08329ce19c0fc33c4bb169dbc9af03c85793210ee`; CRC/inner 4/4 PASS; 21 unique component rows and 33 frozen-target statuses (28/5) schema PASS. No executable written; no source/image/network/device operations.

```text
CALL_WAITING_CW1_COMPILED_AND_STOCK_STATIC_SUPER=PASS_HISTORICAL
CALL_WAITING_CW1_NEW_IMAGE_AND_RUNTIME=NOT_PROVEN
C2_COLLISION_FILTER_28_NATIVE_5_PLATFORM=PASS_HISTORICAL_BUILD_ONLY
C2_PHYSICAL_BOOT=FAIL_PRIOR
EXTRA_MEDIA_TEK_JARS_OEM_TELESERVICE_APKS=HELD_NOT_ADMITTED
OCT03_SOURCE_TO_NEW_IMAGE=PLANNED_NOT_BUILT
OCT11_SUPER_AS_FLASHED_SHA=UNBOUND
SOURCE_MUTATION=NO BUILD=NO SUPER_REPACK=NO DEVICE=NO FLASH=NO
```

## October 13 — A0 protected source custody deliverable prepared, host run pending

Operator requests next deliverable, historical duplication review, validated scripts/performance and PR342 status. Existing archived Oct03 original C3A Android16 source `/srv/data/sable-build/workspaces/titan2-n1d/android`, M4 isolated reconstructed source `/srv/data/sable-build/workspaces/n1f-m4-localrepo/android`, and isolated CW1 source `/srv/data/sable-build/workspaces/n1i-d1r4-cw1-isolated/android` and warm outputs already documented. Original 991-project control, actual M4 R1/B1 POST/POST, PR342 real PHH V1.1, CW1 four DEX methods + stock static invoke-super, merged PR327 36 stock materialization, PR328 28-native + five AOSP16 owner collision resolution, PR331 C2 built image and PR334 C1/C2 physical boot failure remain at their original scope; **no repeat audits or builds**. **No selected new isolated clean Oct03-derived A1/A2 source tree or fresh OUT exists as an approved identity yet.**

Prepared independent `N1F_P342_A0_CUSTODY_V1.zip` SHA256 `33cf05666b1d51992fd1a1bd7c4f127695a881062e304fb2e5f0c08c47537732` (9712 bytes). Read-only Python3.10+ stdlib: seven exact metadata-only known directory path checks and one 2693-byte SHA-bound archived CW1 source patch; dirfd `O_NOFOLLOW` for every ancestor and leaf, no alias fallback; default `plan` no host I/O, explicit `inspect --authorize-readonly-a0`; final status always `A0_CUSTODY_METADATA_ONLY_NEW_PARENT_AND_OUT_NOT_BOUND` even on intact evidence. Existing protected outputs must not be cleaned or reused. **Assistant-only** ZIP integrity PASS, inner 4/4 SHA PASS, AST 2/2 PASS, README `bash -n` PASS, **30/30 synthetic regression PASS**; 1200 local eight-role metadata+patch fixtures median 0.1159ms / p95 0.1486ms; NOT actual ai-g732 or compile performance. No Android source/JAR/image or C2 native file reads. This is a custody checkpoint, **not build readiness certification**. [Detailed plan/QA and next exact source selection gate](titan2/N1F_P342_A0_PROTECTED_SOURCE_CUSTODY_PREFLIGHT_V1_20261013.md).

```text
A0_TOOL_ZIP_AST_BASH_TESTS=PASS_ASSISTANT_30_OF_30
A0_AI_G732_INSPECT=NOT_EXECUTED
HISTORICAL_OCT03_M4_CW1_ROOTS=KNOWN_ROLES_PROTECTED
NEW_OCT03_DERIVED_A1_ANDROID16_ROOT=UNBOUND
NEW_A1_A2_OUTPUT_ROOT=UNBOUND
CW1_PATCH_SHA=HISTORICAL_PIN_ONLY
CW1_RUNTIME=NOT_TESTED
A2_NATIVE_G3=UNBOUND
SOURCE_MUTATION=NO BUILD=NO NETWORK_FETCH=NO DEVICE=NO FLASH=NO
```
