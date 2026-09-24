# R9 SMS/MMS blocking and spam architecture

Status: **active R9 product contract**

## Decision

SableOS keeps Android's platform blocked-number provider as the single
authoritative number-blocking mechanism.

The GrapheneOS 2026081300 Dialer is pinned at:

```text
packages/apps/Dialer
6a629762cf425002d34ecf28596813babda7d751
```

That Dialer already contains the Android `BlockedNumberContract` integration,
including E.164 normalization, insert/delete operations, blocked-number
management UI, and eligibility checks for the current user.

The GrapheneOS Messaging package remains the pinned, unmodified default SMS/MMS
substrate:

```text
external/Messaging
d125442740e85c8c630c6b3c1091046166b99187
package=com.android.messaging
```

Sable Hub / Sable Messages does not become a second SMS transport stack.

## R9 number blocking

Number blocking is **low implementation risk** because the platform capability
already exists.

The R9 contract is:

1. Phone remains the user-facing owner for adding, removing and reviewing
   blocked numbers.
2. The Dialer writes Android's `BlockedNumberContract.BlockedNumbers`
   provider.
3. Android remains responsible for enforcing blocked-number behavior for calls
   and messages.
4. Sable presentation changes must not replace, bypass or fork the blocking
   provider.
5. Sable Hub must not request ownership of `SMS_DELIVER` or
   `WAP_PUSH_DELIVER`.
6. Graphene Messaging remains unmodified.

The Phone settings surface must continue to expose **Blocked numbers** whenever
the current user is eligible to manage the blocked-number provider.

## What "block" means

A blocked sender is a deterministic user decision. It is not a classifier and
does not require message-content inspection, a reputation service, machine
learning or a Sable backend.

A number/address added to Android's blocked-number provider applies at the
platform layer. SableOS therefore does not need separate call-block and
SMS-block databases.

## Automatic SMS/MMS spam classification

Automatic spam detection is a separate feature and is **medium-to-high
complexity** under the current architecture.

The default SMS application owns incoming `SMS_DELIVER` and
`WAP_PUSH_DELIVER` processing, including storage and user notification.
Because R9 deliberately keeps Graphene Messaging as an unmodified prebuilt,
Sable Hub cannot reliably classify and suppress a message before the default
SMS app processes it.

R9 therefore does **not** implement any of the following:

- a second SMS receiver competing with the default SMS app;
- notification-listener based pseudo-filtering after a message has already
  been delivered;
- silent deletion of SMS/MMS provider rows by Sable Hub;
- a remote phone-number reputation upload service;
- message-body upload to a Sable service;
- a privileged universal messaging proxy.

## Future spam-filtering options

A later release can choose one of these architectures deliberately.

### Local rules inside the default SMS application

Examples include repeated-sender rate limits, suspicious-link heuristics,
known sender allowlists, user-maintained patterns, or an on-device classifier.

This preserves privacy best, but requires source-level control of the default
SMS application or an intentionally maintained Sable SMS app.

### Local reputation database

A signed, periodically updated local hash/list can classify known abusive
senders without uploading message bodies or contact data.

This still needs integration in the default SMS delivery path to suppress or
quarantine before normal notification.

### Remote reputation

A remote reputation service can have broader coverage, but introduces backend,
privacy, abuse-reporting, false-positive, update and availability concerns.
It is not part of R9.

## R9 acceptance

Pre-image qualification must prove:

```text
R9_BLOCKED_NUMBER_PLATFORM_SUBSTRATE=PASS
R9_BLOCKED_NUMBER_SETTINGS_UI=PASS
R9_SMS_MMS_BLOCKING_OWNER=ANDROID_BLOCKED_NUMBER_PROVIDER
R9_SMS_MMS_BLOCKING_MESSAGING_FORK_REQUIRED=NO
R9_GRAPHENE_MESSAGING_SOURCE_MUTATION=NONE
R9_SMS_MMS_SPAM_CLASSIFICATION=DEFERRED_DEFAULT_SMS_INTEGRATION_REQUIRED
```

Physical acceptance after the image build must confirm that the Phone UI still
offers blocked-number management and that the installed default SMS package is
the expected pinned Graphene Messaging package.
