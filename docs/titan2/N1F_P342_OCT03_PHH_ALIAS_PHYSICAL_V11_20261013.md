# N1F PR #342 — exact Oct03 artifact alias rebound to witnessed physical target V1.1

Date: 2026-10-13. **Distribution ready; actual ai-g732 V1.1 archived PHH/policy inspection NOT RUN.** Prior authorization permits one narrow read-only comparison; operator still needs to run the exact frozen inspect command. No source mutation, image build, super assembly, device contact, flash or reset.

## Actual metadata result settles the V1 refusal

Operator's checksum-pinned metadata-only helper returned:
```text
OK component=/srv type=DIRECTORY
OK component=/srv/sable-build type=DIRECTORY
OK component=/srv/sable-build/artifacts type=DIRECTORY
STOP component=/srv/sable-build/artifacts/titan2 type=SYMLINK target=/srv/data/sable-build/titan2/artifacts
```
This is **the precise reason** V1 returned `REFUSED_NO_PARTIAL_EVIDENCE [Errno 20] Not a directory: 'titan2'` during its first archive SHA256SUMS path traversal. V1 outer/inner checksum PASS, 30/30 tests PASS; no archive, image or `debugfs` content read occurred. The observed literal symlink target is distinct from older, also-documented `/srv/data/sable-build/artifacts/titan2` path; **do not** substitute that older candidate. No generic symlink traversal has been authorized.

## Frozen V1.1 exact rebinding, no weakened O_NOFOLLOW

New standalone ZIP **`N1F_P342_PHH_POLICY_ALIAS_V1_1.zip`**, outer SHA256 **`ae2763fe15895a0ed2d29b691d5cd845b7d4fe8020de3dcbf8677c019cf78a7f`** (12,304 bytes). Python `n1f_p342_phh_policy_alias_v1_1.py` SHA256 `e7972c6b4459c9bb347f683639a73ff743c5adfa86acb926aa9a835ae1aa771a`; 44-test file `test_n1f_p342_phh_policy_alias_v1_1.py` SHA256 `82c28a95d8a175e9d054fbd2b442de165c76bd7055813a882023f6e2b2114c4f`. Plan, README and exact internal SHA256SUMS included.

Only substantive change from V1: **validate** the legacy alias by per-component nofollow directory descriptors plus `os.stat(...,follow_symlinks=False)` + `os.readlink` and require its **exact** literal target `/srv/data/sable-build/titan2/artifacts`, before reading anything. Then open archive and Oct03 system.img **directly by physical target** (no symlink traversal allowed in that path):
```text
LEGACY_ALIAS=/srv/sable-build/artifacts/titan2
REQUIRED_LITERAL_LINK_TARGET=/srv/data/sable-build/titan2/artifacts
ARCHIVE_MANIFEST=/srv/data/sable-build/titan2/artifacts/c3a-boot-qualified/20261003T221350Z/SHA256SUMS.txt
ARCHIVE_DIRTY=/srv/data/sable-build/titan2/artifacts/c3a-boot-qualified/20261003T221350Z/dirty-project-state.txt
OCT03_RAW_SYSTEM=/srv/data/sable-build/titan2/artifacts/n1f-c3a-derived-c3b5/20261003T221350Z/system.img
M4_RAW_SYSTEM=/srv/data/sable-build/workspaces/n1f-m4-localrepo/android/out-m4-g2-fullimage-01/target/product/tdgsi_arm64_ab/system.img
```
Fixed caps: manifest <=512KiB, archived dirty <=256KiB and SHA-bound to archived manifest; Oct03 image must have size 3200540672, M4 image 3194466304; **no whole-image rehash** (historical prior SHA pins preserved). For each image only three fixed ext4 entries via existing host `/usr/sbin/debugfs`, fd-bound and without `-w`: `/system/bin/phh-on-boot.sh` <=512KiB; `/system/etc/selinux/plat_sepolicy.cil` <=8MiB; `/system/etc/selinux/plat_file_contexts` <=512KiB; content SHA/membership only, not echoed. M4 pinned CIL SHA `a7805083d63a0fda11ce7943c0c4ee90954c44971d7b85897504d64421eab758` and contexts SHA `ac2ba2392c7bcdb9e75f6add88841b4d216159c6ede0e673f881aaf6b4737ff9` remain enforced. Every physical ancestor/leaf uses nofollow; an additional symlink or missing target fails closed. Default `plan` zero I/O; inspect requires `--authorize-exact-oct03-m4-readonly` to exercise the **same narrow read-only scope** requested by operator.

No `realpath`, general symlink following, pathname search, `find`, `repo`, source diff, image mount, extraction output, `secilc`, policy merge, build, network, device or flash. `O_NOFOLLOW` was **not** disabled to get past the old path. The previous V1 script remains immutable and should **not** be retried.

## Validation

Assistant-container local independent verification:
```text
V11_ZIP_INTEGRITY=PASS
V11_INNER_SHA256=PASS_4_OF_4
V11_PYTHON_AST=PASS_BOTH_FILES
V11_README_BASH_N=PASS
V11_REGRESSION=PASS_44_OF_44 (0.007s core)
V11_PLAN=PASS_NO_EVIDENCE_IO
V11_ALIAS_SCOPE=PASS_EXACT_OPERATOR_OBSERVED_LINK_TARGET
V11_FULL_TWO_IMAGE_SYNTHETIC_REPLAY=PASS_WITH_POLICY_MISMATCH_NEGATIVE
V11_SYNTHETIC_METADATA_N=1500
V11_SYNTHETIC_METADATA_MEDIAN_MS=0.00593
V11_SYNTHETIC_METADATA_P95_MS=0.00672
V11_PROCESS_PEAK_RSS_KIB=97292
V11_AI_G732_DEBUGFS_IMAGE_READ=NOT_EXECUTED
```
Synthetic performance measures fixture alias metadata only, NOT `debugfs` or full 3.2GB ext4 image timing. The old main pipeline remains unchanged except the alias check and two artifact literal paths. A new host `ENOTDIR` from the physical target is another **hard stop**, not authority for an alias fallback.

**Evidence limits:** Even a successful no-dirty C3A PHH archived status plus a changed final M4 PHH hook SHA and static platform policy member SHA cannot prove installed hook **execution**, effective *merged* Titan2 vendor/odm SELinux, a device AVC/root cause or that M4 would boot within a hybrid super. Oct03 archived source state, image member comparison and runtime-boot evidence are **different gates**.

```text
V1_HOST_INSPECT=REFUSED_VERIFIED_LEGACY_SYMLINK
V11_ALIAS_LINK_METADATA=PASS_USER_OBSERVATION
V11_REBOUND_READONLY_INSPECT=PREPARED_NOT_EXECUTED
OCT03_BASE_MK_ARCHIVED_DIRTY=NOT_YET_CLASSIFIED
OCT03_VS_M4_STATIC_PHH_AND_SELINUX=NOT_YET_COMPARED
RUNTIME_INIT_MERGED_SELINUX=NOT_PROVEN
SOURCE_MUTATION=NO BUILD=NO DEVICE=NO FLASH=NO
```
