# Titan 2 N0-AOSP BP4A Control Build Pass Seal

Status: `PASS_WITH_PATCH_QUEUE`

This document seals the first N0-AOSP control build result for the Titan 2 / MediaTek GSI build track. It records a local build result only; it does **not** mark the artifact as flashable on Titan 2 or Titan 2 Elite.

## Canonical stage position

```text
CURRENT_STAGE=N0-AOSP
NEXT_STAGE=N0-B-TREBLE
N1_RESERVED_FOR=SABLEOS_PRODUCT_OVERLAY
N2_RESERVED_FOR=PHYSICAL_TITAN2_VALIDATION
```

## Result

```text
STAGE=N0-AOSP
TARGET=generic_system_arm64-bp4a-userdebug
GOAL=systemimage
AOSP_TAG=android-16.0.0_r4
BUILD_ID=BP4A.251205.006
OUT_DIR=/srv/data/sable-build/workspaces/titan2-n0-a16-20260926_221401/aosp-android16/out_sable_t2_n0_aosp_gsi_bp4a
EVIDENCE=/srv/data/sable-build/evidence/titan2/n0-bp4a-rerun/20260927_113543
LUNCH_RC=0
BUILD_RC=0
SYSTEM_IMG_COUNT=2
N0_BP4A_SYSTEMIMAGE=PASS
SKIP_ABI_CHECKS_USED=true
DEVICE_CONTACT=NO
FLASH_AUTHORIZED=NO
```

## Artifact

```text
SYSTEM_IMG=/srv/data/sable-build/workspaces/titan2-n0-a16-20260926_221401/aosp-android16/out_sable_t2_n0_aosp_gsi_bp4a/target/product/mainline_arm64/system.img
SYSTEM_IMG_SIZE=1003M
SYSTEM_IMG_SHA256=16b3eac3bc7c304df19b1cf68031bceae65b425e8e382cadb36bfb924bac1e30
INTERMEDIATE_SYSTEM_IMG=/srv/data/sable-build/workspaces/titan2-n0-a16-20260926_221401/aosp-android16/out_sable_t2_n0_aosp_gsi_bp4a/target/product/mainline_arm64/obj/PACKAGING/system_intermediates/system.img
INTERMEDIATE_SYSTEM_IMG_SHA256=16b3eac3bc7c304df19b1cf68031bceae65b425e8e382cadb36bfb924bac1e30
```

## Build prop sample

```text
ro.build.version.sdk=36
ro.build.version.sdk_full=36.1
ro.build.version.release=16
ro.build.version.security_patch=2025-12-05
ro.build.type=userdebug
ro.build.user=sable
ro.build.host=ai-g732
ro.build.tags=test-keys
ro.build.flavor=mainline-userdebug
```

## Patch queue used

```text
PATCH_1=platform_testing targeted test_package scratch unblocker
PATCH_1_SCOPE=platform_testing/Android.bp
PATCH_1_CLASSIFICATION=temporary_scratch_unblocker
PATCH_1_RUNTIME_SYSTEM_IMG_IMPACT=NO_EXPECTED

PATCH_2=generic_system_arm64 com.android.ranging existence-check allowlist
PATCH_2_SCOPE=build/make/target/product/generic_system_arm64.mk
PATCH_2_CLASSIFICATION=reusable_android16_bp4a_control_patch_candidate
PATCH_2_RUNTIME_SYSTEM_IMG_IMPACT=NO_EXPECTED

BUILD_ENV=SKIP_ABI_CHECKS=true
```

The `platform_testing` patch remains a scratch unblocker for the N0-AOSP control graph. The `com.android.ranging` allowlist remains the preferred narrow control patch because it preserves `base_system.mk` and `RELEASE_RANGING_STACK`.

## Interpretation

```text
N0_AOSP_BP4A_CONTROL=PASS_WITH_PATCH_QUEUE
FLASHABLE_TITAN2_ROM=NO
DEVICE_CONTACT=NO
FLASH_AUTHORIZED=NO
NEXT_STAGE=N0-B-TREBLE
```

N0-B-TREBLE must use the RestlessOS / TrebleDroid product hierarchy and a separate output directory. Do not reuse the N0-AOSP output directory for the Treble product graph.
