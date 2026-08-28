# SableOS architecture

SableOS is designed as one common OS architecture with device-specific hardware adaptation and form-factor-specific interaction profiles.

The project should not become a collection of unrelated ROMs. Hardware changes the adapters. Form factor changes the shell. Application and service semantics remain common wherever practical.

Privacy and security are the first priorities, but SableOS does not discard mature Android/AOSP/vendor capability merely to reduce the amount of Android code present.

## Architectural rules

> One SableOS core, multiple hardware adapters, multiple interaction profiles.

> Preserve proven AOSP/vendor capability unless there is a demonstrated privacy, security, performance, maintainability, or architectural reason to replace it.

> The shell may observe and request; privileged services decide and execute.

A device port should avoid branching common services or applications on model names when the same difference can be represented as a hardware or interaction capability.

SableOS minimalism means minimal privilege, attack surface, unnecessary background activity, data collection, duplicated implementation, and UI complexity. It does not mean reimplementing working platform capabilities without cause.

## Logical layers

```text
SableOS
├── interaction layer
│   ├── touch-first shell
│   ├── keyboard-first shell
│   └── Sable applications
│
├── common semantic APIs
│   ├── commands / capability requests
│   ├── application lifecycle
│   ├── notifications
│   ├── contacts / messages / calls models
│   ├── settings / storage / search models
│   └── media / connectivity semantics
│
├── common Sable services
│   ├── oxynoded
│   ├── narrow brokers/helpers
│   ├── capability / IPC policy
│   └── security policy model
│
├── common Android substrate
│   ├── init integration
│   ├── SELinux integration
│   ├── Binder / HIDL / AIDL infrastructure
│   ├── retained AOSP framework capability
│   └── compatibility components where justified
│
├── hardware adapters
│   ├── Qualcomm
│   │   └── bramble / Pixel 4a 5G
│   └── MediaTek
│       ├── Q25 / MT6789
│       └── future compatible MediaTek devices
│
└── vendor / hardware boundary
    ├── modem / IMS / radio
    ├── audio / camera / graphics
    ├── power / thermal / sensors
    └── firmware / device-specific HALs
```

This is a logical architecture. The repository may use different physical directory names while the implementation is still being established.

## Rust-first userspace

`oxynoded` is the initial native Rust component and the seed of the common SableOS service layer.

The intended direction is to keep privileged code small and auditable:

- narrow services rather than one giant root daemon
- dedicated SELinux domains
- explicit capability boundaries
- no broad device access by default
- no direct modem protocol implementation
- no privilege granted merely for convenience
- no direct privileged hardware/security libraries loaded by the presentation shell

B1 validates native Rust compilation and packaging. B1.1 adds init startup and a dedicated SELinux domain while intentionally granting no radio, Binder, network, device, socket, or capability permissions beyond those required for init to transition into the daemon domain.

## Shell / service trust boundary

Presentation code must remain outside the privileged hardware/security trust boundary.

Preferred flow:

```text
Sable shell / application
        ↓
typed semantic Sable API
        ↓
narrow Rust service / broker
        ↓
SELinux + capability policy
        ↓
AOSP framework / supported HAL / vendor stack
        ↓
hardware
```

A screen that can display or request a privileged operation does not receive the privilege to perform that operation directly.

Examples:

- a brightness control requests a power/display service operation;
- a phone UI requests a call through the telephony service;
- a security UI queries or requests a security service operation;
- a notification UI renders notification state without inheriting arbitrary app or filesystem access.

This prevents a shell/rendering compromise from automatically becoming broad system compromise.

## AOSP capability preservation

SableOS divides inherited platform functionality into three broad classes.

### Foundation

Foundation capabilities are normally retained and hardened rather than rewritten. Examples include Binder/HIDL/AIDL infrastructure, SELinux, AVB, Keystore/KeyMint-backed key handling, update/A-B machinery, networking, Wi-Fi, Bluetooth, audio, media, camera, power/thermal, input, HAL infrastructure, and the supported vendor modem/RIL/IMS stack.

