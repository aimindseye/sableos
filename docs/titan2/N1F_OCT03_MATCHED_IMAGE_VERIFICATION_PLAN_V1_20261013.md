# Titan 2 N1F — Oct03 matched-image host verification plan V1

Date: 2026-10-13 · Active engineering queue [PR #342](https://github.com/aimindseye/sableos/pull/342). **Operator authorization received to produce the host-only matched-image VERIFICATION PLAN using explicitly identified inputs**. Current executable authority is limited to **fixed-path metadata preflight plus one bounded existing JSON read**. No authority for full partition-image byte reads or hashes, extraction, `lpdump`/LP binary parsing, `avbtool` image examination, scratch image writes, `super.img` assembly, Android build, source edits, network, device contact, restore, reboot or flash. Request separate explicit stage-specific authority before doing any of these.

## Historical work reused, not reexecuted

- Operator-selected, historically physically booted **Oct03 N1F C3A-derived C3B5** `system.img` is at `/srv/sable-build/artifacts/titan2/n1f-c3a-derived-c3b5/20261003T221350Z/system.img`, recorded SHA256 `dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a`, bytes `3200540672`. V1 host `stat`/two archive SHA *receipts* previously PASS but **image bytes were NOT freshly hashed**. Historical N1F system_a flash/boot run markers, source-head snapshot and fastboot preflight already PASS at recorded scope.
- Historical E5B/C3A pre-control geometry: earlier E5B SHA `74531923a9ea6c755a9f8ea52db511c4a4a19a5d9dba3cb51da342c04b768926`; C3A preflight SHA256SUMS seal `47f28c371f13974d3a7303dc550014502401fae55a76bb365139f29e4c2da893`. Recent actual ai-g732 operator V1 join PASS **23/23**, `main_a` max `9661579264`, super capacity `9663676416`, snapshot `none`, active COW `0`. Six pre-C3A partition sizes are recorded; `odm_a` is **not bound/not recorded**, not proven absent.
- The existing [N1C hybrid checkpoint](SABLEOS_N1C_HYBRID_SUPER_CHECKPOINT.md) contains **six exact TEE14 reference files and historical stock-source SHA values**; N1C whole-super subsequently **FAILED TO BOOT**, so its former successful offline assembly is NOT a matched Oct03 precedent. [C0 offline qualifier](N1D_C0_OFFLINE_QUALIFICATION.md) already provides LP diff/AVB boundary analysis, `lpdump -j` and `avbtool info_image` methods for later separately approved evidence. Reuse [host-tools.env](../../build/config/host-tools.env): `SABLE_LPDUMP`, `SABLE_LPUNPACK`, `SABLE_SIMG2IMG`, `SABLE_AVBTOOL`; binaries conventionally under `/srv/data/sable-host-tools/android/aosp-host/bin/`, with host shared library requirements as documented in C0.
- N1C matched recovery documents required complete stock super **plus** matched boot/init_boot/vendor_boot/dtbo/vbmeta* state and, separately, a factory reset. A stock `system_a`-only restore is prohibited. The phone's Oct13 M4 Recovery boot failure and failed factory-reset attempt are separate evidence. Do not contact phone or perform resets.
- Oct11 R3 offline lpmake/partition manifest is **NOT the Oct11 actual flashed super**, nor Oct03 matched LP metadata. Oct11 flashed SHA/journal remains **UNBOUND**. R2 native 56 edges, M11, 991 source census, M4 skip-mount and Oct03 run-log qualification should not be repeated.

## Exact named candidate inputs

**Selected Oct03 parent:** `/srv/sable-build/artifacts/titan2/n1f-c3a-derived-c3b5/20261003T221350Z/system.img`.

**Stock TEE14 reference root:** `/srv/data/sable-build/titan2/artifacts/stock-firmware/unihertz-device-fota-20260922/inspection/bit-equivalence/TEE14-large-reference/`. Six checkpointed files and SHA-256 pins (the following are **N1C stock-reference bytes only**, not Oct03 live-partition hash authority):

| Proposed companion | Stock-root leaf name | Historic N1C source-map SHA256 |
|---|---|---|
| `product_a` | `product.img` | `de1fdecab38b3c5ad7f30beea13f1afb46fa02d98b6cc78d57749b34513aad37` |
| `system_ext_a` | `system_ext.img` | `1d9d25921def9b7e4e767c00a1f34d19ef5e7320138e3522545f2a2f2047d170` |
| `vendor_a` | `vendor.img` | `cfeacc74b4289e56921016fedf35a45a995121b874be3cd2f1561b8ed2d61ada` |
| `system_dlkm_a` | `system_dlkm.img` | `2752d357dc698db0967a3bbc9de2204127eab69fa28f7d3471d3e039e4a2946f` |
| `vendor_dlkm_a` | `vendor_dlkm.img` | `1fc51fb7a2f089b3d9255d00944bda711e64b297daf2ecf687abeae17e0a4936` |
| `odm_dlkm_a` | `odm_dlkm.img` | `ebe714d1ed41742eeb87fa06674900703af97f90f729420fe37555bd02338723` |
| `odm_a` | `odm.img` **candidate only** | **UNBOUND**; no checkpoint pin; no proof of absence |

Under that **same exact** TEE14 stock root, check *metadata only* for `super.img`, `boot.img`, `init_boot.img`, `vendor_boot.img`, `dtbo.img`, `vbmeta.img`, `vbmeta_system.img`, `vbmeta_vendor.img`. The images may exist under alternate locations, but this gate is fail-closed: do not guess or search substitute paths. Historical N1C stock-super restore evidence root: `/srv/data/sable-build/evidence/titan2/n1c-stock-super-restore-artifact-r1c-20260930_200124`; historical TEE14 boot/AVB restore evidence root: `/srv/data/sable-build/evidence/titan2/n1c-restore-tee14-boot-avb-direct-20260930_204335`. Evidence roots are inspected as **directory metadata only**, not proof of matched restore.

Pre-C3A reference JSON already qualified: `/srv/sable-build/evidence/titan2/c3a-v010014-fastboot-entry-preflight/20261003T203047Z/c3a-v010014-fastboot-entry-preflight.json`. The new script reads at most 128 KiB from this **one** exact JSON, not images; its pin was checked in the preceding V1 join and will not be re-qualified again by mere presence.

## 2026-10-13 actual ai-g732 Stage A operator result (supersedes pre-run markers)

The operator supplied the complete stdout from the **actual ai-g732 execution** of `N1F_P342_OCT03_MATCHED_IMAGE_V1.zip` using an isolated extraction. ZIP SHA256 PASS; six internal SHA256SUMS members PASS; exact main-script and unittest SHA PASS; AST syntax PASS both; regression tests **30/30 PASS (0.017 s test runtime)**. Stage A inspect elapsed **0.029 s wall**. JSON footer: `NO_OUT_WRITE=YES NO_IMAGE_READ=YES NO_IMAGE_HASH=YES NO_SUBPROCESS=YES NO_NETWORK=YES NO_DEVICE=YES NO_FLASH=YES`. This is an operator log, **not** independent GitHub rehash of image bytes.

- **Oct03 selected N1F parent metadata: unresolved / protected stop.** `/srv/sable-build/artifacts/titan2/n1f-c3a-derived-c3b5/20261003T221350Z/system.img` classified `REFUSED_SYMLINK_COMPONENT`, `stat_bytes=null`, `stat_size_agrees_with_historical=false`, `actual_image_sha256_verified=NO_IMAGE_BYTES_READ`. The rejection does **not** prove the image is absent or corrupt; a single fixed-path `lstat`/`readlink` ancestor-component diagnostic is the next *proposed* limited host metadata step. Do not silently follow/rebind symlinks, alter V1 refusal logic, or initiate image reads/hash.
- **Six N1C TEE14 stock-reference companion candidates PRESENT_REGULAR_FILE**, metadata sizes: `product_a=1842647040`, `system_ext_a=704434176`, `vendor_a=873082880`, `system_dlkm_a=7487488`, `vendor_dlkm_a=18366464`, `odm_dlkm_a=348160` bytes. Historic N1C SHA pins were displayed but **not rehashed**. All six remain `UNBOUND_NO_DEVICE_PARTITION_BYTE_RECEIPT` for the actual Oct03 N1F boot.
- **Seventh `odm_a`:** `odm.img=NOT_PRESENT_AT_EXACT_PATH` and historic stock pin null. Not proof that `odm_a` was absent on-device or from all available stock sources.
- **Eight remaining named stock-root image candidates:** `super.img`, `boot.img`, `init_boot.img`, `vendor_boot.img`, `dtbo.img`, `vbmeta.img`, `vbmeta_system.img`, `vbmeta_vendor.img` = `NOT_PRESENT_AT_EXACT_PATH`. This is bounded input-path coverage only; do not generalize to absence from other previously archived restoration evidence or choose substitute files via guessing.
- **Historical metadata present:** the original C3A preflight JSON passed bounded parse (active `main_a`, max 9,661,579,264; super bytes 9,663,676,416; slot a; snapshot none; zero COW), correctly labeled **PRE_C3A only**, not N1F postflash. The two original stock-super and TEE14 boot/AVB restoration evidence directories were `PRESENT_DIRECTORY`, **not** certified matched image inputs.

**Decision:** `STAGE_A_AI_G732=PASS_EXECUTION_WITH_INPUT_PATH_GAPS`; `OCT03_PARENT_METADATA=REFUSED_SYMLINK_COMPONENT`; `N1C_SIX_REFERENCE_IMAGE_PATHS=PRESENT_NOT_HASHED`; `OCT03_COMPANION_BYTES=UNBOUND_7_OF_7`; `N1F_POSTFLASH_LP=UNBOUND`; `AVB_AND_RESTORE=NOT_QUALIFIED`. No final-image G1/G2/G3 gate closes. Stage B1/B2/B3/B4 and assembly/device/flash remain **NOT AUTHORIZED**. Do not repeat Stage A 30 tests, previous E5B/C3A metadata joins, 991 source census, N1F run history, M4 skip-mount probe or broad searches.

## Exact Oct03 parent symlink component — actual ai-g732 readlink result

Operator executed the previously checksum-pinned **metadata-only** `n1f_p342_oct03_parent_path_probe_v1.py`. The received result: `status=STOP_SYMLINK_COMPONENT`, `component=/srv/sable-build/artifacts/titan2`, `symlink_target_literal=/srv/data/sable-build/titan2/artifacts`, unresolved suffix `n1f-c3a-derived-c3b5/20261003T221350Z/system.img`. Script emitted `no_image_read=true`, `no_image_hash=true`, `no_symlink_follow=true`, `no_output_write=true`, `no_subprocess=true`, `no_device_contact=true`, `authority_to_rebind_parent=false`. **This establishes only an exact literal symlink explanation for the Stage A refusal**; the target's existence/leaf size/hash is not established. V1's refuse-by-design rule is correct and must not be disabled.

The **single explicit candidate** formed from that literal, *not yet bound*, is:

```text
/srv/data/sable-build/titan2/artifacts/n1f-c3a-derived-c3b5/20261003T221350Z/system.img
```

Next **metadata-only** helper `n1f_p342_oct03_canonical_parent_metadata_v1.py` (conversation bundle, **not committed to Android repo**) pins both path strings, requires the original symlink still match the literal exactly, sequentially `lstat`s each component of the explicit candidate, refuses any additional symlink, requires a final regular file, and compares its `st_size` to historical 3,200,540,672 bytes. It reports **`candidate_sha256_verified=false` and `authority_to_rebind_parent=false` even on size match**. Script SHA256 `ba923fbcfbc4d6cba8a95f38ed18980b131d51d07de0b46038877fff593535d5`, test companion SHA256 `963289e2275838fd2a426d1072b90f6a242692bdebe51543d2211f44a14764d1`; both Python AST PASS, local synthetic **11/11 PASS** (0.001 s test runtime); 1000-repeat synthetic median 0.0049 ms/p95 0.0064 ms. **ai-g732 canonical-target check NOT EXECUTED**; these performance measurements are synthetic, not actual host file metadata timing. The probe has no image-open, hashing, scan, subprocess, network, device or output-write code.

No B1/B2/B3/B4 image-byte, LP/AVB/restore authority, no build/repack or device/flash approval. Historical C3A/N1F boot PASS unchanged; 7/7 Oct03 companion byte identities, postflash LP/VAB, matched AVB/restore, G1/G2/G3 remain OPEN/UNBOUND.

## Canonical Oct03 parent metadata — actual ai-g732 PASS; B1 parent-only proposed

Operator's **actual ai-g732** results for checksum-pinned `n1f_p342_oct03_canonical_parent_metadata_v1.py`: script and companion regression module SHA256 both PASS; **11/11 tests PASS** (0.000 seconds reported); metadata probe `status=CANDIDATE_REGULAR_FILE_SIZE_MATCH_METADATA_ONLY`. The original pinned alias `/srv/sable-build/artifacts/titan2` still resolves via literal symlink `/srv/data/sable-build/titan2/artifacts` and the *explicit separately inspected*, no-additional-symlinks candidate is a **regular file of exactly 3,200,540,672 bytes** at `/srv/data/sable-build/titan2/artifacts/n1f-c3a-derived-c3b5/20261003T221350Z/system.img`. This closes the **parent input candidate path/size metadata** question only, not the image content or October 3 device-state matching.

The operator report explicitly states `candidate_sha256_verified=false`, `authority_to_hash_image=false`, `authority_to_rebind_parent=false`, and `NO_OUT_WRITE/NO_IMAGE_READ/NO_IMAGE_HASH/NO_SYMLINK_FOLLOW/NO_SUBPROCESS/NO_NETWORK/NO_DEVICE/NO_BUILD/NO_FLASH=YES`. **Next gate proposal is B1-PARENT ONLY**: one full streaming SHA256 read of *that one exact canonical input*, compare to the historic `dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a`; expected precisely 3,200,540,672 bytes. **Operator separate explicit B1-PARENT authorization has NOT been received.** Do not hash six stock companions or any other image under this narrow proposal.

An optional separately delivered review-only bundle `N1F_P342_OCT03_PARENT_B1_V1.zip` has distribution SHA256 `48a2b08bd53cd2e8d4cfd393e9ac21e1b558245ed27e1a38e4721ec68626b91c`. Main `n1f_p342_oct03_parent_b1_hash_v1.py` SHA256 `a3b02bbd8113a25fb3c0fc4419041054715adf9e9f34ef7eda8daca6b034be2b`; regression `test_n1f_p342_oct03_parent_b1_hash_v1.py` SHA256 `1b774ddba9e85328988386082c3500cf549c220f4b2adae1a530ff8cd7fe1c5b`. Local AST PASS both, synthetic **16/16** PASS in 0.009 s, archive+three-member manifest PASS. **Actual ai-g732 B1 hashing NOT EXECUTED.** Unflagged script does metadata only; hash mode needs explicit `--authorize-parent-image-hash` *and* separate operator permission before it may run. Hash mode uses 4 MiB blocks, fd-relative `O_NOFOLLOW` across all ancestors, regular-file/size prechecks, bounded exact-length read, before/after inode/size/time checks, no output writes, no external subprocess, no phone; local synthetic tiny-file hashes do not qualify real-image performance. No request for automatic image scans/repacking/device work.

A B1 exact parent SHA match, if separately authorized and obtained, will mean only `OCT03_PARENT_BYTES_EQUAL_TO_HISTORICAL_RECEIPT`, **not** physical Oct03 partition content, 7/7 companion matches, postflash LP/VAB, AVB, matched restore, G1/G2/G3 or permitted flashing. If SHA mismatches or source changes, STOP and retain original historical SHA as reference only.

## Next stage gates (B1–B4 still require separate approval)

**A. Current authorization (run now after ZIP verification):** exact-path `lstat` of selected system, seven stock companion **candidate images**, stock super and seven boot/AVB files; inspect two historical recovery evidence roots as directories; read only the named bounded JSON to label pre-control geometry. Refuse symlink path components and non-regular image leaves. Do not scan directories, produce evidence files, open/hash images or claim size=matching content. The Python script's output classifies presence, not Oct03 match; all seven Oct03 content hashes stay **UNBOUND** by construction.

**B1. Proposed future limited byte hashing:** only with explicit operator permission, agree exact path/size/format/trusted expected SHA for each candidate and expected total bytes/time. Compare six current candidate images against historical **N1C stock** hashes; even if equal, this establishes `EQUAL_TO_N1C_STOCK_REFERENCE` only, **not** Oct03 physical companion partition equivalence. `odm_a` has no historical pin and requires separately established authority. Optional rehash of Oct03 3.2GB system needs explicit approval. No automatic image read in Stage A.

**B2. Proposed future LP and Virtual A/B metadata review:** only with approval, run installed `SABLE_LPDUMP` on exact candidate stock `super.img` (raw vs sparse must be checked first); compare slot/group sizes, extents, free capacity, group names, partition attributes and snapshot/COW assumptions. Reuse C0 LP JSON diff code. Any `simg2img` conversion writes large scratch bytes and requires a **separate scratch-write/disk budget**; not authorized by Stage A. Historic pre-C3A `main_a` sizes do not reconstruct Oct03 N1F postflash LP table.

**B3. Proposed future AVB and footer review:** only with approval, `SABLE_AVBTOOL info_image` on specifically approved `vbmeta`, `vbmeta_system`, `vbmeta_vendor` and selected relevant image(s). Compare chain descriptors, rollback and hashtree/footer coverage against actual proposed logical image bytes and partition boundaries. Orange/unlocked boot evidence is not an automatic AVB closure.

**B4. Proposed future matched restore qualification:** only with approval, verify complete same-build TEE14 stock set and exact recovery procedure; N1C restore success does not prove a given stock source matches Oct03 physical N1F. Do not authorize write before restore/slot/COW/AVB and userdata decisions independently pass.

**C. Separate assembly and physical permissions:** no complete hybrid `super.img` build, no COW cleanup, no slot/AVB/boot chain changes, no flash until distinct approval and G1 effective embedded runtime composition, G2 signing/classpath/SELinux, G3 recursive native/IMS namespace pass. The Titan 2 historical N1C whole-super negative precedent remains active.

## V1 standalone script and local validation

Bundle ZIP: `N1F_P342_OCT03_MATCHED_IMAGE_V1.zip` SHA256 `45c052cab339d667d300a6dab2283785af65a7c68da694684b99a81562c2acb7`. Script `n1f_p342_oct03_candidate_preflight_v1.py` SHA256 `8fb3766a52de46f93ee8afb4997b1d3f644c42cd07f57cda571c14cce63bfdb5`. Regression test file SHA256 `1bc4eb947b54636738d5e3b2b7bbde54108b98e8618fca774e2373305e916961`.

Python3 stdlib syntax AST PASS (both files); **30/30 regression tests PASS**, including no-image-open regression, symlink refusal, invalid/duplicate JSON, bounded input, output-write refusal and six historical pins not promoted to an Oct03 match. Full local Python process 0.73s, peak 99,212 KiB; 500-repeat synthetic fixed-path inspection median 0.341ms, p95 0.508ms. Package ZIP and six internal SHA256SUMS entries PASS; operator README Bash snippet syntax PASS. These are **local** measurements; **ai-g732 execution COMPLETE — 30/30 tests PASS; path findings below**. Script needs Python3.10+ stdlib; distribution needs `unzip` and `sha256sum`, no other tools.

```bash
cd "$HOME/Downloads"
echo '45c052cab339d667d300a6dab2283785af65a7c68da694684b99a81562c2acb7  N1F_P342_OCT03_MATCHED_IMAGE_V1.zip' | sha256sum -c -
unzip -n N1F_P342_OCT03_MATCHED_IMAGE_V1.zip
sha256sum -c N1F_P342_OCT03_MATCHED_IMAGE_V1_SHA256SUMS.txt
python3 -B -m unittest -v test_n1f_p342_oct03_candidate_preflight_v1
python3 -B n1f_p342_oct03_candidate_preflight_v1.py inspect
```

Current `BUILD=NO`, `IMAGE_BYTE_READ_OR_HASH=NO`, `SUPER_REPACK=NO`, `DEVICE=NO`, `FLASH=NO`, `RELEASE=NO`. Operator should supply the V1 JSON/NO_* footer for bounded stage-A classification, then select whether to separately authorize B1. No additional archive/journal, 991-head, M11, native inventory, old preflight geometry or directory-wide searches.
