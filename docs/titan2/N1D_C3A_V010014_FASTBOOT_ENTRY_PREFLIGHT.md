# Titan 2 C3A V01.00.14 fastboot-entry recovery preflight

Status: **current operator step for N1D bootloop / read-only fastboot evidence / no write / no reset**

Updated: **2026-10-03 ET**

## Why this path exists

The first C3A live-preflight wrapper assumed the phone could begin in Android so
Phase-10A could recollect stock properties over ADB.

That assumption is invalid for the current recovery state: the N1D system is
bootlooping and the phone is already in bootloader fastboot.

Do not force an Android boot merely to satisfy the old collector sequence.

The V01.00.14 stock/vendor identity was already sealed before the N1D write and
is bound into the offline C3A control plan. The N1D experiment changed
`system_a`; it did not authorize boot/vendor/vbmeta/super/slot mutation.

Therefore the recovery preflight uses:

```text
sealed prior evidence:
  V01.00.14 stock/vendor identity
  fastboot device-binding hash
  active-group topology and maximum size
  pre-N1D whole-super allocation

fresh current evidence:
  fastboot serial binding
  current slot
  product
  unlocked state
  userspace fastbootd state
  snapshot-update-status
  current logical partition sizes
  current system_a size
  active-slot COW presence
```

## Bound C3A authority

```text
OFFLINE_EVIDENCE_DIR=
/srv/sable-build/evidence/titan2/c3a-v010014-control/20261003T192925Z_offline-plan

OFFLINE_EVIDENCE_SEAL_SHA256=
e6ad9a20192ef7c1fcb8bf0bfc1f393afd8b9cdd7239cb19b0497512f4f8fd57

C3A_SYSTEM_SHA256=
4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16

C3A_SYSTEM_BYTES=3146977280
```

The sealed pre-N1D E5B allocation/group package is:

```text
/srv/sable-build/evidence/titan2/n1d-c3b-e5a-readonly-device-state/20261003T053441Z/e5b-authorization-package.json

SHA256=
74531923a9ea6c755a9f8ea52db511c4a4a19a5d9dba3cb51da342c04b768926
```

## Entry state

Start with the Titan 2 already visible to `fastboot devices`.

Either of these is accepted:

```text
bootloader fastboot     is-userspace=no
userspace fastbootd     is-userspace=yes
```

If the device is in bootloader fastboot, the wrapper may execute only:

```text
fastboot reboot fastboot
```

to enter userspace fastbootd.

No ADB path is used.

## Fresh fail-closed checks

The qualifier requires:

```text
fresh fastboot serial hash = sealed device-binding hash
current slot = a
product = Titan_2
unlocked = yes
is-userspace = yes
snapshot-update-status = none
super bytes = 9663676416
system_a = logical
system_a current size > 0
active-slot COW count = 0
sealed baseline active COW count = 0
all sealed active-group members have fresh current sizes
C3A target fits sealed active-group maximum
C3A target leaves >= 512 MiB whole-super headroom
```

Capacity is conservative. Group membership/max and the pre-N1D whole-super
allocation come from the sealed E5B package; current active-group member sizes
come from fresh fastbootd evidence. The whole-super allocation is rebased by
the fresh active-group size delta. This avoids assuming that an omitted
`is-logical:*` getvar means a partition consumes zero bytes.

Active COWs are a hard stop. This preflight does not clean them.

## Authorization boundary

Authorized:

```text
read-only fastboot devices/getvar
bootloader-fastboot -> userspace-fastbootd mode switch if required
```

Not authorized:

```text
ADB
Android boot
flash
erase / format / factory reset
logical-partition resize/create/delete
COW cleanup
AVB/vbmeta mutation
slot change
unlock/lock
custom boot
reboot back to Android
```

The successful terminal device mode is userspace fastbootd.

## Run

```bash
cd /srv/sable-build/sableos/repo

bash build/gates/c3a-v010014-fastboot-entry-preflight-contract.sh

fastboot devices

bash build/titan2/collect-c3a-v010014-fastboot-entry-preflight.sh \
  --authorize-readonly-fastboot-contact \
  --authorize-fastbootd-mode-switch
```

Expected clean result:

```text
C3A_FASTBOOT_ENTRY_CURRENT_SLOT=a
C3A_FASTBOOT_ENTRY_IS_USERSPACE=yes
C3A_FASTBOOT_ENTRY_UNLOCKED=yes
C3A_FASTBOOT_ENTRY_PRODUCT=Titan_2
C3A_FASTBOOT_ENTRY_SNAPSHOT_UPDATE_STATUS=none
C3A_FASTBOOT_ENTRY_ACTIVE_COW_COUNT=0
C3A_FASTBOOT_ENTRY_SUPER_CAPACITY_SAFE=YES
C3A_FASTBOOT_ENTRY_ACTIVE_GROUP_CAPACITY_SAFE=YES

C3A_FASTBOOT_ENTRY_PREFLIGHT=
PASS_READY_FOR_PHYSICAL_CONTROL_REVIEW

C3A_FASTBOOT_ENTRY_FLASH_AUTHORIZED=NO
C3A_FASTBOOT_ENTRY_FACTORY_RESET_AUTHORIZED=NO
C3A_FASTBOOT_ENTRY_LP_MUTATION_AUTHORIZED=NO
C3A_FASTBOOT_ENTRY_COW_CLEANUP_AUTHORIZED=NO
C3A_FASTBOOT_ENTRY_WRITE_CAPABLE_SCRIPT_CREATED=NO

C3A_FASTBOOT_ENTRY_FINAL_DEVICE_MODE=FASTBOOTD
```

Any BLOCKED result stops the C3A control.

A PASS still does not authorize a write. The next deliverable is the separately
gated C3A `system_a` physical-control execution package.
