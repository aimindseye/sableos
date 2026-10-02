# N1D C3B Sable Hub Panther parity contract

Status: **current canonical Titan 2 product-integration requirement — 2026-10-02**

Titan 2 / Titan 2 Elite must carry the common Sable Hub semantics proven on the
Panther reference. Keyboard-first presentation may change focus, layout and
shortcuts; it must not remove the generic Connected Apps capability.

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
SABLE_MESSAGES_AND_SABLE_HUB_ARE_SEPARATE_PRODUCT_SURFACES=YES
D4_MESSAGES_REPLACES_SABLE_HUB=NO
D4_MESSAGES_WEAKENS_CONNECTED_APPS=NO
```

Provider names are compatibility/evidence targets, not an implementation allowlist.
The generic adapter is keyed by package plus Android user/profile and must accept
future compatible installed applications without rebuilding SableOS.

Panther evidence recorded by ADR-0011 remains the reference:

- Signal: notification ingestion, conversation rendering and source-authorized
  RemoteInput reply physically worked.
- WhatsApp: notification ingestion/rendering physically worked; reply-handle
  retention required the documented generic remediation/qualification.
- LinkedIn: notification ingestion and Open-app fallback physically worked; the
  source did not expose a quick-reply surface.
- Telegram: installation worked, but account/runtime conversation qualification
  was not completed in that test environment.

These statuses must not be inflated when carried into Titan qualification.

Sable Messages and Sable Hub are separate product surfaces. Reconciliation or
replacement work for `apps/r8/android/messages` must not replace, subsume,
disable or weaken `apps/r8/android/hub` or its Connected Apps semantics.

The canonical source invariants are checked by
`build/gates/n1d-c3b-hub-parity-contract.py`. Device runtime parity remains a
separate Titan physical-qualification requirement.
