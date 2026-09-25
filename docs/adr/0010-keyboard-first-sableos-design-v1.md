# ADR-0010: Keyboard-First SableOS Design V1

Status: **accepted**

Date: 2026-09-24

## Context

SableOS now has an active keyboard-first portability target in the Unihertz
Titan 2 family and a future Q27-class physical-QWERTY direction. The existing
Sable product model already requires one common semantic OS with multiple
interaction profiles, but the keyboard-first work needs a stronger platform
contract than "touch UI plus focus rings."

The design review considered:

- the existing SableOS interaction, launcher, Hub, non-Pixel and security
  boundaries;
- the Titan 2 physical-keyboard research plan;
- AOSP input, activity/window compatibility and notification architecture;
- Pastiera / future Plektra physical-keyboard behavior;
- Commander keyboard-first command/notification UX;
- OpenMiniLaunch / MinkLauncher keyboard-first launcher and Conversations UX;
- q25toolbox physical-keyboard and device-forensics lessons;
- TrebleDroid / RestlessOS non-Pixel compatibility work;
- Q27 prototype/community observations, which remain research leads until
  reproduced on shipped hardware.

The central decision is:

> **Keyboard-first is a SableOS platform capability, not an IME feature and not
> a device-specific launcher fork.**

## Decision

SableOS adopts the following eleven-component Keyboard-First Design V1.

### 1. Sable Device Profile

A device profile describes behavior and capabilities rather than only product
identity. It binds:

- independent device identity evidence;
- physical display geometry and display classes;
- key-matrix and special-key topology;
- input surfaces and pointer/gesture capabilities;
- keyboard backlight and other hardware indicators;
- vendor quirks;
- security/assurance provenance;
- device-specific compatibility facts.

Applications must not branch directly on "Titan 2", "Q27", or another model
when an interaction/display/input capability is sufficient.

### 2. Sable Hardware Input Mapper

The primary normalization boundary is Android userspace input handling.

Preferred pipeline:

```text
Linux evdev
    -> EventHub
    -> InputReader
    -> Sable hardware InputMapper / device-profile normalization
    -> normalized Sable input semantics
    -> InputDispatcher / policy / IME / application
```

Kernel modification is a last resort after physical evidence proves the vendor
kernel does not expose the required input capability.

The mapper normalizes hardware facts. It does not own high-level policy. For
example, it may normalize an axis sequence into `SWIPE_UP`, but it does not
decide that `SWIPE_UP` means "accept prediction 2."

### 3. Sable Input Surface API

Physical keyboard and pointer/touch surfaces are separate capabilities.

The capability model must be able to express at least:

```text
KEYBOARD
  PHYSICAL_KEY_MATRIX
  MODIFIER_KEYS
  PROGRAMMABLE_KEYS
  KEY_REPEAT
  KEYBOARD_WAKE
  KEY_BACKLIGHT

POINTER_SURFACE
  RELATIVE_POINTER
  ABSOLUTE_POINTER
  SCROLL_X
  SCROLL_Y
  TAP
  CLICK
  LONG_PRESS
  SWIPE
  MULTI_ZONE
  GESTURE_SELECT

SURFACE_LOCATION
  KEYBOARD_MATRIX
  TOOLBELT
  SEPARATE_TRACKPAD
  OTHER
```

This allows a Titan keyboard-associated touch surface and a future separate Q27
toolbelt/trackpad to drive the same higher-level Sable semantics.

### 4. Sable Keyboard Policy Service

Global keyboard behavior is owned by a small platform policy service rather
than a large device-specific `PhoneWindowManager` or launcher state machine.

The policy service decides context, security class and routing. Low-level policy
hooks should yield immediately when no Sable-reserved action matches.

Priority is:

```text
1. security / lockscreen interception
2. explicitly reserved Sable chord
3. active IME / text composition
4. application-level conventional shortcut
5. HOME type-to-search / command
6. Sable navigation mode
7. normal application event
```

The globally reserved Sable shortcut namespace must remain small. Conventional
application shortcuts such as Ctrl+C must not be stolen by default.

Every privileged/global action is assigned a lock-state policy:

```text
ALLOW_LOCKED
ALLOW_LOCKED_REDACTED
AUTH_REQUIRED
UNLOCKED_ONLY
DISABLED
```

### 5. Sable Physical IME

Keyboard-first images ship an offline-capable physical-keyboard-aware input
method.

Default physical-keyboard mode:

