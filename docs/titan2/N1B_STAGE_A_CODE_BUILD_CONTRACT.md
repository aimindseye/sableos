# N1B Stage A code-build contract

Status: **contract / implementation prerequisite**

N1B Stage A is the first implementation stage after the N1B traceability and
multi-profile non-regression contracts. It proves that SableOS application,
profile and product code can build before physical UX validation, full CI, or
image composition starts.

```text
N1B_STAGE_A_CODE_BUILD_CONTRACT=YES
N1B_STAGE_A_IMAGE_BUILD=NO
N1B_STAGE_A_DEVICE_CONTACT=NO
N1B_STAGE_A_FLASH=NO
N1B_STAGE_A_PUBLIC_RELEASE=NO
```

## Required promotion order

N1B must keep the approved sequence:

```text
1_BUILD_SABLEOS_CODE=STAGE_A
2_VALIDATE_PHYSICAL_UX=STAGE_B
3_RUN_FULL_CI=STAGE_C
4_BUILD_CODE_IMAGES=STAGE_D
```

Stage A is complete only when the required code-build gates pass. It does not
authorize image build, device contact, ADB, fastboot, flashing, public release,
or production signing.

```text
N1B_STAGE_A_BEFORE_PHYSICAL_UX=YES
N1B_STAGE_A_BEFORE_FULL_CI=YES
N1B_STAGE_A_BEFORE_IMAGE_BUILD=YES
N1B_SKIP_TO_IMAGE_BUILD=NO
```

## Profile boundary

N1B Stage A must protect non-keyboard devices while adding keyboard-first
capability for Titan 2.

```text
PANTHER_TOUCH_FIRST_REFERENCE_PROTECTED=YES
KEYBOARD_FIRST_CHANGES_PROFILE_GATED=YES
COMMON_CODE_REQUIRES_TOUCH_AND_KEYBOARD_GATES=YES
TITAN2_N1B_DOES_NOT_MUTATE_PANTHER_DEFAULTS=YES
```

Touch-first defaults must remain the default for Panther and other non-keyboard
devices unless a PR explicitly changes the touch-first profile and passes the
Panther non-regression gate.

Keyboard-first behavior must be selected by profile or device configuration, not
by global app defaults that affect Panther.

## Stage A module families

Stage A code build must cover the module families that make N1B a useful
keyboard-first SableOS testbed.

```text
N1B_STAGE_A_MODULE_MATRIX_REQUIRED=YES
N1B_STAGE_A_MODULE_INVENTORY_REQUIRED=YES
N1B_STAGE_A_EXACT_BUILD_COMMANDS_REQUIRED=YES
```

Required module families:

```text
SETUP_WIZARD_FIRST_BOOT=REQUIRED
CRITICAL_TEXT_ENTRY_PLUMBING=REQUIRED
SABLE_START_LAUNCHER=REQUIRED
ALL_APPS_PRIVACY_SUMMARY=REQUIRED
ALL_APPS_APP_FAVORITES=REQUIRED
SABLE_COMMAND_SEARCH=REQUIRED
SABLE_HUB=REQUIRED
MESSAGES_PRODUCT_COMPOSITION=REQUIRED
SABLE_MAIL_INTEGRATION=REQUIRED
CONTACTS_PHONE_PEOPLE=REQUIRED
QUICK_SETTINGS_NOTIFICATION_SHADE=REQUIRED_OR_EXPLICIT_DEFER
LOCKSCREEN_SECURE_ENTRY=REQUIRED_OR_EXPLICIT_DEFER
BROWSER_WEBVIEW_IDENTITY=REQUIRED
READER_TEXT_READER=REQUIRED_OR_EXPLICIT_DEFER
MEDIA_GALLERY=REQUIRED_OR_EXPLICIT_DEFER
WEATHER_UTILITIES=REQUIRED_OR_EXPLICIT_DEFER
SETTINGS_PROFILE_POLICY=REQUIRED
SABLE_KEYBOARD_IME_BOUNDARY=REQUIRED_OR_EXPLICIT_DEFER
SABLE_CAMERA=REQUIRED_OR_EXPLICIT_DEFER
```

A required-or-explicit-defer item may be deferred only with a tracked reason,
owner, issue, and replacement validation note. Silent omission is not allowed.

## Minimum implementation checks

Every N1B implementation PR after this contract must declare which module family
it modifies and which profile gates it affects.

```text
N1B_STAGE_A_PR_DECLARES_MODULE_FAMILY=YES
N1B_STAGE_A_PR_DECLARES_PROFILE_IMPACT=YES
N1B_STAGE_A_PR_DECLARES_PANTHER_IMPACT=YES
N1B_STAGE_A_PR_DECLARES_TITAN2_IMPACT=YES
```

