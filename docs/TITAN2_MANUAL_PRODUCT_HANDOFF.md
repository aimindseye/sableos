# Titan 2 manual-derived product handoff

Status: design-to-implementation guardrail.

This document binds the Titan 2 manual-derived design PRs from `sableos-project/platform_sable` to implementation work in this repository. It exists to prevent code work from accidentally duplicating a capability, implementing a placeholder surface, or inheriting Titan 2 assumptions onto Titan 2 Elite / Q27 without proof.

## Source design PRs

```text
PLATFORM_SABLE_PR_31=Toolbox / Hardware Utilities / Remote / Radio UX
PLATFORM_SABLE_PR_32=Private Space / Dual Apps / Work Profile / App Lock / Secure Vault UX
PLATFORM_SABLE_PR_33=Sub-screen / Shortcut Keys / Keyboard Gestures UX
PLATFORM_SABLE_PR_34=Mobile Manager / App Controls / Student Mode UX
PLATFORM_SABLE_PR_35=Connectivity / OTG / NFC / Cast / Compatibility UX
PLATFORM_SABLE_PR_36=Mobile Manager Network Authority Clarification
```

## Network Manager / Mobile Manager rule

Mobile Manager must reuse the already implemented Settings-owned Sable Network Manager capability. It must not create a second network-blocking stack, a second policy store, or fake transport-specific switches.

The Panther/R9 Network Manager implementation uses the platform-revocable `android.permission.INTERNET` model. It is one all-network per-app control. A per-app Mobile/WLAN split is not valid unless a future platform-backed transport-scoped enforcement path is independently proven and gated.

```text
MOBILE_MANAGER_REUSES_SABLE_NETWORK_MANAGER=YES
NETWORK_CONTROL_AUTHORITY=SETTINGS_OWNED_SABLE_NETWORK_MANAGER
NETWORK_CONTROL_IMPLEMENTATION=REVOCABLE_ANDROID_PERMISSION_INTERNET
ALL_NETWORK_TOGGLE=YES
MOBILE_MANAGER_MAY_DEEP_LINK_TO_NETWORK_MANAGER=YES
MOBILE_MANAGER_MAY_SUMMARIZE_NETWORK_STATE=YES
DUPLICATE_NETWORK_BLOCKER=NO
DUPLICATE_NETWORK_POLICY_STORE=NO
PER_APP_CELLULAR_TOGGLE=NO_UNLESS_PLATFORM_ENFORCEMENT_PROVEN
PER_APP_WIFI_TOGGLE=NO_UNLESS_PLATFORM_ENFORCEMENT_PROVEN
```

Implementation consequence:

```text
MOBILE_MANAGER_NETWORK_TILE=ALLOWED_AS_ENTRYPOINT
MOBILE_MANAGER_NETWORK_BACKEND=EXISTING_SABLE_NETWORK_MANAGER
NEW_NETWORK_BLOCKING_SERVICE=NO
NEW_NETWORK_PERMISSION_MODEL=NO
```

## Mobile Manager remaining scope

Mobile Manager is still a valid umbrella/control center. Its non-network work is separate from the existing Network Manager capability.

```text
APP_AUTOSTART_CONTROL=FUTURE_OR_DEVICE_GATED
BACKGROUND_ACTIVITY_CONTROL=FUTURE_OR_DEVICE_GATED
FREEZER_OR_HIDE_UNUSED_APPS=FUTURE_OR_DEVICE_GATED
STUDENT_MODE_OR_FOCUS_MODE=FUTURE_OR_DEVICE_GATED
APP_WHITELIST=FUTURE_OR_DEVICE_GATED
TIME_LIMITS=FUTURE_OR_DEVICE_GATED
SITE_RESTRICTIONS=FUTURE_OR_DEVICE_GATED
NOTIFICATION_BREAKAGE_WARNING=REQUIRED
```

## Toolbox / hardware utilities

Toolbox is a hardware capability surface, not a generic Android app bundle. Every hardware-backed tool must have a device capability source and a negative gate when the capability is absent.

```text
TOOLBOX_HARDWARE_UTILITIES=YES
NOISE_TEST=MICROPHONE_GATED
COMPASS=SENSOR_GATED
FLASHLIGHT=CAMERA_FLASH_GATED
BUBBLE_LEVEL=SENSOR_GATED
PIC_HANGING=SENSOR_GATED
HEIGHT_MEASURE=CAMERA_SENSOR_GATED
MAGNIFIER=CAMERA_GATED
PLUMB_BOB=SENSOR_GATED
PROTRACTOR=UI_ONLY_OR_SENSOR_ASSISTED
SPEEDOMETER=LOCATION_GATED
PEDOMETER=STEP_COUNTER_OR_ACCELEROMETER_GATED
IR_REMOTE=IR_TRANSMITTER_GATED
FM_RADIO=MEDIA_CAPABILITY_GATE_ONLY
```

