# SableOS non-Pixel device roadmap

Status: **planning roadmap; no non-Pixel device is currently a supported production target**.

This document refines the device-ordering portion of `ROADMAP.md` with the September 2026 Brax3/iodéOS review and current hardware strategy.

## Priority order

```text
1. Pixel 7 / panther
   canonical full-stack SableOS development target

2. Unihertz Titan 2 family
   2A. Titan 2 — large square/dual-screen keyboard-first N0 GSI lab
   2B. Titan 2 Elite — compact near-square keyboard-first N0 GSI candidate

3. Zinwa Q27
   preferred future integrated/full physical-QWERTY candidate after shipped hardware qualifies
```

The ordering is about current SableOS engineering value, not a permanent product ranking.

## Panther first

Pixel 7 remains the authoritative target for:

- GrapheneOS-derived Android 17 platform integration;
- SableStart product composition;
- build/release validation methodology;
- AVB/signing architecture;
- Sable service and product trust boundaries;
- the canonical touch-first reference implementation.

Non-Pixel work must not destabilize or redefine the Panther baseline.

## Titan 2 family second: two complementary N0 labs

SableOS now plans for both the Unihertz Titan 2 and Titan 2 Elite. They share the
keyboard-first portability role but exercise materially different geometry,
camera and vendor behavior.

```text
Titan 2
  Dimensity 7300
  1440x1440 main LCD + rear display
  50MP main + 8MP telephoto
  community GSI boot evidence exists

Titan 2 Elite
  Dimensity 7400
  1080x1200 AMOLED
  50MP main + 50MP telephoto
  Android 16
  GSI candidate pending local bootloader/recovery/Treble proof
```

Titan 2-family work is the active non-Pixel investment path for UI, physical-keyboard and GSI/userspace portability.

Primary role:

```text
SABLEOS_NON_PIXEL_CLASS=N0_GSI_USERSPACE_LAB
```

Why it is useful:

- larger physical-QWERTY form factor;
- square/unusual display useful for SableStart and responsive-layout testing;
- 5G-capable MediaTek platform useful for radio/IMS acceptance methodology;
- GSI feasibility already demonstrated by community work;
- useful bridge while waiting for Q27.

Titan 2 is not assumed to have public kernel source or full SableOS security ownership. Initial development reuses stock kernel/vendor/firmware and is explicitly classified as development-only.

Titan 2 UI qualification is explicitly **keyboard-first**: physical QWERTY is the primary navigation/input path and touch is secondary. The product must not be implemented as a Panther touch layout with optional keyboard shortcuts layered on top. See `TITAN2_KEYBOARD_FIRST_REFERENCE.md` and `INTERACTION_PROFILES.md`.

See `TITAN2_GSI_PLAN.md`.

Read-only T0 stock/device inventory may begin independently for Titan 2 and Titan 2 Elite whenever each device is available. GSI mutation/flash remains gated on the R9 Panther source-bound fresh build and physical Pixel 7 acceptance.

Titan 2 GSI feasibility is already demonstrated by community LineageOS/GSI work.
Titan 2 Elite is treated as **GSI-capable candidate, not yet locally proven**:
Android 16/Treble makes the architecture appropriate, but SableOS still requires
physical proof of bootloader unlock, fastboot/fastbootd, dynamic partitions,
vbmeta/AVB behavior, stock recovery artifacts and a successful generic GSI boot
before declaring `TITAN2_ELITE_GSI=PASS`.

Both remain N0 development targets, not production-security targets.

## Q27: preferred future full QWERTY candidate

Q27 should not be treated as supported until real shipped hardware is available and the following are verified:

- kernel/device source or trustworthy maintained prebuilt-kernel path;
- vendor/BSP availability and maintenance;
- bootloader unlock and stock recovery;
- AVB/custom-key/relock behavior;
- partition and A/B/update topology;
- modem/IMS/5G behavior;
- camera/audio/NFC/GNSS/sensor behavior;
- physical keyboard and pointer behavior;
- suspend/power/thermal behavior;
- current firmware and security lifecycle.

