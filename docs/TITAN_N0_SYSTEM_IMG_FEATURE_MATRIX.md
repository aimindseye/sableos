# Titan N0 System Image Feature Matrix

STATUS=N0_BUILD_PREFLIGHT_CONTRACT
TARGET_DEVICES=Titan 2,Titan 2 Elite
SOURCE_BASE=AOSP Android 16 + RestlessOS android-16.2 references
BUILD_CODE_CHANGED=NO
DEVICE_CODE_CHANGED=NO
FLASH_ENABLEMENT=NO

## Purpose

This document is the build-facing checklist for the first Titan-family N0 `system.img` work. It consolidates the keyboard-first SableOS design contracts, Titan-family manual-derived capability matrix, and recent app display compatibility handoff into one canonical system-image matrix.

The goal is to prevent a successful source build from missing a major product surface.

```text
N0_SYSTEM_IMG_FEATURE_MATRIX=YES
DESIGN_EXISTS_NOT_ENOUGH=YES
SYSTEM_IMG_MAPPING_REQUIRED=YES
FEATURE_MUST_MAP_TO_PACKAGE_MODULE_OR_GATE=YES
FLASH_AUTHORIZED=NO
```

## Core build rule

```text
SOURCE_FETCH_REQUIRED=NO
AOSP_ANDROID16_SOURCE_READY=YES
RESTLESSOS_ANDROID16_2_SOURCE_READY=YES
BUILD_PREFLIGHT_REQUIRED=YES
FIRST_BUILD_MAY_BE_READONLY_OR_MODULE_SCOPED=YES
FULL_FLASH_ENABLEMENT=NO
DEVICE_MUTATION=NO
```

N0 may include UI, package wiring, profile state, validation hooks, and explicit no-op states. N0 must not claim hardware, HAL, vendor service, carrier or WindowManager backend success until runtime proof exists.

```text
N0_CAN_INCLUDE_UI=YES
N0_CAN_INCLUDE_SETTINGS_SURFACES=YES
N0_CAN_INCLUDE_PROFILE_STORAGE=YES
N0_CAN_INCLUDE_VALIDATION_HOOKS=YES
N0_CAN_ASSUME_HAL_SUPPORT=NO
N0_CAN_ASSUME_VENDOR_SERVICE_SUPPORT=NO
N0_CAN_ASSUME_CARRIER_SUPPORT=NO
N0_CAN_FORCE_DISPLAY_BACKEND_WITHOUT_VALIDATION=NO
```

## System image inclusion matrix

