# Sable Flow and Hub product plan

Status: **accepted product direction / implementation planning; revised for native-first messaging**.

Original date: 2026-09-09  
Native-first messaging revision: 2026-09-22

This document turns the existing SableOS product principle into the concrete user-facing direction for the next product-development phase:

> **Applications provide capabilities; Sable organizes people, attention and actions.**

SableOS should feel like a distinct phone operating system rather than a differently branded Android distribution. The primary interaction model is a Metro-inspired, information-first shell with Sable-owned visual language, live tiles, native phone essentials, and a central Hub that organizes communication and attention without bypassing provider-supported clients or Android application sandboxing.

The working design-language name is **Sable Flow**. It is inspired by the useful interaction principles of Windows Phone / Metro but must use original Sable visual assets, naming, implementation and product identity.

## Product principles

1. **People, information and tasks before app silos.** The home surface should expose useful state and actions without forcing the user to repeatedly open applications.
2. **Android remains the capability and enforcement substrate.** Sable replaces presentation and orchestration only where it has a clear product benefit.
3. **No private-database scraping.** Sable Hub must not impersonate third-party applications or read their private application databases.
4. **Official/supported integration first.** Native provider APIs are used only when the provider and user account type actually authorize the required capability.
5. **Installed-app integration before embedded web emulation.** When a proprietary consumer service requires its supported Android client for account creation or primary-device behavior, Sable launches or integrates with that installed app instead of embedding an unofficial WebView client.
6. **Provider capability is explicit.** The Hub UI must distinguish native, notification-derived, API-backed, installed-app and unavailable capability instead of pretending all services are equally integrated.
7. **Privacy boundaries remain visible.** Third-party apps keep their normal Android sandbox and permissions. Sable may consume user-authorized Android notification/conversation surfaces, but does not own provider cookies or credentials.
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
HUB         MAIL
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

## Keyboard-first Sable Flow adaptation

Sable Flow has two presentation profiles over one semantic model:

```text
Panther / conventional slab:
    navigation.primary = touch

Titan 2 / physical-QWERTY:
    navigation.primary = keyboard
    navigation.secondary = touch
```

For Titan 2, keyboard-first is a product requirement rather than a compatibility enhancement.

SableStart must support:

- instant printable-key type-to-search from HOME;
- preservation of the triggering character during focus transition;
- deterministic visible focus;
- Enter/Back/Escape/Home/Recents semantics;
- configurable semantic shortcuts;
- no soft-keyboard popup merely because hardware-keyboard search gains focus;
- keyboard operation of the app list and major Start surfaces without touch.

The launcher interaction reference is OpenMiniLaunch/MinkLauncher; Pastiera and TypeQ25 inform physical-keyboard/IME/modifier behavior; q25toolbox informs keylayout/scancode/device-forensics only. See `TITAN2_KEYBOARD_FIRST_REFERENCE.md`.

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

The accepted V1 navigation is:

```text
Priority | Messages | Email | People
```

Priority is local and explainable. Messages combines SMS with user-enabled
notification/conversation adapters. Email consumes a bounded local Sable Mail
summary and opens Sable Mail for full mailbox work; Hub does not read the Mail
private database. People remains Android-contact backed.


The Hub must support multiple provider types behind one capability model:

```text
native Android/Sable data
    SMS, calls, contacts, calendar, local mail integration where available

notification/conversation adapter
    Android notification + conversation semantics + app-authorized actions

supported provider API adapter
    only capabilities explicitly allowed by current provider APIs/account types

installed-app adapter
    explicit launch/deep-link/share integration with a user-installed provider app
```

