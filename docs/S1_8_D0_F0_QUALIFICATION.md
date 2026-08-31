# S1.8-D0/F0-F3 Rust UI architecture and feasibility qualification

Status: **D0 PASS / BRAMBLE F0-F3 CAPTURED / ACTIVE WORK MOVED TO PANTHER**.

## Purpose

S1.8 is the first user-facing Sable client of the frozen S1.7 power semantic contract and the first evidence-driven qualification of the Rust UI direction.

This document records the now-closed Pixel 4a 5G (`bramble`) Android 14 qualification phase. It remains evidence, not an instruction to continue backporting modern UI frameworks to Rust/Cargo 1.68.

Normative decisions:

- `adr/0002-rust-ui-framework-and-android-app-compatibility.md`;
- `adr/0003-panther-baseline-and-rust-ui-toolchain-boundary.md`.

Current transition record: `S1_8_PLATFORM_TRANSITION.md`.

## D0 closure

D0 established:

1. standard Android APK/split-APK, ART, PackageManager, ActivityManager, permissions/AppOps, Binder, SurfaceFlinger and ordinary Android app sandboxing remain first-class Sable requirements;
2. Sable-native UI remains Rust-first where practical but renderer-independent at the application/interaction semantic layer;
3. Metro-inspired touch-first and BlackBerry/BB10-inspired keyboard-first profiles are both first-class product directions;
4. UI frameworks are candidates, not immutable requirements;
5. focused framework forks or a Sable-owned Rust UI framework are valid outcomes when evidence justifies the maintenance cost;
6. UI renderers remain unprivileged relative to hardware/system services;
7. Launcher3 and AOSP SystemUI are not replaced during framework qualification;
8. App Manager informs Secure Package Intelligence/application transparency without creating a root/ADB super-app;
9. MarathonOS informs mobile/QWERTY UX, measurement, layering and recovery without transferring shell hardware privilege;
10. GrapheneOS remains a security reference for hardened Android primitives and compatibility without ambient trust;
11. historical validation records remain evidence, while accepted ADRs/normative documents govern current architecture.

## Initial F0 pinned upstream references

### Vexo

Repository: `vexornp/Vexo`

Pinned revision:

```text
6dba1001398d594f7b88b6e2cdf414f507c06bb2
```

Captured facts included:

- MIT license;
- Rust retained widget/element/render-object architecture;
- `wgpu` GPU renderer;
- Android demo through GameActivity and a Rust `cdylib`;
- upstream Android workflow centered on NDK + Cargo/Gradle rather than AOSP Soong;
- Android multi-touch not yet supported at the pinned point;
- Android clipboard incomplete at the pinned point;
- accessibility, IME composition, tab traversal and other common UI capabilities still incomplete/roadmap items;
- current dependency/toolchain floor substantially newer than bramble Android 14's Rust/Cargo 1.68.

Conclusion for bramble S1.8: **DEFER**. Retain Vexo as a long-term/fork/SableUI design reference.

### Slint current head

Pinned revision:

```text
40349df126715ef468db725ec59c4a984050c7d2
```

Captured facts included:

- workspace version `1.18.0`;
- `rust-version = 1.92`;
- Rust edition 2024;
- Android backend exists;
- open-source use available under GPLv3 alongside other licensing options.

Conclusion for bramble S1.8: current head is not compatible with the Android 14 AOSP Rust 1.68 toolchain.

## F1: find the oldest credible Slint Android candidate

The first tag found with an MSRV below Rust 1.68 was Slint `v1.2.2` (`rust-version = 1.66`), but validation proved that tag did **not** yet contain Slint Android support; its own documentation still classified mobile Android/iOS as Todo.

Slint `v1.5.0` was then identified as the first credible Android candidate in this investigation:

```text
Slint 1.5.0
edition = 2021
rust-version = 1.70
Android backend = present
```

This made Slint 1.5 the near-term AOSP-1.68 bridge candidate while current Vexo was deferred.

## F2: initial Slint 1.5 Rust-1.68 probe

A temporary `/tmp` copy changed only:

```text
rust-version = "1.70"
    ->
rust-version = "1.68"
```

The first compile failed in `i-slint-common` with missing `fontdb` filesystem/fontconfig APIs.

This was **not** classified as a Rust-language incompatibility.

The root cause was Cargo-1.68 workspace feature inheritance behavior:

