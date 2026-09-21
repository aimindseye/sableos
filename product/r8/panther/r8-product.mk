# SableOS R8 first-party application product integration.
#
# Launcher3QuickStep is supplied by the GrapheneOS platform product and patched
# in-place to host the Sable Start presentation. The standalone SableStart APK
# was retired in R9L8 so exactly one HOME implementation remains.
#
# The modules below are standalone qualified APKs staged into
# vendor/sable/r8/prebuilt by the fail-closed Panther integration script.

PRODUCT_PACKAGES += \
    SableCalculator \
    SableSudoku \
    SableMinesweeper \
    Sable2048 \
    SableMedia \
    SableReader \
    SableHub \
    SableMail \
    SableWeather \
    SableCalendar
