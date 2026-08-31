# SableOS Android-version portability strategy

## Purpose

SableOS is implemented on an Android/AOSP substrate, but it must not become permanently coupled to one Android release.

The architectural rule is:

> Sable semantic contracts and portable Rust logic should remain stable across Android releases; Android-version and device-specific integration belongs behind narrow adapters which are requalified at each substrate transition.

SableOS is therefore not defined as "an Android 14 fork". Android provides the mature kernel, framework, security, application and hardware substrate on which Sable services and policy are implemented.

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
| public Android SDK-facing UI | low to medium |
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

Where interfaces need to survive independent component or Android-version evolution, prefer stable/versioned AIDL or equivalent explicitly versioned Sable contracts rather than private implementation APIs.

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

Sable-native UI technology is independent of third-party Android application technology. A Rust/Slint/Vexo/future-SableUI launcher or application may coexist with Java/Kotlin/Compose/Flutter/native APKs because application execution and lifecycle remain Android-managed.

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

### 4. Vendor/HAL compatibility changes

This is the hard ceiling for old hardware.

A newer Android framework may eventually stop accepting the VINTF/FCM/HAL generations provided by frozen proprietary vendor binaries. When proprietary Google/Qualcomm/MediaTek code cannot be rebuilt, compatibility shims and framework backports increase maintenance and security risk.

At that point Sable should normally move the modern Android baseline to newer hardware rather than accumulate an indefinitely growing compatibility fork for an end-of-life device.

## Sable adapter discipline

Sable semantic APIs should remain independent of how a given Android/device generation implements the operation.

Power is the current reference example:

```text
Sable API: PowerSnapshot / IPowerService V1
        │
        ├── bramble Android 14 adapter -> Health HAL 2.1 callback bridge -> PowerMonitor
        ├── later Pixel adapter       -> supported health/power HAL adapter
        └── MediaTek adapter          -> supported Android/MTK health backend
```

The user-facing contract should not change solely because the physical backend changed. Clients do not receive raw Health handles or battery sysfs paths.

Where useful, implementation structure may distinguish common code from Android-API-specific adapters, for example conceptually:

```text
sable/core/            portable semantics / Rust logic
sable/android/common/  common Android integration
sable/android/api34/   Android 14-specific adapter
sable/android/api35/   Android 15-specific adapter
sable/android/api36/   Android 16-specific adapter
sable/device/<target>/ device/vendor integration
```

This is an architectural pattern, not a mandatory repository layout.

## Device / Android transition strategy

### Pixel 4a 5G (`bramble`)

Role: architecture and regression reference.

- Android 14: primary current Sable development baseline.
- Android 15: planned portability experiment immediately after S1.8 closes and before S1.9 begins.
- Android 16+: not a promised bramble target; investigate only if useful as an engineering experiment.

The Android 15 exercise is intended to answer whether the Sable core survives an Android substrate upgrade cleanly while the frozen bramble vendor generation remains workable.

It does not restore the device's missing OEM firmware/vendor security maintenance.

A proposed qualification sequence is:

1. create a separate Android 15 workspace/OUT_DIR and preserve the frozen Android 14 reference tree;
2. establish a vanilla Android 15 source/device baseline without Sable changes;
3. measure hardware and telephony parity against the Android 14 baseline;
4. measure a bounded ordinary Android APK compatibility corpus;
5. reintroduce the minimum Sable product/service integration;
6. requalify SELinux, build, init and partition boundaries;
7. port the frozen S1.7 Power AIDL contract without semantic redesign;
8. run the S1.8 qualified Rust UI path against the same contract;
9. document every Android-version-specific change.

### Pixel 7

Role: successor modern touch/security reference.

The roadmap intent is for Pixel 7-class supported hardware to take over the modern Android substrate from Android 16 onward, subject to normal hardware/source/bootloader/vendor/security-lifecycle acceptance.

The purpose is not merely to obtain a higher Android version. It is to move the modern Sable baseline onto hardware with a materially better firmware/vendor support and security lifecycle than bramble.

### QWERTY / MediaTek targets

QWERTY devices provide a second portability axis:

```text
Qualcomm -> MediaTek
Pixel/touch-first -> physical-QWERTY/keyboard-first
Google device tree -> independent vendor/community tree
```

A successful QWERTY port should reuse the same semantic Sable core and differ primarily in device adapters and interaction profile.

See `Q25_PORT_PLAN.md` and `INTERACTION_PROFILES.md`.

## Upgrade acceptance rule

An Android substrate upgrade is accepted only when:

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
11. the maintenance burden is lower than or justified against moving to newer supported hardware.

## Long-term objective

The target architecture is:

```text
                  Sable Core
                      │
          stable semantic contracts
                      │
       ┌──────────────┼──────────────┐
       ▼              ▼              ▼
 Android 14       Android 15       Android 16+
 adapter           adapter          adapter
       │              │              │
       ▼              ▼              ▼
 device adapters / supported vendor stacks
```

Sable should be an OS architecture implemented on Android substrates, not an ever-growing collection of release-specific forks.

The renderer is one portable client of this architecture, not the definition of the OS substrate. See `adr/0002-rust-ui-framework-and-android-app-compatibility.md`.
