# SableOS architecture

> **Current first-party HOME authority:** R9L8 Launcher3-hosted Sable Start. See `CURRENT_HOME_AND_C3B_INTEGRATION_AUTHORITY.md` and ADR-0012. Older standalone-SableLauncher records are historical. Android user selection of a third-party HOME remains allowed.

SableOS is one common OS architecture with device-specific hardware adaptation and form-factor-specific interaction profiles.

The project should not become a collection of unrelated ROMs. Hardware changes adapters. Form factor changes interaction. Application and service semantics remain common wherever practical.

Privacy and security are the first priorities, but SableOS does not discard mature Android/AOSP/vendor capability merely to reduce inherited code.

## Current architecture status

Current proven baseline:

- S1.7 is closed, runtime-proven and frozen on Android 14 `bramble`.
- `oxynoded` consumes Android Health HAL 2.1 asynchronously through HIDL callbacks.
- the 60-second production power poller is removed;
- callback-time snapshots are queued in the native bridge and consumed by Rust;
- HAL death unblocks the Rust retry/recovery path;
- latest validated `PowerState` is published through frozen read-only AIDL V1;
- a dedicated `sable_power_test_client` proves the intended Binder client boundary;
- ordinary Android shell may discover the service name through platform service-manager policy, but Binder `call` to `oxynoded` is denied under enforcing SELinux;
- the authorized client has no direct Health HAL or battery sysfs access;
- physical unplug/reconnect while dozing advanced AIDL sequence `1 -> 7` across six externally visible callback state changes with the same provider PID;
- slot A is naturally successful with S1.7 while successful slot B remains the S1.6 fallback;
- SELinux remains enforcing.

Exact S1.7 source, AIDL, image, device-binary and runtime seals are recorded in `S1_7_VALIDATION.md`.

### Current Panther / R9 product architecture

The active Android 17 / Panther product architecture is newer than the S1.7
bramble service baseline above. Current R9 source/module closure establishes:

- R9L8 Launcher3/Launcher3QuickStep as the sole Sable-owned canonical first-party HOME runtime; user-selected third-party HOME remains allowed through Android's normal role/default-app model;
- SableStart retained as reusable presentation/state source compiled into
  Launcher3 rather than a standalone `org.sableos.launcher` application;
- host Gradle presentation qualification limited to the canonical SableStart
  presentation filegroup, with authoritative product compilation through
  Launcher3/Soong;
- `Launcher3QuickStep` also retains Android Quickstep/Recents task and
  gesture integration;
- Settings as the persisted global appearance authority at
  `content://org.sableos.appearance/appearance`, with Sable apps as clients;
- Contacts using the existing Android section indexer plus a Sable right-edge
  alphabet rail rather than a second contact data model;
- Media using lazy large-library rendering, background collection indexing,
  bounded queue handoff and A-Z navigation for Songs/Artists/Albums/Favorites;
- Sable Reader (`org.sableos.reader`) focused on publication/Readium
  workflows: ordinary Light/Dark follows SableOS global appearance, Sepia and
  E-Ink remain explicit reading modes, and the library renders actual books
  continuously rather than collapsing them into presentation stacks;
- standalone Sable Text Reader (`org.sableos.textreader`) owning plain-text
  VIEW/SEND/PROCESS_TEXT, text TTS/audio export and user-directed
  camera/gallery OCR; its Sable flavor is offline-first with no INTERNET
  permission, translation dependency/UI or model-download path, bounds each
  text ingestion to 2 MiB, and permits only local TTS voices;
- Clock/Photos using qualified Day/Night presentation; Panther Camera remains an intentionally upstream, security-sensitive boundary, while keyboard-first Titan-family work uses the separately scoped Sable-owned Camera2 / Camera Control Deck direction from ADR-0012 and `CAMERA_ENHANCEMENT_ROADMAP.md`;
- Sable Hub (`org.sableos.hub`) as the common communications surface with
  Priority / Messages / Email / People pivots; the pinned GrapheneOS Messaging
  package remains the default SMS/MMS transport substrate;
