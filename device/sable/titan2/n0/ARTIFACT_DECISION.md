# Titan 2 N0 artifact decision

Status: **first build candidate selected — gsi-system-image; deployment still closed**

The first Titan 2 artifact will be a **system-only ARM64 candidate** built for the
stock Treble/vendor basis. This is the smallest artifact that can test Sable
userspace while leaving the MediaTek kernel, vendor, ODM and firmware partitions
unchanged.

## Decision

```text
TITAN2_N0_ARTIFACT_KIND=gsi-system-image
PRIMARY_ARTIFACT=system
TARGET_ARCH=arm64
TARGET_ANDROID_RELEASE=16
TARGET_PLATFORM_SDK=36
STOCK_VENDOR_API=34
STOCK_VNDK=34
BUILD_TARGET_IMPLEMENTATION=IN_PROGRESS
BUILD_IMAGE_ENABLED=AFTER_SUBSTRATE_QUALIFICATION
FLASH_ENABLED=NO
E3_DEPLOYMENT_ENABLED=NO
```

## Why system-only first

- Titan 2 is Treble-enabled and the stock vendor/ODM stack is already the
  qualified hardware basis.
- A system-only candidate minimizes the write surface for the first N0.
- The first N0 success gate is boot/ADB/display/input enumeration, not complete
  subsystem parity.
- Exact logical size and AVB handling can be checked after the image exists,
  before any flash.

The choice is a **build candidate**, not a claim that the image already fits or
boots.

## Required after build, before deployment

```text
LP_FREE_SPACE_OK=E3_PENDING
SYSTEM_LOGICAL_SIZE_OK=E3_PENDING
AVB_STRATEGY_OK=TODO
VENDOR_COMPATIBILITY_OK=FIRST_BOOT_PENDING
RESTORE_PATH_OK=PASS
USERDATA_POLICY_OK=TODO
ARTIFACT_SHA256=TODO
E3_DEPLOYMENT_AUTHORIZED=NO
```

## Fallback rule

Escalate from a single system image only if evidence requires it:

1. use a bounded `system/product/system_ext` bundle when Sable composition
   cannot be represented cleanly in `system.img`;
2. use a generated `super.img` only when reviewed logical-partition layout
   changes are actually required.

Do not start with `super.img` merely because the device uses dynamic
partitions.
