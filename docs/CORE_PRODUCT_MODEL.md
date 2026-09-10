# SableOS Core Product Model

Status: **normative product architecture**.

SableOS is an Android-compatible, privacy- and security-first mobile operating system which preserves mature Android platform capability while owning the user-facing layers where Sable can materially improve attention, communication, privacy, security and interaction.

The core product principle is:

> **Applications provide capabilities; Sable organizes people, attention and actions.**

This sentence is both product language and an architecture test. SableOS should avoid rebuilding mature application/platform machinery merely for branding. It should instead make capabilities easier to understand, combine and invoke through a coherent Sable interaction model.

The concrete near-term interaction language is **Sable Flow**, defined in `SABLE_FLOW_AND_HUB_PRODUCT_PLAN.md`.

## Product boundary

SableOS separates three concerns:

```text
Android / third-party applications
        provide capabilities, content and authorized actions
                         |
                         v
AOSP / Android platform services
        provide mature enforcement and device capability
                         |
                         v
Sable product surfaces
        organize people, attention, actions, privacy and intent
```

Replacing a Sable-facing experience does not imply replacing the underlying Android service.

Examples:

- Sable Hub may replace notification/communication presentation while retaining Android NotificationManager, conversation semantics and application-authored actions.
- Sable Start may replace Launcher3 as the primary home experience after qualification while retaining ActivityManager, PackageManager and normal Android application semantics.
- Sable Phone/Messages presentation may evolve while retaining Telecom/Telephony/carrier SMS/MMS machinery.
- Sable Security & Privacy may provide a new application-transparency experience while retaining PackageManager, PermissionController and AppOps as enforcement authorities.
- Sable AOD may own ambient presentation while retaining Android display/doze/power infrastructure.
- Sable Agent may understand intent and request actions while privileged execution remains inside narrow Android/Sable services.

## Sable Flow

Sable Flow is a Metro-inspired, information-first interaction language with original Sable naming, visual assets and implementation.

Core principles:

```text
people / information / tasks before app silos
large typography and clear spatial hierarchy
live state where useful and privacy-safe
low-chrome information surfaces
fast peek / act / return workflows
one semantic model across touch and keyboard profiles
```

The UI-framework/rendering implementation remains evidence-driven. Sable Flow semantics must not depend on one renderer or one Android platform Rust compiler.

## Core Sable product surfaces

### Sable Start

`Sable Start` is the concrete Sable Flow realization of the architectural Home/launcher surface.

Responsibilities:

- vertical live-tile Start surface;
- application/service launch and task navigation;
- large typography and accent/theme system;
- live information/action tiles with privacy/redaction policy;
- fast application/service list transition;
- explicit links to Hub, Search, Security/Privacy and Agent;
- touch-first and keyboard-first semantic navigation;
- capability-driven layout rather than device-name branches;
- multilingual and accessibility-aware rendering;
- no direct privileged hardware authority.

Initial M1 tile set:

```text
PEOPLE      PHONE
MESSAGES    MAIL
CAMERA      PHOTOS
SOCIAL      CALENDAR
SETTINGS    CLOCK
```

Launcher3 remains the compatibility/reference fallback until Sable Start passes replacement gates.

### Sable Hub

The Hub is the central people, communication, attention and service surface.

It is not a second copy of every messaging/social application's private database.

Supported provider classes:

```text
NATIVE_DATA
ANDROID_NOTIFICATION
SUPPORTED_API
WEB
UNAVAILABLE
```

Provider capabilities may include:

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

The Hub must expose capability honestly. A web-backed service must not be presented as a native/API integration.

Initial social-service targets are:

```text
WhatsApp
Instagram
Facebook
LinkedIn
```

Implementation rules:

1. use native Android/Sable data where Sable legitimately owns/has access to it;
2. consume Android notification/conversation semantics and application-authorized actions where appropriate;
3. use official/supported provider APIs only for capabilities/account types they actually authorize;
4. reverify provider/API capability at implementation time because provider support/terms can change;
5. use isolated Sable-managed web capsules where a suitable native consumer API is unavailable;
6. isolate provider session/cookie/storage state by default;
7. never scrape third-party private application databases;
8. never gain broad system privilege merely because a service is surfaced in Hub.

The first Hub may organize bounded state through views such as:

```text
ALL
MESSAGES
PEOPLE
SERVICES
```

The existing attention concepts remain useful:

```text
NOW
PEOPLE
APPS
LATER
```

Exact presentation can evolve during prototyping; the semantic provider/person/action model is the stable part.

### Sable People

People is a first-class cross-surface semantic object used by Start and Hub.

Preferred local identity evidence:

