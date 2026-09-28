# Titan2 N1B2 product-profile implementation

Status: **N1B2 implementation helper**

This document records the first implementation step after the N1B first-boot
ledger and the N1B2 product-closure contract.

The successful N1B boot proved the Titan2 can boot the Android 16
Treble/RestlessOS-derived system image after explicit factory reset. N1B2 must
now turn that bootable substrate into a SableOS product candidate.

```text
N1B_FIRST_BOOT=PASS
FACTORY_RESET_REQUIRED=YES_CONFIRMED
N1B_PRODUCT_CLOSURE=FAIL
N1B2_PRODUCT_PROFILE_IMPLEMENTATION=YES
N1B2_FLASH_ALLOWED=NO_SEPARATE_GATE_REQUIRED
```

## Stage ownership

N1B2 remains in the Sable product-overlay lane.

```text
N0_B_TREBLE=RestlessOS_TrebleDroid_hardware_capable_baseline
N1_SABLE=SableOS_product_overlay_and_package_deltas
N2_TITAN2=physical_Titan2_validation
```

N1B2 must not mutate stock vendor, kernel, firmware, bootloader, or modem
payloads as part of product-identity closure.

```text
STOCK_VENDOR_STRATEGY=PRESERVE
STOCK_BOOT_VENDOR_BOOT_STRATEGY=PRESERVE
FIRMWARE_MUTATION=NO
BOOTLOADER_RELOCK_ALLOWED=NO
AVB_MUTATION_ALLOWED=NO_UNLESS_SEPARATE_REVIEW
PUBLIC_RELEASE_WITH_STOCK_BLOBS=NO_UNLESS_SEPARATE_LICENSE_REVIEW
```

## Implementation files

This PR adds two scripts:

```text
build/titan2/prepare-n1b2-product-profile.sh
build/titan2/collect-n1b2-postboot-acceptance.sh
```

`prepare-n1b2-product-profile.sh` is an Android-workspace preparation script. It
creates a Sable-owned N1B2 product profile under `vendor/sable/n1b2/` and, only
when explicitly requested, appends an `inherit-product-if-exists` line to a
provided active product makefile. It does not contact a device.

`collect-n1b2-postboot-acceptance.sh` is a read-only ADB evidence collector for
the future N1B2 boot after explicit factory reset. It records Setup Wizard,
product identity, HOME resolution, Titan2 input enumeration, display topology,
and a timed radio triage capture.

## Required N1B2 profile markers

The generated profile must carry these markers into the build/evidence path:

```text
N1B2_SETUP_WIZARD_REQUIRED=YES
N1B2_SETUP_WIZARD_REASON=factory_reset_required_for_first_boot
N1B2_SABLE_PRODUCT_IDENTITY_REQUIRED=YES
N1B2_SABLE_HOME_REQUIRED=YES
N1B2_TITAN2_INPUT_PROFILE_REQUIRED=YES
N1B2_MOBILE_NETWORK_TRIAGE_REQUIRED=YES
N1B2_FLASH_ALLOWED=NO_SEPARATE_GATE_REQUIRED
```

## Setup Wizard rule

N1B2 must include a setup path because the proven boot path requires an explicit
factory data reset.

```text
SETUP_WIZARD_INCLUDED=YES
SETUP_WIZARD_NOT_DISABLED_BY_DEFAULT=YES
SETUP_WIZARD_SURVIVES_FACTORY_RESET=YES
SETUP_WIZARD_PRIMARY_DISPLAY_USABLE=YES
SETUP_WIZARD_PHYSICAL_KEYBOARD_USABLE=YES
SETUP_WIZARD_MOBILE_NETWORK_STEP_DOES_NOT_DEAD_END=YES
```

The preparation script searches the Android tree for a setup module candidate.
The default candidate order is:

```text
SableSetupWizard
SetupWizard
Provision
```

If no setup module exists in the Android workspace, the profile preparation must
fail closed rather than silently building another already-provisioned generic
image.

## Sable identity and HOME rule

N1B2 must not keep the user-visible identity captured in N1B:

```text
DEVICE_NAME=TrebleDroid vanilla
HOME=com.android.launcher3/.uioverrides.QuickstepLauncher
SYSTEM_IDENTITY=google/treble_arm64_bvN/tdgsi_arm64_ab
```

N1B2 must target:

```text
DEVICE_NAME_TARGET=SableOS Titan2
VISIBLE_SETTINGS_BRAND_TARGET=SableOS
HOME_RESOLVES_TO_SABLE=YES
QUICKSTEP_ALLOWED_FOR_RECENTS=YES
QUICKSTEP_AS_PRIMARY_HOME=NO_UNLESS_EXPLICITLY_APPROVED
```

