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
N1B_V010014_CONTROL=RETIRED_UNEXECUTABLE_EXACT_ARTIFACT_AND_SOURCE_OBJECTS_UNAVAILABLE
N1B_EXACT_RECONSTRUCTION=RETIRED_PROVIDER_CONFIRMED_BOTH_CRITICAL_OBJECTS_NOT_ADDRESSABLE
N1B_PROVIDER_OBJECT_EXISTENCE=BLOCKED_BOTH_EXACT_OBJECTS_NOT_ADDRESSABLE
N1E_STATUS=RETIRED_EXACT_N1B_PREREQUISITE_UNAVAILABLE
C3A_V010014_CONTROL=PASS_BOOT_QUALIFIED
C3A_V010014_OFFLINE_EVIDENCE_SEAL=e6ad9a20192ef7c1fcb8bf0bfc1f393afd8b9cdd7239cb19b0497512f4f8fd57
C3A_V010014_LIVE_PREFLIGHT=ANDROID_ENTRY_PATH_NOT_USABLE_DEVICE_BOOTLOOPING
C3A_V010014_FASTBOOT_ENTRY_PREFLIGHT=PASS_READY_FOR_PHYSICAL_CONTROL_REVIEW
C3A_V010014_FASTBOOT_ENTRY_EVIDENCE_SEAL=47f28c371f13974d3a7303dc550014502401fae55a76bb365139f29e4c2da893
C3A_V010014_FASTBOOT_ENTRY_ACTIVE_COW_COUNT=0
C3A_V010014_FASTBOOT_ENTRY_REMAINING_HEADROOM_BYTES=3070332928
C3A_V010014_SYSTEM_FLASH=PASS
C3A_V010014_ANDROID_BOOT=PASS
C3A_V010014_VOICE_REGISTRATION=PASS
C3A_V010014_DATA_REGISTRATION=PASS
C3A_V010014_NR_NSA_CAPABILITY=PASS
C3A_V010014_RADIO_POSTBOOT_STABILITY=ISSUE_RECOVERABLE_BY_RADIO_CYCLE
C3A_V010014_COMPATIBILITY_BASELINE=PASS
C3A_SYSTEM_SHA256=4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16
C3A_CONTROL_PATCH_COUNT=369
N1F_STATUS=PASS_C3A_DERIVED_C3B5_BOOT_AND_RUNTIME_PACKAGES
N1F_SYSTEM_SHA256=dc1f917d5892afc04c479907913eb27a436d5abd881377d3e24fd1d7eb46299a
N1F_SYSTEM_BYTES=3200540672
N1F_SYSTEM_GROWTH_BYTES=53563392
N1F_RUNTIME_PACKAGES=PASS_COUNT_5
N1F_ANDROID_BOOT=PASS
N1F_FLASH_TARGET=system_a
N1F_FACTORY_RESET_PERFORMED=NO
N1F_ARTIFACT_DIR=/srv/sable-build/artifacts/titan2/n1f-c3a-derived-c3b5/20261003T221350Z
N1F_C3A_HISTORY_DIR=/srv/sable-build/artifacts/titan2/c3a-boot-qualified/20261003T221350Z
N1F_RUN_EVIDENCE=/srv/sable-build/evidence/titan2/n1f-c3a-derived-c3b5-r2/20261003T221350Z
```

The exact N1B physical-control path is retired as unexecutable. The exact image
and target-files archive are absent from retained storage, the two critical
pinned source revisions are absent from surviving Repo object stores, and the
provider-specific probe confirms that neither exact source object is currently
addressable from its authentic recorded provider lineage.

No available image is relabeled as N1B, and N1E is retired rather than
redefined.

The next compatibility control is the already sealed C3A public-functional
Restless/TrebleDroid reproduction:

```text
C3A_SYSTEM_SHA256=4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16
C3A_SYSTEM_BYTES=3146977280
C3A_MANAGED_PROJECT_COUNT=991
C3A_CONTROL_PATCH_COUNT=369
C3A_CONTROL_FIDELITY=PUBLIC_FUNCTIONAL_REPRODUCTION
```

C3A is not a Sable release baseline and is not claimed to be bit-identical to
N1B. It is the strongest retained source-built control for testing whether the
current V01.00.14 device/vendor state still boots the broad public
Restless/TrebleDroid compatibility substrate.

C3A physically boots on V01.00.14 and is now the working compatibility
baseline for Titan 2. Voice, data and NR_NSA capability were observed; the
transient post-boot radio state loss is recoverable by one airplane-mode cycle
and is tracked separately.

N1F is complete and PASS. The exact C3A compatibility substrate plus exactly
the five admitted Sable product apps rebuilt successfully, produced a
3200540672-byte raw system image, flashed to system_a once, rebooted once,
completed Android boot, and exposed all five Sable packages at runtime.
No compatibility patch was added or removed and no factory reset was used.

The next Titan 2 engineering phase must therefore preserve this exact
C3A-derived compatibility substrate and advance only one additional Sable
integration layer at a time.

See `docs/titan2/N1F_C3A_DERIVED_C3B5_BUILD_FLASH.md`.



## Titan 2 stock-control recovery checkpoint

A stock-`system_a`-only control attempt is now explicitly retired. Flashing the
retained V01.00.14 `TEE14-large-reference/system.img` over the GSI composition
booted the device into recovery rather than Android. Recovery-mode ADB could not
transition the device into usable fastboot for the planned GSI restore.

The owner then performed a recovery factory reset. The device returned to the
complete Unihertz V01.00.14 factory image and USB debugging was re-enabled.

```text
STOCK_SYSTEM_ONLY_CONTROL=INVALID_MIXED_PARTITION_TEST
STOCK_SYSTEM_A_ONLY_FLASH_ALLOWED=NO
FACTORY_RESET_FROM_RECOVERY=PERFORMED
DEVICE_STATE=UNIHERTZ_V010014_FACTORY_IMAGE
USB_DEBUGGING=ENABLED
NEXT_ACTION=READ_ONLY_STOCK_TELEPHONY_CONTROL
GSI_REFLASH=HOLD_UNTIL_STOCK_CONTROL_CAPTURED
```

The retained N1G artifact is present at:

```text
/srv/sable-build/artifacts/titan2/n1g-sable-product-identity/20261003T222829Z/system.img
SHA256=ce399effa7771e6ef0f6a0e6fb2efb94b5e1cdf1d212694396ff69d5ebb01ff6
```

Do not infer active runtime identity from the vendor-side
`UP1A.231005.007` fingerprint. Stock V01.00.14 is a split-generation stack:
the recovered system fingerprint is Android 16 / BP2A while the vendor
fingerprint is Android 14 / UP1A.

A future stock restore must use the verified matched stock restore procedure,
not a standalone stock `system_a` flash.

## Titan 2 N1I-F stock telephony control

Fresh factory-reset V01.00.14 is now the canonical working telephony control.

```text
N1I_F_STOCK_CONTROL=PASS
STOCK_CELLULAR_DATA=PASS
STOCK_SMS_MMS_SEND_RECEIVE=PASS
STOCK_OUTGOING_VOICE=PASS
STOCK_INCOMING_VOICE=PASS
STOCK_DEFAULT_APN=fast.t-mobile.com
STOCK_DATA_VALIDATED=YES
STOCK_IMS_PACKAGE=com.mediatek.ims
STOCK_IMS_MMTEL_VALIDATED=YES
STOCK_IMS_REGISTRATION=PASS
STOCK_ERROR_UNSPECIFIED_COUNT=0
STOCK_REJECT_CAUSE_11_COUNT=0
STOCK_REJECT_CAUSE_13_COUNT=0
STOCK_REJECT_CAUSE_15_COUNT=0
GSI_DEFAULT_APN_OBSERVED=pwg
APN_SELECTION_DELTA_REQUIRES_INVESTIGATION=YES
OEM_IMS_CLOSURE_REQUIRES_INVESTIGATION=YES
MTK_IMS_INDICATION_NULL_AS_ROOT_CAUSE=REJECTED_BY_WORKING_STOCK_CONTROL
TRAY2_SINGLE_SIM_CONTROL=PENDING
DUAL_SIM_DSDS_CONTROL=PENDING
```

The raw stock capture is retained off-repo and hash-pinned. Git stores only the
sanitized engineering reference and sanitizer. See
`docs/titan2/evidence/N1I_F_STOCK_V010014_CONTROL_SANITIZED.md`.

The next GSI work must treat registration/data and IMS/voice as separate
deltas. Stock selects `fast.t-mobile.com` for the validated Internet bearer;
the failing GSI selected `pwg`. Stock also provides the OEM API-36
`com.mediatek.ims` closure and a validated IMS/MMTEL bearer.

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
C3A-first runtime-recovery control order.

## Next execution order

```text
offline:
 -> exact C3A artifact + V01.00.14 control plan = PASS / SEALED

