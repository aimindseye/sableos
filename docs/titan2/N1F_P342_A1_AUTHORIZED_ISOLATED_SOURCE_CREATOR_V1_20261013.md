# PR #342 — A1 user-authorized offline Oct03 C3A isolated source creation, protected provisional gate V1

Date: 2026-10-13. **User explicitly authorized permission to create a new isolated source tree**, and requested next deliverable, project/prior chats/GitHub duplication review, script syntax/performance validation and PR342 update. Scope granted is **a fresh isolated source checkout only**. It is NOT approval for Android app/native/telephony source integration, a systemimage build, hybrid super assembly, AVB, device/fastboot, or flash.

## Already qualified; no repeated historical work

- A0 original/CW1/M4/C2 protected paths and exact archived CW1 2,693-byte patch SHA PASS, 30/30 actual operator tests.
- A0B physical parent and new candidate vacancy PASS **AT INSPECTION TIME**, never reserved, ~957.7GB available at observation. System `ninja` not on PATH **advisory only**.
- A0C Oct03 stage vs archived heads vs pinned repo manifest exact **991/991/991**, both heads SHA256 `10658753bbb947a848369b0c248fca824def491e03287012ef031910542908f4`, zero path/revision deltas, 44/44 actual operator regressions. This closes HISTORIC head-ledger equivalence only.
- Original N1F build+flash runner `build/titan2/run-n1f-c3a-derived-c3b5-r2.sh` archived original `dirty-project-state.txt` and `all-project-heads.tsv` with its `SHA256SUMS.txt` **before** seven files + `rom.mk` source delta; its `verify_c3a_source` requires exactly three dirty project names: `build/soong`, `device/phh/treble`, `treble_app`. Oct03 PHH `base.mk` was proven clean by actual V1.1.
- Archived Oct12 PR339 operator work successfully created M4 local-object 4-project pilot + 987 remainder, but its two Python script names (`n1f_m4_offline_reconstruction_pilot_v1_1.py` and `n1f_m4_remaining_987_offline_v1.py`) are **not available as exact executable code** in current GitHub/Project materials; their contents/sha were NOT reviewed/reused. M4 has later R1/B1/PHH/C3B edits and Recovery outcome; **DO NOT clone current mutable M4 dirty file contents into the Oct03 source**.
- No need to rerun a new **historical** 991-row census, recompilation of CW1, C2 28+5 ownership, R1/B1 two-source inspection, PHH image members or 3GB image hashes. A **fresh** 991 HEAD/status check of the *live original donor* immediately before a new clone IS needed as a different safety question.

## Frozen new executable distribution and scope

ZIP `N1F_P342_A1_LOCAL_SOURCE_CREATOR_V1.zip` **SHA256 `1819469e2945859d13e15a379216383ce53733346f8abfbf25f5e82c43d7142d`**, 16848 bytes; script `n1f_p342_a1_creator_v1.py` SHA256 `25963adf7360696fb255d4cafbc422a223e4b288ee625ea58cd3b9d3c0ce2b71`, tests `test_n1f_p342_a1_creator_v1.py` SHA256 `b91dd6aa341087cb90512406ccdedc3a186d478e3e12bc39f515354e3414ae13`. README, plan, engineering review, validation log, 6-member inner SHA256SUMS. ZIP CRC PASS and **6/6 internal SHA pins PASS**. Python source/test AST + bytecode syntax PASS, README Bash command block `bash -n` PASS.

**Target, and ONLY intended on-host write path**:
```text
DONOR_READ_ONLY=/srv/data/sable-build/workspaces/titan2-n1d/android
SEALED_ARCHIVE_READ_ONLY=/srv/data/sable-build/titan2/artifacts/c3a-boot-qualified/20261003T221350Z
NEW_CONTAINER=/srv/data/sable-build/workspaces/n1f-p342-oct03-a1-isolated
NEW_ANDROID_SOURCE=/srv/data/sable-build/workspaces/n1f-p342-oct03-a1-isolated/android
FUTURE_OUT=/srv/data/sable-build/workspaces/n1f-p342-oct03-a1-isolated/out-a1
FUTURE_OUT_CREATED=NO
PROTECTED_M4_AND_CW1=UNTOUCHED
```