Brax3 shows that OEM cooperation with current BSP/firmware binaries can enable a serious integrated Android port even without public kernel source, but N2 production support still requires SableOS security/release gates.

## Shared keyboard-device tools

Titan 2, Titan 2 Elite and Q27 should share a common Sable Tools application/semantic layer for device diagnostics and keyboard-first utilities.

Reference direction:

- bb10root/bb10tools at revision 68d2e42a471b46b53ff5567edac4293ef0f3d5d6 is retained as a GPL-3.0 BB10/QNX engineering-tooling reference;
- its useful product lesson is compact on-device diagnostics/service tooling;
- production SableOS must not inherit its kernel patching, arbitrary memory/NVRAM writes, security bypasses or unauthenticated service mechanisms.

Initial reusable Sable Tools targets include keyboard/input inspection, build/device reports, radio/IMS status, storage/partition summaries, application/process evidence, logs/report export and safe file/share workflows.

See KEYBOARD_FIRST_SABLE_TOOLS_REFERENCE.md.

## Promotion model

Non-Pixel devices move through explicit assurance classes:

```text
N0  GSI/userspace development lab
 -> N1 integrated vendor/BSP device port
 -> N2 production-qualified SableOS target
```

Promotion is evidence-driven. It is not implied by boot success, community ROM availability or purchase intent.

See `NON_PIXEL_MEDIATEK_ARCHITECTURE.md`.

## Reusable work expected from the Titan 2 family

Titan 2 and Titan 2 Elite development should produce reusable, device-independent assets for Q27 and later devices:

- capability-driven SableStart layout/navigation;
- physical-keyboard focus/shortcut semantics;
- square/compact display classes;
- pointer/touch/keyboard coexistence;
- MediaTek VINTF/vendor inventory tooling;
- telephony/IMS/5G acceptance suites;
- firmware/partition provenance schema;
- recovery/flash guard methodology;
- explicit ABI-shim records where compatibility work is necessary.

Device-specific kernel, firmware, HAL and input details do not automatically flow from Titan 2 to Q27.

## Shared camera enhancement direction

Titan 2, Titan 2 Elite and Q27 are now part of one Sable camera-quality workstream.
The implementation baseline should be the open-source GrapheneOS Camera/CameraX
architecture already compatible with SableOS licensing and security goals.
Community GCam ports are behavioral/reference inputs only; SableOS must not
redistribute proprietary Google Camera code or opaque modified APKs.

Priority lessons from the Titan 2 Elite community port review:

- design the viewfinder/control layout for square and near-square displays;
- validate tap-to-focus coordinate transforms rather than assuming a slab-phone viewport;
- request a high-resolution preview where the HAL supports it;
- expose 1:1 capture cleanly on square-display devices;
- treat stabilization as a per-device/capability decision rather than forcing a mode that warps video;
- tune color/skin-tone behavior against controlled scenes;
- enumerate logical, physical and SYSTEM_CAMERA devices explicitly;
- keep QR/barcode scanning local and user-initiated.

The Titan 2 Elite community report says its physical 2x camera is advertised as
`SYSTEM_CAMERA`, making it unavailable to ordinary third-party camera apps.
Android supports such cameras for system/privileged apps holding
`android.permission.SYSTEM_CAMERA`. Because SableOS controls the system image,
a narrowly privileged Sable Camera may be able to use that telephoto camera
without rooting, but this is **not accepted until physical Camera2/HAL evidence
proves it**.

See `CAMERA_ENHANCEMENT_ROADMAP.md`.

## Release implication

Only N2 devices may be presented as production-qualified SableOS targets.

N0/N1 artifacts must state their assurance class and limitations clearly. In particular, a GSI using the stock device kernel/vendor/firmware must not imply that SableOS owns or provides the kernel/vendor/firmware security-update lifecycle.

## External reference

The September 2026 Brax3/iodéOS review materially informed this roadmap. See `BRAX3_IODEOS_REFERENCE.md` for the exact reviewed repository revisions and lessons.