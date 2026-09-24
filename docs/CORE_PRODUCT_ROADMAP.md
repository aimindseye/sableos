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
SABLEOS_CORE_PRODUCT_STAGE=R8_FINAL_UI_PRODUCT_CLOSURE
SABLE_FLOW_STATUS=IMPLEMENTED_IN_REPOSITORY_PRODUCT_INTEGRATION_PENDING
SABLE_START_STATUS=IMPLEMENTED_NOT_PRODUCT_PROVEN
SABLE_HUB_STATUS=NOT_INTEGRATED
PRODUCTION_KEYS_GENERATED=NO
KEY_GENERATION_AUTHORIZED=NO
SIGNING_AUTHORIZED=NO
OTA_GENERATION_AUTHORIZED=NO
SIGNING_HOST_SELECTION=DEFERRED_NON_BLOCKING
```

Release engineering remains preserved as a paused parallel track; it does not block product development.

### R9 current execution delta

The older R8 status tables below are retained as historical closure context.
Current R9 execution has advanced beyond that snapshot:

```text
SABLE_START_STATUS=STANDALONE_HOME_SOURCE_MODULE_QUALIFIED_PHYSICAL_PENDING
SABLE_MEDIA_STATUS=LARGE_LIBRARY_HARDENED_ALPHABET_NAVIGATION_QUALIFIED
SABLE_MESSAGES_STATUS=NATIVE_SMS_PEOPLE_FOCUSED_QUALIFIED
SABLE_MESSAGES_WEB_CAPSULES=RETIRED
SABLE_MESSAGES_NEXT=CONFIGURABLE_LOCAL_CONVERSATION_ADAPTERS
QUICKSTEP_ROLE=RECENTS_ONLY
FULL_PANTHER_PHYSICAL_ACCEPTANCE=PENDING
```

The next Messages tranche is generic rather than provider-coded: users select
installed messaging apps in Settings; Sable consumes user-authorized Android
notification/conversation metadata and RemoteInput actions where available.
Configuration is keyed by package + Android user/profile, so compatible future
apps do not require recompilation.

## R8 final UI product closure

Status: **ACTIVE / BUILD-BLOCKING**.

The repository now contains major completed UI tranches, but the first physically flashed R8 image proved that standalone/emulator completion and Panther product integration had diverged. The current execution authority is `R8_PIXEL_UI_PRODUCT_CLOSURE.md`.

Current classification:

```text
R8_A_SHARED_DESIGN=PARTIAL
R8_START_METRO_HOME=IMPLEMENTED_IN_REPOSITORY_NOT_PRODUCT_PROVEN
R8_B_CALCULATOR_CONVERT=STANDALONE_PASS_PRODUCT_INTEGRATION_MISSING
R8_C_GAMES=STANDALONE_PASS_PRODUCT_INTEGRATION_MISSING
R8_D_READER_PUBLICATION=STANDALONE_QUALIFIED_PRODUCT_PHYSICAL_PENDING
R8_D2_TEXT_TTS=PASS
R8_D2_OCR=NOT_INTEGRATED
R8_E_MEDIA=STANDALONE_PASS_PRODUCT_INTEGRATION_MISSING
R8_FINAL_UI_PRODUCT_COMPOSITION=FAIL
NEXT_FULL_PANTHER_BUILD_AUTHORIZED=NO
```

The final UI closure must complete shared appearance/reset/accessibility behavior, compose Reader OCR, integrate all first-party APKs into Panther, prove the exact generated package/source set, then run one final Panther build and physical acceptance campaign.

## Dependency rule

Product work still respects Android/platform boundaries:

```text
validated Panther substrate
        -> Sable Flow shared primitives
        -> Sable Start shell prototype
        -> native phone/people/messages vertical slice
        -> Sable Hub provider framework
        -> configurable installed-app / notification-conversation adapters
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
- provider capability model with native, notification-derived, supported-API and installed-app boundaries;
- product-stage markers;
- multilingual/local-first voice dependency;
- release signing explicitly separated from near-term feature work.

## M1 / CP1 — Sable Flow shell primitives + Sable Start

Status: **IMPLEMENTED IN REPOSITORY / PRODUCT INTEGRATION AND PHYSICAL ACCEPTANCE PENDING**.

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
- standalone SableLauncher owns HOME; Launcher3QuickStep is retained only for Recents/Quickstep.

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
INSTALLED_APP
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
INSTALLED_APP
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
- package + Android user/profile configuration;
- source-app-authorized RemoteInput reply when present;
- bounded local notification-derived history;
- no private messaging-app database scraping.

The Hub must expose the difference between native/API, notification-derived and installed-app capability rather than pretending every provider is a native universal integration.

## M4 / CP4 — local conversation adapters

Status: **NEXT R9 MESSAGES TRANCHE**.

Initial service targets:

```text
WhatsApp
Instagram
Facebook
LinkedIn
```

The first implementation does not require or promise a native universal client for these services.

The primary no-server integration path keeps supported official Android apps installed and treats Android's notification/conversation surface as the local adapter boundary. Users opt apps in through Settings; no provider package is compiled into Sable Messages.

Requirements:

- generic NotificationListenerService ingestion, not provider-private APIs;
- MessagingStyle/Person/conversation metadata when supplied by the source app;
- generic RemoteInput reply only when the source notification exposes a valid reply action;
- package + user/profile configuration and dynamic launcher-hiding preference;
- provider notifications remain authoritative; the first tranche does not cancel them to preserve PendingIntent/RemoteInput validity;
- callback work is copied/bounded and moved off the NotificationListener main callback;
- CE-only, bounded local history with explicit retention/privacy controls;
- no provider credentials, private databases, protocol reverse engineering or embedded WebViews;
- truthful fallback to “Open in app” when reply/history capability is unavailable.

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
- package/signing/component/privacy history;
- UI5 Settings -> Applications privacy summaries;
- UI5 Application Security & Privacy detail surface for identity/signing, authority, components, privacy signals, usage/background context and bounded local history.

The application-security surface follows `APPLICATION_SECURITY_PRIVACY_TRANSPARENCY.md` and the shared `UI_UX_CONTRACT.md`. AppManager remains a design/capability reference rather than a privileged dependency.

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
1. close R8-A shared appearance/accessibility contract
2. reconcile current Metro SableStart into the Panther production source tree
3. complete R8-D2 OCR without importing uncontrolled network/model behavior
4. freeze and integrate Calculator/Games/Reader/Media into Panther
5. pass the generated R8 final UI product-composition gate
6. run one final sandbox-qualified Panther build and full physical UI acceptance
7. begin Titan 2 N0 GSI/UI work after T0 read-only inventory; T0 may run in parallel
8. qualify configurable local notification/conversation adapters for Sable Messages
9. rerun combined R9 physical-UX module qualification and fresh Panther physical acceptance
10. production signing / OTA finalization before release candidate
```

This ordering intentionally prioritizes building SableOS as a distinct, useful operating-system experience before optimizing future production distribution machinery.
