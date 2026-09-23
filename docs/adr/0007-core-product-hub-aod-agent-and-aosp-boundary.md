# ADR 0007: Revised SableOS core product boundary

Status: **Accepted**

## Context

SableOS needs a clear product identity without turning into a wholesale reimplementation of Android. Earlier architecture already established that mature AOSP/vendor capability should be preserved unless Sable has a demonstrated security, privacy, maintainability or product reason to replace it.

The product direction has now converged around a small number of strategic Sable-owned surfaces:

- Home;
- Hub;
- Search / command;
- Security & Privacy;
- Always-On Display / glance presentation;
- local-first Agent;
- shared multilingual Voice capability.

These surfaces should work across touch-first and keyboard-first devices and should remain compatible with ordinary Android applications.

The working product tagline/principle is:

> **Applications provide capabilities; Sable organizes people, attention and actions.**

## Decision

SableOS adopts the core product model defined in `../CORE_PRODUCT_MODEL.md`.

Sable owns the user-facing organization layer where it can provide a differentiated experience, while retaining Android as the mature capability, compatibility and enforcement substrate.

### Strategic Sable-owned surfaces

Sable will build and eventually make first-class/default, after qualification:

```text
Sable Home
Sable Hub
Sable Search / Command
Sable Security & Privacy
Sable AOD / Glance presentation
Sable Agent
Sable Voice orchestration
```

### Retained Android foundations

Sable does not rebuild mature platform machinery merely for branding. Android framework/services remain authoritative for areas such as:

- PackageManager / ActivityManager;
- NotificationManager and notification actions;
- PermissionController / AppOps;
- ContactsProvider and standard contact/account semantics;
- Telecom / Radio HAL / vendor RIL / IMS;
- SMS/MMS/carrier transport;
- DocumentsUI / SAF;
- input/IME infrastructure;
- WebView and browser engine substrate;
- display/doze/power/HAL infrastructure;
- camera/audio/media/network/vendor hardware stacks.

### Hub

Hub is the central attention/communication surface. It uses standard Android notification/conversation metadata and application-authorized actions. It does not require direct access to private databases of messaging applications.

Reply and other generic actions use application-supplied Android actions such as `RemoteInput`/`PendingIntent` semantics. Person linking is local-first and evidence-based.

### Notification delivery and presentation boundary

Sable does not introduce or search for a GrapheneOS-specific notification-manager stack. Android/AOSP `NotificationManager`, notification channels, conversation metadata, `RemoteInput`, `PendingIntent` actions and the existing SystemUI notification presentation path remain authoritative.

Notification **delivery to an application before it posts an Android notification** is a separate application/provider concern:

- an app may use Firebase Cloud Messaging when it depends on FCM and the user has chosen to install sandboxed Google Play;
- a portable app may maintain its own push connection, for example WebSocket-style messaging or IMAP IDLE for mail;
- an app may use UnifiedPush when it explicitly supports that ecosystem;
- infrequent pull-based work should use Android scheduling such as `JobScheduler`, rather than Sable inventing a privileged polling daemon.

Sable Hub consumes the Android notification/conversation surface after the application has posted it. Hub must not become a universal push proxy, obtain provider credentials merely to relay notifications, or bypass Android application sandboxing.

For Sable Mail, the retained mail client's own supported background synchronization / IMAP IDLE behavior is preferred. Sable must not add an FCM middleman that requires uploading mail credentials to a Sable server solely to generate notifications.

For the GrapheneOS 2026081300 substrate, `external/Messaging` is a pinned `android_app_import` containing `prebuilt/Messaging.apk`; it is not source code with an Android manifest that Sable should rewrite. Sable preserves that prebuilt package unchanged as the default SMS/MMS transport substrate. Duplicate launcher presentation is handled by standalone SableLauncher suppressing only package `com.android.messaging`. Sable Messages owns the normal SMS/People presentation and uses standard Android messaging intents only for contextual MMS/attachment handoff rather than taking ownership of the prebuilt's transport internals.

Embedded WhatsApp/Instagram/Messenger/LinkedIn WebViews are retired from Sable Messages. Proprietary social services use their supported installed Android applications when the user chooses to install them, with future Sable integration limited to supported intents, share/deep-link surfaces and user-authorized Android notification/conversation metadata. Sable does not capture provider credentials or emulate a provider's primary client in WebView.

Reference: GrapheneOS FAQ, “Do notifications work properly on GrapheneOS?” — https://grapheneos.org/faq#notifications

### Local third-party conversation adapters

For R9, third-party messaging integration uses Android's application-authored
notification/conversation surface rather than a Sable cloud relay, embedded
provider WebView or provider protocol implementation.

