# PR #342 — A0C actual sealed 991-revision agreement and next offline source-creation authority V1

Date: 2026-10-13. Based on actual operator ai-g732 A0C transcript. **This is documentation/decision only: no new executable, source checkout, OUT, network operation, build, super assembly, device contact or flash.** The user earlier agreed to a staged isolated Oct03-derived cellular/CW1 host-build sequence; agreement to the strategy does not override exact mutation/build authority boundaries.

## A0C real operator PASS — source revision authority closed within declared scope

```text
A0C_ZIP_AND_FOUR_INNER_SHA=PASS
A0C_REGRESSIONS=PASS_44_OF_44 0.042s on ai-g732
A0C_PLAN=PLAN_ONLY_ZERO_EVIDENCE_IO
A0C_INSPECT=PASS_SEALED_C3A_STAGE_OCT03_LEDGER_AND_MANIFEST_JOIN_NOT_REPLAYABILITY
STAGE_HEADS=991
OCT03_ARCHIVED_HEADS=991
OCT03_PINNED_REPO_MANIFEST_PROJECTS=991
STAGE_HEADS_SHA256=10658753bbb947a848369b0c248fca824def491e03287012ef031910542908f4
OCT03_HEADS_SHA256=10658753bbb947a848369b0c248fca824def491e03287012ef031910542908f4
OCT03_REPO_MANIFEST_SHA256=ccac2b30e8433bd5b0ec20e3d9ca4a31b90c918a7d8d7608dc619af5fa071fe8
STAGE_TO_OCT03_MISSING=0 EXTRA=0 DIFFERENT_REVISIONS=0
OCT03_TO_MANIFEST_MISSING=0 EXTRA=0 DIFFERENT_REVISIONS=0
GIT_OR_REPO_EXECUTION=NO
CHECKOUT_CREATED=NO
PATCHES_REPLAYED=NO
SOURCE_MUTATION=NO BUILD=NO SUPER=NO DEVICE=NO FLASH=NO
```

**Interpretation:** exact **same path→40-hex revision mapping** in all three retained text records, not merely 991 equal counts. Two frozen TSVs have **identical SHA256**, and the pinned Oct03 XML map resolves to identical 991 path/revision pairs. The stage and Oct03 small files were verified against **their own local SHA256SUMS manifests**; A0C did not independently recertify those manifests with a separate signer. **This closes the narrow textual source HEAD/manifest equivalence question**. The result is not any claim of actual Git-object closure, live source cleanliness, original dirty-file content equivalence, build reproducibility or physical boot qualification.

## Already done: no redundant A0D census or clone proof from filenames alone

The archived Oct12 M4 reconstruction (PR339 closed-unmerged branch `n1i-d1r4-cw1-compiled-checkpoint-20261011`, `docs/titan2/N1F_OCT12_FOUR_WORKSTREAM_STATUS_AND_R1_EXECUTION.md`) records:
- `n1f_m4_offline_reconstruction_pilot_v1_1.py`: local-object four-project pilot PASS, including `frameworks/base`, `build/soong`, `device/phh/treble`, `treble_app`.
- `n1f_m4_remaining_987_offline_v1.py`: remaining 987 project worktrees populated from the **same sealed C3A stage ledger**, `M4_991_PROJECT_HEADS=PASS`, no new network at that time. Git alternates depended on retained local objects; `.repo` metadata initially absent. This was a successful M4 **historical** reconstruction, not proof that the current existing M4 tree can be used as a clean new Oct03 source base, nor proof that alternates will remain self-contained when detached or moved.
- Exact four-pilot known commits: `frameworks/base` `dfb660a1fd590efed475f388870032d2d416403b`, `build/soong` `6725416b1cce7fe6080a863cee69ebc615701ca2`, `device/phh/treble` `bbaf0c2ba33c15c574d9be4ad3b10895b702880f`, `treble_app` `15b30c1a9cac951236db59e66a3ef8222872dfe8`.
- Original PHH C3A `base.mk` was **clean** in the sealed Oct03 `dirty-project-state.txt`, per operator actual PR342 V1.1. The N1F original runner verifies **three dirty project names**; earlier M4 pilot records C3A generated `rom.mk` SHA `ab0ec737342d41d562816fce73e8694e35ce32e09db74c12ea115efa3619d592`, plus `build/soong` and `treble_app/sdk/.knownPackages` modification. Those historical summaries **do not individually seal every dirty source-file byte needed for a fresh clone**. No blind copy of current modified source and no blanket C3B hardening/PHH policy removal.
- Prior Oct03 physically booted N1F system image `dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a` is an OFFLINE planning image parent; oct11 actual as-flashed hybrid super sha/journal still UNBOUND; M4 final failed Recovery. None should be used as an unverified source-tree identity.

