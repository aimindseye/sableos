# SableOS architecture

SableOS is designed as one common OS architecture with device-specific hardware adaptation and form-factor-specific interaction profiles.

The project should not become a collection of unrelated ROMs. Hardware changes the adapters. Form factor changes the shell. Application and service semantics remain common wherever practical.

## Architectural rule

> One SableOS core, multiple hardware adapters, multiple interaction profiles.

A device port should avoid branching common services or applications on model names when the same difference can be represented as a hardware or interaction capability.

## Logical layers

```text
SableOS
├── common core
│   ├── oxynoded
│   ├── capability / IPC model
│   ├── application lifecycle
│   ├── notifications
│   ├── contacts / messages / calls data models
│   ├── settings and storage models
│   ├── search / indexing
│   └── security policy model
│
├── common Android substrate
│   ├── init integration
│   ├── SELinux integration
│   ├── Binder / HIDL / AIDL adapters
│   └── retained Android hardware framework where required
│
├── hardware adapters
│   ├── Qualcomm
│   │   └── bramble / Pixel 4a 5G
│   └── MediaTek
│       ├── Q25 / MT6789
│       └── future compatible MediaTek devices
│
└── interaction profiles
    ├── touch-first
    │   └── Pixel reference experience
    └── keyboard-first
        ├── Q25
        └── future QWERTY devices
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

B1 validates native Rust compilation and packaging. B1.1 adds init startup and a dedicated SELinux domain while intentionally granting no radio, Binder, network, device, socket, or capability permissions beyond those required for init to transition into the daemon domain.

## Hardware adaptation boundary

SableOS should reuse the vendor-supported hardware path instead of replacing working modem, GPU, camera, audio, and firmware protocols without a compelling reason.

Device-specific adaptation belongs below common Sable services.

Examples:

```text
Sable service API
        │
        ├── Qualcomm adapter ── Android HAL / vendor stack ── Qualcomm hardware
        │
        └── MediaTek adapter ── Android HAL / vendor stack ── MediaTek hardware
```

The common service API should expose stable Sable semantics while adapters translate to the Android/vendor interfaces available on each device family.

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

## Security model

The security direction is:

1. SELinux enforcing.
2. Dedicated domains for Sable services.
3. Narrow privileged helpers instead of a monolithic privileged process.
4. No blanket root daemon.
5. No direct hardware, radio, Binder or network permission until required by a concrete feature.
6. Treat AVCs as evidence to investigate, not as instructions to add broad `allow` rules.
7. Preserve verified boot and partition boundaries appropriate to each device during bring-up.

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

See `docs/Q25_PORT_PLAN.md`.

### Zinwa Q27

Status: exploratory/watch target.

Q27 should not be assumed compatible with the Q25 port until public kernel/device sources, unlock/flash documentation, vendor boundaries and physical hardware are available and reviewed.

The goal is to reuse the common Sable core and keyboard-first interaction profile if the hardware/platform substrate is suitable.

## Porting principle

A new device port should prove the hardware substrate before adding Sable-specific behavior:

```text
known-good stock / upstream ROM
        ↓
hardware acceptance baseline
        ↓
minimal Sable Rust integration
        ↓
dedicated init + SELinux domain
        ↓
common Sable services
        ↓
interaction profile
        ↓
optional narrow hardware brokers
```

This keeps hardware regressions distinguishable from SableOS regressions and maximizes reusable common code.