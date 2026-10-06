# Titan 2 N1I-C2 Cellular MVP product delta.
#
# C2 inherits the complete C1 OEM IMS/JAR/config/SELinux island, then adds the
# frozen 33-native compatibility superset plus the Sable cellular integration
# package as one bounded candidate.

$(call inherit-product, vendor/sable/titan2/n1i-c1/sable-titan2-n1i-c1.mk)

PRODUCT_PACKAGES += \
    SableTitan2Cellular \
    SableTitan2CellularInit \
    SableTitan2CellularConfig \
    SableTitan2CellularMarker

# Generated at governed build time from the sealed C1 zero-presence probe
# plus the retained Kati ownership graph. It lists exactly 28 frozen native
# imports; five reviewed collision targets preserve their existing Android 16
# platform providers and therefore omit the Sable duplicate package.
$(call inherit-product, vendor/sable/titan2/n1i-c2/native-packages.mk)

# Enable the already-present Restless legacy incoming-call compatibility path
# for Titan 2 OEM IMS. No framework fork is introduced here.
PRODUCT_SYSTEM_PROPERTIES += \
    ro.telephony.block_binder_thread_on_incoming_calls=false
