# Titan 2 N1B2 cellular PR208 handoff

Status: PR208 restoration implementation, package-verified; first physical validation failed boot due stock phone APK signature mismatch; N1B1 no-flash diagnosis shows AOSP telephony present but cellular registration failing; stock telephony APK audit blocks all stock APK candidates
Date: 2026-09-29

## Conclusion

Restless/Treble/Sable GSI is not sufficient by itself for Titan 2 cellular
stability. Initial PR207/N1B1 evidence appeared to point to an Android framework
telephony gap. Follow-up no-flash diagnosis on the recovered N1B/N1B1 image
proved the core AOSP telephony stack is present: `phone`, `isub`,
`carrier_config`, SIM subscription loading, and Telecom phone account
registration are available.

The remaining N1B1 cellular failure is therefore not simply missing TeleService.
It is a vendor radio / MediaTek framework add-on / IMS-registration compatibility
problem: the SIM loads, T-Mobile/310240 is identified, vendor RIL initializes,
AOSP radio AIDL services and MTK radio extension services are present, but the
network remains IWLAN/no cellular operator registration.

PR208 must not be APN-only, 5G-only, a stock APK transplant, or a full vendor
copy.

The first package-verified PR208 image proved that blindly adding stock MTK
telephony APKs is not runtime-safe. Physical validation at
`/srv/data/sable-build/evidence/titan2/n1b2-mtk-telephony-physical/20260929T205519Z`
booted only to animation. `system_server` crashed during PackageManager system
app scan with:

```text
java.lang.IllegalStateException: Signature mismatch on system package com.android.phone for shared user android.uid.phone/1001
```

Build-engineering review agreed that the stock `MtkTeleService.apk` cannot be
imported as-is. It also warned that removing only that APK may expose the next
shared-UID stock APK boot loop. The offline stock APK audit then confirmed all
five stock telephony/IMS APK candidates are blocked because they duplicate AOSP
phone/telecom/telephony packages or declare `android.uid.phone` / `android.uid.system`.

Therefore the PR208 stock APK path is closed. The PR remains useful as a
classified evidence/build-wiring branch, but the next cellular fix must come from
source-built compatibility, product configuration, overlays, SEPolicy/service
contexts, or a signing-compatible MTK framework add-on path — not stock APK
prebuilts.

## Source boundary

Source stock firmware reference:

```text
STOCK_REFERENCE=2026041315_g71v78c2k_dfl_eea
STOCK_ROLE=KNOWN_GOOD_REFERENCE
```

Do not commit proprietary APK/JAR/SO payloads to Git.

PR208 may commit:

```text
scripts=yes
docs=yes
hash manifests=yes
gates=yes
product build wiring scripts=yes
proprietary payload binaries=no
```

## Implemented PR208 flow

PR208 wires a classified stock-derived payload into the local N1B2 image build
path without committing proprietary binaries:

1. Stage boot-safe payload files from the local stock firmware tree.
2. Emit an excluded-payload report for signature-blocked and conditional MTK/IMS pieces.
3. Audit stock telephony APK manifests/certificates before any conditional APK can be considered.
4. Generate `vendor/sable/n1b2/mtk-telephony-payload/sable_n1b2_mtk_telephony_payload.mk` in the Android build tree.
5. Add that generated makefile to `vendor/sable/n1b2/sable_n1b2_product_profile.mk` using `inherit-product-if-exists`.
6. Build the N1B2 GSI with the existing `build-n1b2-image-candidate.sh` entrypoint.
7. Verify every staged boot-safe payload file is present in target_files with matching SHA-256 values.
8. Keep stock shared-UID APKs, MTK framework JARs, and native IMS libraries excluded until a source-built/signing-compatible consumer path exists.

The flow does not modify flash scripts because the output remains the N1B2 GSI
system image / target_files artifact. Flash script changes are not required
unless a later artifact format or packaging contract changes.

## PR208 payload classes

### Class A: boot-safe config-only payload

These are the only files currently staged into the image candidate:

```text
system/etc/apns-conf.xml
system/etc/permissions/privapp-permissions-mediatek.xml
system_ext/etc/sysconfig/com.mediatek.ims.config.xml
```

### Class B: signature-blocked stock APKs

These are explicitly excluded from the image candidate because they duplicate GSI
package names and/or declare privileged shared UIDs signed with the stock OEM key
rather than the GSI/platform key:

