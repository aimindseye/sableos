# SableOS Titan 2 N1D C3 system-only GSI product.
#
# Keep inheritance ordered from generic AOSP/Graphene GSI base to release
# behavior, then Sable-owned compatibility and product deltas.
$(call inherit-product, $(SRC_TARGET_DIR)/product/generic_system_arm64.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/gsi_release.mk)
$(call inherit-product, vendor/sable/n1d/treble_compat.mk)
$(call inherit-product, vendor/sable/n1d/sable_n1d_product_delta.mk)

PRODUCT_NAME := sable_titan2_n1d_arm64
PRODUCT_DEVICE := mainline_arm64
PRODUCT_BRAND := SableOS
PRODUCT_MODEL := SableOS Titan 2 N1D
PRODUCT_MANUFACTURER := SableOS
