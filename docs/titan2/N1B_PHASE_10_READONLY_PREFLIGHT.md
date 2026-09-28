# N1B Phase 10: Titan2 Read-Only Physical Preflight

## Purpose

Phase 10 collects the physical metadata required by the N1B Phase 09 GSI deployment readiness gate.

Phase 10 is split into two explicit read-only scripts:

```text
10A = Android/ADB read-only metadata collection
10B = bootloader/fastboot or fastbootd read-only metadata collection
```

The default posture is no mode switching. Phase 10B can optionally perform Android -> bootloader and bootloader -> fastbootd transitions only when explicit command-line flags are supplied. Those mode-switch commands are audited separately from read-only getvar collection.

These scripts do not flash, erase, unlock, change slots, patch AVB, mutate logical partitions, or make a public-release or production-signing claim.

## Authorization boundary

```text
DEVICE=titan2
RELEASE=N1B
DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY
ADB_COMMANDS_AUTHORIZED=YES_READ_ONLY_FOR_10A
FASTBOOT_COMMANDS_AUTHORIZED=YES_READ_ONLY_FOR_10B
MODE_SWITCH_AUTHORIZED=NO_BY_DEFAULT
MODE_SWITCH_AUTHORIZED_ADB_REBOOT_BOOTLOADER=YES_ONLY_WITH_EXPLICIT_FLAG
MODE_SWITCH_AUTHORIZED_FASTBOOT_REBOOT_FASTBOOTD=YES_ONLY_WITH_EXPLICIT_FLAG
FLASH_AUTHORIZED=NO
ERASE_AUTHORIZED=NO
UNLOCK_AUTHORIZED=NO
PUBLIC_RELEASE=NO
PRODUCTION_SIGNING=NO
```

## Scripts

```text
build/titan2/collect-n1b-phase-10a-adb-readonly-preflight.sh
build/titan2/collect-n1b-phase-10b-fastboot-readonly-preflight.sh
build/gates/n1b-phase-10-readonly-preflight-contract.sh
```

## Phase 10A: ADB read-only metadata

10A assumes the Titan2 is booted into Android with USB debugging authorized.

10A may run only read-only ADB commands such as:

```text
adb devices -l
adb shell getprop
adb shell cat /proc/mounts
adb shell df -h
adb shell ls -l /dev/block/by-name
adb shell snapshotctl status
adb shell dumpsys update_engine
adb shell blockdev --getsize64 <system block candidates>
```

10A must not run:

```text
adb reboot
adb root
adb remount
adb push
adb sync
adb install
adb shell dd
adb shell setprop
adb shell cmd
adb shell pm
adb shell settings put
```

## Phase 10B: fastboot/fastbootd read-only metadata

10B collects read-only fastboot metadata. By default, it expects the Titan2 to already be in bootloader fastboot or fastbootd.

10B may run read-only fastboot commands such as:

```text
fastboot devices
fastboot getvar all
fastboot getvar current-slot
fastboot getvar is-userspace
fastboot getvar unlocked
fastboot getvar secure
fastboot getvar product
fastboot getvar slot-count
fastboot getvar partition-size:system
fastboot getvar partition-size:system_a
fastboot getvar partition-size:system_b
fastboot getvar partition-size:super
```

10B supports explicit mode-switch flags for the practical Titan2 workflow:

```text
--adb-reboot-bootloader-if-android
--fastboot-reboot-fastbootd-if-bootloader
--require-fastbootd
```

The first flag may run `adb reboot bootloader` only when no fastboot device is visible and an Android device is visible. The second flag may run `fastboot reboot fastboot` only after bootloader fastboot is visible and `is-userspace=no`. Both transitions are explicit and logged.

10B must not run:

```text
fastboot flash
fastboot erase
fastboot format
fastboot flashing
fastboot oem
fastboot set_active
fastboot --set-active
```

## Required Phase 09 metadata fields

Phase 10 is intended to produce evidence for the fields Phase 09 currently reports as missing:

```text
active_slot
avb_action
bootloader_preflight
explicit_titan_serial
fastbootd_preflight
lp_action
restore_path_verified
restore_report
snapshot_update_status
stock_baseline
system_current_bytes
userdata_policy
```

## Expected result after 10A only

After 10A only, Phase 09 should normally remain blocked because bootloader/fastbootd metadata has not been collected.

```text
N1B_PHASE_10A_ADB_READONLY_PREFLIGHT=PASS
N1B_PHASE_09_FLASH_PLAN_ALLOWED=NO
FLASH_AUTHORIZED=NO
```

## Expected result after bootloader-only 10B

Bootloader fastboot may report `is-userspace=no` and may not expose logical system partition sizing. In that case `system_current_bytes` may remain `0`, and Phase 09 should remain blocked.

```text
N1B_PHASE_10B_FASTBOOT_READONLY_PREFLIGHT=PASS
IS_USERSPACE=no
SYSTEM_CURRENT_BYTES=0
N1B_PHASE_09_FLASH_PLAN_ALLOWED=NO
```

## Expected result after 10B reaches fastbootd

For GSI deployment planning, userspace fastbootd is expected to expose logical partition metadata. A later merge step may combine 10A and 10B read-only evidence into a complete physical-preflight metadata record. Even then, the output can authorize only flash-plan generation, not flash execution.

```text
N1B_PHASE_10B_FASTBOOT_READONLY_PREFLIGHT=PASS
IS_USERSPACE=yes
N1B_PHASE_10_READONLY_PREFLIGHT=PASS_METADATA_COLLECTED
N1B_PHASE_09_FLASH_PLAN_ALLOWED=YES_PLAN_ONLY
FLASH_AUTHORIZED=NO
```
