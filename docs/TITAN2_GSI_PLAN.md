# Unihertz Titan 2 SableOS GSI development plan

Status: **preferred interim non-Pixel development candidate; keyboard-first N0 portability work queued after Panther R9 physical acceptance; not yet validated or supported**.

The Titan 2 is the preferred interim physical-QWERTY development target after the Pixel 7 / Panther baseline is closed. Its initial role is a **development GSI/userspace lab**, not a production-security SableOS target.

The goal is to accelerate SableStart, square-display, keyboard/pointer and Android/MediaTek portability work while waiting for the Zinwa Q27 hardware and support situation to mature.

This plan is governed by `NON_PIXEL_MEDIATEK_ARCHITECTURE.md`, `AOSP_CAPABILITY_POLICY.md`, `SECURITY_MODEL.md`, `RELEASE_VALIDATION.md` and the project authorization/evidence methodology.

## Current concurrency rule

Titan 2 availability does not change the Panther-first release gate. Read-only stock/device inventory may begin whenever hardware is available.

Two work classes are deliberately separated:

```text
T0 read-only stock/device inventory
    MAY START IMMEDIATELY ON ARRIVAL

T1/T2 GSI build, bootloader mutation or flashing
    BLOCKED UNTIL PANTHER FINAL UI CLOSURE
```

T0 is observational and may run in parallel with the remaining Pixel UI source/integration work. It should capture exact stock identity, display/input geometry, keyboard devices/keylayout, Treble/VINTF/VNDK, partition topology, bootloader/unlock behavior, stock restore artifacts, kernel/modules, vendor/ODM/HALs, modem/IMS and firmware.

Before any Titan GSI mutation/flash, require:

```text
R9_FRESH_FULL_BUILD=PASS
R9_FULL_BUILD_CAUSALITY=PASS_ABSENT_OUT_TO_FRESH_TARGET_FILES
R9_PIXEL7_PHYSICAL_ACCEPTANCE=PASS
```

This ensures Titan evaluates the same closed Sable UI/application architecture rather than becoming a parallel fork.

## Keyboard-first product requirement

Titan 2 is not a touch-first SableOS UI with keyboard shortcuts added afterward. Its primary interaction profile is keyboard-first:

```text
navigation.primary=keyboard
navigation.secondary=touch
```

The physical keyboard must be sufficient for core HOME navigation, app/search launch, focus traversal, Settings and major Sable first-party surfaces. Touch remains supported as a secondary input path.

Reference review:

- `palsoftware/pastiera` — physical-keyboard IME/modifier/navigation reference;
- `katoaapps/openminilaunch` — keyboard-first launcher/type-to-search reference;
- `sriharshaKanukuntla/TypeQ25` — Q25/Titan physical-keyboard mapping/nav reference;
- `nozerorma/q25toolbox` — keylayout/scancode/device-behavior forensic reference.

Exact reviewed revisions and licensing constraints are recorded in `TITAN2_KEYBOARD_FIRST_REFERENCE.md`.

The first Titan launcher acceptance must prove printable-key type-to-search from HOME with the initial character preserved, visible directional focus, hardware-only navigation through the main launcher flow, and no forced soft-keyboard popup when a physical keyboard is active.

## Strategic role

The intended sequence is:

```text
Pixel 7 / panther
    -> finish canonical SableOS Android 17 product/security/build architecture
    -> close SableStart and core product integration

Titan 2
    -> development GSI/userspace lab
    -> physical QWERTY and square-display UI work
    -> MediaTek/Treble compatibility research
    -> 5G/IMS compatibility inventory
    -> no full-security-support claim

Zinwa Q27
    -> evaluate shipped hardware
    -> source/BSP/firmware/bootloader/AVB acceptance
    -> preferred future full physical-QWERTY candidate if qualified
```

Q25 remains optional for low-level MediaTek/kernel work when its available source provides specific engineering value.

## Why Titan 2 is useful

Titan 2 offers a larger physical-QWERTY form factor and 5G-capable MediaTek platform suitable for exercising SableOS interaction assumptions which a Pixel slab cannot expose.

Expected development value:

- SableStart on a square/unusual display;
- physical keyboard focus/navigation;
- modifier/shortcut behavior;
- keyboard repeat and text-entry behavior;
- pointer/trackpad interaction where exposed;
- responsive Compose or later Sable UI layout work;
- type-to-search and command workflows;
- application/task switching on constrained display geometry;
- Android framework portability outside Pixel;
- Treble/GSI compatibility;
- MediaTek vendor-interface inventory;
- 5G/radio/IMS validation methodology.

