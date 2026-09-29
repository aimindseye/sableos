# Titan 2 N1B2 cellular PR208 handoff

Status: PR208 restoration implementation scaffold
Date: 2026-09-29

## Conclusion

Restless/Treble/Sable GSI is not sufficient by itself for Titan 2 cellular
stability. PR207 evidence points to a stock-derived MediaTek telephony/IMS
compatibility payload requirement layered on top of the Sable/Restless/Treble
GSI base.

PR208 must not be APN-only, 5G-only, or a full vendor copy.

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

PR208 now wires the stock-derived MTK telephony/IMS payload into the local N1B2
image build path without committing proprietary binaries:

1. Stage payload files from the local stock firmware tree.
2. Generate `vendor/sable/n1b2/mtk-telephony-payload/sable_n1b2_mtk_telephony_payload.mk` in the Android build tree.
3. Add that generated makefile to `vendor/sable/n1b2/sable_n1b2_product_profile.mk` using `inherit-product-if-exists`.
4. Build the N1B2 GSI with the existing `build-n1b2-image-candidate.sh` entrypoint.
5. Verify every expected MTK telephony/IMS payload file is present in target_files with matching SHA-256 values.

The flow does not modify flash scripts because the output remains the N1B2 GSI
system image / target_files artifact. Flash script changes are not required
unless a later artifact format or packaging contract changes.

## Initial stock-derived payload candidates

The first PR208 restoration candidate set is system/system_ext only:

```text
system/etc/permissions/privapp-permissions-mediatek.xml
system/etc/apns-conf.xml
system/priv-app/MtkMmsService/MtkMmsService.apk
system/priv-app/MtkTelecom/MtkTelecom.apk
system/priv-app/MtkTelephonyProvider/MtkTelephonyProvider.apk
system/priv-app/MtkTeleService/MtkTeleService.apk
system_ext/etc/sysconfig/com.mediatek.ims.config.xml
system_ext/framework/mediatek-carrier-config-manager.jar
system_ext/framework/mediatek-ims-base.jar
system_ext/framework/mediatek-ims-common.jar
system_ext/framework/mediatek-ims-extension-plugin.jar
system_ext/framework/mediatek-telecom-common.jar
system_ext/lib64/libimsma.so
system_ext/lib64/libimsma_adapt.so
system_ext/lib64/libimsma_rtp.so
system_ext/lib64/libimsma_socketwrapper.so
system_ext/priv-app/ImsService/ImsService.apk
```

First native dependency closure:

```text
system_ext/lib64/libsink.so
system_ext/lib64/libsource.so
system_ext/lib64/libvcodec_cap.so
system_ext/lib64/libcomutils.so
system_ext/lib64/libsignal.so
```

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
```

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

## Runtime validation targets after flashing a verified image

```text
dumpsys phone
dumpsys isub
dumpsys carrier_config
pm list packages -f | grep -Ei 'mtk|mediatek|tele|phone|carrier|ims|mms|stk'
logcat -b radio
```