**Operator CLI**: default `plan` zero I/O. `preflight --authorize-readonly-source-preflight` checks exactly the real-time donor against sealed archived 991 HEAD list and **all porcelain lines of three exact dirty projects**, with symlink/no-follow, sha/size bounds. `create --authorize-create-isolated-source` repeats preflight and **atomically** calls `mkdir` only if new container absent; creates 991 detached per-project local Git clones using `git clone --local --shared --no-checkout` + local `git checkout --detach PINNED_HEAD` (no `git fetch`, no `repo sync`, no remote URLs), then replays only archived dirty **paths** from current original donor. Every new project HEAD/status and current-donor SHA of those modified files checked, emits JSON receipt within new container. Serial to minimize contention. All new directory ancestors symlink-resistant; protected source Git HEAD/status queries use `--no-optional-locks`, hooks/fsmonitor/gc disabled; only file protocol enabled, Git LFS smudge skipped. Source project HEAD and status drift before create => hard STOP. Partial create => persistent protected incomplete marker, no cleanup/resume/clobber. No original/M4/CW1 source or OUT modification intended. No Android build or flash.

**Important limitation, encoded as permanent guard:** Oct03 archived dirty porcelain contains path/status, not cryptographically sealed byte content for every C3A dirty source file. Exact same HEAD and dirty path/status today **cannot prove dirty file BYTE equality with Oct03**; after a success, the only claimed result is `PASS_PROVISIONAL_LOCAL_CLONE_NOT_OCT03_DIRTY_BYTE_PROVENANCE_NOT_BUILD_READY`. Script leaves `.A1_INCOMPLETE_DO_NOT_BUILD`, reports `source_dirty_bytes_matched_to_original_oct03_archive=false` and `local_git_alternates_depend_on_preserved_donors=true`. This makes a provisional checkout dependent on preserved donor object stores; no self-contained Git alternate/object closure, `.repo`, product scaffold, exact 369-patch final equivalence, build environment, Sable product integration or deployability admission. Fresh `out-a1` is not created. An unexpected source status, clone error or partial result is not authority to relax pins or delete generated evidence.

## Script validation and synthetic performance

**36/36 regression + integration tests PASS (0.368s)**. Includes actual local three-tiny-repository detached, shared-only Git cloning and exact tracked/untracked dirty file copy followed by HEAD/status/content postchecks, as well as negative tests for stale donor HEAD, added untracked file, sealed archive tamper, manifest/parser/path/symlink/FIFO/occupied-root/flag failures. Python AST + compile 2/2 PASS, shell syntax PASS. **300 assistant synthetic 991-head TSV parse iterations median 0.82348 ms/p95 0.97672 ms**; **15 assistant-local real Git clones of 3 tiny source repos** with full preflight, clone and postverify median **56.716 ms/p95 61.965 ms**; local peak memory 99340 KiB. **These are NOT timing estimates for 991 actual Android projects, disk copying or ai-g732 host.** Real A1 host action **NOT EXECUTED** by assistant.

Python 3.10+ stdlib and local Git 2.x required to run; `unzip`/`sha256sum` for package integrity. Does not require installed shell PATH `ninja`, Java or Soong to create provisional source, and checks no Android compilation. Reuses source authority from exact archive not a mutable GitHub branch.

## Status after authorization and package creation

```text
A0_HOST=PASS
A0B_HOST=PASS_VACANT_AT_CHECK_TIME_NOT_RESERVED
A0C_HOST=PASS_SEALED_991_SOURCE_TEXT_JOIN
A1_USER_AUTHORIZED_NEW_ISOLATED_CHECKOUT=YES_ONLY
A1_CREATOR_ZIP_AST_TESTS=PASS_36_OF_36
A1_AI_G732_NEW_SOURCE_CREATION=NOT_EXECUTED
A1_CURRENT_DONOR_DIRTY_FILE_BYTE_EQUIVALENCE_TO_OCT03=NOT_PROVEN
A1_NEW_TREE_RESULT=PROVISIONAL_NOT_BUILD_READY_EVEN_IF_CREATED
A1_OUT=NOT_CREATED
SOURCE_MUTATION_AUTHORIZED=YES_ONLY_NEW_CONTAINER
NETWORK_FETCH=NO BUILD=NO SUPER=NO DEVICE=NO FLASH=NO
```

Next after an actual local-host preflight/creation receipt: independently pin original dirty-file content, complete Android16 C3A product/Soong scaffold and A1 R1/B1/C1/PHH/IMS RRO source integration under a **new separate scope**. Do not run original N1F build+flash driver. Native C2 28+5/ViLTE/CW1 requires G3 and another scope; actual October11 hybrid super SHA, stock companion geometry/AVB and physical deployment remain unbound.
