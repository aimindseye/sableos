# SableOS non-Pixel device roadmap

Status: **planning roadmap; no non-Pixel device is currently a supported production target**.

This document refines the device-ordering portion of `ROADMAP.md` with the September 2026 Brax3/iodéOS review and current hardware strategy.

## Priority order

```text
1. Pixel 7 / panther
   canonical full-stack SableOS development target

2. Unihertz Titan 2
   preferred interim non-Pixel N0 GSI/userspace lab

3. Zinwa Q27
   preferred future full physical-QWERTY candidate after hardware ships and qualifies

4. Zinwa Q25
   optional low-level MediaTek/kernel research target when its source availability is specifically needed
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

## Titan 2 second: interim development lab

Titan 2 is preferred over Q25 as the immediate non-Pixel purchase when the goal is UI and portability development rather than low-level kernel research.

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

See `TITAN2_GSI_PLAN.md`.

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

## Q25: optional engineering-capital target

Q25 remains valuable because public/community kernel and device work enables lower-layer experiments which may be impossible on Titan 2.

Use Q25 when the explicit goal is:

- MediaTek kernel/KMI/module experimentation;
- device-tree and vendor integration work with available source;
- low-level power/input/driver research;
- comparison against a second physical-QWERTY implementation.

Q25 is no longer a required precursor to Q27 and no longer the preferred interim purchase when Titan 2 better serves the UI/5G/form-factor roadmap.

See `Q25_PORT_PLAN.md`.

## Promotion model

Non-Pixel devices move through explicit assurance classes:

```text
N0  GSI/userspace development lab
 -> N1 integrated vendor/BSP device port
 -> N2 production-qualified SableOS target
```

Promotion is evidence-driven. It is not implied by boot success, community ROM availability or purchase intent.

See `NON_PIXEL_MEDIATEK_ARCHITECTURE.md`.

## Reusable work expected from Titan 2

Titan 2 development should produce reusable, device-independent assets for Q27 and later devices:

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

## Release implication

Only N2 devices may be presented as production-qualified SableOS targets.

N0/N1 artifacts must state their assurance class and limitations clearly. In particular, a GSI using the stock device kernel/vendor/firmware must not imply that SableOS owns or provides the kernel/vendor/firmware security-update lifecycle.

## External reference

The September 2026 Brax3/iodéOS review materially informed this roadmap. See `BRAX3_IODEOS_REFERENCE.md` for the exact reviewed repository revisions and lessons.