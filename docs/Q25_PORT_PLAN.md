# Zinwa Q25 SableOS port plan

Status: **optional low-level MediaTek / kernel research target; not yet supported**.

## 2026-09-10 strategy update

Q25 is no longer the assumed first non-Pixel purchase or required first MediaTek portability exercise.

After the Brax3/iodéOS review and Titan 2 GSI feasibility work, the preferred device order is now:

```text
Pixel 7 / panther
    -> canonical full-stack SableOS baseline

Unihertz Titan 2
    -> preferred interim N0 GSI/userspace/UI lab

Zinwa Q27
    -> preferred future full physical-QWERTY candidate if qualified

Zinwa Q25
    -> optional source-available MediaTek/kernel/device research platform
```

Q25 remains technically valuable because its community/Lineage kernel and device work enables lower-layer experimentation which may be unavailable on Titan 2. Acquisition should be driven by a specific need for that capability rather than treated as a product-roadmap prerequisite.

See `NON_PIXEL_DEVICE_ROADMAP.md`, `NON_PIXEL_MEDIATEK_ARCHITECTURE.md`, `TITAN2_GSI_PLAN.md`, and `BRAX3_IODEOS_REFERENCE.md`.

## Engineering value

If acquired, Q25 should be treated as **engineering capital** rather than a long-term product commitment.

Its strongest jobs are now:

1. provide a source-available MediaTek kernel/device laboratory;
2. validate kernel/KMI/module and device-tree work which a prebuilt-kernel target cannot expose;
3. test Android/vendor adapter boundaries outside Google's Pixel device family;
4. provide a second physical-QWERTY implementation for keyboard-first portability;
5. expose compact/square-display assumptions independently from Titan 2;
6. develop repeatable MediaTek bootloader, flashing, SELinux and hardware-acceptance methodology;
7. provide a known QWERTY reference against which Titan 2 and a future Q27 port can be compared.

A successful Q25 port may reduce Q27 risk by proving genuinely common abstractions, but Q25-specific vendor assumptions must not flow into Q27 without evidence.

## Upstream substrate

Primary reference tree:

- https://github.com/LineageOS/android_device_xelex_Q25
- current observed branch during planning: `lineage-23.2`

The LineageOS tree identifies a modern MediaTek Android device architecture including:

- arm64;
- MediaTek device/platform integration;
- kernel source dependency;
- A/B OTA support;
- dynamic partitions;
- AVB;
- boot image header version 4;
- `vendor_boot`;
- `system_ext`, `product`, `vendor`, `vendor_dlkm`, and `odm_dlkm` dynamic partitions;
- MediaTek hardware and vendor SELinux dependencies.

The device tree also uses a proprietary vendor layer and firmware extraction rather than pretending the hardware is fully open.

This source availability is the main reason Q25 remains useful even though Titan 2 is now preferred for interim UI/GSI work.

## Relationship to the non-Pixel support classes

Q25 can begin as N0 or N1 depending on the exact upstream build strategy, but its distinguishing value is the ability to investigate lower layers with source.

It does not become N2 merely because kernel source exists.

Production support would still require the complete device security/update model from `NON_PIXEL_MEDIATEK_ARCHITECTURE.md`, including:

- vendor/BSP lifecycle;
- firmware lifecycle;
- AVB/relock/rollback behavior;
- safe OTA/recovery;
- physical hardware parity;
- reproducible release signing;
- acceptable security support lifetime.

## Telephony architecture

The Q25 device manifest exposes standard Android radio services plus MediaTek-specific radio interfaces and vendor IMS integration.

This fits the SableOS telephony rule:

```text
Sable telephony semantics
        ↓
future narrow Rust broker where needed
        ↓
Android Radio / supported vendor interfaces
        ↓
MediaTek vendor RIL / IMS
        ↓
modem firmware
```

Do not implement the modem protocol directly and do not replace the vendor RIL/IMS stack during initial bring-up.

The Brax3 review reinforces that MediaTek telephony qualification must separately validate radio registration, packet data, voice, SMS/MMS, IMS, VoLTE and VoWiFi where applicable.

## Firmware boundary

The upstream extraction metadata includes separate MediaTek firmware images, including modem firmware.

Treat modem, NVRAM/calibration, bootloader and platform firmware as protected device state during bring-up.

Initial SableOS flashing must avoid casually replacing these partitions. Capture versions and preserve recovery paths before the first custom build is flashed.

