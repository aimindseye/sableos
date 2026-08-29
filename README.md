# SableOS

SableOS is an experimental privacy-focused mobile OS with a Rust-first userspace architecture, narrow privilege boundaries, and a goal of sharing one common core across different hardware and interaction profiles.

The project is not intended to become a collection of unrelated device ROMs. Hardware-specific behavior belongs in adapters; form-factor-specific behavior belongs in interaction profiles; common application and service semantics should remain shared wherever practical.

SableOS is also not intended to discard mature Android capability merely to minimize the amount of inherited code. Privacy and security come first, while proven AOSP/vendor functionality is preserved wherever it can be reused safely.

## Core rules

> One SableOS core, multiple hardware adapters, multiple interaction profiles.

> Preserve proven AOSP/vendor capability unless there is a demonstrated privacy, security, performance, maintainability, or architectural reason to replace it.

> The shell may observe and request; privileged services decide and execute.

Minimalism means minimal privilege, attack surface, unnecessary background activity, data collection, duplicated implementation, and UI complexity — not needless reinvention of working platform functionality.

## Current reference target

- Device: Google Pixel 4a 5G G025E
- AOSP device codename: `bramble`
- SoC: Qualcomm Snapdragon 765G / SM7250
- GPU: Adreno 620
- Base: Android 12.1 / `android-12.1.0_r11`
- Build ID: `SQ3A.220705.003.A1`
- Build variant: `userdebug`

## Current milestone: B2 — `power.read_state`

### B0 — physical baseline passed

Vanilla AOSP B0 has been physically validated on the G025E.

Validated cellular/hardware behavior includes cellular Internet, outbound/inbound voice calling, earpiece/microphone/speakerphone, SMS, MMS, LTE, and available 5G/NR behavior.

The retained Google/Qualcomm radio and IMS stack remains the hardware compatibility baseline.

### B1 — physical Rust validation passed

B1 is the first SableOS derivative build on `bramble`.

It keeps the known-good Google/Qualcomm hardware and radio stack intact and adds one native Rust executable:

```text
/system_ext/bin/oxynoded
```

The frozen B1 executable is:

```text
753cd2e2b4e915848a72f289d6bc764cd34edf1bbde0b0b4d023d06ae88d0e45  oxynoded
```

B1 has been physically validated on the G025E. `oxynoded --probe` runs successfully on-device and B1 retains cellular data, voice and SMS parity with B0.

### B1.1 — init + dedicated SELinux domain passed

B1.1 is physically validated and its Gold Master is frozen.

B1.1 proves that the B1-validated `oxynoded` can:

- start automatically through Android init;
- run as UID/GID `system`, not root;
- run in dedicated SELinux domain `u:r:oxynoded:s0`;
- keep SELinux enforcing;
- run with zero inheritable, permitted, effective and ambient Linux capabilities;
- remain running after reboot;
- retain the B1 AOSP/vendor hardware and telephony capability baseline;
- avoid new radio, Binder, network, HAL, service-manager, device-node or other feature privileges.

The B1.1 offline structural/capability audit, safe flash-package audit, physical security validation, hardware parity, telephony parity and firmware-preservation gates all passed.

See `docs/B1_1_VALIDATION.md`.

### B2 — first narrow semantic hardware service

B2 introduces one read-only Sable semantic operation:

```text
power.read_state
```

The goal is to prove the service/backend boundary before adding write-capable or larger Android framework interfaces.

B2 requires:

- a typed `PowerState` semantic API;
- a `PowerBackend` abstraction with a deterministic mock backend;
- a physical Android/bramble backend behind the same contract;
- no bramble-specific paths/constants in core service semantics;
- read-only physical access;
- minimum attributable SELinux permissions;
- no radio, network or telephony permissions;
- no root or Linux capabilities;
- physical agreement with Android battery percentage/charging state;
- reboot/polling stability;
- preservation of the B1.1 hardware and telephony capability baseline.

See `docs/B2_POWER_READ_STATE.md`.

## Architecture

SableOS keeps presentation, semantic services, Android/AOSP substrate and device/vendor adaptation as separate trust and portability layers.

The shell should never gain a privileged hardware/security interface merely because it presents a control for that feature. Sensitive operations belong behind typed semantic APIs, narrow services/brokers and SELinux policy.

See `docs/ARCHITECTURE.md`.

## AOSP capability policy

SableOS classifies inherited functionality as:

- **foundation** — retain and harden mature platform capability;
- **compatibility** — retain when useful, but isolate and grant only required data/privilege;
- **replacement candidate** — Sable-owned presentation/policy where replacement has a clear benefit while useful lower layers remain available.

Before removing an AOSP, LineageOS or vendor component, the project must identify the capability it provides, its dependencies/data flows/privileges, whether the unwanted behavior can be constrained, and whether a replacement has proven physical-device capability parity.

