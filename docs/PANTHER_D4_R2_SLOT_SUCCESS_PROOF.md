# Panther D4-R2 — slot-success proof

Date: 2026-09-08

## Current evidence boundary

`sablectl` v0.3.1 is validated on the physical Panther B2 install:

```text
PYTEST=PASS_26_OF_26
SABLECTL_VERSION=0.3.1
RELEASE_D4_PASS=56
RELEASE_D4_FAIL=0
RELEASE_D4_SKIP=8
RELEASE_D4_MANUAL=0
RELEASE_D4_ERROR=0
RELEASE_D4_OVERALL=PASS
RELEASE_D4_RC=0
```

The runtime slot is proven as `_b`. Ordinary ADB shell cannot obtain the Android Boot Control client on this build (`bootctl get-current-slot rc=70`), and the boot-time slot-success properties are unavailable. Therefore:

```text
D4_RUNTIME_SLOT_B=PASS
D4_RELEASE_GATE=PASS
D4_SLOT_B_SUCCESSFUL=CURRENT_STATE_NOT_PROVEN
```

This is an observability boundary, not evidence that slot B is unsuccessful.

## Purpose of the R2 slot-success harness

`tools/validation/panther-d4/PANTHER_D4_R2_SLOT_SUCCESS_PROOF.sh` closes only the remaining current-state slot metadata boundary.

It requires explicit authorization for device contact and reboot, then:

1. binds the live Android product, slot and completed-boot state;
2. reboots to the bootloader;
3. requires exactly one fastboot device without printing its serial;
4. performs only read-only `fastboot getvar` queries;
5. requires product `panther`, current slot `b`, slot count `2`, `slot-successful:b=yes`, and `slot-unbootable:b=no`;
6. records `slot-retry-count:b` when observable without making it a closure blocker;
7. reboots back to Android;
8. waits for both authorized ADB transport and `sys.boot_completed=1`, then proves product and slot again;
9. writes a final SHA-256 evidence seal.

Android's A/B fastboot contract defines the relevant variables as `current-slot`, `slot-count`, `slot-successful:<slot>`, `slot-unbootable:<slot>`, and `slot-retry-count:<slot>`.

## Mutation boundary

The harness contains no flash, erase, format, set-active, unlock, lock, userdata or metadata wipe operation.

The only device mutations are the two explicitly authorized reboots:

```text
Android -> bootloader
bootloader -> Android
```

Authorization defaults are fail-closed:

```text
DEVICE_CONTACT_AUTHORIZED=NO
DEVICE_REBOOT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
SLOT_CHANGE_AUTHORIZED=NO
USERDATA_OR_METADATA_WIPE_AUTHORIZED=NO
```

A run may proceed only with:

```text
DEVICE_CONTACT_AUTHORIZED=YES
DEVICE_REBOOT_AUTHORIZED=YES
FLASH_AUTHORIZED=NO
SLOT_CHANGE_AUTHORIZED=NO
USERDATA_OR_METADATA_WIPE_AUTHORIZED=NO
```

## Pre-delivery adversarial validation

Exact script SHA-256:

```text
7cb77b25a11968aa4f439ecc58acb517c525014b72c312981fc25de25c327de4
```

Validated cases:

```text
BASH_SYNTAX=PASS
SUCCESS_CASE=PASS
DELAYED_POSTBOOT_COMPLETION=PASS
FAIL_SUCCESSFUL_NO=PASS
FAIL_RECOVERY_REBOOT=PASS
NOAUTH_NO_DEVICE_CONTACT=PASS
EVIDENCE_COLLISION_RESISTANCE=PASS
SERIAL_LEAK=ABSENT
FORBIDDEN_FASTBOOT_MUTATIONS=ABSENT
```

Two pre-execution defects were found and superseded during adversarial validation:

1. a same-second evidence-directory collision, fixed by using `mktemp -d` with a timestamp prefix plus unique suffix;
2. a real-device postboot timing race where ADB may report `device` before `sys.boot_completed=1`, fixed by waiting explicitly for completed Android boot before final validation.

After the authorized `adb reboot bootloader` command succeeds, any bounded failure attempts the authorized recovery reboot back to Android.

## Execution

Do not run without explicit reboot authorization.

When authorized:

```bash
cd /home/mindseye73/sableos-tools

git pull --ff-only

sha256sum tools/validation/panther-d4/PANTHER_D4_R2_SLOT_SUCCESS_PROOF.sh

DEVICE_CONTACT_AUTHORIZED=YES \
DEVICE_REBOOT_AUTHORIZED=YES \
FLASH_AUTHORIZED=NO \
SLOT_CHANGE_AUTHORIZED=NO \
USERDATA_OR_METADATA_WIPE_AUTHORIZED=NO \
EXPECTED_DEVICE=panther \
EXPECTED_SLOT=b \
bash tools/validation/panther-d4/PANTHER_D4_R2_SLOT_SUCCESS_PROOF.sh
```

Expected script hash before execution:

```text
7cb77b25a11968aa4f439ecc58acb517c525014b72c312981fc25de25c327de4
```

Expected closure markers:

```text
FASTBOOT_PRODUCT=panther
FASTBOOT_CURRENT_SLOT=b
FASTBOOT_SLOT_COUNT=2
FASTBOOT_SLOT_SUCCESSFUL_b=yes
FASTBOOT_SLOT_UNBOOTABLE_b=no
D4_SLOT_B_SUCCESSFUL=PASS
D4_SLOT_B_BOOTABLE=PASS
D4_SLOT_B_CURRENT=PASS
POST_SLOT_SUFFIX=_b
POST_BOOT_COMPLETED=1
POST_SLOT_PRESERVED=PASS
PANTHER_D4_R2_SLOT_SUCCESS_RESULT=PASS
```

Only after those markers are observed should the roadmap claim `D4_SLOT_B_SUCCESSFUL=PASS`.