FM Radio belongs under Media only if a real tuner/HAL/vendor path is proven. Do not ship a fake placeholder radio app.

```text
SABLE_MEDIA_FM_RADIO_MODE=YES_IF_HARDWARE_PROVEN
FM_RADIO_PLACEHOLDER_APP=NO
FM_TUNER_HARDWARE_GATE=REQUIRED
FM_HAL_OR_VENDOR_SERVICE_GATE=REQUIRED
```

## Private Space / Dual Apps / Work Profile / App Lock

This is an identity/isolation surface. It should use Android profile/storage/security primitives where available instead of APK-copy hacks or hidden-folder-only behavior.

```text
PRIVATE_SPACE=YES
SECURE_VAULT=YES
DUAL_APPS=YES
WORK_PROFILE=YES
APP_LOCK=YES
ANDROID_PROFILE_MODEL=KEEP
APK_COPY_HACK=NO
PROFILE_BADGES_REQUIRED=YES
SEARCH_RECENTS_LAUNCHER_BADGES_REQUIRED=YES
PRIVATE_SPACE_REDACTION=YES
WORK_PROFILE_PAUSE_CONTROL=YES
```

Titan 2 manual Private Space is a file/content vault concept. Android Private Space is a profile/app-isolation concept. Sable should preserve that distinction during implementation.

```text
TITAN2_PRIVATE_SPACE_MODEL=CONTENT_VAULT
ANDROID_PRIVATE_SPACE_MODEL=PROFILE_APP_SPACE
SABLE_PRIVATE_SPACE_MODEL=VAULT_PLUS_PROFILE_WHEN_AVAILABLE
```

## Sub-screen / shortcut keys / keyboard gestures

Titan 2 sub-screen support should be curated companion behavior, not arbitrary app mirroring. The sub-screen must not be treated as a general text-editing surface.

```text
SUBSCREEN_COMPANION_MODES=YES
SUBSCREEN_ARBITRARY_APP_MIRRORING=NO
SUBSCREEN_TEXT_INPUT=NO
SUBSCREEN_EDITING_INPUT=NO
FUNC1_FUNC2_SHORTCUTS=YES
PTT_KEY_POLICY=YES
MAGIC_KEY_SHORTCUTS=YES
LETTER_KEY_SHORTCUTS=YES
SPACE_KEY_ACTIONS=YES
KEYBOARD_GESTURE_SCROLL_ASSISTANT=YES
KEYBOARD_GESTURE_CURSOR_ASSISTANT=YES
TEXT_INPUT_ALWAYS_WINS=YES
```

## Connectivity / OTG / NFC / Cast / compatibility

Connectivity features retain Android/AOSP provider and permission boundaries. They must require explicit user action for data export, display casting and tethering.

```text
USB_FILE_TRANSFER_INCLUDED=YES
USB_OTG_INCLUDED=YES
BLUETOOTH_FILE_TRANSFER_INCLUDED=YES
NFC_INCLUDED=HARDWARE_GATED
CAST_INCLUDED=YES
HOTSPOT_TETHERING_INCLUDED=YES
ROTATION_CONTROL_INCLUDED=YES
MINI_MODE_COMPATIBILITY_INCLUDED=YES
NO_SILENT_USB_EXPORT=YES
NO_SILENT_CAST=YES
NO_SILENT_TETHERING=YES
```

## Device profile rules

Titan 2, Titan 2 Elite and Q27 must not inherit hardware capability claims from each other.

```text
TITAN2_PROFILE=PRIMARY_MANUAL_AND_DEVICE_EVIDENCE
TITAN2_ELITE_PROFILE=INDEPENDENT_VALIDATION_REQUIRED
Q27_PROFILE=RETAIL_HARDWARE_EVIDENCE_REQUIRED
PROFILE_PASS_INHERITANCE=NO
```

Allowed inheritance is limited to Sable common UX contracts. Hardware claims require device-specific evidence.

## Implementation checklist

Before code implementation for any surface above:

```text
SOURCE_DESIGN_PR_REFERENCED=YES
CAPABILITY_AUTHORITY_IDENTIFIED=YES
DUPLICATE_STACK_CHECKED=YES
HARDWARE_GATE_DEFINED=YES_WHEN_HARDWARE_BACKED
DEVICE_PROFILE_DEFINED=YES
NEGATIVE_ABSENCE_GATE_DEFINED=YES
PRIVACY_WARNING_DEFINED=YES_WHEN_BREAKAGE_OR_EXPORT_POSSIBLE
TEXT_INPUT_ALWAYS_WINS_CHECKED=YES_FOR_TITAN2_KEYBOARD
BUILD_CODE_CHANGED=NO_IN_THIS_DOC
```
