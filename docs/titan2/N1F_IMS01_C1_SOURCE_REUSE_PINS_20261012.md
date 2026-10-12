# N1F embedded IMS-01 — reusable C1 source pins and exact next edit (2026-10-12)

Status: **TARGETED_SOURCE_REUSE_IDENTIFIED, ABI/BINARY ADMISSION PENDING**. This advances the [embedded island contract](N1F_OCT11_IMS01_EMBEDDED_ISLAND_CONTRACT_20261012.md) using **already-existing SableOS source**, rather than another broad evidence audit.

## Existing exact C1 build modules — confirmed on repository main

[`product/titan2/n1i-c1/Android.bp`](https://github.com/aimindseye/sableos/blob/main/product/titan2/n1i-c1/Android.bp) already defines:
- `android_app_import { name: "ImsService", apk: "prebuilt/system_ext/priv-app/ImsService/ImsService.apk", certificate: "platform", privileged: true, system_ext_specific: true, dex_preopt: {enabled: false} }`.
- `dex_import { name: "SableN1IC1MediatekCommon", jars: ["prebuilt/system_ext/framework/mediatek-common.jar"], stem: "mediatek-common", system_ext_specific: true }`.
- `dex_import { name: "SableN1IC1MediatekImsBase", jars: ["prebuilt/system_ext/framework/mediatek-ims-base.jar"], stem: "mediatek-ims-base", system_ext_specific: true }`.
- `prebuilt_etc` entries `SableN1IC1SystemExtPermissionsMediatek`, `SableN1IC1ImsSysconfig`, and `SableN1IC1PrivappPermissionsMediatek`.

**Do not reimplement these as new Make `PRODUCT_COPY_FILES` entries.** Reuse exact modules and the existing pinned C1 staging workflow after checking its installation and build-jar location overrides against the N1F-derived embedded `system_ext`. `system_ext_specific: true` itself does not prove the image's effective mount path. Existing C1 documentation recorded a bootclasspath configured-jar-location mistake; retain `PRODUCT_CONFIGURED_JAR_LOCATION_OVERRIDES` regression checks.

## Already authored telephony compatibility source

The existing patch [`patches/android-16-n1i-c1/telephony/0001-telephony-add-titan2-legacy-writeRilAnswer-overload.patch`](https://github.com/aimindseye/sableos/blob/main/patches/android-16-n1i-c1/telephony/0001-telephony-add-titan2-legacy-writeRilAnswer-overload.patch) adds **only** a no-op `writeRilAnswer(int phoneId, int rilSerial)` method to `frameworks/opt/telephony/src/java/com/android/internal/telephony/metrics/TelephonyMetrics.java`. The existing four-argument overload remains untouched.

The historical N1I-C2 mutation manifest retains exact **Git object IDs**, NOT filesystem SHA256 values:
```text
TELEPHONY_METRICS_BASE_GIT_BLOB=27638e5be9c008101c2f9b8f1e7a9af49d94f838
TELEPHONY_METRICS_POST_GIT_BLOB=9d5108e0ddb8d4960d21cda021813b53dbbf4da8
TELEPHONY_METRICS_PATCH_GIT_BLOB=ee353caded6dd07318991eb52d66687e06034c30
```
The previous exact-state rule is **base blob → apply patch; post blob → record already patched; any third blob → BLOCK**. Never apply the patch twice or assume the N1F source tree matches old C1.

## New R1 change — ownership identified; exact source not yet SHA-pinned

Target only `frameworks/base/core/res/AndroidManifest.xml` in the Android platform checkout selected for the derived N1F build. Proposed statement, if not already declared:
```xml
<protected-broadcast android:name="com.mediatek.common.carrierexpress.operator_config_changed" />
```
A negative duplicate check, source Git blob/SHA, platform manifest validation, and post-build `framework-res.apk` `aapt2 dump xmltree` are required. This is a platform manifest policy edit, not an IMS APK patch or generic receiver-policy relaxation.

## Staging path and stock mount decision

The October 11 running N1F system intentionally uses `/system/etc/init/config/skip_mount.cfg` to bypass standalone stock `system_ext_a`/`product_a`, exposing **embedded** `/system/system_ext`. Hence IMS01 APK, JAR and R2 .so copyout target that embedded image, not the separate offline R3 stock `system_ext.img`. Preserve skip_mount behavior. Use the selected image build's actual installation output for byte-level verification, not `system_ext_specific` nomenclature alone.

## Five R2 inputs — no more, no less

Use exact P0-AV stock bytes and hashes already frozen in [IMS01 contract](N1F_OCT11_IMS01_EMBEDDED_ISLAND_CONTRACT_20261012.md). Native file placement `/system/system_ext/lib64` is **proposed only** until five-library recursive `DT_NEEDED`, strong symbols, GNU versions, HIDL/NDK APEX providers and the IMS privileged-app linker namespace pass. A basic global library resolution is not enough. Reuse C2/B2 analyzers where they answer this exact question; do not revive the broad 33-import set.

## Follow-on minimal modification plan

1. Read the precise C1 `Android.bp`, product package inclusion/boot-JAR override and materialization contract from existing source; **record the original revision and exact staging artifacts**. Do not clone an entirely new IMS integration structure.
2. Bind N1F derived Android checkout `TelephonyMetrics.java` to one of the exact known Git blob states, and the platform manifest owner to a pinned blob. Preserve C3A/N1F substrate.
3. Validate only the five native candidates' *recursive loader reachability*, including potential `/vendor` private dependencies; a proven namespace mismatch blocks copyout.
4. Stage the exact minimal IMS APK + two JARs + 3 configuration XML files + necessary reviewed C1 SELinux and PHH gate with R1 and R2; **scope must be separately authorized**. Not all historical C1 implementation patches are automatically safe on this N1F parent.
5. Then incremental image build and sealed candidate, followed by independent flash authority. Radio recurrent disablement remains its own defect, not an IMS pass/fail proxy.

## Disposition

```text
IMS01_C1_EXISTING_MODULE_OWNERS=IDENTIFIED
IMS01_TELEPHONY_PATCH_FILE=IDENTIFIED
IMS01_TELEPHONY_EXACT_GIT_BLOB_PIN_MODEL=AVAILABLE
IMS01_EMBEDDED_INSTALL_MODEL=SELECTED
R1_PLATFORM_MANIFEST_OWNER=IDENTIFIED_BLOB_PENDING
R2_FIVE_NATIVE_IDENTITY=PASS_HISTORICAL
R2_RECURSIVE_LINKER_NAMESPACE=NOT_QUALIFIED
SOURCE_MUTATION_AUTHORIZED=NO
BUILD_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
```