The user explicitly enables installed apps. Configuration is package +
Android-user/profile based, so new compatible apps do not require recompilation.
A NotificationListenerService normalizes structured MessagingStyle/Person data
where available and may invoke only a source-authored RemoteInput/PendingIntent
reply action. Generic notification text is a bounded fallback, not proof of
complete provider history.

The source application remains authoritative for networking, account state,
cryptography, complete history and rich-provider actions. Sable does not obtain
provider credentials or inspect private application databases.

Notification-listener callbacks perform only bounded extraction/enqueue work;
persistence, person linking and expensive normalization run off the callback
thread. Notification-derived history is credential-encrypted and retention is
user-configurable.

The first tranche keeps source notifications alive rather than canceling them,
because their PendingIntent/RemoteInput objects are part of the authorized
reply path.

This architecture is detailed in ADR-0008 and
`../R9_MESSAGES_LOCAL_CONVERSATION_ADAPTERS.md`.

### AOD

AOD is Sable presentation layered over supported Android/device doze/display capability. Lock-screen privacy remains authoritative. AOD does not gain unrestricted microphone, Hub or Agent privilege.

### Agent

The Agent is local-first and may interpret text/voice intent, maintain bounded user-approved local memory and invoke Sable capabilities. It must request typed semantic actions through narrow services.

A generic root shell, arbitrary privileged Python/native execution and unrestricted other-app/private-files access are rejected as the base trust model.

Optional remote model providers require explicit configuration and data-flow disclosure. They are never a silent fallback from local processing.

### Voice and language

Voice is shared infrastructure for Agent, Hub, Search, dictation and accessibility-compatible output. Multilingual/local-first requirements are governed by `../LANGUAGE_AND_VOICE_POLICY.md`.

## Default-app strategy

The default is selective replacement, not maximum forking.

- Home/Hub/Search/Security-Privacy/AOD/Agent/Voice are strategic Sable surfaces.
- Settings/SystemUI/lockscreen evolve gradually from AOSP rather than being replaced wholesale at the start.
- Phone, SMS/MMS, DocumentsUI, PackageInstaller, PermissionController, input framework and other mature compatibility/system components remain Android-based initially.
- Browser selection must use a maintained Chromium-derived path rather than an obsolete AOSP browser implementation.
- Sable does not need to build its own email client for V1; standard mail clients can participate through Hub.

Any replacement still requires the preserve-before-remove/capability-parity gate.

## Build integration

Build/release validation uses these product stages:

```text
SUBSTRATE
PRODUCT_INTEGRATION
RELEASE_CANDIDATE
PRODUCTION
```

During `SUBSTRATE`, absence of Sable Home/Hub/AOD/Agent/Voice is expected and recorded as `NOT_INTEGRATED` rather than failure.

During `PRODUCT_INTEGRATION`, each intentionally added/replaced surface must prove image presence, expected default/role assignment where applicable, privilege/data-flow state and retained AOSP capability.

`RELEASE_CANDIDATE` and `PRODUCTION` require the intended default-app matrix to be closed and validated.

The active Panther P1B target-files build is `SUBSTRATE` and predates this ADR. It is not restarted or invalidated by this decision.

## Consequences

Positive:

- clearer SableOS product identity;
- less unnecessary application/platform duplication;
- Hub/people/attention model becomes a first-class architecture goal;
- AOD and Agent integrate through existing security boundaries rather than creating new super-privileged UI code;
- standard Android applications remain the ecosystem foundation;
- touch-first and keyboard-first devices share the same semantic product.

Costs:

- Sable must maintain clear adapter/broker APIs between product surfaces and Android services;
- Hub semantics depend on the quality of application-provided notification/conversation actions;
- AOD requires device-specific power/display validation;
- local agent/voice models add memory, battery, model-provenance and privacy engineering work;
- gradual replacement means some releases intentionally contain mixed AOSP and Sable presentation layers.

## Rejected alternatives

### Rebuild every default Android application

Rejected because it creates large maintenance and security burden without necessarily improving the product.

### Make the Agent a universal privileged automation daemon

Rejected because prompt injection/model failure would become a direct privilege-escalation path.

### Implement Hub by reading private app databases

Rejected because it breaks application sandboxing and does not generalize across the Android ecosystem.

### Require always-listening voice for AOD/Agent

Rejected. Explicit invocation is the baseline; wake word is a separately validated optional capability.

## Normative implementation

See:

- `../CORE_PRODUCT_MODEL.md`;
- `../AOSP_CAPABILITY_POLICY.md`;
- `../INTERACTION_PROFILES.md`;
- `../APP_SECURITY_AND_COMPATIBILITY.md`;
- `../APPLICATION_SECURITY_PRIVACY_TRANSPARENCY.md`;
- `../LANGUAGE_AND_VOICE_POLICY.md`;
- `../SECURITY_PRIVACY_ASSURANCE_STANDARD.md`;
- `../RELEASE_VALIDATION.md`.
