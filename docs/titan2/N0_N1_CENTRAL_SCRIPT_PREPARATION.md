# Titan 2 N0/N1 central script preparation

Status: **central script guardrail / no write-capable flash executor**

This document records the central SableOS script behavior required for Titan 2
N0 and N1 image work.

```text
TITAN2_CENTRAL_FLASH_GUARD=YES
PIXEL_FASTBOOT_ASSUMPTIONS_ALLOWED=NO
PANTHER_ARTIFACT_FLASH_TO_TITAN2_ALLOWED=NO
WRITE_CAPABLE_SCRIPT_ALLOWED=NO
SABLE_DEVICE_FLASH_SUPPORTED=NO
SABLE_DEVICE_FLASH_PLAN_SUPPORTED=YES
SABLE_DEVICE_ARTIFACT_KINDS=gsi-system-image
```

## Purpose

Titan 2 is not handled like Panther/Pixel.

Central scripts may prepare and validate the N0/N1 ledger for a Titan 2
`gsi-system-image` artifact, but they must not execute a flash until the reviewed
write plan exists.

## Allowed central operations

```text
REGISTER_TITAN2_GSI_ARTIFACT=YES
PREPARE_TITAN2_FLASH_PLAN_LEDGER=YES
VERIFY_RESTORE_BOOTLOADER_FASTBOOTD_METADATA=YES
VERIFY_AVB_LP_USERDATA_METADATA=YES
CREATE_WRITE_CAPABLE_SCRIPT=NO
CONTACT_DEVICE=NO
RUN_ADB=NO
RUN_FASTBOOT=NO
FLASH=NO
```

## Required registry metadata

Titan 2 artifact registration for a future N0/N1 image must include:

```text
metadata.artifact_logical_bytes=<bytes>
metadata.restore_report=<path>
metadata.bootloader_preflight=<path>
metadata.fastbootd_preflight=<path>
metadata.snapshot_update_status=none
metadata.system_current_bytes=<bytes>
metadata.lp_action=direct-flash|reviewed-resize
metadata.avb_action=<reviewed action>
metadata.userdata_policy=preserve|explicit-wipe-approved
metadata.explicit_titan_serial=REQUIRED
metadata.active_slot=a|b
metadata.stock_baseline=<stock id>
metadata.restore_path_verified=YES
```

The central `flash-plan` path validates these fields through
`build/titan2/prepare-n0-n1-flash-plan.sh`.

## Still blocked

```text
SABLE_DEVICE_FLASH_SUPPORTED=NO
SABLE_DEVICE_PRESERVED_DATA_FLASH_SUPPORTED=NO
FLASH_EXECUTOR_CREATED=NO
FASTBOOT_BOOT=UNSUPPORTED
DSU=UNAVAILABLE_ON_TESTED_STOCK_BUILD
```
