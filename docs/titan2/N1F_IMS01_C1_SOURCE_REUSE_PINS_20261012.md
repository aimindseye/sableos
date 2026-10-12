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

## 2026-10-12 N1F M3 host gate — exact observed results

The operator ran `n1f_m3_r1r2_targeted_gate_v1.py` on ai-g732 with no source mutation, build, network, device, mount or flash.

- Repository `HEAD=7120a783ed418f2bb60651ff70793c602b419f25`.
- R1 platform manifest source: `/srv/data/sable-build/workspaces/titan2-n1d/android/frameworks/base/core/res/AndroidManifest.xml`; filesystem SHA256 `2fe068aa663608ef5e21108d97ba95e9b3bfa0dfaaa7add982d3eb86b8af0e7c`, Git blob `a7675341e1575039845d09c64fa22006612cca4a`, protected action occurrence count 0; decision `CANDIDATE_ADD_ONE_ACTION`. Pin this baseline before editing; the script did not apply the edit.
- Five pinned R2 ELF files: all `PASS_IDENTITY_AND_DIRECT_NEEDED`. Bytes/direct NEEDED: `libmtk_vt_wrapper.so=101920/20`, `libvcodec_cap.so=103008/15`, `libvcodec_capenc.so=35432/6`, `vendor.mediatek.hardware.videotelephony@1.0.so=102424/8`, `vendor.mediatek.hardware.videotelephony-V1-ndk.so=68936/7`. Total 56 direct edges.
- Focused dependency watchpoints explicitly seen in direct edges: `libhidltransport.so`, `libion.so`, `libstagefright_omx_utils.so`, `android.hardware.graphics.bufferqueue@2.0.so`, `libbinder_ndk.so`, `android.hardware.common-V2-ndk.so`, `android.hardware.common.fmq-V1-ndk.so`. Each provider and its namespace is still `UNRESOLVED`; no absence, incompatibility or resolution claim yet.
- `R2_RECURSIVE_CLOSURE=NOT_QUALIFIED`, `R2_GNU_SYMBOL_VERSIONS=NOT_QUALIFIED`, `R2_IMS_CLASSLOADER_NAMESPACE=NOT_QUALIFIED`.
- Gate conclusion: `M3_RESULT=TARGETED_SOURCE_AND_ELF_INVENTORY_NOT_IMPLEMENTATION_ADMISSION`.

**Next constrained work:** resolve the 56 already captured DT_NEEDED edges against the *selected N1F image's* system/system_ext/APEX/vendor providers, then inspect strong undefined symbols and required symbol versions under the IMS app classloader namespace. Do not repeat the hash/ELF inventory. Record a six-column TSV (`dependency,provider,namespace,symbol_version,decision,evidence`) with no invented provider paths. R1 one-line change may be prepared as a separate reversible patch preview, but actual source mutation, build and flash remain unauthorized.

## 2026-10-12 R2 bounded provider resolution v2 — **not an ABI failure**

Operator's host-only `n1f_m3_r2_provider_resolution_v2.py` run reported `R2_EDGES=56`, `R2_RUNTIME_HITS=0`, `R2_STOCK_HITS=6`, `R2_UNRESOLVED=51`, `R2_TRANSITIVE_CLOSURE=NOT_QUALIFIED`, `R2_GNU_SYMBOL_VERSION=NOT_QUALIFIED`, `R2_IMS_NAMESPACE_REACHABILITY=NOT_QUALIFIED`, `R2_IMPLEMENTATION_ADMISSION=NO`. Crucially, `RUNTIME_ROOT=NOT_SUPPLIED`. This was a historical stock-reference lookup, **not** a scan of the N1F Android platform/APEX runtime; common names such as `libc.so`, `libbinder.so`, `libutils.so`, `libhidlbase.so` being unresolved **does not mean missing from the device**. Six stock hit *records* are not necessarily six unique edges, because a DT_NEEDED name can have several matching paths.

Specific retained candidates include `vendor.mediatek.hardware.videotelephony@1.0.so`, `vendor.mediatek.hardware.videotelephony-V1-ndk.so`, `libvcodec_cap.so`, `libvcodec_capenc.so` from the frozen five-set, and historical stock vendor `libhidltransport.so`. All are existence-only, not namespace-accessible or compatible. Next technical step is **not another missing-library list**: feed an actual previously extracted N1F Android system/APEX provider tree (if retained), retain selected image identity and precedence, then resolve only still-open edges with symbol-version and namespace checks. Do not mount/extract/flash merely to satisfy this document. Treat unmatched edges as `UNKNOWN_INPUT_COVERAGE` until those providers are furnished. The IMS-01 `skip_mount.cfg` embedded-system_ext rule and transient cellular diagnostic failure remain unchanged.
