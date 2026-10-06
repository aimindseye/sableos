# Titan 2 N1I-C2 Cellular MVP product delta.
#
# C2 inherits the complete C1 OEM IMS/JAR/config/SELinux island, then realizes
# the frozen 33-target native authority as 28 Sable imports plus five existing
# Android 16 platform providers, together with the Sable cellular integration
# package as one bounded candidate.

$(call inherit-product, vendor/sable/titan2/n1i-c1/sable-titan2-n1i-c1.mk)

PRODUCT_PACKAGES += \
    SableTitan2Cellular \
    SableTitan2CellularInit \
    SableTitan2CellularConfig \
    SableTitan2CellularMarker

# Exact Android 16 owners for the five reviewed Kati collision targets.
# Their duplicate Sable prebuilts are intentionally absent from Android.bp.
PRODUCT_PACKAGES += \
    android.hardware.radio-V4-ndk \
    android.hardware.graphics.common-V6-ndk \
    android.hardware.drm-V1-ndk \
    libheif \
    libsuspend

# Generated at governed build time from the sealed C1 zero-presence probe
# plus the retained Kati ownership graph. It lists exactly 28 frozen native
# imports; five reviewed collision targets preserve their existing Android 16
# platform providers and therefore omit the Sable duplicate package.
$(call inherit-product, vendor/sable/titan2/n1i-c2/native-packages.mk)

# Enable the already-present Restless legacy incoming-call compatibility path
# for Titan 2 OEM IMS. No framework fork is introduced here.
PRODUCT_SYSTEM_PROPERTIES += \
    ro.telephony.block_binder_thread_on_incoming_calls=false
