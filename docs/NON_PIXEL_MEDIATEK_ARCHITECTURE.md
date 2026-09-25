# SableOS non-Pixel / MediaTek architecture

Status: **normative candidate-port architecture; does not declare any non-Pixel device supported**.

This document defines how SableOS approaches non-Pixel Android devices, especially MediaTek hardware, while preserving the common SableOS security/service/product architecture.

It incorporates lessons from the reviewed Brax3/iodéOS implementation and remains subordinate to accepted SableOS ADRs, `SECURITY_MODEL.md`, `KERNEL_SECURITY_UPDATE_POLICY.md`, `AOSP_CAPABILITY_POLICY.md`, and `RELEASE_VALIDATION.md`.

## Core rule

> One SableOS core, device-specific hardware integration, explicit assurance classification.

A device may be useful for SableOS product/UI development before it is acceptable as a production-security target. Functional portability and security ownership are separate gates.

## Device-support classes

SableOS distinguishes three non-Pixel states.

### Class N0 — development GSI / userspace lab

Purpose:

- UI and interaction work;
- common Sable application/service portability;
- generic Android/Treble compatibility exploration;
- physical-keyboard and unusual-display qualification;
- early hardware compatibility inventory.

Expected ownership:

```text
SableOS / AOSP system userspace
        +
stock device kernel
        +
stock vendor / ODM
        +
stock firmware / bootloader
```

Security classification:

- **development only**;
- not a full SableOS production-security target;
- no claim of Sable-owned kernel, vendor or firmware patch lifecycle;
- no claim that GrapheneOS device-specific mitigations are present.

A booting GSI is not sufficient for support status.

### Class N1 — integrated vendor/BSP device port

Purpose:

- real device/product tree;
- explicit VINTF/SELinux/device configuration;
- controlled vendor extraction and compatibility shims;
- A/B/Virtual A/B and OTA integration where hardware supports it;
- device-specific recovery and release packaging.

Possible ownership model:

```text
SableOS platform/userspace
    -> device-specific Android integration
    -> proprietary/vendor BSP interfaces
    -> prebuilt or source-built kernel
    -> signed vendor firmware
```

This class can provide strong functional support but does not automatically satisfy production-security requirements when kernel/vendor/firmware maintenance remains externally controlled.

### Class N2 — production-qualified SableOS device

A non-Pixel target enters production support only after all required SableOS release/security gates close, including:

- maintained and timely Android platform updates;
- understood kernel source/provenance and update mechanism;
- current vendor/BSP maintenance;
- current modem/TEE/bootloader firmware path;
- AVB/custom-key/relock architecture sufficient for the intended security posture;
- rollback protection and safe A/B update/recovery behavior;
- hardware-security capability classification;
- physical capability parity;
- exact release reproducibility and signing.

N2 is an assurance classification, not merely a build target name.

## Architectural layers

```text
common Sable product / applications
        |
        | stable application + semantic service contracts
        v
common Sable services / brokers
        |
        | Android framework / stable NDK/AIDL boundary
        v
Android platform substrate
        |
        +------------------------------+
        |                              |
        v                              v
Pixel/Google adapter          non-Pixel / MediaTek adapter
                                       |
                                       v
                         VINTF / SELinux / init / properties
                                       |
                                       v
                         vendor HAL / RIL / IMS / BSP
                                       |
                                       v
                         kernel / modules / firmware
```

Common applications must not branch on product identity when a capability or interaction-profile abstraction is sufficient.

## Repository / manifest ownership model

A mature non-Pixel target should keep device-specific ownership obvious.

Preferred conceptual structure:

```text
device/sable/<device>/
device/sable/<device>-kernel-prebuilt/     # only when kernel is intentionally prebuilt
vendor/sable/<device>/
vendor/sable/<device>-firmware/            # or separately versioned release artifacts

manifest/snippets/sable-<device>.xml
release-tools/<device>/
```

Exact repository naming can change; the architectural goal is separation of:

- common Sable platform code;
- device integration;
- prebuilt kernel/module inputs;
- proprietary vendor userspace;
- low-level firmware/recovery artifacts;
- release/flashing tooling.

Do not hide device ownership by scattering model-specific changes across common applications or unrelated platform repositories.

## Prebuilt-kernel policy

The Brax3 reference demonstrates that a modern Android userspace can be maintained on top of a prebuilt MediaTek kernel, DTB/DTBO and module set.

SableOS therefore does **not** treat missing kernel source as an automatic blocker for N0 or N1 development.

However:

```text
prebuilt kernel viability
    !=
independent kernel security ownership
```

