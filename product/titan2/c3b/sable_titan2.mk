# SableOS Titan 2 C3B E2 thin-wrapper product.
#
# Preserve the proven E1 generated Treble product graph. This wrapper must not
# directly inherit generic_system_arm64, gsi_release, PHH base.mk, or the retired
# vendor/sable/n1d product.

$(call inherit-product, device/phh/treble/treble_arm64_bvN.mk)
$(call inherit-product, vendor/sable/titan2/sable-titan2-apps.mk)

PRODUCT_NAME := sable_titan2
PRODUCT_DEVICE := tdgsi_arm64_ab
PRODUCT_BRAND := SableOS
PRODUCT_MODEL := SableOS Titan 2
PRODUCT_MANUFACTURER := SableOS
