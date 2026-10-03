# SableOS current status

Last updated: 2026-10-02 ET / 2026-10-03 UTC

This file is the private integration repository's current execution authority.
Historical milestone documents remain evidence but do not override this file or
the active Titan roadmap.

## Executive state

```text
PANTHER=R9_REFERENCE_FROZEN
TITAN2_ACTIVE_ENGINEERING_LANE=N1D_C3B
TITAN2_E3_BUILD_SOURCE=caf98dde723d07a071d95aaa1ef27d578d3208d8
TITAN2_E3_STATUS=SEALED_PASS
TITAN2_ELITE=INDEPENDENT_PORTABILITY_TARGET_PENDING
Q27=RESEARCH
PRODUCTION_SIGNING=DEFERRED
```

## Panther reference

```text
R9_PANTHER_ACCEPTED_SOURCE=edf62e5bb08372a1395841d6cc5d78d3148a7695
R9_PANTHER_TARGET_FILES_SHA256=a0b359613c4f30e9a834fba212e0b044a97d63ed0537c59471c31b99b627d285
R9_PANTHER_PHYSICAL_ACCEPTANCE=PASS_WITH_PRESERVED_PLAY_STATE
```

Later documentation or Titan work does not change the accepted Panther image
identity.

## Titan 2 C3B state

C3A sealed the Restless/Treble public-functional control. C3B is the actual
SableOS baseline and does not inherit the Restless runtime patch stack.

C3B E1 is build-qualified:

```text
N1D_C3B_SYSTEMIMAGE=PASS
SYSTEM_SHA256=9ce0144220b3a5bf531a1b0da7ec97543a89c9181ab9d69b6390ea5a86ad45dd
SYSTEM_BYTES=2940891136
C3B_RUNTIME_PATCH_ALLOWLIST_COUNT=0
```

C3B E2 source admission is complete:

```text
PRODUCT_QUALIFIED_HEAD=769feb9b9f662deda2a9110e85d95bb6114ceace
PRODUCT_QUALIFIED_TREE=cf5c232be3bc79eec4bd30ee0a90ab9247852053
PRODUCT_MERGED_MAIN=dbbb96cc01a0e366ea56817b54028b5686cb4035
SOURCE_IMPORT_COMMIT=aafb543565c9d59ed5e0d9cda876aabb4967f8aa
SOURCE_IMPORT_FILE_COUNT=178
```

Canonical product identity:

```text
PRODUCT_NAME=sable_titan2
LUNCH_TARGET=sable_titan2-bp4a-userdebug
PRODUCT_DEVICE=tdgsi_arm64_ab
TARGET_COPY_OUT_PRODUCT=system/product
MODULE_COUNT=5
```

The five modules are Sable Keyboard, Camera, DisplayCompat, Setup helper and
RadioDiag.

E3 is sealed PASS. The exact image identity and evidence are recorded in the E3 evidence seal.

## Current HOME / IME policy

```text
SABLE_FIRST_PARTY_HOME_OWNER=Launcher3QuickStep
SABLESTART_ROLE=PRESENTATION_AND_STATE_SOURCE_HOSTED_IN_LAUNCHER3
STANDALONE_SABLELAUNCHER_RUNTIME=RETIRED
THIRD_PARTY_HOME_SELECTION_ALLOWED=YES
FORCE_SABLE_HOME_AFTER_USER_SELECTION=NO

SABLE_FIRST_PARTY_IME=SableKeyboard
SABLE_FACTORY_DEFAULT_IME=PENDING_CANONICAL_IR005
THIRD_PARTY_IME_SELECTION_ALLOWED=YES
FORCE_SABLE_IME_AFTER_USER_SELECTION=NO
```

## Parallel P1-P4 product train

Developer work stays in `aimindseye/titan2-temp`.

```text
BASE_MAIN=dbbb96cc01a0e366ea56817b54028b5686cb4035
P1=Sable Start keyboard-first source/handoff
P2=Sable Keyboard provisioning readiness
P3=SetupWizard2 keyboard/square-display integration preparation
P4=Weather city-management + keyboard-first closure
```

The developer proceeds P1 -> P4 without waiting for ai-g732. Each stage is
frozen separately and not merged. After P4, the operator runs one batched
exact-head ai-g732 qualification session across all four stages before admission.

P5 Sable Reader v2 architecture is accepted. It is a sibling implementation track: local-first keyboard-first EPUB/PDF, CBZ comics/manga/webtoons and audiobooks; Text Reader remains separate. Remote AI/account sync is excluded from P5. See docs/SABLE_READER_V2_ARCHITECTURE.md.

The 23-screen titan2-temp/apps/titan2/screens catalog is now explicitly retained as a design/reference baseline, not a runtime product. See docs/titan2/SABLESCREENS_REFERENCE_BASELINE.md.

## Titan 2 C3B E3 image

```text
N1D_C3B_E3_SYSTEMIMAGE=PASS
N1D_C3B_E3_SYSTEM_SHA256=998a8b99cd4d1a631006291a96c6f0160c5a4400c4bf6bba62c319c4ed3c82a5
N1D_C3B_E3_SYSTEM_BYTES=2994405376
N1D_C3B_E3_MODULES_IN_SYSTEM_TREE=PASS count=5
N1D_C3B_E3_POSTBUILD_PACKAGING_ARTIFACTS=PASS_ABSENT
N1D_C3B_E3_DEVICE_CONTACT_AUTHORIZED=NO
N1D_C3B_E3_RELEASE_ELIGIBLE=NO
```