- Slint's workspace dependency disables `fontdb` defaults;
- the member tries to turn defaults back on;
- Cargo 1.68 does not reproduce the later behavior Slint relied on;
- `fontconfig-parser` disappeared from the resolved lock and the expected `fontdb` APIs were consequently absent.

## F3: bounded Cargo compatibility repair

The temporary probe applied only two source changes:

1. Slint workspace MSRV `1.70 -> 1.68`;
2. replace inherited `fontdb default-features=true` behavior with explicit additive features equivalent to the required default set.

Result:

```text
S1_8F3_SLINT_CORE_RUST168=PASS
S1_8F3_FONTDB_DEFAULT_EQUIVALENT=PASS
```

This is important evidence: **Slint 1.5 core itself can compile with AOSP Rust 1.68 after bounded Cargo compatibility handling.**

The next public-API blocker was then:

```text
codemap-diagnostic 0.1.2 requires rustc 1.70
```

Slint 1.5's compiler dependency range requested `codemap-diagnostic` from the `0.1.1` semver line, while Cargo resolved the newer `0.1.2`. This is another dependency-version/MSRV issue rather than evidence that bramble hardware prevents Rust UI development.

The public, software-renderer Android and stock-Android-backend probes were therefore not completed in the bramble qualification sequence.

## Bramble qualification conclusion

The investigation achieved its purpose before selecting a renderer.

```text
BRAMBLE_AOSP_RUST=1.68
SLINT15_CORE_ON_1_68=PROVEN_WITH_BOUNDED_COMPATIBILITY
CURRENT_MODERN_UI_ECOSYSTEM=GENERALLY_NEWER_TOOLCHAIN
VEXO_CURRENT_ON_AOSP168=DEFER
PRODUCTION_S1_8_UI_ON_BRAMBLE=NOT_LANDED
GLOBAL_AOSP_RUST_UPLIFT=NOT_PERFORMED
```

Continuing to pin/down-rev a succession of UI-framework dependencies for an end-of-life Android 14 platform would make a historical reference device dictate Sable's long-term UI architecture.

That work is therefore closed.

## Platform transition

Pixel 7 (`panther`) becomes the active S1.8 touch-first development reference.

`PANTHER-P0` selects the newest supported/reproducible Android platform baseline by inventorying:

- current physical device/build/bootloader state;
- official recovery/factory path;
- AOSP/device/vendor binary availability;
- kernel and partition model;
- Rust/Cargo/Clang/Soong toolchains;
- reproducibility of the newest supported Android hardware baseline.

The previously planned Android 15 bramble portability experiment is closed without execution.

## Modern framework qualification set

S1.8 qualification resumes on panther with a broader set:

- Slint;
- WaterUI;
- Project Robius + Makepad;
- Blinc;
- Vexo;
- Dioxus Native / Blitz where appropriate;
- `BUILD_SABLEUI` if no candidate meets Sable requirements without disproportionate compromise.

Crux remains an architectural reference for renderer-independent Rust application/state/effect separation.

UniFFI and Flutter Rust Bridge remain interop technologies rather than preferred Rust shell renderers.

Tauri/WebView presentation is not the preferred Sable system-shell architecture.

## Toolchain rule after bramble

Do not select the UI framework solely by the platform compiler's MSRV.

If the selected UI fits the current AOSP Rust compiler cleanly:

```text
Sable Rust UI
    -> frozen/generated Rust AIDL binding
    -> Sable service
```

If the selected UI requires a separately pinned modern Rust compiler:

```text
modern Rust UI
    -> stable C/NDK/AIDL adapter
    -> Sable semantic service
```

Do not directly link independently compiled Rust components across compiler-private Rust ABI.

Do not globally uplift AOSP's Rust compiler solely for renderer convenience.

## S1.8-C invariant

The eventual selected implementation path must still produce a standalone Android application/client with this trust boundary:

```text
Rust Sable Power UI
        |
        | stable Sable power semantic API
        v
     oxynoded / successor adapter
        |
        v
supported Android health/power backend
```

The app displays battery percentage, charging state, source and unavailable state. It has no Health HAL, battery sysfs, generic privileged-command or unnecessary network authority. Launcher3 and AOSP SystemUI remain present during S1.8 acceptance.

The UI/application core must remain reusable across the Metro-inspired touch-first Pixel profile and BlackBerry/BB10-inspired keyboard-first Zinwa Q25/Q27 profile.
