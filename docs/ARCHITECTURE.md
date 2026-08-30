# SableOS architecture

SableOS is one common OS architecture with device-specific hardware adaptation and form-factor-specific interaction profiles.

The project should not become a collection of unrelated ROMs. Hardware changes adapters. Form factor changes interaction. Application and service semantics remain common wherever practical.

Privacy and security are the first priorities, but SableOS does not discard mature Android/AOSP/vendor capability merely to reduce inherited code.

## Current architecture status

Current proven baseline:

- S1.6 is closed and runtime-proven on Android 14 `bramble`.
- `oxynoded` consumes Android Health HAL 2.1 asynchronously through HIDL callbacks.
- the 60-second production power poller is removed;
- callback-time snapshots are queued in the native bridge and consumed by Rust;
- HAL death unblocks the Rust retry/recovery path;
- SELinux remains enforcing;
- `oxynoded` has no direct battery sysfs access;
- S1.7A is introducing a frozen, read-only power AIDL API and remains **in progress** until host/image seal completion.

## Architectural rules

> One SableOS core, multiple hardware adapters, multiple interaction profiles.

> Preserve proven AOSP/vendor capability unless there is a demonstrated privacy, security, performance, maintainability, or architectural reason to replace it.

> The shell may observe and request; privileged services decide and execute.

> Platform security boundaries are design constraints to understand first, not obstacles to disable for convenience.

> Stable Sable semantic contracts should survive Android/device changes; substrate details belong behind adapters.

Sable minimalism means minimal privilege, attack surface, unnecessary background activity, data collection, duplicated implementation, and UI complexity. It does not mean reimplementing working platform capability without cause.

## Logical layers

```text
SableOS
├── interaction layer
│   ├── touch-first shell
│   ├── keyboard-first shell
│   └── Sable applications
│
├── common semantic APIs
│   ├── typed read-only state APIs
│   ├── narrow capability requests
│   ├── application lifecycle
│   ├── notifications / communications
│   └── settings / storage / search / media semantics
│
├── common Sable services
│   ├── oxynoded
│   ├── narrow brokers/helpers
│   ├── lifecycle/resource policy
│   └── capability / IPC security policy
│
├── Android substrate
│   ├── init + SELinux
│   ├── Binder / HIDL / AIDL
│   ├── retained AOSP framework capability
│   └── supported HAL compatibility
│
├── hardware adapters
│   ├── Qualcomm / Pixel family
│   └── MediaTek / future QWERTY family
│
└── vendor / hardware boundary
    ├── modem / IMS / radio
    ├── audio / camera / graphics
    ├── power / thermal / sensors
    └── firmware / vendor HALs
```

## Rust-first userspace

`oxynoded` is the seed of the common Sable service layer.

Privileged code should remain small and auditable:

- narrow services rather than a universal root daemon;
- dedicated SELinux domains;
- explicit capability boundaries;
- no broad device access by default;
- no raw modem protocol implementation;
- no privilege merely for convenience;
- no direct privileged hardware/security libraries loaded by the presentation shell.

## Shell / service trust boundary

Presentation code remains outside the privileged hardware/security trust boundary.

```text
Sable shell / application
        |
        | typed semantic Sable API
        v
narrow Rust service / broker
        |
        | SELinux + capability policy
        v
AOSP framework / supported HAL / vendor stack
        |
        v
hardware
```

A screen that displays or requests a privileged operation does not receive the privilege to perform that operation directly.

Preferred:

```text
UI -> getLatestState() -> read-only power service
UI -> setFeatureEnabled(bool) -> narrow validated broker -> framework/HAL
```

Rejected by default:

```text
UI -> raw sysfs writes
UI -> direct Health HAL
UI -> generic privileged command executor
UI -> broad-capability general-purpose utility
```

## Power architecture

### Proven S1.6 path

```text
Android Health HAL 2.1
        |
        | IHealthInfoCallback::healthInfoChanged_2_1
        v
C++ HIDL callback bridge
        |
        | bounded callback-time snapshot queue
        v
Rust HealthEventStream
        |
        v
PowerMonitor
        |
        +-- INITIAL
        +-- CHANGED
        +-- ERROR / RECOVERED
        +-- unchanged suppressed
```

