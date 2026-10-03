# Titan 2 N1D/C3B current plan and assignments

Status: **current execution roadmap**
Updated: **2026-10-03 ET**

This document supersedes the N0/N1B/N1B2/N1C execution plans as the current
Titan 2 roadmap. Those older documents remain historical evidence and may still
be used for requirements, deployment lessons and acceptance criteria.

## Runtime-recovery override

C3A is physically boot-qualified on current Titan 2 firmware V01.00.14.
Restless/TrebleDroid compatibility is therefore the immediate runtime
foundation for the next isolation experiment rather than the earlier plain
C3B image.

```text
C3A_SYSTEM_SHA256=4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16
C3A_SYSTEM_BYTES=3146977280
C3A_CONTROL_PATCH_COUNT=369
C3A_V010014_COMPATIBILITY_BASELINE=PASS

N1F_ROLE=C3A_DERIVED_C3B5_BOOT_ISOLATION
N1F_COMPATIBILITY_PATCH_DELTA=0
N1F_SABLE_MODULE_COUNT=5
N1F_DRIVER=build/titan2/run-n1f-c3a-derived-c3b5.sh
```

The single current operator sequence is:

```text
archive boot-qualified C3A history
 -> build five admitted Sable APKs offline
 -> stage seven files + one C3A rom.mk inherit
 -> incremental C3A systemimage
 -> verify exact five system/product packages
 -> preserve derived system.img + hashes
 -> restore C3A source delta
 -> enter/verify fastbootd, slot a, snapshot none, zero active COWs
 -> flash system_a once
 -> reboot once
 -> observe boot
```

Factory reset is not part of the first N1F attempt. No telephony remediation is
included in this image; the observed radio-state issue remains a separate
runtime investigation.


## Current state

### Panther reference

Pixel 7 / Panther R9 remains the frozen touch-first reference.

```text
R9_PANTHER_ACCEPTED_SOURCE=edf62e5bb08372a1395841d6cc5d78d3148a7695
R9_PANTHER_TARGET_FILES_SHA256=a0b359613c4f30e9a834fba212e0b044a97d63ed0537c59471c31b99b627d285
R9_PANTHER_PHYSICAL_ACCEPTANCE=PASS_WITH_PRESERVED_PLAY_STATE
PANTHER_ROLE=FROZEN_TOUCH_FIRST_REFERENCE
```

### Titan 2 C3B

The current canonical engineering source for the first Sable-composed Titan 2
system image is:

```text
C3B_E3_BUILD_SOURCE=caf98dde723d07a071d95aaa1ef27d578d3208d8
PRODUCT=sable_titan2
LUNCH=sable_titan2-bp4a-userdebug
DEVICE=tdgsi_arm64_ab
TARGET_COPY_OUT_PRODUCT=system/product
```

C3A is sealed as a public-functional Restless/Treble control. It is not the
SableOS runtime/security baseline.

C3B E1 is build-qualified:

```text
N1D_C3B_SYSTEMIMAGE=PASS
SYSTEM_SHA256=9ce0144220b3a5bf531a1b0da7ec97543a89c9181ab9d69b6390ea5a86ad45dd
SYSTEM_BYTES=2940891136
C3B_RUNTIME_PATCH_ALLOWLIST_COUNT=0
```

C3B E2 source admission is complete. The canonical product imports five
source-built modules:

```text
SableTitan2Keyboard
SableTitan2Camera
SableTitan2DisplayCompat
SableTitan2Setup
SableTitan2RadioDiag
```

E3 completed successfully and is **sealed PASS**. The exact system image, five-module membership, hash, size and evidence path are recorded in `docs/titan2/N1D_C3B_E3_SYSTEMIMAGE_EVIDENCE.md` and `build/titan2/n1d-c3b-e3-systemimage-evidence.env`.

