# Panther touch-first non-regression contract

Status: **required guard for N1B and later keyboard-first work**

This document protects the accepted Pixel 7 / Panther touch-first reference while
Titan 2 becomes the first keyboard-first SableOS device. Keyboard-first work may
share common Sable app semantics, but it must not silently change Panther default
UX, build procedures, profile assumptions, or accepted reference behavior.

```text
PANTHER_TOUCH_FIRST_REFERENCE_PROTECTED=YES
PANTHER_ROLE=FROZEN_TOUCH_FIRST_REFERENCE
PANTHER_PROFILE=TOUCH_FIRST
KEYBOARD_FIRST_DEFAULTS_DISABLED_ON_PANTHER=YES
TITAN2_N1B_DOES_NOT_MUTATE_PANTHER_DEFAULTS=YES
COMMON_CODE_REQUIRES_TOUCH_AND_KEYBOARD_GATES=YES
PUBLIC_BUILD_PATH_FAIL_CLOSED=YES
```

## Authority

Panther remains the frozen touch-first reference and regression/security/product
comparison baseline. N1B Titan 2 work does not replace Panther evidence and does
not create a new Panther image authority.

```text
PANTHER_IMAGE_AUTHORITY_UNCHANGED=YES
N1B_TITAN2_IMAGE_AUTHORITY_SEPARATE=YES
PROFILE_PASS_INHERITANCE=NO
```

## Protected Panther assumptions

Common Sable app semantics may evolve, but touch-first defaults must remain
explicit and testable.

Protected Panther defaults:

```text
TOUCH_FIRST_HOME_PATH=REQUIRED
TOUCH_GESTURE_NAVIGATION_PRESERVED=YES
SOFT_KEYBOARD_NORMAL_PATH_PRESERVED=YES
SQUARE_KEYBOARD_LAYOUT_DEFAULT=NO
PHYSICAL_KEYBOARD_REQUIRED_FOR_SETUP=NO
TITAN2_SIDE_KEY_DEFAULTS_APPLIED_TO_PANTHER=NO
TITAN2_TOUCHPAD_DAEMON_INCLUDED_ON_PANTHER=NO
TITAN2_KEYLAYOUT_MUTATION_ON_PANTHER=NO
TITAN2_SUBSCREEN_POLICY_ON_PANTHER=NO
```

## PR requirements for shared code

Any PR touching shared launcher, Hub, Settings, SystemUI, Setup Wizard,
Lockscreen, Reader, Media, Weather, Phone, Contacts, Browser/WebView, app
composition, or build gates must state how Panther remains protected.

Required PR evidence:

```text
PANTHER_TOUCH_PROFILE_IMPACT_REVIEWED=YES
KEYBOARD_PROFILE_IMPACT_REVIEWED=YES
PANTHER_DEFAULT_BEHAVIOR_CHANGED=NO_OR_EXPLICIT
PANTHER_BUILD_PROCEDURE_CHANGED=NO_OR_EXPLICIT
PANTHER_RUNTIME_PROFILE_SWITCH_REQUIRED=NO
COMMON_CODE_PROFILE_GATED=YES
```

If a shared change intentionally affects Panther, it must not hide behind a Titan
workstream. It needs its own Panther acceptance evidence and clear issue/PR scope.

## Build and validation posture

Before a Titan N1B image build can be treated as promotion-ready, Panther
non-regression must have a current status. The exact validation depth may differ
by phase, but it must not be absent.

Required markers:

```text
PANTHER_APP_MODULE_BUILD=REQUIRED_FOR_SHARED_APP_CHANGES
PANTHER_TOUCH_UX_VALIDATION=REQUIRED_FOR_SHARED_UX_CHANGES
PANTHER_FULL_CI=REQUIRED_BEFORE_SHARED_RELEASE_CLAIM
PANTHER_IMAGE_BUILD_NOT_REQUIRED_FOR_TITAN_ONLY_DOCS=YES
```

## Non-goals

This document does not require every Titan-only documentation change to rebuild
Panther. It requires that common-code changes and shared UX changes cannot merge
or promote without an explicit Panther impact decision.

```text
FORCE_PANTHER_IMAGE_BUILD_FOR_DOCS_ONLY=NO
ALLOW_UNGATED_COMMON_UI_MUTATION=NO
ALLOW_TITAN_PROFILE_DEFAULTS_ON_PANTHER=NO
ALLOW_PANTHER_RELEASE_AUTHORITY_DRIFT=NO
```

## Acceptance checklist

```text
PANTHER_TOUCH_FIRST_NON_REGRESSION=PASS
PANTHER_TOUCH_FIRST_REFERENCE_PROTECTED=YES
KEYBOARD_FIRST_CHANGES_PROFILE_GATED=YES
COMMON_CODE_REQUIRES_TOUCH_AND_KEYBOARD_GATES=YES
TITAN2_N1B_DOES_NOT_MUTATE_PANTHER_DEFAULTS=YES
PUBLIC_BUILD_PATH_FAIL_CLOSED=YES
```
