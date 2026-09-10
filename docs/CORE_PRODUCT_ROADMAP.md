# SableOS Core Product Integration Track

Status: **active product-development roadmap**.

This track turns the normative product model in `CORE_PRODUCT_MODEL.md` and the concrete shell/Hub direction in `SABLE_FLOW_AND_HUB_PRODUCT_PLAN.md` into staged implementation gates.

The product principle is:

> **Applications provide capabilities; Sable organizes people, attention and actions.**

The current priority is to build the SableOS user experience first. Production signing-host selection, production key generation and OTA-signing finalization are deliberately deferred until release-candidate work makes them necessary.

## Current development state

Panther D4 physical acceptance is closed. The Android 17 / GrapheneOS-derived Panther development substrate is proven bootable with preserved shared data and broad functional acceptance.

Current product state:

```text
SABLEOS_CORE_PRODUCT_STAGE=PRODUCT_INTEGRATION_START
SABLE_FLOW_STATUS=PLANNING_COMPLETE_IMPLEMENTATION_NEXT
SABLE_START_STATUS=NOT_INTEGRATED
SABLE_HUB_STATUS=NOT_INTEGRATED
PRODUCTION_KEYS_GENERATED=NO
KEY_GENERATION_AUTHORIZED=NO
SIGNING_AUTHORIZED=NO
OTA_GENERATION_AUTHORIZED=NO
SIGNING_HOST_SELECTION=DEFERRED_NON_BLOCKING
```

Release engineering remains preserved as a paused parallel track; it does not block product development.

## Dependency rule

Product work still respects Android/platform boundaries:

```text
validated Panther substrate
        -> Sable Flow shared primitives
        -> Sable Start shell prototype
        -> native phone/people/messages vertical slice
        -> Sable Hub provider framework
        -> social capsules / supported provider integrations
        -> broader product composition
        -> release-candidate signing/OTA closure
```

A Sable presentation surface does not receive direct hardware/system authority merely because it displays or requests a capability.

## CP0 — Core product baseline

Status: **PASS / POLICY COMPLETE**.

Established by:

- `CORE_PRODUCT_MODEL.md`;
- `SABLE_FLOW_AND_HUB_PRODUCT_PLAN.md`;
- ADR-0007;
- `AOSP_CAPABILITY_POLICY.md`;
- `INTERACTION_PROFILES.md`;
- `RELEASE_VALIDATION.md`.

Outputs:

- strategic Sable-owned surface list;
- retain/replace boundary for AOSP/application capability;
- people/attention/action product model;
- Metro-inspired Sable Flow interaction direction;
- provider/capsule Hub model;
- product-stage markers;
- multilingual/local-first voice dependency;
- release signing explicitly separated from near-term feature work.

## M1 / CP1 — Sable Flow shell primitives + Sable Start

Status: **NEXT IMPLEMENTATION MILESTONE**.

Target: Panther / Pixel 7.

Build reusable Sable Flow primitives:

```text
typography
accent/theme tokens
tile layout + tile lifecycle
live-tile data contract
pivot/section navigation
lists/section headers
motion/transitions
focus/navigation semantics
privacy/redaction states
accessibility semantics
compact/square layout rules
keyboard focus/shortcut hooks
```

Sable Start requirements:

- vertical Metro-inspired tile surface;
- large typography and clear information hierarchy;
- user-selectable accent/theme;
- live tiles with privacy-aware state;
- application/service list transition;
- Phone tile;
- People tile;
- Messages tile;
- Settings tile;
- Social Hub placeholder tile;
- Launcher3 retained as development fallback until replacement qualification passes.

M1 is intentionally a real shell/product milestone, not only a renderer demo.

Acceptance:

- deterministic/offline build provenance;
- normal Android lifecycle/task behavior;
- no unnecessary privileged hardware authority;
- process restart/recovery behavior;
- accessibility semantics;
- Panther touch interaction;
- physical-device validation;
- launcher rollback/fallback during development.

## M2 / CP2 — native phone, people and messages experience

Build the first complete daily-use vertical slice while retaining mature Android transport/enforcement.

### Phone

- Sable presentation over Android Telecom/Telephony;
- call history;
- missed-call state/live tile;
- callback affordances;
- no direct modem protocol implementation.

### People

- ContactsProvider-backed Sable People surface;
- local person identity graph;
- recent/important people presentation;
- user-confirmed cross-source identity association when ambiguous.

### Messages

- Sable SMS/MMS presentation over retained mature Android/carrier machinery;
- bounded communication timeline;
- unread/live-tile state;
- lock/privacy redaction.

The first useful product should feel coherent without requiring third-party social applications.

## M3 / CP3 — Sable Hub provider framework

