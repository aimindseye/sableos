# SableOS current status

Last updated: 2026-10-03 ET

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

## Superseding Titan 2 runtime-recovery checkpoint

The sealed N1D/C3B build evidence remains valid, but the first physical N1D
attempt did not establish a stable boot and entered a reboot loop. Therefore
the prior E5 -> E6 progression is suspended.

```text
N1D_PHYSICAL_RESULT=FAIL_REBOOT_LOOP
N1D_RUNTIME_PATCH_ALLOWLIST_COUNT=0
COUNT_ZERO_STATUS=PRIMARY_SUSPECT_NOT_PROVEN_ROOT_CAUSE
CURRENT_STOCK_FIRMWARE=V01.00.14
HISTORICAL_N1B_BOOT_FIRMWARE=V01.00.13
N1D_REFLASH=HOLD
E6_RUNTIME_BASELINE=HOLD
N1B_V010014_CONTROL=PENDING
N1E_BUILD_AUTHORIZED=NO_PENDING_N1B_CONTROL
N1E_FLASH_AUTHORIZED=NO
```

The next physical experiment is the exact sealed N1B system artifact on the
current V01.00.14 state using the already proven active-`system_a` fastbootd
path and the same first-boot data reset. A successful N1B boot isolates the
failure to the broad N1D system-side delta; it does not by itself prove that
`COUNT=0`, dm-verity or any one compatibility patch family is causal.

If N1B boots, N1E is the exact authoritative N1B generated
`treble_arm64_bvN` product and lunch identity plus only the five C3B apps.
It deliberately does not use the `sable_titan2` wrapper identity. N1E must
pass the reviewed G0 -> G1 -> G2 pre-flash qualification before device contact.
If N1B fails on V01.00.14, N1E is stopped and the firmware/boot-chain/current-
device-state delta becomes the active investigation.

See `docs/titan2/N1D_RUNTIME_RECOVERY_AND_N1E_CONTROL_PLAN.md`.

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

E3 and E4 are sealed PASS. E5A fresh read-only device-state revalidation is also sealed PASS. The owner has approved the bounded E5B mutation concept, but standardized execution remains held until the canonical flash plan seals the exact fastboot logical-image size and the execution scope is reconfirmed.

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
E5A_STATUS=PASS_REVIEW_READY_SEALED
E5A_EVIDENCE_TIMESTAMP_UTC=20261003T053441Z
E5A_CURRENT_SLOT=a
E5A_FASTBOOTD_IS_USERSPACE=yes
E5A_ALLOCATION_COMPLETE=YES
E5A_CAPACITY_SAFE=YES
E5A_REMAINING_HEADROOM_AFTER_PLANNED_GROWTH_BYTES=2954141696
E5B_AUTHORIZATION_PACKAGE=READY_FOR_MANUAL_AUTHORIZATION_ACTIVE_SYSTEM_PATH
E5B_OWNER_AUTHORIZATION=APPROVED_BOUNDED_ACTIVE_SYSTEM_SCOPE
E5B_STANDARD_ARTIFACT_REGISTRATION=IMPLEMENTED_PENDING_OPERATOR_RUN
E5B_STANDARD_FLASH_PLAN=PASS_SEALED_LOGICAL_BYTES_2994405376
E5B_STANDARD_FLASH_EXECUTION=QUALIFICATION_IN_PROGRESS_SCOPE_REAFFIRMATION_REQUIRED
E5B_FLASH_AUTHORIZED=NO_STANDARD_DRIVER_REMAINS_FAIL_CLOSED
```

E4 is sealed. E5A read-only device contact and the two required mode transitions are complete. E5B review and owner authorization are complete for the bounded active-system concept, but the standardized write path remains disabled until the canonical flash plan closes fastboot logical-size semantics.

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

E5A completed cleanly and left the phone in userspace fastbootd. The sealed
result is `PASS_REVIEW_READY` with complete logical-partition accounting,
idle/no snapshot update state, and 2954141696 bytes of measured total-`super`
headroom remaining after the planned active-system growth. The separate E5B
owner authorization was subsequently approved, subject to the exact bounded scope.

The first E5B offline package is superseded because it assumed a conventional inactive logical-system target. The corrected next step is offline-only active-system/COW/group analysis from the same sealed E5A evidence. No additional device contact is required.

## Titan 2 C3B E5B deployment-model correction

The first offline E5B package exposed `system_b=0`. Historical Titan 2 evidence
and the research repository confirm this is expected Virtual A/B behavior:
inactive dynamic logical partitions need not be materialized while slot A is
active.

The generic inactive-slot preference is superseded.

```text
TITAN2_VIRTUAL_AB_MODEL=METADATA_SLOTTED_ACTIVE_LOGICAL_MATERIALIZATION
CURRENT_SLOT=a
C3B_TARGET_LOGICAL_PARTITION=system_a
C3B_SLOT_POLICY=KEEP_CURRENT_SLOT_NO_SLOT_SWITCH
N1B_PROVEN_PATH=ACTIVE_SYSTEM_COW_CLEANUP_RESIZE_WRITE_FACTORY_RESET
N1B_FIRST_BOOT=PASS
N1C_WHOLE_SUPER_RESULT=FLASHED_BUT_BOOT_FAILED
C3B_WHOLE_SUPER_PRIMARY_PATH=NO
E5B_OWNER_AUTHORIZATION=APPROVED_BOUNDED_ACTIVE_SYSTEM_SCOPE
E5B_STANDARD_FLASH_PLAN_REQUIRED=YES
E5B_STANDARD_FLASH_EXECUTION=QUALIFICATION_IN_PROGRESS_SCOPE_REAFFIRMATION_REQUIRED
E5B_FACTORY_RESET_AUTHORIZED=NO
```

The corrected E5B package used the sealed E5A `lpdump` and Phase 11 `getvar all` to prove active-slot COW and group capacity. The owner then approved the bounded active-system mutation concept. The current next step is standardized `register-artifact` followed by standardized `flash-plan`; physical write execution remains fail-closed.

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

## Current developer deliverables

The product-source repository is now based on
`aimindseye/titan2-temp@4089c1274a9e4a402a2c617cc00a7c166112f195`
after the accepted P5E merge.

```text
DEVELOPER_B_PR_28=P5F_READER_RUNTIME_READINESS_DRAFT
PR_28_HEAD=e8a5ddd374a0d78ca175b2137cf73707150ca28a
PR_28_ANDROID_COMPILE=PENDING_OPERATOR
PR_28_LINT=PENDING_OPERATOR
PR_28_ANDROID_UNIT_TESTS=PENDING_OPERATOR
PR_28_MERGED_MANIFEST=PENDING_OPERATOR
PR_28_DEVICE_RUNTIME=NOT_RUN