Device identifiers and subscriber identifiers must remain in local logs only and must not be committed to the repository.

The Brax3 reference further requires firmware provenance to be tracked independently from Android platform and kernel provenance.

## Port stages

### Q0 — known-good upstream baseline

Build the supported LineageOS Q25 configuration without Sable modifications.

Q0 is not just a boot baseline. It is the capability inventory for every later Sable regression gate.

Physical acceptance should cover at minimum:

- boot/reboot stability;
- display;
- touch;
- physical keyboard;
- keyboard shortcuts / scan codes;
- trackpad/navigation behavior where exposed by the device;
- Wi-Fi;
- Bluetooth and useful profiles;
- audio playback/recording/routing;
- camera;
- NFC;
- sensors;
- GNSS/location where available;
- USB / ADB / Fastboot;
- storage;
- suspend/resume;
- charging/power;
- SIM detection;
- LTE / available radio behavior;
- packet data;
- outbound/inbound voice;
- SMS/MMS;
- IMS/VoLTE;
- media playback/codec behavior;
- notifications;
- update/rollback/recovery behavior;
- AVB/bootloader state;
- kernel/module baseline;
- vendor and firmware provenance.

For each working capability, record the framework/vendor component or dependency that appears to provide it where practical. This becomes the dependency map used before later component removal.

Freeze hashes and a target-files/recovery record before moving to Sable changes.

### Q1 — native Rust probe

Add the same minimal common `oxynoded` source used to validate Rust integration on Pixel references.

Requirements:

- native arm64 executable;
- installed into the appropriate system partition;
- manual probe only;
- no auto-start;
- no hardware privileges;
- no telephony permissions;
- no broad SELinux changes.

The purpose is to prove the common Rust userspace builds and runs on MediaTek without changing hardware behavior.

#### Q1 capability-parity gate

Repeat the Q0 smoke inventory. Q1 fails if a working Q0 capability is silently lost because of Rust/product integration.

### Q1.1 — init + dedicated SELinux domain

Add:

- init-managed startup;
- dedicated `oxynoded` SELinux domain;
- SELinux enforcing;
- system/non-root UID where practical;
- no radio/Binder/network/device permissions until a concrete service requires them.

Repeat the Q0 hardware and telephony smoke tests.

#### Q1.1 security + capability gate

Q1.1 passes only if:

- the daemon starts automatically in the dedicated domain;
- SELinux remains enforcing;
- no broad privilege is granted merely to suppress AVCs;
- working Q0/Q1 capabilities remain functional;
- firmware/radio boundaries remain unchanged unless an explicitly reviewed update is required.

### Q2 — common Sable services and keyboard shell

Introduce common Sable service APIs and the keyboard-first interaction profile.

Do not fork application semantics from the Pixel or Titan implementation. Differences should be expressed through capabilities and presentation.

The keyboard shell follows the same trust-boundary rule as the touch shell:

> The shell may observe and request; privileged services decide and execute.

A keyboard shortcut or settings screen does not receive direct hardware, encryption, modem, device-node or broad Binder privileges simply because it can request those operations.

#### Q2 portability objective

The Q25's compact/square display and physical input should deliberately find assumptions hidden by larger displays.

The desired result is a **generic keyboard-first interaction framework**, not a Q25-specific UI. Applications query form-factor/input capabilities rather than model names.

#### Q2 capability gate

Replacing Android presentation must not accidentally remove useful lower-layer services.

Examples:

- replacing Settings presentation must preserve underlying Wi-Fi/Bluetooth/power/storage services;
- replacing home/SystemUI presentation must preserve notification, audio, Telecom and connectivity functionality;
- changing app UX for a square/QWERTY display must not require device-specific forks of common application semantics.

### Q3 — narrow MediaTek telephony broker

Only after the vendor stack is proven stable should Sable expose telephony through a narrow broker where the common product requires one.

The broker consumes supported Android/vendor interfaces and presents common Sable call/message/radio semantics. It must not talk directly to raw modem sockets or protocols.

Q3 must retain the Q0 carrier/IMS baseline unless a difference is explicitly understood and accepted.

### Q4 — kernel/device research track

This is the area where Q25 now has unique strategic value compared with Titan 2.

Candidate work includes:

- exact kernel source/provenance sealing;
- KMI/module relationship analysis;
- device-tree and DTBO changes;
- kernel security backport experiments under `KERNEL_SECURITY_UPDATE_POLICY.md`;
- input/power/suspend driver investigation;
- comparison of source-built behavior with vendor-prebuilt MediaTek devices.

