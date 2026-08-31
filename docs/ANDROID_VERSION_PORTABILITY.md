# SableOS Android-version portability strategy

## Purpose

SableOS is implemented on an Android/AOSP substrate, but it must not become permanently coupled to one Android release, one device, or one platform compiler generation.

The architectural rule is:

> Sable semantic contracts and portable Rust logic should remain stable across Android releases; Android-version and device-specific integration belongs behind narrow adapters which are requalified at each substrate transition.

SableOS is therefore not defined as "an Android 14 fork" or as a ROM for one Pixel generation. Android provides the mature kernel, framework, security, application and hardware substrate on which Sable services and policy are implemented.

UI-framework selection is also not defined by whichever Rust compiler happens to ship in one Android branch. Prefer one compiler universe when viable, but use a stable ABI/AIDL/NDK boundary when a separately pinned modern UI toolchain is justified.

Normative device/toolchain transition decision: `adr/0003-panther-baseline-and-rust-ui-toolchain-boundary.md`.

## Coupling model

Android-version coupling is intentionally asymmetric.

```text
low Android-version coupling
        │
        ▼
Sable semantic contracts
        │
portable Rust policy / transformation logic
        │
Sable application / interaction semantics
        │
Sable service interfaces
        │
---------------- Android boundary ----------------
        │
Android-version adapters / small framework hooks
        │
Binder / init / SELinux / PackageManager / AppOps
        │
HAL / VINTF / vendor integration
        │
device-specific hardware adapter
        │
        ▼
high device / substrate coupling
```

Expected coupling by layer:

| Layer | Expected Android-version coupling |
| --- | --- |
| Sable semantic API definitions | very low |
| pure Rust transformation/policy logic | very low |
| host tests | very low |
| Sable application/domain concepts | low |
| renderer-independent UI state/navigation concepts | low |
| public Android SDK-facing UI adapter | low to medium |
| Sable Android services | medium |
| init integration | medium |
| versioned/stable Binder interfaces | medium |
| SELinux policy | medium to high |
| Soong/product/build integration | medium to high |
| PermissionController modifications | high |
| PackageManager / ActivityManager hooks | high |
| device adapter / HAL integration | high |
| proprietary vendor/firmware boundary | very high and device-specific |

A substrate upgrade should therefore not require redesigning Sable semantics merely because Android changed an implementation detail.

## What SableOS intentionally requires from Android

SableOS currently relies on Android/AOSP for mature infrastructure which should be retained and hardened rather than reimplemented without evidence.

### Kernel and process isolation

Retain Android/Linux infrastructure including:

- process and UID/GID isolation;
- namespaces and cgroups;
- Binder driver support;
- SELinux kernel enforcement hooks;
- memory/process management;
- supported device drivers and power-management infrastructure.

### Android init

Use Android init for service lifecycle, identities, partition-aware startup and SELinux domain transitions.

Sable services should not introduce a parallel privileged service manager merely to avoid Android integration.

### SELinux

SELinux remains a foundational mandatory-access-control boundary.

Sable policy should fit Android's public/private/vendor policy architecture. AVC or `neverallow` failures trigger boundary review before permission expansion.

### Binder and stable interfaces

Binder remains the preferred local IPC substrate for Android-integrated Sable services.

Where interfaces need to survive independent component, toolchain or Android-version evolution, prefer stable/versioned AIDL or equivalent explicitly versioned Sable contracts rather than private implementation APIs.

The Rust ABI is not used as a cross-toolchain compatibility contract. If independently compiled Rust components use different compiler versions, interoperate through a stable C/NDK/AIDL boundary.

### HAL / VINTF boundaries

Treble/VINTF boundaries are valuable portability mechanisms, not obstacles to bypass.

Sable hardware adapters should use supported Android/vendor interfaces wherever possible. Direct access to raw vendor protocols, modem sockets or undocumented device nodes is a last resort requiring explicit security and maintenance justification.

### Android application model

Preserve the ordinary Android application substrate:

- APK and split-APK formats;
- PackageInstaller / PackageManager;
- APK signing identity and lineage;
- ART/DEX runtime;
- Android UID sandboxing;
- SELinux application domains;
- runtime permissions and PermissionController;
- AppOps;
- intents, activities, services, providers and broadcasts;
- Android profiles/users;
- scoped storage and related platform APIs.

Sable security features should surround and harden this model rather than require applications to be rebuilt into a Sable-specific format.

