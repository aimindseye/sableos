# S1.8-D0/F0 Rust UI architecture and feasibility qualification

Status: **D0 PASS / F0 READY**.

## Purpose

S1.8 is the first user-facing Sable client of the frozen S1.7 Power AIDL contract and the first evidence-driven qualification of the Rust UI direction on the actual Android 14/AOSP substrate.

This gate deliberately separates architecture reconciliation from source-tree UI mutation.

- D0 reconciles normative documentation and supersedes obsolete bare-Linux UI assumptions.
- F0 compares Slint and Vexo without modifying the Sable Android source tree.
- A framework is not selected until F0 evidence is reviewed.

Normative decision: `adr/0002-rust-ui-framework-and-android-app-compatibility.md`.

## D0 closure

D0 establishes:

1. standard Android APK/split-APK, ART, PackageManager, ActivityManager, permissions/AppOps, Binder, SurfaceFlinger and ordinary Android app sandboxing remain first-class Sable requirements;
2. Sable-native UI remains Rust-first where practical but renderer-independent at the application/interaction semantic layer;
3. Metro-inspired touch-first and BlackBerry/BB10-inspired keyboard-first profiles are both first-class product directions;
4. Slint and Vexo are candidates, not immutable requirements;
5. focused framework forks or a Sable-owned Rust UI framework are valid outcomes when evidence justifies the maintenance cost;
6. UI renderers remain unprivileged relative to hardware/system services;
7. S1.8 remains a standalone app/client qualification surface; Launcher3 and AOSP SystemUI are not replaced during framework qualification;
8. Android 15 bramble portability qualification occurs after S1.8 and before S1.9;
9. App Manager informs Secure Package Intelligence/application transparency without creating a root/ADB super-app;
10. MarathonOS informs mobile/QWERTY UX, measurement, layering and recovery without transferring shell hardware privilege;
11. GrapheneOS remains a security reference for hardened Android primitives and compatibility without ambient trust;
12. historical validation records remain evidence, while accepted ADRs/normative documents govern current architecture.

## F0 pinned upstream references

F0 uses exact source revisions so the comparison can be reproduced later.

### Vexo

Repository: `vexornp/Vexo`

Pinned revision:

```text
6dba1001398d594f7b88b6e2cdf414f507c06bb2
```

Known at planning time:

- MIT license;
- Rust framework with retained widget/element/render-object architecture;
- `wgpu` GPU renderer;
- Android demo uses GameActivity and a Rust `cdylib`;
- documented Android build uses NDK + `cargo-ndk` + Gradle/Android Studio rather than AOSP Soong;
- current Android notes state clipboard is stubbed and multi-touch is not yet supported;
- project documentation describes accessibility, IME composition, tab traversal and additional common UI features as incomplete/roadmap items;
- therefore Android rendering existence is proven upstream, but full Sable touch/keyboard/accessibility shell suitability is not.

### Slint

Repository: `slint-ui/slint`

Pinned revision:

```text
40349df126715ef468db725ec59c4a984050c7d2
```

Known at planning time:

- current workspace version `1.18.0`;
- current workspace `rust-version = 1.92` and Rust edition 2024;
- Android backend exists through `android-activity`;
- open-source use is available under GPLv3, alongside other Slint licensing options;
- current-head compatibility with the Android 14 AOSP Rust toolchain is therefore an explicit F0 question rather than an assumption;
- if current head is too new, F0 may identify the newest older Slint release compatible with the AOSP Rust compiler for comparison.

## F0 principles

### No Sable source mutation

F0 may clone or inspect upstream projects in `/tmp` and may populate normal developer Cargo/git caches if the user chooses to run compilation probes, but it must not modify:

- `device/sable`;
- Sable AIDL source/API snapshots;
- Sable SELinux policy;
- product makefiles;
- Android framework source;
- build images;
- device slots.

No flash is part of F0.

### Framework selection is multidimensional

Do not select a renderer solely because it can render a static screen.

Qualification categories:

1. **AOSP toolchain fit**
   - exact AOSP Rust compiler;
   - Rust edition/MSRV;
   - proc-macro/build-script requirements;
   - native C/C++/shader/build-tool requirements.

