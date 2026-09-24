# ADR-0008: Configurable local conversation adapters

Status: **Accepted for R9 implementation**

Date: 2026-09-23

## Context

Sable Messages needs to unify communication without requiring a Sable-operated
cloud relay and without embedding unofficial provider clients.

The previous provider-capsule approach was rejected because provider web
experiences are not reliable primary-client/account-bootstrap surfaces and add
credential/session/network ownership to Sable Messages.

A provider-specific Android integration is also the wrong scaling model. Users
may install Signal, Telegram, Session, Element, Threema or future messaging
applications. SableOS must not require source changes or recompilation for every
compatible app.

Android already exposes an application-authored conversation boundary through
NotificationListenerService, MessagingStyle/Person metadata, notification
conversation identifiers, PendingIntent actions and RemoteInput quick reply.

## Decision

Sable Messages implements one generic **Local Conversation Adapter** layer.

Configuration identity is:

```text
(packageName, Android user/profile)
```

not a compile-time provider enum.

Users explicitly opt installed applications in through:

```text
Settings
  -> Messages
      -> Connected apps
```

The first implementation supports per-app policy for:

- include in Sable Messages;
- allow source-authorized quick reply;
- hide from SableLauncher;
- notification-derived local-history retention.

## Capability model

Adapters are classified by observed Android capability rather than brand:

```text
CONVERSATION_REPLY
    structured conversation metadata + valid RemoteInput/PendingIntent reply

NOTIFICATION_ONLY
    bounded notification-derived timeline + Open in app

LAUNCH_ONLY
    insufficient usable notification content
```

Capability is dynamic. If an app changes its notification shape or removes a
reply action, Sable degrades rather than fabricating capability.

## Trust boundary

The installed source app remains authoritative for:

- account/session authentication;
- provider networking/push;
- end-to-end cryptography;
- complete provider history;
- attachment transfer;
- delivery/read semantics not exposed through Android;
- voice/video and provider-specific actions.

Sable Messages does not:

- read private application databases;
- use Accessibility to scrape provider UI;
- capture provider credentials/tokens;
- reverse-engineer provider protocols;
- embed provider login WebViews;
- claim notification-derived history is complete provider history.

## Notification listener lifecycle

NotificationListenerService callbacks perform bounded extraction only.

```text
onNotificationPosted()
    -> resolve package/profile
    -> consult in-process policy snapshot
    -> extract bounded text/conversation metadata
       (<=25 messages, <=8 actions, <=4 RemoteInputs/action)
    -> retain at most one source-owned reply handle
    -> enqueue bounded envelope
    -> worker dispatcher
        -> source-app label lookup
        -> normalize
        -> identity resolution
        -> CE-local SQLite persistence
        -> Sable Messages state update
```

The full Notification object, RemoteViews and arbitrary extras are not handed to
the worker. No database write, contact query, bitmap decode or whole-history
reconstruction runs directly in the listener callback.

The first tranche does not cancel source notifications. Their PendingIntent and
RemoteInput objects remain the application-authorized reply/open channel.

## Identity model

The local model separates provider identity from Sable person identity:

```text
SablePerson
    <- LinkedIdentity(packageName, user, sourceConversationId, sourcePersonKey)
    <- UnifiedMessage
```

Automatic linking may use strong local evidence such as normalized phone
identity where available. Display-name-only matches are not sufficient for
automatic cross-provider merges. Ambiguous links require user confirmation.

## Storage and privacy

Notification-derived content is stored in Sable Messages' normal
credential-encrypted app-private SQLite database. The derived store is capped
at 1,200 records and pruned transactionally by per-app retention policy.

Notification-derived content is:

- unavailable through device-protected storage before credential unlock;
- bounded by configurable retention and the global record cap;
- limited to content actually exposed by the source notification;
- removable when the user disconnects an app or clears its local history.

The source application's notification privacy choice is authoritative. Sable
does not reconstruct message text the source intentionally withholds.

## Launcher integration

SableLauncher reads a dynamic hidden-package policy rather than hard-coding
third-party messaging packages. Hiding affects presentation only; it does not
disable/uninstall the package.

The retained Graphene Messaging transport package remains a separately
documented product exception until Sable owns and qualifies the full default
SMS/MMS role contract.

## Consequences

Benefits:

- no Sable cloud server required;
- no provider credentials in Sable;
- low incremental network/battery cost;
- compatible new apps can be enabled through Settings without recompilation;
- provider cryptography/protocol maintenance remains with provider apps;
- Windows-Phone-style person-centric presentation remains possible.

Limitations:

- Sable sees only notification-exposed history;
- muted/suppressed/non-notifying messages may be absent;
- reply is available only when source app exposes RemoteInput;
- rich provider actions may still require opening the source app.

These limitations must be presented truthfully in product UI.