```text
C3B_E3_STATUS=SEALED_PASS
C3B_E3_PREBUILD_QUALIFICATION=PASS
C3B_E3_SYSTEM_SHA256=998a8b99cd4d1a631006291a96c6f0160c5a4400c4bf6bba62c319c4ed3c82a5
C3B_E3_SYSTEM_BYTES=2994405376
DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY_E5A
E5B_OWNER_AUTHORIZATION=APPROVED_BOUNDED_ACTIVE_SYSTEM_SCOPE
E5B_STANDARD_FLASH_EXECUTION=BLOCKED_PENDING_PLAN_AND_SCOPE_RECONFIRMATION
FLASH_AUTHORIZED=NO_STANDARD_DRIVER_REMAINS_FAIL_CLOSED
TARGET_FILES_AUTHORIZED=NO
OTA_AUTHORIZED=NO
PRODUCTION_SIGNING_AUTHORIZED=NO
RELEASE_ELIGIBLE=NO
```

E3 is sealed. Do not reinterpret this as flash, device-contact, OTA, target-files or release authorization.

## E4 operator package

E4 is now defined as an offline/read-only deployment-readiness gate. It consumes
the sealed E3 image plus historical read-only fastbootd and proven stock-restore
evidence. It does not contact the Titan 2.

Expected sizing classification:

```text
DIRECT_FIT=NO
PLANNED_SYSTEM_TARGET_BYTES=3263168512
ESTIMATED_REMAINING_SUPER_HEADROOM_BYTES=3003637760
PARTITION_FIT=PASS_RESIZE_CAPACITY_APPEARS_AVAILABLE_REVIEW_REQUIRED
```

This remains plan-only; fresh device state is required before any future resize
or flash authorization.

See `docs/titan2/N1D_C3B_E4_DEPLOYMENT_READINESS.md`.

## E4 sealed result

```text
N1D_C3B_E4_DEPLOYMENT_READINESS=PASS_REVIEW_READY
SYSTEM_SHA256=998a8b99cd4d1a631006291a96c6f0160c5a4400c4bf6bba62c319c4ed3c82a5
DIRECT_FIT=NO
PLANNED_SYSTEM_TARGET_BYTES=3263168512
PLANNED_SYSTEM_GROWTH_BYTES=2506727424
ESTIMATED_REMAINING_SUPER_HEADROOM_BYTES=3003637760
STOCK_SUPER_RESOLUTION=PASS
STOCK_BOOT_AVB_RESOLUTION=PASS count=6
STOCK_RESTORE_PROOF=PASS
```

E5A read-only device contact and the Android->bootloader->fastbootd transitions are explicitly authorized. E5B physical deployment remains a separate mutation authorization after E5A review.

See:
- `docs/titan2/N1D_C3B_E4_DEPLOYMENT_READINESS_EVIDENCE.md`
- `docs/titan2/N1D_C3B_E5_MANUAL_AUTHORIZATION_CHECKPOINT.md`

## E5A authorization

The operator/user explicitly authorized fresh read-only Titan 2 device-state
revalidation, including the reboots required to reach userspace fastbootd.

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

E5A reuses the audited N1B Phase 10A/10B and Phase 11 read-only collectors,
then applies a C3B-specific offline qualifier. It intentionally leaves the
device in fastbootd after evidence capture.

See `docs/titan2/N1D_C3B_E5A_READONLY_DEVICE_STATE.md`.

## E5A sealed result

Fresh E5A device-state revalidation completed cleanly from canonical operator
head `602fca81ffc43e8731342b96b6945ab9ef9642b6`.

```text
N1D_C3B_E5A_READONLY_DEVICE_STATE=PASS_REVIEW_READY
N1D_C3B_E5A_CURRENT_SLOT=a
N1D_C3B_E5A_FASTBOOTD_IS_USERSPACE=yes
N1D_C3B_E5A_FASTBOOTD_UNLOCKED=yes
N1D_C3B_E5A_ALLOCATION_BASIS=GETVAR_ALL_LOGICAL_PARTITIONS_COMPLETE
N1D_C3B_E5A_ALLOCATION_COMPLETE=YES
N1D_C3B_E5A_FRESH_SUPER_HEADROOM_BYTES=5460250624
N1D_C3B_E5A_PLANNED_SYSTEM_TARGET_BYTES=3263168512
N1D_C3B_E5A_REMAINING_HEADROOM_AFTER_PLANNED_GROWTH_BYTES=2954141696
N1D_C3B_E5A_CAPACITY_SAFE=YES
N1D_C3B_E5A_SNAPSHOT_UPDATE_REVIEW=PASS_IDLE_OR_NONE
N1D_C3B_E5A_FINAL_DEVICE_MODE=FASTBOOTD
```

