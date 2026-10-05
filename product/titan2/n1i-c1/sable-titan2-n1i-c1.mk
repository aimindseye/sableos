# Titan 2 N1I-C1 Android 16 cellular-isolation product delta.
#
# Registration/data remains the physically proven C3A behavior in the initial
# C1 image. This file adds only the dependency-closed V01.00.14 OEM IMS island.

PRODUCT_PACKAGES += \
    ImsService \
    mediatek-common \
    mediatek-ims-base

# Stock bootclasspath.pb places both MTK framework jars on system_ext.
PRODUCT_BOOT_JARS_EXTRA += \
    system_ext:mediatek-common \
    system_ext:mediatek-ims-base

# Narrow policy is generated locally from the pinned stock/C3A Android 16
# policy comparison by the canonical build driver.
SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += \
    vendor/sable/titan2/n1i-c1/sepolicy/system_ext/private

PRODUCT_COPY_FILES += \
    vendor/sable/titan2/n1i-c1/prebuilt/system_ext/lib64/vendor.mediatek.hardware.mtkradioex.se-V1-ndk.so:system_ext/lib64/vendor.mediatek.hardware.mtkradioex.se-V1-ndk.so \
    vendor/sable/titan2/n1i-c1/prebuilt/system/lib64/android.hardware.radio-V4-ndk.so:system/lib64/android.hardware.radio-V4-ndk.so \
    vendor/sable/titan2/n1i-c1/prebuilt/system_ext/lib64/vendor.mediatek.hardware.mtkradioex.rsu-V1-ndk.so:system_ext/lib64/vendor.mediatek.hardware.mtkradioex.rsu-V1-ndk.so \
    vendor/sable/titan2/n1i-c1/prebuilt/system_ext/lib64/vendor.mediatek.hardware.mtkradioex.sim-V1-ndk.so:system_ext/lib64/vendor.mediatek.hardware.mtkradioex.sim-V1-ndk.so \
    vendor/sable/titan2/n1i-c1/prebuilt/system_ext/lib64/vendor.mediatek.hardware.mtkradioex@3.0.so:system_ext/lib64/vendor.mediatek.hardware.mtkradioex@3.0.so \
    vendor/sable/titan2/n1i-c1/prebuilt/system_ext/lib64/android.hardware.radio@1.5.so:system_ext/lib64/android.hardware.radio@1.5.so \
    vendor/sable/titan2/n1i-c1/prebuilt/system_ext/lib64/libsignal.so:system_ext/lib64/libsignal.so \
    vendor/sable/titan2/n1i-c1/prebuilt/system_ext/lib64/libcompress.so:system_ext/lib64/libcompress.so \
    vendor/sable/titan2/n1i-c1/prebuilt/system_ext/lib64/libsource.so:system_ext/lib64/libsource.so \
    vendor/sable/titan2/n1i-c1/prebuilt/system_ext/lib64/libvcodec_cap.so:system_ext/lib64/libvcodec_cap.so \
    vendor/sable/titan2/n1i-c1/prebuilt/system/lib64/android.hardware.graphics.common-V6-ndk.so:system/lib64/android.hardware.graphics.common-V6-ndk.so \
    vendor/sable/titan2/n1i-c1/prebuilt/system_ext/lib64/libvcodec_capenc.so:system_ext/lib64/libvcodec_capenc.so \
    vendor/sable/titan2/n1i-c1/prebuilt/system_ext/lib64/libcomutils.so:system_ext/lib64/libcomutils.so \
    vendor/sable/titan2/n1i-c1/prebuilt/system_ext/lib64/libaudioutilmtk.so:system_ext/lib64/libaudioutilmtk.so \
    vendor/sable/titan2/n1i-c1/prebuilt/system_ext/lib64/libgpud_sys.so:system_ext/lib64/libgpud_sys.so \
    vendor/sable/titan2/n1i-c1/prebuilt/system_ext/lib64/libgralloc_extra_sys.so:system_ext/lib64/libgralloc_extra_sys.so \
    vendor/sable/titan2/n1i-c1/prebuilt/system_ext/lib64/libged_sys.so:system_ext/lib64/libged_sys.so \
    vendor/sable/titan2/n1i-c1/prebuilt/system_ext/lib64/libsf_cpupolicy.so:system_ext/lib64/libsf_cpupolicy.so \
    vendor/sable/titan2/n1i-c1/prebuilt/system_ext/lib64/libstagefright_mbrain.so:system_ext/lib64/libstagefright_mbrain.so \
    vendor/sable/titan2/n1i-c1/prebuilt/system_ext/lib64/libmtk_vt_wrapper.so:system_ext/lib64/libmtk_vt_wrapper.so \
    vendor/sable/titan2/n1i-c1/prebuilt/system_ext/lib64/vendor.mediatek.hardware.videotelephony-V1-ndk.so:system_ext/lib64/vendor.mediatek.hardware.videotelephony-V1-ndk.so \
    vendor/sable/titan2/n1i-c1/prebuilt/system_ext/lib64/vendor.mediatek.hardware.videotelephony@1.0.so:system_ext/lib64/vendor.mediatek.hardware.videotelephony@1.0.so \
    vendor/sable/titan2/n1i-c1/prebuilt/system/lib64/android.hardware.drm-V1-ndk.so:system/lib64/android.hardware.drm-V1-ndk.so \
    vendor/sable/titan2/n1i-c1/prebuilt/system_ext/lib64/libJpegOal.so:system_ext/lib64/libJpegOal.so \
    vendor/sable/titan2/n1i-c1/prebuilt/system_ext/lib64/libjpeg-alpha.so:system_ext/lib64/libjpeg-alpha.so \
    vendor/sable/titan2/n1i-c1/prebuilt/system_ext/lib64/libjpeg-alpha-oal.so:system_ext/lib64/libjpeg-alpha-oal.so \
    vendor/sable/titan2/n1i-c1/prebuilt/system_ext/lib64/vendor.mediatek.hardware.mms@1.3.so:system_ext/lib64/vendor.mediatek.hardware.mms@1.3.so \
    vendor/sable/titan2/n1i-c1/prebuilt/system_ext/lib64/vendor.mediatek.hardware.mms@1.2.so:system_ext/lib64/vendor.mediatek.hardware.mms@1.2.so \
    vendor/sable/titan2/n1i-c1/prebuilt/system_ext/lib64/vendor.mediatek.hardware.mms@1.1.so:system_ext/lib64/vendor.mediatek.hardware.mms@1.1.so \
    vendor/sable/titan2/n1i-c1/prebuilt/system_ext/lib64/vendor.mediatek.hardware.mms@1.0.so:system_ext/lib64/vendor.mediatek.hardware.mms@1.0.so \
    vendor/sable/titan2/n1i-c1/prebuilt/system_ext/lib64/vendor.mediatek.hardware.mbrain-V2-ndk.so:system_ext/lib64/vendor.mediatek.hardware.mbrain-V2-ndk.so \
    vendor/sable/titan2/n1i-c1/prebuilt/system/lib64/libheif.so:system/lib64/libheif.so \
    vendor/sable/titan2/n1i-c1/prebuilt/system/lib64/libsuspend.so:system/lib64/libsuspend.so \
    vendor/sable/titan2/n1i-c1/prebuilt/system_ext/etc/permissions/system-ext-permissions-mediatek.xml:system_ext/etc/permissions/system-ext-permissions-mediatek.xml \
    vendor/sable/titan2/n1i-c1/prebuilt/system_ext/etc/sysconfig/com.mediatek.ims.config.xml:system_ext/etc/sysconfig/com.mediatek.ims.config.xml \
    vendor/sable/titan2/n1i-c1/prebuilt/system/etc/permissions/privapp-permissions-mediatek.xml:system/etc/permissions/privapp-permissions-mediatek.xml

# Preserved V01.00.14 vendor already supplies the IMS feature declaration and
# vendor-side RadioEx/VoLTE/RCS dependencies; do not duplicate vendor payload.
