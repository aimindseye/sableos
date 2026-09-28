# N1B Stage A fast-lane execution bundle

Status: **combined Stage A execution contract / no image work**

This document combines the approved N1B contracts into one Stage A execution
bundle so implementation can move quickly without breaking Panther / Pixel
touch-first behavior.

```text
N1B_STAGE_A_FAST_LANE_EXECUTION=YES
N1B_STAGE_A_COMBINED_PR_ALLOWED=YES
N1B_STAGE_A_ONE_PR_CAN_TOUCH_MULTIPLE_SURFACES=YES
N1B_STAGE_A_CODE_BUILD_FIRST=YES
N1B_STAGE_A_PHYSICAL_UX_AFTER_CODE_BUILD=YES
N1B_STAGE_A_FULL_CI_AFTER_PHYSICAL_UX=YES
N1B_STAGE_A_IMAGE_BUILD_LAST=YES
N1B_SKIP_TO_IMAGE_BUILD=NO
```

## Purpose

The fast lane is allowed to group related Stage A work into a single PR when the
work remains build-scoped and profile-gated. The goal is to avoid a long chain of
small contract-only PRs while keeping hard protection for Panther and
Graphene-supported devices.

```text
FAST_LANE_SCOPE=STAGE_A_CODE_BUILD_AND_STATIC_GATES
FAST_LANE_ALLOWED_TO_DEFINE_IMPLEMENTATION_ENTRYPOINTS=YES
FAST_LANE_ALLOWED_TO_RUN_APP_BUILDS=YES
FAST_LANE_ALLOWED_TO_MUTATE_IMAGE=NO
FAST_LANE_ALLOWED_TO_CONTACT_DEVICE=NO
FAST_LANE_ALLOWED_TO_FLASH=NO
```

## Source layout verified for Stage A app build root

The current integration repo exposes the R8 Android app build root at:

```text
N1B_STAGE_A_APP_BUILD_ROOT=apps/r8/android
N1B_STAGE_A_GRADLE_SETTINGS=apps/r8/android/settings.gradle.kts
N1B_STAGE_A_ROOT_PROJECT=sable-r8-apps
```

The current settings file includes these modules for the first fast-lane app
build sweep:

```text
:design
:calculator
:convert
:games
:media
:hub
:sablestart-presentation-check
:sablestart-visual-review
:weather
:calendar
```

The first fast-lane PR must not invent modules for Setup Wizard, Launcher3,
SystemUI, Reader/Text Reader source import, or Camera if those owners are not yet
present in this Gradle root.

## Android SDK preflight

When `RUN_GRADLE_BUILDS=YES`, the fast-lane driver must prove the Android SDK
before invoking module builds. The driver may use any of these read-only inputs:

```text
ANDROID_HOME
ANDROID_SDK_ROOT
apps/r8/android/local.properties sdk.dir
known local SDK roots
```

If no SDK is found, the driver must fail once with:

```text
N1B_STAGE_A_ANDROID_SDK=FAIL
N1B_STAGE_A_GRADLE_BUILDS=SKIPPED_ANDROID_SDK_PRECONDITION
```

It must not run every Gradle module and produce ten duplicate `SDK location not
found` failures. The driver must not create or modify `local.properties` because
Stage A fast-lane execution is read-only with respect to the local source tree.

## Combined Stage A surfaces

The fast lane groups these surfaces into one execution stream:

```text
SETUP_WIZARD_GRAPHENEOS_BASE_BINDING=REQUIRED
TITAN_KEYBOARD_FIRST_SETUP_EXTENSION_POINT=REQUIRED
SABLE_START_VISUAL_REVIEW_BUILD=REQUIRED
SABLE_START_PRESENTATION_CHECK_BUILD=REQUIRED
HUB_BUILD=REQUIRED
MESSAGES_PRODUCT_COMPOSITION_GATE=REQUIRED
MAIL_INTEGRATION_GATE=REQUIRED
CALENDAR_BUILD=REQUIRED
MEDIA_BUILD=REQUIRED
WEATHER_BUILD=REQUIRED
CALCULATOR_BUILD=REQUIRED
CONVERT_LEGACY_BUILD=REQUIRED_UNTIL_REMOVED
GAMES_BUILD=REQUIRED
DESIGN_SYSTEM_BUILD=REQUIRED
PANTHER_TOUCH_PROFILE_PROTECTION=REQUIRED
TITAN_KEYBOARD_PROFILE_PROTECTION=REQUIRED
```

## Setup Wizard dual-lane binding

Stage A fast lane must preserve the PR #140 decision:

```text
GRAPHENEOS_SETUPWIZARD2_UPSTREAM_OWNER_FOUND=YES
GRAPHENEOS_SETUPWIZARD2_MODULE=SetupWizard2
GRAPHENEOS_SETUPWIZARD2_PACKAGE=app.grapheneos.setupwizard
PIXEL_GRAPHENE_SETUPWIZARD2_BASE_PRESERVED=YES
PANTHER_SETUP_BEHAVIOR_UNCHANGED_UNLESS_EXPLICIT=YES
TITAN_KEYBOARD_FIRST_SETUP_EXTENSION_REQUIRED=YES
SABLE_SETUPWIZARD_LOCAL_OWNER_REQUIRED_FOR_TITAN_EXTENSION=YES
```

The fast-lane driver may only bind or detect GrapheneOS SetupWizard2 source. It
must not silently fork the setup flow, rename the package, replace the Pixel
setup flow, or claim a Titan keyboard-check implementation unless that code owner
is added and compiled in the same PR.

## Required Panther protection

Every combined Stage A implementation PR must preserve:

```text
PANTHER_TOUCH_FIRST_REFERENCE_PROTECTED=YES
KEYBOARD_FIRST_CHANGES_PROFILE_GATED=YES
COMMON_CODE_REQUIRES_TOUCH_AND_KEYBOARD_GATES=YES
TITAN2_N1B_DOES_NOT_MUTATE_PANTHER_DEFAULTS=YES
PIXEL_GRAPHENE_SETUP_BUILD_REGRESSION_GATE_REQUIRED=YES
```

## Required blockers

The fast lane must keep these blockers until real implementation/build evidence
exists:

```text
N1B_SETUP_WIZARD_IMAGE_BLOCKER=YES
N1B_STAGE_B_BLOCKED_UNLESS_STAGE_A_PASS=YES
N1B_STAGE_C_BLOCKED_UNLESS_STAGE_B_PASS=YES
N1B_STAGE_D_BLOCKED_UNLESS_STAGE_C_PASS=YES
IMAGE_BUILD_BLOCKED_UNTIL_CODE_PHYSICAL_CI_PASS=YES
PUBLIC_BUILD_PATH_FAIL_CLOSED=YES
```

## Guardrails

```text
DOCUMENTATION_AND_DRIVER_ONLY=YES
IMAGE_BUILD_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
ADB_COMMANDS_RUN=NO
FASTBOOT_COMMANDS_RUN=NO
PUBLIC_RELEASE=NO
PRODUCTION_SIGNING=NO
ANDROID17_BASELINE_PIVOT=NO
TITAN_TOUCHPAD_DAEMON_ENABLED=NO
```