## Current exact destination / protected paths

The actual A0B metadata result was `PASS_A0B_VACANT_CANDIDATE_METADATA_ONLY_NO_SOURCE_LINEAGE` with proposed container absent at **the time of that check**:

```text
PROPOSED_CONTAINER=/srv/data/sable-build/workspaces/n1f-p342-oct03-a1-isolated
PROPOSED_SOURCE=/srv/data/sable-build/workspaces/n1f-p342-oct03-a1-isolated/android
PROPOSED_OUT=/srv/data/sable-build/workspaces/n1f-p342-oct03-a1-isolated/out-a1
PROTECTED_OCT03=/srv/data/sable-build/workspaces/titan2-n1d/android
PROTECTED_OCT03_OUT=/srv/data/sable-build/workspaces/titan2-n1d/out-c3a-td
PROTECTED_M4=/srv/data/sable-build/workspaces/n1f-m4-localrepo/android
PROTECTED_M4_OUT=/srv/data/sable-build/workspaces/n1f-m4-localrepo/android/out-m4-g2-fullimage-01
PROTECTED_CW1=/srv/data/sable-build/workspaces/n1i-d1r4-cw1-isolated/android
PROTECTED_CW1_OUT=/srv/data/sable-build/workspaces/n1i-d1r4-cw1-isolated/android/out_cw1
```

No container/source/OUT has been created or reserved by A0, A0B, A0C or this documentation turn.

## Next meaningful deliverable — bounded offline local-object and C3A dirty-state replay custody, then separately authorized creation

**Do not commission another 991-row comparison:** A0C settled that. The next engineering task is a **single controlled source-materialization plan**, preferably derived from the *original operator-used* pilot and remaining-987 Python scripts rather than rewritten from memory. Before executable creation or filesystem changes, identify those two exact retained scripts' local paths and SHA-256 (paths/digests currently **NOT** in GitHub). Review their path protections, source-object alternates, git clone/worktree behavior, no-network enforcement, progress/performance controls, rollback-on-partial-failure, and all C3A dirty-project input filenames/bytes. Verify that any designed reuse does **not** carry M4 R1/B1/PHH/C3B source changes into Oct03 baseline. Reuse the archived C3A 369-patch/991-head/dirty-project evidence; do not redo original build, full object store scan, or mobile flash investigations.

**A1 source-creation authorization, once requested** must be limited to atomically claiming the proposed fresh container only if absent, reconstructing 991 exact stage revisions using existing LOCAL object stores with no remote/network fallback and no changes to donor repos, replaying precisely SHA-pinned *C3A* dirty files, and emitting new independent source/dirty/project receipts under that new container. On missing commit/object, changed alternate, unknown patch content, clone collision or unexpected path: **STOP**, do not substitute a mutable M4 HEAD, auto-sync, or broaden scope. Ensure existing source and output trees untouched. New clone post-validation should compare against the already SEALED A0C 991-row map **once** as validation of NEW work, not reauditing old trees. Fresh OUT only after its path's nonexistence and independent approved write authority.

**Next approvals are distinct:** (1) exact source-materialization writes into the new isolated container; (2) mutation/integration of specific R1+B1+C1/PHH/MTK RRO/C2 readiness; (3) host-only `systemimage` build; (4) optional A2 CW1 + 28 stock native/5 platform providers after G3; (5) hybrid super LP/AVB/VAB/matched restore and device/flash. The last four are **not** implied by source creation approval. Current host `ninja` absent on shell PATH remains a hint, not build-toolchain failure, and capacity was a point-in-time hint only.

## Status

```text
A0_ACTUAL_HOST=PASS_PROTECTED_CUSTODY_CW1_SHA
A0B_ACTUAL_HOST=PASS_VACANT_AT_CHECK_TIME_NOT_RESERVED
A0C_ACTUAL_HOST=PASS_SEALED_991_PROJECT_THREE_WAY_JOIN
A0C_NEW_CHECKOUT_REPRODUCIBILITY=NOT_PROVEN
A1_EXACT_PREVIOUS_MATERIALIZATION_SCRIPT_BYTES_AND_SHA=NOT_BOUND
A1_C3A_THREE_DIRTY_PROJECT_FILE_BYTES_AND_REPLAY=NOT_FULLY_REBOUND
A1_NEW_ISOLATED_SOURCE_AND_OUT=NOT_CREATED
A1_HOST_BUILD_AUTHORIZED=NO
SOURCE_MUTATION=NO BUILD=NO SUPER_REPACK=NO NETWORK=NO DEVICE=NO FLASH=NO
```
