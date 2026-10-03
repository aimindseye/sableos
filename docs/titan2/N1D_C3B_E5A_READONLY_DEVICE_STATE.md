# N1D C3B E5A read-only device-state revalidation

Status: **AUTHORIZED / READY TO RUN**

Authorization granted on **2026-10-03**:

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

## Implementation strategy

E5A deliberately reuses the already-audited N1B read-only collectors:

```text
Phase 10A -> stock Android ADB read-only baseline
Phase 10B -> authorized Android->bootloader->fastbootd transition + read-only getvars
Phase 11  -> read-only fastbootd logical-partition/super sizing
C3B E5A qualifier -> offline C3B-specific validation and sanitized final evidence
```

The E5A wrapper does not introduce a second fastboot implementation.

## Starting state

Start E5A with the Titan 2 booted into recovered stock Android **V01.00.14**, USB
debugging enabled and the ai-g732 host authorized for ADB.

Expected stock fingerprint:

```text
Unihertz/Titan_2/Titan_2:16/BP2A.250605.031.A3/V01.00.14:user/release-keys
```

Expected incremental:

```text
V01.00.14
```

A different stock baseline blocks E5B planning until matching restore evidence is
reviewed.

## Pre-contact checks

Before contacting the phone E5A must prove:

```text
E4 sealed evidence contract=PASS
sealed E3 system SHA/size still match
E4 stock-super artifact hash still matches
E4 six boot/AVB artifact hashes still match
Phase 10 and Phase 11 read-only safety contracts=PASS
```

## What E5A captures

ADB before mode switching:

```text
stock build fingerprint / incremental
current slot
verified-boot and vbmeta device state
dynamic-partition / virtual-A/B properties
battery level
snapshotctl status
update_engine status
read-only lpdump when available
```

Bootloader and userspace fastbootd:

```text
current slot
is-userspace
unlocked / secure
product / slot count
snapshot-update-status when exposed
system/system_ext/product/vendor/odm/dlkm logical sizes
super size
fresh all-slot reported logical allocation estimate
fresh remaining capacity after proposed E3 system growth
```

## Privacy

The device serial is needed internally to bind ADB, bootloader fastboot and
fastbootd to the same phone. All raw serial-bearing Phase 10/11 JSON, command output and console logs are
kept beneath the local `private/` evidence subtree. The C3B summary independently
hash-verifies that 10A, 10B and Phase 11 refer to the same device.

Normal console/final C3B evidence records only:

```text
N1D_C3B_E5A_DEVICE_BINDING_SHA256=<hash>
```

Do not publish the raw private Phase 10/11 logs.

## Mode transitions

The underlying audited Phase 10B collector is allowed to execute only:

```text
adb reboot bootloader
fastboot reboot fastboot
```

No reboot back to Android is authorized. A successful E5A leaves the phone in
userspace fastbootd for review.

## Fresh capacity rule

E4 used historical sizing. E5A uses fresh fastbootd evidence and prefers all
logical partitions reported by getvar-all. If the device does not expose
logical markers, it may calculate a known-family fallback estimate, but that
fallback is explicitly marked for manual review and cannot by itself clear E5B.

```text
PLANNED_SYSTEM_TARGET_BYTES=3263168512
MIN_REMAINING_HEADROOM_BYTES=536870912
MIN_FUTURE_MUTATION_BATTERY_PERCENT=50
```

This remains a planning calculation. E5A never resizes a partition.

## Run

After the E5A PR is merged, from exact merged main:

```bash
cd /srv/sable-build/sableos/repo

git fetch origin main
git switch main
git pull --ff-only origin main

bash build/gates/n1d-c3b-e5a-readonly-device-state-contract.sh

bash build/titan2/collect-n1d-c3b-e5a-readonly-device-state.sh \
  --authorize-e5a-readonly \
  --authorize-reboot-to-fastbootd
```

The script expects exactly one authorized ADB device unless an explicit serial is
supplied.

## Review-ready results

```text
N1D_C3B_E5A_READONLY_DEVICE_STATE=PASS_REVIEW_READY

or

N1D_C3B_E5A_READONLY_DEVICE_STATE=
PASS_REVIEW_READY_SNAPSHOT_STATUS_REQUIRES_MANUAL_REVIEW
```

The second result still blocks E5B until the captured snapshot/update evidence
is reviewed.

Any BLOCKED_* result blocks E5B.

Even on PASS:

```text
E5B_FLASH_AUTHORIZED=NO
E5B_LP_MUTATION_AUTHORIZED=NO
E5B_AVB_MUTATION_AUTHORIZED=NO
E5B_SLOT_MUTATION_AUTHORIZED=NO
E5B_UNLOCK_LOCK_AUTHORIZED=NO
E5B_FACTORY_RESET_AUTHORIZED=NO
```