```text
ContactsProvider
Android Person
conversation / shortcut identity
user-confirmed associations
```

Ambiguous cross-service identity linking must be user-confirmed. Sable must not create a permanent cloud archive of all communication as a side effect of providing person-centric organization.

### Sable Search / Command

A system-wide search and command surface across touch and physical-keyboard profiles.

Potential semantic results:

- applications/services;
- contacts/people;
- conversations/Hub entries;
- settings;
- locally indexed user content where explicitly permitted;
- Sable actions;
- agent invocation.

Search is Unicode-aware and multilingual. Original-script identity is preserved; transliteration may be an additional local matching aid.

### Sable Security & Privacy

First-class application/device security and privacy transparency.

This includes Secure Package Intelligence and ongoing Application Security & Privacy Transparency.

It should expose effective permissions/AppOps, package identity/signing, components, privacy signals, network/data-use information where reliable, history and device security posture without becoming a root/ADB super-application.

### Sable Always-On Display / Glance

Sable AOD is a low-power ambient information surface built on supported Android/device doze and display architecture.

Initial information may include:

- time/date;
- battery/charging state;
- bounded priority Hub indicators;
- missed calls/messages/calendar/reminder state where authorized;
- privacy-preserving notification summaries;
- optional voice/agent affordance.

AOD rules:

1. lock-screen privacy/redaction policy is authoritative;
2. AOD does not gain unrestricted Hub, microphone or agent privilege;
3. burn-in mitigation, refresh behavior, suspend/doze residency and battery impact require physical validation;
4. device hardware capability determines available AOD modes;
5. failure/disablement must not break Hub, lockscreen, notifications or normal suspend.

### Sable Agent

A local-first personal agent with strict privilege separation.

Preferred architecture:

```text
text / voice request
        -> Sable Agent
        -> semantic intent
        -> typed capability request
        -> narrow Sable/Android service
        -> validated action/result
```

Rejected as the base trust model:

```text
agent -> root shell
agent -> generic privileged command executor
agent -> arbitrary privileged Python/native execution
agent -> unrestricted other-app private data
agent -> unrestricted filesystem mutation
```

Optional remote models require explicit configuration and data-flow disclosure. Agent memory is local by default and user-controllable.

### Sable Voice

Voice is a shared capability serving Agent, Hub reply/actions, Search, dictation, accessibility-compatible speech output and future hands-free/AOD invocation.

The multilingual/local-first requirements are defined in `LANGUAGE_AND_VOICE_POLICY.md`.

## Native core-phone baseline

SableOS should become a usable phone before broad social integration.

Priority product surfaces:

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

The first vertical slice is:

```text
PHONE
PEOPLE
MESSAGES
SETTINGS
```

Sable presentation should sit over retained mature transport/providers/framework services where replacement would add no security/product value.

## Interaction model

The same semantic product works through multiple interaction profiles.

Touch-first Panther example:

```text
tile / swipe / tap / hold
        -> Start / Hub / semantic action
```

Keyboard-first Q25/Q27 example:

```text
focus
shortcuts
command/search
type-to-search
predictable navigation restoration
```

Exact gestures/shortcuts remain UX decisions, but semantic actions and provider/person models must be shared rather than reimplemented per device.

## Default application and platform-surface matrix

### Sable-owned / strategic replacement

```text
Home / Launcher                  -> SABLE START after qualification
Hub / communication/attention   -> SABLE OWNED
Search / command                 -> SABLE OWNED
Security & Privacy               -> SABLE OWNED
Agent                            -> SABLE OWNED
AOD / glance presentation        -> SABLE OWNED over Android doze/display
Voice orchestration              -> SABLE OWNED local-first capability
```

### Hybrid / gradual Sable presentation over retained Android machinery

```text
Phone / call history             -> SABLE PRESENTATION over Telecom/Telephony
Messages / SMS/MMS presentation  -> SABLE PRESENTATION over mature transport/provider path
Contacts / People                -> ContactsProvider retained; Sable People presentation
Settings                         -> AOSP initially; Sable high-value surfaces progressively
SystemUI                         -> AOSP initially; Sable presentation after bounded qualification
Lockscreen / Quick Settings      -> AOSP initially; evolve with SystemUI qualification
Calendar                         -> provider semantics retained; Sable presentation may evolve
Camera                           -> framework/HAL retained; app UX may evolve
```

### Retain Android/platform implementation initially

```text
Telecom / Telephony transport
SMS/MMS carrier transport
DocumentsUI / SAF
PackageInstaller enforcement
PermissionController enforcement
Android input/IME framework
WebView / maintained Chromium path
vendor HAL / modem / firmware stacks
```

### Product-specific selection rather than blind AOSP inheritance