Existing community work demonstrates that Android GSIs can boot on Titan 2 with device-specific compatibility work. This is feasibility evidence only, not SableOS support evidence.

## Initial assurance classification

```text
SABLEOS_ASSURANCE_STAGE=DEVELOPMENT
SABLEOS_NON_PIXEL_CLASS=N0_GSI_USERSPACE_LAB
SABLEOS_PRODUCTION_SECURITY_CLAIM=NO
```

Expected initial ownership:

```text
SableOS/AOSP system userspace
+
stock Titan 2 kernel
+
stock vendor/ODM
+
stock firmware/bootloader
```

The initial GSI must be described accurately. It is not equivalent to a fully supported GrapheneOS-derived device port and does not inherit device-specific GrapheneOS kernel/firmware security properties.

## T0 — documentation and stock-artifact qualification

No flashing or device mutation is authorized by this planning document.

Before producing a device-specific GSI plan, collect authoritative/public information and a sealed stock firmware set where lawfully available.

Inventory at minimum:

- exact product/model identifiers;
- SoC and architecture;
- stock Android build and security patch levels;
- Treble/VNDK/VINTF state;
- system-as-root/dynamic partition layout;
- `super` metadata;
- A/B or non-A/B update model;
- `boot`, `init_boot`, `vendor_boot`, `dtbo` layout;
- `vendor`, `odm`, `vendor_dlkm`, `odm_dlkm` presence;
- stock vbmeta chain and AVB algorithm/rollback information;
- bootloader unlock path and warnings;
- stock restore/recovery path;
- kernel release and GKI/KMI information if observable;
- stock kernel modules;
- vendor and ODM manifests/matrices;
- modem/IMS packages and services;
- firmware partitions and versions;
- keyboard/input devices and keylayout files;
- rear-display and device-specific services where applicable.

T0 output is read-only evidence and an exact stock-artifact manifest.

## T1 — generic GSI compatibility baseline

Before adding SableOS components, use a known generic AOSP-compatible GSI to establish what works with the stock Titan 2 kernel/vendor stack.

The purpose is to separate:

```text
stock vendor limitation
from
SableOS regression
```

Minimum baseline matrix:

- boot/reboot;
- display/touch;
- physical keyboard;
- pointer/trackpad behavior;
- Wi-Fi;
- Bluetooth;
- audio;
- camera;
- NFC;
- GNSS/location;
- sensors;
- fingerprint;
- USB/ADB;
- charging;
- suspend/resume;
- SIM detection;
- mobile data;
- LTE/5G registration;
- inbound/outbound voice;
- SMS;
- IMS/VoLTE;
- VoWiFi where supported by stock/carrier;
- rear display and device-specific controls where practical.

Failures are classified, not hidden by broad permissive changes.

## T2 — Sable GSI build definition

Create a versioned GSI build profile from the canonical SableOS Android platform only after Panther product architecture is stable enough to reuse.

Initial Sable additions should be deliberately narrow:

- SableStart;
- common unprivileged Sable applications;
- common semantic client libraries which do not require unsupported device privilege;
- interaction-profile capability detection;
- test/diagnostic instrumentation authorized for development.

Do not initially add:

- custom kernel;
- raw MediaTek modem access;
- device-specific privileged super-daemon;
- broad SELinux bypasses;
- firmware replacement;
- production signing/security claims.

## T3 — SableStart / interaction acceptance

Titan 2's first major product purpose is UI qualification.

Validate:

- HOME rendering at the physical display geometry;
- app enumeration and launch;
- focus traversal without touch;
- keyboard shortcut dispatch;
- type-to-search;
- modifier and repeat semantics;
- touch/keyboard coexistence;
- pointer behavior where present;
- task switching and back navigation;
- screen rotation/presentation policy;
- IME behavior;
- accessibility/focus visibility;
- app layouts across square and non-square activities;
- no device-name forks in common Sable application semantics.

A Titan-specific adapter may report capabilities, but the common UI consumes capability values rather than checking `Titan 2` directly.

## T4 — MediaTek vendor/BSP compatibility inventory

Use the Brax3 reference as a checklist, not as copy-paste source.

Inventory:

- AIDL/HIDL HAL versions;
- MediaTek vendor extensions;
- system/vendor/system_ext cross-partition dependencies;
- radio/IMS framework components;
- proprietary privileged APKs;
- vendor services and init definitions;
- graphics/audio/camera libraries;
- KeyMint/Gatekeeper/TEE implementation;
- firmware and NVRAM/calibration dependencies.

