# Sable R1 release validation

R1-R0 and R1-R1 are closed.

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

## R1-R1 — CLOSED

Files:

```text
tools/validation/release-r1/SABLE_R1_R1_POLICY_PREFLIGHT.py
tools/validation/release-r1/test_release_policy_r1r1.py
release/r1/panther-release-policy-v1.json
release/r1/release-source-seal-v1.schema.json
docs/SABLE_R1_R1_RELEASE_POLICY_AND_CUSTODY.md
docs/SABLE_R1_R1_CLOSURE_20260908.md
release/r1/r1-r1-closure-20260908.json
```

R1-R1 validates release identity, the exact two-file future source-mutation plan, key inventory/custody policy, production build policy, source-seal schema, the Sable-owned update endpoint and exact pinned GrapheneOS release-tooling preimages.

Canonical policy:

```text
SABLE_UPDATE_BASE_URL=https://updates.sableos.org/
CERTIFICATE_SUBJECT=CN=SableOS
BUILD_VARIANT=user
OFFICIAL_BUILD=true
release_policy_sha256=32d09f8ccb7b21bca083c8db3d41ae838daa1ee46e953454dfdb3c3f596a8c92
release_policy_git_blob=9db278de6bdaa8781043762a326f2f9df03f0902
```

Final live disposition:

```text
R1_R1_TESTS=PASS_34_OF_34
PASS=55 BLOCKER=0 INFO=9 SKIP=0 ERROR=0
R1_R1_POLICY_EXECUTION=PASS
R1_R1_POLICY_READINESS=READY_TO_REQUEST_KEYGEN_AUTHORIZATION
R1_R1_ENDPOINT_RC=0
```

Evidence:

```text
/tmp/SABLE_R1_R1_POLICY_PREFLIGHT_20260909T002354Z_qdw0b9dv
```

The validator remains strictly read-only. It does not generate keys, mutate Android source, build, sign, generate OTAs, contact a device, reboot, flash, change slots, lock/unlock the bootloader or wipe data.

A zero exit code means only that policy is complete enough to **request** separate key-generation authorization. It is not key-generation authorization itself.

## Current authorization boundary

```text
SOURCE_MUTATION_AUTHORIZED=NO
WORKSPACE_OUTPUT_MUTATION_AUTHORIZED=NO
BUILD_AUTHORIZED=NO
KEY_GENERATION_AUTHORIZED=NO
SIGNING_AUTHORIZED=NO
OTA_GENERATION_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
DEVICE_REBOOT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
SLOT_CHANGE_AUTHORIZED=NO
USERDATA_OR_METADATA_WIPE_AUTHORIZED=NO
```

## Next gate

Prepare and adversarially validate the exact two-file Android source mutation and the key-generation harness without executing either. Only after those deliverables are sealed should separate mutation/key-generation authorization be requested.
