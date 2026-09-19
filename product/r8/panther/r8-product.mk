# SableOS R8 first-party application product integration.
#
# SableStart is source-built by Soong. The remaining apps are standalone
# qualified APKs staged into vendor/sable/r8/prebuilt by the fail-closed
# Panther integration script.

PRODUCT_PACKAGES += \
    SableStart \
    SableCalculator \
    SableSudoku \
    SableMinesweeper \
    Sable2048 \
    SableMedia \
    SableReader
