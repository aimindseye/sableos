# Titan2 N1B2 product-closure requirements

Status: **N1B2 prebuild contract**

This document records the required scope for the next Titan2 build after the
first N1B system-image boot.

N1B proved that the Titan2 can boot the Android 16 Treble/RestlessOS-derived
system image when the deployment path is:

```text
fastbootd verified
snapshot-update-status=none
stale active-slot COW logical partitions removed
system_a resized
system_a flashed
factory data reset explicitly approved and performed
```

N1B also proved that the booted image is not yet a SableOS Titan2 product image.
N1B2 must fix product closure before any new flash is considered successful.

## Evidence basis

Current evidence:

```text
FIRST_N1B_BOOT=PASS
BOOT_COMPLETED=PASS
FACTORY_RESET_REQUIRED=YES_CONFIRMED
ACTIVE_SLOT=_a
VERIFIED_BOOT_STATE=orange
STOCK_VENDOR_BASELINE=PRESENT
SYSTEM_IDENTITY=google/treble_arm64_bvN/tdgsi_arm64_ab
DEVICE_NAME=TrebleDroid vanilla
HOME=com.android.launcher3/.uioverrides.QuickstepLauncher
TITANKEY_ENUMERATED=PASS
TOUCHPAD_ENUMERATED=PASS
PRIMARY_DISPLAY=1440x1440
REAR_DISPLAY=410x502
MOBILE_NETWORK=PARTIAL_UNSTABLE
```

## N1B2 mandatory product changes

N1B2 must include the following before an image is accepted as an N1B2 build
candidate.

```text
N1B2_SETUP_WIZARD_REQUIRED=YES
N1B2_SETUP_WIZARD_REASON=factory_reset_required_for_first_boot
N1B2_SABLE_PRODUCT_IDENTITY_REQUIRED=YES
N1B2_SABLE_HOME_REQUIRED=YES
N1B2_TITAN2_INPUT_PROFILE_REQUIRED=YES
N1B2_MOBILE_NETWORK_TRIAGE_REQUIRED=YES
N1B2_FLASH_ALLOWED=NO_SEPARATE_GATE_REQUIRED
```

### Setup Wizard

Because the proven first-boot path requires a factory data reset, N1B2 must not
boot into an already-complete generic TrebleDroid user state. It must include a
setup wizard path that is usable on Titan2's square primary display and physical
keyboard.

Required checks:

```text
SETUP_WIZARD_INCLUDED=YES
SETUP_WIZARD_NOT_DISABLED_BY_DEFAULT=YES
SETUP_WIZARD_SURVIVES_FACTORY_RESET=YES
SETUP_WIZARD_PRIMARY_DISPLAY_USABLE=YES
SETUP_WIZARD_PHYSICAL_KEYBOARD_USABLE=YES
SETUP_WIZARD_WIFI_STEP_USABLE=YES_OR_EXPLICITLY_SKIPPABLE
SETUP_WIZARD_MOBILE_NETWORK_STEP_DOES_NOT_DEAD_END=YES
SETUP_WIZARD_COMPLETION_RECORDED=YES
```

N1B2 must not claim setup success only because Settings is reachable after an
already-completed user state. The acceptance evidence must be collected after a
fresh factory reset.

### Sable product identity

N1B2 must remove visible generic substrate identity from user-facing surfaces
where Sable owns the product.

Required checks:

```text
DEVICE_NAME=SableOS Titan2 OR approved SableOS Titan 2 label
VISIBLE_SETTINGS_BRAND=SableOS
RESTLESSOS_USER_VISIBLE_BRANDING_REMOVED_OR_BOUNDED=YES
TREBLEDROID_USER_VISIBLE_BRANDING_REMOVED_OR_BOUNDED=YES
PHH_USER_VISIBLE_CONTROL_SURFACES_HIDDEN_OR_BOUNDARY_REVIEWED=YES
GRAPHENE_PLACEHOLDER_UI_REMOVED_OR_BOUNDARY_REVIEWED=YES
VANADIUM_NOT_SHOWN_AS_CHROME=YES
```

The vendor fingerprint may remain stock Unihertz because N1B2 is still a GSI /
stock-vendor portability lane. The system image identity must not remain a
generic TrebleDroid product identity in user-visible surfaces.

### HOME and launcher

N1B booted with Launcher3/Quickstep as HOME. N1B2 must make the intended Sable
launcher/HOME path explicit.

