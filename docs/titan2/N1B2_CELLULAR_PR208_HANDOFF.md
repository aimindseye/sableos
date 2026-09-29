# Titan 2 N1B2 cellular PR208 handoff

Status: PR208 restoration scaffold
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
proprietary payload binaries=no
```

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
PR208_PRODUCT_OR_IMAGE_MUTATION_IN_FIRST_PR=NO
```

## Runtime validation targets after a later image build

```text
dumpsys phone
dumpsys isub
dumpsys carrier_config
pm list packages -f | grep -Ei 'mtk|mediatek|tele|phone|carrier|ims|mms|stk'
logcat -b radio
```