- embedded social-provider WebViews retired. Third-party messaging integration
  proceeds through user-authorized Android notification/conversation adapters
  and supported installed-app actions rather than private-database or protocol
  impersonation;
- Sable Mail remains the owner of mail accounts, protocols, sync and private
  mailbox storage. Hub consumes only a bounded local mail snapshot/provider
  contract and does not become a second mail client or read the Mail database;
- Hub Priority is local and explainable rather than an opaque ranking service.
  V1 is driven by explicit unread/active communication state and preserves
  source attribution.

These R9 source/module decisions still require final fresh-image Panther
physical acceptance. They must not be described as completed physical release
closure until the source-bound image and device gates pass.

See `R9_SABLE_HOME_REPLACEMENT.md`,
`R9_MESSAGES_LOCAL_CONVERSATION_ADAPTERS.md`,
`R9_MEDIA_FLOW_REDESIGN.md`, ADR-0008,
`docs/adr/0009-separate-reader-and-text-reader-products.md`, and
`docs/adr/0011-sable-hub-v1.md`.

## Architectural rules

> One SableOS core, multiple hardware adapters, multiple interaction profiles.

> Preserve proven AOSP/vendor capability unless there is a demonstrated privacy, security, performance, maintainability, or architectural reason to replace it.

> The shell may observe and request; privileged services decide and execute.

> Platform security boundaries are design constraints to understand first, not obstacles to disable for convenience.

> Stable Sable semantic contracts should survive Android/device changes; substrate details belong behind adapters.

> Functional portability and production-security support are separate device gates.

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

### Proven S1.6 callback path

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

### Proven S1.7 typed IPC path

```text
Android Health HAL 2.1 callback
    -> native callback bridge
    -> PowerMonitor
    -> PowerStateStore
    -> com.sableos.power.IPowerService/default
    -> frozen read-only AIDL V1
    -> explicitly authorized Sable client
```

The V1 client receives stable Sable semantics, not backend handles:

- availability;
- battery percentage;
- charging state;
- Sable power-source enum;
- externally-visible state-change sequence.

It does not receive raw sysfs paths, a Health handle, mutation methods, or backend lifecycle details.

Authorization is a transaction boundary, not a secrecy boundary. Android 14 platform policy permits shell to discover many `service_manager_type` services, including the Sable power service. S1.7 therefore validates the effective boundary at Binder use: `sable_power_test_client` can find and call `oxynoded`, while `u:r:shell:s0` cannot start that dedicated client and is denied Binder `call` to `u:r:oxynoded:s0` under enforcing SELinux.

The physical closure correlated the API directly with callback delivery: sequence advanced from `1` to `7` across six externally visible callback transitions while the same `oxynoded` PID survived.

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

## Non-Pixel assurance classes

The Brax3/iodéOS review demonstrates that useful modern Android device integration can be maintained above a proprietary MediaTek BSP and prebuilt kernel/module set. SableOS therefore separates **functional device integration** from **production-security ownership**.

Canonical non-Pixel classes are:

```text
N0_GSI_USERSPACE_LAB
    Sable/AOSP userspace over stock kernel/vendor/firmware
    development/UI/compatibility work only

N1_INTEGRATED_VENDOR_BSP_PORT
    device tree + VINTF + SELinux + vendor/BSP integration
    may use prebuilt kernel/modules and proprietary firmware
    functional support can be strong while lower-layer maintenance remains external

N2_PRODUCTION_QUALIFIED
    full SableOS release/security gates including kernel/vendor/firmware lifecycle,
    AVB/signing/rollback, recovery, physical parity and reproducible release evidence
```

A device does not move from N0 to N1 or N2 merely because it boots.