DEVELOPER_A_PR_29=C3B_NON_READER_RUNTIME_READINESS_DRAFT
PR_29_HEAD=5468758dc42c372854fc6936e3800afc1ee33def
PR_29_STATIC_GATE=PASS_DEVELOPER
PR_29_MUTATION_TESTS=PASS_DEVELOPER
PR_29_ANDROID_OFFLINE=PENDING_OPERATOR
PR_29_DEVICE_RUNTIME=NOT_RUN
```

PR #28 includes Reader runtime-readiness tooling and bounded Reader source fixes,
so exact-head operator Android compile, lint, Android unit tests and merged-
manifest verification are required before admission. Warning counts must come
from the real lint XML rather than being invented. Device runtime remains a
separate later qualification.

PR #29 adds non-Reader runtime-readiness/evidence tooling and no feature code.
Its static/Python/mutation evidence is useful, but the Android-offline path must
be run by the operator with a base that precedes the Android source delta.
Neither draft is canonical runtime admission, and neither changes the
N1B -> N1E recovery order.

## Next execution order

```text
offline:
 -> bind the five N1E APK hashes from the sealed E2 bundle
 -> rerun the N1E qualification selftest on the real host

physical:
 -> exact sealed N1B on current V01.00.14
 -> same active-system_a deployment model
 -> factory reset
 -> boot + transient telemetry capture

if N1B PASS:
 -> capture authoritative N1B source/product state
 -> construct minimal N1E (N1B product + five apps only)
 -> capture N1E with the exact N1B lunch identity
 -> G0 -> G1
 -> build N1E systemimage
 -> ownership-preserving N1B/N1E extraction
 -> G2
 -> only then authorize N1E flash
 -> if N1E boots, resume controlled product-identity/runtime deltas
 -> E6 runtime baseline

if N1B FAIL:
 -> stop N1E
 -> investigate V01.00.13 -> V01.00.14 / boot-chain / current-state delta

parallel:
 -> operator-qualify PR #28 and PR #29 exact heads
 -> do not claim device runtime from either developer PR
```

## Historical execution plans

N0, N1A, N1B, N1B2, N1B3 and N1C documents/scripts are retained for historical
evidence and useful acceptance/deployment lessons. They are not the current
Titan 2 execution roadmap.

The current roadmap is
`docs/titan2/N1D_C3B_CURRENT_PLAN_AND_ASSIGNMENTS.md`.