The UI consumes capabilities, not provider-specific implementation details. Embedded provider WebViews are not a Sable messaging capability.

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
INSTALLED_APP
NATIVE_DATA
```

A capability may be classified as:

```text
NATIVE
ANDROID_NOTIFICATION
SUPPORTED_API
INSTALLED_APP
UNAVAILABLE
```

The Hub must not silently promote `INSTALLED_APP` or `UNAVAILABLE` into a claim of native integration.

### Initial social providers

Initial social-service targets:

```text
WhatsApp
Instagram
Facebook
LinkedIn
```

The first milestone does **not** require implementing a native universal client for those services. Provider capabilities and terms change; implementation must verify the current official provider documentation before enabling API-backed functionality.

The practical path is installed-app-first: if the user chooses to install a provider's supported Android application, Sable may launch it, deep-link into supported destinations, share to it, and later consume user-authorized Android notification/conversation semantics. Sable does not embed provider login pages inside its own WebView.

WhatsApp is the concrete reason for this boundary: WhatsApp Web is a linked-device surface that requires an already-active primary account and therefore cannot serve as Sable's account-creation or primary-client path.

### Third-party application boundary

Provider account state, credentials, cookies, media and private databases stay inside the provider application sandbox. Sable Hub does not reproduce or proxy those stores.

Conceptually:

```text
Sable Hub -> supported Android intent / notification surface
provider app -> provider account/session/data
```

Removing embedded capsules also removes the need for Sable Messages to request network access solely to host proprietary provider sessions.

## Local conversation adapters

The accepted R9 no-server integration architecture is a configurable local
Android conversation adapter layer. It is not a provider-specific protocol
client.

### Connected apps

Connected-app management is provider-agnostic and uses two management pivots:

```text
Enabled | Available
```

Enabled keeps active providers and their reply/launcher/retention controls easy
to reach. Available remains searchable and includes disabled installed apps so
future compatible providers do not require a SableOS rebuild.

Settings exposes the surface under:

```text
Settings
  -> Messages
      -> Connected apps
```

Configuration is keyed by:

```text
(packageName, Android user/profile)
```

rather than compile-time provider enums. A compatible future app such as
Signal, Telegram, Session, Threema, Element or another messaging application
can therefore be enabled/disabled without recompiling SableOS.

Per-app policy includes at minimum:

```text
Include in Sable Messages
Allow quick reply when source exposes RemoteInput
Hide from SableLauncher
Retention policy for notification-derived history
```

### Android integration boundary

The generic adapter consumes:

- NotificationListenerService posted/removed notification events;
- MessagingStyle messages when present;
- Person / conversation metadata when present;
- source package, user/profile, notification key and shortcut/conversation id;
- RemoteInput + source PendingIntent for quick reply when the notification
  explicitly exposes a valid reply action.

The adapter does not require provider credentials or provider-private APIs.
The official installed application remains responsible for push/networking,
end-to-end cryptography, account/session state, attachments, complete history
and protocol compatibility.

### Capability levels

```text
CONVERSATION_REPLY
    structured conversation metadata + source-authorized RemoteInput reply

NOTIFICATION_ONLY
    bounded title/text timeline + Open in app

LAUNCH_ONLY
    insufficient usable notification content; launch provider app only
```

Sable must not claim complete history merely because it has a notification
timeline.

### Privacy and lifecycle rules

- notification access is explicit user authorization;
- only enabled package/profile pairs are retained;
- callback work is copied/bounded and moved off the notification callback
  thread before Room/identity/contact work;
- no private-database scraping, accessibility scraping or provider credential
  capture;
- no embedded provider WebViews;
- source notification privacy/redaction is respected; Sable does not reconstruct
  content the source app intentionally withheld;
- source notifications are not canceled in the first tranche so reply
  PendingIntents remain valid;
- notification-derived history is CE-only and bounded by explicit retention
  policy;
- identity linking is evidence-based and ambiguous cross-provider person merges
  require user confirmation.

### Launcher integration

SableLauncher hiding becomes dynamic rather than package-coded. Connected-app
settings may hide an enabled provider from the Sable app list, but the package
remains installed/enabled and can always be surfaced again through Settings.
Graphene Messaging remains a separately documented product transport exception.

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

The Social tile may initially open a Sable Flow Hub shell that reports installed/supported provider capability. It must not present placeholder WebView sessions as if they were functional provider clients.

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
- provider sandbox / authorization boundary;
- provider-specific privacy/data-flow disclosure.

### M4 — social app adapters

- detect intentionally installed provider apps without bypassing package visibility policy;
- supported launch/deep-link/share actions;
- Android notification/conversation adapters only with explicit user authorization;
- no provider credential capture or private-database access;
- no embedded provider WebView clients;
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
5. installed-app / notification adapters for selected social services
6. broader native apps and polish
7. Q25/Q27 portability work when hardware/projects justify it
8. production signing / OTA finalization before release candidate
```

This ordering intentionally prioritizes building the operating-system experience before optimizing the machinery used to distribute a future production release.
