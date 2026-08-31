# S1.8 platform transition: bramble closure and panther restart

Status: **BRAMBLE CLOSED / PANTHER P0 NEXT**.

## Decision

S1.8 framework work will no longer continue on Pixel 4a 5G (`bramble`) Android 14 solely to satisfy the branch's Rust/Cargo 1.68 toolchain.

The bramble program closes with:

- S1.7 overall PASS/FROZEN as the authoritative architecture/runtime seal;
- S1.8 D0 documentation reconciliation PASS;
- S1.8 F0/F1/F2/F3/F4 qualification evidence retained;
- no S1.8 production UI source landed on bramble;
- no global AOSP Rust uplift performed;
- no Android 15 bramble portability experiment required;
- no further Slint-1.5-on-Rust-1.68 dependency pinning/backport work required.

Normative decision: `adr/0003-panther-baseline-and-rust-ui-toolchain-boundary.md`.

Final bramble UI/toolchain evidence: `S1_8_BRAMBLE_UI_QUALIFICATION_FINAL.md`.

## What the bramble UI experiment proved

The framework probes were useful despite not selecting a renderer.

1. The limitation was the Android 14 AOSP toolchain, not Pixel 4a 5G's CPU architecture.
2. The frozen bramble tree uses AOSP Rust/Cargo 1.68.
3. Current Rust UI frameworks have moved substantially beyond that toolchain.
4. Slint 1.5 core can compile on Rust 1.68 after bounded Cargo compatibility adjustments, proving that the framework was not fundamentally blocked by the device architecture.
5. F4 then showed the public Slint path entering successive transitive dependency compiler floors: after resolving Cargo-1.68 `fontdb` behavior and pinning `codemap-diagnostic` to 0.1.1, the next blocker was `toml_edit 0.21.1` requiring Rust 1.69.
6. Continuing to down-rev and pin modern UI-framework dependencies for an end-of-life Android baseline would make historical platform constraints drive Sable product architecture.
7. Current Vexo and other modern candidates also demonstrate that framework qualification should happen against a newer platform or a separately pinned UI compiler.
8. The S1.7 frozen semantic service boundary gives Sable a clean mechanism to decouple UI evolution from hardware/service implementation.

## Bramble final role

Pixel 4a 5G remains useful for:

- reproducing the frozen Android 14 S1.7 service/API architecture;
- regression archaeology;
- validating historical physical callback/slot behavior when specifically needed;
- comparison against later adapters.

It is not:

- the active S1.8 development target;
- the long-term security reference;
- a framework-selection constraint;
- a required Rust-development device;
- scheduled for an Android 15 Sable portability port.

## Panther next role

Pixel 7 (`panther`) becomes the active touch-first development reference.

The next gate is deliberately `PANTHER-P0`, not an immediate Sable port. P0 determines:

- exact device/bootloader/current-build state;
- usable official factory/OTA recovery point;
- reproducible AOSP/platform branch candidates;
- Pixel 7 proprietary/vendor binary availability for those branches;
- kernel/vendor_boot/vendor_kernel_boot partition model;
- exact Rust/Cargo/Clang/Soong toolchains;
- stock hardware/telephony/camera/audio/connectivity baseline;
- whether the newest supported Android release can be used directly as the reproducible Sable baseline or whether an older reproducible panther branch is needed temporarily for platform bring-up.

The preference is the newest supported/reproducible panther Android release, not an arbitrary older version chosen for compatibility with bramble-era code.

## UI framework reset

The S1.8 framework decision is reopened on the new baseline.

Qualification set:

- Slint;
- WaterUI;
- Project Robius + Makepad;
- Blinc;
- Vexo;
- Dioxus Native / Blitz;
- `BUILD_SABLEUI` if no candidate meets Sable requirements without disproportionate compromise.

Architectural references/tools:

- Crux: renderer-independent core/state/effect architecture;
- UniFFI: possible in-process Rust/Kotlin/Swift interop, not a shell renderer;
- Flutter Rust Bridge: Flutter/Rust interop, not a Rust-first renderer;
- Tauri: not preferred for the Sable system shell because the WebView/origin/IPC model adds an unnecessary system-shell trust surface.

Framework selection must consider:

- Metro-inspired touch-first interaction quality;
- BlackBerry/BB10-inspired physical-QWERTY interaction quality;
- shared semantic/application core across both profiles;
- multi-touch;
- keyboard/focus/traversal;
- IME/clipboard;
- accessibility;
- text shaping/localization;
- Android Activity/surface/lifecycle fit;
- SurfaceFlinger/GPU integration;
- performance, memory and idle power;
- offline/reproducible dependency integration;
- license and security provenance;
- Android-version portability;
- no renderer-specific privilege expansion.

## Rust toolchain rule

Do not make framework selection depend on whichever Rust compiler happens to be integrated into one Android branch.

Same-toolchain integration remains preferred because it permits direct use of generated Rust AIDL bindings.

If the chosen modern UI framework requires a newer separately pinned Rust toolchain:

```text
modern Rust UI
    -> stable C/NDK/AIDL adapter
    -> Sable semantic service
```

Do not directly link independently compiled Rust components across compiler-private Rust ABI.

Do not globally uplift AOSP's Rust compiler solely for UI convenience.

## Android application compatibility

The transition preserves the Android application model unchanged:

- APK/split APK;
- PackageManager/PackageInstaller;
- ART/DEX;
- ActivityManager;
- Binder;
- Android application UID/SELinux sandbox;
- runtime permissions/PermissionController;
- AppOps;
- intents/components;
- F-Droid/direct APK/other compatible stores;
- future optional sandboxed Google compatibility.

Sable's own Rust renderer is a presentation choice, not a replacement Android application runtime.

## Interaction profiles

Pixel-class devices remain the reference for the Metro-inspired touch profile.

Zinwa Q25/Q27-class devices remain the intended BlackBerry/BB10-inspired keyboard-first profile.

The panther transition must strengthen, not weaken, the requirement that both profiles share one Sable application/service semantic core.

## Next sequence

```text
S1.7 bramble
PASS / FROZEN
      |
      v
S1.8 bramble D0/F0-F4
architecture + toolchain evidence captured
      |
      X  close further A14 UI backport work
      |
      v
PANTHER-P0
source/device/toolchain baseline
      |
      v
PANTHER-V0
vanilla hardware + Android app compatibility baseline
      |
      v
S1.7 semantic service port
      |
      v
S1.8 modern Rust UI qualification + first power client
      |
      v
S1.9 lifecycle
```

No implementation source mutation, image build, flash or device state change is implied by this documentation transition.
