# PR #342 — operator A0B PASS, A0C sealed C3A 991-project text-ledger join handoff V1

Date: 2026-10-13. User supplied actual ai-g732 A0B package and metadata-only inspect. **A0B now PASS at its actual limited scope**. This A0C handoff is **prepared, not executed on ai-g732**. No permission for checkout creation, image build, source mutation, network, device or flash is assumed.

## A0B actual operator result

```text
A0B_PACKAGE_SHA256=PASS
A0B_INTERNAL_SHA256=PASS_4_OF_4
A0B_REGRESSION=PASS_30_OF_30 duration=0.005s
A0B_PLAN=PLAN_ZERO_HOST_EVIDENCE_IO
A0B_INSPECT=PASS_A0B_VACANT_CANDIDATE_METADATA_ONLY_NO_SOURCE_LINEAGE
A0B_PARENT_ANCESTORS=PASS_EXACT_PHYSICAL_DIRECTORY_ANCESTORS
A0B_CANDIDATE=/srv/data/sable-build/workspaces/n1f-p342-oct03-a1-isolated
A0B_CANDIDATE_STATE=PASS_ABSENT_AT_CHECK_TIME_NOT_RESERVED
A0B_FUTURE_ANDROID=/srv/data/sable-build/workspaces/n1f-p342-oct03-a1-isolated/android
A0B_FUTURE_OUT=/srv/data/sable-build/workspaces/n1f-p342-oct03-a1-isolated/out-a1
A0B_AVAILABLE_BYTES_AT_CHECK_TIME=957711626240
A0B_AVAILABLE_INODES_AT_CHECK_TIME=217743852
A0B_PATH_PRESENT_ADVISORY=python3,bash,git,repo,java,sha256sum,unzip
A0B_NINJA=NOT_IN_PATH_ADVISORY_ONLY
A0B_SOURCE_ROOT_CREATED_OR_RESERVED=false
A0B_SOURCE_CONTENT_READ=false
A0B_BUILD=false DEVICE=false FLASH=false
```

**Do not** flag absent system `ninja` as a build failure: AOSP Soong/Ninja may use source/warm-output-provided build tools and versions. A0B never executed `ninja`, `java`, Repo or Git; it is not an Android16 toolchain certification. Free space/inodes and vacancy are a point-in-time observation; check atomic target nonexistence when a separately approved checkout is actually created.

## Existing prior work examined before another deliverable

