# N1I telephony evidence normalizer: contract tests (v1.2)

Offline only. No device contact, `/srv`, network, build or flash. Recovery execution is out of scope pending
root-cause identification; nothing here executes, schedules or simulates a device action.

| File | Role |
|---|---|
| `docs/titan2/N1I_TELEPHONY_EVIDENCE_NORMALIZER_CONTRACT_V1_2.md` | Design document: scope, evidence baseline, identity/default-data/continuity rules, gates, fixtures. |
| `docs/titan2/N1I_TELEPHONY_EVIDENCE_CONTRACT_V1_2.json` | Machine contract v1.2 (design-only). Fixtures carry `gates`, `bundle` and machine-checked `assert`. |
| `build/titan2/n1i_telephony_evidence_eval.py` | Pure evaluator: contract validation, bundle integrity/provenance/schema checks, time-scoped identity attribution, per-subscription qualification. |
| `tests/titan2/n1i-telephony-evidence/make_fixtures.py` | Deterministic generator for the 39 sanitized synthetic bundles in `fixtures/`. `--check` fails if committed fixtures drift. |
| `tests/titan2/n1i-telephony-evidence/test-telephony-evidence-contract.py` | Self-tests (`CASE` lines): fixture replay, bundle mutations, contract mutations, evaluator fault injection, G10 static scan, CLI. Also run by `tests/titan2/n1i-b/run-selftests.sh` as component `telephony_evidence`, marker `N1I_TELEPHONY_EVIDENCE_CONTRACT_TESTS`. |

Run:

```bash
python3 tests/titan2/n1i-telephony-evidence/test-telephony-evidence-contract.py
python3 build/titan2/n1i_telephony_evidence_eval.py --contract docs/titan2/N1I_TELEPHONY_EVIDENCE_CONTRACT_V1_2.json \
  --bundle tests/titan2/n1i-telephony-evidence/fixtures/F02_OCT09_LOSS.json
```

## Changes from v1.1

- **Identity is time-scoped and fail-closed.** A `SIM_STATE LOADED` event with explicit phone, slot and
  subscription opens a mapping; `ABSENT` closes it. An event is attached only through the mapping in force at its
  own timestamp. Later mappings are never applied backwards. Explicit subscription/phone/slot contradictions abort
  with `IDENTITY_CONFLICT`. Evidence that cannot be attached is counted (`unattached_events`) and blocks a
  `VALIDATED_STABLE` overall verdict.
- **Overall verdict follows the evidenced default-data subscription only.** New `DEFAULT_DATA` event type. No
  `DEFAULT_DATA` evidence gives `INCONCLUSIVE NO_DEFAULT_DATA_EVIDENCE`; a default naming an unmapped subscription
  gives `INCONCLUSIVE DEFAULT_DATA_UNMAPPED`. Sorted-first selection is gone.
- **Continuity is required for registration, bearer and validation separately.** Each needs samples from window
  start to capture end with no step over 15 s. In `PASSIVE_LOG` only `CAPABILITY_SNAPSHOT` `VALID` samples count;
  a `TRANSITION` changes state but is not a sample. In `ACTIVE_PROBE` only `PROBE` samples bound to an active
  internet bearer cid count. Registration polling alone cannot qualify.
- **Window restarts** on identity, SIM, radio, registration, bearer (loss and recovery), default-data change,
  operator action, capture gap and any `INVALID`/`UNKNOWN` validation transition.
- **Provenance:** every bundle carries `validation_mode` and a `network_config` with `private_dns_mode`,
  `dns_servers`, `connectivity_check_urls`, `connectivity_check_source`, `apn_name`, `apn_protocol`,
  `apn_roaming_protocol`. Each is `OBSERVED` with value and evidence reference, or `UNKNOWN` with null value and
  null reference. An observed value without an evidence reference aborts (`PROVENANCE`).
- **Historical correctness:** `0x140F7C` and decimal `1314684` are one opaque vendor code (canonical `0x140F7C`);
  conflicting forms abort (`VENDOR_CODE_CONFLICT`). Registration reject order is preserved per run (Oct 9
  `15→13→11`; N1F 9AA tray 1 `13→15→11`). IMS bearers and IMS registration are counted as out of scope and never
  satisfy or break qualification.
- Fixtures F01 (renamed: Oct 3 is now polling-only, not stable), F10 (renamed: default-data S2) and F15 (renamed)
  changed; F21–F39 added.

## What these tests do not prove

Fixtures are synthetic abstractions shaped after committed evidence, not raw log replays. A passing run says the
contract and evaluator behave as specified. It says nothing about Titan 2 runtime behaviour, root cause or DSDS.
