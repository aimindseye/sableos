#
# SableOS B1
#
# Base platform:
#   Google Pixel 4a 5G G025E
#   bramble
#   Android 12.1 / SQ3A.220705.003.A1
#
# B1 delta:
#   Package native Rust oxynoded into /system_ext/bin.
#

$(call inherit-product, device/google/bramble/aosp_bramble.mk)

PRODUCT_NAME := sable_bramble_b1
PRODUCT_MODEL := SableOS B1 on bramble

PRODUCT_PACKAGES += \
    oxynoded
