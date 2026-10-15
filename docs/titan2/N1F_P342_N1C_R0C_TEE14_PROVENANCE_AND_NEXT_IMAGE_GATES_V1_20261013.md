# PR #342 — N1C TEE14 R0B actual result, proposed R0C and next-image gates

Date: 2026-10-13. Documentation-only governance. **R0C new cap requires separate explicit operator authorization before inspection.** No image-byte read, receipt read, extraction, build, device or flash granted.

## Actual operator R0B receipt, not previously recorded

The ai-g732 operator ran checksum-pinned `N1F_P342_N1C_R0B_EXACT_LEAVES_V1.zip`: package outer ZIP and four internal files SHA-256 PASS; Python synthetic **20/20 PASS (0.005 s)**. The no-host-access `plan` PASS. Explicit one-root, seven-fixed-name `inspect --authorize-exact-tee14-leaf-metadata` returned `PASS_EXACT_LEAF_METADATA_ONLY` with `names_checked=7`, **zero content bytes read**, no directory enumeration/symlink follow/output write/device/build/flash.

Every exact direct TEE14 restoration evidence root basename `boot.img`, `init_boot.img`, `vendor_boot.img`, `dtbo.img`, `vbmeta.img`, `vbmeta_system.img`, `vbmeta_vendor.img` returned `NOT_PRESENT_AT_THIS_EXACT_ROOT` and `stat_bytes=null`. This is **not** absence from nested folders, other dated evidence, original firmware, or the historical physical restore operation. Earlier R0 top-level listing had `REFUSED_ENTRY_CAP` at 64 with suppressed entries and must **not** be relabeled empty. The historical N1C V01.00.14/TEE14 complete restore PASS is not contradicted or independently requalified.

First root remains completed: 18 immediate metadata entries; exact candidate `/srv/data/sable-build/evidence/titan2/n1c-stock-super-restore-artifact-r1c-20260930_200124/titan2-stock-v010014-super-restore-r1c.sparse.img` is a 4,189,766,872-byte regular file **metadata only**. Small exact receipt names such as `source-partition-hashes.sha256`, `source-partition-map.txt`, `source-partition-sizes.tsv`, and `N1C_STOCK_SUPER_RESTORE_ARTIFACT_LEDGER.md` have already been identified. They have **not been read**; R1 content permission absent.

## Prior GitHub/project reuse and no duplication

