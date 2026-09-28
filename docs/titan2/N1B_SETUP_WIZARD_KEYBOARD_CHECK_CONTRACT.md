# N1B Setup Wizard keyboard-check contract

Status: **Stage A dual-lane setup gate / implementation blocked until Titan extension owner exists**

This document turns the approved Setup Wizard / First Boot keyboard-first design
into an N1B Stage A implementation contract.

This revision corrects the initial owner finding from PR #140. The current
`aimindseye/sableos` tree does not expose a Sable-owned `SetupWizard` or
`FirstBoot` implementation owner, but the product/source-composition level does
have an upstream setup owner for the Pixel / Graphene-supported lane:

```text
GRAPHENEOS_SETUPWIZARD2_UPSTREAM_OWNER_FOUND=YES
GRAPHENEOS_SETUPWIZARD2_UPSTREAM_REPO=GrapheneOS/platform_packages_apps_SetupWizard2
GRAPHENEOS_SETUPWIZARD2_MODULE=SetupWizard2
GRAPHENEOS_SETUPWIZARD2_PACKAGE=app.grapheneos.setupwizard
GRAPHENEOS_SETUPWIZARD2_PRIVILEGED_PLATFORM_SIGNED=YES
GRAPHENEOS_SETUPWIZARD2_SYSTEM_EXT_SPECIFIC=YES
GRAPHENEOS_SETUPWIZARD2_OVERRIDES_PROVISION=YES
```

The private integration repo finding remains:

```text
SABLE_PRIVATE_SETUPWIZARD_CODE_OWNER_FOUND=NO
SABLE_PRIVATE_SETUPWIZARD_IMPL_CLAIM=NO
```

Therefore N1B must use a dual-lane setup strategy rather than inventing one
setup path for every device.

```text
N1B_SETUP_WIZARD_KEYBOARD_CHECK_CONTRACT=YES
SABLE_SETUP_WIZARD_STRATEGY=DUAL_LANE_PROFILE_GATED_EXTENSION
PIXEL_GRAPHENE_SETUPWIZARD2_BASE_PRESERVED=YES
PANTHER_SETUP_BEHAVIOR_UNCHANGED_UNLESS_EXPLICIT=YES
TITAN2_SETUP_WIZARD_BASE=GRAPHENEOS_SETUPWIZARD2_REFERENCE_OR_DERIVED
TITAN_KEYBOARD_FIRST_SETUP_EXTENSION_REQUIRED=YES
SABLE_SETUPWIZARD_LOCAL_OWNER_REQUIRED_FOR_TITAN_EXTENSION=YES
N1B_SETUP_WIZARD_IMAGE_BLOCKER=YES
DOCUMENTATION_ONLY=YES
BUILD_CODE_CHANGED=NO
DEVICE_CODE_CHANGED=NO
IMAGE_BUILD_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
```

## Source authority

N1B Setup Wizard work is bound to the approved `platform_sable` first-boot
contract and the N1B traceability / multi-profile / Stage A contracts merged in
PRs #137, #138 and #139.

Required source contracts:

```text
SETUP_WIZARD_FIRST_BOOT_UX=YES
ANDROID_SETUP_MENTAL_MODEL=KEEP
KEYBOARD_FIRST_ONBOARDING=YES
PHYSICAL_KEYBOARD_VERIFICATION=YES
CRITICAL_TEXT_ENTRY_GATE=YES
WIFI_PASSWORD_ENTRY=YES
ALT_SYM_FN_TEXT_ENTRY=YES
SOFTWARE_KEYBOARD_FALLBACK=YES
DARK_THEME_SELECTION=YES
SABLE_APPS_FOLLOW_SYSTEM_THEME=YES
PRIVACY_POSTURE_EXPLICIT=YES
RESTORE_IMPORT_FAIL_CLOSED=YES
```

N1B must not treat the Setup Wizard as optional because it is the first
user-facing SableOS system path after boot.

## Upstream GrapheneOS setup owner

GrapheneOS provides the upstream Setup Wizard owner used by the Pixel /
Graphene-supported lane:

```text
UPSTREAM_SETUP_OWNER=GrapheneOS/platform_packages_apps_SetupWizard2
UPSTREAM_SETUP_MODULE=SetupWizard2
UPSTREAM_SETUP_PACKAGE=app.grapheneos.setupwizard
UPSTREAM_SETUP_ENTRY=app.grapheneos.setupwizard.view.activity.WelcomeActivity
UPSTREAM_SETUP_INTENT_CATEGORY=android.intent.category.SETUP_WIZARD
UPSTREAM_SETUP_HOME_CATEGORY=android.intent.category.HOME
UPSTREAM_SETUP_OVERRIDES=Provision
UPSTREAM_SETUP_SIGNING=platform
UPSTREAM_SETUP_PRIVILEGED=true
UPSTREAM_SETUP_SYSTEM_EXT_SPECIFIC=true
```

The upstream module includes the existing GrapheneOS first-run flow, including
Wi-Fi, date/time, location, security, migration, gestures and finish screens.
It also carries GrapheneOS-specific package names and user-facing strings.

## Pixel / Graphene-supported lane

