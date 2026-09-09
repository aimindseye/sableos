# Sable Flow and Hub product plan

Status: **accepted product direction / implementation planning**.

Date: 2026-09-09

This document turns the existing SableOS product principle into the concrete user-facing direction for the next product-development phase:

> **Applications provide capabilities; Sable organizes people, attention and actions.**

SableOS should feel like a distinct phone operating system rather than a differently branded Android distribution. The primary interaction model is a Metro-inspired, information-first shell with Sable-owned visual language, live tiles, native phone essentials, and a central Hub that organizes communication and social services without requiring a separate full Android application for every service where a safe, supported alternative is possible.

The working design-language name is **Sable Flow**. It is inspired by the useful interaction principles of Windows Phone / Metro but must use original Sable visual assets, naming, implementation and product identity.

## Product principles

1. **People, information and tasks before app silos.** The home surface should expose useful state and actions without forcing the user to repeatedly open applications.
2. **Android remains the capability and enforcement substrate.** Sable replaces presentation and orchestration only where it has a clear product benefit.
3. **No private-database scraping.** Sable Hub must not impersonate third-party applications or read their private application databases.
4. **Official/supported integration first.** Native provider APIs are used only when the provider and user account type actually authorize the required capability.
5. **Web capsules are a legitimate fallback.** Where a consumer service does not expose an appropriate supported API, Sable may provide an isolated web session rather than requiring the vendor's full Android application.
6. **Provider capability is explicit.** The Hub UI must distinguish native, notification-derived, API-backed and web-backed capability instead of pretending all services are equally integrated.
7. **Privacy boundaries remain visible.** Provider sessions, cookies and storage remain isolated by provider unless the user explicitly chooses otherwise.
8. **One semantic product across form factors.** The same shell/Hub concepts must scale from Panther touch-first development to future Q25/Q27 compact and physical-keyboard profiles without device-name forks.

## Sable Start

The primary launcher/home experience is **Sable Start** (the concrete Sable Flow realization of the architectural `Sable Home` surface).

Core interaction:

```text
vertical Start surface
    -> resizable information/action tiles
    -> large typography and strong hierarchy
    -> user-selected accent/theme
    -> live state where privacy policy allows
    -> fast transition to alphabetical application/service list
```

Initial tile set:

```text
PEOPLE      PHONE
MESSAGES    MAIL
CAMERA      PHOTOS
SOCIAL      CALENDAR
SETTINGS    CLOCK
```

Tile behavior must be data-driven and privacy-aware. Examples:

- People: recent/important people or bounded avatars/state;
- Phone: missed-call state and callback affordance;
- Messages: unread count and redacted preview according to lock/privacy state;
- Calendar: next event/time;
- Social: provider/activity summary rather than a permanent combined remote feed;
- Battery/system tiles: consume typed Sable/Android semantic services rather than raw hardware authority.

Launcher3 remains available as the development/reference fallback until Sable Start passes replacement gates.

## Shared Sable Flow UI primitives

The first product implementation should establish reusable primitives instead of hand-building unrelated screens:

```text
typography
accent/theme tokens
tile layout and tile lifecycle
live-tile data contract
pivot/panorama-style navigation
lists and section headers
focus/navigation semantics
motion/transitions
privacy/redaction states
accessibility semantics
compact/square layout rules
keyboard focus and shortcut hooks
```

The rendering framework remains evidence-driven. Sable Flow semantics must not depend on one renderer or one Android platform Rust compiler.

## Native core-phone baseline

The first usable Sable product should provide a coherent phone experience before broad social integration.

Priority surfaces:

```text
Phone / call history
People / Contacts
Messages / SMS/MMS presentation
Settings high-value Sable surfaces
Camera
Photos
Clock / alarms / timers
Calculator
Calendar
Files
Notes
Browser
Sable Hub
```

The policy is not to fork every mature Android implementation. Sable may retain Android/AOSP transport, providers, framework services and enforcement while replacing the user-facing presentation progressively.

Initial vertical slice:

```text
PHONE
PEOPLE
MESSAGES
SETTINGS
```

These four tiles/surfaces are the minimum useful shell proof for Panther.

## Sable Hub

Sable Hub is the central people, communication, attention and service surface.

The Hub must support multiple provider types behind one capability model:

```text
native Android/Sable data
    SMS, calls, contacts, calendar, local mail integration where available

notification/conversation adapter
    Android notification + conversation semantics + app-authorized actions

supported provider API adapter
    only capabilities explicitly allowed by current provider APIs/account types

isolated web capsule
    provider web application/session when a supported native consumer API is unavailable
```

The UI consumes capabilities, not provider-specific implementation details.

### Provider capability model

Each provider declares capabilities such as:

```text
MESSAGING
FEED
PROFILE
CONTACTS
SHARE
NOTIFICATIONS
DEEP_LINK
WEB_SESSION
NATIVE_DATA
```

A capability may be classified as:

```text
NATIVE
ANDROID_NOTIFICATION
SUPPORTED_API
WEB
UNAVAILABLE
```

The Hub must not silently promote `WEB` or `UNAVAILABLE` into a claim of native integration.