The preparation script defaults the Sable HOME module to `SableStart`; operators
may override it with `SABLE_HOME_MODULE=<module>` when the Android workspace uses
a different module name.

Missing Sable HOME is a hard blocker for an N1B2 candidate. The preparation
script must not report `N1B2_PRODUCT_PROFILE_PREPARED=PASS` when the HOME module
is absent.

```text
N1B2_SABLE_HOME_MODULE_PRESENT=YES_REQUIRED
N1B2_SABLE_HOME_MISSING_BEHAVIOR=FAIL_CLOSED
ALLOW_MISSING_SABLE_HOME=YES_INVESTIGATION_ONLY_NOT_CANDIDATE
```

If `SableStart` is missing, the next valid action is to import or generate a
buildable Sable HOME module in the Android workspace, not to ship with Quickstep
as primary HOME.

## Titan2 input rule

N1B2 must explicitly track Titan2 keyboard and touchPad behavior.

```text
TITANKEY_ENUMERATED=YES
TOUCHPAD_ENUMERATED=YES
TITAN2_KEYLAYOUT_REVIEWED=YES
TITAN2_KEYCHARMAP_REVIEWED=YES
GENERIC_KL_KCM_AS_FINAL_POLICY=NO
PHYSICAL_KEYBOARD_TEXT_ENTRY_SMOKE=PASS_REQUIRED
NAVIGATION_KEYS_SMOKE=PASS_REQUIRED
TOUCHPAD_POLICY=BOUNDED_AND_REVIEWED
```

The first N1B capture proved enumeration, not final policy. N1B2 must preserve
that evidence and add functional smoke checks after boot.

## Mobile-network triage rule

N1B showed LTE/5G could appear, and the telemetry recorded LTE HOME/data
transitions, but later state included out-of-service and emergency-only periods.
N1B2 therefore must not claim telephony stability from one visual state.

```text
MOBILE_NETWORK_STATUS=TRIAGE_REQUIRED
OPERATOR_BLOCKING_UNKNOWN=YES
IMAGE_OR_VENDOR_QUIRK_UNKNOWN=YES
LTE_HOME_SEEN=YES
LTE_DATA_CONNECTED_SEEN=YES
LTE_STABILITY_PASS=NO_UNTIL_TIMED_CAPTURE
IMS_PASS=NO_UNTIL_CALL_SMS_VOLTE_VOWIFI_TESTS
EMERGENCY_CALL_TESTING=NO
```

The post-boot collector performs a bounded timed capture. Default duration is ten
minutes, adjustable with `--duration-seconds` for local validation.

## Use of stock images on ai-g732

Stock images already present on ai-g732 may be used as private restore inputs or
as local packaging inputs if a gated N1B2 packaging path needs them. They must
not be committed to git or included in a public release without a separate
license review.

```text
STOCK_IMAGES_ON_AI_G732=AVAILABLE
PRIVATE_RESTORE_USE=YES
LOCAL_PACKAGING_USE=YES_IF_GATED
COMMIT_STOCK_IMAGES_TO_GIT=NO
COMMIT_EXTRACTED_PROPRIETARY_BINARIES=NO
PUBLIC_RELEASE_WITH_STOCK_BLOBS=NO_UNLESS_SEPARATE_LICENSE_REVIEW
```

## Non-goals

```text
DEVICE_CONTACT_DURING_PROFILE_PREP=NO
FLASH_AUTHORIZED_BY_PROFILE_PREP=NO
FACTORY_RESET_AUTHORIZED_BY_PROFILE_PREP=NO
AVB_MUTATION_AUTHORIZED_BY_PROFILE_PREP=NO
STOCK_VENDOR_REPACK_AUTHORIZED_BY_PROFILE_PREP=NO
PUBLIC_RELEASE_AUTHORIZED=NO
PRODUCTION_SIGNING_AUTHORIZED=NO
```

## Expected operator flow

After this PR is merged and CI passes, prepare the Android workspace profile:

```bash
bash build/titan2/prepare-n1b2-product-profile.sh \
  --android-root /srv/data/sable-build/workspaces/titan2-n0b-restless-native-android16-r7-seeded-public-skip-goodix-20260927_174816/treble_restlessos/src \
  --active-product-mk device/phh/treble/treble_arm64_bvN.mk \
  --patch-active-product
```

Then build N1B2 through the normal image-candidate path. Flashing N1B2 remains
blocked until a separate flash-readiness gate is reviewed.

After the future N1B2 flash and explicit factory reset, collect acceptance:

```bash
bash build/titan2/collect-n1b2-postboot-acceptance.sh \
  --serial TITAN20000006073 \
  --duration-seconds 600
```