```text
system/priv-app/MtkMmsService/MtkMmsService.apk
package=com.android.mms.service
shared_uid=android.uid.phone
reason=DUPLICATES_COM_ANDROID_MMS_SERVICE_EXPECTED_SHARED_UID_PHONE

system/priv-app/MtkTelecom/MtkTelecom.apk
package=com.android.server.telecom
shared_uid=android.uid.system
reason=DUPLICATES_COM_ANDROID_SERVER_TELECOM_EXPECTED_SYSTEM_SIGNATURE_SPACE

system/priv-app/MtkTelephonyProvider/MtkTelephonyProvider.apk
package=com.android.providers.telephony
shared_uid=android.uid.phone
reason=DUPLICATES_COM_ANDROID_PROVIDERS_TELEPHONY_EXPECTED_SHARED_UID_PHONE

system/priv-app/MtkTeleService/MtkTeleService.apk
package=com.android.phone
shared_uid=android.uid.phone
reason=BOOT_FATAL_DUPLICATES_COM_ANDROID_PHONE_SHARED_UID_ANDROID_UID_PHONE

system_ext/priv-app/ImsService/ImsService.apk
package=com.mediatek.ims
shared_uid=android.uid.phone
reason=DECLARES_SHARED_USER_ID_android.uid.phone
```

Known physical failure:

```text
system/priv-app/MtkTeleService/MtkTeleService.apk
reason=BOOT_FATAL_SHARED_UID_SIGNATURE_MISMATCH
package=com.android.phone
shared_uid=android.uid.phone/1001
```

### Class C: conditional non-APK MTK/IMS payload

These are held out of the boot-safe image until there is a source-built or
signing-compatible consumer path. Add back only one group at a time after
manifest/shared-UID, duplicate-library, classpath, and runtime consumer audits:

```text
system_ext/framework/mediatek-carrier-config-manager.jar
system_ext/framework/mediatek-ims-base.jar
system_ext/framework/mediatek-ims-common.jar
system_ext/framework/mediatek-ims-extension-plugin.jar
system_ext/framework/mediatek-telecom-common.jar
system_ext/lib64/libimsma.so
system_ext/lib64/libimsma_adapt.so
system_ext/lib64/libimsma_rtp.so
system_ext/lib64/libimsma_socketwrapper.so
system_ext/lib64/libsink.so
system_ext/lib64/libsource.so
system_ext/lib64/libvcodec_cap.so
system_ext/lib64/libcomutils.so
system_ext/lib64/libsignal.so
```

## Current no-flash diagnosis

Recovered N1B/N1B1 evidence shows:

```text
AOSP_TELESERVICE_PRESENT=YES
PHONE_SERVICE_PRESENT=YES
ISUB_SERVICE_PRESENT=YES
CARRIER_CONFIG_PRESENT=YES
SIM_SLOT_1_STATE=LOADED
SIM_SLOT_1_MCCMNC=310240
CARRIER=T-Mobile
AOSP_RADIO_AIDL_SERVICES_PRESENT=YES
MTK_RADIO_EXTENSION_SERVICES_PRESENT=YES
MTK_IMS_TELEPHONY_OVERLAY_ENABLED=YES
CELLULAR_OPERATOR_REGISTRATION=FAIL_EMPTY_OPERATOR_NUMERIC
NETWORK_TYPE=IWLAN,IWLAN
```

Important runtime clues:

```text
RILC: isMtkFwkAddonNotExisted(1) -1
RilOpProxy: dlopen failed: library "libmtkmipc-rilop.so" not found
```

The enabled PHH MTK IMS overlay maps AOSP `TeleService` IMS MMTEL config to
`com.mediatek.ims`, but the stock `com.mediatek.ims` APK declares
`android.uid.phone`; it is not safe to add as a prebuilt into the GSI image.

## Required PR208 markers

```text
PR208_PROPRIETARY_PAYLOAD_COMMITTED=NO
PR208_VENDOR_PARTITION_COPY=NO
PR208_FULL_VENDOR_COPY=NO
PR208_PAYLOAD_HASH_GATE=YES
PR208_LOCAL_STOCK_INPUT_REQUIRED=YES
PR208_SYSTEM_EXT_MTK_IMS_PAYLOAD=YES
PR208_PRODUCT_COPY_FILES_WIRING=YES
PR208_BUILD_WIRING=YES
PR208_IMAGE_PAYLOAD_VERIFICATION=YES
PR208_FLASH_SCRIPT_MUTATION=NO_NOT_REQUIRED
PR208_STOCK_APK_AUDIT=YES
```

Current payload markers expected from staging/build:

