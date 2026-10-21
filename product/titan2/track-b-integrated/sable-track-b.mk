# Titan2 Track B A16 product delta. Generated AOSP prebuilt modules come
# from the single canonical Sable full CI run (not detached Gradle snapshots).
# No stock telephony, default IME/SMS role, or flash policy is overridden.
PRODUCT_PACKAGES += \
    SableLauncher \
    SableTB2Keyboard \
    SableTB2Camera \
    SableTB2DisplayCompat \
    SableTB2Setup \
    SableTB2Tools \
    SableTB2Calculator \
    SableTB2Media \
    SableTB2Hub \
    SableTB2Weather \
    SableTB2Calendar \
    SableTB2Reader \
    SableTB2Mail \
    SableTB2TextReader

# Exactly one explicitly admitted IMS provider must have been chosen by the
# Sable source stage and its *actual* selected AOSP product inherited below.
# Presence here never substitutes for G1/G2/G3 or live IMS verification.
ifeq ($(strip $(SABLE_TB2_IMS_PROVIDER)),OEM)
$(call inherit-product, vendor/sable/trackb/ims-oem-only.mk)
else ifeq ($(strip $(SABLE_TB2_IMS_PROVIDER)),FLOSS)
$(call inherit-product, vendor/sable/trackb13ims/selected-provider.mk)
else
$(error TB2_IMS_PROVIDER_UNSELECTED_OR_INVALID)
endif
