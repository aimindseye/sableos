# SableOS R9 first-party application product integration.
#
# SableLauncher is the user-facing HOME application. Launcher3QuickStep remains
# installed only as the Android Quickstep/Recents substrate and must not be the
# HOME role holder.
#
# The prebuilt modules below are standalone qualified APKs staged into
# vendor/sable/r8/prebuilt by the fail-closed Panther integration script.

PRODUCT_PACKAGES += \
    SableLauncher \
    SableCalculator \
    SableSudoku \
    SableMinesweeper \
    Sable2048 \
    SableMedia \
    SableTextReader \
    SableReader \
    SableHub \
    SableMail \
    SableWeather \
    SableCalendar