If newer Sable/Android userspace requires ABI compatibility shims, each shim receives an explicit record as required by `NON_PIXEL_MEDIATEK_ARCHITECTURE.md`.

## T5 — telephony and 5G qualification

5G hardware support is a reason to use Titan 2 as a lab, but it is not assumed to work merely because the device registers on a network.

Test separately:

```text
SIM
LTE registration
5G registration
packet data
voice
SMS/MMS
IMS registration
VoLTE
VoWiFi where applicable
carrier configuration
handover/stability
```

Do not replace the vendor modem/RIL/IMS stack during initial bring-up.

No routine test places a live emergency-services call.

## T6 — recovery / mutation qualification

Before repeated development flashing, prove a safe and repeatable recovery path.

Required evidence before higher-risk device mutation:

- exact stock firmware recovery package;
- exact partition map;
- known bootloader unlock state;
- backup/preservation plan for calibration/NVRAM-sensitive partitions;
- ability to return to a known-good stock boot;
- dynamic-partition resize/flash method understood;
- AVB behavior understood;
- explicit wipe/non-wipe effects understood.

Unihertz warnings about unofficial flashing are treated as a real hardware-risk input. No destructive or low-level flash procedure should be improvised from unrelated MediaTek devices.

## T7 — possible integrated N1 port research

Only after the GSI lab is useful and the stock-device evidence is complete should SableOS evaluate promotion from N0 to an integrated N1 device port.

Possible inputs:

- stock prebuilt kernel and modules;
- extracted/proven vendor userspace;
- device-specific VINTF/init/sepolicy;
- controlled compatibility shims;
- OTA/recovery integration;
- OEM-supplied firmware updates.

The Brax3/iodéOS implementation proves this model can be practical without public kernel source, but it does not make N1 or N2 automatic.

## N2 production-support gate

Titan 2 becomes a production-supported SableOS target only if the complete device security/update model is acceptable.

In addition to functional parity require:

- timely kernel security-update path;
- timely vendor/BSP updates;
- modem/TEE/bootloader firmware maintenance;
- production AVB signing and acceptable locked/custom-key behavior;
- rollback protection;
- safe A/B/update/recovery semantics where applicable;
- Sable release reproducibility;
- supported security lifetime;
- hardware-security capability classification.

If those cannot be satisfied, Titan 2 can remain an extremely useful development GSI target without being mislabeled as production-secure SableOS.

## Output and repository structure if activated

Do not create these paths merely because this plan exists. If T0/T1 justify implementation, preferred ownership is conceptually:

```text
device/sable/titan2/                    # only for integrated N1 work
vendor/sable/titan2/                    # only after legal/provenance review
vendor/sable/titan2-firmware/           # if Sable packages approved firmware
manifest/snippets/sable-titan2.xml
release-tools/titan2/
```

A pure GSI build may require none of the full device-tree paths initially.

## Relationship to Panther

Panther remains the authoritative full-stack SableOS development target.

Titan 2 work must not interrupt or redefine Panther architecture. Common SableStart/application/service changes should first preserve Panther correctness, then prove portability on Titan 2.

## Relationship to Q25

Q25 is no longer the assumed first non-Pixel purchase or required portability step.

Use Q25 when we specifically need:

- maintainable/community kernel source;
- lower-level MediaTek kernel experimentation;
- device-tree experimentation which Titan 2's opaque kernel/BSP blocks.

See `Q25_PORT_PLAN.md`.

## Relationship to Q27

Q27 remains the preferred future full physical-QWERTY candidate if its shipped hardware, source/BSP, firmware, AVB, recovery and support lifecycle pass acceptance.

Titan 2 work should deliberately produce reusable artifacts for Q27:

- capability-driven keyboard UI;
- square/compact responsive layout behavior;
- MediaTek vendor-inventory tooling;
- telephony/IMS acceptance suites;
- firmware/partition provenance records;
- recovery and flashing guards.

Do not assume common SoC family or branding means device-specific code is reusable.

## References

- `NON_PIXEL_MEDIATEK_ARCHITECTURE.md`
- `BRAX3_IODEOS_REFERENCE.md`
- `Q25_PORT_PLAN.md`
- `ROADMAP.md`
- `RELEASE_VALIDATION.md`
- https://source.android.com/docs/core/tests/vts/gsi
- https://source.android.com/docs/core/architecture/vintf
- https://grapheneos.org/build
