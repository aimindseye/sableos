# Titan 2 N0 stock basis

Status: **bound for first-build work — deployment decisions remain closed**

The first Titan 2 N0 artifact is bound to the tested US retail stock
firmware/vendor basis below. Normalized evidence comes from
`aimindseye/unihertz-titan2` PR #15 at
`cabae7ab474daebc25f201586821c257b216e612`; raw firmware, partition images,
serials and private captures remain outside this repository.

## Normalized known basis

```text
DEVICE=titan2
FASTBOOT_PRODUCT=g71v78c2k_dfl_tee
FASTBOOTD_PRODUCT=Titan_2
STOCK_BASELINE=V01.00.13
ANDROID_BASE=16
PLATFORM_SDK=36
BOARD_FIRST_API=34
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
ACTIVE_SLOT=a
BOOTLOADER_UNLOCKED=YES
VERIFIED_BOOT=orange
SNAPSHOT_UPDATE_STATUS=none
```

## Evidence binding

```text
STOCK_FIRMWARE_SOURCE_HASHED=PASS
RESTORE_CRITICAL_IMAGE_HASHES=PASS
ACTIVE_SLOT_CAPTURED=PASS
LP_METADATA_CAPTURED=PASS
SNAPSHOT_STATE_CAPTURED=PASS_NONE_ACTIVE
VBOOT_CHAIN_CAPTURED=PASS
RESTORE_PLAN_VERIFIED=PASS
TITAN2_STOCK_BASIS_BOUND=YES_FOR_BUILD
```

E0 restore verification, E1 bootloader-fastboot preflight and E2 fastbootd/LP
preflight are complete. That is sufficient to create and inspect a **non-flashed**
candidate system artifact.

The following remain deployment gates, not build gates:

```text
AVB_STRATEGY_DECIDED=NO
USERDATA_POLICY_DECIDED=NO
E3_ARTIFACT_FIT_VERIFIED=NO
E3_DEPLOYMENT_AUTHORIZED=NO
```

## Stock dependency assumption

Initial N0 preserves the stock MediaTek kernel/vendor/firmware stack unless
first-boot evidence forces a narrower change:

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

The first build therefore must not package Panther boot images, Pixel vendor
content, Titan stock firmware or extracted proprietary blobs.