- N1C first-write postmortem: historical V01.00.14 stock-super + TEE14 boot/AVB recovery, followed by distinct factory reset.
- Merged SableOS [#218](https://github.com/aimindseye/sableos/pull/218), [#250](https://github.com/aimindseye/sableos/pull/250), [#251](https://github.com/aimindseye/sableos/pull/251) already corrected C0/E4 stock-super and six boot/AVB image path resolution from prior restore evidence. **Do not rerun their recursively searching, image-hashing or report-writing drivers.** Their source supplies basename candidates only, not a locally verified Oct03 physical-content match.
- Tier2 V01.00.13/TEE13 restore verification `aimindseye/unihertz-titan2` is **not** the N1C V01.00.14/TEE14 input.
- PR #342 prior 30/30 Stage A, B1 parent 3,200,540,672-byte actual SHA256 `dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a` PASS, historical C3A/E5B 23/23 join, original Oct03 boot/run markers, 991-project source census, native R2 evidence are **already completed and must not be repeated**.

## Proposed R0C: one root, capped filtered one-level *metadata only*

Only the **same explicit TEE14 evidence root** `/srv/data/sable-build/evidence/titan2/n1c-restore-tee14-boot-avb-direct-20260930_204335`. Prepared ZIP: `N1F_P342_R0C_TEE14_INVENTORY_V1.zip`, SHA256 `3989e5b1aeabe140e95c9b3ea15b5ac8b706a90458c7610e89b80b0ae2df6e68`. Main script `n1f_p342_r0c_tee14_name_inventory_v1.py` SHA256 `db3f0c5f070b8b1215b2386f535cfe9346877629df9c7f62ad4bed32c0cea674`; synthetic test file SHA256 `8c0703f9d68cf12e319a95ebe111f122768fa8095e7895fc7592b3fd6cba984e`. The separately supplied ZIP also contains user README, full plan and internal four-file manifest.

**Important safety:** Original R0 cap=64 stays intact. New **256 immediate-entry** cap is a **proposed scope expansion**, NOT authorized by the previous R0 or R0B approval; do not run explicit inspection until operator approves that exact increase. Default `plan` makes no host FS access. With separately approved `inspect --authorize-r0c-256-immediate-names`, the script no-follows each ancestor; enumerates **at most 256 immediate names** from only this root; retains **at most 96 matching** names with tokens `boot,avb,vbmeta,dtbo,restore,hash,sha256,manifest,ledger,source,partition,receipt,summary`; outputs their no-follow type and regular-file sizes only. Any overflow produces **REFUSED_NO_PARTIAL_ENTRIES**, no partial names. No subdirectories followed or entered, no file content reads, no other roots, no image hashes, no LP/AVB or Android tools, no output files, network, builds or device. Matching filenames are untrusted **metadata candidates only**, not proof of restore version/hash or permission to open.

Local package ZIP/integrity PASS; AST syntax both Python files PASS; **22/22 synthetic tests PASS** (0.005 s test runtime; separate whole test process 0.78s, peak 98,700 KiB); README shell syntax PASS. 1,000 synthetic 150-entry one-level inspections median **0.1884ms**, p95 **0.2096ms**, synthetic assistant host only. Python >=3.10 stdlib; only unzip/sha256sum for distribution; no AOSP host tools. **Actual ai-g732 R0C = NOT EXECUTED.**

## Road to next image — evidence and separate permissions

| Milestone | Status and stop |
| --- | --- |
| Selected Oct03 N1F host parent identity | **PASS historical SHA**, not a physical Oct03 system_a readback or automatic parent production rebind |
| Exact stock super + boot/AVB provenance | Historic N1C restore PASS; super evidence file **metadata present**, seven direct TEE14 leaves missing; receipt paths/bounds and matched input hashes need decisions |
| Oct03 seven companion partition bytes and N1F postflash LP/Virtual A/B | **UNBOUND**; old pre-C3A control group/snapshot metadata cannot substitute |
| G1 final embedded system_ext/product/skip_mount.cfg | **OPEN**, prior static checks reused |
| G2 effective final signing, classpath, SELinux | **OPEN**, historical static evidence reused |
| G3 recursive native/IMS namespace | **OPEN**, historical R1/C1/M11/native edges reused |
| Isolated N1F-derived IMS system build / offline super assembly | **NOT AUTHORIZED**; distinct assembly permission and exact final-image gates required |
| Restore-ready physical flash | **NOT AUTHORIZED**; one-attempt mode/LP/AVB/stock rollback and independent operator decision required |

**Priorities:** (1) R0C **only if independently authorized**, to find bounded historical receipt names rather than repeating scans; (2) propose R1 reads of *specific tiny* receipts, separately approved; (3) concurrently design targeted G1/G2/G3 closure from the already qualified static artifacts; (4) settle Oct03-matched companion/LP/AVB and full matched restore; (5) only then seek a separate isolated offline image-build/repack permission, and later distinct device authority. No completion percent is meaningful across independent must-pass gates.

```text
R0B_AI_G732=PASS_EXACT_SEVEN_METADATA_ALL_ABSENT_AT_DIRECT_ROOT
R0C_PREPARED=YES
R0C_CAP_256_AUTHORIZATION=NOT_RECEIVED
R0C_AI_G732=NOT_EXECUTED
R1_RECEIPT_FILE_CONTENT=NOT_AUTHORIZED
OCT03_PARENT_HOST_B1_SHA256=PASS_HISTORICAL_REFERENCE_ONLY
OCT03_PHYSICAL_COMPANIONS=UNBOUND_7_OF_7
G1_G2_G3=OPEN
B1_EXTRA_IMAGE_READ_B2_B3_B4=NOT_AUTHORIZED
SOURCE_MUTATION=NO BUILD=NO NETWORK=NO DEVICE=NO FLASH=NO
```
