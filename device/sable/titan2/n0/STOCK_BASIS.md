# Titan 2 N0 stock basis

Status: **placeholder — bind before artifact work**

The first Titan 2 N0 artifact must be bound to an exact stock firmware/vendor
basis. This file records the normalized starting basis and the missing proofs
that must be completed before E3/N0 deployment.

## Normalized known basis

```text
DEVICE=titan2
FASTBOOT_PRODUCT=g71v78c2k_dfl_tee
STOCK_BASELINE=V01.00.13
ANDROID_BASE=16
SOC=MediaTek_MT6878
ARCH=arm64_only
VENDOR_API=34
VNDK=34
KERNEL=6.1.145_android14_derived
DYNAMIC_PARTITIONS=YES
VIRTUAL_AB=YES
SUPER_BYTES=9663676416
FASTBOOTD=YES
FASTBOOT_BOOT=NO
DSU=NO_ON_TESTED_STOCK_BUILD
RECOVERY_PATH=vendor_boot_recovery_vendor_ramdisk
```

## Required binding before artifact creation

```text
STOCK_FIRMWARE_SOURCE_HASHED=TODO
RESTORE_CRITICAL_IMAGE_HASHES=TODO
ACTIVE_SLOT_CAPTURED=TODO
LP_METADATA_CAPTURED=TODO
SNAPSHOT_STATE_CAPTURED=TODO
VBOOT_CHAIN_CAPTURED=TODO
AVB_STRATEGY_DECIDED=TODO
USERDATA_POLICY_DECIDED=TODO
```

## Stock dependency assumption

Initial N0 should preserve the stock MediaTek kernel/vendor stack unless evidence
forces a different approach.

```text
boot
init_boot
vendor_boot
dtbo
vendor
vendor_dlkm
odm_dlkm
vbmeta_vendor
modem and MTK firmware partitions
```

Do not modify additional partitions without an explicit bring-up reason.