```text
Browser    -> maintained Chromium-derived path
Email      -> standard client/provider or future Sable presentation; participates through Hub when authorized
Gallery    -> compatible option initially; Sable local-first Photos is a product candidate
RCS        -> preserve available carrier/application compatibility; do not invent a Sable transport
Social     -> Hub provider/capsule model; do not require full vendor Android apps when a safe supported alternative works
```

This matrix is a starting policy, not an excuse to ship obsolete/unmaintained applications.

## AOSP replacement gate

A Sable-owned surface may replace an Android/AOSP default only after proving:

- capability/dependency inventory;
- Android application compatibility;
- equal or narrower privilege boundary;
- localization/accessibility behavior;
- touch and keyboard interaction behavior where applicable;
- privacy/data-flow inventory;
- offline/reproducible build provenance;
- runtime stability;
- physical-device parity;
- development rollback path.

Until then, mature Android surfaces remain reference/fallback where practical.

## Product-stage build model

```text
SUBSTRATE
    Android/device bring-up; preserve capability

PRODUCT_INTEGRATION_START
    shared Sable Flow primitives and first user-facing components begin entering builds

PRODUCT_INTEGRATION
    Sable Start/Hub/native surfaces become functional and progressively default

RELEASE_CANDIDATE
    intended product/default-app composition closed; production signing/OTA becomes mandatory

PRODUCTION
    signed end-user product with mandatory product/security/privacy/update gates
```

Canonical markers:

```text
SABLEOS_CORE_PRODUCT_STAGE=SUBSTRATE|PRODUCT_INTEGRATION_START|PRODUCT_INTEGRATION|RELEASE_CANDIDATE|PRODUCTION
SABLEOS_CORE_PRODUCT_MODEL=PASS|FAIL|NOT_RUN
SABLEOS_DEFAULT_APP_MATRIX=PASS|FAIL|NOT_RUN
SABLEOS_AOSP_FOUNDATION_PRESERVED=PASS|FAIL|NOT_RUN
SABLE_FLOW_STATUS=NOT_STARTED|PLANNING_COMPLETE_IMPLEMENTATION_NEXT|PRESENT|DEFAULT|FAIL
SABLEOS_HOME_STATUS=NOT_INTEGRATED|PRESENT|DEFAULT|FAIL
SABLEOS_START_STATUS=NOT_INTEGRATED|PRESENT|DEFAULT|FAIL
SABLEOS_HUB_STATUS=NOT_INTEGRATED|PRESENT|DEFAULT|FAIL
SABLEOS_SEARCH_STATUS=NOT_INTEGRATED|PRESENT|DEFAULT|FAIL
SABLEOS_SECURITY_PRIVACY_STATUS=NOT_INTEGRATED|PRESENT|DEFAULT|FAIL
SABLEOS_AOD_STATUS=NOT_INTEGRATED|PRESENT|ENABLED|DEVICE_UNAVAILABLE|FAIL
SABLEOS_AGENT_STATUS=NOT_INTEGRATED|PRESENT|ENABLED|DISABLED_BY_DEFAULT|FAIL
SABLEOS_VOICE_STATUS=NOT_INTEGRATED|PRESENT|ENABLED|FAIL
SABLEOS_LANGUAGE_BASELINE=PASS|FAIL|NOT_RUN
```

## Current Panther effect

Panther D4 substrate/physical acceptance is closed. The project now enters:

```text
SABLEOS_CORE_PRODUCT_STAGE=PRODUCT_INTEGRATION_START
SABLE_FLOW_STATUS=PLANNING_COMPLETE_IMPLEMENTATION_NEXT
```

The first concrete gate is Sable M1: shared Sable Flow primitives plus a Sable Start prototype containing Phone, People, Messages, Settings and Social Hub tiles.

Production signing/key generation/OTA finalization is deferred and non-blocking during this stage. It becomes mandatory again before release-candidate distribution.

## Q25 / Q27 relationship

Sable Start/Hub semantics are the base for future compact/QWERTY work, not a Panther-only design.

Shared objects include:

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

Q25 may validate compact/square and keyboard-first assumptions as an engineering reference. Q27 remains a future preferred modern QWERTY direction. Device-specific forks of the common product model are rejected.

## Product outcome

SableOS should not be defined by the number of applications it forks.

Its identity is the coherent relationship between Android capabilities and Sable interaction:

> **Applications provide capabilities; Sable organizes people, attention and actions.**

Sable Start organizes access and live state. Hub organizes people, communication and services. Search organizes intent. Security & Privacy explains authority. AOD makes important state glanceable. Agent and Voice turn natural language into explicitly authorized actions. Android remains the mature compatibility and enforcement substrate beneath them.
