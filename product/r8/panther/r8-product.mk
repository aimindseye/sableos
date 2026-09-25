# SableOS R9 first-party application product integration.
#
# SableLauncher is the user-facing HOME application. Launcher3QuickStep remains
# installed only as the Android Quickstep/Recents substrate and must not be the
# HOME role holder.
#
# Sable first-party prebuilts below are staged into vendor/sable/r8/prebuilt
# by the fail-closed Panther integration script. AppStore is different: it is
# the upstream GrapheneOS module already pinned by the 2026081300 manifest at
# external/AppStore. It is included so users can choose optional applications,
# including sandboxed Google Play. Google Play itself is not preinstalled.

PRODUCT_PACKAGES += \
    SableSettingsPrivappPermissions \
    AppStore \
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
