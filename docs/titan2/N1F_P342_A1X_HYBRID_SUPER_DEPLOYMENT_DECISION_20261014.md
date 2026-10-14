# 2026-10-14 Titan 2 — operator hybrid-super deployment decision after A1X PASS

**Authority/decision.** The operator explicitly approved proceeding toward **hybrid `super.img` deployment** and requested clarification about whether that is required to install additional libraries/APKs. Record `HYBRID_SUPER_DEPLOYMENT_STRATEGY=OPERATOR_APPROVED`. This is a device-write strategy approval, **not evidence that a compatible complete super image, matched stock restore set, or safe flash command exists**. Do **not** initiate whole-super write, slot/AVB changes, reboot, factory reset or device contact while the remaining hard gates are unqualified. If the exact one-use command is eventually offered, it must enforce its contemporaneous host/device/snapshot/restore preflight and refer to a fully pinned artifact; no assumption of current fastbootd mode from the October 13 history.

## What was proven by A1X

Actual ai-g732 output: `PASS_A1X_NEW_IMAGE_AND_TREE_READONLY_NOT_DEVICE_READY`, `errors=[]`, elapsed 4.502s. The image at `/srv/data/sable-build/workspaces/n1f-p342-oct03-a1-isolated/.A1T_HOST_ONLY_SYSTEMIMAGE_V1/out/target/product/tdgsi_arm64_ab/system.img` is 3210473472 bytes and SHA256 **`7142c10f85fc18e7a0f72101421324009a17ea2dad895c917f414997951c9a1b`**. All **16** selected embedded ext4 image members exactly match the output tree (namespace `top_system`): five Sable APKs in `/system/product/app`; `ImsService.apk` in `/system/system_ext/priv-app` (package `com.mediatek.ims`, shared UID, platform signing cert equality); `mediatek-common.jar`, `mediatek-ims-base.jar`, three C1 XML files, 46-byte marker, framework-res, bootclasspath.pb, compiled property and service contexts with both IMS slot mappings. A1W source-staged exact `radio.te` and `service_contexts` and built 86/86 in 02:43, preserving the original SHA 82ceeaf2... image snapshot.

**Not proven:** the *new image* `gsi_skip_mount.cfg` actual installed bytes at `/system/system_ext/etc/init/config/skip_mount.cfg`, compatibility symlink at `/system/etc/init/config`, effective first-stage mounting/overlay precedence or true device boot. A1X's 16 selected checks do **not** include these G1 paths. The new image currently includes the verified six C1 modules (one OEM privileged IMS APK, two Mediatek framework JARs, three XMLs) plus five Sable apps; it does **not** establish the 28-stock-plus-five-platform C2 native library admission, five R2 ViLTE ELF payloads, CW1 four-method source integration, or any other additional APKs beyond the checked list. Do not imply `G3` recursive native/provider/classloader/ABI runtime closure from signer and file presence.

## Hybrid vs installed payloads — reconcile AtlasOS architecture

Upstream `Abyss-c0re/atlasos` (current public `README.md`, `scripts/build.sh`) says its Titan 2 recipe is a *custom LineageOS GSI plus stock region-matched vendor/boot*, packaged into a hybrid super using an optional workshop `titanus2`. Its script builds/stages owned apps and the Titan touchpad into the **GSI systemimage** first, and offers `--gsi-only` without a stock ZIP. With `STOCK_ZIP` and workshop it can package hybrid; it does **not** establish that hybrid super alone is necessary to make a given APK/JAR appear. AOSP documentation supports system_ext under `/system/system_ext` when independently mounted system_ext is absent, contingent upon actual GSI skip-mount/init behavior. **Therefore:** payload *installation* comes from correct system / embedded system_ext / product build composition; deployment packaging may be a whole-super hybrid, system_a-only, or other reviewed variant. A whole-super write is not a proof of runtime mount precedence or IMS boot success.

