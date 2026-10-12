# October 11 Titan 2 — IMS-01 embedded OEM IMS island contract

Date 2026-10-12. Status: **TARGETED_STATIC_DESIGN; NOT BUILD OR FLASH AUTHORITY**. Supersedes the prerequisite wording in [minimal implementation specification](N1F_OCT11_MINIMAL_IMPLEMENTATION_SPEC_20261012.md).

## Root cause of apparent missing OEM IMS

Engineering feedback identifies `/system/etc/init/config/skip_mount.cfg` as deliberately suppressing mounting of physical `system_ext_a` (dm-2) and `product_a` (dm-1) on the flashed N1F-based runtime. Consequently `/system_ext -> /system/system_ext` and `/product -> /system/product` remain active. R8Q3 captures the live symlinks and R8R records the OEM APK missing at the checked live paths. **Do not repeat an APK hunt or propose placing IMS in stock standalone `system_ext.img`.** Preserve the actual `skip_mount.cfg` content, target image init import/order and mount-table corroboration as an acceptance gate; the complete contents of that file have not yet been pasted into this PR.

Offline R3 super can contain stock `system_ext.img` and `product.img` while runtime still uses embedded directories: presence in LP metadata is not mount visibility. **Do not delete or alter `skip_mount.cfg` to mount Android 14 stock partitions** as an IMS fix; boot compatibility of such a change is not qualified.

The WfcHandler protected-receiver and libmtk_vt_wrapper loader failures were seen on historical **D1R1 when OEM IMS was installed**; the Oct 11 N1F runtime's missing IMS package means those particular faults are proposed preventive corrections, not demonstrated live crashes in this Oct 11 runtime.

## IMS-01 exact minimal inclusion envelope

Target **embedded** `/system/system_ext` inside selected N1F-derived `system.img`, exposed at runtime under `/system_ext`. **Only these C1 island components are in the proposed initial implementation envelope**:

| ID | Exact scope | Required pre-implementation gate |
|---|---|---|
| IMS01-A | Stock `ImsService.apk`, exact pin, **platform-resigned** as previously qualified in C1 | Select platform cert/key identity, APK package/UID/service role and retained C1 staged APK hashes; do not copy third-party or mismatched signed APK |
| IMS01-B | `mediatek-common.jar` | Bind exact stock C1 import bytes, installed stem, configured bootclasspath location and runtime classpath |
| IMS01-C | `mediatek-ims-base.jar` | Same exact staged bytes, bootclasspath/uses-library placement and symbol compatibility |
| IMS01-D | Previously reviewed C1 `system_ext` SELinux/privapp rules | Confirm exact policy file ownership and merge; ensure no broad allow rules |
| IMS01-E | Exact `writeRilAnswer(II)V` framework/API compatibility correction | Bind callsite and implementing source owner/descriptor, no speculative Java method |
| IMS01-F | Existing PHH `mtkmal` gate marker | Bind prior gate semantics and source before applying; no unrelated property scripts |
| R1-01 | One platform `<protected-broadcast android:name="com.mediatek.common.carrierexpress.operator_config_changed" />` | Pin `frameworks/base/core/res/AndroidManifest.xml` at *actual selected source* revision; verify merged `framework-res.apk` with `aapt2 dump xmltree`; ensure no duplicate/broad action |
| R2-01 | Five existing SHA-256-pinned ViLTE ELF64 libraries | Destination embedded `/system/system_ext/lib64`; validate complete transitive DT_NEEDED, symbols, versions and privileged-app linker namespace before copyout |

### Excluded by default

- D1R2 seven-JAR or 33-native import set, `MtkTeleService.apk`, new unrelated radio/property overrides, AtlasOS watchdog/healing loops, unreviewed stock system_ext mount, and any changes to boot/vendor_boot/vbmeta/vendor firmware.
- No patch to `ImsService.apk` itself, no downgrade of Android receiver security, no workaround replacing system runtime libc/libdl/libm.
- No claims that completing IMS01 or R1/R2 will cure the **separate observed recurring radio disablement**.

## Order of work

1. **Task B closed in architecture, not yet in hash/manifest admission**: stop hunting `ImsService.apk` on N1F; admit a minimal embedded IMS island, with exact previously sealed C1 component refs. Preserve `skip_mount.cfg`; do not use physical stock system_ext copyout.
2. **Task A**: confirm single framework manifest owner and one-action platform fix, including compiled `framework-res.apk` effective manifest gate.
3. **Task C**: use the five exact pinned stock libraries; recursively resolve `DT_NEEDED`, strong UND, required symbol versions, HIDL `libhidlbase`/`libhidltransport`, NDK `libbinder_ndk`, APEX providers and permitted vendor-public libraries **from the IMS APK namespace**. Output six-column `dependency,provider,namespace,symbol_version,decision,evidence` TSV. Do not infer namespace access from physical existence.
4. **Task D remains held** until source/byte pins, exact C1 island merge and R1/R2 ABI/namespace checks pass. Only then produce a manifest-bounded patch and isolated incremental build with separate authorization.

## Acceptance status

```text
MILESTONE=M3_TO_M4_MINIMAL_PATCH_SPEC
REVIEW_FEEDBACK=SPECIFICATION_APPROVED
IMS01_PATH_MODEL=EMBEDDED_SYSTEM_SYSTEM_EXT
SKIP_MOUNT_CFG=OPERATOR_PREVIOUS_FINDING_RETAINED
STOCK_STANDALONE_SYSTEM_EXT_AS_TARGET=NO
IMS_APK_HUNT=STOP
IMS01_SOURCE_AND_BUILD_PINS=NOT_REBOUND
R1=PASS_STATIC_CANDIDATE
R2_FIVE_HASH_PINS=PASS_HISTORICAL
R2_RECURSIVE_SYMBOL_NAMESPACE=NOT_QUALIFIED
ADB_CELLULAR=TRANSIENT_DIAGNOSTIC_FAILURE
SOURCE_MUTATION_AUTHORIZED=NO
BUILD_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
```