| Area | System image expectation | Owner / package / module target | N0 status | Validation gate |
| --- | --- | --- | --- | --- |
| Home / launcher | SableLauncher / Sable Start must be installed as the intended HOME. Launcher3 must not host Sable UI or advertise HOME; Quickstep remains only for Recents/gesture integration. | `org.sableos.launcher`, Launcher3QuickStep boundary | REQUIRED | HOME resolution, Recents still works, no Launcher3 HOME drift |
| Base quick bar | Phone, Hub, Command, All Apps quick bar available with keyboard and touch/pointer access. | SableLauncher / Start | REQUIRED | visible quick bar, Fn shortcuts, fallback access paths |
| Three-page Start model | Center Start, left glance widgets, right Hub semantics retained where profile supports it. | SableLauncher / Start | REQUIRED_OR_PROFILE_GATED | visual/profile validation |
| Type-to-launch | Printable key starts local command/search when no text field is focused. | SableLauncher + Sable Command | REQUIRED | text fields are not hijacked |
| Global Command / Search | Local-first command/search with apps, settings, Hub, contacts, files/notes where locally indexed. | Sable Command / launcher integration | REQUIRED | provider-safe actions only |
| Keyboard policy | Physical keyboard first, onscreen fallback, visible focus, Alt/Sym/Fn handling, text-input-wins. | framework/input/settings/app surfaces | REQUIRED | no focus traps, no shortcut activation while typing |
| Titan key profile | Programmable key, PTT, Sym/Fn, letter shortcuts, Space actions, keyboard gestures, cursor/scroll assistants, backlight. | Settings + input/profile service | REQUIRED_WITH_DEVICE_GATES | key event discovery and per-feature runtime validation |
| App display compatibility | Per-app display profiles including Native, Mini Mode, 16:9 letterbox, 4:3, square-safe, fullscreen media, keyboard-safe, reset outside app. | Settings > Display, Settings > Apps, Launcher app-info handoff | REQUIRED_UI_GATED_BACKEND | WindowManager/backend behavior not claimed until proven |
| Global appearance | Settings remains global appearance authority; Sable apps follow system theme. | Settings provider + Sable app clients | REQUIRED | dark/light propagation across Sable apps |
| Quick Settings / shade | Keyboard-first shade, compact/expanded QS, privacy-aware notification actions, profile-gated hardware tiles. | SystemUI / QS profile overlays | REQUIRED | no start quick bar inside shade, redaction correct |
| Lockscreen | Keyboard PIN/password entry, software fallback, notification redaction, emergency call path. | SystemUI / Keyguard | REQUIRED | no unlock bypass, emergency path preserved |
| Setup Wizard | Keyboard verification, critical text-entry gates, Wi-Fi password entry, privacy/theme choices, restore/import fail-closed. | SetupWizard / provisioning | REQUIRED | no setup dead ends |
| All Apps | App names primary, package names hidden by default, privacy/security summaries under app names, app actions keyboard-accessible. | Launcher / Settings Applications | REQUIRED | permission summary and app-info path |
| Application Security & Privacy | Per-app effective-access transparency, identity/provenance, permissions, app ops, components, network/background/security evidence where available. | Settings > Applications | REQUIRED | distinguish declared, granted, observed, inferred, unknown |
| Sable Network Manager | Settings-owned per-app all-network toggle using revocable `android.permission.INTERNET`; Mobile Manager may link but not own duplicate policy. | Settings / PermissionController integration | REQUIRED | duplicate network blocker absent, no fake cellular/Wi-Fi split |
| Hub | Common communications/attention surface with Priority/Messages/Email/People pivots, provider ownership retained, local explainable priority. | `org.sableos.hub` | REQUIRED | bounded providers, no embedded social WebViews |
| Messages | Keyboard-first latest-anchored conversation UX; onscreen fallback; no custom SMS/RCS/MMS stack. | Sable Messages UI + GrapheneOS/AOSP Messaging transport boundary | REQUIRED | open at latest, provider-safe actions |
| Phone | Keyboard dialing, onscreen dialpad fallback, DTMF, recents privacy, emergency path preserved. | Sable Phone / Dialer | REQUIRED | call flows and emergency path |
| Contacts / People | A-Z rail, search, provider-safe people actions, source labels, privacy redaction. | Contacts / People | REQUIRED | source labels and no custom provider |
| Mail | Sable Mail owns accounts, protocols, sync and private mailbox storage; Hub consumes bounded snapshot/provider contract only. | Sable Mail + Hub provider boundary | REQUIRED | no second mail database reader in Hub |
| Calendar | 5-column/agenda now view, event detail, current/next event visible, keyboard-first. | Calendar app / provider boundary | REQUIRED | latest/current visible rule |
| Browser / WebView | Vanadium/default browser identity accurate, WebView provider boundary visible in diagnostics, find/page/reader keyboard access. | Browser + WebView provider | REQUIRED | Chrome label not used for Vanadium-backed browser |
| Media / Gallery | Zune/Windows-inspired media player; keyboard-first gallery contact sheet; MediaStore boundaries retained. | Sable Media / Gallery | REQUIRED | latest/current media visible, no custom MediaStore |
| Camera | Titan camera profiles, 1x/3.4x telephoto UI, Pro/RAW/high-res opportunity, quality validation gates. | Sable Camera / camera app boundary | REQUIRED_GATED_HAL | camera HAL and privileged capability validation |
| Files / Documents | SAF/DocumentsUI-compatible files/documents/downloads/picker/share; no root file manager default. | Files/DocumentsUI integration | REQUIRED | provider and scoped storage boundaries |
| Utilities | Notes, Recorder, Clock, Calculator/Converter, Tasks/Checklists, optional weather provider card. | Sable utilities | REQUIRED | local-first, provider boundaries, mic/location explicit |
| Toolbox | Noise, Compass, Flashlight, Level, Pic Hanging, Height Measure, Magnifier, Alarm, Plumb Bob, Protractor, Pedometer, Speedometer. | Sable Toolbox / hardware utility surface | REQUIRED_GATED_SENSORS | sensor/runtime validation |
| IR Remote | Local-first infrared remote if transmitter and database path are validated. | Sable Toolbox / Remote | HARDWARE_GATED | IR transmitter validation |
| FM Radio | Do not include as enabled surface unless hardware/HAL/vendor path is proven. | Sable Media gate | DISABLED_GATED | FM hardware/HAL proof required |
| Private Space / Secure Vault | Encrypted file/folder vault; app/profile isolation is platform-gated. | Settings / Files / privacy surface | REQUIRED_GATED_PROFILE | no fake isolation claim |
| Dual Apps | Android clone profile first; no ad-hoc duplicated app sandbox. | Settings / profile management | REQUIRED_GATED_PROFILE | clone/profile runtime validation |
| App Lock | User-selected app lock surface; no hidden policy trap. | Settings / app control surface | REQUIRED | reset and recovery paths |
| Freezer / App blocker | Hide/freeze selected apps with explicit notification/sync breakage warnings. | Mobile Manager / Settings app control | REQUIRED | no silent restrictions |
| Student / Focus mode | Password, time, app, network and site-limit UX, implementation gated by available platform enforcement. | Mobile Manager / Settings | REQUIRED_GATED_ENFORCEMENT | no fake enforcement |
| Connectivity | USB transfer, OTG, Bluetooth file transfer, NFC, Cast, hotspot/tethering, reverse charging where supported. | Settings / connected devices | REQUIRED_GATED_HW | no silent export/cast/tethering |
| eSIM / dual SIM | eSIM and dual SIM 5G carrier-gated surfaces where stack is available. | Settings / Telephony | GATED | EUICC and carrier validation |
| Sub-screen | Titan 2-specific companion surface only; not Titan-family base. | Device profile / companion service | TITAN2_SPECIFIC | not promoted to Elite without proof |
| Call recording | Manual/visible recording surface with default off and region policy gate. | Phone / Recorder policy integration | GATED_POLICY | visible state and storage path |
| Brand / identity scrub | No Graphene placeholder labels in Sable UI; Vanadium not shown as Chrome; package names not primary labels. | product overlays / app resources | REQUIRED | visual and string audit |