This PR's engineer-authoritative Oct13 architecture **retains offline complete hybrid super as LP metadata/partition-byte control** and embeds IMS exclusively in `system.img`; standalone stock `system_ext_a` is not where our IMS fix should live. `skip_mount.cfg` must remain effective. The selected **Oct03 booted system.img** SHA dc1f917d... was previously independently hashed under B1 (historical host artifact identity only), **not** proof of matching seven Oct03 live logical companion bytes. Oct11 actual hybrid flash SHA/journal remains UNBOUND. Historical N1C hybrid `super.img` offline composition and round-trip PASS, but *whole-super physical flash failed boot* and required matched stock restore. Historical Oct13 M4 `system_a` transport PASS led to Recovery FAIL; neither test is controlled evidence that whole-super would fix this current image.

## Required pre-assembly/admission (host-only)

1. **G1 effective embedded mount layout for A1X image**, source+image `skip_mount.cfg` and compatibility symlink, read-only/no mount and no rebuild. For runtime applicability, identify actual stock first-stage fstab/LP mount precedence. Never assert mount proof solely from file presence.
2. **Stock matching:** name/verify exact already-retained donor stock image/firmware version and byte-pinned logical partitions `product_a, system_ext_a, vendor_a, system_dlkm_a, vendor_dlkm_a, odm_dlkm_a, odm_a` (the seventh `odm_a` is historically UNBOUND, **not absent**), exact old LP metadata and group/snapshot/COW arrangement, active/inactive group semantics and physical super capacity. Historical pre-C3A `main_a` group max 9661579264 bytes and super 9663676416 bytes are not post-A1W on-device LP authority. A `super.img` from old N1C/Oct11 cannot be blindly reused.
3. **AVB and full matched restore:** bind the complete stock super and same firmware version boot, init_boot, vendor_boot, dtbo, vbmeta, vbmeta_system, vbmeta_vendor and verify descriptor/chained-AVB handling without speculative disable/patch. Recovery must not rely on stock system_a-only restore or an unverified factory reset. A previously failed N1C whole-super flash remains a high-risk negative precedent.
4. **G3:** classify exact required IMS/native provider and linker namespace dependencies against this **selected image and donor vendor**, and first-boot minimum, without importing held R2/C2 files merely to assemble super. Distinguish remaining IMS/VoLTE/ViLTE support from Android boot feasibility.
5. After host evidence PASS and separate bounded offline-repack execution step, generate `super.img` with exact pinned `system_a` and matched companions, then `lpdump` + `lpunpack` round-trip per-partition SHA and geometry/AVB read-only checks, capacity and COW/snapshot gate. Do not touch device as part of assembly.
6. **Physical write remains a distinct one-use gate**: fresh explicit identity/device mode check; active slot, power/cable/backup and restore provenance; no automatic mode assumptions; exact flash command of reviewed artifact only; bounded waits, no auto retries; stop after any failure. Operator strategy approval is recorded, but a **safe artifact/flash command cannot yet be specified or executed** because these inputs remain unbound.

## Engineering status

```text
A1W_HOST_BUILD=PASS_REAL
A1X_NEW_IMAGE_AND_TREE=PASS_REAL_16_OF_16
A1X_IMS_PLATFORM_SIGNER=PASS
A1X_COMPILED_IMS_SLOT1_SLOT2=PASS
HYBRID_SUPER_STRATEGY=USER_APPROVED_2026_10_14
HYBRID_SUPER_PREPACK_MATCHED_PARTITIONS=HOLD_UNBOUND_INPUTS
G1_A1X_SKIP_MOUNT_AND_FIRST_STAGE=OPEN
G2_A1X_SELECTED_IMS_PARTIAL_HOST_PASS
G3_SELECTED_VENDOR_NATIVE_NAMESPACE=OPEN
HYBRID_SUPER_ARTIFACT=NOT_BUILT_FOR_A1X
HYBRID_SUPER_DEVICE_WRITE=NOT_EXECUTED
FLASH_COMMAND=NOT_ADMITTED_PENDING_VERIFIED_ARTIFACT_AND_RESTORE
```
