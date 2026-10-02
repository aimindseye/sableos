# SableOS roadmap

Last updated: 2026-09-19

## Roadmap rule

SableOS advances through independently testable security, capability and product gates.

A milestone is complete only when its implementation, policy boundary, build integration, generated artifacts and relevant physical behavior are validated. New product/security features must not silently remove working Android capability.

Portable semantic contracts should remain stable while Android-version/device integration is requalified behind bounded adapters.

The current project priority is to build the SableOS user experience. Production signing/OTA infrastructure is preserved but temporarily non-blocking until release-candidate work.

## 2026-09-19 final Pixel UI closure overlay

The active engineering sequence has changed after the first sandbox-qualified full UI build was flashed successfully but exposed incomplete application/product composition. The build and preserved-data deployment pipeline is proven; the next full Panther build is blocked until the complete R8 UI set is integrated and audited.

```text
R8-A shared design/appearance/accessibility closure
    -> production Metro SableStart reconciliation
    -> R8-D2 OCR completion
    -> exact artifact freeze for Calculator/Games/Reader/Media
    -> Panther PRODUCT_PACKAGES/prebuilt/source integration
    -> UI4/UI5/UI6 source-identity verification
    -> generated product-composition gate
    -> targeted/incremental compile gates
    -> one fresh sandbox-qualified Panther build
    -> preserved-data physical flash
    -> full Pixel UI/runtime acceptance
    -> Titan 2 N0 UI/portability work
```

Read-only Titan 2 T0 stock/device inventory may proceed in parallel as soon as hardware is available. Titan GSI mutation/flash waits for Panther final UI closure.

Canonical gate: `R8_PIXEL_UI_PRODUCT_CLOSURE.md`.

## 2026-09-18 execution overlay

Current execution has moved onto the R8 standalone application and qualification track. The older Sable Flow/M1 product sequence remains architectural context, but the active engineering handoff is now:

```text
R8 application implementation/build preparation
    -> standalone CI qualification
    -> exact artifact freeze
    -> product integration gates
    -> Panther/Titan development qualification
    -> release/security hardening
         -> INFRA5 encrypted trusted runner
         -> production signing/key custody
         -> signed OTA/release closure
```

INFRA5 is **deferred and non-blocking**. The current `ai-g732` Sable storage is unencrypted, therefore the INFRA4 policy continues to prohibit trusted self-hosted execution. GitHub-hosted CI remains the current qualification authority. Build-host encryption, ephemeral trusted-runner activation and production signing should be revisited together when release-candidate hardening becomes active.

This is a scheduling decision only; INFRA4's fail-closed security requirement remains unchanged. See `INFRA5_DEFERRED_TRUSTED_RUNNER.md`.

## Current progression

```text
validated Android 17 Panther substrate
    -> Sable Flow shared UI primitives
    -> Sable Start M1 shell
    -> Phone / People / Messages vertical slice
    -> Sable Hub provider framework
    -> isolated social-service capsules
    -> broader native apps / Search / Security / polish
    -> Titan 2 N0 GSI/userspace/UI portability lab when Panther is ready
    -> Q27 full-QWERTY evaluation when shipped hardware qualifies
    -> release-candidate composition
    -> production signing / OTA / rollback closure
```

A later layer must not paper over an unproven earlier layer.

## Current snapshot

