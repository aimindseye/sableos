# Sable R1 release validation

R1-R0 is closed. `SABLE_R1_R1_POLICY_PREFLIGHT.py` is the current read-only Panther release-policy/custody gate.

## R1-R0 execution lineage

```text
SABLE_R1_R0_RELEASE_PREFLIGHT.py      HISTORICAL BYTE-BOUND BASE
SABLE_R1_R0R1_RELEASE_PREFLIGHT.py    SUPERSEDED / SELF-RECURSION DEFECT
SABLE_R1_R0R2_RELEASE_PREFLIGHT.py    SUPERSEDED / TARGET-IDENTITY DEFECT
SABLE_R1_R0R3_RELEASE_PREFLIGHT.py    FINAL R1-R0 EXECUTABLE / R1-R0 CLOSED
```

Final R1-R0 live result:

```text
PY_COMPILE=PASS_6_OF_6
R1_R0R3_TESTS=PASS_38_OF_38
PASS=19 BLOCKER=10 INFO=11 SKIP=2 ERROR=0
R1_R0_PREFLIGHT_EXECUTION=PASS
R1_RELEASE_READINESS=BLOCKED_10
R1_R0R3_RC=3
```

See `docs/SABLE_R1_R0_CLOSURE_20260908.md` and `release/r1/r1-r0-closure-20260908.json`.

## Current R1-R1 gate

Files:

```text
tools/validation/release-r1/SABLE_R1_R1_POLICY_PREFLIGHT.py
tools/validation/release-r1/test_release_policy_r1r1.py
release/r1/panther-release-policy-v1.json
release/r1/release-source-seal-v1.schema.json
docs/SABLE_R1_R1_RELEASE_POLICY_AND_CUSTODY.md
```

R1-R1 validates release identity, the exact two-file future source-mutation plan, key inventory/custody policy, production build policy, source-seal schema, and exact pinned GrapheneOS release-tooling preimages.

It remains strictly read-only. It does not generate keys, mutate Android source, build, sign, generate OTAs, contact a device, reboot, flash, change slots, lock/unlock the bootloader, or wipe data.

Use the existing sablectl virtual environment:

```bash
PY="$HOME/.venvs/sablectl/bin/python"

PYTHONDONTWRITEBYTECODE=1 "$PY" -m pytest \
  -p no:cacheprovider \
  tools/validation/release-r1/test_release_policy_r1r1.py -q

PYTHONDONTWRITEBYTECODE=1 env \
  SOURCE_MUTATION_AUTHORIZED=NO \
  WORKSPACE_OUTPUT_MUTATION_AUTHORIZED=NO \
  BUILD_AUTHORIZED=NO \
  KEY_GENERATION_AUTHORIZED=NO \
  SIGNING_AUTHORIZED=NO \
  OTA_GENERATION_AUTHORIZED=NO \
  DEVICE_CONTACT_AUTHORIZED=NO \
  DEVICE_REBOOT_AUTHORIZED=NO \
  FLASH_AUTHORIZED=NO \
  SLOT_CHANGE_AUTHORIZED=NO \
  USERDATA_OR_METADATA_WIPE_AUTHORIZED=NO \
  "$PY" tools/validation/release-r1/SABLE_R1_R1_POLICY_PREFLIGHT.py

RC=$?
echo "R1_R1_RC=$RC"
```

Pre-delivery R1-R1 validation is 34/34 PASS. With the checked-in policy the expected live disposition is deliberately:

```text
ERROR=0
R1_R1_POLICY_EXECUTION=PASS
R1_R1_POLICY_READINESS=BLOCKED_1
R1_R1_RC=3
```

The sole expected blocker is the intentionally unset Sable-owned HTTPS update endpoint. No hostname is invented by the tooling. A future zero exit code means only that the policy is complete enough to **request** separate key-generation authorization; it is not key-generation authorization itself.
