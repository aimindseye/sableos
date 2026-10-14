# PR342 A1B V1.1 — Mac unit-fixture path correction; Ubuntu source audit still pending

Date: 2026-10-13 (operator-provided Mac transcript; new assistant fixture QA). **DO NOT TREAT MAC REFUSAL AS FAILURE OF THE UBUNTU A1 991-PROJECT CHECKOUT.**

## Exact reported evidence

The user confirmed **build host is Ubuntu ai-g732** and provided two separate transcripts:
- **Ubuntu A1 source creator**: outer+6 inner SHA PASS, 36/36 tests PASS (0.187s); current protected donor 991 exact HEADs / 3 expected dirty projects PASS; new local 991/991 detached clones+post-verify PASS in `/srv/data/sable-build/workspaces/n1f-p342-oct03-a1-isolated/android`. Final classification **`PASS_PROVISIONAL_LOCAL_CLONE_NOT_OCT03_DIRTY_BYTE_PROVENANCE_NOT_BUILD_READY`**. Its `.A1_INCOMPLETE_DO_NOT_BUILD` marker must remain; `out-a1` was not created; Git object alternates still depend on donor stores. **Do not rerun the A1 creator or start a build.**
- **Mac A1B V1**: ZIP/inner SHA PASS, then **27 of 44** regression tests ERRORED, all at `dirfd(ANDROID)` during temporary fixture setup `os.open('var', O_DIRECTORY|O_NOFOLLOW, ...)`: `NotADirectoryError: [Errno 20] Not a directory: 'var'`. The test fixture used `tempfile.TemporaryDirectory()` under Mac `/var/folders/...`, where `/var` aliases `/private/var`. The strict no-follow production verifier correctly refuses this ancestor. Separately, Mac `inspect --authorize-a1b-readonly` refused **`[Errno 2] No such file or directory: 'srv'`** because the fixed production `/srv/data` host layout exists on **Ubuntu**, not Mac. **No actual Ubuntu A1B source/archive bytes were inspected**; neither Mac refusal establishes a source-content, A1 clone, Soong or Android failure.

## V1.1 immutable corrected distribution

`N1F_P342_A1B_SOURCE_AUDIT_V1_1.zip`, outer **SHA256 `a2c714016856a3ef28a4fcf77f463224f818c15d218e8825a5098713dd62e634`**. New source `n1f_p342_a1b_source_audit_v1_1.py` SHA256 `04b99e82b7bb18b84af6d2e437fbe0e7696a968e80b0a83ef08d2e512c8013ce`. Python **production diff from V1 is EXACTLY ONE LINE**: `VERSION='1.0'` to `VERSION='1.1'`; `dirfd`, per-component nofollow source/archive paths, regular bounded reads, 4 dirty file checks, 2 original Soong post Git blob checks, original Oct03 archive PHH rom SHA binding, marker/receipt/no `.repo`/no `out-a1`/six scaffold metadata checks unchanged.

**Only the test harness** canonicalizes `Path(os.path.realpath(tempfile.gettempdir()))` for its **synthetic temporary fixture parent** and validates that this physical parent passes the SAME original nofollow dirfd test before creating synthetic files. It NEVER calls `realpath` on any actual pinned Ubuntu source/archive path. Two additional tests: physical temporary fixture path, and intentional symlinked fixture alias still refused by unchanged production `dirfd`. The Mac `/var` issue is therefore fixed *in synthetic test setup*, not bypassed in safety-critical audit.

Distribution contents: two Python scripts, fixed plan/README, engineering review, SHA256SUMS. **ZIP integrity PASS; internal 5/5 SHA PASS; Python AST/compile 2/2 PASS; README `bash -n` PASS; 46/46 regression tests PASS (0.081s locally)**; simulated macOS-style `TMPDIR=/tmp/.../var-alias` pointing at a physically distinct temporary fixture base: **46/46 PASS (0.079s)**. **600 synthetic fixed-file inspections** median **0.42678 ms**, p95 **0.67645 ms** on assistant fixture; this is NOT Ubuntu ai-g732 disk throughput or Android compile performance. No Ubuntu A1B `inspect` was executed or reported yet.

## Correct next host action

Run new V1.1 ZIP on **Ubuntu ai-g732**: sha256sum -c outer SHA, unzip -tqq, inner SHA256SUMS, `python3 -B -m unittest -q test_n1f_p342_a1b_source_audit_v1_1`, `python3 -B n1f_p342_a1b_source_audit_v1_1.py plan`, then `python3 -B n1f_p342_a1b_source_audit_v1_1.py inspect --authorize-a1b-readonly`. Do not use Mac for this last fixed `/srv` inspection. No Git/Repo/Java/Ninja/Soong/network/build/device/flash. **Even successful A1B** yields at most `PASS_A1B_THREE_OF_FOUR_DIRTY_FILE_AUTHORITIES_FOURTH_UNBOUND_NOT_BUILD_READY` due to unbound original Oct03 modified `treble_app/sdk/.knownPackages` bytes and unqualified product graph/alternates. If Ubuntu refuses some fixed build-scaffold file, preserve output and original paths; do not fabricate symlink or mutate source to satisfy a metadata expectation. The permanent A1 no-build marker stays.

```text
A1_UBUNTU_SOURCE_CREATION=PASS_991_PROVISIONAL_NO_BUILD
A1B_V1_MAC_TESTS=FAILED_27_SYMLINKED_TMP_FIXTURE_ERRORS
A1B_V1_MAC_INSPECT=REFUSED_EXPECTED_MISSING_SRV
A1B_V1_1_LOCAL_ZIP_SHA_AST_BASH=PASS
A1B_V1_1_LOCAL_TESTS=PASS_46_OF_46
A1B_V1_1_SYMLINKED_TMP_EMULATION=PASS_46_OF_46
A1B_V1_1_UBUNTU_REAL_INSPECT=NOT_EXECUTED
NO_BUILD_MARKER=PRESERVE
SOURCE_MUTATION=NO BUILD=NO NETWORK=NO DEVICE=NO FLASH=NO
```
