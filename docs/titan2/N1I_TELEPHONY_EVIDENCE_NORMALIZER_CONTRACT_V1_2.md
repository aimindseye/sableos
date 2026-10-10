# N1I Telephony Evidence Normalizer and Qualification Contract — v1.2

**Status:** `DESIGN_ONLY_NOT_PRODUCTION_AUTHORIZED`. Synthetic qualification only.
**Scope:** `EVIDENCE_NORMALIZATION_AND_QUALIFICATION_ONLY` for Unihertz Titan 2, N1I Android 16 GSI on the MediaTek
vendor radio stack: one active SIM in either tray, and DSDS evidence that is reported but never qualified offline.
**Recovery execution:** `OUT_OF_SCOPE_PENDING_ROOT_CAUSE`. This contract defines no recovery action, executor,
proposal-to-execute path or approval token.
**Authority:** host-only offline analysis. Every authority key is `false`: device contact, ADB, fastboot, SIM
movement, settings mutation, source mutation, build, flash, reboot, network fetch.

Supersedes the v1.0 "N1I Cellular Recovery Architecture and Regression Contract" and contract v1.1
(`N1I_RECOVERY_CONTRACT_V1.json`, renamed to `N1I_TELEPHONY_EVIDENCE_CONTRACT_V1_2.json`).

| Artifact | Path |
|---|---|
| Machine contract | `docs/titan2/N1I_TELEPHONY_EVIDENCE_CONTRACT_V1_2.json` |
| Evaluator (pure, read-only) | `build/titan2/n1i_telephony_evidence_eval.py` |
| Fixture generator and fixtures | `tests/titan2/n1i-telephony-evidence/make_fixtures.py`, `fixtures/` |
| Self-tests | `tests/titan2/n1i-telephony-evidence/test-telephony-evidence-contract.py` |

## 1. Why the rescope

The evidence identifies *what* was observed when data was lost on Oct 9. It does not identify *why*. Until a
root cause is established, any recovery action would be a guess, so v1.2 limits itself to two jobs:

1. **Normalize** retained telephony evidence into one event form, with explicit identity, clock and provenance.
2. **Qualify** whether a capture shows continuous validated internet on the default-data subscription, and say
   precisely why not when it does not.

Removed relative to v1.0: the `RECOVERY_CANDIDATE` state, the `REQUEST_EXPLICIT_RECOVERY_APPROVAL` proposal and the
future executor section. The evaluator's advisory proposals are only `NO_ACTION`, `OBSERVE` and
`ESCALATE_FOR_REVIEW`.

## 2. Evidence baseline, with limits

| Evidence | Confirmed | Not established |
|---|---|---|
| Oct 3 N1H, tray 1 | 132/132 sampled registration/data observations over 15 min | Continuous *validated internet*: polling registration and bearer state is not a validation sample. Tray 2; DSDS |
| Oct 9 N1F, PHONE1 / tray 2 | Data setup; DNS/validation failure; `DATA_DEACT_CALL_IND` 21:28:53.124; vendor code **`0x140F7C`** (logged as `onDataCallDeact aid:0 res:1314684`); CID 101 `active=0`, `ERROR_UNSPECIFIED`; PS reject order **15 → 13 → 11** in this run | Meaning of the code; who initiated the release; why |
| N1I-B §9AA, tray 1 (IMS package removed) | `pwg` session connected, then `ERROR_UNSPECIFIED` disconnect; PS reject order **13 → 15 → 11**, later **11 → 13 → 15**, in this run | Vendor deactivation code (not recorded in §9AA); validation verdict; whether order differences matter |
| DSRM Oct 9 | `GET_DATA_CALL_LIST` selected; "recovery was not started" | Any DSRM-executed restart or teardown |
| Stock tray 2 | Different code **`0x141AD1`** (`res:1317585`), reject 27, new activation, `ccmni1 active=2` | Equivalence to the N1F failure |
| Oct 9 radio cycle | PHONE1 off/on, fresh `SETUP_DATA_CALL`, connected | Validated internet; sustained uptime |
| Oct 9 post-cycle | Validation `INVALID` at 21:37:51.221 | Passing internet qualification |
| APN trial ~22:53 UTC | Occurred after the 21:28 failure; confounded by a SIM toggle | Any causal role in the initial failure |