Required checks:

```text
HOME_RESOLVES_TO_SABLE=YES
QUICKSTEP_ALLOWED_FOR_RECENTS=YES
QUICKSTEP_AS_PRIMARY_HOME=NO_UNLESS_EXPLICITLY_APPROVED
ALL_APPS_UX_SABLE_ALIGNED=YES
PHYSICAL_KEYBOARD_NAVIGATION_USABLE=YES
```

### Titan2 keyboard and touchPad profile

N1B enumerated both `TitanKey` and `touchPad`, but the capture still showed
generic key layout / key character map bindings. N1B2 must include or explicitly
track the Titan2 input profile.

Required checks:

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

### Mobile network triage

N1B visual evidence showed mobile network/5G briefly, and telemetry showed LTE
HOME / IN_SERVICE and data connection transitions. Later telemetry also showed
out-of-service / emergency-only periods. N1B2 must not claim telephony pass from
one transient state.

Required checks:

```text
MOBILE_NETWORK_STATUS=TRIAGE_REQUIRED
OPERATOR_BLOCKING_UNKNOWN=YES
IMAGE_OR_VENDOR_QUIRK_UNKNOWN=YES
RADIO_STACK_PRESENT=YES
LTE_HOME_SEEN=YES
LTE_DATA_CONNECTED_SEEN=YES
LTE_STABILITY_PASS=NO_UNTIL_TIMED_CAPTURE
IMS_PASS=NO_UNTIL_CALL_SMS_VOLTE_VOWIFI_TESTS
EMERGENCY_CALL_TESTING=NO
```

N1B2 must add a bounded timed radio capture. A suggested minimum is:

```text
RADIO_CAPTURE_DURATION_MINUTES=10
CAPTURE_SERVICE_STATE_TRANSITIONS=YES
CAPTURE_DATA_CONNECTION_TRANSITIONS=YES
CAPTURE_APN_SELECTION=YES
CAPTURE_OPERATOR_ALPHA_AND_MCC_MNC=YES
CAPTURE_RADIO_POWER_STATE=YES
CAPTURE_MODEM_CRASH_OR_RIL_RESTARTS=YES
```

The result may be one of:

```text
MOBILE_NETWORK_STABLE_PASS
MOBILE_NETWORK_PARTIAL_INTERMITTENT
MOBILE_NETWORK_FAIL_NO_REGISTRATION
MOBILE_NETWORK_BLOCKED_OPERATOR_OR_SIM_UNKNOWN
```

## Stock images on ai-g732

The ai-g732 stock images may be used for private restore validation and local
packaging experiments if a gated N1B2 packaging path needs them.

```text
STOCK_IMAGES_ON_AI_G732=AVAILABLE
PRIVATE_RESTORE_USE=YES
LOCAL_PACKAGING_USE=YES_IF_GATED
COMMIT_STOCK_IMAGES_TO_GIT=NO
COMMIT_EXTRACTED_PROPRIETARY_BINARIES=NO
PUBLIC_RELEASE_WITH_STOCK_BLOBS=NO_UNLESS_SEPARATE_LICENSE_REVIEW
```

N1B2 must not silently import proprietary stock payloads into git or public
release artifacts.

## N1B2 success definition

N1B2 is successful enough for a new flash-readiness discussion only if all of
these are true:

```text
N1B2_BUILD=PASS
N1B2_IMAGE_ARTIFACT_REGISTERED=YES
SETUP_WIZARD_INCLUDED=YES
SABLE_PRODUCT_IDENTITY=PASS
HOME_RESOLUTION=PASS_SABLE
TITANKEY_TOUCHPAD_PROFILE=PASS_OR_BOUNDED_PARTIAL
MOBILE_NETWORK_TRIAGE_CAPTURE=PASS_CAPTURED
FLASH_PLAN_REVIEWED=YES
FACTORY_RESET_POLICY=EXPLICIT_WIPE_APPROVED_REQUIRED
```

A build-only N1B2 change does not authorize flashing.

```text
N1B2_FLASH_ALLOWED=NO_SEPARATE_GATE_REQUIRED
USERDATA_WIPE_IMPLICIT_ALLOWED=NO
BOOTLOADER_RELOCK_ALLOWED=NO
AVB_MUTATION_ALLOWED=NO_UNLESS_SEPARATE_REVIEW
```
