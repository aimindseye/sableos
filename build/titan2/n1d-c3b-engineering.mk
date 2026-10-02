# SableOS Titan 2 N1D C3B engineering reduction delta.
#
# Copied into device/phh/treble and inherited after base.mk by the pinned
# generator. This is not final Sable product composition; E2 owns Sable product
# identity and source-module admission.
#
# E1 deliberately starts with zero admitted Restless runtime patches and strips
# broad PHH runtime/control behavior. A removed compatibility mechanism can be
# re-admitted only from reproduced C3B failure evidence.

# Never bypass SELinux neverallow checks.
SELINUX_IGNORE_NEVERALLOWS := false

# Do not import the broad PHH private sepolicy or product overlay as accepted
# Sable runtime policy.
SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS := $(filter-out device/phh/treble/sepolicy,$(SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS))
PRODUCT_PACKAGE_OVERLAYS := $(filter-out device/phh/treble/overlay,$(PRODUCT_PACKAGE_OVERLAYS))

# Titan 2's first C3B engineering baseline does not pre-admit legacy VNDK
# compatibility payloads. Re-admit an exact version only if vendor/runtime
# evidence proves it is needed.
PRODUCT_EXTRA_VNDK_VERSIONS :=

# Remove PHH control, vendor-specific helpers, legacy partition tools and broad
# overlay packages inherited by the universal base.
PRODUCT_PACKAGES := $(filter-out     HardwareOverlayPicker     MtkInCallService     NoCutoutOverlay     NavigationBarMode2ButtonOverlay     QcRilAm     QtiAudio     TrebleApp     android.hardware.biometrics.fingerprint@2.1-service.oppo.compat     android.hardware.biometrics.fingerprint@2.1-service.oplus.compat     asus-motor     curl     evgrab     lightsctl     lightsctl-aidl     lptools     mtk-sms-fwk-ready     oneplus-motor     oplus-alert-slider     phh-ota     resetprop_phh     simg2img_simple     slsi-booted     treble-overlay-%     uevent     vr_hwc     xiaomi-motor     xiaomi-touch     ,$(PRODUCT_PACKAGES))

# Remove PHH mutation/init, legacy VNDK, OTA, remote-debug, TWRP/busybox and
# privileged TrebleApp configuration payloads inherited by base.mk.
PRODUCT_COPY_FILES := $(filter-out     device/phh/treble/adbd.rc:%     device/phh/treble/files/adbd.rc:%     device/phh/treble/files/ota.sh:%     device/phh/treble/ld.config.26.txt:%     device/phh/treble/phh-on-boot.sh:%     device/phh/treble/phh-on-data.sh:%     device/phh/treble/phh-prop-handler.sh:%     device/phh/treble/phh-securize.sh:%     device/phh/treble/privapp-permissions-me.phh.treble.app.xml:%     device/phh/treble/remote/%     device/phh/treble/remove-telephony.sh:%     device/phh/treble/rw-system.sh:%     device/phh/treble/sysconfig-me.phh.treble.app.xml:%     device/phh/treble/twrp/%     device/phh/treble/vndk-detect:%     device/phh/treble/vndk.rc:%     ,$(PRODUCT_COPY_FILES))

# PHH base enables unauthenticated adb and adb-by-default USB. C3B rejects both.
PRODUCT_SYSTEM_DEFAULT_PROPERTIES := $(filter-out     ro.adb.secure=%     persist.sys.usb.config=%     ,$(PRODUCT_SYSTEM_DEFAULT_PROPERTIES))
PRODUCT_SYSTEM_DEFAULT_PROPERTIES +=     ro.adb.secure=1

# Do not inherit PHH's optional-SetupWizard / generic large-screen product
# policy as Titan 2 product authority.
PRODUCT_PRODUCT_PROPERTIES := $(filter-out     ro.setupwizard.mode=%     persist.settings.large_screen_opt.enabled=%     ,$(PRODUCT_PRODUCT_PROPERTIES))