- full touch keyboard hidden by default when a physical keyboard is active;
- Android IME/InputConnection lifecycle remains intact;
- optional compact candidate/status surface;
- data-driven language, Alt/SYM and compose maps;
- explicit held, one-shot and latched modifier state;
- cursor, selection and editing shortcuts;
- explicit user action can show a normal touch keyboard for emoji, symbols,
  accessibility or complex scripts;
- suggestion/candidate UI can be disabled by the user.

Device-specific scan-code and axis quirks do not live in the common IME.

Pastiera/Plektra remains a behavior/architecture reference until licensing,
successor ownership and reuse boundaries are explicitly resolved. GPL process
separation is not treated as an automatic legal safe harbor.

### 6. SableStart Command Surface

SableStart becomes the keyboard-first system shell while retaining touch.

From HOME:

- a printable key enters Search/Command immediately;
- the triggering character is preserved;
- no prior tap is required;
- app search, Settings routes and typed Sable actions are first-class;
- people, conversations and authorized local content can be added through
  typed providers;
- visual Start, tiles, All Apps and touch navigation remain available.

OpenMiniLaunch/MinkLauncher and Commander are interaction references. Their
launcher/application-level workarounds are not copied where SableOS owns a
cleaner platform boundary.

### 7. Sable Focus & Navigation

All Sable-owned system surfaces and first-party applications must be operable
without touch on keyboard-first devices.

Order of preference:

```text
Tier 0  native Android/app focus works
Tier 1  Sable focus styling/traversal improvements
Tier 2  directional compatibility assistance
Tier 3  virtual-pointer compatibility
Tier 4  explicit app-specific compatibility rule
```

SystemUI overlays over every third-party application are not the default focus
architecture.

### 8. Sable App Display Profiles

SableOS provides persistent per-app display compatibility profiles.

The physical/global display remains native. Overrides are scoped to the
application Activity/Task compatibility configuration using Android
size-compat/letterbox/window configuration machinery.

User choices include:

```text
Automatic
App Default
Native / Full Screen
1:1
4:3
3:2
16:9 Portrait
device-specific tested presets
Custom logical width x height
optional logical density / UI scale
Reset
```

Profiles are keyed by at least:

```text
Android user/profile + package + display class
```

They must not be implemented by changing global `wm size` when foreground
applications change.

Insets, resources and input-coordinate transforms must remain consistent with
the virtual app canvas.

### 9. Sable Notification Policy & Profiles

Notification configuration is a first-class keyboard-first capability while
remaining useful on touch-first devices.

Policy remains separate from Hub aggregation.

Per application/channel/conversation, Sable may expose Android-supported controls
for:

- alerting / quiet / off;
- sound;
- vibration;
- heads-up/presentation;
- badge;
- lockscreen privacy;
- priority;
- snooze;
- Hub inclusion where technically valid;
- supported hardware-attention outputs.

Keyboard navigation in the notification surface may use contextual commands
such as:

```text
Up/Down    previous/next
Enter      open
R          reply when RemoteInput exists
D          dismiss
Z          snooze
M          mute/configure delivery
C          configure channel/app/conversation
Space      expand/collapse
Esc        back
```

These single-key commands are contextual to the focused notification surface,
not global shortcuts.

Device notification capabilities are declared independently:

```text
OUTPUT_STATUS_LED
OUTPUT_KEYBOARD_BACKLIGHT
OUTPUT_SECONDARY_DISPLAY
OUTPUT_HAPTIC
OUTPUT_AUDIO
OUTPUT_ALWAYS_ON_DISPLAY
```

Unsupported outputs are not shown.

### 10. Sable Hub

Notification policy and Sable Hub are distinct services/surfaces.

Third-party communication ingestion is restricted to supported Android/public
interfaces:

```text
NotificationListener / MessagingStyle / Person / conversation metadata
RemoteInput
PendingIntent / supported intents
published shortcuts / supported public APIs
```

No private third-party messaging database scraping is part of the architecture.

First-party Sable Mail, Messages, Phone, Contacts and Calendar may integrate
through bounded provider/service APIs. They do not gain unrestricted access to
each other's raw databases simply because they are first-party.

Hub may maintain a bounded encrypted index/cache where needed.

### 11. Sable Device Adapter & Security Delta Ledger

Non-Pixel compatibility changes stay explicit and scoped.

TrebleDroid/RestlessOS is a compatibility laboratory for identifying where
arbitrary vendor partitions conflict with newer/hardened Android userspace. It
is **not** the SableOS security baseline.

Every compatibility relaxation or hardening exception records:

