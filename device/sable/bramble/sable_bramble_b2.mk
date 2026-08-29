$(call inherit-product, device/google/bramble/aosp_bramble.mk)

PRODUCT_NAME := sable_bramble_b2
PRODUCT_MODEL := SableOS B2 on bramble

PRODUCT_PACKAGES += \
    oxynoded \
    oxynoded_init_rc