See `docs/titan2/N1D_C3B_E5A_EVIDENCE.md`.

The first offline package's inactive-slot assumption is superseded. The corrected package passed and the owner approved the bounded active-system mutation concept. Standardized execution remains held until canonical artifact registration and flash-plan seal the exact fastboot logical-image size. Titan 2 Virtual A/B does not guarantee a materialized inactive `system_b`. The corrected package binds to the proven N1B active-system path and evaluates current-slot COW cleanup plus active-group/total-super capacity from sealed E5A evidence.

## Developer deliverables at the recovery checkpoint

```text
TITAN2_TEMP_P5E_BASE=4089c1274a9e4a402a2c617cc00a7c166112f195
PR_28=P5F_READER_RUNTIME_READINESS_DRAFT
PR_28_HEAD=e8a5ddd374a0d78ca175b2137cf73707150ca28a
PR_28_OPERATOR_ANDROID=REQUIRED
PR_28_DEVICE_RUNTIME=NOT_RUN

PR_29=C3B_NON_READER_RUNTIME_READINESS_DRAFT
PR_29_HEAD=5468758dc42c372854fc6936e3800afc1ee33def
PR_29_STATIC_MUTATION=PASS_DEVELOPER
PR_29_OPERATOR_ANDROID_OFFLINE=REQUIRED
PR_29_DEVICE_RUNTIME=NOT_RUN
```

Keep both PRs draft until their operator-side qualifications are attached.
PR #28 changed Reader Kotlin/test sources and therefore needs exact-head Android
compile/lint/unit/merged-manifest verification. PR #29 adds readiness tooling,
matrices and docs only; its delegated Android-offline path still needs an
operator run with the correct pre-Android-source base. Neither PR authorizes device contact or changes the canonical C3A-first compatibility-control sequence.

## Assignment model

Two lanes proceed in parallel.

### Canonical engineering lane

Owner: SableOS maintainer/operator.

Responsibilities:

- finish and seal E3;
- image membership and artifact audit;
- E4 deployment-readiness / partition-fit / restore preflight;
- explicit flash authorization package;
- E5 first physical C3B boot and untouched baseline capture;
- E6 runtime qualification for radio, input, display, camera, setup and security;
- E7 evidence-driven runtime compatibility admission;
- canonical Android-tree integration of accepted product-source work;
- SELinux, privileged permissions, radio/IMS/QNS/IWLAN, signing and release
  policy.

The runtime compatibility rule remains:

```text
reproduce failure
 -> identify smallest cause
 -> review security/runtime impact
 -> admit bounded change
 -> focused qualification
 -> fresh image
 -> physical evidence
```

Do not import the Restless patch stack wholesale.

### Parallel product developer lane

Repository: `aimindseye/titan2-temp`

Base for P1:

```text
main=dbbb96cc01a0e366ea56817b54028b5686cb4035
tree=cf5c232be3bc79eec4bd30ee0a90ab9247852053
```

The developer may proceed continuously through P1-P4 without waiting for
ai-g732 after each stage.

Required stacked sequence:

```text
main@dbbb96cc
  -> P1 Sable Start keyboard-first source/handoff
  -> P2 Sable Keyboard first-boot/default provisioning readiness
  -> P3 SetupWizard2 keyboard/square-display integration preparation
  -> P4 Weather city-management + keyboard-first closure
```

Each stage must be frozen and independently reviewable before the next stage is
branched. Do not merge the train yet.

After P4, the operator runs one batched ai-g732 qualification session against
the exact frozen P1, P2, P3 and P4 heads. Each stage must independently pass.
A later stage may not retroactively repair an invalid earlier stage.

#### P1 — Launcher3-hosted Sable Start

Deliver reusable keyboard-first interaction/focus/type-to-search source and
tests for canonical Launcher3/Launcher3QuickStep-hosted Sable Start.

Required boundaries:

