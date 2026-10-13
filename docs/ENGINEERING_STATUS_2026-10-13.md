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
