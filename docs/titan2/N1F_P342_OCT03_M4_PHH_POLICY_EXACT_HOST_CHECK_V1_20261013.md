# PR342 — Oct03 archived PHH and final M4 installed hook/policy: bounded verification V1

Date 2026-10-13. Operator requested confirmation of the archived Oct03 PHH source state, and of installed PHH boot-hook/platform SELinux changes in the final M4 image. **Tool prepared, NOT executed on ai-g732**. No source edits/builds/flash.

## Reused evidence and no-dup scope

Original Oct03 N1F = C3A 991-project/369-patch source plus seven files and one rom.mk inheritance (new compatibility delta 0). Main C3A env pins PHH commit 39ba82ef89ff5bf6b22ca8f147dbf317bffa20ed; full C3B hardener pins its HEAD:base.mk Git blob SHA1 a29e402009d449150f1216e5d517ec0c9b36bfbd. C3A generated dirty-path allowlist excludes base.mk, but Oct03 final runner only checked dirty *project names*, not every file. It archived a SHA256SUMS-sealed dirty-project-state.txt prior to the seven-file product delta. Inspecting that exact small text closes a distinct remaining source-file question.

M4 had exact two-block PHH/C3B repair, base.mk POST SHA256 9e197a490a61a5721b8bb881e93acbc451104957a9599895bc724cfb5768820b, removing the PHH private-policy input and external-overlay inheritance plus TrebleApp XML. The wider C3B boot-hook removal transforms were NOT all replayed. Real packaging e2fsdroid failed to label /bt_firmware, then after narrow cleanup complete M4 image was produced. This does not prove runtime AVC, policy merge, hook invocation or Recovery cause.

Previous M4 full image SHA256 261ee714db92c188eec7effc1afb6edd26627aaa1741e5f887915e078e1000ce size 3194466304 PASS at historical scope; embedded plat_sepolicy.cil SHA256 a7805083d63a0fda11ce7943c0c4ee90954c44971d7b85897504d64421eab758 and plat_file_contexts SHA256 ac2ba2392c7bcdb9e75f6add88841b4d216159c6ede0e673f881aaf6b4737ff9 PASS. Original Oct03 booted system.img SHA256 dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a, size 3200540672. Do NOT rehash images, rerun M4 11/11, A4/R2, R1/B1 or 991-project census.

## Frozen exact input / read contract

Distribution-only ZIP N1F_P342_PHH_POLICY_EXACT_V1.zip SHA256 c923fe6b92fedafd0a302590dea28f052390988d4aa316b2ad3170c56330f358. Python source SHA256 50b201a03243011aa58e0713f210aea55e3ae548fa6585264040996bdc2fc01a; tests SHA256 70fa0a5e3a1495623e5f1ed53d7c01cc8c7ce0af5dd62e7bc4fb31e2e10824cc.

The script only reads:

1. /srv/sable-build/artifacts/titan2/c3a-boot-qualified/20261003T221350Z/SHA256SUMS.txt (<=512KiB), and sibling dirty-project-state.txt (<=256KiB). Unique manifest SHA must match actual dirty bytes. Parse only device/phh/treble section for base.mk dirty, not a new git/repo scan.
2. /srv/sable-build/artifacts/titan2/n1f-c3a-derived-c3b5/20261003T221350Z/system.img (exact 3200540672 bytes), and /srv/data/sable-build/workspaces/n1f-m4-localrepo/android/out-m4-g2-fullimage-01/target/product/tdgsi_arm64_ab/system.img (exact 3194466304 bytes). Path and size required; inherited read-only fd to /usr/sbin/debugfs, no -w and no mount.
3. In each ext4 image exactly /system/bin/phh-on-boot.sh (<=512KiB); /system/etc/selinux/plat_sepolicy.cil (<=8MiB); /system/etc/selinux/plat_file_contexts (<=512KiB), with stat metadata before bounded cat. Output only membership/bytes/SHA, never contents, never directory listing. Two existing M4 policy-member SHA pins must pass.

Default plan makes zero evidence calls. Host inspect requires explicit --authorize-exact-oct03-m4-readonly. Fail closed on symlink/size/path/M4 known hash mismatch, no alternate path alias, no partial results. Whole-image current SHA is NOT recomputed; the prior seals remain historic, and fresh path+size alone is not a cryptographic rebind. Source mutation NO, build NO, mount NO, network NO, device NO, flash NO, super packing NO.

**Result limits:** archived no-dirty supports the pinned HEAD base.mk provenance as of archive time. Different PHH script member SHA means different *installed bytes*; presence does not prove init called it. Different plat CIL/context SHA proves distinct *static platform member content*, not specifically a PHH cause nor successful vendor/odm merged SELinux/AVC. Even identical members would not establish effective runtime policy or boot success.

## Script QA and performance

