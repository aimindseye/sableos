# Titan 2 N0_A16 profile gates

Status: **required before first Sable-owned system image build**

Titan 2 N0_A16 build-target work is now bound to the merged SableOS common
profile architecture and device-capability matrix.

```text
PLATFORM_SABLE_PROFILE_CONTRACT_PR=sableos-project/platform_sable#11
PLATFORM_SABLE_CAPABILITY_MATRIX_PR=sableos-project/platform_sable#12
DEVICE=titan2
TITAN_RELEASE_ID=N0_A16
PROFILE_GATE_REQUIRED=YES
PROFILE_PASS_INHERITANCE=NO
```

## Why this gate exists

Titan 2, Titan 2 Elite and Zinwa Q27 are all keyboard-first candidates, but they
must not share one hardware/display/input profile. Titan 2 N0_A16 may proceed
only against the Titan 2 capability record and Titan 2 acceptance gates.

The first Sable-owned `system.img` build is not allowed to assume:

- Titan 2 Elite AMOLED/AOD behavior;
- Q27 keyboard or pointer behavior;
- Pixel / Panther display, input, SystemUI or power assumptions;
- generic keyboard-phone behavior without Titan 2 evidence.

## Required profile posture

```text
SABLE_HARDWARE_PROFILE=titan2
SABLE_DISPLAY_PROFILE=square_lcd_with_rear_subscreen
SABLE_PANEL_POWER_PROFILE=lcd_no_aod_default
SABLE_ATTENTION_PROFILE=subscreen_candidate_keyboard_backlight_candidate_no_aod
SABLE_KEYBOARD_PROFILE=titan2_required_independent
SABLE_POINTER_SURFACE_PROFILE=titan2_required_independent
SABLE_APP_LAYOUT_PROFILE=square_keyboard_first
SABLE_CRITICAL_TEXT_ENTRY_PROFILE=required
```

## Required before Sable-owned image build

```text
TITAN2_DEVICE_CAPABILITY_RECORD=ACKNOWLEDGED
TITAN2_AOD_DEFAULT=NO
TITAN2_SUBSCREEN_POLICY=REQUIRED_FOR_ATTENTION_SURFACE
TITAN2_KEYBOARD_PROFILE=REQUIRED
TITAN2_POINTER_SURFACE_PROFILE=REQUIRED
TITAN2_CRITICAL_TEXT_ENTRY_GATES=REQUIRED
TITAN2_BT_PAIRING_TEXT_ENTRY_GATE=REQUIRED
TITAN2_SOFTWARE_KEYBOARD_FALLBACK_GATE=REQUIRED
TITAN2_ALT_SYM_SYSTEM_DIALOG_GATE=REQUIRED
```

## Permitted before this gate is fully satisfied

Read-only and host-only work may continue:

```text
AOSP16_SOURCE_BOOTSTRAP=ALLOWED_WITH_NETWORK_AUTHORIZATION
SUBSTRATE_PROBE=ALLOWED_READ_ONLY
SUBSTRATE_QUALIFICATION=ALLOWED_HOST_ONLY
DEVICE_CONTACT=NO
FLASH=NO
```

## Blocked until this gate is satisfied

```text
SABLE_SYSTEM_IMAGE_BUILD=BLOCKED_UNTIL_PROFILE_GATE_ACK
ARTIFACT_REGISTRATION=BLOCKED
E3_DEPLOYMENT=BLOCKED
FLASH=BLOCKED
PUBLIC_BUILD_ENABLEMENT=BLOCKED
```

## First-boot acceptance linkage

After an image exists and E3 allows a bounded deployment, Titan 2 first-boot
acceptance must populate the merged capability matrix rather than replacing it.
The following remain independent PASS gates and cannot be inherited from Pixel,
Titan 2 Elite, Q27 or reference apps:

```text
TITAN2_MAIN_DISPLAY_BOOT=NOT_TESTED
TITAN2_REAR_SUBSCREEN_ENUMERATION=NOT_TESTED
TITAN2_HARDWARE_KEYBOARD_TEXT_ENTRY=NOT_TESTED
TITAN2_ALT_SYM_ENTRY_SYSTEM_DIALOG=NOT_TESTED
TITAN2_SOFTWARE_KEYBOARD_FALLBACK=NOT_TESTED
TITAN2_BT_PAIRING_TEXT_ENTRY=NOT_TESTED
TITAN2_POINTER_TOUCH_SURFACE=NOT_TESTED
TITAN2_AOD=NO_BY_DEFAULT
```