The implementation branch must produce or update a module inventory before Stage
A can pass:

```text
N1B_STAGE_A_MODULE_INVENTORY_PATH=docs/titan2/N1B_STAGE_A_MODULE_INVENTORY.tsv
```

The inventory should include:

```text
module_family
repo_path
build_command
profile_scope
panther_gate
titan2_gate
status
defer_reason
issue_or_doc_reference
```

## Expected code-build lanes

Stage A should use focused build lanes before the full CI gate.

```text
LANE_1_SHARED_APP_BUILD=YES
LANE_2_TOUCH_FIRST_PANTHER_PROFILE_BUILD=YES
LANE_3_KEYBOARD_FIRST_TITAN2_PROFILE_BUILD=YES
LANE_4_STATIC_CONTRACT_GATES=YES
```

The exact commands may evolve with implementation, but the Stage A result must
record the final commands and outputs. Initial command families should include:

```text
GRADLE_COMPILE_REQUIRED=YES
GRADLE_ASSEMBLE_REQUIRED=YES
LINT_WHERE_AVAILABLE=YES
UNIT_TESTS_WHERE_AVAILABLE=YES
STATIC_PROFILE_GATES_REQUIRED=YES
```

## Mandatory acceptance markers

Stage A cannot pass unless the implementation result records these markers:

```text
N1B_STAGE_A_CODE_BUILD=PASS
N1B_STAGE_A_SHARED_APP_BUILD=PASS
N1B_STAGE_A_PANTHER_NON_REGRESSION_BUILD=PASS
N1B_STAGE_A_TITAN2_KEYBOARD_PROFILE_BUILD=PASS
N1B_STAGE_A_SETUP_WIZARD_BUILD=PASS
N1B_STAGE_A_CRITICAL_TEXT_ENTRY_BUILD=PASS
N1B_STAGE_A_ALL_APPS_PRIVACY_BUILD=PASS
N1B_STAGE_A_HUB_BUILD=PASS
N1B_STAGE_A_MESSAGES_MAIL_BUILD=PASS
N1B_STAGE_A_PROFILE_GATES=PASS
```

If a marker is intentionally deferred, Stage A must record:

```text
DEFER_MARKER=<marker>
DEFER_REASON=<bounded reason>
DEFER_OWNER=<repo/path/issue>
DEFER_STAGE=<Stage B/C/N1C/N2>
```

## Stage A blockers

The following states block Stage A promotion:

```text
PANTHER_TOUCH_FIRST_REFERENCE_BROKEN=BLOCK
KEYBOARD_FIRST_DEFAULTS_GLOBALIZED=BLOCK
SETUP_WIZARD_OMITTED=BLOCK
CRITICAL_TEXT_ENTRY_OMITTED=BLOCK
HUB_MESSAGES_MAIL_UNBOUND=BLOCK
ALL_APPS_PRIVACY_SUMMARY_OMITTED=BLOCK
DUPLICATE_MESSAGES_EXPOSURE_UNRESOLVED_WITHOUT_DEFER=BLOCK
IMAGE_BUILD_ATTEMPTED_BEFORE_STAGE_A_PASS=BLOCK
DEVICE_CONTACT_ATTEMPTED=BLOCK
FLASH_ATTEMPTED=BLOCK
```

## Non-goals

```text
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

## Relationship to prior contracts

This contract depends on the merged N1B traceability and multi-profile
non-regression contracts.

```text
N1B_PLATFORM_SABLE_TRACEABILITY_REQUIRED=YES
SABLE_MULTI_PROFILE_CONTRACT_REQUIRED=YES
PANTHER_TOUCH_FIRST_NON_REGRESSION_REQUIRED=YES
N1B_MULTI_PROFILE_NON_REGRESSION_REQUIRED=YES
```

## Exit criteria

Stage A exits only when SableOS code builds for the required app/profile lanes
and the result is recorded with exact commands and evidence paths.

```text
N1B_STAGE_A_EXIT_CODE_BUILD_PASS=REQUIRED
N1B_STAGE_A_EXIT_MODULE_INVENTORY=REQUIRED
N1B_STAGE_A_EXIT_NO_IMAGE_BUILD=REQUIRED
N1B_STAGE_A_EXIT_NO_DEVICE_CONTACT=REQUIRED
N1B_STAGE_A_READY_FOR_STAGE_B_PHYSICAL_UX=YES_AFTER_PASS
```