Foundation does not mean unrestricted trust. These components remain subject to privilege minimization, SELinux policy, network/privacy review, and physical regression testing.

### Compatibility

Compatibility components may be retained when they preserve useful ecosystem functionality, but should be optional and isolated as tightly as practical.

Examples may include Android application compatibility, selected framework services, automotive/projection compatibility, or other third-party interoperability layers.

A compatibility component does not automatically gain unrelated access to contacts, location, messages, media, identifiers, files, sensors, or the network.

### Replacement candidate

SableOS is expected to own presentation and policy where that creates a better privacy/security/product architecture, while retaining useful lower layers.

Examples include the launcher/home experience, SystemUI presentation, Settings presentation, notification presentation, search/command UI, and Sable-native applications.

Replacing presentation does not imply deleting the underlying AOSP service that provides the capability.

See `docs/AOSP_CAPABILITY_POLICY.md` for the preserve-before-remove and replacement gates.

## Hardware adaptation boundary

SableOS should reuse the vendor-supported hardware path instead of replacing working modem, GPU, camera, audio, and firmware protocols without a compelling reason.

Device-specific adaptation belongs below common Sable services.

Examples:

```text
Sable service API
        │
        ├── mock backend ───────────── development / tests
        │
        ├── Qualcomm adapter ── Android HAL / vendor stack ── Qualcomm hardware
        │
        └── MediaTek adapter ── Android HAL / vendor stack ── MediaTek hardware
```

The common service API should expose stable Sable semantics while adapters translate to the Android/vendor interfaces available on each device family.

Mocks belong behind the same service contracts. Production UI code should not switch between mock and direct privileged libraries.

## Telephony boundary

Telephony is a strict vendor-stack preservation boundary.

SableOS must not implement a raw modem protocol or bypass the supported Radio HAL path.

### Qualcomm / bramble

```text
Sable telephony API
      ↓
future narrow Rust broker
      ↓
Android Radio HAL / Binder / HIDL
      ↓
Google / Qualcomm radio, QCRIL and IMS stack
      ↓
modem firmware
```

### MediaTek / Q25-class devices

```text
Sable telephony API
      ↓
future narrow Rust broker
      ↓
Android Radio HIDL / vendor MediaTek interfaces
      ↓
MediaTek vendor RIL and IMS stack
      ↓
modem firmware
```

CarrierConfig, APN selection, IMS behavior and vendor radio firmware should remain intact until a replacement is demonstrably safer and equally compatible.

## Automotive and external-device compatibility

SableOS should preserve the Android/AOSP capabilities that make automotive and accessory interoperability possible, including media-session semantics, Bluetooth profiles, Telecom/call semantics, notifications, location/navigation interfaces, audio routing, USB/network transports, and related framework behavior.

Do not make proprietary Google components a foundation requirement for SableOS. Equally, do not intentionally break compatible Android interfaces simply because the Sable shell is different.

If official Android Auto or another proprietary/third-party projection host is usable on a future configuration, treat it as an optional compatibility component behind explicit Sable capability grants. It should receive only the media, calls, notifications, navigation/location, microphone, contacts, or other data that the feature actually requires and the user has enabled.

If official projection is unavailable, reuse the mature underlying Android media, Telecom, Bluetooth, notification, navigation, and external-display semantics rather than inventing parallel stacks without cause.

## Security model

The security direction is:

1. SELinux enforcing.
2. Dedicated domains for Sable services.
3. Narrow privileged helpers instead of a monolithic privileged process.
4. No blanket root daemon.
5. No direct hardware, radio, Binder or network permission until required by a concrete feature.
6. The shell remains unprivileged relative to the operations it presents.
7. Treat AVCs as evidence to investigate, not as instructions to add broad `allow` rules.
8. Preserve verified boot and partition boundaries appropriate to each device during bring-up.
9. Reused compatibility components receive explicit, minimal data and privilege rather than inheriting broad platform access.
10. Replacement code must have an equal or narrower trust boundary than the mature component it replaces.

