# SableOS Core Product Model

Status: **normative product architecture**.

SableOS is an Android-compatible, privacy- and security-first mobile operating system which preserves mature Android platform capability while owning the user-facing layers where Sable can materially improve attention, communication, privacy, security and interaction.

The core product principle and working tagline is:

> **Applications provide capabilities; Sable organizes people, attention and actions.**

This sentence is both product language and an architecture test. SableOS should avoid rebuilding mature application/platform machinery merely for branding. It should instead make capabilities easier to understand, combine and invoke through a coherent Sable interaction model.

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

- Sable Hub may replace notification presentation while retaining Android NotificationManager and application-authored notification actions.
- Sable Home may replace Launcher3 as the primary home experience after qualification while retaining ActivityManager, PackageManager and normal Android application semantics.
- Sable Security & Privacy may provide a new application-transparency experience while retaining PackageManager, PermissionController and AppOps as enforcement authorities.
- Sable AOD may own the ambient presentation while retaining Android display/doze/power infrastructure.
- Sable Agent may understand intent and request actions while privileged execution remains inside narrow Android/Sable services.

## Core Sable product surfaces

The intended core SableOS experience consists of these Sable-owned product surfaces.

### Sable Home

Primary launcher/home and shell entry point.

Responsibilities:

- touch-first and keyboard-first home presentation;
- application launch and task navigation;
- quick access to Hub, Search, Agent and Security/Privacy;
- capability-driven layout rather than device-name branches;
- multilingual and accessibility-aware rendering;
- no direct privileged hardware authority.

Launcher3 remains the compatibility/reference baseline until Sable Home passes replacement gates.

### Sable Hub

The Hub is the central attention and communication surface.

Its goal is not to become a second copy of every messaging application's database. It consumes Android-supported notification/conversation semantics and application-authorized actions.

The initial semantic views are:

```text
NOW      current attention / priority / messages / calls / alerts
PEOPLE   person-centric communication and conversation grouping
APPS     source/application-oriented notification view
LATER    snoozed, deferred or explicitly saved attention
```

The Hub should support actions such as:

```text
reply
open
mark read when the source exposes such an action
call back
snooze
dismiss/archive where semantically valid
save/defer
```

Generic reply should use application-supplied Android `RemoteInput` / notification actions rather than impersonating the source application.

Person linking is local-first and evidence-based. Prefer Android `Person`, conversation/shortcut identity and ContactsProvider associations. Ambiguous cross-application identity linking should be user-confirmed rather than silently inferred by a remote service.

Hub history is bounded and local by default. Sable must not create a permanent cloud archive of all notification content as a side effect of providing a unified inbox.

### Sable Search / Command

A system-wide search and command surface which works across touch and physical-keyboard profiles.

It should organize local, authorized capability rather than becoming a universal privileged executor.

Potential semantic results include:

- applications;
- contacts/people;
- conversations/Hub entries;
- settings;
- locally indexed user content where explicitly permitted;
- Sable actions;
- agent invocation.

Search is Unicode-aware and multilingual. Original-script identity is preserved; transliteration may be an additional local matching aid.

### Sable Security & Privacy

First-class application/device security and privacy transparency.

This includes the Secure Package Intelligence and ongoing Application Security & Privacy Transparency architecture defined elsewhere.

It should expose effective permissions/AppOps, package identity/signing, components, privacy signals, network/data-use information where reliable, history and device security posture without becoming a root/ADB super-application.

### Sable Always-On Display / Glance

Sable AOD is a low-power ambient information surface built on the supported Android/device doze and display architecture.

Initial information may include:

- time/date;
- battery/charging state;
- bounded priority Hub indicators;
- missed calls/messages/calendar/reminder state where authorized;
- privacy-preserving notification summaries;
- optional voice/agent affordance.

AOD rules:

1. lock-screen privacy/redaction policy is authoritative;
2. AOD does not gain unrestricted Hub, microphone or agent privilege merely because it presents an affordance;
3. burn-in mitigation, refresh behavior, suspend/doze residency and battery impact require physical validation;
4. device hardware capability determines available AOD modes;
5. failure or disablement of AOD must not break notifications, Hub, lockscreen or normal suspend;
6. always-listening voice is not required for AOD.

AOD is a Sable presentation capability layered on mature display/power infrastructure, not a reason to replace the vendor display stack.

### Sable Agent

A local-first on-device personal agent inspired by useful ideas from projects such as `flagdizero/jenny-android-ai-agent`, but with a stricter Sable privilege boundary.

The agent may provide:

- natural-language and voice command interpretation;
- local user-approved memory/context;
- Hub triage and response assistance;
- Search/command assistance;
- reminders and bounded scheduled actions;
- composition/summarization over data the user explicitly authorizes;
- invocation of typed Sable/Android capabilities.

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
agent -> arbitrary Python/native execution with OS privilege
agent -> unrestricted other-app private data
agent -> unrestricted filesystem mutation
```

Agent model providers are capability choices. Local inference is preferred where practical. Optional remote models require explicit user configuration, clear data-flow disclosure and must never be a silent fallback from a local operation.

Agent memory is local by default, user-controllable and covered by the privacy inventory/retention policy. Raw microphone streams are not agent memory.

### Sable Voice

Voice is a shared product capability rather than a separate assistant silo.

It serves:

- Agent;
- Hub reply/actions;
- Search;
- dictation;
- accessibility-compatible speech output;
- future AOD/hands-free invocation.

The multilingual/local-first requirements are defined in `LANGUAGE_AND_VOICE_POLICY.md`.

## Interaction model

The same semantic product works through multiple interaction profiles.

Touch-first example:

```text
swipe / tap / hold
        -> Hub/Search/Home semantic action
