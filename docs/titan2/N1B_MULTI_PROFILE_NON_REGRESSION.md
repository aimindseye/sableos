# N1B multi-profile non-regression contract

Status: **required gate before N1B implementation/image work**

N1B must become the first Titan 2 keyboard-first SableOS UX-evaluation image
without breaking Panther or future non-keyboard devices. This document records
the multi-profile contract that sits between the N1B traceability plan and actual
implementation PRs.

```text
N1B_MULTI_PROFILE_NON_REGRESSION=YES
KEYBOARD_FIRST_CHANGES_PROFILE_GATED=YES
COMMON_CODE_REQUIRES_TOUCH_AND_KEYBOARD_GATES=YES
IMAGE_BUILD_BLOCKED_UNTIL_CODE_PHYSICAL_CI_PASS=YES
PUBLIC_BUILD_PATH_FAIL_CLOSED=YES
```

## Profile split

SableOS now has two active product profile families:

```text
TOUCH_FIRST_PROFILE
  current reference: panther
  input priority: touch / gestures / software keyboard
  role: frozen accepted reference and regression baseline

KEYBOARD_FIRST_PROFILE
  first target: titan2
  next targets: titan2-elite, q27
  input priority: physical keyboard with touch/software fallback
  role: portability and N1B UX-evaluation path
```

Common app semantics remain shared. Hardware, display, attention, setup,
keyboard, pointer, and critical text-entry behavior are profile-owned.

```text
COMMON_SABLE_SEMANTICS_SHARED=YES
DEVICE_PROFILE_OWNS_INPUT_DISPLAY_ATTENTION=YES
PROFILE_PASS_INHERITANCE=NO
```

## Implementation rule

A shared implementation PR must not assume the active device is Titan 2.

Required code/design posture:

```text
COMMON_CODE_PROFILE_AWARE=YES
TOUCH_FIRST_PATH_PRESERVED=YES
KEYBOARD_FIRST_PATH_EXPLICIT=YES
PANTHER_DEFAULTS_UNCHANGED_UNLESS_DECLARED=YES
TITAN2_DEFAULTS_NOT_GLOBAL_DEFAULTS=YES
```

## N1B promotion sequence dependency

The approved sequence remains:

```text
1_BUILD_SABLEOS_CODE=REQUIRED
2_VALIDATE_PHYSICAL_UX=REQUIRED
3_RUN_FULL_CI=REQUIRED
4_BUILD_CODE_IMAGES=LAST
```

Image composition/build is blocked until code build, physical UX validation, and
full CI have current pass/fail evidence.

```text
IMAGE_BUILD_BLOCKED_UNTIL_CODE_PHYSICAL_CI_PASS=YES
N1B_SKIP_TO_IMAGE_BUILD=NO
```

## Touch-first non-regression requirements

For shared code changes, the PR must answer:

```text
DOES_THIS_TOUCH_PANTHER_DEFAULTS=YES_OR_NO
DOES_THIS_CHANGE_TOUCH_FIRST_HOME=YES_OR_NO
DOES_THIS_CHANGE_SOFT_KEYBOARD_PATH=YES_OR_NO
DOES_THIS_CHANGE_PANTHER_BUILD_PROCEDURE=YES_OR_NO
DOES_THIS_CHANGE_SHARED_APP_UI=YES_OR_NO
```

If any answer is `YES`, Panther/touch-first validation must be attached before
promotion.

## Keyboard-first requirements

For Titan 2 / N1B work, the PR must answer:

```text
DOES_THIS_REQUIRE_PHYSICAL_KEYBOARD=YES_OR_NO
DOES_THIS_AFFECT_SETUP_WIZARD=YES_OR_NO
DOES_THIS_AFFECT_LOCKSCREEN_TEXT_ENTRY=YES_OR_NO
DOES_THIS_AFFECT_SYSTEM_DIALOG_TEXT_ENTRY=YES_OR_NO
DOES_THIS_USE_TITAN2_HARDWARE_ASSUMPTIONS=YES_OR_NO
```

If hardware assumptions are used, they must be bound to Titan 2 profile evidence,
not encoded as common defaults.

## Build lane requirements

N1B must keep public build paths fail-closed until qualified.

```text
PUBLIC_TITAN2_BUILD_IMAGE=NO_UNTIL_QUALIFIED
PUBLIC_TITAN2_FLASH=NO_UNTIL_QUALIFIED
PRODUCTION_SIGNING=NO
ANDROID17_BASELINE_PIVOT=NO
R7E_ANDROID16_BASELINE_PRESERVED=YES
```

## Required gate outcomes

```text
N1B_MULTI_PROFILE_NON_REGRESSION=PASS
PANTHER_TOUCH_FIRST_REFERENCE_PROTECTED=YES
KEYBOARD_FIRST_CHANGES_PROFILE_GATED=YES
COMMON_CODE_REQUIRES_TOUCH_AND_KEYBOARD_GATES=YES
TITAN2_N1B_DOES_NOT_MUTATE_PANTHER_DEFAULTS=YES
IMAGE_BUILD_BLOCKED_UNTIL_CODE_PHYSICAL_CI_PASS=YES
PUBLIC_BUILD_PATH_FAIL_CLOSED=YES
```
