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
    SableTitan2CellularMarker \
    SableN1IC2NativeM007 \
    SableN1IC2NativeM008 \
    SableN1IC2NativeM009 \
    SableN1IC2NativeM010 \
    SableN1IC2NativeM011 \
    SableN1IC2NativeM012 \
    SableN1IC2NativeM013 \
    SableN1IC2NativeM014 \
    SableN1IC2NativeM015 \
    SableN1IC2NativeM016 \
    SableN1IC2NativeM017 \
    SableN1IC2NativeM018 \
    SableN1IC2NativeM019 \
    SableN1IC2NativeM020 \
    SableN1IC2NativeM021 \
    SableN1IC2NativeM022 \
    SableN1IC2NativeM023 \
    SableN1IC2NativeM024 \
    SableN1IC2NativeM025 \
    SableN1IC2NativeM026 \
    SableN1IC2NativeM027 \
    SableN1IC2NativeM028 \
    SableN1IC2NativeM029 \
    SableN1IC2NativeM030 \
    SableN1IC2NativeM031 \
    SableN1IC2NativeM032 \
    SableN1IC2NativeM033 \
    SableN1IC2NativeM034 \
    SableN1IC2NativeM035 \
    SableN1IC2NativeM036 \
    SableN1IC2NativeM037 \
    SableN1IC2NativeM038 \
    SableN1IC2NativeM039

# Enable the already-present Restless legacy incoming-call compatibility path
# for Titan 2 OEM IMS. No framework fork is introduced here.
PRODUCT_SYSTEM_PROPERTIES += \
    ro.telephony.block_binder_thread_on_incoming_calls=false
