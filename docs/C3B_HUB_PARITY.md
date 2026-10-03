# C3B Sable Hub / Connected Apps parity contract (D4)

This is a contract, not an implementation. `apps/r8/android/hub` stays canonical SableOS source; nothing from it is imported into or changed by this
repository, and D4 changes no Hub Android or Kotlin code. The machine-readable form is `docs/C3B_HUB_PARITY.env` and is gate-enforced.

Sable Hub functionality already built and physically exercised on Panther must not be lost on Titan 2 / Titan 2 Elite, and Sable Messages (D4) is not a path to losing it.

```text
SABLE_MESSAGES_AND_SABLE_HUB_ARE_SEPARATE_PRODUCT_SURFACES=YES
D4_MESSAGES_REPLACES_SABLE_HUB=NO
D4_MESSAGES_WEAKENS_CONNECTED_APPS=NO
```

## Required semantics

```text
C3B_HUB_CANONICAL_OWNER=CANONICAL_SABLEOS
C3B_HUB_PANTHER_V1_SEMANTICS_REQUIRED=YES
C3B_HUB_CONNECTED_APPS=REQUIRED
C3B_HUB_GENERIC_NOTIFICATION_ADAPTER=REQUIRED
C3B_HUB_REMOTEINPUT_REPLY=REQUIRED
C3B_HUB_OPEN_APP_FALLBACK=REQUIRED
C3B_HUB_PACKAGE_USER_POLICY=REQUIRED
C3B_HUB_LOCAL_BOUNDED_HISTORY=REQUIRED
C3B_HUB_DYNAMIC_PROVIDER_DISCOVERY=REQUIRED
C3B_HUB_PROVIDER_SPECIFIC_ALLOWLIST=NO
C3B_HUB_PRIVATE_PROVIDER_PROTOCOLS=NO
C3B_HUB_PROVIDER_CREDENTIALS=NO
C3B_HUB_PRIVATE_DATABASE_SCRAPING=NO
C3B_HUB_PROVIDER_WEBVIEWS=NO
C3B_HUB_DEVICE_RUNTIME_VALIDATED=NO
```

The architecture is provider-generic: package plus Android user/profile configuration, `NotificationListenerService` ingestion, Android
conversation/MessagingStyle metadata, source-owned `RemoteInput` reply, an Open-app fallback and bounded local derived history. The canonical
implementation lives in `SableNotificationListenerService.kt`, `ConnectedNotificationNormalizer.kt`, `ConnectedReplyRegistry.kt`,
`ConnectedNotificationHistoryStore.kt`, `ConnectedAppsInventory.kt` and `ConnectedAppsRepository.kt`, which are present at sableos
`648aec147765361676b51fb428b7ac177883f6f2` with the blob ids pinned in the env file (re-checked by
`build/titan2/verify-c3b-messages-canonical-pin.sh`).

Provider names are compatibility and evidence targets, never a hard-coded allowlist. This lane contains no package-specific handling for any
messaging app; future compatible messaging apps must remain possible without rebuilding SableOS.

## Panther evidence levels (recorded exactly, not upgraded)

| Provider | Panther evidence |
|---|---|
| Signal | Notification ingestion, conversation rendering and source-authorized RemoteInput reply physically worked. |
| WhatsApp | Notification ingestion and rendering physically worked; generic reply-handle retention had a documented remediation and final-qualification item that is still pending. |
| LinkedIn | Notification ingestion and Open-app fallback physically worked; the source exposed no quick-reply surface. |
| Telegram | Installation worked; account/runtime conversation qualification was not completed in that Panther test environment. |

Nothing here is Titan evidence: `C3B_HUB_DEVICE_RUNTIME_VALIDATED=NO`.

## Ownership and closure

IR-013 (canonical Hub product admission and preservation of Panther V1 Connected Apps semantics on Titan 2 / Titan 2 Elite) and KL-030 are
OPEN and blocking. They close only with canonical SableHub admission, plus Titan runtime Connected Apps qualification, plus provider
capability evidence without evidence inflation. IR-013 asks for no provider-specific private API, no broader Hub privilege and no provider credentials.
The same requirement is recorded in the owning repositories (sableos PR #237, platform_sable PR #42, .github PR #15, device_sable_titan2 PR #19);
this lane neither implements nor copies those.
