# ADR-0002: Rust UI Qualification on the Android-Compatible SableOS Substrate

Status: Accepted

## Context

SableOS intends to own its primary mobile interaction model and Sable-native applications while preserving Android/AOSP as the mature application, security, framework, compositor, hardware and vendor substrate.

Earlier concept work identified Slint for an initial Rust UI and Vexo/`wgpu` for a later GPU-oriented UI. Some of that early work was coupled to a substantially different bare-Linux architecture which proposed removing or bypassing Android components such as ART, Zygote, `system_server`, servicemanager and SurfaceFlinger, using direct framebuffer/GPU paths, raw modem or sysfs access, root-owned services, or generic privileged IPC.

Those assumptions are superseded by the Android 14 Sable architecture proven through S1.7.

SableOS is intended to be open-source and free to use. UI-framework adoption therefore prioritizes technical fit, maintainability, reproducibility and compatible open-source licensing rather than proprietary product monetization.

## Decision

### 1. Preserve the Android application substrate

SableOS keeps standard Android application compatibility as a first-class architectural requirement.

Retain and harden rather than replace without evidence:

- APK and split-APK formats;
- PackageManager / PackageInstaller;
- ART / DEX;
- Zygote and ordinary Android process/application lifecycle;
- Android UID sandboxing and SELinux application domains;
- runtime permissions / PermissionController;
- AppOps;
- intents, activities, services, providers and broadcasts;
- Android user/profile isolation;
- SurfaceFlinger and the Android graphics/window substrate;
- Binder as the local IPC foundation.

Applications installed from F-Droid, compatible third-party stores, direct APK installation, development/ADB paths, and a future optional sandboxed Google Play compatibility layer remain ordinary Android applications. They do not need to be rebuilt for the Sable-native UI framework.

### 2. Rust-first Sable UI, renderer-independent semantics

Sable-owned UI should remain Rust-first where practical, but application semantics and interaction behavior must not become tightly coupled to one renderer.

Conceptually:

```text
Sable application / interaction semantics
              |
              v
      renderer adapter boundary
         /             \
        v               v
     Slint            Vexo
        \               /
         \             /
          future SableUI
              |
              v
       Android-managed surface
              |
              v
         SurfaceFlinger
```

The renderer may change without redesigning Sable service APIs, capability semantics, navigation meaning, application meaning or privilege boundaries.

### 3. Slint and Vexo are candidates, not permanent requirements

The historic direction of Slint first and Vexo later remains useful as a hypothesis, not a binding release rule.

S1.8 qualifies both against the actual Android 14/AOSP environment. Selection is evidence-driven and may result in one of four outcomes:

- `SELECT` — use an upstream framework substantially as-is;
- `SELECT_WITH_GAPS` — use it with clearly bounded missing capabilities scheduled before shell replacement;
- `FORK` — maintain focused Sable changes when the upstream architecture is sound but specific mobile requirements are missing;
- `BUILD_SABLEUI` — create a Sable-owned framework/renderer when neither candidate can meet requirements without disproportionate architectural compromise.

If SableUI is eventually required, Slint and Vexo remain useful design references rather than failed experiments.

### 4. Android integration boundary

A Sable Rust UI runs as an Android-managed application/process and renders through an Android surface. It does not gain direct hardware authority merely because its renderer uses Vulkan, OpenGL, Skia, `wgpu`, or another GPU path.

Required direction:

```text
Sable UI
    |
    | typed semantic IPC
    v
narrow Sable service
    |
    v
Android framework / supported HAL / vendor stack
    |
    v
hardware
```

Rejected as the default Sable architecture:

- direct framebuffer/KMS ownership on Android targets;
- UI-owned Health HAL;
- UI battery sysfs access;
- raw modem/RIL protocols in the UI;
- generic privileged command executors;
- broad Linux capabilities granted to the shell for presentation features;
- renderer-specific privilege expansion.

S1.7 power is the reference implementation: UI clients consume frozen `IPowerService` rather than Health or battery sysfs.

### 5. Two first-class interaction profiles

SableOS has two deliberate mobile interaction profiles which share common application and service semantics.

#### Touch-first profile

For Pixel-class and conventional touch-first phones, the intended direction is Metro-inspired rather than stock-Android imitation:

- strong typography;
- clear spatial hierarchy;
- edge-to-edge content;
- minimal chrome;
- glanceable information surfaces;
- gesture-first navigation;
- fast peek/return workflows;
- low-latency transitions;
- deliberate large touch targets;
- motion which communicates hierarchy rather than decoration.

This is inspiration, not a Windows Phone clone.

#### Keyboard-first profile

For Zinwa Q25/Q27-class and future physical-QWERTY devices, the intended direction is BlackBerry/BB10-inspired:

- physical keyboard as a primary input path;
- deterministic focus and visible focus state;
- global and contextual shortcuts;
- type-to-search;
- command-palette / quick-launch behavior;
- fast communication/notification triage;
- predictable back/navigation semantics;
- focus restoration;
- touch, keyboard and pointer coexistence where hardware provides them.

This is inspiration, not a BlackBerry OS clone.

