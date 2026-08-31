# ADR-0003: Move the active development baseline to Pixel 7 and decouple UI framework choice from the platform Rust compiler

Status: Accepted

## Context

SableOS proved its initial service and security architecture on Pixel 4a 5G (`bramble`) using Android 14. S1.7 closed and froze a callback-driven Health integration, a narrow read-only power semantic contract, frozen AIDL V1, SELinux authorization boundaries, inactive-slot deployment discipline, runtime authorization, and physical callback-to-AIDL sequence correlation.

S1.8 then used the same Android 14 tree to begin Rust UI framework qualification. That work established that the Android 14 AOSP branch used for bramble ships Rust/Cargo 1.68. Current Rust UI frameworks are substantially newer. Slint 1.5 core could be made to compile on 1.68 with bounded compatibility patches, but public/runtime qualification immediately began accumulating dependency-version work caused by the old Cargo/Rust baseline. Current Vexo and several other modern Rust UI candidates require significantly newer Rust toolchains.

The limiting factor is not the Pixel 4a 5G CPU architecture and not Rust's ability to target the device. The limiting factor is the age of the selected Android/AOSP platform branch and its integrated Rust/Cargo toolchain, combined with bramble's end-of-life vendor/firmware security ceiling.

Pixel 7 (`panther`) is still in Google's supported-device cohort and has official Android 17 updates. It also has supported Pixel kernel/device development infrastructure and a materially newer Android-platform path than bramble.

SableOS must not choose its long-term UI framework merely because one framework can be backported to the oldest platform compiler used by an historical reference device.

## Decision

### 1. Close active bramble development after the frozen S1.7 architecture record

Pixel 4a 5G (`bramble`) becomes a frozen historical architecture/regression reference.

- S1.7 remains the authoritative bramble architecture and runtime seal.
- The Android 14 bramble tree remains useful for reproducing S1.7 and for narrowly scoped regression archaeology.
- No further S1.8 UI-framework backport work is required on bramble.
- The previously planned Android 15 bramble portability experiment is closed without execution; it no longer gates S1.8 or S1.9.
- Bramble is not a production-security reference and no future Android-version promise is made for it.

The S1.8 Slint-on-Rust-1.68 probes are retained as useful evidence about framework/toolchain coupling, but they do not become a maintenance obligation.

### 2. Pixel 7 (`panther`) becomes the active touch-first development reference

SableOS moves current development to Pixel 7.

The first panther gate must establish the actual reproducible Android baseline rather than assume one:

1. verify device identity, bootloader/recovery state and current stock build;
2. inventory official AOSP/device/vendor/kernel sources and proprietary binary availability;
3. inventory the exact Rust/Cargo/Clang/Soong toolchain for candidate Android branches;
4. establish a vanilla/upstream panther hardware baseline before Sable changes;
5. prefer the newest currently supported Android release which can be reproduced with understood vendor/kernel/boot boundaries;
6. if the newest release cannot yet be reproduced as a clean AOSP hardware build, use the newest reproducible panther baseline for platform bring-up while keeping the UI-toolchain rule below independent.

As of this decision, Pixel 7 receives official Android 17 updates and remains in Google's five-year update cohort. This is enough to make it a substantially better current engineering target than bramble, but Pixel 7 is not treated as an indefinite production-security target. Later Pixel hardware with longer upstream support may replace it without changing Sable semantics.

### 3. Framework selection is independent of the platform Rust version

Sable distinguishes two Rust toolchain roles:

```text
Android platform Rust
---------------------
AOSP/Soong integrated compiler
platform Rust services
binder_rs-generated platform components
SELinux/build-tested system modules

Sable UI Rust
-------------
renderer / UI framework
Sable interaction/application semantics
standalone Android-managed UI process
```

Using the same compiler for both roles is preferred when it does not distort framework choice or maintenance cost.

However, Sable UI may use a separately pinned modern Rust compiler when required by the selected framework, provided the platform boundary is stable and auditable.

### 4. Never rely on Rust ABI across independently compiled toolchain universes

Rust's native ABI is not a stable cross-compiler contract.

If UI and platform components are built with different Rust compiler versions, they must not directly link through compiler-private Rust dylib ABI.

Allowed boundary examples include:

- stable/versioned Binder AIDL through an appropriate generated non-Rust ABI/backend;
- AIDL NDK/C++ plus a tiny reviewed stable C ABI adapter;
- another explicitly versioned C ABI owned by Sable when justified.

Rejected:

```text
modern-Rust UI
    -> direct link to AOSP-rustc-generated Rust dylib
```

