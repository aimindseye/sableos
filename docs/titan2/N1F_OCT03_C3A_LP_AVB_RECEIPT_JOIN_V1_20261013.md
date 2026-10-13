# PR #342 — October 3 C3A preflight LP/AVB receipt join V1

**Date:** 2026-10-13. **Authority:** documentation-only evidence handoff; selected Oct03 N1F `system.img` remains an operator-approved **OFFLINE PLANNING** parent only. **No Android source mutation, build, image reading/hash/extraction, LP repack, network, device contact, reboot, AVB mutation, restore, factory reset or flash authority.**

## Prior SableOS work located — do not repeat

1. **2026-10-03 05:34:41Z E5A/E5B**: `docs/titan2/N1D_C3B_E5B_AUTHORIZATION_PACKAGE.md`, `build/titan2/prepare-n1d-c3b-e5b-authorization-package.sh` and `n1d-c3b-e5a-readonly-device-state/20261003T053441Z/e5b-authorization-package.json` contain an independently prior sealed LP/Virtual A/B `main_a` group model; E5B JSON SHA256 `74531923a9ea6c755a9f8ea52db511c4a4a19a5d9dba3cb51da342c04b768926`. E5B source used earlier `lpdump` and fastboot `getvar` but **we do not rerun tools or device contact**.
2. **2026-10-03 20:30:47Z C3A fastboot-entry preflight**: `docs/titan2/N1D_C3A_V010014_FASTBOOT_ENTRY_PREFLIGHT.md`, original collector `build/titan2/collect-c3a-v010014-fastboot-entry-preflight.sh`, and preflight qualifier already sealed exact fastbootd/slot A/snapshot `none`/zero active COW and capacity checks. Preflight `SHA256SUMS.txt` SHA256 `47f28c371f13974d3a7303dc550014502401fae55a76bb365139f29e4c2da893`. The qualifier compares the exact E5B input SHA, pinned `main_a` maximum, and fresh pre-C3A logical member **sizes**; it does *not* produce companion partition byte SHA-256 identities.
3. **2026-10-03 22:13:50Z N1F R2 run**: operator-confirmed PR #342 27/27 V2 host result established original 90,361-byte run log's six exact ordered `system_a` flash/boot success markers. PR #342 23/23 V1 confirmed archived Oct03 N1F image size, SHA *receipt* and source archive presence. The original R2 runner changed only `system_a` at its documented scope; historical success does **not** certify current LP metadata or seven companion byte identities.

The **C3A preflight was already copied into the October 3 C3A archive**, but this new V1 does *not* replay earlier 991-head project audits, R2 native libraries, M11 compile, M4 skip-mount, V17 journal search, N1D E5B device geometry, complete image hashing, `lpdump` or `lpmake`.

## Remaining narrow question and executable

**V1** validates, via named bounded text only, that the historically sealed pre-C3A preflight JSON and earlier E5B package form the expected cryptographic and field-level receipt chain. It reports which of seven companion partitions have **recorded *pre-C3A sizes***, while always reporting their Oct03 N1F *boot-session content hashes* `UNBOUND_NO_PARTITION_HASH`.

Inputs:
- `/srv/sable-build/evidence/titan2/c3a-v010014-fastboot-entry-preflight/20261003T203047Z/SHA256SUMS.txt` (<=256 KiB) and `c3a-v010014-fastboot-entry-preflight.json` (<=128 KiB);
- `/srv/sable-build/evidence/titan2/n1d-c3b-e5a-readonly-device-state/20261003T053441Z/e5b-authorization-package.json` (<=128 KiB).

Verifies original preflight manifest SHA256 pin, exact preflight JSON member SHA256 within that manifest, exact historical E5B JSON SHA256, JSON unique keys, pre-C3A fastbootd/slot/COW/snapshot/capacity state, consistent earlier `main_a` group maximum. No source tree or image byte read. Importantly **even every historical seal PASS cannot qualify Oct03-matched `super.img`, AVB chain, metadata at N1F postboot or physical restoration**.