The bridge captures callback-delivered state rather than treating a callback as a wake signal for a later read. This preserves transient states across scheduling/suspend gaps.

Physical runtime testing proved the prior steady poller could miss a real Battery interval across suspend. The architectural correction was callback delivery—not longer test timing and not a daemon wakelock.

### S1.7 target

```text
Health callback
    -> PowerMonitor
    -> PowerStateStore
    -> frozen read-only AIDL
    -> explicitly authorized Sable client
```

The V1 client receives stable Sable semantics, not backend handles:

- availability;
- battery percentage;
- charging state;
- Sable power-source enum;
- state-change sequence.

It does not receive raw sysfs paths, a Health handle, mutation methods, or backend lifecycle details.

### Power semantics

Source precedence:

```text
Wireless > AC > USB > charging-without-source Unknown > Battery
```

A reconnect may legitimately be:

```text
Battery -> Unknown -> AC
```

when charging becomes true before an external-source online flag settles. Stable contracts model validated platform state rather than forcing backend behavior into an artificial one-step transition.

## AOSP capability preservation

Inherited capability falls into three classes.

### Foundation

Normally retain and harden mature platform capability: Binder/HIDL/AIDL, SELinux, AVB, Keystore/KeyMint, A/B update machinery, networking, Wi-Fi, Bluetooth, audio, media, camera, power/thermal, input, HAL infrastructure, and supported vendor modem/RIL/IMS stacks.

### Compatibility

Retain when useful, but isolate and grant only required data/privilege. Android application compatibility and selected framework/third-party interoperability layers belong here.

### Replacement candidate

Sable may replace presentation/policy where this creates a better product/security architecture while retaining useful lower layers: launcher/home, SystemUI presentation, Settings presentation, notifications, search/command UI, and Sable-native applications.

Replacement of presentation does not imply replacement of the mature underlying service.

See `AOSP_CAPABILITY_POLICY.md`.

## Hardware adaptation boundary

Reuse vendor-supported hardware paths instead of replacing working modem, GPU, camera, audio, power, or firmware protocols without compelling evidence.

```text
Sable semantic service
      |
      +-- mock backend (tests)
      +-- Qualcomm adapter -> Android/vendor stack -> hardware
      +-- MediaTek adapter -> Android/vendor stack -> hardware
```

Mocks live behind the same service contracts. Production UI never switches to direct privileged libraries.

Bramble-specific facts belong below generic contracts, including:

- immutable Google vendor image;
- HIDL Health 2.1 compatibility path;
- cable classification quirks such as computer reconnect reporting AC;
- A/B partition deployment details.

## Telephony boundary

Telephony remains a strict vendor-stack preservation boundary.

SableOS must not implement a raw modem protocol or bypass the supported Radio HAL path.

```text
Sable telephony API
    -> narrow broker
    -> Android Radio HAL / supported interface
    -> vendor RIL / IMS
    -> modem firmware
```

CarrierConfig, APNs, IMS behavior, vendor firmware, and supported radio paths remain intact until a replacement is demonstrably safer and equally compatible.

## Automotive / accessory compatibility

Preserve Android semantics useful for media sessions, Bluetooth profiles, Telecom/calls, notifications, navigation/location, audio routing, USB/network transports, and external-device integration.

Optional proprietary compatibility components must remain optional and explicitly authorized rather than becoming Sable foundation dependencies.

## Security model

Direction:

1. SELinux enforcing.
2. Dedicated domains for Sable services.
3. Narrow privileged helpers instead of monolithic privilege.
4. No blanket root daemon.
5. No hardware/network/Binder/device-node access until justified by a concrete feature.
6. Shell remains unprivileged relative to operations it presents.
7. AVCs are evidence to investigate, not automatic requests for broad `allow` rules.
8. `neverallow` failures are architecture signals.
9. Verified boot and partition boundaries remain part of bring-up/release design.
10. Compatibility components receive minimal explicit authority.
11. Replacement code must have equal or narrower trust boundaries than what it replaces.
12. Security claims include kernel, firmware, vendor code, and OEM support lifetime.
13. Development/unlocked state is not production security.
14. Security maintenance is continuous.

