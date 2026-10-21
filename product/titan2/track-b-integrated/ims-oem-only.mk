# TB2 OEM-only IMS source slice. Avoids pulling the retired C3B RadioDiag/app set.
# Keep original C1 classpath and SEPolicy directives verbatim below.
# Titan 2 N1I-C1 Android 16 cellular-isolation delta.
# Preserve N1F, then add only the explicitly admitted OEM IMS island.
#
# No stock native .so is admitted in the first C1 candidate. N1I-B2 replaced
# the N1I-A keyword heuristic for native dependency admission.

PRODUCT_PACKAGES += \
    ImsService \
    SableN1IC1MediatekCommon \
    SableN1IC1MediatekImsBase \
    SableN1IC1SystemExtPermissionsMediatek \
    SableN1IC1ImsSysconfig \
    SableN1IC1PrivappPermissionsMediatek

PRODUCT_BOOT_JARS_EXTRA += \
    system_ext:SableN1IC1MediatekCommon \
    system_ext:SableN1IC1MediatekImsBase

# PRODUCT_BOOT_JARS uses module names, while these dex_import modules install
# stock-compatible stems. Tell Soong the exact on-device bootclasspath names.
PRODUCT_CONFIGURED_JAR_LOCATION_OVERRIDES += \
    system_ext:SableN1IC1MediatekCommon:system_ext:mediatek-common \
    system_ext:SableN1IC1MediatekImsBase:system_ext:mediatek-ims-base

SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += \
    vendor/sable/titan2/n1i-c1/sepolicy/system_ext/private
