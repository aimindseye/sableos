# N1B Setup Wizard keyboard-check contract

Status: **Stage A ownership gate / implementation blocked until code owner exists**

This document turns the approved Setup Wizard / First Boot keyboard-first design
into an N1B Stage A implementation contract. It exists because the current
`aimindseye/sableos` tree does not expose a clear `SetupWizard` or `FirstBoot`
implementation owner by repository search.

```text
N1B_SETUP_WIZARD_KEYBOARD_CHECK_CONTRACT=YES
N1B_SETUP_WIZARD_CODE_OWNER_CURRENTLY_FOUND=NO
N1B_SETUP_WIZARD_IMPLEMENTATION_REQUIRED=YES
N1B_SETUP_WIZARD_MODULE_OWNER_REQUIRED=YES
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

## Current repository finding

The immediate Stage A inspection did not find an existing implementation owner
for Setup Wizard / First Boot in `aimindseye/sableos` using searches for:

```text
SetupWizard
setup wizard
FirstBoot
keyboard check
```

Therefore PR #140 must not claim a completed first-boot implementation. It
instead records the required implementation boundary and blocks N1B image
promotion until a code owner exists and compiles.

```text
SETUP_WIZARD_OWNER_DISCOVERY=PASS_ABSENT
SETUP_WIZARD_IMPLEMENTATION_CLAIM=NO
SETUP_WIZARD_CODE_OWNER_BLOCKER=YES
```

## N1B implementation requirement

Before N1B can advance beyond Stage A, SableOS must provide one explicit code
owner for first boot:

```text
OPTION_A=wrap_existing_platform_setupwizard
OPTION_B=add_sable_owned_setupwizard_module
OPTION_C=profile_gate_existing_first_run_surface_with_sable_screen
```

The chosen option must be recorded with:

```text
SETUP_WIZARD_IMPLEMENTATION_OPTION=<A|B|C>
SETUP_WIZARD_MODULE_PATH=<repo_path>
SETUP_WIZARD_PACKAGE_NAME=<android_package>
SETUP_WIZARD_ENTRY_ACTIVITY=<activity_or_component>
SETUP_WIZARD_PROFILE_GATE=<touch_first|keyboard_first|shared>
SETUP_WIZARD_BUILD_COMMAND=<exact_command>
```

## Required behavior

The implementation must provide or preserve:

```text
SABLE_BRANDED_FIRST_BOOT=YES
NO_GRAPHENE_AOSP_BRANDING_ON_SABLE_OWNED_SCREENS=YES
TITAN2_SQUARE_LAYOUT_SAFE=YES
TOUCH_FALLBACK_AVAILABLE=YES
SOFTWARE_KEYBOARD_FALLBACK_AVAILABLE=YES
PHYSICAL_KEYBOARD_VERIFICATION_SCREEN=YES
CRITICAL_TEXT_ENTRY_TEST=YES
WIFI_PASSWORD_ENTRY_TEST=YES
ALT_SYM_FN_TEXT_ENTRY_TEST=YES
ENTER_BACKSPACE_NAVIGATION_TEST=YES
DARK_THEME_SELECTION=YES
PRIVACY_POSTURE_EXPLICIT=YES
RESTORE_IMPORT_FAIL_CLOSED=YES
ACCESSIBILITY_ENTRY_VISIBLE=YES
NO_SETUP_DEAD_ENDS=YES
NO_FOCUS_TRAPS=YES
```

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