```text
target device/profile
affected platform security feature
vendor/kernel dependency
observed failure
smallest change required
security impact
physical/runtime test
removal condition
upstream/reference source
```

A RestlessOS/TrebleDroid patch is never imported solely because it makes more
devices boot.

## Reference-project policy

Reference use is classified separately from code reuse.

### OpenMiniLaunch / MinkLauncher

- role: keyboard-first launcher, command/search and active-conversation UX;
- current reviewed repository license: Apache-2.0;
- useful lessons: first-key preservation, already-focused command surface,
  local-first search, work-profile awareness, NotificationListener +
  RemoteInput conversation handling, assistant-overlay invocation;
- direct reuse still requires normal provenance/NOTICE review.

### Commander

- role: keyboard-first command palette and notification-Hub UX;
- useful lessons: broad local command vocabulary, keyboard navigation, search
  aliases, recents/app actions, RemoteInput-bound replies;
- app-level Accessibility/overlay mechanisms are not automatically Sable
  platform architecture.

### Pastiera / Plektra

- role: physical-keyboard IME, modifier, layout and touch-surface behavior;
- Pastiera reviewed as GPL-3.0;
- behavior and tests are strong reference material;
- direct code reuse requires explicit licensing decision.

### q25toolbox

- role: physical-keyboard/device forensic and failure-mode reference;
- root, KernelSU, LSPosed, bind-mount and Accessibility techniques are evidence
  about stock-device constraints, not the SableOS production mechanism.

### TrebleDroid / RestlessOS

- role: non-Pixel/GSI/vendor compatibility research;
- especially useful for Unihertz/MediaTek keylayout, camera, fingerprint,
  SELinux and vendor-compatibility evidence;
- security weakening is never imported as a blanket portability policy.

### Q27 community/prototype evidence

Community and prototype reports are research leads only. Shipped-device
behavior must be reproduced before becoming a Sable device-profile fact.

## Consequences

### Positive

- one keyboard-first platform model can support Titan 2, Titan 2 Elite, future
  Q27-class devices and conventional external keyboards;
- UI/application semantics remain shared with Panther;
- per-app resolution and notification behavior become user-controlled product
  capabilities rather than root/accessibility workarounds;
- non-Pixel compatibility work is separated from security claims;
- launcher, IME, Hub and hardware quirks remain independently testable.

### Costs

- InputReader/platform work requires careful Android-version adaptation;
- per-app logical resolution/density requires resource, inset and input-transform
  qualification;
- keyboard-first SystemUI/Settings coverage is broader than launcher-only work;
- notification-output integrations require device evidence;
- a first-party IME requires significant language/layout/test work if GPL reuse
  is avoided.

## Implementation workstreams

The next implementation plan is split into bounded workstreams:

```text
KF1  capability schema + device profile + normalized input-surface model
KF2  Keyboard Policy Service + routing/security tests
KF3  SableStart type-to-command + keyboard focus/navigation
KF4  physical IME baseline + modifier/layout tests
KF5  SystemUI/Settings keyboard traversal
KF6  Sable App Display Profiles
KF7  Sable Notification Policy & keyboard notification center
KF8  Hub integration against notification policy
KF9  Titan 2 N0 adapter/evidence binding
KF10 Titan 2 Elite independent evidence/adapter binding
KF11 future Q27 shipped-hardware qualification
```

Each workstream should compile/test independently before a full-image gate.

## Acceptance principles

At minimum, keyboard-first qualification must prove:

- no touch required for core navigation;
- first HOME key is preserved in Search/Command;
- no focus traps across Sable-owned surfaces;
- normal application Ctrl/Alt shortcuts remain usable;
- lockscreen policy cannot be bypassed through keyboard commands;
- physical text entry does not summon a full touch keyboard by default;
- app display profiles are per-app and do not mutate global display metrics;
- custom app bounds/density preserve input coordinate correctness;
- notification commands act only in the correct focused context;
- notification privacy rules survive lock/unlock transitions;
- device-specific hardware indicators are capability-gated;
- third-party Hub replies occur only through source-app-authorized actions;
- compatibility/security deltas are recorded and device-scoped.

## Supersession / relationship

This ADR extends rather than replaces:

- ADR-0002 — UI framework/application compatibility;
- ADR-0004 — portable hardware capability model;
- ADR-0007 — core product/Hub/AOSP boundary;
- ADR-0008 — configurable local conversation adapters.

When older keyboard-first notes conflict with this ADR, this ADR is
authoritative for Keyboard-First SableOS Design V1.