A Sable milestone must not silently lose working baseline functionality. Intentional removals are explicit product decisions with documented rationale.

See `docs/AOSP_CAPABILITY_POLICY.md`.

## Interaction profiles

SableOS does not require radically different form factors to use one slab-phone UI.

### Touch-first

The Pixel reference experience is touch-first with a Metro-inspired design direction: strong typography, simple geometry, glanceable information, low chrome and fast gesture navigation.

### Keyboard-first

Physical-QWERTY devices use a keyboard-first profile built around focus navigation, shortcuts, type-to-search, command routing, dense information presentation, and touch/keyboard coexistence.

Source and API naming should remain generic rather than naming the interaction model after another commercial OS.

See `docs/INTERACTION_PROFILES.md`.

## Device roadmap

### Google Pixel 4a 5G G025E (`bramble`)

Status: **reference / physically validated through B1.1**.

- Qualcomm SM7250
- B0 physical baseline: passed
- B1 Rust validation: passed
- B1.1 init/SELinux validation: passed
- B2 `power.read_state`: planned/current

### Zinwa Q25

Status: **planned port / not yet supported**.

The current LineageOS Q25 device tree provides a promising MediaTek substrate with arm64, MT6789, kernel source dependency, A/B updates, dynamic partitions, AVB, MediaTek vendor policy/hardware support, and Android/MediaTek radio interfaces.

Q25 is intended to validate:

- a second SoC/vendor family;
- the common Sable Rust/service architecture on MediaTek;
- vendor-RIL preservation outside Qualcomm;
- capability-preserving reuse of the existing LineageOS/AOSP substrate;
- the keyboard-first interaction profile.

See `docs/Q25_PORT_PLAN.md`.

### Zinwa Q27

Status: **exploratory/watch target**.

Q27 is of interest as a future physical-QWERTY platform, but SableOS will not assume Q25 compatibility or claim support until public developer sources, unlock/flash documentation, vendor interfaces and physical hardware can be reviewed.

If suitable, it should reuse the common Sable core and keyboard-first interaction framework rather than become a separate OS fork.

## Telephony rule

SableOS preserves the supported vendor modem path.

On Qualcomm this means retaining the Google/Qualcomm Radio HAL, QCRIL, IMS and modem firmware stack. On MediaTek targets it means retaining Android Radio HIDL/AIDL plus the supported MediaTek vendor RIL/IMS stack.

A future Rust telephony broker must use narrow supported Android/vendor interfaces. It must not talk directly to raw modem sockets or implement a replacement modem protocol.

## Automotive / Android compatibility

SableOS should retain the underlying Android media, Bluetooth, Telecom, notification, navigation/location, audio-routing, USB/networking and related semantics that enable automotive and accessory interoperability.

The core OS must not depend on proprietary Google components. If official Android Auto or another third-party/proprietary compatibility layer is usable on a future configuration, it should be optional and tightly sandboxed with explicit access only to the media, calls, notifications, navigation/location or other data actually required and enabled by the user.

The goal is reuse without surrendering privacy/security control.

## Repository layout

```text
device/sable/bramble/        SableOS bramble product and oxynoded source
patches/                     Minimal AOSP patches required by pinned bases
docs/                        Architecture, build, validation and porting notes
```

Generated Android images, proprietary vendor archives, firmware blobs and target-files ZIPs are intentionally not committed to this repository.

## Documentation

- `docs/ARCHITECTURE.md` — common-core, AOSP reuse, hardware-adapter, security and telephony architecture
- `docs/AOSP_CAPABILITY_POLICY.md` — preserve/remove/replacement, compatibility, parity and privacy/security gates
- `docs/INTERACTION_PROFILES.md` — touch-first and keyboard-first UI/input design
- `docs/Q25_PORT_PLAN.md` — planned MediaTek/QWERTY port methodology
- `docs/BUILDING_B1.md` — reproduce the B1 build
- `docs/B1_VALIDATION.md` — B1 build and physical validation record
- `docs/B1_1_VALIDATION.md` — completed B1.1 build, SELinux, structural, capability and physical validation record
- `docs/B2_POWER_READ_STATE.md` — B2 semantic API, backend, privilege and physical acceptance plan
- `docs/B1_GOLD_MASTER.md` — immutable B1 archive/freeze record
- `docs/G025E_HARDWARE_ACCEPTANCE.md` — factory-state, unlock, safe-flash and hardware acceptance runbook
- `docs/CARRIER_COMPATIBILITY.md` — carrier compatibility goals and qualification rules

## Next gate

Implement the B2 semantic `PowerState` contract and deterministic `MockPowerBackend` first, with host-side tests and no new Android/SELinux privileges. Only after that core layer is clean should B2 inspect and select the narrowest physical Android/bramble power-state interface.
