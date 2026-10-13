# N1F PR #342 — N1C restore-receipt provenance handoff V1

Date: 2026-10-13. **Host-only plan and two-root top-level metadata check ONLY.** The operator authorized preparing this plan, not reading image contents, running prior full C0/E4 tools, contacting Titan 2, or approving any restore/build/flash.

## Prior work checked and reused, not repeated

- [N1C first-write postmortem](N1C_FIRST_WRITE_POSTMORTEM_20260930.md): `STOCK_SUPER_RESTORE=PASS`, `TEE14_BOOT_AVB_RESTORE=PASS`, then a separate recovery factory reset; device recovered to **V01.00.14**. A later stock `system_a`-only restore failed. This establishes **N1C historical recovery**, NOT an exact Oct03 N1F physical same-session companion-image match.
- Merged [PR #218](https://github.com/aimindseye/sableos/pull/218), [PR #250](https://github.com/aimindseye/sableos/pull/250) and [PR #251](https://github.com/aimindseye/sableos/pull/251) already repaired image evidence discovery. Main `build/titan2/qualify-n1d-c0-offline.sh` and `build/titan2/qualify-n1d-c3b-e4-deployment-readiness.sh` have proven stock-super / six boot+AVB *resolution mechanisms* using explicit paths or N1C evidence. E4 searches recursively via find/grep, reads/hashes stock images and writes evidence, therefore **do not rerun E4/C0** for this narrow investigation. Neither repo code nor current PR states the precise existing leaf names inside the two host evidence roots.
- Separate `aimindseye/unihertz-titan2` Tier 2 `tools/t2-tier2-restore-verify.sh` already hashed a **V01.00.13 / TEE13** recovery set, writing reports. That is a *different stock version* from N1C's V01.00.14/TEE14 and must **never** substitute for this host evidence. Its N1C mirrored postmortem confirms required TEE14 boot/init_boot/vendor_boot/dtbo/vbmeta/vbmeta_system/vbmeta_vendor in addition to stock super.
- Previously qualified on actual ai-g732: PR #342 B1-PARENT **single canonical Oct03 host `system.img` hash PASS**, bytes `3200540672`, SHA256 `dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a`. Never repeat that costly hash. Oct03 seven **physical** companion partition SHA256 remain 7/7 UNBOUND; N1F postflash LP/Virtual A/B, AVB and matched restore remain UNBOUND/NOT_QUALIFIED. Original Stage A had both historical restore **directories present**, but stock-root super/boot/AVB **leaves absent at that one checked TEE14 location**; absence at an exact path is not global absence.

## The only two Stage R0 input roots

```text
/srv/data/sable-build/evidence/titan2/n1c-stock-super-restore-artifact-r1c-20260930_200124
/srv/data/sable-build/evidence/titan2/n1c-restore-tee14-boot-avb-direct-20260930_204335
```

### R0 — bounded immediate-child metadata (new, not previously executed on ai-g732)

Package `N1F_P342_N1C_RESTORE_RECEIPTS_V1.zip`: **SHA256 `1995f01afd5e362d36eb7a307efcd45fc0a2bb30a42a05562f9448ea89e847dd`**. Python tool `n1f_p342_n1c_restore_receipts_v1.py`: SHA256 `f799e1f8193d432bfabe75dd4ce8910f16ce3c0dd576d8addf90935660a9dbb1`. Tests `test_n1f_p342_n1c_restore_receipts_v1.py`: SHA256 `59899a46204d64282706bb8ab0aab0908888965f9ab2c4d201f3ab08e71f6a1b`. The bundle also holds detailed standalone plan and README, with an internal four-member checksum manifest. The bundle is provided to the operator via the conversation, **not** committed to Android/build code.

`python3 -B n1f_p342_n1c_restore_receipts_v1.py plan` is the safe default and makes **no host filesystem inspection**. Explicit `inspect --authorize-two-root-metadata` uses Linux/POSIX stdlib dirfd-relative `O_NOFOLLOW` along every original path component; for **only the two named roots**, iterates at most **64 immediate children per root**, labels regular file / directory / symlink / other, and obtains **only** regular-file `st_size`. No subdirectory traversal, symlink following, arbitrary glob, path guessing, receipt-content read, SHA of evidence/images, image read, LP/AVB tools, writes, subprocess, network or device. A cap/path/symlink issue fails closed. The metadata JSON does **not** establish receipt contents or artifact SHA/provenance; it supplies exact names for the next review.

Local independent package SHA+five ZIP member integrity PASS; Python AST both PASS, **22/22 synthetic regression tests PASS** (0.005–0.010 s test runtime), full test process ~0.69 s / peak ~98,308 KiB on assistant host. In 1,000 synthetic one-level listings of twelve short filenames: median **0.0245 ms**, p95 **0.0506 ms**. These are **synthetic**, not measured against actual ai-g732 host roots. README Bash snippet syntax PASS. Python >=3.10 stdlib; `sha256sum` and `unzip` only for package transfer. No AOSP host tool installation or invocation needed.

**Execution state:** `R0_AI_G732=NOT_EXECUTED` until operator returns JSON. If a directory contains nested subdirs, R0 only prints the subdir name and does not enter; follow-up would need a separately approved exact subpath.

### R1 — proposed future leaf-receipt verification (not yet authorized)

From actual R0 names **only**, select exact regular **text** receipt leaf names (not files merely guessed from extensions), independently pin permitted bytes (proposed <=128 KiB/file), expected SHA if independently known, and parser/schema; classify any path mentioned inside a receipt as an **untrusted historical statement**, not permission to follow or hash. Nested evidence paths require a separate exact-path proposal. No automatic image-byte read, archive extraction, or recursive listing. Never publish raw device serials, carrier/subscriber data or unredacted logs into the PR.

### Holds

```text
N1C_HISTORICAL_STOCK_RESTORE=PASS_IN_ORIGINAL_N1C_SCOPE
OCT03_PARENT_HOST_SHA256=PASS_HISTORICAL_REFERENCE_ONLY
R0_TWO_ROOT_METADATA=PLAN_PREPARED_AI_G732_NOT_EXECUTED
R1_EXACT_TEXT_RECEIPT_READ=NOT_AUTHORIZED
B1_OTHER_IMAGE_HASHES=NOT_AUTHORIZED
B2_LP_B3_AVB_B4_RESTORE=NOT_AUTHORIZED
OCT03_COMPANION_PARTITION_SHA256=UNBOUND_7_OF_7
OCT03_POSTFLASH_LP_AVB_AND_MATCHED_RESTORE=NOT_QUALIFIED
OCT11_ACTUAL_SUPER=UNBOUND
G1_G2_G3=OPEN
SOURCE_MUTATION=NO BUILD=NO NETWORK=NO DEVICE=NO REBOOT=NO FLASH=NO
```
