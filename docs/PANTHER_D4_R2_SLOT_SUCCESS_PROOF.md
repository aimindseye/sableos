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

## First authorized physical slot-success attempt

The first authorized physical run used script SHA-256:

```text
7cb77b25a11968aa4f439ecc58acb517c525014b72c312981fc25de25c327de4
```

It proved the pre-reboot Android state and reached exactly one fastboot transport, then bounded-failed on the first `getvar product` query:

```text
PRE_DEVICE_PRODUCT=panther
PRE_SLOT_SUFFIX=_b
PRE_BOOT_COMPLETED=1
FASTBOOT_TRANSPORT=PASS_ONE_DEVICE
GATE_ERROR=FASTBOOT_PRODUCT_UNOBSERVABLE
PANTHER_D4_R2_SLOT_SUCCESS_RESULT=BOUNDED_FAIL
R2_RC=50
```

Its immediate recovery `fastboot reboot` also returned `1`. A subsequent manual read-only probe, without any flash or slot mutation, showed:

```text
CURRENT_MODE=FASTBOOT
fastboot getvar product -> product: panther
FASTBOOT_GETVAR_PRODUCT_RC=0
fastboot reboot -> RC=0
POST_BOOT_COMPLETED=PASS
POST_PRODUCT=panther
POST_SLOT_SUFFIX=_b
```

Therefore the first R2 failure is classified as:

```text
R2_FAILURE_CLASS=HOST_HARNESS_FASTBOOT_READINESS_RACE
R2_SLOT_CONTRADICTION=NONE
R2_FLASH_EXECUTION=NONE
R2_SLOT_CHANGE=NONE
R2_DATA_MUTATION=NONE
R2_RECOVERY=PASS_MANUAL_AUTHORIZED_REBOOT
```

`fastboot devices` enumeration alone was not a sufficient readiness predicate on this physical Panther/host combination.

## Corrected harness

`tools/validation/panther-d4/PANTHER_D4_R2_SLOT_SUCCESS_PROOF.sh` now:

1. binds the live Android product, slot and completed-boot state;
2. reboots to the bootloader;
3. requires exactly one fastboot device without printing its serial;
4. does **not** declare fastboot ready until a read-only `getvar product` succeeds;
5. reuses that successful product response and retries subsequent read-only slot `getvar` queries through transient readiness windows;
6. requires product `panther`, current slot `b`, slot count `2`, `slot-successful:b=yes`, and `slot-unbootable:b=no`;
7. records `slot-retry-count:b` when observable without making it a closure blocker;
8. reboots back to Android;
9. waits for both authorized ADB transport and `sys.boot_completed=1`, then proves product and slot again;
10. writes a final SHA-256 evidence seal.

Recovery is also hardened: after an authorized reboot-to-bootloader has succeeded, any bounded failure retries the authorized `fastboot reboot` through the same transient readiness window and, when possible, confirms completed Android boot.

The corrected script's Git blob identity on branch `sablectl-v0.1-clean` is:

```text
94e0dd1d6b40e29771df13a3f0ba0ba4716488b8
```

The next physical run's evidence seal will record the exact SHA-256 of the corrected script and its final log.

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

## Execution

Do not run without explicit reboot authorization.

When authorized, bind the corrected Git blob before execution:

```bash
cd /home/mindseye73/sableos-tools

git pull --ff-only

SCRIPT=tools/validation/panther-d4/PANTHER_D4_R2_SLOT_SUCCESS_PROOF.sh
EXPECTED_BLOB=94e0dd1d6b40e29771df13a3f0ba0ba4716488b8
ACTUAL_BLOB=$(git hash-object "$SCRIPT")

printf 'EXPECTED_SCRIPT_BLOB=%s\n' "$EXPECTED_BLOB"
printf 'ACTUAL_SCRIPT_BLOB=%s\n' "$ACTUAL_BLOB"
[[ "$ACTUAL_BLOB" == "$EXPECTED_BLOB" ]] || exit 90

sha256sum "$SCRIPT"

DEVICE_CONTACT_AUTHORIZED=YES \
DEVICE_REBOOT_AUTHORIZED=YES \
FLASH_AUTHORIZED=NO \
SLOT_CHANGE_AUTHORIZED=NO \
USERDATA_OR_METADATA_WIPE_AUTHORIZED=NO \
EXPECTED_DEVICE=panther \
EXPECTED_SLOT=b \
bash "$SCRIPT"
```

Expected closure markers:

```text
FASTBOOT_TRANSPORT=PASS_ONE_DEVICE
FASTBOOT_GETVAR_READY=PASS
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