For a prebuilt-kernel target record at minimum:

- kernel release/version string;
- Android/GKI/KMI family if determinable;
- kernel image hash;
- DTB/DTBO hashes;
- `vendor_boot` module manifest/hashes;
- `vendor_dlkm`/`system_dlkm` module manifest/hashes where applicable;
- vendor-provided release date and security provenance;
- module/kernel compatibility checks;
- whether the OEM supplies timely replacement artifacts.

`KERNEL_SECURITY_UPDATE_POLICY.md` remains authoritative. A target without maintainable kernel source or equivalent trustworthy vendor update provenance cannot claim SableOS independent K1/K2 kernel-update support.

## Vendor/BSP preservation boundary

Initial MediaTek bring-up should preserve working vendor paths rather than replacing modem, IMS, camera, graphics, audio, GNSS, secure-element, TEE or power stacks without evidence.

Expected pattern:

```text
Sable semantic API / presentation
    -> Android framework / narrow broker
    -> supported HAL / vendor extension
    -> proprietary BSP implementation
    -> hardware / firmware
```

Do not implement raw modem protocols or bypass supported Radio/IMS interfaces merely to reduce inherited vendor code.

## VINTF and HAL inventory

Before integrated N1 bring-up, build a complete hardware contract inventory covering at least:

- framework compatibility matrix;
- device/vendor manifests;
- AIDL/HIDL HAL versions;
- MediaTek vendor extensions;
- init services;
- service-manager domains;
- required shared libraries;
- system/vendor/system_ext cross-partition dependencies.

Unknown vendor extensions are architecture questions, not candidates for deletion by default.

## Framework/vendor ABI shim policy

Older vendor BSPs may require compatibility adaptation on newer Android versions.

Allowed only when explicit and bounded:

- `DT_NEEDED` additions/replacements;
- SONAME fixes;
- symbol/library compatibility shims;
- property-name compatibility patches;
- versioned HAL compatibility libraries.

Each shim must record:

```text
component
source vendor/BSP version
new Android/platform version
reason
exact binary/library change
expected callers
security relevance
runtime test
removal condition
```

A pile of undocumented binary patches is not an acceptable long-term architecture.

## Telephony / 5G / IMS boundary

MediaTek telephony must remain behind supported Android/vendor radio interfaces.

Qualification is layered:

```text
SIM detected
    -> registration
    -> LTE/5G data
    -> voice
    -> SMS/MMS
    -> IMS
    -> VoLTE
    -> VoWiFi where supported
    -> carrier-specific stability
```

A working data connection does not imply a working or safe voice/IMS implementation.

Carrier configuration, emergency-call routing, modem firmware and vendor IMS services are preserved until an alternative is intentionally designed and proven.

Routine testing must not place live emergency-service calls.

## Firmware lifecycle

Firmware is part of device support and release security.

Track independently where applicable:

```text
bootloader / LK
modem / md1img
TEE
connectivity firmware
power-management firmware
DSP / SCP / VCP / SSPM / MCUPM
camera firmware
NVRAM/calibration state
```

A system-only GSI does not own these updates.

An integrated port may package OEM-supplied signed firmware when licensing, hardware safety and provenance permit, but the Sable release record must distinguish:

- source-built Sable/AOSP code;
- vendor binary userspace;
- kernel/module artifacts;
- signed firmware payloads.

## Security patch-level provenance

Do not summarize device security with one patch date.

Record separately:

```text
PLATFORM_SPL
VENDOR_SPL
KERNEL_BOOT_SPL_OR_PROVENANCE
MODEM_FIRMWARE_VERSION
TEE_FIRMWARE_VERSION
BOOTLOADER_VERSION
CONNECTIVITY_FIRMWARE_VERSION
```

A newer Android platform patch level does not imply that the vendor BSP, kernel, modem or TEE are current.

## SELinux

SELinux remains enforcing for supported development and production paths.

Rules:

- targeted permissions only;
- no global permissive target to make hardware work;
- `neverallow` failures are architecture signals;
- vendor domains stay vendor-scoped where required;
- compatibility shims do not acquire unrelated privileges;
- UI remains outside privileged hardware domains.

## AVB / signing

Development may use test keys or unlocked boot state when explicitly classified.

Release-candidate and production builds must fail closed if required signing material is unavailable.

Rejected production behavior:

```text
missing private key
    -> public AOSP test key
    -> verification disabled
```

Required production evidence includes:

- exact AVB key identity;
- vbmeta chain/descriptor proof;
- rollback-index policy;
- bootloader state;
- custom-key/relock behavior where applicable;
- image/payload signatures;
- update/rollback path.