For Pixel / Graphene-supported devices, including Panther, SableOS should
preserve the existing GrapheneOS SetupWizard2 behavior and security semantics.

```text
PIXEL_GRAPHENE_SETUP_LANE=GRAPHENEOS_SETUPWIZARD2_BASE
PANTHER_SETUP_BEHAVIOR_UNCHANGED_UNLESS_EXPLICIT=YES
PIXEL_SETUP_SECURITY_FLOW_PRESERVED=YES
PIXEL_SETUP_PROVISION_OVERRIDE_PRESERVED=YES
SABLE_BRANDING_OVERLAY_ONLY_WHERE_VALIDATED=YES
PIXEL_SETUP_KEYBOARD_FIRST_SCREEN_DEFAULT=NO
```

SableOS may apply branding/resource overlays for Pixel only when those overlays
are already validated and do not change provisioning, security, restore,
network, or device-provisioned behavior.

## Titan 2 / keyboard-first lane

Titan 2 / N1B needs additional keyboard-first setup behavior. It should not be a
disconnected setup flow. It must either derive from, wrap, or remain explicitly
compatible with the GrapheneOS SetupWizard2 base semantics.

```text
TITAN2_SETUP_LANE=KEYBOARD_FIRST_EXTENSION
TITAN2_SETUP_WIZARD_BASE=GRAPHENEOS_SETUPWIZARD2_REFERENCE_OR_DERIVED
TITAN2_KEYBOARD_FIRST_SETUP_EXTENSION_REQUIRED=YES
TITAN2_SETUP_EXTENSION_PROFILE_GATED=YES
TITAN2_SETUP_EXTENSION_MUST_NOT_MUTATE_PIXEL_DEFAULTS=YES
```

The Titan extension must add or preserve:

```text
SABLE_BRANDED_FIRST_BOOT=YES
PHYSICAL_KEYBOARD_VERIFICATION_SCREEN=YES
CRITICAL_TEXT_ENTRY_TEST=YES
WIFI_PASSWORD_ENTRY_TEST=YES
ALT_SYM_FN_TEXT_ENTRY_TEST=YES
ENTER_BACKSPACE_NAVIGATION_TEST=YES
SOFTWARE_KEYBOARD_FALLBACK_AVAILABLE=YES
TOUCH_FALLBACK_AVAILABLE=YES
ACCESSIBILITY_ENTRY_VISIBLE=YES
NO_SETUP_DEAD_ENDS=YES
NO_FOCUS_TRAPS=YES
```

## Required implementation record

Before N1B can advance beyond Stage A, SableOS must provide one explicit code
owner for Titan setup extension work.

```text
SETUP_WIZARD_IMPLEMENTATION_OPTION=<A|B|C>
SETUP_WIZARD_MODULE_PATH=<repo_path>
SETUP_WIZARD_PACKAGE_NAME=<android_package>
SETUP_WIZARD_ENTRY_ACTIVITY=<activity_or_component>
SETUP_WIZARD_PROFILE_GATE=<touch_first|keyboard_first|shared>
SETUP_WIZARD_BUILD_COMMAND=<exact_command>
PIXEL_GRAPHENE_BASE_PRESERVED=<YES|NO>
TITAN_KEYBOARD_EXTENSION_INCLUDED=<YES|NO>
```

Accepted implementation shapes:

```text
OPTION_A=profile_gate_grapheneos_setupwizard2_extension
OPTION_B=derive_sable_setupwizard_from_grapheneos_setupwizard2_for_titan
OPTION_C=add_sable_setupwizard_module_only_if_grapheneos_base_cannot_be_used
```

Option C requires explicit parity documentation showing why the GrapheneOS base
cannot be consumed directly in the Titan / Restless substrate.

## Profile isolation

Setup Wizard work is profile-sensitive. Keyboard-first additions must not change
Panther default first-boot behavior unless an explicit Panther PR says so.

```text
PANTHER_TOUCH_FIRST_REFERENCE_PROTECTED=YES
KEYBOARD_FIRST_CHANGES_PROFILE_GATED=YES
TITAN2_N1B_DOES_NOT_MUTATE_PANTHER_DEFAULTS=YES
COMMON_CODE_REQUIRES_TOUCH_AND_KEYBOARD_GATES=YES
```

If Setup Wizard code is shared, the keyboard verification screen must be gated by
profile or device capability, not by raw model-name string checks.

## Stage gates

N1B image composition remains blocked until:

```text
N1B_STAGE_A_SETUP_WIZARD_CODE_OWNER=PASS
N1B_STAGE_A_SETUP_WIZARD_COMPILE=PASS
N1B_STAGE_A_CRITICAL_TEXT_ENTRY_COMPILE=PASS
N1B_STAGE_A_PROFILE_ISOLATION=PASS
N1B_STAGE_B_SETUP_WIZARD_PHYSICAL_UX=PASS
N1B_STAGE_C_FULL_CI_AFTER_SETUP_WIZARD=PASS
```

Image build is not authorized by this document.

```text
N1B_SKIP_TO_IMAGE_BUILD=NO
IMAGE_BUILD_BLOCKED_UNTIL_CODE_PHYSICAL_CI_PASS=YES
```