A prebuilt kernel is not an automatic blocker for N0/N1 development, but it does not provide independent Sable kernel-security ownership. Vendor ABI shims, modem/IMS components, TEE/KeyMint/Gatekeeper binaries, firmware and module inputs must be explicit, versioned dependencies.

See `NON_PIXEL_MEDIATEK_ARCHITECTURE.md`, `NON_PIXEL_RELEASE_VALIDATION.md`, and `BRAX3_IODEOS_REFERENCE.md`.

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

On MediaTek devices, 5G/data, voice, SMS/MMS, IMS registration, VoLTE and VoWiFi are separate acceptance gates. Packet-data success does not prove IMS/voice support.

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
15. Release/production builds fail closed when required signing material is unavailable; they do not silently fall back to public test keys or verification-disabled vbmeta.
16. Platform, vendor, kernel/boot, modem, TEE and bootloader security provenance are tracked independently on non-Pixel targets.

See `SECURITY_MODEL.md`.

## B2 / S1 architectural precedent

Earlier B2 work proved that a `coredomain` helper directly reading `sysfs_batteryinfo` conflicts with Android platform security boundaries. The correct response was not weakening the platform invariant.

S1 refined the implementation further after discovering `bramble`'s final vendor image is an immutable Google prebuilt: the production power architecture now leaves battery sysfs ownership in the vendor Health HAL and makes `oxynoded` a Health client.

S1.7 extends that precedent upward: user-facing or diagnostic consumers do not become Health clients. They receive the frozen Sable semantic API through explicit Binder authorization.

This precedent applies broadly: understand why the boundary exists, then place the component on the correct side of it.

## Security-reference discipline

AOSP is normative for Android platform/security architecture. GrapheneOS remains a primary additional security-engineering reference for attack-surface reduction, exploit mitigations, capability enforcement, verified boot, update discipline, USB/debug controls, and device-support lifecycle.

External projects such as MarathonOS are useful for UX/device/power/recovery lessons. Brax3/iodéOS is additionally a strong reference for non-Pixel MediaTek device layering, proprietary-BSP compatibility, firmware/update ownership and recovery constraints. Neither project defines the SableOS trust model.

See `SECURITY_REFERENCE_GRAPHENEOS.md`, `EXTERNAL_LESSONS.md`, and `BRAX3_IODEOS_REFERENCE.md`.

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

On proprietary non-Pixel BSPs, also identify any framework/vendor ABI shim and the exact vendor/firmware dependency before removal or replacement.

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

## Keyboard-first platform architecture

Keyboard-First SableOS Design V1 is normative in
`docs/adr/0010-keyboard-first-sableos-design-v1.md`.

Keyboard-first behavior is a platform capability rather than an IME-only or
launcher-only feature. The common architecture now includes:

```text
Sable Device Profile
    -> Sable Hardware Input Mapper
    -> Sable Input Surface API
    -> Sable Keyboard Policy Service
    -> Sable Physical IME / application routing

SableStart Command Surface
Sable Focus & Navigation
Sable App Display Profiles
Sable Notification Policy & Profiles
Sable Hub
Sable Device Adapter & Security Delta Ledger
```

First-party input ownership does not remove Android user choice:

~~~text
SABLE_FIRST_PARTY_HOME=Launcher3QuickStep/SableStart
THIRD_PARTY_HOME_SELECTION_ALLOWED=YES
SABLE_FIRST_PARTY_IME=SableKeyboard
THIRD_PARTY_IME_SELECTION_ALLOWED=YES
FORCE_SABLE_DEFAULT_AFTER_USER_SELECTION=NO
~~~

Third-party launchers do not automatically gain Quickstep/SystemUI or Private
Space integration, and third-party IMEs do not automatically inherit Sable's
critical-entry/direct-boot acceptance. See ADR-0012.

Keyboard-first camera interaction is also part of the common interaction
profile rather than a device-specific UI fork. Sable Camera maps physical keys
to semantic camera actions and uses a landscape Camera Control Deck with a
viewfinder-first layout, while portrait and touch fallback remain supported.

