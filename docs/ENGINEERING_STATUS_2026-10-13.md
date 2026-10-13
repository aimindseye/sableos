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
