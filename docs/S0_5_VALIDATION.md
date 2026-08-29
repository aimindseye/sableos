# S0.5 Validation — Android 14 Firmware Pairing and Physical Vanilla Baseline

Status: **PASS**

Target device: Google Pixel 4a (5G), codename `bramble`.

Baseline build:
- AOSP tag: `android-14.0.0_r28`
- Build ID: `UP1A.231105.001.B2`
- Android release: `14`
- Security patch reported by build: `2023-11-05`

## Pre-flash gates

Host/artifact preflight passed:
- AOSP-built Fastboot present
- Verified Android 14 factory bootloader image SHA256: `63df7c9a2957ffb6f648ea0973f1b2f3ada427a10bd1ac29ac8741a3c8ff3272`
- Verified Android 14 factory radio image SHA256: `b65fb8b2750228bc409c48136e2e3563338a1f9782bfbcc77dd5e20a0129c356`
- Verified factory inner image SHA256: `cd087c3d2778ff5fa5f59adefbe783e6fffa434c3dcc2f48b685cf6f1ed59288`
- Verified S0.3 AOSP image hashes
- Verified target-files SHA256: `86d69608d548cdcf20b713424b156b53a87c7d667099f251eb0589403eb80549`
- `device/sable` absent from vanilla source boundary

Physical Fastboot pre-flash gate passed:
- Product: `bramble`
- Bootloader unlocked
- Current slot: `a`
- Starting bootloader: `b5-0.4-8351080`
- Starting baseband: `g7250-00202-220422-B-8489468`

No device serial, IMEI, IMSI, ICCID, or phone number is recorded in this document.

## Firmware transition

Verified Android 14 firmware pair:
- Bootloader: `b5-0.6-10489838`
- Baseband: `g7250-00264-230619-B-10346159`

### Bootloader stage

Result:
- Bootloader flash returned success
- Reboot back to bootloader succeeded
- New bootloader version verified: `b5-0.6-10489838`
- Baseband remained unchanged during this stage

Gate: `S0_5_BOOTLOADER_WRITE_GATE=PASS`

### Radio stage

Result:
- Radio flash returned success
- Reboot back to bootloader succeeded
- Bootloader remained `b5-0.6-10489838`
- New baseband verified: `g7250-00264-230619-B-10346159`

Gate: `S0_5_RADIO_WRITE_GATE=PASS`

## Vanilla AOSP flash

Before the OS write, the following were revalidated:
- Product `bramble`
- Bootloader `b5-0.6-10489838`
- Baseband `g7250-00264-230619-B-10346159`
- Frozen S0.3 image hashes
- Target-files hash
- `device/sable` absent

The AOSP-built Fastboot `flashall -w` operation returned success and wrote the Android 14 payload.

Gate: `S0_5_AOSP_WRITE_GATE=PASS`

The first `flashall -w` output did not prove that all wipe targets were erased, so a separate explicit wipe was performed in bootloader Fastboot mode.

Bootloader Fastboot reported:
- `partition-type:userdata: raw`
- `partition-type:metadata: raw`

Explicit `fastboot -w` then produced successful erases for:
- `userdata`
- `metadata`

A missing `cache` partition was non-blocking for this device. Host-side formatting was not performed because Fastboot reported those partitions as `raw`; the erase itself completed successfully.

Clean-data gate: **PASS**

## Physical first boot

The device booted successfully into the regular vanilla AOSP Android UI with no observed boot loop.

Physical first-boot observations:
- Android UI reached
- Display path functional
- Touch/UI path functional

## Post-flash identity and security

ADB post-flash identity gate:

```text
S0_5_BOOT_COMPLETED=PASS
POSTFLASH_PRODUCT=bramble
POSTFLASH_BUILD_ID=UP1A.231105.001.B2
POSTFLASH_ANDROID_RELEASE=14
POSTFLASH_SECURITY_PATCH=2023-11-05
POSTFLASH_BOOTLOADER=b5-0.6-10489838
POSTFLASH_BASEBAND=g7250-00264-230619-B-10346159
POSTFLASH_SLOT_SUFFIX=_a
POSTFLASH_SELINUX=Enforcing
S0_5_POSTFLASH_PRODUCT=PASS
S0_5_POSTFLASH_BUILD_ID=PASS
S0_5_POSTFLASH_BOOTLOADER=PASS
S0_5_POSTFLASH_BASEBAND=PASS
S0_5_POSTFLASH_SELINUX=PASS
S0_5_POSTFLASH_IDENTITY_GATE=PASS
```

## Conclusion

S0.5 establishes a physically booting vanilla Android 14 bramble baseline with the matching official Android 14 bootloader/baseband firmware pair, a clean data state, the expected build identity, and SELinux enforcing.

This does **not** yet prove full hardware capability parity. Telephony, Wi-Fi, Bluetooth, audio, camera, suspend/resume, sensors, USB behavior, and other platform capabilities remain subject to the next physical capability-validation gate before SableOS reintegration begins.

The reported `2023-11-05` security patch level reflects the Android 14 baseline build and must not be interpreted as current production security coverage for this EOL device.
