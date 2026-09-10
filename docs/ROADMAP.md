# SableOS roadmap

Last updated: 2026-09-09

## Roadmap rule

SableOS advances through independently testable security, capability and product gates.

A milestone is complete only when its implementation, policy boundary, build integration, generated artifacts and relevant physical behavior are validated. New product/security features must not silently remove working Android capability.

Portable semantic contracts should remain stable while Android-version/device integration is requalified behind bounded adapters.

The current project priority is to build the SableOS user experience. Production signing/OTA infrastructure is preserved but temporarily non-blocking until release-candidate work.

## Current progression

```text
validated Android 17 Panther substrate
    -> Sable Flow shared UI primitives
    -> Sable Start M1 shell
    -> Phone / People / Messages vertical slice
    -> Sable Hub provider framework
    -> isolated social-service capsules
    -> broader native apps / Search / Security / polish
    -> Q25/Q27 portability when justified
    -> release-candidate composition
    -> production signing / OTA / rollback closure
```

A later layer must not paper over an unproven earlier layer.

## Current snapshot

```text
PANTHER_D4                          CLOSED / PASS
SABLEOS_PRODUCT_DEVELOPMENT        ACTIVE
SABLEOS_CORE_PRODUCT_STAGE         PRODUCT_INTEGRATION_START
SABLE_FLOW_STATUS                  PLANNING_COMPLETE_IMPLEMENTATION_NEXT
NEXT_PRODUCT_MILESTONE             SABLE_M1_METRO_SHELL_PROTOTYPE

R1_RELEASE_SIGNING_WORK            PAUSED_NON_BLOCKING
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

### Q25

Status: **OPTIONAL FUTURE ENGINEERING REFERENCE**.

Q25 may validate:

- MediaTek adapter portability;
- compact/square layout constraints;
- physical keyboard/focus/navigation semantics.

It must reuse the common Sable Start/Hub semantic model rather than creating a Q25-specific product fork. See `Q25_PORT_PLAN.md`.

### Q27

Status: **FUTURE PREFERRED MODERN QWERTY DIRECTION**.

Q27 remains subject to source/vendor/bootloader/security/radio/power/hardware acceptance. Sable Flow and Hub are deliberately being designed now so Q27 can consume the same semantic model later.

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
- Q25/Q27 support claims, if any, have independent hardware acceptance;
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
7. Q25/Q27 portability when hardware/projects justify it
8. M6 AOD / Voice / Agent
9. production signing / OTA finalization before release candidate
```

The project intentionally prioritizes building the actual operating-system experience before optimizing the distribution machinery for a product that is not yet feature-complete.