```text
SABLE_FIRST_PARTY_HOME_OWNER=Launcher3QuickStep
STANDALONE_SABLELAUNCHER_RUNTIME=RETIRED
THIRD_PARTY_HOME_SELECTION_ALLOWED=YES
FORCE_SABLE_HOME_AFTER_USER_SELECTION=NO
```

No standalone HOME APK and no Titan model branching.

#### P2 — Sable Keyboard provisioning readiness

Prepare product-side source/contracts for Sable Keyboard as the factory first
party IME while preserving user selection of third-party IMEs.

Do not force IME selection from application code. Canonical IR-005 remains an
Android product/platform integration responsibility.

#### P3 — SetupWizard2 integration preparation

Keep GrapheneOS SetupWizard2 as the first-boot base. Sable Setup remains a
post-provisioning helper, not a second Setup Wizard.

Prepare keyboard-first, square-display, Wi-Fi/password/account/SIM non-dead-end
behavior and fallback contracts. Runtime integration stays canonical.

#### P4 — Weather closure

Implement user-managed city add/remove, persistence, selected-city persistence,
reset-to-defaults, manual city management without precise-location permission
and complete physical-keyboard operation. Common Weather must not become a
Titan-only fork.

## SableScreens design baseline

The early aimindseye/titan2-temp/apps/titan2/screens 23-screen Compose catalog is now an explicit design/reference baseline. It is not a shipping app and must not be counted as runtime completion. See docs/titan2/SABLESCREENS_REFERENCE_BASELINE.md for the 23-screen convergence map. P1 and P3 consume it directly; P2 consumes its shared input/focus semantics; P4 Weather is additive because Weather was not one of the 23 surfaces.

## P5 — Sable Reader v2 implementation track

P5 architecture/UX/format/dependency choices are now **accepted**. P5 is a separate sibling implementation track and must not be stacked into the P1-P4 train. See docs/SABLE_READER_V2_ARCHITECTURE.md.

Current accepted direction:

```text
Sable Reader
  ebooks / PDF-style reading
  comics / manga / webtoon reading
  audiobooks

Sable Text Reader
  remains a separate lightweight text/TTS/accessibility product
```

Reader v2 is common Sable application architecture, not a Titan-specific fork.

Planned comic direction is local-first and Mihon-inspired at the product/UX
level: library/categories, reading progress, paged/continuous/webtoon modes,
LTR/RTL reading, bookmarks and local backup. Start with formats whose dependency
and licensing posture is clear, such as CBZ/image collections. Do not import an
unreviewed executable extension ecosystem.

Planned audiobook direction includes MediaSession/background playback,
chapters, resume position, speed, skip controls, sleep timer and bookmarks.

Keyboard-only operation is a first-class acceptance requirement across books,
comics and audiobooks.

## Keyboard-first design implementation queue

DESIGN-KF-A through DESIGN-KF-D are now accepted and implementation-ready, but
remain intentionally unassigned until the current P1-P4 and P5 trains finish.

```text
DESIGN-KF-A  Notification Policy + Attention + Hub ownership        ACCEPTED
DESIGN-KF-B  SystemUI visual/convergence                            ACCEPTED
DESIGN-KF-C  Sable Tools / Toolbox consolidation                    ACCEPTED
DESIGN-KF-D  All Apps privacy row + responsive app polish           ACCEPTED
```

Public authority:
`sableos-project/platform_sable@80e3097bdef4cd2d5cbfd8ebde16390c29767918`.

Private assignment/sequence authority:
`docs/titan2/KEYBOARD_FIRST_DESIGN_IMPLEMENTATION_QUEUE.md`.

Recommended future assignment after qualification:
Developer A -> KF-D-I -> KF-A-I -> KF-B-I; Developer B -> KF-C-I1..I5.


## P1-P4 prequalification review

Developer A froze P1-P4 candidate heads, but operator source review found one normalized-key semantic issue before ai-g732 qualification: Android cursor/list Home movement must not be conflated with system HOME. The canonical boundary is now published at `sableos-project/platform_sable@80e3097bdef4cd2d5cbfd8ebde16390c29767918`, `docs/NORMALIZED_KEY_INPUT_CONTRACT.md`.

