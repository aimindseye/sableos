# ADR-0011: Sable Hub V1 communications surface

Status: **accepted for final R9 common-product remediation**

Date: 2026-09-24

## Context

R9 physical testing proved the configurable local conversation adapter with real
third-party applications:

- Signal notification ingestion, conversation rendering and source-authorized
  RemoteInput reply work;
- WhatsApp notification ingestion/rendering work, and Android SystemUI exposes
  Reply while the current Hub reducer can lose the reply-capable child when a
  newer summary notification becomes the latest stored record;
- LinkedIn notification ingestion and Open-app fallback work without a source
  quick-reply surface;
- Telegram installation works but account setup was not completed because the
  provider requested a paid verification step in the test environment.

The implementation package is already `org.sableos.hub` / `SableHub`, but
the current product presentation still calls itself "Sable Messages" and exposes
only Messages / People as top-level pivots.

Physical use also exposed two product issues:

1. Connected Apps is a single long list of nearly every launchable package.
   Enabling or editing a provider near the bottom requires repeated scrolling.
2. Connected-app replies are handed to the source application but are not
   represented as local outgoing chat events, so the conversation view feels
   like a notification history rather than a communication thread.

Keyboard-first SableOS strengthens the need for one fast communications surface
rather than independent notification/message/email silos.

## Decision

Promote the existing SableHub implementation into the canonical Sable
communications surface.

The top-level Hub pivots are:

```text
Priority | Messages | Email | People
```

Sable Hub is an **aggregator and interaction surface**, not the owner of every
source database or account.

### Priority

Priority is local and explainable. V1 does not use opaque AI ranking.

Initial eligibility is derived from explicit state such as:

- unread SMS;
- currently active connected-app conversation notifications;
- currently active mail alerts;
- future user-marked priority people/conversations.

Every item retains source attribution and an explanation for why it appears.

### Messages

Messages contains:

- SMS conversations from Android telephony;
- user-enabled notification-derived conversation adapters;
- truthful source capability:
  - `CONVERSATION_REPLY`,
  - `NOTIFICATION_ONLY`,
  - `LAUNCH_ONLY`.

Conversation detail is chat-oriented:

- incoming items left aligned;
- locally handed-off replies right aligned;
- inline composer when the active source exposes free-form RemoteInput;
- Open source app fallback when reply is unavailable.

A successful RemoteInput handoff may be shown locally as an outgoing bubble, but
its state is **Handed off**, not delivered/read. Sable must not manufacture
delivery semantics the source did not expose.

### Email

Sable Mail remains the owner of:

- account credentials;
- IMAP/POP3/SMTP;
- MIME parsing;
- message storage;
- synchronization;
- TLS/certificate handling.

Hub must not read Sable Mail's private database.

Email enters Hub through a bounded local Sable Mail summary/provider contract
and/or Android notification contract. V1 may initially expose active/recent mail
summaries and Open in Sable Mail while the richer bounded provider is qualified.
The contract must remain local, read-only from Hub, and must not duplicate mail
credentials or full mailbox storage.

### People

People remains Android-contact backed.

Cross-provider person identity is not guessed from display names. Future
cross-source identity linking requires explicit confirmation for ambiguous
matches.

## Connected Apps management

Connected Apps becomes a two-pivot management surface:

```text
Enabled | Available
```

Rules:

- Enabled is the default management view when any providers are enabled;
- enabled providers show quick reply, launcher visibility and retention policy;
- Available contains disabled installed applications;
- Available is searchable;
- enabling an app moves it to Enabled immediately;
- disabling an app clears its derived Hub history under the existing policy and
  returns it to Available;
- no provider-specific hard-coded allowlist is required.

The full installed-app inventory remains available because future messaging apps
must work without rebuilding SableOS.

## Third-party application appearance

Hub and system surfaces follow Sable appearance.

A third-party application that chooses its own Light/Dark theme remains
authoritative for its own content. For example, LinkedIn remaining light while
SableOS is dark is not a Sable defect if LinkedIn does not follow system
`uiMode`.

## Keyboard-first behavior

The same Hub model is shared by touch and keyboard-first devices.

Keyboard-first interaction should support:

```text
Alt+H / reserved Sable Hub chord -> open Hub
1 / P  -> Priority
2 / M  -> Messages
3 / E  -> Email
4 / C  -> People
Up/Down -> move selection
Enter   -> open item
R       -> reply only when capability is present
Esc     -> back
```

Exact reserved chords remain subject to the Sable Keyboard Policy Service and
must not steal conventional app shortcuts.

## Freshness and refresh contract

Hub and Start use event-driven refresh as the primary path:

- committed connected-app history changes notify both the Hub history URI and
  the Hub live-snapshot URI;
- SableStart observes the Hub snapshot URI and refreshes its live tile;
- Hub observes the local history URI and reloads its snapshot;
- the Start Hub tile reports generic active communication attention rather than
  claiming third-party notification state is Android SMS unread state.

Both SableStart and Sable Hub also expose standard pull-to-refresh. Manual
refresh is an escape hatch for delayed provider callbacks or lifecycle races; it
does not replace event-driven updates.

## Security and privacy invariants

- Hub has no provider credentials for third-party messaging services.
- Hub does not use Accessibility scraping.
- Hub does not read third-party private databases.
- Source notification actions remain source-owned PendingIntents.
- Sable Mail private storage remains owned by Sable Mail.
- Derived local history remains credential-encrypted and bounded.
- Third-party source notifications are not cancelled merely because Hub ingests
  them.
- Capability degrades truthfully when source authority disappears.

## Panther closure

Panther remains the touch-first physical reference used to qualify the common
Hub implementation.

The final R9 Hub remediation should combine:

1. generic WhatsApp reply-handle retention;
2. Connected Apps Enabled / Available management;
3. chat-oriented local reply handoff representation;
4. Sable Hub product branding;
5. the common Hub navigation contract.

After focused qualification and one final source-bound Panther build/physical
review, Panther returns to frozen-reference status and the same Hub semantics
carry into Titan 2 / Titan 2 Elite keyboard-first work.
