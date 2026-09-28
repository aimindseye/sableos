# N1B Setup Wizard module ownership

Status: **owner required before implementation claim**

This document defines how PR #140 hands off N1B Setup Wizard work to the next
implementation PR. It does not add a Setup Wizard module by itself.

```text
N1B_SETUP_WIZARD_MODULE_OWNERSHIP=YES
SETUP_WIZARD_OWNER_REQUIRED=YES
SETUP_WIZARD_OWNER_DISCOVERY_DONE=YES
SETUP_WIZARD_IMPLEMENTATION_ABSENT=YES
SETUP_WIZARD_NEXT_PR_MUST_ADD_OR_BIND_OWNER=YES
```

## Required owner record

The implementation PR must add a machine-readable owner block to this file or a
successor implementation document:

```text
SETUP_WIZARD_OWNER_STATUS=IMPLEMENTED
SETUP_WIZARD_MODULE_PATH=<path>
SETUP_WIZARD_BUILD_TARGET=<target>
SETUP_WIZARD_BUILD_COMMAND=<exact_command>
SETUP_WIZARD_PROFILE_GATE=<profile_gate>
SETUP_WIZARD_PANTHER_DEFAULTS_CHANGED=<YES|NO>
SETUP_WIZARD_TITAN2_KEYBOARD_CHECK=<YES|NO>
```

Until that block exists, N1B image composition is blocked.

## Candidate implementation shapes

### Option A — wrap an existing platform SetupWizard

Use this only if the Android/Restless/AOSP workspace exposes a SetupWizard owner
that can be safely overlaid or extended without destabilizing platform setup.

Required checks:

```text
EXISTING_SETUPWIZARD_OWNER_CONFIRMED=YES
OVERLAY_OR_EXTENSION_PATH_DEFINED=YES
PANTHER_TOUCH_DEFAULTS_UNCHANGED=YES
KEYBOARD_FIRST_SCREEN_PROFILE_GATED=YES
```

### Option B — add a Sable-owned setup wizard module

Use this if no safe platform owner exists in the integration repo.

Required checks:

```text
SABLE_SETUPWIZARD_MODULE_ADDED=YES
SABLE_SETUPWIZARD_MANIFEST_VALID=YES
SABLE_SETUPWIZARD_BUILD_COMMAND_DEFINED=YES
SABLE_SETUPWIZARD_NOT_ENABLED_ON_PANTHER_BY_ACCIDENT=YES
```

### Option C — profile-gate an existing first-run surface

Use this only if the existing first-run surface is already product-owned and can
host a keyboard-check screen without pretending to be full device provisioning.

Required checks:

```text
FIRST_RUN_SURFACE_OWNER_CONFIRMED=YES
KEYBOARD_CHECK_SCREEN_ADDED=YES
LIMITATIONS_DOCUMENTED=YES
N1B_FULL_SETUPWIZARD_GAP_RECORDED=YES
```

## Required compile gates

The implementation PR must provide exact build commands. Example placeholders
are not acceptable for closure.

```text
SETUP_WIZARD_EXACT_BUILD_COMMAND_REQUIRED=YES
SETUP_WIZARD_COMPILE_REQUIRED=YES
SETUP_WIZARD_LINT_REQUIRED_WHERE_AVAILABLE=YES
SETUP_WIZARD_UNIT_TESTS_REQUIRED_WHERE_AVAILABLE=YES
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