## Gated backend and runtime proof matrix

```text
APP_DISPLAY_BACKEND=GATED_UNTIL_WINDOWMANAGER_VALIDATION
SUBSCREEN=TITAN2_SPECIFIC_NOT_ELITE_BASE
FM_RADIO=NO_UNLESS_HAL_VENDOR_PATH_PROVEN
CAMERA_TELEPHOTO=HAL_VALIDATION_REQUIRED
ESIM=EUICC_STACK_VALIDATION_REQUIRED
NFC=NFC_HAL_VALIDATION_REQUIRED
IR_REMOTE=IR_TRANSMITTER_VALIDATION_REQUIRED
USB_OTG=USB_OTG_VALIDATION_REQUIRED
REVERSE_CHARGING=VALIDATION_REQUIRED
CALL_RECORDER=REGION_POLICY_AND_VISIBLE_RECORDING_REQUIRED
PER_APP_CELLULAR_WIFI_SPLIT=NO_UNLESS_PLATFORM_ENFORCEMENT_PROVEN
```

## First N0 preflight checks

Before starting a long build, the build driver should record:

```text
N0_SOURCE_SYNC_SEAL=PASS
AOSP_WS_PRESENT=YES
RESTLESSOS_META_PRESENT=YES
TREBLE_RESTLESSOS_PRESENT=YES
FLASH_AUTHORIZED=NO
PRODUCT_SELECTION_REVIEWED=YES
SYSTEM_IMG_FEATURE_MATRIX_PRESENT=YES
DEVICE_GATE_MATRIX_PRESENT=YES
PLATFORM_COVERAGE_AUDIT_PRESENT=YES
```

Then inspect or generate evidence for:

```text
PRODUCT_MAKEFILES
PRODUCT_PACKAGES
SYSTEM_EXT_PACKAGES
PRIV_APP_PACKAGES
DEFAULT_HOME_RESOLUTION
SETTINGS_SURFACES
SYSTEMUI_SURFACES
INPUT_KEYLAYOUTS_AND_OVERLAYS
PERMISSION_CONTROLLER_AND_APP_OPS_BOUNDARIES
BRAND_STRING_OVERLAYS
```

## Acceptance criteria

```text
TITAN_N0_SYSTEM_IMG_FEATURE_MATRIX=PASS
KEYBOARD_FIRST_SURFACES_LISTED=PASS
TITAN_FAMILY_BASE_FEATURES_LISTED=PASS
APP_DISPLAY_COMPATIBILITY_INCLUDED=PASS
NETWORK_MANAGER_AUTHORITY_RULE_INCLUDED=PASS
SUBSCREEN_REMAINS_TITAN2_SPECIFIC=PASS
FM_RADIO_REMAINS_GATED=PASS
NO_FLASH_ENABLEMENT=PASS
BUILD_CODE_CHANGED=NO
DEVICE_CODE_CHANGED=NO
FLASH_ENABLEMENT=NO
```