**Vendor code.** `0x140F7C` and decimal `1314684` are the same number in two bases. The normalizer stores one opaque
canonical form (`0x140F7C`) and never decodes it. A record whose hex and decimal forms disagree aborts with
`VENDOR_CODE_CONFLICT`.

**Reject order is run-specific.** It is kept in event order and never sorted or merged across runs. Two runs share
an initial condition only when their first vendor code, loss sequence and reject sequence all match.

**IMS is outside v1 qualification.** `IMS_REGISTRATION`, `IMS_BEARER`, voice and SMS/MMS are scope exclusions.
IMS bearers (`apn_type` contains `ims`) and IMS-domain registration are counted as `out_of_scope_events` and neither
satisfy nor break the internet-bearer requirement.

## 3. Provenance: required evidence, explicit unknowns

Every bundle declares `validation_mode` (`PASSIVE_LOG` or `ACTIVE_PROBE`) and a `network_config` holding exactly:

| Field | Meaning |
|---|---|
| `private_dns_mode` | off / opportunistic / hostname, as configured on the device |
| `dns_servers` | DNS servers supplied for the default-data network (redacted as reviewed) |
| `connectivity_check_urls` | HTTP/HTTPS/fallback validation URLs in effect |
| `connectivity_check_source` | where those URLs came from (AOSP default, overlay, settings, carrier) |
| `apn_name` | APN of the internet bearer |
| `apn_protocol` | APN home protocol (IP / IPV6 / IPV4V6) |
| `apn_roaming_protocol` | APN roaming protocol |

Each field is either `{"status": "OBSERVED", "value": <non-null>, "evidence_ref": "<source>"}` or
`{"status": "UNKNOWN", "value": null, "evidence_ref": null}`. Rule: `explicit_UNKNOWN_never_inferred`. A value
without an evidence reference (an inference) or a missing field aborts with `PROVENANCE`. The evaluator reports the
unknown fields verbatim in `provenance_unknown` and the observed values in `network_config`; it never fills a gap
from defaults.

## 4. Canonical event

Fields (exact, extras rejected): `schema_version`, `source_id`, `sequence`, `timestamp_utc`, `source_clock_kind`,
`event_type`, `phone_id`, `slot_id`, `subscription_ref`, `cid`, `payload`, `evidence_ref`.

Event types (closed set): `SIM_STATE`, `RADIO_STATE`, `REGISTRATION`, `BEARER`, `VALIDATION`, `DNS_PROBE`,
`VENDOR_DEACT`, `DSRM_ACTION`, `OPERATOR_ACTION`, `ACTION_RESULT`, `CAPTURE_GAP`, `DEFAULT_DATA` (new).

`VALIDATION.payload.basis` is `CAPABILITY_SNAPSHOT` (periodic poll of `NET_CAPABILITY_VALIDATED`), `PROBE` (an
active probe; carries `bound_cid`) or `TRANSITION` (a logged state change).

Fail-closed order: SHA-256 of events before any parsing → provenance and network config → schema → duplicates
(`(source_id, sequence)`; identical copies dropped, conflicting copies abort) → vendor-code form → capture window →
identity timeline. Any `UNKNOWN` clock gives `INCONCLUSIVE CLOCK_UNKNOWN` without evaluation.

## 5. Identity: time-scoped, explicit, never retroactive

Rule: `time_scoped_explicit_mapping_no_inference_no_retroactive_application`; conflicts `ABORT`.

- A mapping `subscription ↔ (phone, slot)` opens only on `SIM_STATE LOADED` carrying all three. `SIM_STATE ABSENT`
  on that phone closes it.
- Events are walked in time order. Each event is attached through the mapping in force **at its own timestamp**.
  A mapping first seen at 950 s does not adopt phone evidence from 0–945 s (F24).
- An event naming a subscription is attached only while that subscription is mapped; if it also names a phone or
  slot that disagrees with the mapping, the bundle aborts `IDENTITY_CONFLICT` (F22, F23).
- A `LOADED` that maps a subscription already mapped elsewhere, puts a second subscription on a mapped phone, or
  changes a phone's slot without an intervening `ABSENT` aborts `IDENTITY_CONFLICT`.