Sable-native UI technology is independent of third-party Android application technology. A Rust/Slint/WaterUI/Makepad/Blinc/Vexo/future-SableUI launcher or application may coexist with Java/Kotlin/Compose/Flutter/native APKs because application execution and lifecycle remain Android-managed.

### Hardware and vendor stacks

Preserve mature supported implementations for:

- radio/RIL/IMS;
- Wi-Fi and Bluetooth;
- graphics/display;
- camera;
- audio;
- GNSS/location;
- NFC;
- USB;
- sensors;
- health/power/thermal.

A Sable semantic broker may expose a safer common contract, but it should not replace a functioning vendor stack without a demonstrated security or architectural need and physical capability parity.

### Hardware-backed security

Future production targets should retain and use supported Android security infrastructure including:

- KeyMint/Keymaster;
- StrongBox where available;
- Gatekeeper/Weaver;
- Android Verified Boot;
- rollback protection;
- hardware-backed key and attestation capabilities.

## Breaking-change classes

Every Android substrate upgrade should classify breakage instead of treating all compile failures as equivalent.

### 1. Public SDK / behavior changes

Examples include runtime-permission behavior, background execution, foreground-service rules or public API changes.

Typical response:

- rebuild against the new SDK;
- update UI/application adapters;
- run compatibility regressions.

This is usually low-to-medium risk.

### 2. Internal framework changes

Sable features which hook PackageManager, PackageInstaller, PermissionController or ActivityManager are more tightly coupled to AOSP internals.

The preferred pattern is:

```text
AOSP framework
      │
      │ small reviewed hook
      ▼
Sable-owned service/module
      │
portable analyzer / policy logic
```

Avoid spreading Sable policy across large patches in `frameworks/base`. Keep framework integration small so an Android rebase changes the hook rather than the policy engine.

### 3. SELinux/build-system changes

A later Android release may change:

- public/vendor type visibility;
- `neverallow` rules;
- policy macros;
- partition policy ownership;
- Soong module behavior;
- product/partition packaging.

Every substrate upgrade therefore requires a fresh compile, `sepolicy_test`, generated-policy inspection, runtime AVC audit and negative-access testing. A policy compiling on Android N does not automatically authorize carrying it unchanged to Android N+1.

### 4. Platform Rust/Cargo changes

The Rust/Cargo toolchain integrated into AOSP changes by release and may be substantially older than current upstream GUI/application ecosystems.

Do not respond automatically by either:

- down-revving every UI dependency until it fits the platform compiler; or
- globally uplifting AOSP's Rust compiler solely for UI convenience.

Preferred decision order:

1. use the platform compiler if the chosen UI stack fits cleanly;
2. use bounded source compatibility work only when small and maintainable;
3. if the UI requires a modern compiler, build the UI with a separately pinned toolchain and cross into platform services through a stable ABI/AIDL/NDK adapter;
4. upgrade the AOSP platform compiler only as an independently justified Android-platform change with full blast-radius validation.

### 5. Vendor/HAL compatibility changes

This is the hard ceiling for old hardware.

A newer Android framework may eventually stop accepting the VINTF/FCM/HAL generations provided by frozen proprietary vendor binaries. When proprietary Google/Qualcomm/MediaTek code cannot be rebuilt, compatibility shims and framework backports increase maintenance and security risk.

At that point Sable should normally move the modern Android baseline to newer hardware rather than accumulate an indefinitely growing compatibility fork for an end-of-life device.

## Sable adapter discipline

Sable semantic APIs should remain independent of how a given Android/device generation implements the operation.

Power is the current reference example:

```text
Sable API: PowerSnapshot / IPowerService V1 semantics
        │
        ├── bramble Android 14 adapter -> Health HAL 2.1 callback bridge -> PowerMonitor
        ├── panther adapter            -> supported health/power HAL adapter
        └── MediaTek adapter           -> supported Android/MTK health backend
```

The user-facing contract should not change solely because the physical backend changed. Clients do not receive raw Health handles or battery sysfs paths.

Where useful, implementation structure may distinguish common code from Android-API-specific adapters, for example conceptually:

```text
sable/core/            portable semantics / Rust logic
sable/android/common/  common Android integration
sable/android/api34/   Android 14-specific adapter
sable/android/api35/   Android 15-specific adapter
sable/android/api36/   Android 16-specific adapter
sable/android/api37/   Android 17-specific adapter
sable/device/<target>/ device/vendor integration
```

