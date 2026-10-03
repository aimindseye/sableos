# C3B Messages reconciliation (D4)

`MESSAGES_PRODUCT_OWNER=CANONICAL_SABLEOS`. The integrated-product messaging surface is the existing canonical Sable Messages,
not stock Messaging and not a new messaging stack. This lane records the reconciliation; it imports no canonical application source.

## Pinned canonical source

The pin lives in `docs/C3B_MESSAGES_CANONICAL_BINDING.env` and is the single source of truth.

| item | value |
|---|---|
| repository | `aimindseye/sableos` |
| commit | `648aec147765361676b51fb428b7ac177883f6f2` (2026-10-02T14:37:42Z) |
| last commit touching the module | `5ee9fa17f0f08f376ea10c22e2a6be553e787e09` |
| earlier pin | `e97ea89cbd77a53390df8a14d93eb1a36531178c`; no file under `apps/r8/android/messages` differs between the two |
| module | `apps/r8/android/messages`, applicationId `org.sableos.messages` |
| icon | `ic_sable_messages.xml` (module and Hub copies; first-party, canonical icon contract) |

The Git blob id of each reconciled canonical file is pinned in the binding file. `build/titan2/verify-c3b-messages-canonical-pin.sh`
re-fetches them with `gh api` and compares (network, operator-run; the developer sandbox cannot be the judge of canonical state).

## What the canonical implementation does (observed at the pin)

- Source-built Compose app with a Sable-owned UI, keyboard-first interaction model (`MessagesInteractionModel.kt`) and JVM tests.
- Provider-safe handoff: `Intent.ACTION_SENDTO` on `smsto:` with `sms_body`, via `startActivity`. If no provider accepts it the UI says so.
- Manifest: `uses-feature` telephony and telephony.messaging both `required=false`; a `<queries>` entry for `smsto:`; no `uses-permission`
  at all (no `READ_SMS`, `SEND_SMS`, `RECEIVE_SMS`, `RECEIVE_MMS`); no receiver, no service, `usesCleartextTraffic=false`.
- Runtime data (verified at the pin): `MainActivity` renders `MessagesInteractionModel.latestFirstThreads(sampleThreads)`, and `sampleThreads` is
  hard-coded fixture data (Maya Patel, Team thread, Alex). The only real action is the `smsto:` handoff to another installed provider app.
  Nothing in the module supplies live conversations.
- Declared markers: `CUSTOM_SMS_STACK=NO`, `CUSTOM_RCS_STACK=NO`, `CUSTOM_MMS_STACK=NO`, `CUSTOM_CARRIER_STACK=NO`,
  `PROVIDER_OWNERSHIP_RETAINED=YES`, `MESSAGES_DEFAULT_SMS_ROLE=NO`.

## Runtime data truth (what this reconciliation does and does not establish)

At the pinned commit the canonical module is a keyboard-first UX and provider-handoff surface, not a usable SMS/MMS conversation client:

```text
C3B_MESSAGES_RUNTIME_DATA_SOURCE=STATIC_SAMPLE_THREADS
C3B_MESSAGES_LIVE_THREAD_DATA=NO
C3B_MESSAGES_INCOMING_MESSAGE_DATA_PATH=NOT_IMPLEMENTED_IN_CANONICAL_MODULE
C3B_MESSAGES_SEND_PATH=EXTERNAL_PROVIDER_ACTION_SENDTO_SMSTO
C3B_MESSAGES_PRODUCT_STATUS=UX_HANDOFF_SOURCE_RECONCILED_RUNTIME_DATA_PATH_OPEN
```

So D4 reconciles source, ownership and the UX/handoff contract only. It does not show that the module can list real conversations or show
incoming messages, and the work left is larger than canonical admission plus device evidence: the canonical lane still has to decide and
build a runtime data and provider integration that makes Sable Messages usable (IR-012) without a custom SMS/MMS/RCS stack, without a
custom telephony or carrier path, and without this lane adding SMS permissions or a default-SMS role request. Until that exists, no
document may claim live threads or incoming-message support; the gate enforces this for this exact pin.

## Boundary with Sable Hub

```text
SABLE_MESSAGES_AND_SABLE_HUB_ARE_SEPARATE_PRODUCT_SURFACES=YES
D4_MESSAGES_REPLACES_SABLE_HUB=NO
D4_MESSAGES_WEAKENS_CONNECTED_APPS=NO
```

Sable Hub keeps the Connected Apps functionality already built and exercised on Panther (generic notification adapter, source-owned RemoteInput reply,
Open-app fallback, package and user policy, bounded local history, dynamic provider discovery). That requirement is recorded in
`docs/C3B_HUB_PARITY.md` and IR-013 and is unaffected by this reconciliation.

## Ownership decision

| concern | owner |
|---|---|
| Sable Messages UI, interaction model, tests, icon | canonical SableOS (`aimindseye/sableos`) |
| Product admission, partition, signing, image composition | canonical C3B lane (IR-011, IR-012) |
| Actual SMS/MMS provider, default-SMS role, MmsService, TelephonyProvider, carrier/APN/IMS | supported Android messaging/provider path in the canonical platform; unmodified by this lane |
| Reconciliation record, manifests, static gate, negative tests | this lane (D4) |

This lane adds no SMS/MMS/RCS transport, telephony service, carrier integration, APN handling, IMS logic or privileged radio interface,
and requests no privileged permission or platform API for Messages. It does not request the default SMS role either.

## Stock Messaging

Stock AOSP Messaging/MmsService is documented only as a temporary radio-focused engineering fallback for a minimal radio image
(`C3B_MESSAGES_STOCK_MESSAGING_ROLE=TEMPORARY_RADIO_ENGINEERING_FALLBACK_ONLY`). It is not the integrated-product decision
(`C3B_MESSAGES_STOCK_MESSAGING_IS_FINAL_PRODUCT_DECISION=NO`). Removing the fallback from the radio-focused image is a canonical decision under IR-012.

## What D4 deliberately does not do

- No canonical Messages source, Gradle module, manifest, resource or test is copied into this repository (`C3B_MESSAGES_SOURCE_IMPORTED_INTO_THIS_REPO=NO`).
  The canonical module already exists, builds in the canonical Gradle project (`:design` dependency) and is gated by the canonical `n1b2-messages-module-contract.sh`.
- No dependency delta: `C3B_MESSAGES_DEPENDENCY_DELTA=NONE`. No Gradle, manifest, Soong or Kotlin file changes.
- No runtime claim: `C3B_MESSAGES_DEVICE_RUNTIME_VALIDATED=NO`. SMS/MMS MO/MT device evidence belongs to the canonical radio qualification and is only
  meaningful once a runtime data path exists (see above).

## Gate coverage

`build/titan2/qualify-c3b-product-source.sh --static` enforces the contract (markers `C3B_MESSAGES_*`), and
`build/titan2/test-c3b-messages-contract.sh` proves by mutation that each rule fails when violated.

The gate never accepts any of these: reverting the product choice to stock Messaging, an imported canonical module,
SMS/MMS/RCS/carrier/IMS/APN API or privileged-permission use, a new messaging dependency, runtime-data markers that differ from the pinned
source, or wording that claims live threads or incoming-message support while the pin uses static sample threads. Moving the canonical pin requires
re-verifying the runtime data and updating `C3B_MESSAGES_RUNTIME_DATA_REVERIFIED_AT_COMMIT`.