physical read-only (completed PASS / sealed):
 -> phone is already in fastboot because N1D is bootlooping; do not require Android/ADB entry
 -> run C3A fastboot-entry device-binding / fastbootd / snapshot / COW / capacity preflight
 -> require target system_a, active COW count 0, active-group and super capacity safe
 -> leave phone in userspace fastbootd
 -> no write and no reset

offline (next):
 -> register exact C3A artifact and sealed prerequisites through the canonical registry
 -> generate and seal the standard C3A no-write plan
 -> stop after reporting the exact plan seal

later execution remains separately gated:
 -> exact sealed C3A system_a write only
 -> separate explicitly authorized factory reset if required
 -> boot + transient telemetry capture

if C3A PASS:
 -> record current vendor/device compatibility with broad C3A substrate
 -> capture exact derivative authority needed for N1F
 -> define N1F = C3A compatibility baseline + five C3B apps only
 -> qualify N1F before any flash

if C3A FAIL_OR_INCONCLUSIVE:
 -> review pinned published C2 RestlessOS prebuilt as independent second control
 -> do not relabel C2 as N1B or as a Sable baseline

parallel:
 -> operator-qualify developer PR #28 and #29 exact heads
 -> no developer PR may claim Titan device runtime yet
```

## Historical execution plans

N0, N1A, N1B, N1B2, N1B3 and N1C documents/scripts are retained for historical
evidence and useful acceptance/deployment lessons. They are not the current
Titan 2 execution roadmap.

The current roadmap is
`docs/titan2/N1D_C3B_CURRENT_PLAN_AND_ASSIGNMENTS.md`.