- Phone-only events attach to the phone's current subscription; events from a phone known to be empty are recorded
  in `ignored_phones` (F02, F05). Anything else that cannot be attached is counted in `unattached_events`, which
  blocks a `VALIDATED_STABLE` overall verdict (`UNATTRIBUTED_EVIDENCE`).
- A phone index is never used as a fallback for a subscription.

## 6. Overall verdict: evidenced default-data subscription only

Rule: `default_data_subscription_only_never_inferred`.

- The overall outcome is the outcome of the subscription named by the last `DEFAULT_DATA` event.
- No `DEFAULT_DATA` evidence → `INCONCLUSIVE NO_DEFAULT_DATA_EVIDENCE`, even when every subscription is stable (F25).
- `DEFAULT_DATA` naming a subscription not mapped at capture end → `INCONCLUSIVE DEFAULT_DATA_UNMAPPED` (F26).
- Per-subscription outcomes are always reported; they never leak into each other (F10).
- `dsds` is `NOT_QUALIFIED_OFFLINE_REQUIRES_PHYSICAL` for two or more subscriptions and
  `NOT_QUALIFIED_SINGLE_SIM_EVIDENCE` otherwise. Offline evidence never qualifies DSDS.

## 7. Qualification: continuous evidence, binding thresholds

Required (all): explicit time-scoped mapping, explicit default-data subscription, SIM loaded, radio on, PS
registered, internet bearer active, continuous registration samples, continuous bearer samples, continuous
validation samples, no `INVALID`/`UNKNOWN` in the window, stable window.

Thresholds (binding): stable window 900 s; maximum sample gap 15 s; active-probe maximum validation age 10 s.

**Continuity** means at least one sample in the window and no step longer than the gap, counting from window start
and up to capture end. Registration, bearer and validation are checked separately, so registration polling alone
(F01) cannot qualify.

| Mode | What counts as a validation sample |
|---|---|
| `PASSIVE_LOG` | `VALID` with basis `CAPABILITY_SNAPSHOT`. A `TRANSITION` changes state only. |
| `ACTIVE_PROBE` | `VALID` with basis `PROBE` whose `bound_cid` is an active internet-bearer cid at that moment. The last one must be within 10 s of capture end. Unbound probes are counted and ignored (F30). |

**Window restarts** (restart cause reported as `window_restart_cause`) on: `IDENTITY`, `SIM`, `RADIO`,
`REGISTRATION`, `BEARER` (loss *and* recovery, F29, F39), `DEFAULT_DATA`, `OPERATOR_ACTION`, `CAPTURE_GAP` (window
restarts at the end of the gap, F15, F27) and `VALIDATION_TRANSITION` (any `INVALID` or `UNKNOWN`, F28). A restart
discards all earlier samples.

Outcome order: SIM not loaded → `LOST`; radio not on → `LOST` (or `INCONCLUSIVE RADIO_NOT_CONFIRMED_ON` before any
bearer); PS not registered or no internet bearer → `LOST`; last verdict `INVALID` → `FAIL_INTERNET_VALIDATION`; no
`VALID` → `NOT_QUALIFIED` after an observed cycle, `INCONCLUSIVE PROBE_NOT_BOUND` when only unbound probes exist,
else `INCONCLUSIVE VALIDATION_PENDING`; window shorter than 900 s → `WINDOW_INCOMPLETE`; then `VALIDATION_STALE`,
`VALIDATION_NOT_CONTINUOUS`, `REGISTRATION_NOT_CONTINUOUS`, `BEARER_NOT_CONTINUOUS`; otherwise `VALIDATED_STABLE`.
`root_cause` is always `UNKNOWN`.

## 8. Gates

