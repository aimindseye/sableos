# Zinwa Q25 SableOS port plan

Status: **planned / not yet supported**.

The Zinwa Q25 is the first planned non-Pixel SableOS target and the first planned physical-QWERTY / MediaTek validation platform.

The objective is not to fork SableOS for the Q25. The objective is to reuse the common Rust/services/security architecture while introducing a MediaTek hardware adapter and a keyboard-first interaction profile.

## Upstream substrate

Primary reference tree:

- https://github.com/LineageOS/android_device_xelex_Q25
- current observed default branch during planning: `lineage-23.2`

The LineageOS tree identifies:

- architecture: arm64
- platform: MediaTek `mt6789`
- kernel source dependency: `kernel/xelex/mt6789`
- A/B OTA support
- dynamic partitions
- AVB
- boot image header version 4
- `vendor_boot`
- `system_ext`, `product`, `vendor`, `vendor_dlkm`, and `odm_dlkm` dynamic partitions
- MediaTek hardware and vendor SELinux dependencies

The device tree also uses a proprietary vendor layer and firmware extraction rather than pretending the hardware is fully open.

## Telephony architecture

The Q25 device manifest exposes standard Android Radio HIDL services including `android.hardware.radio` 1.2/1.6 and `android.hardware.radio.config`, plus MediaTek-specific radio interfaces such as `vendor.mediatek.hardware.mtkradioex`.

The device makefile enables the vendor RIL service and includes MediaTek IMS integration.

This fits the SableOS telephony rule:

```text
Sable telephony semantics
        ↓
future narrow Rust broker
        ↓
Android Radio HIDL / supported vendor interfaces
        ↓
MediaTek vendor RIL / IMS
        ↓
modem firmware
```

Do not implement the modem protocol directly and do not replace the vendor RIL/IMS stack during initial bring-up.

## Firmware boundary

The upstream extraction metadata includes separate MediaTek firmware images, including modem firmware.

Treat modem, NVRAM/calibration, bootloader and platform firmware as protected device state during bring-up.

Initial SableOS flashing must avoid casually replacing these partitions. Capture versions and preserve recovery paths before the first custom build is flashed.

Device identifiers and subscriber identifiers must remain in local logs only and must not be committed to the repository.

## Port stages

### Q0 — known-good upstream baseline

Build the supported LineageOS Q25 configuration without Sable modifications.

Physical acceptance should cover at minimum:

- boot stability
- display
- touch
- physical keyboard
- keyboard shortcuts / scan codes
- Wi-Fi
- Bluetooth
- audio
- camera
- NFC
- sensors
- USB / ADB / Fastboot
- suspend/resume
- charging
- SIM detection
- LTE / available 5G behavior
- packet data
- outbound/inbound voice
- SMS/MMS
- IMS/VoLTE

Freeze hashes and a target-files/recovery record before moving to Sable changes.

### Q1 — native Rust probe

Add the same minimal common `oxynoded` source used to validate Rust integration on bramble.

Requirements:

- native arm64 executable
- installed into the appropriate system partition
- manual probe only
- no auto-start
- no hardware privileges
- no telephony permissions
- no broad SELinux changes

The purpose is to prove the common Rust userspace builds and runs on MediaTek without changing hardware behavior.

### Q1.1 — init + dedicated SELinux domain

Add:

- init-managed startup
- dedicated `oxynoded` SELinux domain
- SELinux enforcing
- system/non-root UID where practical
- no radio/Binder/network/device permissions until a concrete service requires them

Repeat the Q0 hardware and telephony smoke tests.

### Q2 — common Sable services and keyboard shell

Introduce the common Sable service APIs and the keyboard-first interaction profile.

Do not fork application semantics from the Pixel implementation. Differences should be expressed through capabilities and shell presentation.

### Q3 — narrow MediaTek telephony broker

Only after the vendor stack is proven stable should Sable expose telephony through a narrow broker.

The broker should consume supported Android/vendor interfaces and present common Sable call/message/radio semantics. It must not talk directly to raw modem sockets or protocols.

## Shared vs device-specific code

Expected shared code:

- `oxynoded` core
- capability model
- application lifecycle
- notifications
- contacts/messages/calls models
- settings/storage/search
- security design
- keyboard-first interaction framework
- eventual common telephony API

Expected Q25/MediaTek-specific code:

- device product/config integration
- MediaTek HAL/HIDL/AIDL adapters
- vendor policy integration
- keyboard hardware mapping/configuration
- display/form-factor capability profile
- firmware/partition acceptance rules

## Interaction profile

The Q25 should use the generic keyboard-first shell described in `INTERACTION_PROFILES.md`.

The goal is not to squeeze a conventional slab-phone UI into a compact/square display. Physical QWERTY input is a primary navigation mechanism.

Applications should query capabilities rather than the `Q25` model name.

## Dependency policy

Initial bring-up should keep the working LineageOS/MediaTek hardware substrate intact rather than attempting to remove every Lineage component immediately.

Once Q0/Q1/Q1.1 are physically stable, dependencies can be reviewed individually and replaced only when SableOS has an equivalent with a clear security, maintenance or efficiency benefit.

## Q27 relationship

The Zinwa Q27 is currently an exploratory target, not an extension of this port by assumption.

Do not share Q25 device-specific code with Q27 until public Q27 kernel/device sources, partition layout, vendor interfaces and physical hardware prove the platforms compatible.

If suitable, Q27 should reuse:

- the common Sable core
- MediaTek abstractions that are genuinely common
- the keyboard-first interaction framework

while maintaining its own device acceptance and firmware boundary.

## Port acceptance rule

A Q25 build becomes a SableOS supported target only after:

1. the upstream baseline is reproducible;
2. hardware/telephony acceptance is recorded;
3. Sable Rust integration is physically validated;
4. SELinux remains enforcing with narrow domains;
5. firmware/vendor boundaries are documented;
6. keyboard-first interaction works without device-specific application forks;
7. a safe restore path is proven.