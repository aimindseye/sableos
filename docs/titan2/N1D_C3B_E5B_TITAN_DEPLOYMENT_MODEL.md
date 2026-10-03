# N1D C3B E5B Titan 2 deployment model correction

Status: **CURRENT E5B DEPLOYMENT AUTHORITY / MUTATION NOT AUTHORIZED**

This record corrects the earlier generic inactive-slot assumption in the first
E5B offline package.

## Device model

Titan 2 is not a conventional Android device with two simultaneously
materialized dynamic-system copies.

The research evidence establishes:

```text
PHYSICAL_BOOT_SLOT_COUNT=2
VIRTUAL_AB=YES
DYNAMIC_PARTITIONS=YES
ACTIVE_SLOT=a
FASTBOOTD=YES

ACTIVE_LOGICAL_PARTITIONS:
  system_a
  product_a
  system_ext_a
  vendor_a
  system_dlkm_a
  vendor_dlkm_a
  odm_dlkm_a

SYSTEM_B_MAY_BE_NOT_MATERIALIZED_WHILE_SLOT_A_ACTIVE=YES
LP_METADATA_SLOT_1_CAN_STILL_DESCRIBE_B_LAYOUT=YES
```

Therefore:

```text
system_b size 0 / Partition not found
!=
safe inactive system deployment target
```

The active logical system follows the current Virtual A/B metadata state.

## Historical deployment evidence

### N0

The durable N0 flash-plan ledger is planning/research evidence and records:

```text
FIRST_SABLE_BOOT=NOT_RUN
WRITE_CAPABLE_SCRIPT_PRESENT=NO
```

The canonical repository therefore does not use N0 as proof of a successful
alternate-system boot.

### N1B — proven boot path

N1B is the first durable successful Titan 2 alternate-system boot record.

```text
ACTIVE_SLOT_BEFORE_FLASH=a
TARGET_PARTITION=system_a

snapshot-update-status=none

stale active-slot COW logical partitions removed
system_a resized
system_a written
AVB mutation=NO
boot/vendor/vbmeta write=NO
slot change=NO

first reboot -> stock recovery
explicit factory data reset -> boot success

FIRST_N1B_BOOT=PASS
ACTIVE_SLOT=_a
VERIFIED_BOOT_STATE=orange
```

The first resize attempt failed because Virtual A/B COW logical partitions
consumed allocatable super space. Total super headroom alone was not sufficient.

The proven corrective sequence was COW-aware active-system replacement.

## N1C — whole-super negative evidence

N1C replaced `system_a` inside a rebuilt sparse hybrid `super` while preserving
the other stock dynamic partitions. The write itself completed, but Android did
not boot.

Recovery required:

```text
stock super restore
matched TEE14 boot / init_boot / vendor_boot / vbmeta* restore
factory reset from recovery
```

Therefore the N1C whole-super write is not the primary C3B deployment path.

## C3B E5B direction

C3B reuses the proven N1B deployment architecture unless fresh evidence blocks
it:

```text
TARGET_SYSTEM_PARTITION=system_<current-slot>
CURRENT_SLOT=a
CURRENT_TARGET=system_a
SLOT_POLICY=KEEP_CURRENT_SLOT_NO_SLOT_SWITCH

PRESERVE:
  boot
  init_boot
  vendor_boot
  dtbo
  vbmeta
  vbmeta_system
  vbmeta_vendor
  product_a
  system_ext_a
  vendor_a
  system_dlkm_a
  vendor_dlkm_a
  odm_dlkm_a

DO_NOT_USE_AS_PRIMARY_PATH:
  inactive system_b deployment
  slot switch
  whole-super N1C-style write
```

Before authorization, the offline package must prove from the sealed E5A
evidence:

1. snapshot/update state is idle/none;
2. exact active logical-system size;
3. current active-slot COW inventory and sizes;
4. active group membership and maximum size from `lpdump`;
5. active-group capacity after the proposed system target;
6. total-super capacity after any reviewed stale-COW cleanup and growth;
7. sealed E3 image identity and stock restore artifacts remain unchanged.

## Userdata policy

Historical N1B evidence is explicit:

```text
FACTORY_RESET_REQUIRED=YES_CONFIRMED
```

C3B must not repeat the preserve-data assumption as if Titan 2 were Panther.
The E5B proposal therefore treats first-boot factory reset as an expected,
separately authorized destructive step.

No reset is authorized by this document.

## Current safety boundary

```text
DEVICE_CONTACT_AUTHORIZED=NO_FOR_OFFLINE_PACKAGE
FLASH_AUTHORIZED=NO
ERASE_AUTHORIZED=NO
LP_MUTATION_AUTHORIZED=NO
AVB_MUTATION_AUTHORIZED=NO
SLOT_MUTATION_AUTHORIZED=NO
FACTORY_RESET_AUTHORIZED=NO
```

The corrected offline package emits no write-capable commands.
