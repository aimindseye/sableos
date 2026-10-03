# Titan 2 N1D/C3B current plan and assignments

Status: **current execution roadmap**
Updated: **2026-10-02 ET / 2026-10-03 UTC**

This document supersedes the N0/N1B/N1B2/N1C execution plans as the current
Titan 2 roadmap. Those older documents remain historical evidence and may still
be used for requirements, deployment lessons and acceptance criteria.

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

The current E3 run passed the cheap compatibility/product/module prerequisites
and entered the long fresh `systemimage` build. E3 is **running, not yet
sealed**.

```text
C3B_E3_STATUS=BUILD_RUNNING_NOT_YET_SEALED
C3B_E3_PREBUILD_QUALIFICATION=PASS
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
TARGET_FILES_AUTHORIZED=NO
OTA_AUTHORIZED=NO
PRODUCTION_SIGNING_AUTHORIZED=NO
RELEASE_ELIGIBLE=NO
```

Do not promote E3 to PASS until the final image/module/hash evidence is captured.

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

## P5 — Sable Reader v2 design track

P5 implementation is **not yet assigned**. Scope/design is being finalized
while P1-P4 proceed.

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

## Execution roadmap

| Phase | Purpose | Exit condition | State |
| --- | --- | --- | --- |
| E3 | first Sable-composed Titan 2 systemimage | exact system.img + five module membership + hashes | RUNNING |
| E4 | artifact seal and deployment readiness | image audit, partition fit, restore/fastbootd plan | NEXT |
| E5 | first physical C3B boot | boot + untouched baseline capture | NEXT |
| E6 | runtime baseline qualification | radio/input/display/camera/setup/security classified | AFTER E5 |
| E7 | evidence-driven compatibility peel | only reproduced runtime fixes admitted | AFTER E6 |
| E8A | core OS usability | Start, Keyboard, Setup, Settings, Hub/Messages, browser/files | PARALLEL SOURCE WORK |
| E8B | daily-driver apps/privacy | Phone, People, Mail, Calendar, Media, Weather, Reader, privacy surfaces | PLANNED |
| E8C | hardware enhancements | extended Camera, DisplayCompat, NFC/OTG/Cast/SubScreen/etc. | EVIDENCE-GATED |
| N1D Beta 1 | integrated daily-driver candidate | fresh image + full gates + physical acceptance | LATER |
| Release engineering | signing/OTA/public release | production custody and release gates | DEFERRED |

## Immediate sequence

```text
E3 completes
 -> seal exact artifact
 -> E4 deployment preflight
 -> explicit operator authorization
 -> E5 physical boot
 -> E6 read-only runtime baseline
 -> E7 smallest evidence-backed fixes

in parallel:

titan2-temp P1
 -> P2
 -> P3
 -> P4
 -> freeze four heads
 -> batched ai-g732 qualification
 -> canonical source admission

P5 Reader v2
 -> finalize scope/design
 -> separate implementation work package
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

Until explicitly advanced:

```text
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
TARGET_FILES_AUTHORIZED=NO
OTA_AUTHORIZED=NO
PRODUCTION_SIGNING_AUTHORIZED=NO
PUBLIC_RELEASE_AUTHORIZED=NO
```

A build PASS is not a device PASS and a device boot is not a production-support
claim.
