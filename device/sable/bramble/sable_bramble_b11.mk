$(call inherit-product, device/google/bramble/aosp_bramble.mk)

PRODUCT_NAME := sable_bramble_b11
PRODUCT_MODEL := SableOS B1.1 on bramble

PRODUCT_PACKAGES += \
    oxynoded \
    oxynoded_init_rc
