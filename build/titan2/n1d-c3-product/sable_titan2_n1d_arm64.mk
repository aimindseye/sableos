# SableOS Titan 2 N1D C3 system-only GSI product.
#
# Keep inheritance ordered from generic AOSP/Graphene system base to release
# behavior, then Sable-owned compatibility and product deltas.
$(call inherit-product, $(SRC_TARGET_DIR)/product/generic_system_arm64.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/gsi_release.mk)

# GrapheneOS intentionally omits several AOSP sample/application repositories
# referenced by build/make's Soong-defined GSI image modules. Keep the Make-side
# GSI release settings above, but make the Soong gsi.building_gsi selector false.
# BoardConfigGsiCommon uses ifdef BUILDING_GSI, so the non-empty value "false"
# still preserves its GSI board configuration.
BUILDING_GSI := false

$(call inherit-product, vendor/sable/n1d/treble_compat.mk)
$(call inherit-product, vendor/sable/n1d/sable_n1d_product_delta.mk)

PRODUCT_NAME := sable_titan2_n1d_arm64
PRODUCT_DEVICE := gsi_arm64
PRODUCT_BRAND := SableOS
PRODUCT_MODEL := SableOS Titan 2 N1D
PRODUCT_MANUFACTURER := SableOS