```text
PANTHER_D4                          CLOSED / PASS
SABLEOS_PRODUCT_DEVELOPMENT        ACTIVE
SABLEOS_CORE_PRODUCT_STAGE         R8_FINAL_UI_PRODUCT_CLOSURE
SABLE_FLOW_STATUS                  IMPLEMENTED_IN_REPO_PRODUCT_INTEGRATION_PENDING
NEXT_PRODUCT_MILESTONE             R8_FINAL_UI_PRODUCT_COMPOSITION_PASS

NON_PIXEL_ASSURANCE_MODEL          N0_GSI_USERSPACE_LAB -> N1_INTEGRATED_VENDOR_BSP_PORT -> N2_PRODUCTION_QUALIFIED
TITAN2_ROLE                        T0_READ_ONLY_ON_ARRIVAL_THEN_N0_AFTER_PANTHER_UI_CLOSURE
Q27_ROLE                           FUTURE_FULL_QWERTY_CANDIDATE_PENDING_QUALIFICATION
Q25_ROLE                           OPTIONAL_MEDIATEK_KERNEL_DEVICE_RESEARCH

R1_RELEASE_SIGNING_WORK            PAUSED_NON_BLOCKING
INFRA5_TRUSTED_RUNNER              DEFERRED_NON_BLOCKING
TRUSTED_SELF_HOSTED_RUNNER         DISABLED
SOURCE_BUILD_STORAGE_ENCRYPTED     NO
PRODUCTION_KEYS_GENERATED          NO
KEY_GENERATION_AUTHORIZED          NO
SIGNING_AUTHORIZED                 NO
OTA_GENERATION_AUTHORIZED          NO
SIGNING_HOST_SELECTION             DEFERRED
```

## Historical substrate/service milestones

### S0 — Android security baseline uplift

Status: **PASS / HISTORICAL BRAMBLE BASELINE**.

The original bramble development substrate established the Android 14 baseline, capability inventory and security ceiling used to prove the early narrow Sable service architecture.

Detailed evidence remains in `S0_*` records.

### S1.1–S1.6 — narrow Sable power/service architecture

Status: **PASS / FROZEN ON BRAMBLE REFERENCE**.

Key outcomes:

- dedicated `oxynoded` SELinux domain;
- semantic power state separated from physical backend;
- Health-backed architecture rather than direct battery sysfs;
- callback-driven power monitoring;
- nonfatal HAL failure/recovery behavior;
- Android logging and lifecycle cleanup.

### S1.7 — frozen read-only power API

Status: **PASS / FROZEN**.

Frozen contract:

```text
com.sableos.power.IPowerService/default
    getLatestState() -> PowerSnapshot
```

Properties:

- read-only semantic state;
- explicit availability;
- battery percentage / charging / stable source enum;
- monotonic externally visible sequence;
- no Health handle;
- no raw sysfs;
- no mutation methods.

Authorized/unauthorized client behavior and callback-to-AIDL physical transitions were proven on bramble. See `S1_7_VALIDATION.md`.

### S1.8 historical UI/toolchain qualification

Status: **BRAMBLE QUALIFICATION CLOSED / LESSONS RETAINED**.

The historical Android 14 Rust/Cargo 1.68 branch proved that UI-framework choice must not be permanently constrained by an old platform compiler. Slint and other candidates were bounded/tested; further dependency down-rev work for the end-of-life bramble branch was stopped.

The accepted rule remains:

```text
modern UI toolchain
    -> stable C / NDK / AIDL boundary
    -> Android/Sable semantic services
```

Do not use compiler-private cross-version Rust ABI.

## Panther Android 17 track

### P0 / P0R1 / P1A / P1B

Status: **HISTORICAL BRING-UP / QUALIFICATION EVIDENCE**.

These milestones selected and bounded the Pixel 7 / Android 17 substrate, audited generation/toolchain dependencies and established the modern Panther development path.

The earlier pure-AOSP workspace is no longer the canonical active product substrate.

### Panther D4

Status: **CLOSED / PASS**.

Canonical physical-development outcome:

```text
Pixel 7 / panther
Android 17 / SDK 37
GrapheneOS 2026081300-derived audited substrate
B2 target-files flashed successfully
shared userdata preserved
BuildManifest identity PASS
ART identity PASS_5_OF_5
slot B current/bootable/successful PASS
broad functional acceptance PASS
```

D4 release gate:

```text
PASS=56
FAIL=0
SKIP=8
MANUAL=0
ERROR=0
OVERALL=PASS
```