The primary input normalization boundary is Android userspace around
EventHub/InputReader. Kernel changes are a last resort after device evidence
proves the vendor driver does not expose the required event capability.
Hardware normalization does not own semantic policy: a raw axis sequence may
become a normalized swipe or pointer event, while the Keyboard Policy Service,
IME, launcher or focused application decides what that event means in context.

Physical keyboard matrices and pointer/touch surfaces are modeled separately.
A Titan keyboard-associated touch surface and a future independent toolbelt or
trackpad can therefore consume the same common Sable navigation semantics.

App display compatibility is also a common platform capability. Per-app profiles
may select aspect ratio, logical width/height and optional density/UI scale
without changing global `wm size`. Overrides belong in Activity/Task
size-compat/window configuration and are keyed by Android user/profile, package
and display class.

Notification policy remains separate from Hub aggregation. Sable Settings and
SystemUI may expose keyboard-operable app/channel/conversation delivery,
privacy and snooze controls plus capability-gated hardware outputs such as a
status LED, keyboard backlight or secondary display. Third-party Hub data still
uses supported Android/public interfaces; first-party apps integrate through
bounded provider/service APIs rather than a shared unrestricted database.

Non-Pixel compatibility patches are recorded in a security delta ledger. A
TrebleDroid/RestlessOS compatibility workaround may explain a vendor failure,
but it is not imported as a blanket Sable security relaxation.

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

S1.7 followed this model: known-good successful S1.6 slot B was preserved while S1.7 was written to inactive slot A; activation occurred only after all validated image writes, slot A became naturally successful, and slot B remained successful fallback.

For non-Pixel hardware, the recovery model must additionally qualify the actual OEM bootloader/A-B behavior and any vendor low-level restore tooling. Unlockability is not sufficient evidence of safe OTA/rollback/relock behavior.

## Reference / planned hardware

### Pixel 4a 5G (`bramble`)

Role: architecture/regression reference on Android 14; Android 15 portability experiment candidate. It is not a long-lived production-security target because OEM firmware/vendor maintenance has ended.

### Pixel 7 (`panther`)

Role: active canonical full-stack SableOS development target on the GrapheneOS-derived Android 17 path. Panther remains the authoritative touch-first product/security/build reference while non-Pixel work is exploratory.

### Later Pixel-class reference

Future actively maintained touch/security baseline for production-security work, modern mitigations, relocked verified boot, and long-lived firmware/vendor updates.

### Unihertz Titan 2

Preferred interim non-Pixel candidate after Panther for SableStart, physical-keyboard, square-display, pointer and MediaTek/5G compatibility work.

Initial class: **N0 GSI/userspace development lab** using the stock kernel/vendor/firmware stack. It is not a production-security target unless later N1/N2 gates are independently proven.

See `TITAN2_GSI_PLAN.md`.

### Zinwa Q25

Optional MediaTek/QWERTY low-level study target. Its distinguishing value is source/community access for kernel/device experimentation which may not be possible on a prebuilt-kernel Titan 2 path. It is no longer assumed to be the first non-Pixel purchase or a required Q27 precursor.

### Zinwa Q27

Future preferred full physical-QWERTY candidate subject to real shipped hardware and kernel/BSP/vendor/bootloader/AVB/radio/IMS/camera/audio/keyboard/suspend/power/security-lifecycle acceptance.

See `NON_PIXEL_DEVICE_ROADMAP.md`.

## Non-goals

- direct UI-to-sysfs control;
- broad file capabilities on generic tools;
- UI-owned HAL handles;
- polling to compensate for suspend when a real event interface exists;
- global policy expansion to make a test pass;
- unbounded callback/event queues;
- device-name branches throughout common applications;
- coupling stable APIs to one vendor/backend implementation;
- treating a booting GSI as production device support;
- claiming ownership of kernel/vendor/firmware security updates which SableOS does not actually maintain.