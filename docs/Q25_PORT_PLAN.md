# Zinwa Q25 SableOS port plan

Status: **planned / not yet supported**.

The Zinwa Q25 is the first planned non-Pixel SableOS target and the first planned physical-QWERTY / MediaTek validation platform.

The objective is not to fork SableOS for the Q25. The objective is to reuse the common Rust/services/security architecture while introducing a MediaTek hardware adapter and a keyboard-first interaction profile.

The port must preserve working LineageOS/AOSP/vendor capability by default. Cleanup or replacement work begins only after the known-good baseline is inventoried and only when the Sable replacement has a clear privacy, security, maintainability, performance or architectural benefit.

See `AOSP_CAPABILITY_POLICY.md`.

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

Q0 is not just a boot baseline. It is the capability inventory for every later Sable regression gate.

Physical acceptance should cover at minimum:

- boot/reboot stability
- display
- touch
- physical keyboard
- keyboard shortcuts / scan codes
- Wi-Fi
- Bluetooth and useful profiles
- audio playback/recording/routing
- camera
- NFC
- sensors
- GNSS/location where available
- USB / ADB / Fastboot
- storage
- suspend/resume
- charging/power
- SIM detection
- LTE / available 5G behavior
- packet data
- outbound/inbound voice
- SMS/MMS
- IMS/VoLTE
- media playback/codec behavior
- notifications
- update/rollback/recovery behavior

For each working capability, record the framework/vendor component or dependency that appears to provide it where practical. This becomes the dependency map used before later component removal.

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

#### Q1 capability-parity gate

Repeat the Q0 smoke inventory. Q1 fails if a working Q0 capability is silently lost because of the Rust/product integration.

### Q1.1 — init + dedicated SELinux domain

Add:

- init-managed startup
- dedicated `oxynoded` SELinux domain
- SELinux enforcing
- system/non-root UID where practical
- no radio/Binder/network/device permissions until a concrete service requires them

Repeat the Q0 hardware and telephony smoke tests.

#### Q1.1 security + capability gate

Q1.1 passes only if:

- the daemon starts automatically in the dedicated domain;
- SELinux remains enforcing;
- no broad privilege is granted merely to suppress AVCs;
- working Q0/Q1 capabilities remain functional;
- firmware/radio boundaries remain unchanged unless an explicitly reviewed update is required.

### Q2 — common Sable services and keyboard shell

Introduce the common Sable service APIs and the keyboard-first interaction profile.

Do not fork application semantics from the Pixel implementation. Differences should be expressed through capabilities and shell presentation.

The keyboard shell follows the same trust-boundary rule as the touch shell:

> The shell may observe and request; privileged services decide and execute.

A keyboard shortcut or settings screen does not receive direct hardware, encryption, modem, device-node or broad Binder privileges simply because it can request those operations.

#### Q2 capability gate

Replacing Lineage/AOSP presentation must not accidentally remove the useful lower-layer service.

Examples:

- replacing Settings presentation must preserve the underlying working Wi-Fi/Bluetooth/power/storage services;
- replacing home/SystemUI presentation must preserve notification, audio, Telecom and connectivity functionality used by the product;
- changing app UX for the square/QWERTY display must not require device-specific forks of common application semantics.

### Q3 — narrow MediaTek telephony broker

Only after the vendor stack is proven stable should Sable expose telephony through a narrow broker.

The broker should consume supported Android/vendor interfaces and present common Sable call/message/radio semantics. It must not talk directly to raw modem sockets or protocols.

Q3 must retain the Q0 carrier/IMS baseline unless a difference is explicitly understood and accepted.

## Shared vs device-specific code

Expected shared code:

- `oxynoded` core
- capability model
- application lifecycle
- notifications
- contacts/messages/calls models
- settings/storage/search
- media/application semantics
- security design
- keyboard-first interaction framework
- eventual common telephony API
- capability-preservation/compatibility policy

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

## Dependency and reuse policy

Initial bring-up should keep the working LineageOS/MediaTek hardware substrate intact rather than attempting to remove every Lineage component immediately.

Dependencies fall into three broad classes:

- **foundation**: keep and harden when they provide mature hardware/platform capability;
- **compatibility**: keep when useful, but isolate and grant only required data/privilege;
- **replacement candidate**: replace presentation/policy only after the underlying capability and dependency graph are understood.

Before removing a LineageOS/AOSP/vendor component, apply the preserve-before-remove gate in `AOSP_CAPABILITY_POLICY.md`.

A replacement is not approved simply because equivalent UI exists. It must preserve the working hardware/service capability or document an intentional product decision to remove it.

## Automotive / accessory compatibility

If the Q25 substrate already provides Android media, Bluetooth, Telecom, notification, navigation/location, USB/networking or other compatibility semantics useful to vehicles/accessories, preserve them through the Sable transition where they can be retained safely.

Optional proprietary/third-party projection components are not foundational dependencies. If later used, isolate them behind explicit Sable capabilities rather than widening the keyboard shell or common services.

## Q27 relationship

The Zinwa Q27 is currently an exploratory target, not an extension of this port by assumption.

Do not share Q25 device-specific code with Q27 until public Q27 kernel/device sources, partition layout, vendor interfaces and physical hardware prove the platforms compatible.

If suitable, Q27 should reuse:

- the common Sable core
- MediaTek abstractions that are genuinely common
- the keyboard-first interaction framework
- the same AOSP capability-preservation and security gates

while maintaining its own device acceptance and firmware boundary.

## Port acceptance rule

A Q25 build becomes a SableOS supported target only after:

1. the upstream baseline is reproducible;
2. the Q0 capability inventory and hardware/telephony acceptance are recorded;
3. Sable Rust integration is physically validated without capability regression;
4. SELinux remains enforcing with narrow domains;
5. firmware/vendor boundaries are documented;
6. keyboard-first interaction works without device-specific application forks;
7. retained AOSP/Lineage/vendor functionality passes the relevant parity checks;
8. removed/replaced components have passed the preserve-before-remove and replacement gates;
9. optional compatibility components are isolated rather than given broad shell/service privilege;
10. a safe restore path is proven.
