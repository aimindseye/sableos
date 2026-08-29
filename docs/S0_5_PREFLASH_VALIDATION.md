# S0.5 Fastboot pre-flash validation

Status: **PASS**

## Purpose

S0.5 verifies both the host-side artifacts and the physical Fastboot state before any Android 14 firmware or OS partition is written to the reference `bramble` device.

This gate is intentionally read-only with respect to device partitions.

## Host/artifact evidence

Observed:

- AOSP-built Fastboot present: `/srv/data/aosp_bramble_workspace/out_s0/host/linux-x86/bin/fastboot`
- Fastboot version: `34.0.4-eng.mindse.20260829.101937`
- `S0_5_AOSP_FASTBOOT_PRESENT=PASS`
- `S0_5_FACTORY_EVIDENCE=PASS`
- verified Android 14 bootloader image SHA256: `63df7c9a2957ffb6f648ea0973f1b2f3ada427a10bd1ac29ac8741a3c8ff3272`
- verified Android 14 radio image SHA256: `b65fb8b2750228bc409c48136e2e3563338a1f9782bfbcc77dd5e20a0129c356`
- verified matching Google factory inner image SHA256: `cd087c3d2778ff5fa5f59adefbe783e6fffa434c3dcc2f48b685cf6f1ed59288`
- verified S0.3 AOSP `boot.img`, `vendor_boot.img`, `vbmeta.img`, target-files package and target-files ZIP integrity
- `S0_5_VANILLA_SABLE_ABSENT=PASS`
- `S0_5_HOST_PREFLIGHT=PASS`

## Physical Fastboot evidence

Observed on the reference device:

- product: `bramble`
- current slot: `a`
- unlocked: `yes`
- current bootloader: `b5-0.4-8351080`
- current baseband: `g7250-00202-220422-B-8489468`

Gates:

- `S0_5_FASTBOOT_SINGLE_DEVICE=PASS`
- `S0_5_FASTBOOT_PRODUCT=PASS`
- `S0_5_FASTBOOT_UNLOCKED=PASS`
- `S0_5_FASTBOOT_SLOT=PASS`
- `S0_5_CURRENT_BOOTLOADER_CONFIRMED=PASS`
- `S0_5_CURRENT_BASEBAND_CONFIRMED=PASS`
- `S0_5_NO_PARTITION_WRITE=PASS`
- `S0_5_FASTBOOT_PREFLASH_GATE=PASS`

## Required Android 14 firmware pairing

From the verified Google `UP1A.231105.001.B2` factory package:

- bootloader: `b5-0.6-10489838`
- baseband: `g7250-00264-230619-B-10346159`

The current Android 12-era bootloader and baseband therefore must be updated before the first Android 14 physical baseline flash.

## Write-stage policy

The write stage must remain checkpointed:

1. verify and flash only the matching bootloader;
2. reboot to bootloader and verify the new bootloader version;
3. verify and flash only the matching radio/baseband;
4. reboot to bootloader and verify the new baseband version;
5. reverify product, unlock state, bootloader and radio;
6. flash the S0.3 vanilla AOSP Android 14 system with a data wipe;
7. perform first-boot and physical capability validation.

Do not use Google's full `flash-all.sh` as the Sable baseline payload. The Google package is used to source the matching bootloader/radio firmware; the operating-system payload remains the independently built S0.3 vanilla AOSP images.

Do not restore `device/sable` until the vanilla Android 14 physical baseline passes.