| Gate | Required result | Fixtures |
|---|---|---|
| `G00_PROVENANCE` | Hash before parse; clock scope; network config observed-or-unknown | F09, F12, F36, F37, F38 |
| `G01_SCHEMA` | Exact fields and closed event types | F17, F18 |
| `G02_MAPPING` | Time-scoped identity; empty phone ignored; conflicts abort; no retroactive mapping | F02, F05, F13, F22, F23, F24 |
| `G03_ORDERING` | Deterministic replay; duplicates; capture gaps | F02, F16, F27 |
| `G04_BEARER_VS_INTERNET` | Connected is not validated; continuity per mode; IMS excluded | F01, F03, F06, F21, F28, F30, F31, F33, F34 |
| `G05_VENDOR_CAUSE` | One opaque code; run-specific reject order | F02, F04, F32, F35 |
| `G06_DSRM_ATTRIBUTION` | Selection is not execution | F02, F19 |
| `G07_RECOVERY_CYCLE` | Cycle or reconnect restarts qualification | F03, F20, F29, F39 |
| `G08_TEMPORAL_CAUSALITY` | Post-failure actions are not prior causes | F07 |
| `G09_STOCK_PARITY` | Different stock cause is not equivalent | F04, F11 |
| `G10_SAFETY` | All actions denied; evaluator imports/calls/strings scanned | F08 |
| `G11_NEGATIVE_CASES` | Every negative case aborts or ends `INCONCLUSIVE`/`UNKNOWN` | see contract |
| `G12_DUAL_SIM` | Default-data only; DSDS never qualified offline | F10, F25, F26 |

## 9. Regression design

- **Fixture replay:** 39 fixtures, each with a machine-checked `assert` in the contract.
- **Bundle mutations:** edits to a stable bundle (gaps per stream, mid-window `INVALID`, trailing silence, capture
  gap, operator action, probe rebinding, dropped mapping, dropped default-data, DSDS default switch, identity
  conflicts, unattributed phone evidence, vendor-form disagreement, unknown clock, extra field, tamper) must each
  produce the specified verdict.
- **Contract mutations:** weakening any rule (identity, overall verdict, provenance, IMS scope, recovery scope,
  vendor-code handling, thresholds, restart events, fixture expectations) must be rejected and must stop evaluation.
- **Evaluator fault injection:** in-memory source edits of the evaluator (retroactive mapping, phone-index fallback,
  sorted-first primary, registration-only acceptance, transition-as-sample, ignored probe binding, split vendor
  forms, sorted rejects, counted IMS bearers, ignored identity conflicts, missing restarts, and the v1.1 set) must
  each fail at least one check.
- **G10 static scan** of the evaluator: import allow-list; no process, network or write calls; no device-tool
  strings; no recovery-action vocabulary.

## 10. Next phase (separately reviewed)

A read-only normalizer for the retained Oct 3, Oct 7 and Oct 9 evidence, starting with the
**validation-versus-bearer-loss chronology** on Oct 9: whether `INVALID` preceded or followed the vendor
deactivation and bearer loss, with clock domain, identity and provenance stated per event and unknowns left
unknown. That work needs its own review before it reads any retained evidence; this contract only fixes the form
its output must take.

**Decision markers**

```text
N1I_TELEPHONY_EVIDENCE_CONTRACT_VERSION=1.2
N1I_TELEPHONY_EVIDENCE_SCOPE=EVIDENCE_NORMALIZATION_AND_QUALIFICATION_ONLY
N1I_RECOVERY_EXECUTION=OUT_OF_SCOPE_PENDING_ROOT_CAUSE
N1I_PHYSICAL_QUALIFICATION=NOT_EXECUTED
N1I_ROOT_CAUSE=UNKNOWN
DEVICE_CONTACT_AUTHORIZED=NO
BUILD_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
```

## Final-review clarifications (v1.2)

- **Time-valid default data:** A `DEFAULT_DATA` record is usable for overall qualification only if its named subscription was explicitly mapped when that record was observed and remains mapped at capture end. A later mapping cannot retroactively validate an earlier declaration. An unbound default-data record yields `INCONCLUSIVE / DEFAULT_DATA_UNMAPPED`, even if the same subscription becomes mapped later.
- **Temporal evidence, not causality:** The legacy evaluator output key `prior_cause_candidates` contains only operator action labels observed *before the first detected loss in that evidence window*. These are **prior operator actions, not established cause candidates**. The key remains for v1.2 fixture compatibility; consumers must not promote it into root-cause attribution. The root cause remains `UNKNOWN`. If observation predates or misses a prior loss, the report must not imply causality.
- No device operations, recovery executor, APN changes, radio commands, or production permissions are granted by these clarifications.