E3 is sealed. E4 artifact/deployment readiness is next; flash remains unauthorized.

## Titan 2 C3B E4 deployment readiness

```text
N1D_C3B_E4_DEPLOYMENT_READINESS=PASS_REVIEW_READY
N1D_C3B_E4_DIRECT_FIT=NO
N1D_C3B_E4_PLANNED_SYSTEM_TARGET_BYTES=3263168512
N1D_C3B_E4_PLANNED_SYSTEM_GROWTH_BYTES=2506727424
N1D_C3B_E4_ESTIMATED_REMAINING_SUPER_HEADROOM_BYTES=3003637760
N1D_C3B_E4_STOCK_SUPER_RESOLUTION=PASS
N1D_C3B_E4_STOCK_BOOT_AVB_RESOLUTION=PASS count=6
N1D_C3B_E4_STOCK_RESTORE_PROOF=PASS
E5A_DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY
E5A_REBOOT_BOOTLOADER_AUTHORIZED=YES
E5A_REBOOT_FASTBOOTD_AUTHORIZED=YES
E5A_STATUS=AUTHORIZED_READY_TO_RUN
E5B_FLASH_AUTHORIZED=NO
```

E4 is sealed. E5A read-only device contact and the two required mode transitions are explicitly authorized. E5B remains unauthorized until the fresh E5A evidence is reviewed.

## Titan 2 C3B E5A authorization

```text
E5A_DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY
E5A_ADB_READONLY_AUTHORIZED=YES
E5A_FASTBOOT_READONLY_AUTHORIZED=YES
E5A_REBOOT_BOOTLOADER_AUTHORIZED=YES
E5A_REBOOT_FASTBOOTD_AUTHORIZED=YES
E5B_FLASH_AUTHORIZED=NO
E5B_ERASE_AUTHORIZED=NO
E5B_LP_MUTATION_AUTHORIZED=NO
E5B_AVB_MUTATION_AUTHORIZED=NO
E5B_SLOT_MUTATION_AUTHORIZED=NO
E5B_UNLOCK_LOCK_AUTHORIZED=NO
E5B_FACTORY_RESET_AUTHORIZED=NO
```

E5A may collect fresh state and leave the phone in fastbootd. E5B remains a
separate mutation authorization after fresh evidence review.

## Keyboard-first design closure

```text
DESIGN_KF_A_NOTIFICATION_ATTENTION_HUB=ACCEPTED
DESIGN_KF_B_SYSTEMUI_CONVERGENCE=ACCEPTED
DESIGN_KF_C_SABLE_TOOLS_CONSOLIDATION=ACCEPTED
DESIGN_KF_D_ALL_APPS_RESPONSIVE_POLISH=ACCEPTED
KEYBOARD_FIRST_V1_FOUNDATIONAL_DESIGN=COMPLETE
TITAN2_V1_PRODUCT_DESIGN=COMPLETE
```

Implementation remains queued until P1-P4 and P5 qualification completes. See
`docs/titan2/KEYBOARD_FIRST_DESIGN_IMPLEMENTATION_QUEUE.md`.


## P1-P4 prequalification review

Developer A froze P1-P4 candidate heads, but operator source review found one normalized-key semantic issue before ai-g732 qualification: Android cursor/list Home movement must not be conflated with system HOME. The canonical boundary is now published at `sableos-project/platform_sable@80e3097bdef4cd2d5cbfd8ebde16390c29767918`, `docs/NORMALIZED_KEY_INPUT_CONTRACT.md`.

```text
P1_P4_PREQUAL_RESTACK_REQUIRED=YES
P1_MOVE_HOME_SYSTEM_HOME_CONFLATION=FIX_REQUIRED
P1_P4_PLATFORM_SABLE_REBIND=80e3097bdef4cd2d5cbfd8ebde16390c29767918
AI_G732_P1_P4_BATCH_QUALIFICATION=HOLD_UNTIL_RESTACK
```

P2 Android glue remains specifically subject to the operator offline Android compile after the corrected stack is frozen. P4 canonical admission must also adopt the per-city Weather cache key before user-managed cities are runtime-safe.

## Next execution order

```text
E3 sealed
 -> E4 sealed PASS
 -> E5A read-only authorization GRANTED
 -> fresh device-state revalidation
 -> separate E5B mutation authorization
 -> E5 physical C3B boot
 -> E6 read-only runtime baseline
 -> E7 smallest evidence-backed compatibility changes
 -> E8 product closure waves
 -> N1D Beta 1 integrated daily-driver candidate
 -> production signing/OTA later

parallel:
P1 -> P2 -> P3 -> P4 -> freeze heads -> batched ai-g732 qualification
P5 Reader v2 -> accepted architecture -> separate P5A-P5F implementation train
```

## Historical execution plans

N0, N1A, N1B, N1B2, N1B3 and N1C documents/scripts are retained for historical
evidence and useful acceptance/deployment lessons. They are not the current
Titan 2 execution roadmap.

The current roadmap is
`docs/titan2/N1D_C3B_CURRENT_PLAN_AND_ASSIGNMENTS.md`.
