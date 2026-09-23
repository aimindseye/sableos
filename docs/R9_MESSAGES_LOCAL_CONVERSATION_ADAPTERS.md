# R9 Messages Local Conversation Adapter Foundation

Status: **source implementation complete; focused module qualification pending**

Base behavior already qualified:

- Sable Messages normal surface is Messages + People;
- embedded provider WebViews are retired;
- Sable Messages does not request Internet solely to host provider sessions;
- Graphene Messaging remains the SMS/MMS role/transport substrate;
- SMS/contact snapshot loading is off-main;
- conversation/people/thread rendering is lazy.

## Objective

Add a configurable, provider-agnostic local conversation layer using standard
Android notification/conversation contracts.

Adding Signal, Telegram or another compatible installed messaging app must not
require rebuilding SableOS.

## Product flow

```text
Settings -> Messages -> Connected apps
    -> select installed app
       [x] Include in Sable Messages
       [x] Allow quick reply
       [ ] Hide from SableLauncher
       retention: 7 days / 30 days / until deleted
```

Sable Messages then presents notification-derived conversations alongside local
SMS conversations using truthful per-channel capability.

## Source contracts

### Configuration

Persist:

```text
ConnectedAppKey(
    packageName,
    userSerial
)
```

Each record stores policy only. It does not store provider credentials.

### Listener

A platform NotificationListenerService receives posted/removed events.

Fast callback path:

1. determine source package/user;
2. consult the in-process immutable Connected Apps policy cache;
3. reject packages/profiles that are not enabled;
4. extract at most 25 MessagingStyle messages, 8 actions and 4 RemoteInputs
   per action;
5. bound labels/identifiers to 256/512 characters and bodies to 4096
   characters;
6. retain at most one source-owned free-form RemoteInput/PendingIntent handle;
7. enqueue the bounded envelope and return.

The full Notification object, RemoteViews and arbitrary extras are not handed to
the worker.

Heavy work is off-callback:

- source-app label lookup;
- conversation/title normalization;
- credential-encrypted SQLite history update;
- retention cleanup.

Cross-provider person/identity linking is part of the accepted architecture but
is deliberately deferred from this foundation tranche. Until that separately
qualified tranche lands, provider conversations remain distinct and Sable does
not guess identity from display names.

### Normalized model

```text
UnifiedConversation
    localConversationId
    personId?
    sourcePackage
    sourceUserSerial
    sourceConversationId
    displayName
    capability

UnifiedMessage
    localMessageId
    conversationId
    sourceNotificationKey
    sourceMessageId?
    senderLabel?
    timestamp
    body?
    incoming
    capability
```

The first tranche uses an app-private SQLite database
(`sable_connected_message_history.db`) in normal credential-encrypted app
storage. It is capped at 1,200 derived message records, uses source and
conversation indexes, and prunes disabled/expired records transactionally.
Connected-app policy remains small SharedPreferences-backed configuration;
message history does not use SharedPreferences.

### Reply

A reply is enabled only when the active source notification exposes a free-form
RemoteInput action and the Connected App policy allows reply.

Sable injects the reply result into the source PendingIntent. It does not open a
provider socket or API.

If the reply action disappears, the UI degrades immediately to Open in app.

### Source notification policy

Do not cancel provider notifications in the first tranche. This preserves the
source application's PendingIntent/RemoteInput authority and avoids making
Sable Messages responsible for notification lifecycle/ranking.

A future SystemUI de-duplication policy may suppress duplicate presentation
without invalidating the underlying source notification.

### Launcher hiding

Replace third-party hard-coded hiding with a dynamic settings-backed policy.

The launcher inventory asks for hidden packages for the target Android user.
Connected-app policy can optionally hide a provider from All Apps while leaving
it installed/enabled.

The existing hidden Graphene Messaging package is migrated into the same policy
mechanism or retained as one explicit system-product rule until that migration
is separately qualified.

## Security/privacy invariants

- notification access requires explicit user authorization;
- only enabled package/user pairs are ingested;
- no Internet permission is required for the adapter itself;
- no private app DB access;
- no Accessibility scraping;
- no provider credential/token storage;
- no WebView provider sessions;
- no source-notification cancellation in tranche 1;
- callback does no blocking database/contact work;
- local history is CE-only and bounded;
- source redaction is respected;
- this foundation does not auto-link people across providers; a future
  identity-linking tranche must require confirmation for ambiguous matches.

## Qualification

Static/source:

```text
R9_MESSAGES_CONNECTED_APPS=PASS_CONFIGURABLE_PACKAGE_USER
R9_MESSAGES_NOTIFICATION_LISTENER=PASS_GENERIC
R9_MESSAGES_LISTENER_CALLBACK=PASS_BOUNDED_MEMORY_POLICY
R9_MESSAGES_REMOTE_INPUT=PASS_SOURCE_AUTHORIZED_ONLY
R9_MESSAGES_PRIVATE_DATABASE_ACCESS=PASS_ABSENT
R9_MESSAGES_PROVIDER_WEBVIEW=PASS_ABSENT
R9_MESSAGES_PROVIDER_CREDENTIALS=PASS_ABSENT
R9_MESSAGES_NOTIFICATION_HANDOFF=PASS_NO_FULL_NOTIFICATION
R9_MESSAGES_HISTORY=PASS_CE_BOUNDED_SQLITE
R9_MESSAGES_LAUNCHER_HIDE_POLICY=PASS_DYNAMIC
R9_MESSAGES_LAUNCHER_POLICY_CALLER_BOUNDARY=PASS_LAUNCHER_ONLY
R9_MESSAGES_LAUNCHER_INVENTORY_REFRESH=PASS_OFF_MAIN
```

Focused module qualification is staged so source-quality failures are rejected
before compilation or APK packaging:

1. source contracts and pipeline contract;
2. non-Gradle source-style preflight for Hub Kotlin/Kotlin scripts
   (line length, whitespace, and chained-query continuation indentation);
3. Detekt + KtLint static-quality preflight;
4. Kotlin compilation + unit tests + Android lint;
5. APK assembly only after the earlier stages pass.

Warnings remain errors, Detekt/KtLint remain fail-closed, and product/model code
must be refactored rather than added to quality-rule exclusion lists merely to
make qualification pass. No full Panther build is authorized solely by this
tranche.

Physical acceptance after a future image:

- grant notification access explicitly;
- enable at least two installed messaging apps without source changes;
- receive messages into distinct local conversations;
- prove disabled app notifications are not persisted;
- prove reply works only when the source offers RemoteInput;
- prove Open in app fallback works;
- prove app hiding toggles dynamically in SableLauncher;
- prove source notifications remain functional;
- prove reboot/unlock restores policy/history only after CE availability.