NFC RF tag read remains a non-blocking external-hardware validation gap; framework/service/HAL/enable/routing passed.

See `PANTHER_D4_CLOSURE_20260908.md`.

## Product track — Sable Flow

The normative product model is `CORE_PRODUCT_MODEL.md`. The concrete implementation plan is `SABLE_FLOW_AND_HUB_PRODUCT_PLAN.md`.

Product principle:

> **Applications provide capabilities; Sable organizes people, attention and actions.**

### M1 / CP1 — Sable Flow primitives + Sable Start

Status: **NEXT**.

Target: Panther.

Deliverables:

```text
Sable Flow typography/theme tokens
vertical tile-grid engine
tile lifecycle + live-tile data contract
pivot/section navigation
motion/transitions
privacy/redaction states
accessibility semantics
focus/keyboard hooks
Sable Start development launcher
Phone tile
People tile
Messages tile
Settings tile
Social Hub placeholder tile
```

Launcher3 stays available as a development fallback until Sable Start replacement qualification passes.

M1 acceptance requires normal Android lifecycle/task behavior, deterministic build provenance, no unnecessary privileged authority, accessibility, restart recovery and Panther physical validation.

### M2 / CP2 — Phone / People / Messages vertical slice

Status: **PLANNED AFTER M1**.

Phone:

- Sable UI over Android Telecom/Telephony;
- call history/missed calls/callback actions;
- no direct modem protocol implementation.

People:

- ContactsProvider-backed presentation;
- local people identity graph;
- user-confirmed ambiguous cross-source associations.

Messages:

- Sable SMS/MMS presentation;
- mature Android/carrier transport retained;
- bounded communication timeline;
- live/unread state and privacy redaction.

### M3 / CP3 — Sable Hub provider framework

Status: **PLANNED**.

Provider classes:

```text
NATIVE_DATA
ANDROID_NOTIFICATION
SUPPORTED_API
WEB
UNAVAILABLE
```

Capabilities:

```text
MESSAGING
FEED
PROFILE
CONTACTS
SHARE
NOTIFICATIONS
DEEP_LINK
WEB_SESSION
```

Requirements:

- capability registry;
- provider lifecycle/account state;
- notification/conversation ingestion;
- application-authorized actions;
- local people linking;
- bounded history;
- explicit privacy/data-flow disclosure;
- separate provider session/storage boundaries;
- no private third-party application-database scraping.

### M4 / CP4 — social-service capsules

Status: **PLANNED**.

Initial targets:

```text
WhatsApp
Instagram
Facebook
LinkedIn
```

Sable does not assume these services expose a complete supported native consumer API. Provider capabilities must be verified against current official documentation at implementation time.

Where needed, use isolated web capsules with independent session/cookie/storage state. The Hub must label web/API/native capability honestly.

### M5 / CP5 — broader native apps + Search/Security

Status: **PLANNED**.

Candidate Sable-facing surfaces:

```text
Camera
Photos
Clock
Calculator
Calendar
Files
Notes
Browser
```

Reuse mature Android capability underneath where appropriate.

Also advance:

- Search / Command;
- Secure Package Intelligence;
- application security/privacy transparency;
- higher-value Sable Settings surfaces.

### M6 / CP6 — AOD / Voice / Agent

Status: **PLANNED AFTER CORE SHELL/HUB FOUNDATION**.

AOD remains presentation over supported Android display/doze/power architecture.

Voice/Agent remain local-first and capability-bounded:

```text
text / voice
    -> semantic intent
    -> typed capability request
    -> narrow Sable/Android service
```

No generic privileged shell or unrestricted other-app private-data authority.

## Interaction/form-factor track

### Panther touch-first

Status: **ACTIVE REFERENCE**.

Sable Flow establishes:

