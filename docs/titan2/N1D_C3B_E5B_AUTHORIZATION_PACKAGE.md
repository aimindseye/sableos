# N1D C3B E5B offline authorization package

Status: **OFFLINE PREPARATION AUTHORIZED / E5B MUTATION NOT AUTHORIZED**

E5A is sealed `PASS_REVIEW_READY`. The Titan 2 remains in userspace fastbootd.

This package is the next non-mutating engineering step. It consumes the already
captured E5A JSON and does not contact the device.

## Safety boundary

```text
DEVICE_CONTACT_AUTHORIZED=NO
ADB_COMMANDS_RUN=NO
FASTBOOT_COMMANDS_RUN=NO
REBOOT_COMMANDS_RUN=NO
FLASH_AUTHORIZED=NO
ERASE_AUTHORIZED=NO
FORMAT_AUTHORIZED=NO
LP_MUTATION_AUTHORIZED=NO
AVB_MUTATION_AUTHORIZED=NO
SLOT_MUTATION_AUTHORIZED=NO
UNLOCK_LOCK_AUTHORIZED=NO
FACTORY_RESET_AUTHORIZED=NO
CUSTOM_BOOT_AUTHORIZED=NO
WRITE_CAPABLE_COMMANDS_EMITTED=NO
```

## Purpose

The package converts the sealed E5A evidence into a sanitized E5B decision
record containing:

- current and inactive slot;
- exact `system_a` / `system_b` sizes from E5A evidence;
- planned target size;
- per-candidate growth requirement;
- remaining total-`super` headroom for each candidate;
- lpdump capture hash/presence;
- explicit unresolved group-capacity proof;
- the recommended rollback-oriented slot policy.

The current engineering preference is:

```text
PREFER_INACTIVE_SLOT_TO_PRESERVE_PROVEN_STOCK_ACTIVE_SLOT
```

but only if the inactive slot's stock boot chain and logical-partition group
capacity are both confirmed. The package does not authorize that policy.

## Run

From the exact merged canonical head published with the handoff:

```bash
bash build/gates/n1d-c3b-e5b-authorization-package-contract.sh

bash build/titan2/prepare-n1d-c3b-e5b-authorization-package.sh
```

This uses the sealed E5A evidence directory by default:

```text
/srv/sable-build/evidence/titan2/n1d-c3b-e5a-readonly-device-state/20261003T053441Z
```

Do not reboot or otherwise contact the phone for this step.

## Required outcome

The package is reviewable only when it ends with:

```text
N1D_C3B_E5B_AUTHORIZATION_PACKAGE=
READY_FOR_MANUAL_DECISION_AFTER_GROUP_AND_INACTIVE_BOOT_CHAIN_REVIEW
```

This still means:

```text
E5B_FLASH_AUTHORIZED=NO
E5B_LP_MUTATION_AUTHORIZED=NO
E5B_AVB_MUTATION_AUTHORIZED=NO
E5B_SLOT_MUTATION_AUTHORIZED=NO
```

The next authorization decision must be based on the generated candidate sizes,
fresh group-capacity evidence, and inactive-slot boot/AVB coherence.
