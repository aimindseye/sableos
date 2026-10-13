# Titan 2 N1F — Operator parent-selection decision (2026-10-13)

**Authority: ACCEPTED FOR OFFLINE ENGINEERING PLANNING ONLY** · **No build, Android source mutation, image extraction, mount, hybrid `super.img` repack, network fetch, device contact, fastboot, reboot, erase, factory reset, restore, flash, release or merge authority**.

## Exact selection

The operator explicitly accepted the proposed choice to stop exploratory October 11 flash-journal discovery and adopt the **October 3, 2026 physically boot-qualified N1F C3A-derived C3B5 `system.img` as the distinct planning parent**.

```text
PARENT_SELECTION_AUTHORITY=OPERATOR_EXPLICIT_2026-10-13
PARENT_ROLE=OCT03_N1F_OFFLINE_PLANNING
PARENT_DEVICE=UNIHERTZ_TITAN_2
PARENT_ANDROID=16
PARENT_PARTITION=system_a
PARENT_ARTIFACT_KIND=system.img
PARENT_SYSTEM_SHA256=dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a
PARENT_SYSTEM_BYTES=3200540672
PARENT_PHYSICAL_BOOT=PASS_RETAINED_OCT03
PARENT_IMAGE_CURRENT_HOST_REHASH=NOT_PERFORMED
OCT11_ACTUALLY_FLASHED_HYBRID_SUPER_SHA=UNBOUND
OCT11_RUNTIME_NOT_INHERITED=YES
OCT11_PARENT_SEARCH=STOP_PENDING_EXPLICIT_NEW_ARTIFACT
OCT03_WHOLE_SUPER_PARENT=NOT_CLAIMED
PARENT_MATCHED_LP_PARTITION_SET=NOT_YET_BOUND
BUILD_AUTHORIZED=NO
SOURCE_MUTATION_AUTHORIZED=NO
IMAGE_EXTRACTION_AUTHORIZED=NO
SUPER_REPACK_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
```

Primary existing evidence: [Oct03 N1F five-app build/physical acceptance](N1F_C3A_DERIVED_C3B5_BUILD_FLASH.md), with historic system image artifact at `/srv/sable-build/artifacts/titan2/n1f-c3a-derived-c3b5/20261003T221350Z/system.img`, and preserved run evidence `/srv/sable-build/evidence/titan2/n1f-c3a-derived-c3b5-r2/20261003T221350Z`. The current existence, bytes and Git source tree have **not** been reverified by this *selection decision*. Do not silently substitute a reconstructed Oct12 or nonbooting Oct13 M4 image.

## Parent identity and compatibility limits

1. This is a **physically tested Oct03 system image**, not evidence that it formed the actually flashed October 11 `super.img`. October 11's `sys.boot_completed=1`, briefly registered cellular behavior and separate R8 captures remain historical observations without image-byte lineage.
2. The seven logical-partition hashes and `lpmake-command.txt` in `n1f-atlas-hybrid-control-r3-virtual-ab-20261011` are an **offline candidate only**. Their LP groups, Virtual A/B geometry and AVB chain **cannot** become the Oct03 matched whole-super authority without an exact independent reconciliation.
3. This choice does **not** resurrect the October 13 failed M4 image as a suitable parent. `system_a` transport PASS and Android Recovery boot FAIL remain independent evidence with no proven root cause.
4. Preserve, in the future derived `system.img`, exact qualified compatibility behavior of the Oct03 parent, including primary embedded `/system/system_ext/etc/init/config/skip_mount.cfg` and `/system/etc/init/config` compatibility symlink; verify selected parent effective bytes before changing anything. Oct13 M4 skip-mount source/staging presence, wiring and `cmp` already PASSED (SHA256 `0a30008c167d46e3177e9189fcb14e482325c4f08da4f47c9d708a6700f2483e`), but this is not Oct03 parent equivalence or M4 runtime proof.

## New next step — exact parent-to-source and LP planning matrix (host evidence review only)

Do not make a fresh Android build or replay 991-project validation. Reuse existing Oct03 source manifests, C3A/N1F five-app runner evidence, historic Oct03 SHA receipts, and PR #339/PR #342 R3 metadata, R8 runtime and six sealed V1 receipts. Generate a narrow **written review** listing:

- **SYSTEM_PARENT:** Oct03 path, immutable 64-digit digest, byte length, historic physical PASS and source/build manifest relationship; unknown current-host presence classified `NEEDS_HOST_CHECK`.
- **SOURCE_LINEAGE:** exact Oct03 source/worktree and the relation of isolated M4 worktree source to those heads, when demonstrable from retained manifests. Do not presume M4 rebuild equals Oct03 parent from project count or package names.
- **UNMODIFIED_LOGICAL_PARTITIONS:** known physical stock/retained LP input identities for `vendor`, `odm`, `product`, `system_ext`, etc., where needed, and whether they are actually Oct03-matched. Unbound partitions remain `NOT_BOUND`; do not use Oct11 R3 as a proven parent.
- **VIRTUAL_AB/LP:** source of proposed layout/groups/COW/snapshot rules and capacity limits, all independent of Oct03's `system.img` physical boot success. No `lpmake` execution.
- **AVB/RESTORE:** compare required descriptor/partition boundaries and recovery artifact versions; readiness remains `OPEN` until separately verified.
- **IMS ISLAND:** exact approved R1+C1 package/JAR/XML changes inside **embedded** `/system/system_ext` only; hold five R2 libraries on full G3 recursive symbol and privileged IMS linker namespace closure. Preserve stock standalone `system_ext` and `product` logical images but do not install live IMS there.
- **GATES:** G1 final-image composition, G2 signing/bootclasspath/privapp/SELinux and G3 native ABI/namespace are still **OPEN**. The LTE registration collapse is an independent unresolved issue.

Stop when a required source/image/LP parent identity is missing; ask for the exact missing already-retained input rather than fabricating evidence or executing a new scan. Subsequent incremental unified Android build, final image analysis, offline complete `super.img` construction, restore qualification and any physical flash **each require separate explicit approval**.

## Governance

Draft [PR #342](https://github.com/aimindseye/sableos/pull/342) remains the **only active engineering queue**. Closed/unmerged [PR #339](https://github.com/aimindseye/sableos/pull/339) remains an immutable evidence archive. This document selects the engineering parent for **planning only**; no PR is merged and no Android/production code is changed by the decision.