## A/B and recovery qualification

Unlockability alone is insufficient.

A serious non-Pixel candidate must eventually validate, where the hardware supports it:

```text
known-good stock restore
unlock
custom image boot
A -> B update
B -> A update
interrupted-update recovery
rollback/fallback
relock/custom-key verified boot
factory recovery from a failed custom deployment
```

Low-level MediaTek flashing tools and scatter maps are recovery assets and dangerous mutation mechanisms. They require the same fail-closed product/partition/hash authorization discipline as fastboot deployment.

## Physical acceptance matrix

N1/N2 physical acceptance should include at minimum:

- boot/reboot stability;
- display/touch;
- physical keyboard, modifiers, shortcuts and repeat where present;
- pointer/trackpad behavior where present;
- Wi-Fi;
- Bluetooth and important profiles;
- NFC;
- GNSS/location;
- audio playback/record/call routes;
- cameras and sensors;
- fingerprint/biometric behavior;
- charging and USB;
- suspend/resume;
- thermal behavior;
- storage/encryption;
- SIM/radio/data/voice/SMS/IMS;
- 5G where hardware supports it;
- OTA/slot/rollback behavior;
- AVB/bootloader state;
- relevant hardware-security capabilities.

`BOOT=PASS` and `HOME=PASS` are never sufficient release criteria.

## Build reproducibility

For release-quality non-Pixel builds bind:

- exact manifest revisions rather than only moving branch names;
- container image by digest if containerized;
- host/build tool versions;
- kernel/module/DTB/DTBO hashes or source commits;
- vendor/BSP hashes;
- firmware hashes;
- Sable source revisions/hashes;
- release signing identity;
- build date and build number;
- target-files and final image hashes.

Containerization is useful for repeatability, but a Dockerfile containing moving package repositories or `latest` downloads is not itself proof of reproducibility.

## Interaction profiles

Non-Pixel hardware is also an interaction portability test.

Common applications consume capabilities such as:

```text
input.has_physical_keyboard
input.has_touch
input.has_pointer
display.aspect_class
display.size_class
navigation.primary
telephony.radio_family
```

Do not fork app semantics for Titan 2, Q25 or Q27 model names.

## Candidate roadmap application

### Titan 2

Initial role: **N0 development GSI/userspace lab**.

Use it for SableStart, square-display layout, keyboard/pointer navigation, framework portability and MediaTek compatibility work while retaining the stock kernel/vendor/firmware stack.

Promotion to N1/N2 requires separate evidence and is not implied by successful GSI boot.

### Zinwa Q25

Role: **optional low-level MediaTek/kernel research platform** when its community kernel/device source provides value that Titan 2 cannot provide.

Q25 is no longer assumed to be the required first non-Pixel SableOS development device.

### Zinwa Q27

Role: **preferred future physical-QWERTY full-device candidate**, subject to real shipped hardware and complete source/BSP/bootloader/AVB/firmware/security-lifecycle qualification.

## TrebleDroid / RestlessOS compatibility-reference policy

TrebleDroid and RestlessOS are useful non-Pixel compatibility laboratories,
especially for identifying vendor assumptions around Unihertz/MediaTek
keylayouts, Agold/vendor camera behavior, fingerprint HAL policy, VINTF, SELinux
and older kernel/vendor compatibility.

They are not the SableOS security baseline. A compatibility patch may disable or
relax a hardening feature in order to boot across arbitrary vendor partitions;
SableOS must not generalize that trade-off to every target.

Every candidate compatibility delta must enter a device-scoped security ledger:

```text
target device/profile
affected hardening/security feature
vendor/kernel dependency
reproduced failure
smallest required delta
security/privacy impact
runtime/physical test
removal condition
reference/upstream source
```

If a hardening feature is unsupported by the retained vendor kernel/BSP, the
release/support claim must say so. Compatibility success does not upgrade N0/N1
security ownership.

## External reference relationship

Brax3/iodéOS and TrebleDroid/RestlessOS are device-port and compatibility references. They are not the SableOS security baseline.

GrapheneOS remains the primary additional reference for production security engineering. AOSP documentation remains normative for Android partitioning, VINTF, AVB, SELinux, update and GKI behavior.

See:

- `BRAX3_IODEOS_REFERENCE.md`
- `TITAN2_GSI_PLAN.md`
- `Q25_PORT_PLAN.md`
- `RELEASE_VALIDATION.md`
- `KERNEL_SECURITY_UPDATE_POLICY.md`
- `SECURITY_REFERENCE_GRAPHENEOS.md`