See `SECURITY_MODEL.md`.

## B2 / S1 architectural precedent

Earlier B2 work proved that a `coredomain` helper directly reading `sysfs_batteryinfo` conflicts with Android platform security boundaries. The correct response was not weakening the platform invariant.

S1 refined the implementation further after discovering `bramble`'s final vendor image is an immutable Google prebuilt: the production power architecture now leaves battery sysfs ownership in the vendor Health HAL and makes `oxynoded` a Health client.

This precedent applies broadly: understand why the boundary exists, then place the component on the correct side of it.

## Security-reference discipline

AOSP is normative for Android platform/security architecture. GrapheneOS remains a primary additional security-engineering reference for attack-surface reduction, exploit mitigations, capability enforcement, verified boot, update discipline, USB/debug controls, and device-support lifecycle.

External projects such as MarathonOS are also useful for UX, device-layering, recovery and measurement-driven power lessons. Product ideas are evaluated separately from their privilege architecture.

See `SECURITY_REFERENCE_GRAPHENEOS.md` and `EXTERNAL_LESSONS.md`.

## Capability-preservation gate

Before removing/replacing an AOSP, LineageOS, or vendor component, determine:

- capability provided;
- dependency graph;
- external communications/data flows;
- UID/SELinux/Binder/socket/device/network privileges;
- whether unwanted behavior can be disabled while retaining useful behavior;
- whether a narrower broker solves the concern;
- whether replacement is demonstrably better;
- whether physical capability parity has been proven.

## Interaction is not hardware support

Hardware support and UX are separate axes.

Touch-first and keyboard-first profiles should consume common semantic UI/command primitives rather than hard-code device identity.

Device capabilities—not product names—should drive behavior, for example:

```text
input.has_physical_keyboard
input.has_touch
input.has_pointer
navigation.primary
display.aspect_class
telephony.radio_family
compat.android_runtime
```

See `INTERACTION_PROFILES.md`.

## UI architecture direction

Sable UI should be mobile-first rather than desktop Linux narrowed to a phone.

Areas worth exploring after service boundaries are stable:

- gesture-first navigation;
- unified notification/communication hub;
- persistent live task previews;
- fast app switching and peek/return workflows;
- explicit foreground/background lifecycle;
- physical-keyboard-aware workflows.

These are product directions, not privilege justifications.

## Rendering roadmap

The renderer is replaceable. Application semantics, service contracts, lifecycle and security boundaries should remain stable across rendering generations.

## Recovery architecture

A/B deployment is an architectural property.

For runtime-changing milestones:

1. preserve current known-good successful slot;
2. write only the inactive slot;
3. verify writes before activation;
4. activate last;
5. require natural slot success;
6. keep the prior successful slot as fallback until closure.

Do not manually mark a slot successful as a substitute for runtime proof.

## Reference / planned hardware

### Pixel 4a 5G (`bramble`)

Role: architecture/regression reference on Android 14; Android 15 portability experiment candidate. It is not a long-lived production-security target because OEM firmware/vendor maintenance has ended.

### Modern Pixel-class reference

Future actively maintained touch/security baseline for production-security work, modern mitigations, relocked verified boot, and long-lived firmware/vendor updates.

### Zinwa Q25

Optional MediaTek/QWERTY study target useful for proving second-SoC and keyboard-first portability. It is not supported until source/unlock/vendor/physical gates pass.

### Zinwa Q27

Future primary QWERTY candidate subject to public source, unlock/recovery, vendor interfaces, radio/IMS, camera/audio, keyboard, suspend/power, and security-lifecycle acceptance.

## Non-goals

- direct UI-to-sysfs control;
- broad file capabilities on generic tools;
- UI-owned HAL handles;
- polling to compensate for suspend when a real event interface exists;
- global policy expansion to make a test pass;
- unbounded callback/event queues;
- device-name branches throughout common applications;
- coupling stable APIs to one vendor/backend implementation.
