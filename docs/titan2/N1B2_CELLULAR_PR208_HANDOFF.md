# Titan 2 N1B2 cellular PR208 handoff

Status: PR208 restoration implementation, package-verified; first physical validation failed boot due stock phone APK signature mismatch; N1B1 no-flash diagnosis shows AOSP telephony present but cellular registration failing
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

PR208 must not be APN-only, 5G-only, or a full vendor copy.

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
shared-UID stock APK boot loop. Therefore PR208 now splits the stock-derived
payload into boot-safe config, signature-blocked APKs, and conditional MTK/IMS
pieces. PR208 also adds an offline stock APK manifest/certificate classifier so
conditional items such as `ImsService.apk` are audited before any image build or
flash.

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
8. Keep stock shared-UID APKs, MTK framework JARs, IMS APK, and native IMS libraries excluded until the base AOSP telephony stack is proven and each conditional item has a consumer/signature/duplicate audit.

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

These are explicitly excluded from the image candidate because they can duplicate
GSI package names and/or declare privileged shared UIDs signed with the stock OEM
key rather than the GSI/platform key:

```text
system/priv-app/MtkMmsService/MtkMmsService.apk
system/priv-app/MtkTelecom/MtkTelecom.apk
system/priv-app/MtkTelephonyProvider/MtkTelephonyProvider.apk
system/priv-app/MtkTeleService/MtkTeleService.apk
```

Known physical failure:

```text
system/priv-app/MtkTeleService/MtkTeleService.apk
reason=BOOT_FATAL_SHARED_UID_SIGNATURE_MISMATCH
package=com.android.phone
shared_uid=android.uid.phone/1001
```

### Class C: conditional MTK/IMS payload

These are held out of the boot-safe image until N1B1/N1B2 proves that the
source-built AOSP phone stack is present and stable. Add back only one group at a
time after manifest/shared-UID, duplicate-library, and consumer audits:

```text
system_ext/priv-app/ImsService/ImsService.apk
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
`com.mediatek.ims`, but the package list from N1B1 does not show an installed
`com.mediatek.ims` implementation. That makes `system_ext/priv-app/ImsService`
a conditional candidate, but only after the stock APK audit confirms it has no
shared UID / duplicate AOSP package risk.

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
N1B2_MTK_PAYLOAD_STOCK_APKS_IN_BOOT_SAFE=NO
N1B2_MTK_PAYLOAD_STOCK_JARS_IN_BOOT_SAFE=NO
N1B2_MTK_PAYLOAD_STOCK_NATIVE_LIBS_IN_BOOT_SAFE=NO
N1B2_MTK_BUILD_PAYLOAD_PROFILE=BOOT_SAFE_CONFIG_ONLY
```

Current stock APK audit markers expected:

```text
N1B2_STOCK_APK_AUDIT=PASS
N1B2_STOCK_APK_AUDIT_BLOCKED_COUNT=4
N1B2_STOCK_APK_AUDIT_CONDITIONAL_COUNT=1
N1B2_STOCK_APK_AUDIT_IMSSERVICE_CLASS=CONDITIONAL
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

Use the MTK telephony wrapper for the implementation build:

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

## Runtime validation targets after flashing a verified image

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
NEXT_PR208_STEP=RUN_STOCK_APK_AUDIT_THEN_DECIDE_IF_IMSSERVICE_CAN_BE_ISOLATED_CONDITIONAL_TEST
```
