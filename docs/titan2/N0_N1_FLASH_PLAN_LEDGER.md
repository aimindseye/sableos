# Titan 2 N0/N1 flash plan ledger

Status: **flash-plan ledger / no write-capable executor**

This document records the SableOS-side gate for Titan 2 N0 and N1 deployment.
It exists so the project does not accidentally apply Pixel/Panther flashing
assumptions to Titan 2.

```text
TITAN2_N0_N1_FLASH_PLAN_LEDGER=YES
DEVICE=titan2
DEVICE_FAMILY=titan2,titan2-elite_independent
LANE=TREBLE_PORTABILITY
PIXEL_FASTBOOT_ASSUMPTIONS_ALLOWED=NO
PANTHER_ARTIFACT_FLASH_TO_TITAN2_ALLOWED=NO
FLASH_SCRIPT_CREATED=NO_UNTIL_REVIEWED
WRITE_CAPABLE_SCRIPT_ALLOWED=NO
IMAGE_BUILD_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
ADB_COMMANDS_RUN=NO
FASTBOOT_COMMANDS_RUN=NO
PUBLIC_RELEASE=NO
```

## Source authority

Titan 2 deployment policy is derived from the Titan 2 research repository and
must remain consistent with its bring-up contract, Tier 2 runbook, bootloader /
AVB evidence, and N0 acceptance matrix.

Required facts carried into SableOS execution:

```text
FASTBOOT_BOOT=UNSUPPORTED
DSU=UNAVAILABLE_ON_TESTED_STOCK_BUILD
FASTBOOTD=SUPPORTED
FASTBOOTD_MUST_BE_VERIFIED_BY_GETVAR_IS_USERSPACE_YES=YES
DYNAMIC_PARTITIONS=true
VIRTUAL_AB=true
SUPER_BYTES=9663676416
RECOVERY_PATH=vendor_boot_recovery_vendor_ramdisk
NO_STANDALONE_RECOVERY_PARTITION_OBSERVED=YES
FIRST_SABLE_BOOT=NOT_RUN
```

## Preserved stock dependency set

N0/N1 work must preserve the stock MediaTek kernel/vendor/firmware stack unless
specific bring-up evidence requires a reviewed exception.

```text
PRESERVE_BOOT=YES
PRESERVE_INIT_BOOT=YES
PRESERVE_VENDOR_BOOT=YES
PRESERVE_DTBO=YES
PRESERVE_VENDOR=YES
PRESERVE_VENDOR_DLKM=YES
PRESERVE_ODM_DLKM=YES
PRESERVE_VBMETA_VENDOR=YES
PRESERVE_MODEM_AND_MTK_FIRMWARE=YES
```

The first write should be system-side only after artifact preflight proves the
exact logical image identity, size, AVB posture and recovery path.

## Required pre-write ledger fields

No flash command sequence may be created until every field below is filled from
current evidence and reviewed.

```text
RESTORE_REPORT=REQUIRED
BOOTLOADER_PREFLIGHT=REQUIRED
FASTBOOTD_PREFLIGHT=REQUIRED
SNAPSHOT_UPDATE_STATUS=none
ARTIFACT_SHA256=REQUIRED
ARTIFACT_LOGICAL_BYTES=REQUIRED
SYSTEM_CURRENT_BYTES=REQUIRED
LP_ACTION=direct-flash|reviewed-resize
AVB_ACTION=REQUIRED
USERDATA_POLICY=preserve|explicit-wipe-approved
EXPLICIT_TITAN_SERIAL=REQUIRED
ACTIVE_SLOT=REQUIRED
STOCK_BASELINE=REQUIRED
RESTORE_PATH_VERIFIED=REQUIRED
```

A userdata wipe must never be implicit. If a wipe is required, it must be a
separate explicit destructive decision.

```text
USERDATA_WIPE_IMPLICIT_ALLOWED=NO
USERDATA_WIPE_REQUIRES_EXPLICIT_APPROVAL=YES
```

## Stop conditions

Stop before any write if any of these are true:

```text
TARGET_IDENTITY_AMBIGUOUS=STOP
RESTORE_VERIFICATION_FAILS=STOP
FASTBOOT_MODE_NOT_REQUESTED_MODE=STOP
BOOTLOADER_LOCKED_UNEXPECTEDLY=STOP
SNAPSHOT_UPDATE_STATUS_NOT_NONE=STOP
ARTIFACT_HASH_DIFFERS_FROM_REVIEWED_PLAN=STOP
ARTIFACT_SIZE_DIFFERS_FROM_REVIEWED_PLAN=STOP
LP_RESIZE_OR_DELETE_UNREVIEWED=STOP
RECOVERY_PATH_NOT_VERIFIED=STOP
```

## N0 minimum success gate

N0 success is intentionally narrow. It proves the bring-up loop is viable; it
does not claim full hardware parity.

```text
N0_SYS_BOOT_COMPLETED=REQUIRED
N0_ADB_EXPLICIT_TITAN_SERIAL=REQUIRED
N0_PRIMARY_DISPLAY_USABLE=REQUIRED
N0_PRIMARY_TOUCH_USABLE=REQUIRED
N0_TITANKEY_ENUMERATED=REQUIRED
N0_TITANKEY_BASIC_EVENTS=REQUIRED
N0_TOUCHPAD_ENUMERATED=REQUIRED
N0_BOUNDED_RECOVERY_PATH=REQUIRED
```

Rear SubScreen, fingerprint, camera, audio, modem/IMS, sensors and other parity
areas remain N0 follow-up work unless they block the minimum gate.

## N1 rule

N1 may use the same Titan flash model only after N0 evidence exists. N1 must not
skip the Titan-specific AVB / logical-partition / userdata / restore review just
because N0 succeeded.

```text
N1_REQUIRES_N0_EVIDENCE=YES
N1_REUSES_TITAN_FLASH_GATES=YES
N1_SKIP_AVB_LP_USERDATA_REVIEW_ALLOWED=NO
```