## Capability-preservation gate

Before removing or replacing an AOSP, LineageOS, or vendor component, determine:

- the capability it provides;
- its dependency graph;
- its external communications/data flows;
- its current UID/SELinux/Binder/socket/device/network privileges;
- whether unwanted behavior can be disabled while preserving useful behavior;
- whether a narrower broker or policy boundary solves the privacy/security concern;
- whether a proposed replacement is demonstrably better;
- whether physical-device capability parity has been proven.

A component is not removed merely because it is inherited from Android.

Each device maintains a known-good capability baseline. Subsequent Sable milestones must not silently lose working capabilities; intentional removals must be documented as explicit product decisions.

## Interaction is not hardware support

Hardware support and user experience are separate axes.

The Pixel reference device uses a touch-first, Metro-inspired visual and navigation direction. Physical-QWERTY devices use a keyboard-first interaction profile designed around focus, shortcuts, type-to-search and dense information presentation.

Applications should consume semantic UI and command primitives rather than hard-code a Pixel or Q25 layout.

See `docs/INTERACTION_PROFILES.md`.

## Device capability model

Applications and shells should prefer capabilities over device-name checks.

Examples:

```text
input.has_physical_keyboard
input.has_touch
input.has_pointer
input.keyboard_touch_surface
navigation.primary
navigation.secondary
display.aspect_class
display.compactness
telephony.radio_family
media.automotive_projection
compat.android_runtime
```

A future QWERTY device should be able to use the keyboard-first shell without adding device-specific branches throughout applications.

## Rendering roadmap

R1 uses Slint for the first SableOS UI implementation.

R2 moves toward Vexo / `wgpu` so rendering, composition and higher-level UI behavior can evolve without changing the common service, application-data and capability architecture.

The renderer is replaceable. Application semantics, IPC contracts and security boundaries should remain stable across rendering generations.

## Reference and planned hardware

### Pixel 4a 5G G025E (`bramble`)

Status: reference and physically validated platform.

- Qualcomm Snapdragon 765G / SM7250
- Adreno 620
- Android 12.1 baseline: `android-12.1.0_r11`
- build ID: `SQ3A.220705.003.A1`
- B0 physical hardware/carrier baseline: passed
- B1 native Rust validation: passed
- B1.1 init + dedicated SELinux integration: in progress

### Zinwa Q25

Status: planned port; not yet a supported SableOS build.

The current LineageOS Q25 tree provides a promising substrate:

- arm64
- MediaTek MT6789
- GKI kernel source dependency
- A/B updates
- dynamic partitions
- AVB
- `vendor_boot`
- MediaTek vendor SELinux and hardware dependencies
- Android Radio HIDL plus MediaTek-specific radio interfaces

The Q25 baseline must inventory and preserve working LineageOS/AOSP capabilities before Sable-specific cleanup begins.

See `docs/Q25_PORT_PLAN.md`.

### Zinwa Q27

Status: exploratory/watch target.

Q27 should not be assumed compatible with the Q25 port until public kernel/device sources, unlock/flash documentation, vendor boundaries and physical hardware are available and reviewed.

The goal is to reuse the common Sable core and keyboard-first interaction profile if the hardware/platform substrate is suitable.

## Porting principle

A new device port should prove and inventory the hardware/software substrate before adding Sable-specific behavior:

```text
known-good stock / upstream ROM
        ↓
hardware + capability acceptance baseline
        ↓
minimal Sable Rust integration
        ↓
capability-parity regression gate
        ↓
dedicated init + SELinux domain
        ↓
capability-parity regression gate
        ↓
common Sable services
        ↓
interaction profile
        ↓
optional narrow hardware/compatibility brokers
```

This keeps hardware regressions distinguishable from SableOS regressions, prevents accidental loss of mature Android functionality, and maximizes reusable common code.