Status: **PLANNED AFTER M2 FOUNDATION**.

Hub becomes the common people/communication/service layer.

Provider types:

```text
NATIVE_DATA
ANDROID_NOTIFICATION
SUPPORTED_API
WEB
UNAVAILABLE
```

Provider capability declarations include:

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
- Android notification/conversation ingestion;
- application-authorized reply/actions;
- local evidence-based person linking;
- bounded local history;
- unified share/deep-link semantics;
- privacy/data-flow disclosure;
- separate provider session/storage boundaries;
- no private messaging-app database scraping.

The Hub must expose the difference between native/API/web capability rather than pretending every provider is a native universal integration.

## M4 / CP4 — social service capsules

Status: **PLANNED**.

Initial service targets:

```text
WhatsApp
Instagram
Facebook
LinkedIn
```

The first implementation does not require or promise a native universal client for these services.

Where an appropriate supported consumer API is unavailable, use isolated Sable-managed web capsules with independent provider session state. Official provider API capability must be reverified at implementation time because provider terms and supported account types can change.

Requirements:

- isolated persistent provider sessions;
- no automatic cross-provider authentication sharing;
- bounded background/resource behavior;
- explicit WEB capability classification;
- Android notification/deep-link integration where intentionally available;
- no unsupported native/API claims.

## M5 / CP5 — broader Sable core apps + Search/Security

Expand the coherent native phone baseline:

```text
Camera
Photos
Clock / alarms / timers
Calculator
Calendar
Files
Notes
Browser
```

Reuse mature Android capability where appropriate rather than forking every implementation merely for branding.

Search:

- Unicode/multilingual local search;
- applications, people, conversations, settings and authorized local content;
- typed command dispatch.

Security/Privacy:

- Secure Package Intelligence;
- application transparency;
- effective Permission/AppOps state;
- package/signing/component/privacy history.

## M6 / CP6 — AOD, Voice and Agent

AOD / Glance:

- time/date/battery;
- priority Hub indicators;
- privacy redaction;
- burn-in mitigation;
- display/doze residency;
- battery impact;
- graceful disable/failure behavior.

Voice/Agent remain local-first and capability-bounded:

```text
text / voice
    -> semantic intent
    -> typed capability request
    -> narrow Sable/Android service
```

No generic root shell, arbitrary privileged executor or unrestricted other-app private-data access.

Language requirements remain governed by `LANGUAGE_AND_VOICE_POLICY.md`.

## Q25 / Q27 portability track

Sable Flow and Hub are explicitly the common foundation for future QWERTY/compact devices.

Shared semantic objects include:

```text
tile
person
conversation
provider
capability
action
pivot/section
focus
navigation
search/command
```

Panther validates the touch-first presentation. Q25 may later validate compact/square and physical-keyboard assumptions as an engineering reference. Q27 remains a future preferred modern QWERTY direction.

Device-specific UI forks are rejected. Form-factor differences belong in interaction/layout profiles consuming shared semantics.

## Release-candidate composition closure

Production release infrastructure returns to the critical path here, not during M1 shell development.

Before release-candidate classification:

- intended default-app matrix is explicit;
- required Sable surfaces are installed and validated;
- retained AOSP surfaces are intentional;
- removed/replaced surfaces have capability-parity evidence;
- privacy/data-flow records are complete;
- multilingual/accessibility gates pass;
- physical power/privacy gates pass for AOD where applicable;
- touch/keyboard profiles consume common semantics;
- product image contains no accidental duplicate privileged implementation;
- signing host / encrypted production keystore / backups are selected and validated;
- production key generation is separately authorized and sealed;
- signed target-files/factory/OTA and rollback/recovery gates pass.

Typical closure markers:

```text
SABLEOS_CORE_PRODUCT_STAGE=RELEASE_CANDIDATE
SABLEOS_CORE_PRODUCT_MODEL=PASS
SABLEOS_DEFAULT_APP_MATRIX=PASS
SABLEOS_AOSP_FOUNDATION_PRESERVED=PASS
SABLEOS_LANGUAGE_BASELINE=PASS
```

Production adds the signing/security/privacy/update gates in `RELEASE_VALIDATION.md`.

## Near-term priority order

```text
1. M1 Sable Flow shared primitives
2. M1 Sable Start prototype on Panther
3. M2 Phone / People / Messages vertical slice
4. M3 Sable Hub provider capability framework
5. M4 social web capsules
6. M5 broader native apps + product polish
7. Q25/Q27 portability work when hardware/projects justify it
8. M6 AOD/Voice/Agent as dependencies mature
9. production signing / OTA finalization before release candidate
```

This ordering intentionally prioritizes building SableOS as a distinct, useful operating-system experience before optimizing future production distribution machinery.