### Standalone V1 deliverable (not committed as Android execution code)

- `N1F_P342_OCT03_LP_AVB_AUTHORITY_V1.zip` SHA256 `c5c2607c959245f213856290b1f290ed1dc10751c1be549cd8771e217d048a99`.
- `n1f_p342_oct03_lp_avb_receipt_v1.py` SHA256 `473ca5fd6578d1d2f713dd7b3d0fdbbd25d49ae9b0bdec8191bc13b08b880a49`.
- `test_n1f_p342_oct03_lp_avb_receipt_v1.py` SHA256 `ece32af70d27abc88eb8ea92626a50eca87f95de468271af3042261df3d47762`.
- Complete checksum manifest, README, engineering review, performance and test log in ZIP.

**Local tests:** Python AST compile both files PASS, **23/23 unittest PASS** (full isolated process 0.72s, peak RSS 98,576 KiB); 500-iteration synthetic small-JSON inspect median **0.094 ms**, p95 **0.150 ms**; default missing-input inspect 0.60s / 96,268 KiB. ZIP internal and checksum manifest PASS; README command Bash syntax PASS. **Actual ai-g732 execution NOT RUN**. Local timings do not claim ai-g732 speed.

**Tools on operator host:** Python 3.10+ standard library, `unzip`, `sha256sum` for checking transferred bundle. No `adb`, `fastboot`, `lpdump`, `lpmake`, `avbtool`, mount, repo, git, network or binary image parsing.

Run **only** after retrieving the bundle to `~/Downloads`:

```bash
cd "$HOME/Downloads"
echo 'c5c2607c959245f213856290b1f290ed1dc10751c1be549cd8771e217d048a99  N1F_P342_OCT03_LP_AVB_AUTHORITY_V1.zip' | sha256sum -c -
unzip -n N1F_P342_OCT03_LP_AVB_AUTHORITY_V1.zip
sha256sum -c N1F_P342_OCT03_LP_AVB_AUTHORITY_V1_SHA256SUMS.txt
python3 -B -m unittest -v test_n1f_p342_oct03_lp_avb_receipt_v1
python3 -B n1f_p342_oct03_lp_avb_receipt_v1.py inspect
```

## Status and next authorization boundary

```text
OCT03_SELECTED_PARENT=OFFLINE_PLANNING_ONLY
HISTORICAL_N1F_SYSTEM_A_BOOT=PASS_RETAINED
C3A_PRE_CONTROL_GEOMETRY=PREVIOUSLY_PASS_RECORDED_V1_JOIN_PENDING
OCT03_COMPANION_PARTITION_CONTENT_SHA=UNBOUND_7_OF_7
OCT03_N1F_POSTBOOT_LP_AND_SNAPSHOT_METADATA=UNBOUND
OCT03_MATCHED_AVB_DESCRIPTORS=UNBOUND
MATCHED_RESTORE=UNBOUND
OCT11_ACTUAL_PHYSICAL_SUPER=UNBOUND
G1_FINAL_IMAGE=OPEN G2_EFFECTIVE_AUTHORITY=OPEN G3_IMS_NAMESPACE=OPEN
V1_AI_G732=NOT_EXECUTED
SUPER_BUILD_AUTHORIZED=NO DEVICE_CONTACT_AUTHORIZED=NO FLASH_AUTHORIZED=NO
```

If the V1 join passes, **stop**: this closes *historical pre-C3A geometric receipt chain* only, **not** parent-matched super. To progress toward actual super assembly, ask for **separate, explicit, bounded authority** to inspect known pre-existing stock/Oct03 image LP and AVB metadata with a reviewed matched-restore policy; no device contact, build or flash implied. An Oct03 post-N1F device snapshot cannot be retroactively collected at present, so distinguish reconstructed offline compatibility from proven historic physical bytes. No more generic evidence discovery loops.