- live information/action tiles;
- large typography/spatial hierarchy;
- low-chrome surfaces;
- fast peek/act/return interaction;
- touch/gesture semantics;
- accessibility and multilingual behavior.

### Unihertz Titan 2

Status: **PREFERRED INTERIM NON-PIXEL N0 LAB AFTER PANTHER**.

Titan 2 is intended first as a GSI/userspace/UI laboratory, not a production-security target. Initial work should preserve the stock kernel, vendor, firmware and boot-chain substrate while qualifying:

- physical keyboard/focus/navigation behavior;
- larger QWERTY form-factor Sable Flow layouts;
- Android framework/application portability;
- stock vendor/HAL compatibility;
- data/5G/IMS behavior as separate observations rather than assumed support.

Keyboard-device product extensions accepted on 2026-10-02:

- Sable Camera Control Deck: portrait remains supported, while landscape uses a
  viewfinder-first physical-keyboard control surface with transient parameter
  strips, AF/AE lock, focus-point movement and complete touch fallback;
- Sable Keyboard D6 backlog: compact input strip, configurable SYM/emoji/snippet
  surfaces and local dictionary/prediction improvements;
- Pastiera 0.86 is a pinned GPL-3.0 behavior/product reference only, not a Sable
  source dependency;
- Sable Start and Sable Keyboard remain factory/first-party defaults while
  third-party HOME and IME selection stays allowed through Android's normal
  user-choice model.

These extensions are non-blocking and must not delay C3B image/radio/security
qualification. See ADR-0012 and `CAMERA_ENHANCEMENT_ROADMAP.md`.

A successful GSI boot remains `N0_GSI_USERSPACE_LAB`. It does not imply Sable-owned kernel security maintenance, full firmware lifecycle ownership, relocked verified boot or supported production OTA. See `TITAN2_GSI_PLAN.md`.

### Zinwa Q25

Status: **OPTIONAL SOURCE-AVAILABLE MEDIATEK/KERNEL RESEARCH REFERENCE**.

Q25 may validate lower-level areas which Titan 2 cannot if Titan 2 kernel/BSP source is unavailable:

- MediaTek kernel/device-tree work;
- source-level module and boot integration;
- compact/square layout constraints;
- physical keyboard/focus/navigation semantics.

Q25 is not a required first non-Pixel purchase and is not a prerequisite for Q27. It must reuse the common Sable Start/Hub semantic model rather than creating a product fork. See `Q25_PORT_PLAN.md`.

### Zinwa Q27

Status: **FUTURE PREFERRED MODERN FULL-QWERTY CANDIDATE**.

Q27 remains subject to shipped-hardware qualification of source/BSP/vendor/bootloader/security/radio/power/firmware/update behavior. Sable Flow and Hub are deliberately being designed now so Q27 can consume the same semantic model later.

Q27 does not inherit support status from Titan 2 or Q25. It must independently qualify the N2 requirements if it is ever proposed as a production-supported device.

See `NON_PIXEL_MEDIATEK_ARCHITECTURE.md`, `NON_PIXEL_DEVICE_ROADMAP.md`, and `NON_PIXEL_RELEASE_VALIDATION.md`.

## Non-Pixel assurance model

Non-Pixel ports use explicit assurance classes so functional progress is not confused with security ownership:

```text
N0_GSI_USERSPACE_LAB
    -> stock kernel/vendor/firmware retained
    -> userspace/UI/framework portability work

N1_INTEGRATED_VENDOR_BSP_PORT
    -> device/product/VINTF/SELinux/vendor integration
    -> prebuilt kernel/BSP permitted when explicitly classified
    -> vendor ABI shims and firmware inputs versioned and tested

N2_PRODUCTION_QUALIFIED
    -> production verified-boot/signing posture
    -> supported OTA/rollback/recovery
    -> complete kernel/vendor/firmware security-lifecycle claim
    -> full physical hardware and telephony acceptance
```

