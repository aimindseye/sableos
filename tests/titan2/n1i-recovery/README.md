# N1I cellular-recovery contract tests

Offline only. No device contact, `/srv`, network, build or flash.

| File | Role |
|---|---|
| `docs/titan2/N1I_RECOVERY_CONTRACT_V1.json` | Contract v1.1 (design-only). Fixtures carry `gates`, `bundle` and machine-checked `assert`. |
| `build/titan2/n1i_recovery_eval.py` | Pure evaluator: contract validation, bundle integrity/schema checks, per-subscription state machine. Never executes or simulates actions. |
| `tests/titan2/n1i-recovery/make_fixtures.py` | Deterministic generator for the 20 sanitized synthetic bundles in `fixtures/`. `--check` fails if committed fixtures drift. |
| `tests/titan2/n1i-recovery/test-recovery-contract.py` | Self-tests (`CASE` lines). Also run by `tests/titan2/n1i-b/run-selftests.sh` as marker `N1I_RECOVERY_CONTRACT_TESTS`. |

Run:

```bash
python3 tests/titan2/n1i-recovery/test-recovery-contract.py
python3 build/titan2/n1i_recovery_eval.py --contract docs/titan2/N1I_RECOVERY_CONTRACT_V1.json \
  --bundle tests/titan2/n1i-recovery/fixtures/F02_OCT09_LOSS.json
```

## Changes from contract v1.0

- Fixtures map to gates; every gate must have at least one fixture.
- Fixture expectations are machine-checked `assert` blocks, replayed through the evaluator.
- `authority`, required fields, event types, thresholds and outcome mappings are checked as exact sets/values.
- Thresholds are binding (`thresholds_binding: true`), not "suggested".
- Validation freshness has two declared modes. `PASSIVE_LOG`: last verdict after the window start is `VALID` with no `INVALID` since. `ACTIVE_PROBE`: probe `VALID`s with no gap over 15 s, the last within 10 s of capture end. A 10 s TTL cannot be met from passive Android logs.
- The stability window starts at the latest SIM, radio, registration, bearer, identity or operator-action change.
- Duplicate `(source_id, sequence)` with different content aborts; extra event fields abort.
- Added fixtures F11–F20: stock transient recovery, unknown clock, missing mapping, stale validation, capture gap, duplicate conflict, schema violations, DSRM executed vs selected, and a cycle with no `VALID`.

## What these tests do not prove

Fixtures are synthetic abstractions shaped after committed evidence, not raw log replays. A passing run says the contract and evaluator behave as specified. It says nothing about Titan 2 runtime behaviour, root cause or DSDS.
