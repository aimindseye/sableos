# N1B promotion sequence

Status: **approved planning contract / documentation-only**

N1B must follow the approved sequence:

```text
1. build SableOS code
2. validate physical UX
3. run full CI
4. build code/images
```

This sequence is mandatory. Image build must not become the first proof that
product code is valid.

```text
N1B_PROMOTION_SEQUENCE_REQUIRED=YES
DOCUMENTATION_ONLY=YES
BUILD_CODE_CHANGED=NO
DEVICE_CODE_CHANGED=NO
IMAGE_BUILD_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
```

## Stage A — Build SableOS code

Purpose: prove app/product code builds before physical UX or image composition.

```text
N1B_STAGE_A_CODE_BUILD=PASS_REQUIRED
IMAGE_BUILD_ALLOWED=NO
DEVICE_CONTACT_ALLOWED=NO
FLASH_ALLOWED=NO
```

Expected checks:

```text
Hub / Messages / Mail
Launcher / Start / All Apps
Settings / policy surfaces
Setup Wizard / first-run code if implemented in-tree
Quick Settings / SystemUI code if included
Reader / Text Reader
Media / Gallery
Weather
Contacts / Phone
Camera if included
Kotlin/Java compile
assembleDebug or equivalent app/module build
lint where available
unit tests where available
```

## Stage B — Validate physical UX

Purpose: validate shared Sable UX after code builds and before full CI promotion.

```text
N1B_STAGE_B_PHYSICAL_UX=PASS_REQUIRED
IMAGE_BUILD_ALLOWED=NO
FLASH_ALLOWED=NO
```

Physical validation may use the available physical reference for shared Sable
surfaces. Titan 2 device-contact validation requires separate explicit approval.

Minimum UX checklist:

```text
Setup Wizard / first-run mock or physical path where available
Lockscreen / secure text-entry path where available
Sable Start / launcher
All Apps favorites and permission summaries
Search / Peek / app security Back flow
Hub people and connected-app favorites
single visible Messages product
Mail handoff from Hub
Contacts and Phone contact entry
Reader theme behavior
Media density behavior
Weather city management if included
Quick Settings / Notification Shade theme/branding if included
Browser / Vanadium label
dark/light/accent propagation
keyboard-first navigation and focus
```

## Stage C — Run full CI

Purpose: ensure all repository gates pass after physical UX feedback has been
incorporated.

```text
N1B_STAGE_C_FULL_CI=PASS_REQUIRED
IMAGE_BUILD_ALLOWED=NO_UNTIL_PASS
```

The promotion CI must run after Stage B changes. Earlier CI is useful but does
not replace the final promotion gate.

## Stage D — Build code/images

Purpose: compose and build the N1B Android 16 Restless image only after Stage A,
Stage B and Stage C have passed.

```text
N1B_STAGE_D_IMAGE_BUILD=PASS_REQUIRED
```

Output requirements:

```text
system.img
target-files.zip
image-sha256s.txt
package inventory
Sable app inventory
design traceability snapshot
issue inclusion snapshot
device gate snapshot
artifact qualification result
```

## Stage E — Artifact qualification

Before any device action:

```text
N1B_ARTIFACT_QUALIFICATION=PASS_REQUIRED
ANDROID16_R7E_BASELINE_CONFIRMED=YES
R7E_DEVIATIONS_RECORDED=YES
SABLE_APPS_INCLUDED=YES
TRACEABILITY_MARKERS_PRESENT=YES
NO_PRIVATE_SOURCE_REFS=YES
NO_ADB_FASTBOOT_FLASH_ACTIVITY=YES
```

## Device action gate

Any Titan 2 load/flash work remains blocked until a later explicit decision:

```text
DEVICE_CONTACT_AUTHORIZED=YES_EXPLICIT_USER_APPROVAL_REQUIRED
FLASH_AUTHORIZED=YES_EXPLICIT_USER_APPROVAL_REQUIRED
STOCK_RESTORE_READY=YES
AVB_STRATEGY_EXPLICIT=YES
USERDATA_POLICY_EXPLICIT=YES
SERIAL_BOUND_COMMANDS_REQUIRED=YES
```

## Acceptance

```text
N1B_PROMOTION_SEQUENCE=PASS
N1B_STAGE_A_CODE_BUILD_BEFORE_PHYSICAL_UX=YES
N1B_STAGE_B_PHYSICAL_UX_BEFORE_FULL_CI=YES
N1B_STAGE_C_FULL_CI_BEFORE_IMAGE_BUILD=YES
N1B_STAGE_D_IMAGE_BUILD_LAST=YES
N1B_SKIP_TO_IMAGE_BUILD=NO
```
