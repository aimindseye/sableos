# N1D C3B E5 manual authorization checkpoint

Status: **E5A PASS / SEALED — E5B NOT AUTHORIZED**

E4 is sealed PASS. E5A read-only device-state revalidation completed with `PASS_REVIEW_READY` and is sealed. The device remains in userspace fastbootd. E5B remains separately unauthorized.

## E5A — fresh read-only device-state revalidation

Purpose: determine whether the current Titan 2 still matches the historical
deployment assumptions before any mutation is considered.

E5A is authorized as **device contact, read-only only**, including Android -> bootloader -> userspace fastbootd transitions.

Required fresh observations:

```text
ADB/Android baseline before reboot, if currently booted
serial binding / device identity without publishing the serial
battery/power sanity
current slot / slot suffix
bootloader unlocked state
verified-boot state
dynamic-partition state
snapshot / virtual A/B / update state
fastbootd userspace state
logical partition names and current sizes
system_a/system_b current allocation
super total size and group allocation
free/available dynamic-partition capacity
product/vendor/system_ext allocations
current stock version / fingerprint
restore artifact availability still present
```

E5A authorization does **not** authorize:

```text
flash
erase
logical-partition resize/delete/create
AVB/vbmeta mutation
slot change
bootloader unlock/lock
factory reset
booting or flashing a custom image
```

If reaching fastbootd requires rebooting the device, that reboot is considered a
device-state transition and must be explicitly included in the E5A authorization.
The E5A runner must not emit or execute deployment commands. The agreed post-capture state is userspace fastbootd; reboot back to Android is not part of E5A authorization.

## E5B — first physical C3B deployment

E5B is not authorized by E5A PASS.

After reviewing fresh E5A evidence, a separate manual authorization must identify:

```text
exact E3 system SHA256
fresh active slot
exact logical system partition to resize
fresh current system allocation
exact planned target allocation
fresh super/group headroom after proposed growth
exact stock-super restore artifact/hash
exact boot/AVB restore artifacts/hashes
rollback stop conditions
userdata policy
AVB/vbmeta policy
slot policy
post-write first-boot acceptance sequence
```

No executable write-capable deployment script should be produced before that
separate authorization.

## Offline E5B decision package

The first E5B package's inactive-slot preference is superseded.

Titan 2's Virtual A/B dynamic-partition layout can report `system_b=0` while
slot A is active; the research baseline explicitly records that the B logical
partitions may be described in LP metadata without being materialized/openable
in fastbootd.

The proven booting N1B path is the authority for E5B planning:

```text
ACTIVE_SLOT=a
TARGET=system_a
snapshot-update-status=none
review/delete stale active-slot COW logical partitions if present
resize active system
write active system
SLOT_CHANGE=NO
AVB_MUTATION=NO
BOOT_VENDOR_VBMETA_WRITE=NO
explicit factory reset
FIRST_N1B_BOOT=PASS
```

N1C whole-`super` replacement wrote successfully but failed to boot and is not
the primary C3B deployment path.

The corrected offline package must therefore prove active-slot COW and group
capacity from the already captured E5A evidence. It does not authorize any
mutation.

See `N1D_C3B_E5B_TITAN_DEPLOYMENT_MODEL.md`.

## Current state

```text
E4_DEPLOYMENT_READINESS=PASS_REVIEW_READY
E5A_DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY
E5A_REBOOT_BOOTLOADER_AUTHORIZED=YES
E5A_REBOOT_FASTBOOTD_AUTHORIZED=YES
E5A_STATUS=PASS_REVIEW_READY_SEALED
E5A_CURRENT_SLOT=a
E5A_ALLOCATION_COMPLETE=YES
E5A_CAPACITY_SAFE=YES
E5A_REMAINING_HEADROOM_AFTER_PLANNED_GROWTH_BYTES=2954141696
E5B_AUTHORIZATION_PACKAGE=OFFLINE_PREPARATION_READY
E5B_FLASH_AUTHORIZED=NO
E5B_LP_MUTATION_AUTHORIZED=NO
E5B_AVB_MUTATION_AUTHORIZED=NO
E5B_SLOT_MUTATION_AUTHORIZED=NO
```