```text
N1B2_MTK_PAYLOAD_PROFILE=BOOT_SAFE_CONFIG_ONLY
N1B2_MTK_PAYLOAD_PRESENT_COUNT=3
N1B2_MTK_PAYLOAD_EXCLUDED_SIGNATURE_BLOCKED_COUNT=5
N1B2_MTK_PAYLOAD_EXCLUDED_CONDITIONAL_COUNT=14
N1B2_MTK_PAYLOAD_STOCK_APKS_IN_BOOT_SAFE=NO
N1B2_MTK_PAYLOAD_STOCK_JARS_IN_BOOT_SAFE=NO
N1B2_MTK_PAYLOAD_STOCK_NATIVE_LIBS_IN_BOOT_SAFE=NO
N1B2_MTK_BUILD_PAYLOAD_PROFILE=BOOT_SAFE_CONFIG_ONLY
```

Current stock APK audit markers expected:

```text
N1B2_STOCK_APK_AUDIT=PASS
N1B2_STOCK_APK_AUDIT_CHECKED_COUNT=5
N1B2_STOCK_APK_AUDIT_MISSING_COUNT=0
N1B2_STOCK_APK_AUDIT_BLOCKED_COUNT=5
N1B2_STOCK_APK_AUDIT_CONDITIONAL_COUNT=0
N1B2_STOCK_APK_AUDIT_PARSE_FAILURES=0
N1B2_STOCK_APK_AUDIT_IMSSERVICE_CLASS=BLOCKED
N1B2_STOCK_APK_AUDIT_IMSSERVICE_REASON=DECLARES_SHARED_USER_ID_android.uid.phone
N1B2_STOCK_APK_AUDIT_SAFE_CONDITIONAL_APKS=NO
N1B2_STOCK_APK_AUDIT_RESULT=PASS
```

## Stock APK audit entrypoint

Run the offline APK audit before any conditional APK is added to the image:

```bash
bash build/titan2/audit-n1b2-stock-telephony-apks.sh \
  --stock-root <stock-2026041315-root> \
  --android-src <android-src> \
  --evidence-dir <evidence-dir>
```

The audit uses `aapt2` to read `AndroidManifest.xml` and optionally uses
`apksigner` to record certificate digests. It does not use adb, fastboot, image
builds, or source mutation.

## Build entrypoint

Use the MTK telephony wrapper only for the boot-safe config-only image candidate:

```bash
bash build/titan2/build-n1b2-image-candidate-with-mtk-telephony.sh \
  --android-src <android-src> \
  --stock-root <stock-2026041315-root> \
  --full-ci-evidence-dir <full-local-ci-evidence-dir> \
  --out-dir <out-dir> \
  --jobs <n>
```

## Required no-flash N1B1 diagnosis before next physical PR208 run

The recovered N1B/N1B1 image boots. Before flashing another PR208 image, capture
whether the source-built AOSP telephony stack is installed and stable:

```text
pm list packages -f | grep -Ei 'com.android.phone|providers.telephony|carrier|telecom|mms|stk'
dumpsys phone
dumpsys isub
dumpsys carrier_config
logcat crash/signature scan for com.android.phone / PhoneApp / TeleService
```

If AOSP `com.android.phone` is missing, fix product inheritance/package inclusion
before layering MTK components. If it is installed but crash-looping, diagnose the
crash before layering stock payload.

## Runtime validation targets after flashing a verified boot-safe image

```text
dumpsys phone
dumpsys isub
dumpsys carrier_config
pm list packages -f | grep -Ei 'mtk|mediatek|tele|phone|carrier|ims|mms|stk'
logcat -b radio
```

## Current physical validation status

```text
FIRST_PR208_PHYSICAL_FLASH=PASS
FIRST_PR208_BOOT_RESULT=FAIL_BOOT_ANIMATION_STUCK
FIRST_PR208_FAILURE_CAUSE=BOOT_FATAL_SHARED_UID_SIGNATURE_MISMATCH_ON_COM_ANDROID_PHONE
ROLLBACK_TO_N1B1=PASS
N1B1_AOSP_TELEPHONY_PRESENT=YES
N1B1_RADIO_REGISTRATION=FAIL
N1B1_MTK_IMS_OVERLAY_ENABLED=YES
STOCK_APK_AUDIT_RESULT=ALL_STOCK_TELEPHONY_APKS_BLOCKED
NEXT_PR208_CANDIDATE=BOOT_SAFE_CONFIG_ONLY_EVIDENCE_ARTIFACT_ONLY
NEXT_CELLULAR_FIX_DIRECTION=SOURCE_BUILT_OR_CONFIGURED_MTK_COMPATIBILITY_LAYER_NOT_STOCK_APKS
```
