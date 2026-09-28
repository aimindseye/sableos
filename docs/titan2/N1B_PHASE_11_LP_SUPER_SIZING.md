# N1B Phase 11: Titan2 LP/Super Sizing Analysis

## Purpose

Phase 11 determines whether the canonical N1B GSI system image can fit the Titan2 logical partition layout observed from userspace fastbootd.

Phase 10 established that bootloader fastboot is not enough for this decision:

```text
IS_USERSPACE=no
SYSTEM_CURRENT_BYTES=0
```

The corrected Phase 10B fastbootd run produced:

```text
IS_USERSPACE=yes
SYSTEM_CURRENT_BYTES=756441088
```

The canonical N1B GSI system image is larger than the observed current system logical partition, so Phase 11 must collect and compare LP/super sizing before any flash-plan work is allowed.

## Titan2-specific deployment constraints

Phase 11 is intentionally not modeled like a generic Android phone flashing flow. It is bound to the Titan2 evidence collected during N0/N1 work:

```text
TITAN2_DYNAMIC_PARTITIONS=YES
TITAN2_VIRTUAL_AB=YES
TITAN2_FASTBOOTD_SUPPORTED=YES
TITAN2_DSU_AVAILABLE=NO
TITAN2_FASTBOOT_BOOT_SUPPORTED=NO
TITAN2_STANDALONE_RECOVERY_PARTITION=NO_OBSERVED
TITAN2_RECOVERY_LOCATION=vendor_boot_recovery_vendor_ramdisk
TITAN2_AVB_CHAINED_BOOT_VBMETA_SYSTEM_VBMETA_VENDOR=YES
TITAN2_BOOTLOADER_UNLOCKED_ORANGE_STATE_ALLOWED_FOR_INTERNAL_PREFLIGHT=YES
TITAN2_GSI_DEPLOYMENT_REQUIRES_FASTBOOTD_LP_CONTEXT=YES
```

Practical impact:

```text
DO_NOT_USE_DSU_FOR_N1B_GSI=YES
DO_NOT_USE_FASTBOOT_BOOT_FOR_N1B_GSI=YES
DO_NOT_ASSUME_STANDALONE_RECOVERY_FLASH_PATH=YES
DO_NOT_TREAT_SYSTEM_AS_FIXED_RAW_PARTITION=YES
DO_NOT_TREAT_BOOTLOADER_FASTBOOT_AS_SUFFICIENT_FOR_LP_SIZING=YES
USE_FASTBOOTD_READONLY_GETVAR_FOR_LP_SUPER_SIZING=YES
```

This differs from many regular Android-phone GSI instructions because Titan2 deployment planning must be driven from dynamic-partition and fastbootd evidence, not from DSU, `fastboot boot`, recovery-side assumptions, or a simple fixed-size raw `system` partition.

## Scope

Phase 11 is a plan-only sizing gate.

It may collect read-only fastbootd metadata and compare it against the registered N1B system artifact.

It must not flash, erase, format, unlock, change slots, reboot, resize logical partitions, delete logical partitions, create logical partitions, patch AVB, or claim production/public release readiness.

## Authorization boundary

```text
DEVICE=titan2
RELEASE=N1B
DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY_FASTBOOTD
FASTBOOT_COMMANDS_AUTHORIZED=YES_READ_ONLY_GETVAR_ONLY
ADB_COMMANDS_RUN=NO
REBOOT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
ERASE_AUTHORIZED=NO
UNLOCK_AUTHORIZED=NO
LP_MUTATION_AUTHORIZED=NO
AVB_MUTATION_AUTHORIZED=NO
PUBLIC_RELEASE=NO
PRODUCTION_SIGNING=NO
```

## Scripts

```text
build/titan2/collect-n1b-phase-11-fastbootd-lp-sizing.sh
build/titan2/qualify-n1b-phase-11-lp-super-sizing.sh
build/gates/n1b-phase-11-lp-super-sizing-contract.sh
```

## Phase 11A: fastbootd LP/super sizing collection

Phase 11A assumes the Titan2 is already in userspace fastbootd.

It may run only read-only fastboot commands such as:

```text
fastboot devices
fastboot getvar all
fastboot getvar current-slot
fastboot getvar is-userspace
fastboot getvar product
fastboot getvar slot-count
fastboot getvar partition-size:super
fastboot getvar partition-size:system
fastboot getvar partition-size:system_a
fastboot getvar partition-size:system_b
fastboot getvar partition-size:product_a
fastboot getvar partition-size:vendor_a
fastboot getvar partition-size:system_ext_a
fastboot getvar partition-size:odm_a
```

Phase 11A must not run:

```text
fastboot flash
fastboot erase
fastboot format
fastboot reboot
fastboot flashing
fastboot oem
fastboot set_active
fastboot --set-active
fastboot resize-logical-partition
fastboot delete-logical-partition
fastboot create-logical-partition
```

## Phase 11B: sizing qualification

Phase 11B is offline. It compares:

```text
required_system_bytes = N1B GSI system image size
system_current_bytes = current fastbootd-reported system logical partition size
super_bytes = fastbootd-reported super partition size when available
total_selected_dynamic_current_bytes = summed selected dynamic partition sizes from fastbootd getvars
super_headroom_estimate_bytes = super_bytes - total_selected_dynamic_current_bytes when computable
```

If the current system partition is smaller than the N1B image, Phase 11 must remain plan-only and report that an LP resize plan is required.

## Expected result for the observed Titan2 state

The observed fastbootd values show:

```text
SYSTEM_CURRENT_BYTES=756441088
N1B_GSI_SYSTEM_LOGICAL_BYTES=3180666880
```

Expected classification:

```text
N1B_PHASE_11_DIRECT_SYSTEM_SIZE_COMPATIBILITY=BLOCKED_NEEDS_LP_RESIZE_PLAN
N1B_PHASE_11_FLASH_PLAN_ALLOWED=NO
FLASH_AUTHORIZED=NO
```

Phase 11 may eventually report that a resize plan appears feasible if super headroom is sufficient, but it must not produce executable flash or resize commands. Any later LP resize plan must be a separate reviewed PR and a separate authorization boundary.

## Canonical post-merge flow

After this PR is merged, run from merged main only:

```bash
cd /srv/data/sable-build/sableos/repo

git fetch origin main
git switch main
git merge --ff-only origin/main

SABLEOS_DEVICE=titan2 \
SABLEOS_RELEASE_VERSION=N1B \
bash build/local-ci/run.sh full

TITAN_FASTBOOT_SERIAL="TITAN20000006073" \
bash build/titan2/collect-n1b-phase-11-fastbootd-lp-sizing.sh \
  --require-fastbootd
```

Then run the offline qualifier with the produced Phase 11 JSON and the canonical system image:

```bash
bash build/titan2/qualify-n1b-phase-11-lp-super-sizing.sh \
  --phase11-json <phase11-fastbootd-lp-sizing.json> \
  --system-image /srv/data/sable-build/workspaces/titan2-n1b/out_sable_t2_n1_sable_gsi/target/product/tdgsi_arm64_ab/system.img
```