## Actual ai-g732 operator outcome — 2026-10-13

The operator verified ZIP and all six internal file SHA-256 manifest entries **PASS**; Python unittest **23/23 PASS** (reported 0.007 s). Bounded `inspect` returned `receipt_integrity`: both the historical C3A manifest pin and exact preflight JSON member hash match, as does the E5B package's independent historical SHA-256 pin. This is an **actual ai-g732 host execution**, not merely the synthetic local benchmarks documented above.

```text
V1_AI_G732=PASS_23_OF_23
C3A_PREFLIGHT_JSON_MEMBER=EXACT_MEMBER_FOUND
C3A_PREFLIGHT_MANIFEST_SHA256_MATCH=YES
C3A_PREFLIGHT_JSON_MEMBER_SHA256_MATCH=YES
E5B_BASELINE_SHA256_MATCH=YES
C3A_PRE_CONTROL_GEOMETRY=PASS_PINNED_HISTORICAL_TEXT_RECEIPT
ACTIVE_GROUP=main_a
ACTIVE_GROUP_MAXIMUM_BYTES=9661579264
SUPER_BYTES=9663676416
SNAPSHOT=none
ACTIVE_COW_COUNT=0
BASELINE=PASS_PINNED_E5B_REFERENCE
GROUP_MAXIMUM_CONSISTENCY=PASS_HISTORICAL_GROUP_MAXIMUM
C3A_PREFLIGHT_TIMESTAMP_LABEL=20261003T203047Z
E5B_BASELINE_TIMESTAMP_LABEL=20261003T053441Z
N1F_RUN_TIMESTAMP_LABEL=20261003T221350Z
HISTORICAL_ORDER=PASS_LABEL_ORDER_ONLY
RECORDED_COMPANION_PRE_C3A_SIZES=6_OF_7
ODM_A_PRE_C3A_SIZE=NOT_BOUND_OR_NOT_RECORDED
OCT03_BOOT_SESSION_COMPANION_SHA256=UNBOUND_7_OF_7
OCT03_N1F_POSTBOOT_LP_SNAPSHOT=UNBOUND
OCT03_MATCHED_AVB_DESCRIPTORS=NOT_QUALIFIED
OCT03_MATCHED_RESTORE=NOT_QUALIFIED
OCT03_MATCHED_WHOLE_SUPER=NOT_QUALIFIED
G1=OPEN_FINAL_IMAGE
G2=OPEN_SIGNING_CLASSPATH_SELINUX
G3=OPEN_IMS_LINKER_NAMESPACE
NO_OUT_WRITE=YES NO_IMAGE_READ=YES NO_IMAGE_HASH=YES
NO_SUBPROCESS=YES NO_NETWORK=YES NO_DEVICE=YES NO_FLASH=YES
```

**Six companion pre-C3A sizes are recorded** for `product_a`, `system_ext_a`, `vendor_a`, `system_dlkm_a`, `vendor_dlkm_a` and `odm_dlkm_a`; `odm_a` returned `NOT_BOUND_OR_NOT_RECORDED`. This is not evidence that `odm_a` is absent, and none of the seven had a byte/hash binding to the October 3 *N1F boot session*. The 05:34Z/20:30Z/22:13Z chronology is based on evidence labels, not a cryptographically complete device-session lineage. Historical pre-C3A `main_a` geometry and COW/snapshot states are now **closed at the pinned receipt level**; this is **not** the post-N1F `super.img` geometry or AVB/restore certification.

**Stop / next decision:** do not rerun V1 or perform another broad census. Before proposing a complete offline `super.img`, identify a separately approved, image-specific and restore-matched method for the **seven companion partition byte identities**, effective LP metadata/Virtual A/B snapshot state and AVB footer/descriptors, without retroactively assuming the physical Oct03 postboot snapshot exists. Any subsequent host image-byte reads/hashes/extractions, compilation, repack or device action require distinct operator authorization. This document grants none.