This is an architectural pattern, not a mandatory repository layout.

## UI toolchain portability

The long-term UI architecture must also survive device/platform compiler changes.

Same-compiler path:

```text
Sable Rust UI
    -> generated stable AIDL Rust binding
    -> Sable service
```

Different-compiler path:

```text
modern Rust UI
    -> stable C/NDK/AIDL adapter
    -> Sable semantic service
```

Rejected:

```text
modern-rustc UI
    -> direct linkage to platform-rustc private Rust dylib ABI
```

This separation is especially important for Pixel versus future MediaTek/QWERTY targets, which may ship different Android branches and platform Rust versions while still needing the same Sable UI/application semantics.

## Device / Android transition strategy

### Pixel 4a 5G (`bramble`)

Role: frozen architecture and regression reference.

- Android 14: authoritative S1.7 service/API/runtime baseline.
- S1.8 D0/F0-F3: framework/toolchain evidence captured, no production UI landed.
- Android 15 bramble portability experiment: closed without execution.
- Android 16+: no promised Sable bramble target.

Bramble's unsupported proprietary firmware/vendor components impose a security ceiling. It must not constrain current framework selection or modern Android architecture.

### Pixel 7 (`panther`)

Role: active touch-first development reference.

The transition begins with `PANTHER-P0` rather than assuming one Android branch.

P0 must:

1. identify the exact physical device/current stock build;
2. record bootloader/recovery/update state and official restore path;
3. inventory candidate AOSP/platform branches and device/vendor proprietary binary availability;
4. inventory the exact Rust/Cargo/Clang/Soong toolchain for each candidate;
5. understand the Pixel 7 kernel and `vendor_kernel_boot`/dynamic-partition model;
6. select the newest supported/reproducible Android hardware baseline;
7. explicitly record any reason an older panther platform baseline is temporarily required.

Pixel 7 currently receives modern Android releases and is a better active engineering target than bramble. Its remaining OEM support lifetime is nevertheless finite, so later Pixel hardware can supersede it without semantic redesign.

After P0, `PANTHER-V0` establishes vanilla hardware, security and ordinary Android-app compatibility before Sable service/UI integration.

### QWERTY / MediaTek targets

QWERTY devices provide a second portability axis:

```text
Qualcomm/Google -> MediaTek
Pixel/touch-first -> physical-QWERTY/keyboard-first
Google device tree -> independent vendor/community tree
```

A successful QWERTY port should reuse the same semantic Sable core and UI/application model and differ primarily in device adapters and interaction profile.

Platform Rust compiler differences do not justify separate Pixel and QWERTY UI codebases.

See `Q25_PORT_PLAN.md` and `INTERACTION_PROFILES.md`.

## Upgrade acceptance rule

An Android substrate upgrade or device transition is accepted only when:

1. a vanilla or upstream baseline is reproducible;
2. hardware/telephony capability parity is measured;
3. Sable semantic contracts remain stable unless a deliberate API revision is justified;
4. Android-specific patches/hooks remain bounded and documented;
5. SELinux remains enforcing and narrow;
6. app compatibility regressions are measured;
7. Sable-native UI integration is requalified without granting renderer-specific hardware privilege;
8. direct and negative security tests pass;
9. update/verified-boot behavior is understood;
10. device firmware/vendor security limitations are explicitly documented;
11. the maintenance burden is lower than or justified against moving to newer supported hardware;
12. Rust-toolchain differences are explicitly classified, with stable ABI boundaries when compilers differ.

## Long-term objective

The target architecture is:

```text
                    Sable Core
                        │
             stable semantic contracts
                        │
       ┌────────────────┼────────────────┐
       ▼                ▼                ▼
   Pixel adapter   later Pixel      MediaTek/QWERTY
       │             adapter            adapter
       │                │                │
       └──────── Android substrates ─────┘
                        │
              supported vendor stacks
```

Above that substrate, one renderer-independent Sable application/interaction core supports both Metro-inspired touch-first and BlackBerry/BB10-inspired keyboard-first profiles.

Sable should be an OS architecture implemented on Android substrates, not an ever-growing collection of release-specific forks.

The renderer is one portable client of this architecture, not the definition of the OS substrate. See `adr/0002-rust-ui-framework-and-android-app-compatibility.md` and `adr/0003-panther-baseline-and-rust-ui-toolchain-boundary.md`.