Assistant container local ZIP CRC PASS, four inner SHA256 PASS, Python AST/compile PASS both files, README Bash -n PASS; **30/30 synthetic tests PASS (0.003s core)** covering no-I/O plan, approval gate, unique archived SHA, dirty parse, malformed records, ext4 stat regular/missing/symlink/oversize, member SHA/caps, nofollow ancestor/leaf, file size, no process mutation. 4000 synthetic parser cases median 0.00442ms/p95 0.00463ms, max test process RSS 95884KiB. This is NOT image/debugfs throughput. The assistant container has no /usr/sbin/debugfs, so external ext4 integration awaits an actual ai-g732 operator receipt. PR339 previously used that exact host debugfs tool.

```text
OCT03_ARCHIVED_BASE_MK_DIRTY_RECEIPT=NOT_YET_READ
M4_INSTALLED_PHH_BOOT_HOOK_SHA=NOT_YET_READ
OCT03_VS_M4_PLATFORM_POLICY_MEMBERS=NOT_YET_COMPARED
EFFECTIVE_RUNTIME_MERGED_SELINUX=UNPROVEN
M4_RECOVERY_CAUSE=UNKNOWN
EXACT_HOST_CHECK=PREPARED_AST_30_TESTS_ZIP_PASS
SOURCE_MUTATION=NO BUILD=NO IMAGE_BUILD=NO DEVICE=NO FLASH=NO
```

## Actual operator run: exact archive path refused before any receipt content (2026-10-13)

**Operator-provided ai-g732 result**, not synthetic: original `N1F_P342_PHH_POLICY_EXACT_V1.zip` outer SHA PASS; four internal manifest entries PASS; regression **30/30 PASS (0.002s)**; default plan `PLAN_ONLY_NO_EVIDENCE_IO` correctly lists exact Oct03 archive and two system images. Authorized `inspect --authorize-exact-oct03-m4-readonly` returned:

```json
{"status":"REFUSED_NO_PARTIAL_EVIDENCE","reason":"[Errno 20] Not a directory: 'titan2'","source_mutation":false,"image_mutation":false,"build":false,"device":false,"flash":false}
```

**Cause localized to code path order:** Existing frozen `inspect()` calls `exact_bytes(MANIFEST,...)` first, which calls `open_exact` walking each absolute ancestor with `O_DIRECTORY | O_NOFOLLOW`. The first `titan2` component along the fixed archive manifest path is **`/srv/sable-build/artifacts/titan2`**. On Linux, `ENOTDIR` from that `os.open` can mean symlink-with-O_NOFOLLOW or non-directory component. The transcript does **not** reveal which. It is not an artifact, image, compiled policy, PHH hook, hash or device failure. Since refusal happens before the manifest open, **archived dirty-state bytes read=0, Oct03/M4 image bytes read=0, real debugfs calls=0**. The terminal SSH session closed after nonzero return while shell `set -e` was active; no inference of host crash.

**Safety disposition:** Preserve fail-closed original script and its existing pins. Do **not** strip `O_NOFOLLOW`, call `realpath` and substitute its output, change the pinned root to a guessed `/srv/data` alias, read the images anyway, or re-run 30 tests for this same package. Before any newly bound path content reads, run the following **metadata-only lstat check** that stops at the **first** symlink/non-directory/error. It never follows a symlink, enumerates a directory or opens a file's contents:

```bash
export PYTHONDONTWRITEBYTECODE=1
python3 -B "$HOME/Downloads/N1F_P342_OCT03_PATH_METADATA_V1.py"
```

Distribution single Python file checksum `bff8cb5f26c25a49a9f409eb36ce3ed387a62799d6c8bcd2ce88f0d45fc9c8a4`. It has the literal first Oct03 manifest path only; reports ancestor metadata and, for a symlink, `os.readlink` text **without following the link**. Program prints `STOP component=...` on the first unsafe component, returning to shell for inspection (no source/image/evidence content read). Assistant-local Python compilation PASS, **4/4 synthetic tests** of regular path, symlink, non-directory and missing path PASS; **1000 mocked temporary symlink inspections** median 0.0099ms/p95 0.0109ms (assistant container only, no ai-g732 benchmark). This file is strictly diagnostic; it is **not** a patched content inspector or license to access a symlink target. After metadata is supplied, rebind new exact path only with separate explicit acceptance of physical canonical root and appropriate content SHA evidence. The original broad archived paths are source-history literals, not proof of mount topology today.

```text
PHH_V1_PACKAGE_AND_REGRESSIONS_AI_G732=PASS_30_OF_30
PHH_V1_REAL_INSPECT=REFUSED_ENOTDIR_AT_LITERAL_TITAN2_COMPONENT
FAIL_CLOSED=PASS_NO_PARTIAL_CONTENT
ARCHIVED_OCT03_DIRTY_STATE=NOT_READ
OCT03_VS_M4_INSTALLED_BOOT_HOOK=NOT_READ
OCT03_VS_M4_STATIC_POLICY=NOT_READ
NEXT=METADATA_ONLY_LSTAT_NOFOLLOW_LITERAL_ARCHIVE_PATH
SOURCE_MUTATION=NO IMAGE_READ=NO BUILD=NO DEVICE=NO FLASH=NO
```
