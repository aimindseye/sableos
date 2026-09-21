# R9 Phone + Contacts visual-first refresh

Status: **visual review only / platform mutation not started**

## Goal

Bring the platform Phone and Contacts applications into the Sable visual language
without replacing Android telephony, contacts storage, account, intent, or
provider behavior.

The target platform trees are the GrapheneOS-maintained Android 17 forks at:

- `packages/apps/Dialer`
- `packages/apps/Contacts`

The first phase is intentionally visual-only. The Mac mini / Pixel 7 AVD review
must be accepted before patches are authored against either platform tree.

## Capability boundary

The refresh may change presentation and theme behavior but must preserve:

- Android Telecom and in-call session ownership;
- existing Dialer favorites/call-log/contacts/voicemail navigation semantics;
- call history and voicemail behavior;
- ContactsProvider-backed storage and queries;
- account/group/contact editing semantics;
- Android permission checks and runtime permission ownership;
- vCard/import/export and existing contact intents;
- emergency and carrier-sensitive telephony behavior.

No Sable replacement provider, telephony service, contact database, or account
layer is introduced.

## Visual direction

Both apps use the existing `SableTheme` contract.

Phone:

- large lowercase Metro-derived title;
- flat search/action affordance with Sable accent rule;
- call history as label-first rows separated by hairlines;
- existing favorites/recent/contacts/voicemail concepts retained;
- dialpad uses typography and whitespace rather than raised key cards;
- in-call controls remain obvious while avoiding heavy Material surfaces;
- destructive end-call action remains semantically distinct.

Contacts:

- large lowercase title;
- flat search + add affordance;
- alphabetized label-first rows with a reachable right-edge rail;
- account/group concepts remain available without becoming the dominant chrome;
- contact detail is typography-first with flat action affordances;
- no invented network/cloud status.

## Review module

The non-product module is:

`apps/r8/android/phone-contacts-visual-review`

Application ID:

`org.sableos.phonecontacts.visualreview`

It contains representative fixture data only. It does not read call logs,
contacts, Telecom, ContactsProvider, or the network.

Required capture set:

- `00-phone-recents-light`
- `01-phone-dialpad-light`
- `02-phone-in-call-light`
- `03-contacts-list-light`
- `04-contact-detail-light`
- `05-phone-recents-dark`
- `06-contacts-list-dark`

The Mac runner captures each state directly through explicit activity extras so
review does not depend on manual navigation timing.

## Gate transition

Before visual acceptance:

`R9_PHONE_CONTACTS_VISUAL_REVIEW_STATUS=PENDING_USER_REVIEW`

`R9_PHONE_CONTACTS_PLATFORM_SOURCE_MUTATION=NONE_VISUAL_PHASE`

After visual acceptance, the next deliverable is a platform patch/gate set for
Dialer + Contacts followed by focused local module builds. A Panther target-files
build is not part of the visual phase.