### Initial social providers

Initial social-service targets:

```text
WhatsApp
Instagram
Facebook
LinkedIn
```

The first milestone does **not** require implementing a native universal client for those services. Provider capabilities and terms change; implementation must verify the current official provider documentation before enabling API-backed functionality.

The practical initial path is isolated Sable web capsules where necessary, with native Android notification/deep-link integration when a compatible installed application is intentionally present.

### Capsule isolation

Each social/web provider should have independent persistent session state and storage isolation. The architecture should not automatically combine authentication state merely because services share a parent company.

Conceptually:

```text
WhatsApp session != Instagram session
Instagram session != Facebook session
Facebook session != LinkedIn session
```

A provider capsule must not gain broad system privilege by virtue of appearing inside Sable Hub.

## People-centric model

People should become a first-class organizational object shared by Start and Hub.

Preferred local evidence:

```text
ContactsProvider identity
Android Person / conversation metadata
shortcut/conversation identity
user-confirmed associations
```

Sable may show a person-centric communication view across authorized sources, but ambiguous cross-service identity linking must be user-confirmed.

The goal is a useful answer to "what is happening with this person?" without creating a hidden cloud copy of every conversation.

## Unified activity policy

Do not begin by constructing an unlimited global social feed. The first Hub should organize bounded actionable state:

```text
ALL
MESSAGES
PEOPLE
SERVICES
```

The existing NOW / PEOPLE / APPS / LATER attention concepts remain useful and may coexist with these service-oriented pivots as the interaction model is prototyped.

Priority is actionable communication and attention, not maximum content ingestion.

## Sable M1 — Metro shell prototype

Target: **Panther / Pixel 7**.

Milestone outcome:

```text
Sable Start present as a standalone/default-selectable development launcher
vertical tile grid
Sable Flow typography/theme primitives
accent themes
app/service list transition
live-tile provider contract
Phone tile
People tile
Messages tile
Settings tile
Social Hub placeholder tile
```

The Social tile initially opens a real Sable Flow Hub shell with provider entries for WhatsApp, Instagram, Facebook and LinkedIn; provider integration may remain placeholder/capsule-only while shell interaction and architecture are validated.

Acceptance must include:

- Android lifecycle and task behavior;
- no unnecessary privileged hardware authority;
- accessibility semantics;
- portrait touch interaction on Panther;
- process restart/recovery behavior;
- launcher fallback during development;
- deterministic/offline build provenance;
- physical-device validation before replacing Launcher3 by default.

## Follow-on milestones

### M2 — native phone/people/messages experience

- People Hub and ContactsProvider integration;
- Phone/call history presentation over Android Telecom/Telephony;
- SMS/MMS presentation over retained mature transport/provider machinery;
- bounded communication timeline;
- live tile state and privacy/redaction.

### M3 — Hub provider framework

- capability registry;
- provider lifecycle/account state;
- notification/conversation adapters;
- unified share/deep-link semantics;
- isolated provider storage/session model;
- provider-specific privacy/data-flow disclosure.

### M4 — social capsules

- WhatsApp web capsule;
- Instagram web capsule;
- Facebook web capsule;
- LinkedIn web capsule;
- independent session storage;
- bounded resource/background policy;
- no claim of unsupported native/API functionality.

### M5 — richer supported integrations

Add provider API functionality only where current official APIs, account types and user authorization make it legitimate and maintainable. Any richer integration is additive to the provider capability model rather than a special-case rewrite of Hub.

## Q25 / Q27 foundation

Sable Flow is intentionally a portability foundation for future compact/QWERTY devices.

Shared semantics:

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

Touch-first Panther presentation and future keyboard-first Q25/Q27 presentation must consume those same semantics.

Q25 is useful as an engineering/reference target for compact-square and physical-keyboard assumptions. Q27 remains a future preferred modern QWERTY product direction. Neither should require a fork of the Sable Hub data/capability model.

## Release-signing relationship

Production signing/OTA infrastructure is **deferred and non-blocking for this product-development phase**.

Already completed release-engineering policy/evidence remains valid and preserved, but no production key generation is required to develop, build and physically validate Sable Flow features on the existing development substrate.

Current policy while product development is active:

```text
PRODUCTION_KEYS_GENERATED=NO
KEY_GENERATION_AUTHORIZED=NO
SIGNING_AUTHORIZED=NO
OTA_GENERATION_AUTHORIZED=NO
SIGNING_HOST_SELECTION=DEFERRED
PRIMARY_PRODUCTION_KEYSTORE=DEFERRED
```

Release signing returns to the critical path when the product approaches release-candidate composition and OTA distribution becomes necessary.

## Near-term priority

```text
1. Sable Flow shell primitives
2. Sable Start M1 prototype on Panther
3. Phone / People / Messages / Settings vertical slice
4. Sable Hub shell + provider capability contract
5. social web capsules
6. broader native apps and polish
7. Q25/Q27 portability work when hardware/projects justify it
8. production signing / OTA finalization before release candidate
```

This ordering intentionally prioritizes building the operating-system experience before optimizing the machinery used to distribute a future production release.
