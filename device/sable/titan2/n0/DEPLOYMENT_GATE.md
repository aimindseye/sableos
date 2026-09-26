# Titan 2 N0 deployment gate

Status: **closed — no E3 deployment yet**

E3/N0 deployment is blocked until a real artifact exists and the artifact is
bound to the exact stock firmware/vendor basis.

## Gate state

```text
TITAN2_N0_ARTIFACT_EXISTS=NO
TITAN2_N0_ARTIFACT_KIND=UNDECIDED
TITAN2_STOCK_BASIS_BOUND=NO
TITAN2_RESTORE_PLAN_VERIFIED=NO
TITAN2_AVB_STRATEGY_DECIDED=NO
TITAN2_USERDATA_POLICY_DECIDED=NO
TITAN2_SERIAL_BOUND_COMMANDS_READY=NO
E3_DEPLOYMENT_AUTHORIZED=NO
```

## Required before opening the gate

1. Confirm the handset is on the expected stock baseline.
2. Confirm bootloader state and active slot.
3. Verify stock restore images and hashes are reachable.
4. Capture current LP/super metadata and snapshot-update state.
5. Decide artifact kind.
6. Decide AVB handling.
7. Decide whether userdata wipe is required.
8. Generate/register the artifact.
9. Verify artifact hash and metadata.
10. Use explicit serial binding for every `adb` and `fastboot` command.

## Explicit destructive-data policy

Titan 2 must not inherit Panther's preserved-data flash contract. If first N0
requires wiping userdata, the deployment adapter must expose an explicit
destructive-data authorization flag.

```text
PRESERVE_DATA_DEFAULT=NO_CLAIM
DESTRUCTIVE_DATA_ALLOWED=NO_UNTIL_EXPLICITLY_AUTHORIZED
```

## Fail-closed rule

Any missing gate input keeps deployment closed.
