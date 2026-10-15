# PR342 — Ubuntu A1B V1 actually refused at six-path scaffold contract; exact metadata diagnosis V1

Date: 2026-10-13. This document admits **the latest Ubuntu operator run**, not the earlier Mac `/var` test-fixture failure. It is a docs-only investigation and a **new read-only metadata diagnostic**, not source repair or build authorization.

## Genuine A1B Ubuntu host evidence

Operator has successfully completed **A1 source creation** separately: 991/991 original C3A exact project HEAD and three dirty-project paths/statuses; 991 locally cloned/verified source checkouts at `/srv/data/sable-build/workspaces/n1f-p342-oct03-a1-isolated/android`, no `out-a1`, status `PASS_PROVISIONAL_LOCAL_CLONE_NOT_OCT03_DIRTY_BYTE_PROVENANCE_NOT_BUILD_READY`. Preserve `.A1_INCOMPLETE_DO_NOT_BUILD` and donor alternate object stores. A1 source creation is done and **MUST NOT BE RE-RUN**.

The new Ubuntu **A1B V1** test transcript is distinct from the Mac log. Frozen ZIP outer/internal SHA PASS, **44/44 regression tests PASS (0.048s)**, and plan `PLAN_ONLY_ZERO_HOST_EVIDENCE_IO` reports expected physical `/srv/data` locations (rather than Mac `/private/tmp`). Explicit authorized read-only inspect returned:

```json
{"status":"REFUSED_NO_BUILD_ADMISSION","reason":"build_scaffold_expected_regular_missing_or_unsafe","output_write":false,"source_mutation":false,"build":false,"device":false,"flash":false}
```

**Bounded interpretation:** the frozen V1 code calls `compare()`, verifies the A1 receipt/no-build marker, all four A1 dirty source SHA vs pinned donor/receipt, both Soong original C3A **POST Git blob** pins, and exact original Oct03 archived PHH `rom.mk` bytes/manifest **before** testing `if any(v!='REGULAR' for v in scaffold.values())`. Reaching the scaffold refusal proves these earlier checks did not raise in the observed control flow. However A1B emits **no partial PASS receipt**, and its final result is a STOP, **not source admission**. It does not print WHICH of the six exact metadata leaves was `ABSENT` or `NONREGULAR_OR_SYMLINK`. Do not infer a missing project or a damaged clone, auto-copy original files, normalize a symlink into a file, waive a static gate or remove the no-build marker. The earlier Mac A1B V1 tests erred 27/44 on its `/var` alias, the followup V1.1 fixed **test fixture only** with production code unchanged; the current *Ubuntu* A1B V1 tests already passed, so rerunning V1.1 with the **same six-path regular-only rule** would not diagnose this.

## New exact next check: old-donor vs new-A1 six-path metadata, nothing else

Prepared `N1F_P342_A1B_SCAFFOLD_DIAGNOSIS_V1.zip`, SHA256 **`30e1ba581cfd26d4658bb0e95a4e0f0393b6d56a158e623c358a3763a671b86c`** (9,526 bytes). Main script `n1f_p342_a1b_scaffold_diagnosis_v1.py` SHA256 `e0fba9a17857e6ceca858e024c152282806b5e0aa899947a8e8a33d622465097`, test `test_n1f_p342_a1b_scaffold_diagnosis_v1.py`, plan, README and test log; **five inner SHA256SUMS entries**. The interpreter is Python 3.10+ stdlib and `sha256sum`/`unzip` only for distribution checks; **no Android build tools needed**, and no Git/Repo/Ninja/Java or `debugfs` invoked.

Hardcoded read-only comparison roots:
```text
A1=/srv/data/sable-build/workspaces/n1f-p342-oct03-a1-isolated/android
DONOR_PROTECTED=/srv/data/sable-build/workspaces/titan2-n1d/android
```
Exactly **six** A1B original scaffold relative leaf names under **each** root (12 metadata-only checks):
1. `build/envsetup.sh`
2. `build/soong/soong_ui.bash`
3. `build/make/core/main.mk`
4. `build/make/target/product/gsi/Android.bp`
5. `build/make/target/product/gsi/gsi_skip_mount.cfg`
6. `device/phh/treble/generate.sh`

Plus **metadata only** for `/srv/data/sable-build/workspaces/n1f-p342-oct03-a1-isolated/.A1_INCOMPLETE_DO_NOT_BUILD` and absent `out-a1`. Default `plan` **zero host evidence I/O**, authorized `inspect --authorize-exact-scaffold-metadata-readonly` uses fd-relative `stat(...,follow_symlinks=False)` for every ancestor and exact leaf and `os.open(...,O_DIRECTORY|O_NOFOLLOW)` for each existing ancestor, NEVER follows a symlink; literal `readlink` metadata is allowed **without resolution** to diagnose an exact alias. Every path is either `REGULAR`, `ABSENT`, `SYMLINK_LEAF`, `STOP_UNSAFE_ANCESTOR`, other file type or exact access/race blocker; no content read, directory listing, source checksum, Git objects scan, image read, command execution, mount, build, source/output mutation, network, device or flash. It does NOT substitute a path from a symlink target.

**Interpretation of outcome**:
- A1 path missing/unsafe **and original donor same**: inherited layout, possible false A1B *required regular file* assumption; need separately approve **contract refinement**, not source mutation.
- A1 path missing/unsafe but protected donor literal is `REGULAR`: investigate possible new-source materialization or changed ownership (metadata only so far); do not copy files until owner and evidence pinned.
- A1 path a symlink even if donor is regular: no-follow remains mandatory, hold for explicit ownership/real-location review.
- A1 `REGULAR` all six would be a **different** result from old A1B and require fresh source evidence reconciliation; not build admission.
- `DIAGNOSIS_COMPLETE_NOT_BUILD_READY` reports the six classifications, regardless of count; no build gate can PASS through this tool. `OUT` and marker not modified.

**Validated on assistant Linux fixture**: ZIP CRC PASS, five inner SHA checks PASS, Python source/test AST and compile PASS, README fenced Bash script `bash -n` PASS, **46/46 tests PASS (0.088s)** including missing/unsafe/symlink ancestor/leaf/FIFO, no-follow flags, exact six roles, donor comparisons, no content reads/process/network/write, and simulated physical-temp fixture. **400 synthetic full 12-leaf + two extra metadata inspections median 0.3624ms, p95 0.5311ms** (assistant fixture, not ai-g732 performance). **Real ai-g732 diagnostic not yet executed**. No claim of Android build toolchain, C1/C2 native G3, CW1 runtime, SELinux policy merge, source readiness, or hybrid super/image success.

```text
A1_AI_G732=PASS_991_PROJECTS_PROVISIONAL_ONLY
A1B_UBUNTU_V1_ZIP_TESTS=PASS_44_OF_44
A1B_UBUNTU_V1_INSPECT=REFUSED_SCAFFOLD_EXPECTED_REGULAR
A1B_EARLIER_BYTE_COMPARE_CONTROL_FLOW=REACHED_SCAFFOLD_NO_FINAL_PASS_RECEIPT
A1B_SIX_SPECIFIC_SCAFFOLD_PATH_STATES=NOT_YET_IDENTIFIED
NEW_DIAGNOSTIC_LOCAL_QA=PASS_46_OF_46
NEW_DIAGNOSTIC_AI_G732=NOT_EXECUTED
A1_NO_BUILD_MARKER=PRESERVE
A1_NEW_OUT=NOT_CREATED_BUILD=NO
SOURCE_MUTATION=NO NETWORK=NO DEVICE=NO FLASH=NO
```
