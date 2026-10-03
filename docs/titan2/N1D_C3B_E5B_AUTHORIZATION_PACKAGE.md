# N1D C3B E5B offline authorization package

Status: **CORRECTED PACKAGE PASS / OWNER BOUNDED MUTATION AUTHORIZATION RECEIVED / STANDARD EXECUTION HELD**

E5A is sealed `PASS_REVIEW_READY`. The Titan 2 remains in userspace fastbootd.

This package consumes the already captured E5A evidence only. It performs no
device contact and emits no write-capable commands.

## Corrected Titan 2 model

The first E5B package incorrectly treated `system_b` as a conventional inactive
deployment target. That assumption is superseded.

Titan 2 uses Virtual A/B dynamic partitions. While slot A is active, the B
logical system may not be materialized/openable even though metadata describes
the alternate layout.

The durable deployment precedent is N1B:

```text
current slot a
 -> active-slot COW review/cleanup
 -> resize system_a
 -> write system_a
 -> keep slot a
 -> preserve boot/vendor/vbmeta chain
 -> explicit factory reset
 -> boot success
```

See `N1D_C3B_E5B_TITAN_DEPLOYMENT_MODEL.md`.

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

## What the corrected package proves

The offline package reads:

- sealed E5A summary JSON;
- fresh E5A `lpdump`;
- fresh Phase 11 `getvar all`.

It reports:

- current slot and active `system_<slot>` target;
- whether the opposite logical system is materialized;
- current active-system size and target growth;
- active-slot COW partition inventory and sizes;
- active-group membership and maximum size;
- projected active-group use after the system target;
- projected total-`super` headroom after reviewed COW cleanup and growth;
- preservation policies for boot/AVB and stock dynamic partitions;
- explicit first-boot userdata policy.

## Run

From the exact merged canonical head published with the handoff:

```bash
bash build/gates/n1d-c3b-e5b-authorization-package-contract.sh

bash build/titan2/prepare-n1d-c3b-e5b-authorization-package.sh
```

The default evidence root is:

```text
/srv/sable-build/evidence/titan2/n1d-c3b-e5a-readonly-device-state/20261003T053441Z
```

Do not reboot or otherwise contact the phone for this step.

## Review-ready outcome

The desired corrected state is:

```text
N1D_C3B_E5B_AUTHORIZATION_PACKAGE=
READY_FOR_MANUAL_AUTHORIZATION_ACTIVE_SYSTEM_PATH
```

Even then:

```text
E5B_FLASH_AUTHORIZED=NO
E5B_LP_MUTATION_AUTHORIZED=NO
E5B_AVB_MUTATION_AUTHORIZED=NO
E5B_SLOT_MUTATION_AUTHORIZED=NO
E5B_FACTORY_RESET_AUTHORIZED=NO
```

A later explicit authorization must name the exact COW cleanup, active-system
resize/write, userdata reset policy and rollback stop conditions.


## Subsequent owner authorization and standardization

After this corrected package passed, the owner explicitly authorized the bounded
active-`system_a` E5B mutation concept while preserving the no-COW-delete,
no-slot-change, no-AVB/boot-chain-write and no-factory-reset boundaries.

During execution review, the standard Android fastboot logical-partition behavior
introduced an additional scope detail: `fastboot flash` may resize a logical
partition to the image logical size as part of the flash operation. Because that
exact logical size was not yet sealed in the authorization package, physical
execution remains held.

The next authoritative workflow is now:

```text
build/sable.sh titan2 N1D register-artifact
 -> build/sable.sh titan2 N1D show-artifact
 -> build/sable.sh titan2 N1D flash-plan
 -> review exact SYSTEM_LOGICAL_BYTES and capacity
 -> reconfirm execution scope
 -> only then qualify standard flash execution
```

See `N1D_C3B_E5B_STANDARD_DEPLOYMENT.md`.