Device-specific presentation may differ, but message, notification, call, application, search, command, status and capability semantics remain common.

### 6. Framework qualification criteria

S1.8-F0 compares Slint and Vexo on the real Sable Android baseline. Important criteria include:

- compatibility with the selected AOSP Rust toolchain;
- reproducible/offline-capable source and dependency integration;
- Soong/product integration cost;
- dependency and supply-chain size;
- open-source license obligations;
- Android Activity/window/surface lifecycle fit;
- SurfaceFlinger and GPU/Vulkan integration;
- binary/image footprint;
- startup latency, memory and idle CPU;
- touch and multi-touch;
- scrolling and animation behavior;
- keyboard input, modifiers, repeat and focus traversal;
- IME and clipboard integration;
- accessibility bridge maturity;
- text shaping/localization readiness;
- crash isolation;
- Android-version portability risk;
- ability to consume frozen Rust AIDL bindings without backend privilege;
- absence of unnecessary network or hardware permissions.

A framework passing a small power screen is not automatically approved to replace Launcher or SystemUI.

### 7. Incremental replacement of Android presentation

S1.8 is a standalone Sable UI/client qualification surface. Launcher3 and AOSP SystemUI remain intact during framework qualification.

Later replacement is staged:

1. standalone Sable-native applications;
2. Sable HOME/launcher after app-launching and lifecycle parity are proven;
3. SystemUI presentation only through separate capability-preservation/security gates because SystemUI participates in security-sensitive and framework-integrated behavior.

Replacing presentation does not justify deleting the mature underlying Android service.

### 8. Android application ecosystem compatibility

Sable-native UI technology is independent of third-party APK technology.

A Sable launcher written in Rust may launch an ordinary Java/Kotlin/Compose/Flutter/Unity/native Android APK through normal Android intents and ActivityManager. The APK remains in its normal Android sandbox.

The security target remains compatibility without ambient trust:

```text
application source
        |
        v
standard Android package verification
        |
        v
Sable local analysis / policy
        |
        v
ordinary Android application sandbox
```

F-Droid, direct APKs, compatible stores and future optional Google compatibility must converge on the standard package-management enforcement path.

### 9. External design references

SableOS deliberately learns from multiple projects without inheriting their complete trust model.

#### App Manager

Useful lessons include package/component transparency, permission and AppOps inspection, signing identity, manifest/component visibility, tracker/library signals, split-package handling and update comparison.

Sable adapts these into platform-backed Secure Package Intelligence rather than creating a root/ADB "super app". Privileged mutations belong behind narrow platform enforcement points and services.

#### MarathonOS

Useful lessons include mobile-first interaction, gesture/peek workflows, QWERTY experimentation, measurement-driven power work, device layering, recovery discipline and immutable-image awareness.

Sable does not copy a shell-as-privilege-aggregator design. Hardware/system authority remains behind typed services and Android security boundaries.

#### GrapheneOS

Useful lessons include strengthening Android primitives, sandboxed compatibility without ambient trust, meaningful capability semantics, verified boot discipline and continuous security maintenance.

AOSP remains the normative substrate reference.

Standing rule:

> Borrow product behavior, algorithms and security properties; re-derive privilege boundaries for SableOS.

### 10. Android-version portability

The renderer and Sable semantic contracts must not define SableOS as an Android 14-only product.

The bramble Android 15 portability experiment occurs after S1.8 closes and before S1.9 begins. It should requalify the same frozen power contract and the selected/qualified S1.8 Rust UI path on the new substrate while separately measuring ordinary Android APK compatibility.

This experiment does not restore OEM firmware/vendor security support for bramble.

## Consequences

Positive:

- Sable can develop a distinctive Rust-native UX without abandoning the Android application ecosystem;
- F-Droid/Play/direct APK support remains compatible with a Rust shell;
- UI framework changes do not force backend/service redesign;
- touch-first and keyboard-first products can share semantics;
- framework gaps are measured before platform dependence grows;
- an eventual Sable-owned renderer is possible without precommitting to unnecessary reinvention;
- security and privacy boundaries remain independent of visual design.

Costs:

- S1.8 requires a deliberate framework-qualification gate before feature implementation;
- renderer-independent state/navigation abstractions require additional design work;
- Android accessibility, IME, lifecycle and packaging integration cannot be ignored by a custom renderer;
- maintaining a fork or SableUI would create a significant long-term maintenance burden and requires evidence before approval.

## Superseded assumptions

Where older project notes conflict with this ADR, the following assumptions are historical and not current Sable architecture:

- removing ART/Zygote/system_server to obtain a Rust UI;
- replacing Binder/service-manager semantics with a generic Unix-socket command API;
- direct framebuffer/KMS ownership on Android targets;
- root `oxynoded` as the normal service model;
- direct battery sysfs ownership by Sable UI/services;
- raw modem/RIL implementation as a shortcut;
- treating Slint or Vexo as immutable release requirements.

Historical validation records remain valid evidence for the milestones they document, but current architecture decisions are governed by accepted ADRs and the normative architecture/security/application-compatibility documents.