Preferred when the same toolchain is viable:

```text
Sable Rust UI
    -> frozen sable-power-aidl-V1-rust
    -> oxynoded
```

Preferred when toolchains differ:

```text
modern-Rust Sable UI
    -> stable C/NDK/AIDL adapter
    -> frozen Sable semantic service
    -> oxynoded / later service implementation
```

A global AOSP Rust-toolchain uplift is not performed solely to satisfy a UI framework.

### 5. S1.8 framework qualification restarts on the modern baseline

The Android-14-specific Slint backport investigation stops after the captured F3 evidence. Do not continue pinning/down-revving dependencies merely to make bramble's Rust 1.68 toolchain accept a framework.

S1.8 resumes on panther and requalifies a broader Rust UI candidate set using the actual modern baseline.

Primary framework/renderer candidates and references include:

- Slint;
- WaterUI;
- Project Robius + Makepad;
- Blinc;
- Vexo;
- Dioxus Native / Blitz where appropriate;
- a Sable-owned UI framework assembled from suitable components if no upstream framework satisfies requirements.

Crux remains an architectural reference for renderer-independent Rust application/state/effect separation. UniFFI and Flutter Rust Bridge are interop technologies rather than preferred Sable shell renderers. Tauri/WebView-based presentation is not the preferred system-shell architecture.

Qualification still requires evidence for touch, multi-touch, keyboard/focus, IME, clipboard, accessibility, text shaping, lifecycle, performance/power, dependency provenance, reproducibility, security and Android-version portability.

### 6. Keep the two interaction profiles and one semantic core

The device transition does not change the UX direction.

- Pixel-class phones use the Metro-inspired touch-first profile.
- Zinwa Q25/Q27-class devices use the BlackBerry/BB10-inspired keyboard-first profile.
- Application, status, notification, navigation, search, command and capability semantics remain shared.
- Renderer/framework code must not create separate Pixel and QWERTY application architectures.

A modern UI-toolchain boundary should make it easier, not harder, to reuse the same Sable UI core on future MediaTek/QWERTY Android substrates whose platform Rust compiler may differ from Pixel's.

### 7. Preserve Android APK compatibility and security boundaries

The device/toolchain transition does not alter the Android compatibility contract.

Retain standard Android APK/split-APK, ART, PackageManager, ActivityManager, PermissionController, AppOps, Binder, SurfaceFlinger, Android app sandboxing, profiles/users, intents and component semantics.

F-Droid, direct APKs, compatible third-party stores and a future optional sandboxed Google compatibility layer remain ordinary Android applications.

The Sable renderer remains unprivileged relative to hardware. UI-framework choice does not justify Health/sysfs/modem/network-admin or generic privileged-command authority.

### 8. Security-support lifetime remains a selection criterion

Pixel 7 is an active development improvement, not the final hardware-security answer.

When selecting later production/reference Pixel hardware, prefer devices with materially longer remaining OEM security/vendor/firmware support. Device migration should remain cheap because Sable semantic contracts, application model and UI core are designed to survive hardware changes.

## Consequences

Positive:

- S1.8 is no longer distorted by Android 14 Rust 1.68 compatibility work;
- modern Rust UI frameworks can be compared on their actual merits;
- Pixel and Zinwa targets can share one UI architecture despite different Android/platform compiler versions;
- bramble's successful S1.7 work remains preserved rather than repeatedly rebased;
- platform security boundaries remain narrow and stable;
- future Android updates become adapter/toolchain qualification instead of UI rewrites.

Costs:

- a separately compiled UI may require a small stable FFI/AIDL adapter;
- Sable must maintain explicit provenance for both platform and UI Rust toolchains when they differ;
- dependency/security monitoring must cover the selected UI compiler and framework independently from AOSP;
- panther requires a fresh vanilla hardware, image, SELinux, vendor, kernel and app-compatibility baseline before Sable integration.

## Immediate next gate

`PANTHER-P0` performs read-only host/device/source/toolchain inventory and chooses the reproducible Android baseline. No Sable source mutation or flash occurs until that gate is reviewed.

After P0:

1. establish vanilla panther build/runtime capability baseline;
2. port the frozen S1.7 semantic power service contract without redesigning V1 semantics unless Android's service transport requires an explicitly versioned successor;
3. re-run S1.8 framework qualification against the chosen panther platform and a separately pinned modern UI-toolchain option;
4. build the first standalone Sable power UI while Launcher3 and SystemUI remain intact;
5. continue to S1.9 only after the new baseline and S1.8 client are physically proven.