Q4 is never permission to perform unbounded kernel modifications. K1/K2/K3 classification and full build/runtime evidence still apply.

## Shared vs device-specific code

Expected shared code:

- `oxynoded` core;
- capability model;
- application lifecycle;
- notifications;
- contacts/messages/calls models;
- settings/storage/search;
- media/application semantics;
- security design;
- keyboard-first interaction framework;
- eventual common telephony API;
- capability-preservation/compatibility policy;
- non-Pixel vendor/firmware provenance tooling.

Expected Q25/MediaTek-specific code:

- device product/config integration;
- MediaTek HAL/HIDL/AIDL adapters;
- vendor policy integration;
- keyboard hardware mapping/configuration;
- display/form-factor capability profile;
- firmware/partition acceptance rules;
- Q25 kernel/device-tree changes.

Any code proposed for Titan 2 or Q27 reuse must first be shown to represent a real MediaTek or Sable abstraction rather than a Q25 implementation detail.

## Interaction profile

Q25 uses the generic keyboard-first shell described in `INTERACTION_PROFILES.md`.

The goal is not to squeeze a conventional slab-phone UI into a compact/square display. Physical QWERTY input is a primary navigation mechanism.

Applications query capabilities rather than the `Q25` model name.

Using Titan 2, Q25 and Q27 where available provides a stronger portability test than designing the keyboard profile against one device alone: common navigation and semantic behavior should survive different display sizes, keyboards and hardware generations.

## Dependency and reuse policy

Initial bring-up keeps the working LineageOS/MediaTek hardware substrate intact rather than attempting to remove every Lineage component immediately.

Dependencies remain classified as:

- **foundation**: keep and harden when they provide mature hardware/platform capability;
- **compatibility**: keep when useful, but isolate and grant only required data/privilege;
- **replacement candidate**: replace presentation/policy only after the underlying capability and dependency graph are understood.

Before removing a LineageOS/AOSP/vendor component, apply the preserve-before-remove gate in `AOSP_CAPABILITY_POLICY.md`.

Compatibility shims between Android and proprietary vendor binaries must follow the explicit record requirements in `NON_PIXEL_MEDIATEK_ARCHITECTURE.md`.

## Titan 2 relationship

Titan 2 and Q25 now have deliberately different roles:

```text
Titan 2
preferred interim purchase
N0 GSI/userspace/UI/5G lab
stock kernel/vendor/firmware initially
        │
        │ common UI/acceptance/tooling flows across
        ▼
Q25
optional source-available kernel/device laboratory
```

Titan 2 should be sufficient for most immediate SableStart and keyboard/square-display work. Q25 becomes valuable when opaque lower layers prevent the experiment we need to run.

## Q27 relationship

Q27 remains the preferred future modern physical-QWERTY candidate, subject to real source/BSP/physical-device acceptance.

Do not share Q25 device-specific code with Q27 until Q27 kernel/device sources or maintained prebuilt inputs, partition layout, vendor interfaces and physical hardware prove the platforms compatible.

Q27 must independently pass:

- kernel/device source or trusted maintained kernel-artifact availability;
- bootloader unlock and safe restore/recovery;
- partition/AVB/update-layout acceptance;
- vendor/HAL/VINTF inventory;
- radio/IMS/5G/camera/audio/suspend/power hardware parity;
- physical keyboard mapping and input behavior;
- firmware/vendor security-lifecycle review;
- production signing/relock/rollback requirements.

## Port acceptance rule

A Q25 build becomes a supported SableOS target only after:

1. the upstream baseline is reproducible;
2. the Q0 capability inventory and hardware/telephony acceptance are recorded;
3. Sable Rust integration is physically validated without capability regression;
4. SELinux remains enforcing with narrow domains;
5. kernel, firmware and vendor boundaries are documented and current enough for the claimed support class;
6. keyboard-first interaction works without device-specific application forks;
7. retained AOSP/Lineage/vendor functionality passes relevant parity checks;
8. removed/replaced components pass preserve-before-remove and replacement gates;
9. optional compatibility components are isolated rather than given broad shell/service privilege;
10. a safe restore path is proven;
11. the device satisfies N2 production requirements before any production-security claim.

Until these gates pass, Q25 remains a lab/reference candidate rather than a supported SableOS device.