A prebuilt-kernel/BSP target can be a valuable N0/N1 engineering platform but is not equivalent to independent Sable kernel-security ownership. Platform, kernel, vendor, modem, TEE, bootloader and connectivity firmware provenance are tracked separately. Production AVB configuration fails closed if required production keys or verification settings are missing.

The Brax3/iodéOS review is a device-port reference for these rules, not a SableOS security baseline. See `BRAX3_IODEOS_REFERENCE.md`.

## Security/product tracks after shell foundation

### S2 — Secure Package Intelligence

Status: **PLANNED / ARCHITECTURE DEFINED**.

Areas:

- deterministic package analysis;
- update delta engine;
- Secure Install UI;
- PackageManager enforcement integration;
- PermissionController context;
- unified permissions/AppOps presentation;
- local tracker/library signals;
- special-access/exported-component analysis;
- compatibility regression corpus.

### S3 — ecosystem compatibility without ambient trust

Status: **PLANNED**.

- multi-source Android installation through common enforcement;
- optional sandboxed compatibility layers where maintainable;
- integrity/DRM reporting separate from APK compatibility;
- per-app exceptions instead of global security rollback.

### S4 — user-facing capability hardening

Status: **PLANNED**.

Candidate areas:

- per-app network capability;
- Storage Scopes;
- Contact Scopes;
- sensor/local-network scopes;
- profile-centered trust controls.

### S5 — measured resource/lifecycle policy

Status: **PLANNED**.

- background lifecycle;
- freezer/uclamp decisions where justified;
- memory pressure;
- display/network standby;
- thermal/wakeup accounting;
- before/after physical evidence.

No tuning knob lands on folklore alone.

## Release engineering / R1

Status: **PAUSED / NON-BLOCKING DURING PRODUCT DEVELOPMENT**.

Completed foundations include:

- release identity/policy;
- `CN=SableOS` source mutation;
- `https://updates.sableos.org/` Updater source mutation;
- exact signing-domain policy;
- source/keygen static gates;
- signing-key custody architecture;
- public endpoint transport validation.

No production signing key has been generated.

Current boundary:

```text
KEY_GENERATION_AUTHORIZED=NO
SIGNING_AUTHORIZED=NO
OTA_GENERATION_AUTHORIZED=NO
SIGNING_HOST_SELECTION=DEFERRED
PRIMARY_PRODUCTION_KEYSTORE=DEFERRED
```

Release engineering resumes before release-candidate distribution with:

```text
signing-host acceptance
primary encrypted keystore
physically separated encrypted backups
zero-swap/no-hibernate key-use window
production key generation
signed target-files/factory artifacts
OTA generation
forward-update validation
rollback/recovery validation
release evidence closure
```

## Release-candidate gate

Before SableOS becomes a release candidate:

- intended Sable default surfaces are explicit;
- replaced Android surfaces have capability-parity evidence;
- retained Android surfaces are intentional;
- privacy/data-flow records are complete;
- accessibility and multilingual gates pass;
- Panther physical regression suite passes;
- any non-Pixel support claim has the assurance class and independent hardware acceptance required by `NON_PIXEL_RELEASE_VALIDATION.md`;
- production signing/key custody is closed;
- signed OTA/factory and rollback/recovery are proven.

## Near-term priority

```text
1. M1 Sable Flow primitives
2. M1 Sable Start on Panther
3. M2 Phone / People / Messages
4. M3 Sable Hub provider framework
5. M4 social-service capsules
6. M5 broader native apps and polish
7. Titan 2 N0 portability/UI lab when Panther product work is ready
8. Q27 qualification when shipped hardware and source/BSP inputs are known
9. Q25 only when source-level MediaTek/kernel research is specifically useful
10. M6 AOD / Voice / Agent
11. production signing / OTA finalization before release candidate
```

The project intentionally prioritizes building the actual operating-system experience before optimizing the distribution machinery for a product that is not yet feature-complete.
