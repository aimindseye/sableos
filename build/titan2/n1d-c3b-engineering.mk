# SableOS Titan 2 N1D C3B engineering delta.
#
# This file is copied into device/phh/treble and inherited by the pinned
# TrebleDroid generator after base.mk. It is deliberately a build/runtime
# reduction layer, not final Sable product composition. E2 owns Sable app and
# product admission.
#
# C3B begins from zero admitted Restless runtime patches. Remove broad PHH
# runtime/control features and known insecure defaults before the first
# engineering compile. Re-admit only from reproduced failure evidence.

# Never bypass SELinux neverallow checks in C3B.
SELINUX_IGNORE_NEVERALLOWS := false

# Remove privileged/control and non-Titan runtime packages inherited by the
# generic PHH base. Static hardware overlays are also excluded by default;
# Titan-specific overlays require evidence and explicit admission.
PRODUCT_PACKAGES := $(filter-out     HardwareOverlayPicker     MtkInCallService     QcRilAm     QtiAudio     TrebleApp     mtk-sms-fwk-ready     phh-ota     resetprop_phh     treble-overlay-%     ,$(PRODUCT_PACKAGES))

# Remove PHH mutation, OTA, remote-debug, TWRP/busybox and privileged TrebleApp
# configuration payloads inherited by base.mk.
PRODUCT_COPY_FILES := $(filter-out     device/phh/treble/rw-system.sh:%     device/phh/treble/phh-on-boot.sh:%     device/phh/treble/phh-on-data.sh:%     device/phh/treble/phh-prop-handler.sh:%     device/phh/treble/phh-securize.sh:%     device/phh/treble/files/ota.sh:%     device/phh/treble/remove-telephony.sh:%     device/phh/treble/remote/%     device/phh/treble/twrp/%     device/phh/treble/privapp-permissions-me.phh.treble.app.xml:%     device/phh/treble/sysconfig-me.phh.treble.app.xml:%     ,$(PRODUCT_COPY_FILES))

# PHH base enables unauthenticated adb and adb-by-default USB. C3B rejects both.
PRODUCT_SYSTEM_DEFAULT_PROPERTIES := $(filter-out     ro.adb.secure=%     persist.sys.usb.config=%     ,$(PRODUCT_SYSTEM_DEFAULT_PROPERTIES))
PRODUCT_SYSTEM_DEFAULT_PROPERTIES +=     ro.adb.secure=1