```text
P1_P4_PREQUAL_RESTACK_REQUIRED=YES
P1_MOVE_HOME_SYSTEM_HOME_CONFLATION=FIX_REQUIRED
P1_P4_PLATFORM_SABLE_REBIND=80e3097bdef4cd2d5cbfd8ebde16390c29767918
AI_G732_P1_P4_BATCH_QUALIFICATION=HOLD_UNTIL_RESTACK
```

P2 Android glue remains specifically subject to the operator offline Android compile after the corrected stack is frozen. P4 canonical admission must also adopt the per-city Weather cache key before user-managed cities are runtime-safe.

## Execution roadmap

| Phase | Purpose | Exit condition | State |
| --- | --- | --- | --- |
| E3 | first Sable-composed Titan 2 systemimage | exact system.img + five module membership + hashes | **PASS / SEALED** |
| E4 | artifact seal and deployment readiness | image audit, partition fit, restore/fastbootd plan | **PASS / SEALED** |
| Recovery-C3A | current-firmware compatibility control | exact sealed C3A + fresh physical boot evidence | **LIVE READ-ONLY PREFLIGHT NEXT** |
| N1F | C3A-derived minimal five-app isolation | defined only after C3A boot + provenance capture | **RESERVED / NOT AUTHORIZED** |
| E6 | runtime baseline qualification | radio/input/display/camera/setup/security classified | **HOLD UNTIL BOOT-QUALIFIED BASELINE** |
| E7 | evidence-driven compatibility peel | only reproduced runtime fixes admitted | AFTER E6 |
| E8A | core OS usability | Start, Keyboard, Setup, Settings, Hub/Messages, browser/files | PARALLEL SOURCE WORK |
| E8B | daily-driver apps/privacy | Phone, People, Mail, Calendar, Media, Weather, Reader, privacy surfaces | PLANNED |
| E8C | hardware enhancements | extended Camera, DisplayCompat, NFC/OTG/Cast/SubScreen/etc. | EVIDENCE-GATED |
| N1D Beta 1 | integrated daily-driver candidate | fresh image + full gates + physical acceptance | LATER |
| Release engineering | signing/OTA/public release | production custody and release gates | DEFERRED |

## Immediate sequence

```text
N1D physical reboot loop recorded
 -> exact N1B/N1E path retired
 -> C3A offline compatibility-control preparation PASS / SEALED
 -> fresh C3A live read-only preflight
 -> require same Titan 2 binding, slot a, fastbootd, no snapshot, zero active COWs
 -> require active-group + total-super capacity PASS
 -> separately review/authorize exact C3A system_a write
 -> separately authorize factory reset if required
 -> capture C3A boot outcome + transient telemetry
 -> if C3A boots: define N1F minimal five-app isolation
 -> if C3A fails/inconclusive: review pinned C2 as second control

in parallel:

titan2-temp P1
 -> P2
 -> P3
 -> P4
 -> freeze four heads
 -> batched ai-g732 qualification
 -> canonical source admission

P5 Reader v2
 -> P5A baseline/privacy/library model
 -> P5B EPUB/PDF keyboard UX
 -> P5C comics/manga/webtoon
 -> P5D audiobooks
 -> P5E unified backup/quality
 -> P5F exact-head ai-g732 qualification
```

## Historical-plan rule

The following families are historical execution evidence, not current
authority:

```text
N0*
N1A*
N1B*
N1B2*
N1B3*
N1C*
```

They must not be deleted merely because they are superseded. They may contain
useful acceptance criteria and deployment lessons. New work must use this
roadmap, `CURRENT_STATUS.md`, accepted ADRs and the current C3B source as the
execution authority.

## Safety boundaries

Current authorization boundary:

```text
DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY_E5A
E5A_REBOOT_BOOTLOADER_AUTHORIZED=YES
E5A_REBOOT_FASTBOOTD_AUTHORIZED=YES
FLASH_AUTHORIZED=NO
TARGET_FILES_AUTHORIZED=NO
OTA_AUTHORIZED=NO
PRODUCTION_SIGNING_AUTHORIZED=NO
PUBLIC_RELEASE_AUTHORIZED=NO
```

A build PASS is not a device PASS and a device boot is not a production-support
claim.
