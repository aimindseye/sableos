# N1B Setup Wizard module ownership

Status: **dual-lane owner required before implementation claim**

This document defines how PR #140 hands off N1B Setup Wizard work to the next
implementation PR. It does not add or modify a Setup Wizard module by itself.

The ownership model is now split by lane:

```text
N1B_SETUP_WIZARD_MODULE_OWNERSHIP=YES
SETUP_WIZARD_PIXEL_GRAPHENE_OWNER=GRAPHENEOS_SETUPWIZARD2
SETUP_WIZARD_PIXEL_GRAPHENE_OWNER_FOUND=YES
SETUP_WIZARD_PIXEL_MODULE_NAME=SetupWizard2
SETUP_WIZARD_PIXEL_PACKAGE_NAME=app.grapheneos.setupwizard
PANTHER_SETUP_WIZARD_BEHAVIOR_PRESERVED=YES
SABLE_PRIVATE_SETUPWIZARD_CODE_OWNER_FOUND=NO
SABLE_SETUPWIZARD_LOCAL_OWNER_REQUIRED_FOR_TITAN_EXTENSION=YES
TITAN2_KEYBOARD_FIRST_SETUP_EXTENSION_REQUIRED=YES
SETUP_WIZARD_NEXT_PR_MUST_BIND_GRAPHENEOS_BASE_OR_ADD_PROFILE_EXTENSION_OWNER=YES
```

## Pixel / Graphene owner record

Pixel / Graphene-supported devices should continue to use the GrapheneOS
SetupWizard2 base unless a separate explicit Panther/Pixel PR changes that.

```text
PIXEL_SETUP_OWNER_STATUS=UPSTREAM_GRAPHENEOS
PIXEL_SETUP_OWNER_REPO=GrapheneOS/platform_packages_apps_SetupWizard2
PIXEL_SETUP_MODULE=SetupWizard2
PIXEL_SETUP_PACKAGE=app.grapheneos.setupwizard
PIXEL_SETUP_ENTRY=WelcomeActivity
PIXEL_SETUP_PROVISION_OVERRIDE=Provision
PIXEL_SETUP_SECURITY_SEMANTICS_PRESERVED=YES
PIXEL_SETUP_BRANDING_OVERLAY_ONLY_WHERE_VALIDATED=YES
PIXEL_SETUP_KEYBOARD_FIRST_EXTENSION_DEFAULT=NO
```

## Titan extension owner record

The implementation PR must add a machine-readable Titan extension owner block to
this file or a successor implementation document:

```text
TITAN_SETUP_EXTENSION_OWNER_STATUS=IMPLEMENTED
TITAN_SETUP_EXTENSION_MODULE_PATH=<path>
TITAN_SETUP_EXTENSION_BUILD_TARGET=<target>
TITAN_SETUP_EXTENSION_BUILD_COMMAND=<exact_command>
TITAN_SETUP_EXTENSION_PROFILE_GATE=<profile_gate>
TITAN_SETUP_EXTENSION_GRAPHENE_BASE_BINDING=<wrapped|derived|not_used_with_reason>
TITAN_SETUP_EXTENSION_PANTHER_DEFAULTS_CHANGED=<YES|NO>
TITAN_SETUP_EXTENSION_KEYBOARD_CHECK=<YES|NO>
```

Until that block exists, N1B image composition is blocked.

## Candidate implementation shapes

### Option A — profile-gate a GrapheneOS SetupWizard2 extension

Preferred when the Android/Restless workspace can consume or carry the
GrapheneOS SetupWizard2 module.

Required checks:

```text
GRAPHENEOS_SETUPWIZARD2_BASE_BOUND=YES
PROFILE_GATED_KEYBOARD_SCREEN_ADDED=YES
PANTHER_TOUCH_DEFAULTS_UNCHANGED=YES
PIXEL_GRAPHENE_SETUP_SECURITY_SEMANTICS_PRESERVED=YES
KEYBOARD_FIRST_SCREEN_PROFILE_GATED=YES
```

### Option B — derive a Sable setup wizard from GrapheneOS SetupWizard2 for Titan

Use this if a direct extension is too risky for the Titan / Restless substrate,
but the GrapheneOS setup/security semantics can still be preserved.

Required checks:

```text
SABLE_DERIVED_SETUPWIZARD_MODULE_ADDED=YES
GRAPHENEOS_SETUPWIZARD2_PROVENANCE_RECORDED=YES
LICENSE_AND_NOTICE_PRESERVED=YES
PIXEL_GRAPHENE_SETUPWIZARD2_UNCHANGED=YES
TITAN_PROFILE_EXTENSION_ONLY=YES
SABLE_SETUPWIZARD_BUILD_COMMAND_DEFINED=YES
```

### Option C — add a Sable-owned setup wizard module only if the base cannot be used

Use this only if the Titan / Restless substrate cannot safely consume
GrapheneOS SetupWizard2 directly or as a derived module.

Required checks:

```text
GRAPHENEOS_BASE_NOT_USABLE_REASON_RECORDED=YES
SABLE_SETUPWIZARD_MODULE_ADDED=YES
SABLE_SETUPWIZARD_MANIFEST_VALID=YES
SABLE_SETUPWIZARD_BUILD_COMMAND_DEFINED=YES
SABLE_SETUPWIZARD_NOT_ENABLED_ON_PANTHER_BY_ACCIDENT=YES
SETUP_PARITY_GAPS_RECORDED=YES
```

## Required compile gates

The implementation PR must provide exact build commands. Example placeholders
are not acceptable for closure.

```text
SETUP_WIZARD_EXACT_BUILD_COMMAND_REQUIRED=YES
SETUP_WIZARD_COMPILE_REQUIRED=YES
SETUP_WIZARD_LINT_REQUIRED_WHERE_AVAILABLE=YES
SETUP_WIZARD_UNIT_TESTS_REQUIRED_WHERE_AVAILABLE=YES
PIXEL_GRAPHENE_SETUP_BUILD_REGRESSION_GATE_REQUIRED=YES
TITAN_SETUP_EXTENSION_BUILD_GATE_REQUIRED=YES
```

The implementation PR may add temporary per-module commands, but the command
must be runnable without device contact, flash, or image build.

## Physical UX gates deferred to Stage B

Stage A can only prove code ownership and buildability. Physical behavior must
be validated later:

```text
STAGE_A_PHYSICAL_UX_CLAIM=NO
STAGE_B_PHYSICAL_UX_REQUIRED=YES
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
ADB_COMMANDS_RUN=NO
FASTBOOT_COMMANDS_RUN=NO
```

Stage B validation must include:

```text
PHYSICAL_KEYBOARD_PRINTABLE_INPUT=PASS
ALT_SYM_FN_TEXT_ENTRY=PASS
ENTER_BACKSPACE_NAVIGATION=PASS
SOFTWARE_KEYBOARD_FALLBACK=PASS
TOUCH_FALLBACK=PASS
NO_SETUP_DEAD_ENDS=PASS
```
