# PR #342 — N1C restoration R0B exact-leaf metadata V1

2026-10-13. **Host-only, no device/network/build/flash.** R0B is a **strict subset** of the prior two-root metadata scope. It does not read receipt or image bytes, and does not widen the previous 64-entry directory cap.

## Evidence and root cause of the R0 stop

The operator reported outer ZIP and all four source/doc README hashes PASS, **22/22** R0 test cases PASS (0.004s), default plan no filesystem access. Actual stock-super root returned **18** immediate file metadata rows. Notably, `titan2-stock-v010014-super-restore-r1c.sparse.img` appears as a **4,189,766,872-byte regular file**, without image read/hash, firmware-header validation, LP parse or certification. Valid small-file metadata leaf candidates include `N1C_STOCK_SUPER_RESTORE_ARTIFACT_LEDGER.md` (1267 B), `source-partition-hashes.sha256` (542 B), `source-partition-map.txt` (1105 B), `source-partition-sizes.tsv` (1625 B), `partition-compare.txt` (1328 B), `stock-super-file-type.txt` (239 B), and `unpacked-inventory.txt` (173 B). **R1 content read not authorized.** `summary.log` may contain identifiers; do not publish raw text.

Second historical root, `/srv/data/sable-build/evidence/titan2/n1c-restore-tee14-boot-avb-direct-20260930_204335`, yielded `REFUSED_ENTRY_CAP` at 64 with empty *suppressed* entries array. **This is not an empty directory.** Do not modify R0's cap or run unrestricted `find`/`grep`.

## Previously completed authority, reused

N1C historical V01.00.14/TEE14 stock-super + boot/AVB restore, then factory reset, already PASS for original N1C device recovery. Merged PRs **#218**, **#250**, **#251** already implemented E4/C0 stock artifact evidence discovery. Their full drivers would recursively search, hash image files, and write new reports, so must **not** be invoked for this stage. Older Tier 2 E0 verification concerns V01.00.13/TEE13 and is not equivalent. Oct03 parent host-file SHA was independently qualified in B1 and must not be rehashed.

## One-root fixed-basename subset

Script `n1f_p342_n1c_restore_exact_leaves_v1.py` checks only one pinned directory's **seven directly named leaves**:

```text
boot.img
init_boot.img
vendor_boot.img
dtbo.img
vbmeta.img
vbmeta_system.img
vbmeta_vendor.img
```

The first six excluding `dtbo` are exact component names used by the merged E4 resolution; N1C first-write recovery documents `dtbo` as the seventh boot-chain component. No recursive listing, directory enumeration or arbitrary filename heuristics. Uses fd-relative `O_NOFOLLOW|O_DIRECTORY` for each ancestor and `os.stat(..., follow_symlinks=False)` for only those seven leaves. Symlinks are never followed, directories never entered, file contents and hashes never read. Missing means absent only **at this exact evidence-root leaf path**.

Default `plan` mode makes no filesystem access; `inspect --authorize-exact-tee14-leaf-metadata` is opt-in metadata only. Fixed scope fits within prior operator-approved metadata-only work; new R1 receipt content, large directory enumeration, image or LP/AVB read require separately scoped consent.

## Offline checked bundle

```text
ZIP=N1F_P342_N1C_R0B_EXACT_LEAVES_V1.zip
ZIP_SHA256=d9ceb7ce62ce76d2296c8944f31fd7f874064037615f3db41f225eeb834d7564
PYTHON_SCRIPT_SHA256=7ea86376cc1ce0568a13093d7e2b7d4d1fcec3d858f69fdd589999e67e5869ec
PYTHON_TEST_SHA256=fcfe2f05d84471479c33ff2cdcdac6eceb2625a6340bd2e4900abc7bd27205c6
LOCAL_PYTHON_AST=PASS_BOTH
LOCAL_SYNTHETIC_TESTS=PASS_20_OF_20
LOCAL_FULL_TEST_PROCESS_WALL_SECONDS=0.87
LOCAL_PEAK_RSS_KIB=98956
LOCAL_1000_SEVEN_LEAF_MEDIAN_MS=0.0135
LOCAL_1000_SEVEN_LEAF_P95_MS=0.0190
AI_G732_R0B=NOT_YET_EXECUTED
```

Python3.10+ stdlib for probe, sha256sum/unzip for transfer. No AOSP host-tool binary or installation required. The existing two-root R0 remains `INCOMPLETE_OR_REFUSED`, with first-root partial success retained. No stock image or boot/AVB integrity qualified by R0B.

## Hold boundaries

```text
N1C_HISTORICAL_RESTORE=PASS_PRIOR_N1C_SCOPE_ONLY
R0_SUPER_DIR=PASS_METADATA_18_LEAVES
R0_TEE14_DIR=REFUSED_ENTRY_CAP_64
R0B_SEVEN_EXACT_LEAVES=PREPARED_NOT_EXECUTED
R1_RECEIPT_CONTENT=NOT_AUTHORIZED
B1_STOCK_COMPANION_IMAGE_HASH=NOT_AUTHORIZED
B2_LP_B3_AVB_B4_RESTORE=NOT_AUTHORIZED
OCT03_N1F_PHYSICAL_COMPANIONS=UNBOUND_7_OF_7
G1_G2_G3=OPEN
NETWORK=NO BUILD=NO IMAGE_CONTENT_READ=NO DEVICE=NO FLASH=NO
```
