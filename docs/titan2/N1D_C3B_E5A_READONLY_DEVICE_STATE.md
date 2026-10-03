# N1D C3B E5A read-only device-state revalidation

Status: **AUTHORIZED / OPERATOR READY**  
Authorization date: **2026-10-03**

E5A is the fresh-device checkpoint between sealed E4 deployment readiness and
any later E5B mutation/deployment discussion.

## Authorized scope

```text
DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY_E5A
ADB_READONLY_AUTHORIZED=YES
FASTBOOT_READONLY_AUTHORIZED=YES
REBOOT_BOOTLOADER_AUTHORIZED=YES
REBOOT_FASTBOOTD_AUTHORIZED=YES

FLASH_AUTHORIZED=NO
ERASE_AUTHORIZED=NO
FORMAT_AUTHORIZED=NO
LP_MUTATION_AUTHORIZED=NO
AVB_MUTATION_AUTHORIZED=NO
SLOT_MUTATION_AUTHORIZED=NO
UNLOCK_LOCK_AUTHORIZED=NO
FACTORY_RESET_AUTHORIZED=NO
CUSTOM_BOOT_AUTHORIZED=NO
REBOOT_BACK_TO_ANDROID=NO_NOT_AUTHORIZED
```

The only authorized device-state transitions are:

```text
stock Android -> bootloader fastboot
bootloader fastboot -> userspace fastbootd
```

The device is intentionally left in userspace fastbootd for evidence review.

## Required starting state

Start with the Titan 2 booted into the proven restored stock baseline, USB
debugging enabled and ai-g732 already authorized for ADB.

Expected stock identity:

```text
incremental=V01.00.14
fingerprint=Unihertz/Titan_2/Titan_2:16/BP2A.250605.031.A3/V01.00.14:user/release-keys
```

A mismatch fails before the authorized reboot.

## Captured evidence

Before reboot, E5A records read-only Android state:

- build fingerprint and incremental;
- active slot;
- verified-boot/vbmeta state;
- dynamic-partition and virtual-A/B properties when exposed;
- battery level;
- snapshot/update state;
- read-only `lpdump` and block-size observations when available.

It performs a controlled single-device mode transition: exactly one authorized ADB device is accepted before reboot, and exactly one fastboot device is accepted after the commanded transition unless an explicit fastboot serial is supplied. ADB and fastboot identifiers are hashed separately and raw serials are not printed.

In bootloader and fastbootd it records only read-only `getvar` information,
including current slot, userspace state, unlocked/secure state, snapshot/update
state, `super` size and logical-partition sizes.

## Fresh capacity rule

The sealed E3 image remains:

```text
SYSTEM_SHA256=998a8b99cd4d1a631006291a96c6f0160c5a4400c4bf6bba62c319c4ed3c82a5
SYSTEM_BYTES=2994405376
PLANNED_SYSTEM_TARGET_BYTES=3263168512
MIN_REMAINING_HEADROOM_BYTES=536870912
```

E5A does not trust a missing inactive-slot size as zero. A fresh capacity PASS
requires complete allocation evidence: either a complete logical-partition list
from fastboot `getvar all`, or complete slot-size evidence for every known
slotted dynamic-partition family. Otherwise E5A blocks with incomplete/unknown
capacity rather than overstating free `super` space.

## Privacy

Raw ADB/fastboot enumeration files remain local evidence and may contain the
device serial. Do not publish them.

Console output uses only:

```text
N1D_C3B_E5A_DEVICE_BINDING_SHA256=<adb-sha256>\nN1D_C3B_E5A_FASTBOOT_BINDING_SHA256=<fastboot-sha256>\nN1D_C3B_E5A_DEVICE_BINDING_METHOD=CONTROLLED_SINGLE_DEVICE_MODE_TRANSITION
```

## Operator run

After merging the E5A package, use the exact merged-main head published with the
handoff, then:

```bash
bash build/gates/n1d-c3b-e5a-readonly-device-state-contract.sh

bash build/titan2/collect-n1d-c3b-e5a-readonly-device-state.sh \
  --authorize-e5a-readonly \
  --authorize-reboot-to-fastbootd
```

Do not add any other authorization flag.

## Successful review states

```text
N1D_C3B_E5A_READONLY_DEVICE_STATE=PASS_REVIEW_READY

or

N1D_C3B_E5A_READONLY_DEVICE_STATE=
PASS_REVIEW_READY_SNAPSHOT_STATUS_REQUIRES_ADB_EVIDENCE_REVIEW
```

The latter still requires manual snapshot/update review.

Any `BLOCKED_*` result stops E5B planning.

## E5B boundary

E5A PASS does not authorize E5B.

```text
E5B_FLASH_AUTHORIZED=NO
E5B_LP_MUTATION_AUTHORIZED=NO
E5B_AVB_MUTATION_AUTHORIZED=NO
E5B_SLOT_MUTATION_AUTHORIZED=NO
```

The E5B plan may be prepared only after the fresh E5A evidence has been reviewed.