```

Keyboard-first example:

```text
H       Hub
/       Search
J/K     next/previous
R       reply
S       snooze
Enter   open/activate
```

Exact shortcuts remain a UX decision, but the semantic action must be shared rather than reimplemented separately per device.

## Default application and platform-surface matrix

The initial policy is to preserve mature AOSP capability and selectively replace presentation.

### Sable-owned / strategic replacement

```text
Home / Launcher                  -> SABLE_OWNED after qualification
Hub / notification presentation -> SABLE_OWNED
Search / command                 -> SABLE_OWNED
Security & Privacy               -> SABLE_OWNED
Agent                            -> SABLE_OWNED
AOD / glance presentation        -> SABLE_OWNED over Android doze/display
Voice orchestration              -> SABLE_OWNED local-first capability
```

### Hybrid / gradual Sable presentation over retained Android machinery

```text
Settings                         -> AOSP initially; Sable high-value surfaces gradually
SystemUI                         -> AOSP initially; Sable presentation only after bounded qualification
Lockscreen / Quick Settings      -> AOSP initially; evolve with SystemUI qualification
Contacts / People                -> retain ContactsProvider; Sable people experience may evolve
```

### Retain AOSP/platform implementation initially

```text
Phone / Telecom / InCallUI       -> RETAIN mature Android path
SMS/MMS transport                -> RETAIN mature Android/carrier path
Calendar/provider semantics      -> RETAIN
DocumentsUI / SAF                -> RETAIN
PackageInstaller                 -> RETAIN enforcement path, add Sable review around it
PermissionController             -> RETAIN enforcement path
Camera framework/HAL             -> RETAIN; app UX replacement is optional/later
Clock                            -> RETAIN initially
Calculator                       -> RETAIN initially
Android input/IME framework      -> RETAIN
WebView                          -> RETAIN maintained Android/Chromium path
```

### Product-specific selection rather than blind AOSP inheritance

```text
Browser    -> maintained Chromium-derived browser path; do not rely on obsolete AOSP Browser
Email      -> no requirement to build a Sable mail client for V1; standard clients participate through Hub
Gallery    -> existing compatible option initially; Sable local-first gallery is a later candidate
RCS        -> do not invent a Sable transport; preserve available carrier/application compatibility
```

This matrix is a starting policy, not an excuse to ship obsolete or unmaintained applications. Security maintenance and application quality remain release requirements.

## AOSP replacement gate

A Sable-owned surface may replace an AOSP default only after proving:

- capability/dependency inventory;
- Android application compatibility;
- equal or narrower privilege boundary;
- localization/accessibility behavior;
- touch and keyboard interaction behavior where applicable;
- privacy/data-flow inventory;
- offline/reproducible build provenance;
- runtime stability;
- physical-device parity;
- rollback path during development.

Until then, the mature AOSP surface remains available as reference/fallback where practical.

## Product-stage build model

Build and release gates distinguish substrate bring-up from actual Sable product integration.

```text
SUBSTRATE
    Android/device bring-up; preserve AOSP capability

PRODUCT_INTEGRATION
    Sable-owned product surfaces begin entering images

RELEASE_CANDIDATE
    intended default-app/product composition is closed

PRODUCTION
    signed end-user product with all mandatory product/security/privacy gates
```

Canonical markers:

```text
SABLEOS_CORE_PRODUCT_STAGE=SUBSTRATE|PRODUCT_INTEGRATION|RELEASE_CANDIDATE|PRODUCTION
SABLEOS_CORE_PRODUCT_MODEL=PASS|FAIL|NOT_RUN
SABLEOS_DEFAULT_APP_MATRIX=PASS|FAIL|NOT_RUN
SABLEOS_AOSP_FOUNDATION_PRESERVED=PASS|FAIL|NOT_RUN
SABLEOS_HOME_STATUS=NOT_INTEGRATED|PRESENT|DEFAULT|FAIL
SABLEOS_HUB_STATUS=NOT_INTEGRATED|PRESENT|DEFAULT|FAIL
SABLEOS_SEARCH_STATUS=NOT_INTEGRATED|PRESENT|DEFAULT|FAIL
SABLEOS_SECURITY_PRIVACY_STATUS=NOT_INTEGRATED|PRESENT|DEFAULT|FAIL
SABLEOS_AOD_STATUS=NOT_INTEGRATED|PRESENT|ENABLED|DEVICE_UNAVAILABLE|FAIL
SABLEOS_AGENT_STATUS=NOT_INTEGRATED|PRESENT|ENABLED|DISABLED_BY_DEFAULT|FAIL
SABLEOS_VOICE_STATUS=NOT_INTEGRATED|PRESENT|ENABLED|FAIL
SABLEOS_LANGUAGE_BASELINE=PASS|FAIL|NOT_RUN
```

`NOT_INTEGRATED` is valid during `SUBSTRATE`; it is not a production pass.

## Current Panther effect

The active Panther P1B work is `SUBSTRATE`.

It must preserve Android capability and avoid choices which make the core product architecture impossible, but it is **not** required to contain Sable Home, Hub, AOD, Agent or Voice yet. The revised product model therefore does not restart, invalidate or mutate the current target-files integration build.

The core-product gate becomes materially enforcing during post-V0 Sable UI/product integration.

## Product outcome

SableOS should not be defined by the number of applications it forks.

Its identity is the coherent relationship between Android capabilities and Sable interaction:

> **Applications provide capabilities; Sable organizes people, attention and actions.**

Home organizes access. Hub organizes attention and people. Search organizes intent. Security & Privacy explains authority. AOD makes important state glanceable. Agent and Voice turn natural language into explicitly authorized actions. Android remains the mature compatibility and enforcement substrate beneath them.