- Exact original Oct03 C3A/N1F host build driver [`build/titan2/run-n1f-c3a-derived-c3b5-r2.sh`](https://github.com/aimindseye/sableos/blob/main/build/titan2/run-n1f-c3a-derived-c3b5-r2.sh) calls **sealed source preflight** before the seven-file/one-`rom.mk` N1F app delta. It archived the C3A stage tree, `all-project-heads.tsv`, `repo-manifest-r.xml`, `dirty-project-state.txt` and `SHA256SUMS.txt` in **`c3a-boot-qualified/20261003T221350Z`**. Oct03 historical `system_a` boot PASS and archive C3A head count 991 previously verified. The original driver mixes build/flash and must not be rerun.
- Oct12 [four-workstream/M4 source-reconstruction operator record](https://github.com/aimindseye/sableos/blob/n1i-d1r4-cw1-compiled-checkpoint-20261011/docs/titan2/N1F_OCT12_FOUR_WORKSTREAM_STATUS_AND_R1_EXECUTION.md) records **`n1f_m4_offline_reconstruction_pilot_v1_1.py` four-project local-object pilot PASS** and **`n1f_m4_remaining_987_offline_v1.py` remaining 987 local-object project reconstruction PASS**, consuming exact C3A stage ledger at `/srv/data/sable-build/evidence/titan2/n1d-c3a-trebledroid-prep/20261001T152117Z-trebledroid-stage`. `M4_991_PROJECT_HEADS=PASS` historical. **Do not redo these old worktree operations** or assume the M4 result is the new, clean source parent; M4 had R1/B1/PHH/C3B changes and failed Recovery.
- Actual PR342 A0 seven protected historical source/output/C2 bundle paths and original 2693-byte CW1 patch SHA PASS. A0B new name now vacant at check time. No new checkout exists. R1/B1 source state, PHH guard, selected M4 vs Oct03 platform SELinux CIL/context SHA, M4 full image, native A4/R2 and CW1 four methods are already checked in their historical scopes; no repeat census or source content hash necessary.

## New A0C small-text three-way join (no project scans)

Review-only package `N1F_P342_A0C_LINEAGE_V1.zip`, SHA256 **`1603f95a2587474189d0a674f6d2c003d2cc986e4a7581e8a5bfeb66df2feded`** (11,095 bytes), Python main SHA256 `720187f070386080b7c50953b2aff70da61d410f875261a4ca7c4542a813b868`. The exact plan/README/tests are in the archive. Default plan **zero evidence I/O**; authorized `inspect --authorize-a0c-five-receipts-readonly` uses **five exact, bounded text file reads only**, not one of the existing 991 Git worktrees:

1. Stage `/srv/data/sable-build/evidence/titan2/n1d-c3a-trebledroid-prep/20261001T152117Z-trebledroid-stage/SHA256SUMS.txt`, max 4 MiB.
2. Stage same directory `postpatch-project-heads.tsv`, max 256 KiB.
3. Oct03 physical witness-target `/srv/data/sable-build/titan2/artifacts/c3a-boot-qualified/20261003T221350Z/SHA256SUMS.txt`, max 4 MiB.
4. Oct03 same archive `all-project-heads.tsv`, max 256 KiB.
5. Oct03 same archive `repo-manifest-r.xml`, max 4 MiB.

The stage and Oct03 **per-directory** manifests must each SHA256-bind exactly named ledger/XML bytes (the script does **not** prove independently pinned digest for the manifests themselves). It parses 991 unique project path/40-hex HEAD rows in each TSV and 991 project path/revision entries in Oct03 pinned repo XML (forbids unresolved includes/extends/removals and symbolic revisions). It compares each exact path-to-revision map, rather than scanning source project directories or comparing only row counts. SHA/line grammar/XML/path count failures REFUSE without partial success; discrepant **sealed** ledgers produce HOLD with difference counts and up to eight paths, never guess which is authoritative. No raw source, OEM files, image or revision ledger content echoed.

Security: each ancestor opened read-only `O_DIRECTORY|O_NOFOLLOW`, each regular leaf `O_NOFOLLOW|O_NONBLOCK`, bounded `fstat` and exact size checks, no symlink follow/path fallback; historical Oct03 artifact symlink is **not traversed**. No worktree/OUT creation, dirty patch reproduction, `git`, `repo`, `ninja`, Android build, git-object enumeration, 369 patch replay, network, flash or device. Python3.10+ stdlib only; `unzip`/`sha256sum` for package transfer.

**Potential positive outcome:** `PASS_SEALED_C3A_STAGE_OCT03_LEDGER_AND_MANIFEST_JOIN_NOT_REPLAYABILITY`. This demonstrates **those three retained text authorities agree on 991 project revisions**, not that every needed object exists, local alternates are self-contained, dirty C3A 369-patch/source modifications can be reproduced, Android toolchain works, exact Oct03 image can be reproduced, or the proposed future checkout is built or even created. Any missing provenance from repo manifests stays a real gap.

**Assistant-container QA:** Python AST/compile 2/2 PASS, README Bash `-n` PASS, ZIP CRC PASS and SHA256SUMS 4/4 PASS, **44/44 synthetic regression tests PASS (0.112s latest)** including reject altered SHA, missing rows, traversal, ambiguous repo includes, ancestor/leaf symlink, FIFO, wrong cap, no-I/O plan and full three-ledger match/difference cases. **300 synthetic full 991-row three-way joins** median **4.7861 ms**, p95 **6.3353 ms**, peak local process RSS **101392 KiB**. This is pure parser/mocked file-source performance, not ai-g732 actual disk or 991 worktree reconstruction speed. **Host A0C actual inspection NOT EXECUTED**. No new Android build driver produced.

## Next after A0C

If all three frozen texts agree and object/patch authorities are independently identified, request **separate specific authorization** to allocate the proposed new isolated checkout and replay exact offline pinned project sources, preserving every original Oct03/M4/CW1 path and OUT. A later source mutation/build request must separately qualify its C1/R1/B1/guard/MTK overlay and optional C2 28+5/CW1 G3 boundaries; no hybrid LP, AVB, Virtual A/B, restore or physical device write without distinct approval.

```text
A0B_AI_G732=PASS_VACANT_CANDIDATE_METADATA_ONLY
A0C_LOCAL_PACKAGE_AND_TESTS=PASS_44_OF_44
A0C_AI_G732_FIVE_TEXT_RECEIPT_JOIN=NOT_EXECUTED
C3A_STAGE_VS_OCT03_MANIFEST_SHA_JOIN=UNBOUND_PENDING_A0C
NEW_SOURCE_CHECKOUT_AND_OUT=NOT_CREATED_OR_RESERVED
LOCAL_GIT_OBJECT_REPLAYABILITY=UNPROVEN
SOURCE_MUTATION=NO BUILD=NO NETWORK=NO SUPER_REPACK=NO DEVICE=NO FLASH=NO
```
