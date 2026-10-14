# A1Y — New-image G1 static mount-skip + exact historical restore receipts

Date: 2026-10-14. SableOS Titan 2 PR342 engineering lane. PR remains open/draft/unmerged. **No physical write, device, super assembly, source edit or network permitted by this package.**

## Actual input and prior-work reuse

Actual ai-g732 A1X postbuild: `PASS_A1X_NEW_IMAGE_AND_TREE_READONLY_NOT_DEVICE_READY`, errors empty, elapsed 4.502 s, original A1W/A1U receipt continuity passed, 16/16 selected image ext4 members exact compared against PRODUCT_OUT, five Sable APK package identities PASS, OEM ImsService platform certificate and shared UID PASS, two Mediatek JARs and classpath PASS, compiled IMS slot1/2 SELinux service labels PASS. **New active image SHA256 `7142c10f85fc18e7a0f72101421324009a17ea2dad895c917f414997951c9a1b`, bytes 3210473472.**

Operator explicitly selected hybrid-super deployment as intended engineering strategy; successful prior N1C offline super and failed N1C physical whole-super flash are separate evidence. Previously merged PR218/250/251 C0/E4 stock resolution and original N1C/Oct03 B1 receipts should NOT be repeated. PR342 R0 earlier listed 18 exact immediate leaves in stock-super restore evidence root, while the second boot/AVB evidence root refused an overly broad 64-entry census. R0B seven exact immediate-leaf names was already designed, and R1 small text candidate leaves were already identified, but not yet read. No new R0 scans. Canonical host-tools.env already exposes LP/AVB tool paths but invocation/assembly remains outside this step. AOSP GSI source explicitly places `gsi_skip_mount.cfg` under embedded `/system/system_ext/etc/init/config/skip_mount.cfg` and installs a compatibility directory symlink `/system/etc/init/config -> /system/system_ext/etc/init/config`; C++ fs_mgr loader recognizes this path. Previous A1X **did not** include these G1 members among its 16 verified files, so a narrow new check is appropriate.

## A1Y V1 sealed external package

`N1F_P342_A1Y_G1_EXACT_RESTORE_READONLY_V1.zip`, bytes **14302**, outer SHA256 **`00ee63554d54ff222944454105a2ca231f83732641f45b91b3b505c78813e382`**; ZIP 8 entries (7 SHA-sealed plus SHA256SUMS.txt), CRC PASS.

Runner after independently verifying ZIP SHA and fresh extraction: `bash ./n1f_p342_a1y_one_command_v1.sh`. It validates all seven internal SHA entries, Python AST 2 scripts, Bash syntax, and 30 synthetic hermetic tests. It prints a **zero-host-I/O plan**, then uses `inspect --authorize-a1y-readonly-g1-and-exact-receipts` (no mutation authorization; read scope opt-in) against exact pinned A1 paths. The bare direct Python script defaults to `plan` and cannot inspect without the explicit flag. The final output is JSON **stdout only** and no A1 evidence files are created.

**G1:** Check prior A1W IMAGE_RESULT.txt (<=8KiB), strict no-symlink component open of active image, exactly 3210473472-byte extent and complete streaming SHA (once), ext4 signature, exact installed source `android/build/make/target/product/gsi/gsi_skip_mount.cfg` and output-tree `system/system_ext/etc/init/config/skip_mount.cfg` <=16KiB, exact built compatibility symlink target, then read just two exact image members from the same pinned read-only image FD via existing Ubuntu `/usr/sbin/debugfs` or `/usr/bin/debugfs` with bounded stdout/deadline: the primary embedded config bytes and directory symlink stat. Validate config has exact `/product, /system_ext, /product/*, /system_ext/*` rules, and image source/tree equality. It does not claim first-stage execution, effective stock fstab precedence, LP/COW or a device boot.

**Historical fixed inputs:** Four known N1C V01.00.14 / TEE14 small text receipts under `/srv/data/sable-build/evidence/titan2/n1c-stock-super-restore-artifact-r1c-20260930_200124`: `N1C_STOCK_SUPER_RESTORE_ARTIFACT_LEDGER.md`, `source-partition-hashes.sha256`, `source-partition-map.txt`, `source-partition-sizes.tsv`; cap 16KiB each, UTF-8 check, report SHA256/bytes/line count **only**. Do not output raw historical paths, serials, log text or follow paths mentioned within the receipts. Seven exact direct-leaf metadata names `boot.img, init_boot.img, vendor_boot.img, dtbo.img, vbmeta.img, vbmeta_system.img, vbmeta_vendor.img` at historical evidence root `/srv/data/sable-build/evidence/titan2/n1c-restore-tee14-boot-avb-direct-20260930_204335`. No directory enumeration, recursive search, symlink following, image bytes, LP binary tool, AVB tool or data write. A boot file `NOT_VERIFIED_AT_DIRECT_ROOT` is **not** proof of global absence.

Results can reach `PASS_A1Y_STATIC_G1_AND_HISTORICAL_RECEIPTS_NOT_MATCHED_SUPER_READY`, expressly a static/read-only progress receipt **NOT** matched super / flash readiness. On any mismatch or missing exact receipt: `HOLD_NOT_HYBRID_SUPER_READY` and exit 1, with reasons. Stage A1Y never certifies seven October 3 physical companion content identities, postflash LP/AVB/VAB, same-version matched restore or native IMS runtime G3. No super.img built or device contact attempted.

## Independent syntax, functional and performance QA

- ZIP CRC PASS; inner SHA7/7 PASS; both Python files AST/bytecode compile PASS; Bash `bash -n` PASS.
- **30/30** fully synthetic source/tree/ext4/stub-debugfs tests PASS under both umask077 and umask022 **after fresh exact archive extraction**; earlier source suite 30/30 PASS. Synthetic negative cases include corrupted image, drifted A1W receipt, missing skip rules, tree/image wrong symlink, partial/extra FD hash, rejected source/receipt symlink, oversized receipt, missing named historical leaf, failed read-only command and bounded output classification. Synthetic fixtures explicitly exclude the real A1 paths.
- Assistant-container synthetic 4MiB FD SHA 25 repetitions median **2.7057ms**, p95 **3.0582ms**; synthetic bounded small receipt read 700 repetitions median **0.0103ms**, p95 **0.0154ms**. These timings are not ai-g732 real 3.21GB disk throughput or LP/AVB timings.
- **Actual A1Y ai-g732 NOT EXECUTED**; no G1 runtime/matched stock/super device claim implied.

```text
A1W_BUILD=PASS_ACTUAL
A1X_POSTBUILD=PASS_ACTUAL_16_IMAGE_MEMBERS
A1Y_ARCHIVE_AND_TESTS=PASS_LOCAL_30_BOTH_UMASKS
A1Y_AI_G732=NOT_EXECUTED
HYBRID_SUPER_STRATEGY=USER_APPROVED
HYBRID_SUPER_MATCHED_INPUTS=OPEN
HYBRID_SUPER_BUILT_FOR_A1X=NO
DEVICE_CONTACT=NO FLASH=NO
```