2. **Reproducible build / supply chain**
   - lockfile state;
   - registry/git dependency count;
   - network-required build steps;
   - ability to vendor/pin sources;
   - Soong/Rust module integration cost;
   - NDK/Gradle side-build assumptions which would need replacement or bounded integration.

3. **Licensing**
   - framework license;
   - dependency licenses;
   - obligations for a fully open-source/free-use Sable distribution;
   - compatibility with repository/component licensing boundaries.

4. **Android platform fit**
   - Activity/window lifecycle;
   - Android-managed Surface;
   - SurfaceFlinger compatibility;
   - Vulkan/OpenGL/Skia/`wgpu` assumptions;
   - configuration changes and background/foreground behavior;
   - no need to bypass Android compositor/application model.

5. **Touch-first profile**
   - single-touch;
   - multi-touch;
   - gesture recognition;
   - kinetic scrolling;
   - interruptible animation;
   - typography/text shaping;
   - edge-to-edge layout;
   - large/virtualized lists;
   - IME/clipboard;
   - accessibility.

6. **Keyboard-first profile**
   - key events;
   - modifier keys;
   - repeat;
   - focus graph/traversal;
   - directional focus;
   - shortcuts;
   - type-to-search;
   - focus restoration;
   - pointer/touch coexistence;
   - IME behavior.

7. **Security/privacy**
   - renderer receives no Health/sysfs privilege;
   - no generic Binder/system privilege;
   - no unnecessary `INTERNET` permission or network client in the S1.8 power app;
   - crash cannot stop `oxynoded`;
   - Rust/native unsafe and dependency surface is inventoried rather than assumed safe because it is Rust.

8. **Android app compatibility**
   - framework does not require removal/replacement of ART, PackageManager, ActivityManager or SurfaceFlinger;
   - Sable UI can coexist with and later launch ordinary Android APKs;
   - Launcher/SystemUI replacement remains a separate later acceptance gate.

9. **Android-version portability**
   - identify API/NDK/Activity/graphics assumptions likely to change on Android 15;
   - prefer a bounded platform adapter around stable Sable UI semantics.

## F0 decision states

Each candidate receives one of:

```text
PASS_CANDIDATE
PASS_WITH_GAPS
FORK_CANDIDATE
NOT_SUITABLE
```

The combined S1.8 framework outcome is one of:

```text
SELECT_SLINT
SELECT_VEXO
SELECT_SLINT_WITH_GAPS
SELECT_VEXO_WITH_GAPS
FORK_SLINT
FORK_VEXO
BUILD_SABLEUI
NEEDS_DEEPER_PROBE
```

Do not use a simple numeric score to hide a blocking requirement. A framework can perform well overall and still fail Sable if it has a blocking accessibility, input, Android-integration, reproducibility, licensing or security defect with no credible repair path.

## Blocking requirements before S1.8-C source mutation

At least one candidate path must have a credible answer for:

- reproducible pinned source;
- open-source license compliance;
- Android 14 compiler/build integration path;
- Android-managed rendering surface;
- Rust AIDL V1 client integration path;
- touch-first basic input;
- keyboard-event/focus path suitable for future qualification;
- no requirement for direct hardware privilege;
- no requirement to remove Android APK runtime/application infrastructure;
- bounded dependency/supply-chain plan.

Full multi-touch, accessibility and keyboard-shell completeness may be classified as scheduled gaps for a standalone S1.8 power client, but such gaps block promoting that renderer to the full Sable launcher/SystemUI without later closure.

## S1.8-C invariant after F0

The selected implementation path must produce a standalone Android application/client with this boundary:

```text
Rust Sable Power UI
        |
        | frozen sable-power-aidl V1
        v
     oxynoded
        |
        v
Health callback backend
```

The app displays battery percentage, charging state, source and unavailable state. It has no Health HAL, battery sysfs, generic privileged-command or unnecessary network authority. Launcher3 and AOSP SystemUI remain present during S1.8 acceptance.

## Android 15 follow-on

After S1.8 closes, A15-P repeats the relevant app/UI/service qualification in a separate Android 15 workspace before S1.9 lifecycle work. The goal is to determine whether stable Sable semantics and the qualified Rust UI path survive a substrate move without redesign or broad security exceptions.
