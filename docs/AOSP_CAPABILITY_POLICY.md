# AOSP capability preservation policy

SableOS is privacy- and security-first, but it is not designed to discard mature Android/AOSP capability merely to reduce the amount of Android code present.

The default rule is:

> Preserve proven AOSP/vendor capability. Replace, restrict, sandbox, or remove a component only when there is a demonstrated privacy, security, performance, maintainability, or product-architecture reason.

Minimalism in SableOS means minimal privilege, attack surface, unnecessary background activity, data collection, duplicated implementation, and UI complexity. It does **not** mean reimplementing working platform capabilities without cause.

## Shell security rule

> The shell may observe and request; privileged services decide and execute.

Touch-first and keyboard-first shells should not receive direct access to device nodes, raw modem sockets, filesystem-encryption primitives, broad Binder/HAL surfaces, or privileged native libraries merely because a setting is visible in the UI.

Preferred flow:

```text
Sable shell / application
        ↓
typed semantic Sable API
        ↓
narrow service / broker
        ↓
SELinux + capability policy
        ↓
AOSP framework / supported HAL / vendor stack
        ↓
hardware
```

The same semantic API may be backed by a mock implementation for development, a Qualcomm adapter on bramble, or a MediaTek adapter on a future target.

## Capability classes

### 1. Foundation

Foundation capabilities should normally be retained and hardened rather than rewritten.

Examples include:

- Linux kernel integration required by the device
- Binder/HIDL/AIDL infrastructure
- SELinux
- AVB and verified-boot plumbing
- Keystore/KeyMint-backed key handling where available
- update engine and A/B update machinery
- networking and Wi-Fi framework
- Bluetooth stack and profiles
- audio framework and vendor audio HAL
- media codecs/framework
- camera framework/HAL boundary
- input and accessibility infrastructure where retained by the product
- power/suspend/thermal infrastructure
- Android/vendor hardware abstraction boundaries
- vendor modem/RIL/IMS stack

Foundation does not mean unrestricted trust. Components remain subject to SELinux, privilege minimization, network/privacy review, and regression testing.

### 2. Compatibility

Compatibility components may be retained when they preserve valuable functionality or ecosystem interoperability, but they should be optional and sandboxed as tightly as practical.

Examples can include:

- Android application/runtime compatibility
- selected framework services needed by third-party applications
- automotive/projection compatibility
- selected account/provider integrations
- compatibility shims for existing Android applications or accessories

A compatibility component is not automatically entitled to broad filesystem, contacts, location, identifier, microphone, camera, notification, or network access. Its data flows must be explicit and user-controllable where practical.

### 3. Replacement candidate

Replacement candidates are surfaces where SableOS has a strong reason to own the experience or policy while retaining useful lower layers.

Examples include:

- launcher/home experience
- SystemUI presentation
- Settings presentation
- notification presentation
- Sable-native applications
- search/command UI
- touch-first and keyboard-first shells

Replacing presentation does not imply deleting the underlying AOSP service that provides the capability.

## Preserve-before-remove gate

Before removing, disabling, or replacing an AOSP, LineageOS, or vendor component, answer all of the following:

1. What user-visible or system capability does the component provide?
2. Which framework services, applications, HALs, update paths, accessories, or recovery flows depend on it?
3. Does it communicate externally? If so, with whom and for what purpose?
4. What user data, device identifiers, sensors, files, messages, contacts, location, media, or metadata can it access?
5. What UID, SELinux domain, Linux capabilities, Binder services, sockets, device nodes, or network privileges does it have?
6. Can unwanted behavior be disabled or constrained while preserving the useful capability?
7. Can SELinux, IPC narrowing, user consent, or a dedicated broker reduce its privilege sufficiently?
8. Can Sable expose the useful behavior through a narrower semantic API while retaining the mature underlying implementation?
9. Is the proposed replacement demonstrably safer, more private, more maintainable, or materially more efficient?
10. Has the replacement passed capability-parity and regression testing on physical hardware?

If these questions are not answered, removal is not approved.

## Capability-parity gate

A Sable milestone must not silently lose working baseline capability unless the removal is an explicit product decision with documented rationale.

For every device baseline, maintain a capability inventory covering at least the features relevant to that hardware:

- boot/reboot/recovery
- display and input
- Wi-Fi
- Bluetooth and major profiles
- audio playback/recording/routing
- camera
- sensors
- USB/ADB/Fastboot as appropriate to the build stage
- storage
- charging/power/suspend/resume
- cellular data
- voice calling
- SMS/MMS
- IMS/VoLTE and available 5G behavior
- NFC where present
- location/GNSS where present
- media playback/codec support
- notifications
- accessibility/input behavior retained by the product
- update/rollback/recovery path

A milestone that intentionally changes one of these capabilities must record the change and rationale rather than treating it as an accidental regression.

## Security/privacy gate for reused components

Reusing Android/AOSP/vendor code is acceptable only when it does not bypass SableOS security goals.

Review at least:

- privilege level and SELinux domain
- Binder/HIDL/AIDL surface area
- device-node access
- filesystem scope
- network access and destinations
- telemetry/analytics behavior
- persistent identifiers
- account coupling
- location/contact/message/media access
- background execution
- user consent and revocation
- update provenance and maintainability

Where a useful compatibility component requires more data or privilege than the base Sable service, isolate it rather than widening the base service for everyone.

## Automotive and Android Auto compatibility

SableOS should preserve Android media, Bluetooth, Telecom, notification, location/navigation, USB/networking, and related application semantics that make automotive interoperability possible.

Do not design the core OS around a requirement for proprietary Google components, but do not intentionally break compatible Android interfaces merely because the Sable shell is different.

If official Android Auto or another proprietary/third-party projection host is technically and legally usable on a future SableOS configuration, treat it as an optional compatibility component:

```text
vehicle/projection compatibility component
        ↓
explicitly granted Sable capabilities
        ↓
media / calls / notifications / navigation as enabled
```

The component should not automatically inherit unrelated filesystem, contacts, identifiers, location, microphone, camera, or service-internal access.

If official projection is unavailable, SableOS may still reuse the same underlying AOSP media, Telecom, Bluetooth, notification, navigation, and external-display semantics rather than inventing parallel media/call stacks.

## Mock and test backends

UI development should support mock backends without changing application semantics:

```text
Sable semantic API
        ├── mock backend
        ├── bramble / Qualcomm backend
        └── Q25-class / MediaTek backend
```

Mocks belong behind service contracts. The production shell must not switch between direct privileged libraries and mocks with a compile-time UI flag.

## Porting gate

A new hardware port begins from a known-good stock/upstream baseline and records its capability inventory before Sable-specific changes.

Each subsequent stage must repeat the relevant capability-parity checks. This prevents a device port from being declared successful merely because it boots or renders the Sable shell while losing mature Android hardware functionality.

## Replacement approval rule

A mature AOSP/vendor implementation should be replaced only when all of the following are true:

1. the existing capability and dependency graph are understood;
2. the privacy/security issue or architectural benefit is documented;
3. the replacement has a narrower or at least equivalent trust boundary;
4. physical-device capability parity has been demonstrated;
5. update/recovery behavior remains safe;
6. rollback to the last known-good implementation is possible during development.

The objective is not to maximize the amount of custom code. The objective is to maximize user control, privacy, security, reliability, and portability while reusing proven platform capability where it is safe to do so.
